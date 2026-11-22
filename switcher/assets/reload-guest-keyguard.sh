#!/system/bin/sh
# Optional: persist lockscreen.auto_pin_confirm in the guest (no process restart).
# PIN length and auto-submit at runtime come from services_patched.jar (guest_local_lock.py).
set -eu
PID=$(pidof system_server | awk '{print $1}')
[ -n "$PID" ] || exit 1
BB=$(which busybox 2>/dev/null)
[ -n "$BB" ] || BB=/data/adb/ksu/bin/busybox
G=/data/oneos_genv.sh
if [ -x "$BB" ]; then
    "$BB" nsenter -t "$PID" -m /system/bin/sh "$G" /system/bin/settings put secure lockscreen.auto_pin_confirm 1 2>/dev/null || true
else
    nsenter -t "$PID" -m /system/bin/sh "$G" /system/bin/settings put secure lockscreen.auto_pin_confirm 1 2>/dev/null || true
fi
echo "lockscreen.auto_pin_confirm=1 (no SystemUI restart)"
