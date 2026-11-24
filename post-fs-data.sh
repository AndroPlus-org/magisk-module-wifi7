#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}
# This script will be executed in post-fs-data mode

rm -f "${MODDIR}/mtk6g" "${MODDIR}/qcom6g"
mkdir -p "${MODDIR}/xml"

# Record boot timing to see whether the Wi-Fi driver was already loaded
{
    echo "uptime: $(cut -d' ' -f1 /proc/uptime)"
    echo "wlan modules: $(grep -i -E 'wlan|gen4m|connac|qca_cld' /proc/modules | cut -d' ' -f1 | tr '\n' ' ')"
    [ -e /proc/net/wlan ] && echo "/proc/net/wlan exists"
} > "${MODDIR}/boot.log" 2>&1

# Drop mounts left over from initrc, a soft reboot or a module update so that
# the original file is read again
unmount_cfg() {
    N=0
    while grep -q " $1 " /proc/1/mountinfo && [ $N -lt 5 ]; do
        echo "existing mount on $1: $(grep " $1 " /proc/1/mountinfo | cut -d' ' -f4 | tail -n 1)" >> "${MODDIR}/boot.log"
        nsenter -t 1 -m -- umount "$1" 2>/dev/null
        umount "$1" 2>/dev/null
        N=$((N + 1))
    done
}

# Copy the SELinux context of $2 to $1 (toybox chcon on some devices has no
# --reference)
copy_ctx() {
    CTX=$(ls -Z "$2" 2>/dev/null | awk '{print $1}')
    [ -n "$CTX" ] && chcon "$CTX" "$1"
}

# Bind-mount a patched copy over the original file.
# Mount in init's namespace so kernel-side reads of the file (request_firmware
# through ueventd) see it too.
mount_cfg() {
    chmod 644 "$1"
    copy_ctx "$1" "$2"
    nsenter -t 1 -m -- mount -o ro,bind "$1" "$2" || mount -o ro,bind "$1" "$2"
}

QCOM_RE='^(BandCapability=|oem_6g_support_disable=1|scan_mode_6ghz=0|enable_11be=0)'
CHIP=$(sed -n 's/^qca_cld3_\([^ ]*\) .*/\1/p' /proc/modules | head -n 1)

# Qualcomm (OPPO etc.): ueventd looks for firmware in /data/vendor/firmware/update/
# before /vendor/firmware/. A patched WCNSS_qcom_cfg.ini placed there survives
# reboots and is read when the driver probes, which can happen before
# post-fs-data scripts or before root comes up at all.
FWOVR=/data/vendor/firmware/update
fw_dirs() {
    # ueventd reads these files in this order
    for rc in /system/etc/ueventd.rc /vendor/ueventd.rc /vendor/etc/ueventd.rc /odm/etc/ueventd.rc; do
        sed -n 's/^[[:space:]]*firmware_directories[[:space:]]*//p' "$rc" 2>/dev/null
    done | tr ' ' '\n' | grep '^/' | sed 's@/*$@/@'
}
if [ -n "$CHIP" ] && fw_dirs | grep -q -x "$FWOVR/"; then
    KO=$(find /vendor/lib/modules /vendor_dlkm/lib/modules /system/lib/modules \
        -name "qca_cld3_${CHIP}.ko" 2>/dev/null | head -n 1)
    # The ini path the driver requests, e.g. wlan/WCNSS_qcom_cfg.ini
    REL=$(grep -a -o -E "wlan/[A-Za-z0-9_/]*WCNSS_qcom_cfg\.ini" "$KO" 2>/dev/null | head -n 1)
    OVR="$FWOVR/$REL"
    SRC=""
    if [ -n "$REL" ]; then
        for dir in $(fw_dirs); do
            [ "$dir" = "$FWOVR/" ] && continue
            if [ -e "$dir$REL" ]; then SRC="$dir$REL"; break; fi
        done
    fi
    if [ -n "$SRC" ]; then
        REAL=$(readlink -f "$SRC")
        unmount_cfg "$REAL"
        if grep -q -E "$QCOM_RE" "$REAL"; then
            mkdir -p "${OVR%/*}"
            [ -e "$OVR" ] || echo "$OVR" > "${MODDIR}/fwovr_created"
            sed \
                -e 's@^BandCapability=@#BandCapabilityMOD=@' \
                -e 's@^oem_6g_support_disable=1@#oem_6g_support_disableMOD=1@' \
                -e 's@^scan_mode_6ghz=0@#scan_mode_6ghzMOD=0@' \
                -e 's@^enable_11be=0@enable_11be=1@' \
                "$REAL" > "$OVR"
            chmod 644 "$OVR"
            restorecon -R "$FWOVR"
            echo "fw override ini: $OVR (from $SRC)" >> "${MODDIR}/boot.log"
        elif [ -f "${MODDIR}/fwovr_created" ]; then
            # No longer needed (e.g. after an OTA): remove the file we created
            rm -f "$(cat "${MODDIR}/fwovr_created")" "${MODDIR}/fwovr_created"
        fi
    fi
fi

