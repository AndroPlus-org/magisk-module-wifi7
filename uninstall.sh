#!/system/bin/sh
MODDIR=${0%/*}

# Early copies for initrc/wifi7.rc
rm -rf /metadata/enable-wifi-7

# Remove the driver config files created by post-fs-data.sh
if [ -f "${MODDIR}/cota_created" ]; then
    # HONOR COTA Wi-Fi config
    COTA=$(cat "${MODDIR}/cota_created")
    case "$COTA" in
    /data/misc/wifi/*) rm -f "$COTA" ;;
    esac
fi
if [ -f "${MODDIR}/fwovr_created" ]; then
    # WCNSS_qcom_cfg.ini in /data/vendor/firmware/update/
    OVR=$(cat "${MODDIR}/fwovr_created")
    case "$OVR" in
    /data/vendor/firmware/update/*) rm -f "$OVR" ;;
    esac
fi
