REPLACE="
"

# WCNSS_qcom_cfg.ini under /vendor and /odm is patched at boot by post-fs-data.sh
WIFICFG="WCNSS_qcom_cfg.ini"
if [ -e /mnt/vendor/persist/wlan/${WIFICFG} ]; then
    sed -i 's@BandCapability=@#BandCapabilityMOD=@g' /mnt/vendor/persist/wlan/${WIFICFG}
    # Samsung
    sed -i 's@enable_11be=0@enable_11be=1@g' /mnt/vendor/persist/wlan/${WIFICFG}
fi
