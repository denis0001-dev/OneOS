#!/system/bin/sh
# One UI: grant the official KernelSU manager and Termux full root before a
# guest session snapshots /data/adb/ksu/.allowlist (guest_runtime baseline).
set -eu
S=${STAGE:-/data/local/tmp/oneos}
[ "$(id -u)" = 0 ] || exit 0
[ -x /data/adb/ksud ] || exit 0
GR="$S/guest_root"
[ -x "$GR" ] || exit 0
if ! "$GR" --host-grant-core; then
    echo "host_ksu_grants: one or more grants failed"
    exit 1
fi
echo "host_ksu_grants: KernelSU manager and Termux have full root"
