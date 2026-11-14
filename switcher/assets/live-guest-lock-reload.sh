#!/system/bin/sh
# Re-bind services_patched (guest PIN) and refresh keyguard; needs One UI root
# while the guest runs. From guest adb alone, only settings (no bind).
set -eu
STAGE=${STAGE:-/data/local/tmp/oneos}
[ "$(id -u)" = 0 ] || { echo "live-guest-lock-reload: need su 0 (host KernelSU)" >&2; exit 1; }
[ -x "$STAGE/guest_bind_patched_jars.sh" ] || [ -x /data/local/tmp/guest_bind_patched_jars.sh ] || {
    echo "live-guest-lock-reload: guest_bind_patched_jars.sh missing in $STAGE" >&2
    exit 1
}
[ -x "$STAGE/guest_bind_patched_jars.sh" ] || cp /data/local/tmp/guest_bind_patched_jars.sh "$STAGE/"
chmod 755 "$STAGE/guest_bind_patched_jars.sh"
STAGE="$STAGE" /system/bin/sh "$STAGE/guest_bind_patched_jars.sh"
setprop oneos.guest.powerctl ksud:soft-reboot
echo "live-guest-lock-reload: soft-reboot requested (patched services after pivot in guest_start)"
