#!/bin/sh
# Build services_patched.jar with guest_no_frp_policy.py only (no stage gatekeeper).
# Input jar defaults to the phone stage copy or a path argument.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APKTOOL="${APKTOOL:-$(ls /tmp/apktool.jar "$ROOT"/mysticgsi/tools/apktool/*.jar 2>/dev/null | head -1)}"
[ -f "$APKTOOL" ] || { echo "need apktool.jar (APKTOOL=...)" >&2; exit 1; }

IN="${1:-}"
if [ -z "$IN" ]; then
    SERIAL="${ANDROID_SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" && $1 !~ /^emulator/ {print $1; exit}')}"
    [ -n "$SERIAL" ] && export ANDROID_SERIAL="$SERIAL"
    TMP=/tmp/oneos-device-services.jar
    adb pull /data/local/tmp/oneos/services_patched.jar "$TMP" >/dev/null
    IN="$TMP"
fi
[ -f "$IN" ] || { echo "missing input jar: $IN" >&2; exit 1; }

J=/tmp/oneos-frp-only
rm -rf "$J"
mkdir -p "$J"
java -jar "$APKTOOL" d -q -f -r -o "$J/src" "$IN"
python3 -I "$ROOT/switcher/patches/guest_no_frp_policy.py" "$J/src"
java -jar "$APKTOOL" b -q -o "$J/rebuilt.jar" "$J/src" 2>"$J/apktool.err" || {
    tail -20 "$J/apktool.err" >&2
    exit 1
}
cp "$IN" "$J/out.jar"
for d in smali smali_classes2 smali_classes3 smali_classes4 smali_classes5; do
    case "$d" in
        smali) DEX=classes.dex ;;
        *) DEX="classes${d#smali_classes}.dex" ;;
    esac
    if unzip -l "$J/rebuilt.jar" "$DEX" 2>/dev/null | grep -q " $DEX"; then
        rm -rf "$J/dex"
        mkdir -p "$J/dex"
        unzip -q -o "$J/rebuilt.jar" "$DEX" -d "$J/dex"
        (cd "$J/dex" && zip -q -0 "$J/out.jar" "$DEX")
        echo "replaced $DEX"
    fi
done
shasum -a 256 "$J/out.jar"
echo "$J/out.jar"
