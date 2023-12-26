REPLACE="
"

WIFICFG="WCNSS_qcom_cfg.ini"
if [ -e /odm/vendor/etc/wifi/${WIFICFG} ]; then
    cp -a /odm/vendor/etc/wifi/${WIFICFG} ${MODPATH}/xml/${WIFICFG}
    sed -i 's@BandCapability=@#BandCapabilityMOD=@g' ${MODPATH}/xml/${WIFICFG}
fi

if [ -e /mnt/vendor/persist/wlan/${WIFICFG} ]; then
    sed -i 's@BandCapability=@#BandCapabilityMOD=@g' /mnt/vendor/persist/wlan/${WIFICFG}
fi