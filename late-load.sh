#!/system/bin/sh
# KernelSU late-load (root loaded after boot, e.g. locked bootloader) runs
# late-load.sh instead of post-fs-data.sh
MODDIR=${0%/*}
sh "${MODDIR}/post-fs-data.sh"
