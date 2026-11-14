#!/bin/sh
# Stage patched framework-telecom, apply bind (host root), run verify-guest-call.
# Usage: ANDROID_SERIAL=RFCY70YWGFY scripts/run-guest-telephony-acceptance.sh
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
export PATH="/opt/homebrew/opt/e2fsprogs/sbin:$PATH"
SERIAL=${1:-${ANDROID_SERIAL:-RFCY70YWGFY}}
STAGE=/data/local/tmp/oneos

echo "=== waiting for $SERIAL"
adb -s "$SERIAL" wait-for-device

"$ROOT/scripts/stage-telephony-fix-from-device.sh" || exit $?

echo "=== repair (host root: bind framework-telecom + telecom cleanup)"
if adb -s "$SERIAL" shell "su -c 'sh $STAGE/repair-guest-telephony.sh'" 2>/dev/null; then
    :
elif adb -s "$SERIAL" root 2>/dev/null && adb -s "$SERIAL" shell "sh $STAGE/repair-guest-telephony.sh"; then
    :
else
    echo "WARN: repair needs KernelSU/host root — run on device: su -c sh $STAGE/repair-guest-telephony.sh"
    adb -s "$SERIAL" shell "sh /data/local/tmp/live-guest-telephony.sh" 2>/dev/null || true
fi

"$ROOT/scripts/verify-guest-call.sh" "$SERIAL"
