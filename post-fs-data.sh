#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}
# This script will be executed in post-fs-data mode

WIFICFG="WCNSS_qcom_cfg.ini"
if [ -e "${MODDIR}/xml/${WIFICFG}" ]; then
    mount -o ro,bind ${MODDIR}/xml/${WIFICFG} /odm/vendor/etc/wifi/${WIFICFG}
fi

# Record boot timing to see whether the Wi-Fi driver was already loaded
{
    echo "uptime: $(cut -d' ' -f1 /proc/uptime)"
    echo "wlan modules: $(grep -i -E 'wlan|gen4m|connac' /proc/modules | cut -d' ' -f1 | tr '\n' ' ')"
    [ -e /proc/net/wlan ] && echo "/proc/net/wlan exists"
} > "${MODDIR}/boot.log" 2>&1

# MediaTek: allow 6GHz in the driver config (DisallowBand6G 1 on CN builds)
for MTKCFG in /odm/etc/wifi/wifi.cfg /vendor/etc/wifi/wifi.cfg /vendor/firmware/wifi.cfg; do
    grep -q '^DisallowBand6G[[:space:]]*1' "$MTKCFG" 2>/dev/null || continue
    MODCFG="${MODDIR}/xml/$(echo ${MTKCFG#/} | tr / _)"
    cp -f "$MTKCFG" "$MODCFG"
    sed -i 's/^\(DisallowBand6G[[:space:]]*\)1/\10/' "$MODCFG"
    chmod 644 "$MODCFG"
    chcon --reference="$MTKCFG" "$MODCFG"
    mount -o ro,bind "$MODCFG" "$MTKCFG"
done

# Comment out if you don't want to change country code
resetprop -n ro.boot.wificountrycode AU
#resetprop -n ro.boot.hwc US
iw reg set AU