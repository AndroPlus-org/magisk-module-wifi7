#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}

# Avoid {n} repetition: some device grep builds do not accept it
SIXG_RE='(59[3-9][0-9]|6[0-9][0-9][0-9]|7[01][0-9][0-9])'

has_6g_channels() {
    if command -v iw >/dev/null; then
        iw phy 2>/dev/null | grep -q -E " $SIXG_RE MHz"
    else
        # Some devices ship without iw
        cmd wifi get-allowed-channel 2>/dev/null | grep -q -E "(^| )$SIXG_RE( |$)"
    fi
}

driver_country() {
    dumpsys wifi 2>/dev/null | sed -n 's/^ *mDriverCountryCode: *//p' | head -n 1
}

log() {
    echo "service: $* ($(cut -d' ' -f1 /proc/uptime))" >> "${MODDIR}/boot.log"
}

override_country() {
    dumpsys wifi 2>/dev/null | sed -n 's/^ *mOverrideCountryCode: *//p' | head -n 1
}

# Wait until system_server has stayed up for 20 seconds. KernelSU late-load
# runs service.sh right after boot, and the framework may restart around then,
# which drops the forced country code.
wait_system_server() {
    STABLE=0
    LAST=""
    while [ "$STABLE" -lt 4 ]; do
        sleep 5
        PID=$(pidof system_server)
        if [ -n "$PID" ] && [ "$PID" = "$LAST" ] && \
            [ "$(getprop sys.boot_completed)" = "1" ] && cmd wifi status >/dev/null 2>&1; then
            STABLE=$((STABLE + 1))
        else
            STABLE=0
        fi
        LAST="$PID"
    done
}

{
    wait_system_server

    cmd wifi force-country-code enabled AU
    sleep 3

    RESTART=0
    # The framework defers a country code change while Wi-Fi is connected,
    # so the driver can stay on the old one (e.g. CN) until Wi-Fi restarts
    CC=$(driver_country)
    if [ -n "$CC" ] && [ "$CC" != "AU" ]; then
        log "driver country code is $CC"
        RESTART=1
    fi
    # MediaTek: if the driver came up before wifi.cfg was replaced, restart
    # Wi-Fi once so it reloads the config with 6GHz allowed
    if [ -e "${MODDIR}/mtk6g" ] && ! has_6g_channels; then
        log "no 6GHz channels"
        RESTART=1
    fi

    if [ "$RESTART" = 1 ] && [ "$(settings get global wifi_on)" != "0" ]; then
        cmd wifi set-wifi-enabled disabled
        sleep 5
        cmd wifi set-wifi-enabled enabled
        sleep 10
        log "after Wi-Fi restart: country $(driver_country)"
    fi

    has_6g_channels && R=yes || R=no
    log "6GHz channels: $R"
    # Qualcomm reads WCNSS_qcom_cfg.ini only when the driver probes. If root
    # came up after that (e.g. KernelSU late-load), the patched file is not
    # used until the driver is loaded again.
    if [ -e "${MODDIR}/qcom6g" ] && [ "$R" = no ]; then
        log "WCNSS_qcom_cfg.ini was patched after the driver loaded"
    fi

    # Re-apply if the forced country code was dropped (framework restart)
    for i in 1 2 3; do
        sleep 60
        [ "$(override_country)" = "AU" ] && continue
        log "override country code is $(override_country), re-applying"
        wait_system_server
        cmd wifi force-country-code enabled AU
        if [ "$(settings get global wifi_on)" != "0" ]; then
            cmd wifi set-wifi-enabled disabled
            sleep 5
            cmd wifi set-wifi-enabled enabled
            sleep 10
        fi
        log "country after re-apply: $(driver_country)"
    done
}&
