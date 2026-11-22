#!/system/bin/sh
# OneOS: clear stale session markers without reboot (One UI still running).
set -eu
STAGE=/data/local/tmp/oneos
BB=
for x in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox; do
    [ -x "$x" ] && BB=$x && break
done
[ -n "$BB" ] || { echo "reset-state: no busybox"; exit 1; }

echo "reset-state: stage=$STAGE"

for pat in oneos_switch guest_runtime.ui_activator oneos_wdog_feeder; do
    for pid in $($BB pgrep -f "$pat" 2>/dev/null); do
        kill -TERM "$pid" 2>/dev/null || true
    done
done

if awk -v s="$STAGE/tmp/guest_runtime_baseline/allowlist.saved" 'index($5, s) { found=1 } END { exit !found }' /proc/self/mountinfo 2>/dev/null ||
   $BB mount 2>/dev/null | grep -q allowlist.saved; then
    if $BB umount /data/adb/ksu/.allowlist 2>/dev/null; then
        echo "reset-state: umount allowlist bind ok"
    else
        echo "reset-state: WARN umount allowlist failed"
    fi
fi

rm -f "$STAGE/tmp/switch.lock" \
    "$STAGE/tmp/guest_runtime_baseline/.running" \
    "$STAGE/bin/.lock" 2>/dev/null || true

B="$STAGE/tmp/guest_runtime_baseline"
if [ -f "$B/allowlist.protected" ] && ! $BB mount 2>/dev/null | grep -q allowlist.saved; then
    rm -f "$B/allowlist.protected"
    echo "reset-state: cleared stale allowlist.protected"
fi

if [ ! -f "$STAGE/persist_session.active" ]; then
    echo "reset-state: no persist_session.active"
else
    ONEOS_APP=1 STAGE="$STAGE" $BB nsenter -t 1 -m -- /system/bin/sh "$STAGE/guest_props.sh" restore-persist --recover
    rc=$?
    echo "reset-state: guest_props restore-persist exit=$rc"
    [ "$rc" -eq 0 ] || exit "$rc"
fi

if grep -F "$STAGE" /proc/1/mountinfo 2>/dev/null | grep -q .; then
    echo "reset-state: WARN mounts still under stage:"
    grep -F "$STAGE" /proc/1/mountinfo | head -5
    exit 2
fi

echo "reset-state: OK — force-stop OneOS and reopen"
