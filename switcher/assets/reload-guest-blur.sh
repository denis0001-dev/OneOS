#!/system/bin/sh
# Allow window-level blur in the running guest (no guest restart, no SystemUI kill).
# Sets disable_window_blurs=0 and asks WindowManagerService (BlurController) to refresh.
set -eu
STAGE=/data/local/tmp/oneos
PID=$(pidof system_server | awk '{print $1}')
[ -n "$PID" ] || { echo "no guest system_server"; exit 1; }
BB=$(which busybox 2>/dev/null)
[ -n "$BB" ] || BB=/data/adb/ksu/bin/busybox
G=/data/oneos_genv.sh
run() {
    if [ -x "$BB" ]; then
        "$BB" nsenter -t "$PID" -m /system/bin/sh "$G" "$@"
    else
        nsenter -t "$PID" -m /system/bin/sh "$G" "$@"
    fi
}
if [ -f "$STAGE/rootfs/system/framework/oplus-services.jar" ]; then
    echo "ColorOS guest: window blur left to guest_props (no change)"
    exit 0
fi
BEFORE=$(run /system/bin/settings get global disable_window_blurs 2>/dev/null | tr -d '\r')
run /system/bin/settings put global disable_window_blurs 0 2>/dev/null || true
run /system/bin/cmd window disable-blur 0 2>/dev/null || true
AFTER=$(run /system/bin/settings get global disable_window_blurs 2>/dev/null | tr -d '\r')
BLUR=$(run /system/bin/dumpsys window 2>/dev/null | grep -m1 'mBlurEnabled' | tr -d '\r')
echo "disable_window_blurs: ${BEFORE:-?} -> ${AFTER:-?}"
echo "$BLUR"
