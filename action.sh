#!/system/bin/sh
# Diagnostics for "Enable Wi-Fi 6GHz & Wi-Fi 7".
# Run from the Action button in Magisk / KernelSU manager.
# The result is printed and also saved to /sdcard/Download/wifi7_diag.txt
MODDIR=${0%/*}
OUT=/sdcard/Download/wifi7_diag.txt

section() { echo; echo "===== $1"; }

diag() {
    section "Root / Module"
    echo "KSU=${KSU:-} KSU_VER=${KSU_VER:-} KSU_VER_CODE=${KSU_VER_CODE:-}"
    echo "MAGISK_VER=${MAGISK_VER:-} MAGISK_VER_CODE=${MAGISK_VER_CODE:-}"
    grep -E '^(version|versionCode)=' "$MODDIR/module.prop"
    ls -la /data/adb/metamodule 2>&1
    ls -la "$MODDIR" "$MODDIR/system/product/overlay" "$MODDIR/product/overlay" 2>&1
    [ -e "$MODDIR/skip_mount" ] && echo "skip_mount exists"
    [ -e "$MODDIR/disable" ] && echo "module disabled"

    section "Device"
    for p in ro.product.manufacturer ro.product.model ro.product.device \
        ro.board.platform ro.soc.manufacturer ro.soc.model \
        ro.build.version.release ro.build.display.id \
        ro.oplus.wifi.11be_disabled ro.boot.wificountrycode; do
        echo "$p=$(getprop $p)"
    done

    section "Overlay files"
    ls -l /product/overlay/treble-overlay-wifi7*.apk /system/product/overlay/treble-overlay-wifi7*.apk 2>&1
    grep -E ' /(product|system/product|system)( |/overlay)' /proc/mounts

    section "Wi-Fi resource packages"
    for pkg in $(pm list packages | grep -i wifi | sed 's/^package://'); do
        echo "$pkg $(pm path $pkg | tr '\n' ' ')"
    done

    section "Overlays targeting wifi resources"
    cmd overlay list | grep -i -A20 'wifi.resources'
    cmd overlay dump 2>/dev/null | grep -i -B2 -A12 'wifi7'

    section "Resolved values"
    for pkg in com.android.wifi.resources com.google.android.wifi.resources; do
        pm path $pkg >/dev/null 2>&1 || continue
        for r in bool/config_wifi11beSupportOverride bool/config_wifi6ghzSupport \
            bool/config_wifiSoftapIeee80211beSupported integer/config_wifiBand6GhzBonus; do
            echo "$pkg:$r = $(cmd overlay lookup $pkg $pkg:$r 2>&1)"
        done
    done

    section "Wi-Fi state"
    cmd wifi get-country-code 2>&1
    cmd wifi status 2>&1 | head -n 20
    dumpsys wifi 2>/dev/null | grep -i -E '11be|wifi7|6ghz|6g band|eht|mlo' | head -n 40

    section "Driver config files"
    for f in $(find /vendor/firmware /vendor/etc/wifi /odm/firmware /odm/etc/wifi \
        /odm/vendor/firmware /odm/vendor/etc/wifi /mnt/vendor/persist/wlan \
        -maxdepth 2 \( -iname 'wifi*.cfg' -o -iname '*.ini' \) 2>/dev/null); do
        echo "--- $f"
        grep -i -E '6g|eht|11be|band|mlo|wifi7' "$f" | head -n 40
    done

    section "OPLUS feature flags"
    grep -r -i -h -E 'wifi7|wifi_7|11be|6ghz|wifi_6g|wlan.*6g' \
        /my_product/etc /my_region/etc /my_bigball/etc /my_stock/etc /my_heytap/etc \
        /odm/etc/permissions /vendor/etc/permissions /product/etc/permissions 2>/dev/null | head -n 60
}

diag 2>&1 | tee "$OUT"
echo
echo "Saved to $OUT"
