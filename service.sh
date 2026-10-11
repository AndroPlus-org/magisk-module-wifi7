#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}

has_6g_channels() {
    iw phy 2>/dev/null | grep -q -E ' (59[3-9][0-9]|6[0-9][0-9][0-9]|7[01][0-9][0-9]) MHz'
}

{
    # Wait 10 seconds
    until [[ "$(getprop sys.boot_completed)" == "1" ]]; do
        sleep 10
    done

    cmd wifi force-country-code enabled AU

    # MediaTek: if the driver came up before wifi.cfg was replaced, restart
    # Wi-Fi once so it reloads the config with 6GHz allowed
    if [ -e "${MODDIR}/mtk6g" ] && ! has_6g_channels; then
        echo "service: no 6GHz channels at $(cut -d' ' -f1 /proc/uptime)" >> "${MODDIR}/boot.log"
        if [ "$(settings get global wifi_on)" != "0" ]; then
            cmd wifi set-wifi-enabled disabled
            sleep 5
            cmd wifi set-wifi-enabled enabled
            sleep 10
        fi
        has_6g_channels && R=yes || R=no
        echo "service: 6GHz channels after Wi-Fi restart: $R" >> "${MODDIR}/boot.log"
    fi
}&