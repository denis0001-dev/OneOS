#!/system/bin/sh
# One UI: KernelSU manager, OneOS, shell and Termux get full root on the host.
# Run before guest_runtime baseline (allowlist freeze) and after return restore.
set -eu
S=${STAGE:-/data/local/tmp/oneos}
[ "$(id -u)" = 0 ] || exit 0
GR="$S/guest_root"
[ -x "$GR" ] || { echo "host_ksu_grants: no $GR" >&2; exit 1; }
if ! "$GR" --host-grant-core; then
    echo "host_ksu_grants: one or more core grants failed" >&2
    exit 1
fi
echo "host_ksu_grants: core KernelSU profiles granted on One UI"