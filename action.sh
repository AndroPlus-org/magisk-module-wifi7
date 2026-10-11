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
    grep -h wifi /proc/mounts

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
    dumpsys wifi 2>/dev/null | grep -i -E '11be|wifi7|6ghz|6g band|eht|mlo' | cut -c1-300 | head -n 40

    section "Driver config files"
    for f in $(find /vendor/firmware /vendor/etc/wifi /odm/firmware /odm/etc/wifi \
        /odm/vendor/firmware /odm/vendor/etc/wifi /mnt/vendor/persist/wlan \
        -maxdepth 2 \( -iname 'wifi*.cfg' -o -iname '*.ini' \) 2>/dev/null); do
        echo "--- $f"
        grep -v -E '^[[:space:]]*(#|$)' "$f" | head -n 200
    done

    section "OPLUS feature flags"
    find /my_product/etc /my_region/etc /my_bigball/etc /my_stock/etc /my_heytap/etc \
        /odm/etc/permissions /vendor/etc/permissions /product/etc/permissions \
        -name '*.xml' 2>/dev/null | xargs grep -i -h -E 'wifi7|wifi_7|11be|6ghz|wifi_6g|wlan.*6g' 2>/dev/null | cut -c1-300 | head -n 60

    section "Wi-Fi props"
    getprop | grep -i -E 'wifi|wlan|6g' | grep -v -i 'mac' | head -n 80

    section "Driver 6GHz state"
    echo "--- boot.log (post-fs-data)"
    cat "$MODDIR/boot.log" 2>&1
    echo "--- wifi.cfg mount in init namespace"
    grep wifi /proc/1/mountinfo
    echo "--- current uptime: $(cut -d' ' -f1 /proc/uptime)"
    grep -i -E 'wlan|gen4m|connac' /proc/modules | cut -d' ' -f1
    find /vendor /odm /data/vendor /mnt/vendor -name 'wifi*.cfg' 2>/dev/null
    ls /proc/net/wlan /proc/wlan 2>&1
    for c in /proc/net/wlan/cfg /proc/wlan/cfg; do
        [ -r "$c" ] && head -c 4000 "$c"
    done
    for k in DisallowBand6G ApEHT StaEHT; do
        echo "GET_CFG $k: $(wpa_cli -i wlan0 -p /data/vendor/wifi/wpa/sockets DRIVER GET_CFG $k 2>&1 | tail -n 1)"
    done
    iw reg get 2>&1 | head -n 40
    iw phy 2>&1 | grep -E 'Band [0-9]|MHz' | cut -c1-120 | head -n 120
    echo "--- scan results >= 5925MHz"
    cmd wifi list-scan-results 2>&1 | awk 'NR==1 || $2+0 >= 5925' | head -n 30
    echo "--- dmesg"
    dmesg 2>/dev/null | grep -i -E '6g|band6|wifi.cfg|DisallowBand|country|regd' | tail -n 60
    echo "--- logcat"
    logcat -d -b all 2>/dev/null | grep -i -E '6ghz|band6g|DisallowBand|6g band' | tail -n 40
}

diag 2>&1 | tee "$OUT"
echo
echo "Saved to $OUT"
