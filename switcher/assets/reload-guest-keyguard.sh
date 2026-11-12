#!/system/bin/sh
# Restart guest SystemUI so it re-reads PIN length / metrics (no guest soft-reboot).
set -eu
PID=$(pidof system_server | awk '{print $1}')
[ -n "$PID" ] || exit 1
BB=$(which busybox)
G=/data/oneos_genv.sh
$BB nsenter -t "$PID" -m /system/bin/sh "$G" /system/bin/settings put secure lockscreen.auto_pin_confirm 1 2>/dev/null || true
$BB nsenter -t "$PID" -m /system/bin/sh "$G" /system/bin/pkill -TERM com.android.systemui 2>/dev/null || true
sleep 3
$BB nsenter -t "$PID" -m /system/bin/sh "$G" /system/bin/cmd statusbar expand-settings 2>/dev/null || true
echo "SystemUI restart requested (pid was $PID)"
