#!/bin/sh
# Pull telephonycore from a running OneOS stage, build framework-telecom_patched.jar,
# push back to STAGE. Requires adb + debugfs (e2fsprogs on macOS: brew install e2fsprogs).
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SERIAL=${ANDROID_SERIAL:-RFCY70YWGFY}
STAGE=/data/local/tmp/oneos
adb -s "$SERIAL" wait-for-device
adb -s "$SERIAL" pull "$STAGE/telephonycore_payload.img" "$ROOT/out/telephonycore_payload.img"
"$ROOT/scripts/patch-framework-telecom-from-payload.sh" \
    "$ROOT/out/telephonycore_payload.img" \
    "$ROOT/out/framework-telecom_patched.jar"
adb -s "$SERIAL" push "$ROOT/out/framework-telecom_patched.jar" "$STAGE/"
adb -s "$SERIAL" push "$ROOT/switcher/assets/live-guest-telephony.sh" /data/local/tmp/live-guest-telephony.sh
adb -s "$SERIAL" push "$ROOT/switcher/assets/repair-guest-telephony.sh" "$STAGE/repair-guest-telephony.sh"
echo "Staged. Host root: sh $STAGE/repair-guest-telephony.sh"
echo "Guest adb:     sh /data/local/tmp/live-guest-telephony.sh"
echo "Test:          $ROOT/scripts/verify-guest-call.sh $SERIAL"