# Qualcomm: remove the band restriction in WCNSS_qcom_cfg.ini.
# Newer devices keep one file per Wi-Fi chip (e.g. qca_cld/kiwi_v2/).
for QCOMCFG in $(find /vendor/firmware/wlan/qca_cld /vendor/etc/wifi \
    /odm/vendor/etc/wifi /odm/etc/wifi /odm/firmware/wlan/qca_cld \
    -maxdepth 2 -name 'WCNSS_qcom_cfg.ini' 2>/dev/null); do
    # Symlinks (e.g. qca_cld/<chip>/ -> /vendor/etc/wifi/<chip>/) are handled
    # through their target
    [ -L "$QCOMCFG" ] && continue
    unmount_cfg "$QCOMCFG"
    grep -q -E "$QCOM_RE" "$QCOMCFG" || continue
    MODCFG="${MODDIR}/xml/$(echo ${QCOMCFG#/} | tr / _)"
    cp -f "$QCOMCFG" "$MODCFG"
    sed -i \
        -e 's@^BandCapability=@#BandCapabilityMOD=@' \
        -e 's@^oem_6g_support_disable=1@#oem_6g_support_disableMOD=1@' \
        -e 's@^scan_mode_6ghz=0@#scan_mode_6ghzMOD=0@' \
        -e 's@^enable_11be=0@enable_11be=1@' \
        "$MODCFG"
    mount_cfg "$MODCFG" "$QCOMCFG"
    touch "${MODDIR}/qcom6g"
done

# HONOR: the driver reads WCNSS_qcom_cfg_cota.ini first. It is a symlink to
# /data/misc/wifi/wifi_cfg/WCNSS_qcom_cfg.ini (written by HONOR's config OTA),
# which survives reboots and is read before root comes up (KernelSU late-load).
COTALINK="/vendor/firmware/wlan/qca_cld/${CHIP}/WCNSS_qcom_cfg_cota.ini"
if [ -n "$CHIP" ] && [ -L "$COTALINK" ]; then
    COTA=$(readlink "$COTALINK")
    case "$COTA" in
    /data/*)
        if [ ! -e "$COTA" ]; then
            BASE="/vendor/firmware/wlan/qca_cld/${CHIP}/WCNSS_qcom_cfg.ini"
            mkdir -p "${COTA%/*}"
            cp -f "$BASE" "$COTA"
            # Remember that the file is ours so uninstall.sh can remove it
            echo "$COTA" > "${MODDIR}/cota_created"
        fi
        # BandCapability / oem_6g_support_disable: same as HONOR's overseas
        # config (WCNSS_qcom_cfg_ovs.ini).
        # scan_mode_6ghz: 2 = scan all 6GHz channels. The default and the
        # overseas config use 4 (PSC channels only, non-PSC only when found in
        # an RNR), which misses 6GHz-only SSIDs on non-PSC channels.
        sed -i \
            -e 's@^#*BandCapability\(MOD\)*=.*@BandCapability=7@' \
            -e 's@^#*oem_6g_support_disable\(MOD\)*=.*@oem_6g_support_disable=0@' \
            -e 's@^#*scan_mode_6ghz\(MOD\)*=.*@scan_mode_6ghz=2@' \
            "$COTA"
        chown -R 1010:1010 "${COTA%/*}"
        chmod 774 "${COTA%/*}" "$COTA"
        restorecon -R "${COTA%/*}"
        echo "cota ini: $COTA" >> "${MODDIR}/boot.log"
        ;;
    esac
fi

# MediaTek: allow 6GHz in the driver config (DisallowBand6G 1 on CN builds)
for MTKCFG in /odm/etc/wifi/wifi.cfg /vendor/etc/wifi/wifi.cfg /vendor/firmware/wifi.cfg; do
    unmount_cfg "$MTKCFG"
    grep -q '^DisallowBand6G[[:space:]]*1' "$MTKCFG" 2>/dev/null || continue
    MODCFG="${MODDIR}/xml/$(echo ${MTKCFG#/} | tr / _)"
    cp -f "$MTKCFG" "$MODCFG"
    sed -i 's/^\(DisallowBand6G[[:space:]]*\)1/\10/' "$MODCFG"
    # Early copy for initrc/wifi7.rc (on init), since /data is not ready yet
    if [ -d /metadata ]; then
        mkdir -p /metadata/enable-wifi-7
        cp -f "$MODCFG" /metadata/enable-wifi-7/
        chmod 644 "/metadata/enable-wifi-7/${MODCFG##*/}"
        copy_ctx "/metadata/enable-wifi-7/${MODCFG##*/}" "$MTKCFG"
    fi
    mount_cfg "$MODCFG" "$MTKCFG"
    touch "${MODDIR}/mtk6g"
done
echo "init ns mount: $(grep -c -E 'wifi.cfg|WCNSS_qcom_cfg' /proc/1/mountinfo)" >> "${MODDIR}/boot.log"

# Comment out if you don't want to change country code
resetprop -n ro.boot.wificountrycode AU
#resetprop -n ro.boot.hwc US
command -v iw >/dev/null && iw reg set AU
