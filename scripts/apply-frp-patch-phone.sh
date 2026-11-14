#!/bin/sh
# Install guest_no_frp_policy services_patched.jar on the phone stage and keep it
# across prepares/switches (oneos_switch.sh re-applies from attic when the
# marker exists). Usage:
#   scripts/build-frp-services-jar.sh
#   scripts/apply-frp-patch-phone.sh [path/to/out.jar]
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SERIAL="${ANDROID_SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" && $1 !~ /^emulator/ {print $1; exit}')}"
[ -n "$SERIAL" ] && export ANDROID_SERIAL="$SERIAL"
JAR="${1:-/tmp/oneos-frp-only/out.jar}"
if [ ! -f "$JAR" ]; then
    echo "building $JAR ..." >&2
    "$ROOT/scripts/build-frp-services-jar.sh"
fi
[ -f "$JAR" ] || { echo "missing $JAR" >&2; exit 1; }
SHA=$(shasum -a 256 "$JAR" | awk '{print $1}')
echo "FRP jar $SHA"
adb push "$JAR" /data/local/tmp/services_frp_patched.jar
adb shell su -M -c "
ST=/data/local/tmp/oneos
mkdir -p \$ST/attic \$ST/data
cp -f /data/local/tmp/services_frp_patched.jar \$ST/attic/services_patched.frp.jar
echo $SHA > \$ST/data/oneos_frp_policy
cp -f \$ST/attic/services_patched.frp.jar \$ST/services_patched.jar
sed -i 's/^[0-9a-f]\\{64\\}  services_patched\\.jar/$SHA  services_patched.jar/' \$ST/files.sha256 \$ST/guards.txt 2>/dev/null || true
sha256sum \$ST/services_patched.jar
grep services_patched \$ST/files.sha256 | head -1
"
if [ -f "$ROOT/switcher/assets/oneos_switch.sh" ]; then
    adb push "$ROOT/switcher/assets/oneos_switch.sh" /data/local/tmp/oneos_switch.sh.new
    adb shell su -M -c 'cp -f /data/local/tmp/oneos_switch.sh.new /data/local/tmp/oneos/oneos_switch.sh && chmod 755 /data/local/tmp/oneos/oneos_switch.sh'
fi
echo "Done. Restart guest or switch to Pixel; FRP patch re-applies after every app prepare."
