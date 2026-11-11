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
ST=/data/local/tmp/oneos
adb shell "su -M -c 'mkdir -p $ST/attic && cp -f /data/local/tmp/services_frp_patched.jar $ST/attic/services_patched.frp.jar && cp -f $ST/attic/services_patched.frp.jar $ST/services_patched.jar'"
echo "$SHA" | adb shell "su -M -c 'cat > /data/local/tmp/oneos_frp_policy'"
SYNC=$(mktemp)
cat > "$SYNC" <<EOF
#!/system/bin/sh
set -e
ST=$ST
SHA=$SHA
chattr -i "\$ST/files.sha256" "\$ST/guards.txt" "\$ST/services_patched.jar" 2>/dev/null || true
sed -i "s/^[0-9a-f]\{64\}  services_patched\.jar/\$SHA  services_patched.jar/" "\$ST/files.sha256" "\$ST/guards.txt"
GSHA=\$(sha256sum "\$ST/guards.txt" | cut -d' ' -f1)
sed -i "s/^[0-9a-f]\{64\}  guards\.txt/\$GSHA  guards.txt/" "\$ST/files.sha256"
sha256sum "\$ST/services_patched.jar" "\$ST/guards.txt"
grep -E 'services_patched|^'\$GSHA'  guards.txt' "\$ST/files.sha256"
EOF
adb push "$SYNC" /data/local/tmp/oneos-sync-frp-hashes.sh
adb shell su -M -c 'sh /data/local/tmp/oneos-sync-frp-hashes.sh'
rm -f "$SYNC"
if [ -f "$ROOT/switcher/assets/oneos_switch.sh" ]; then
  adb push "$ROOT/switcher/assets/oneos_switch.sh" /data/local/tmp/oneos_switch.sh.new
  adb shell "su -M -c 'chattr -i $ST/oneos_switch.sh 2>/dev/null; cp -f /data/local/tmp/oneos_switch.sh.new $ST/oneos_switch.sh && chmod 755 $ST/oneos_switch.sh'"
fi
echo "Done. Restart guest or switch to Pixel; FRP patch re-applies after every app prepare."
