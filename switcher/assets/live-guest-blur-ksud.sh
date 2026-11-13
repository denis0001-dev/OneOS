#!/system/bin/sh
# Live guest fix: window blur prop + settings, optional KernelSU ksud reload.
# Run as One UI root while the guest is up (not from unprivileged adb in the guest).
set -eu
STAGE=${STAGE:-/data/local/tmp/oneos}
[ "$(id -u)" = 0 ] || { echo "live-guest-blur-ksud: need uid 0 (su 0 sh -c)" >&2; exit 1; }
for c in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox; do
    [ -x "$c" ] && BB=$c && break
done
[ -n "${BB:-}" ] || BB=$(command -v busybox 2>/dev/null || true)
PID=$(pidof system_server 2>/dev/null | awk '{print $1}')
[ -n "$PID" ] || { echo "live-guest-blur-ksud: no system_server" >&2; exit 1; }
case "$(readlink "/proc/$PID/root" 2>/dev/null)" in
    "$STAGE/rootfs"|"$STAGE/rootfs"/*) GUEST=1 ;;
    *) GUEST=0 ;;
esac
run() {
    [ -n "$BB" ] || return 1
    "$BB" nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh "$@"
}
RP=""
for c in /data/adb/ksu/bin/resetprop /data/adb/ap/bin/resetprop; do
    [ -x "$c" ] && RP=$c && break
done
if [ "$GUEST" = 1 ]; then
  echo "live-guest-blur-ksud: guest system_server pid $PID"
  if [ -n "$RP" ]; then
    run "$RP" -n ro.surface_flinger.supports_background_blur 1 &&
      echo "live-guest-blur-ksud: ro.surface_flinger.supports_background_blur=1"
  fi
  run /system/bin/settings put global disable_window_blurs 0 &&
    echo "live-guest-blur-ksud: disable_window_blurs=0"
  bl=$(run /system/bin/dumpsys window windows 2>/dev/null | grep -m 1 -o 'mBlurEnabled=[a-z]*' || true)
  echo "live-guest-blur-ksud: $bl"
  if [ -x "$STAGE/reload-guest-ksud.sh" ]; then
    STAGE="$STAGE" /system/bin/sh "$STAGE/reload-guest-ksud.sh" || true
  fi
  if [ -x "$STAGE/repair-guest-session.sh" ]; then
    echo "live-guest-blur-ksud: running repair-guest-session (SystemUI refresh)"
    STAGE="$STAGE" /system/bin/sh "$STAGE/repair-guest-session.sh"
  fi
else
  echo "live-guest-blur-ksud: system_server is One UI; blur props apply on next switch" >&2
  exit 1
fi
