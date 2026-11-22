#!/bin/sh
# Build framework-telecom_patched.jar from a staged telephonycore_payload.img
# (make-overlays.sh does the same during overlay builds).
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PAYLOAD="${1:-$ROOT/app-android/packages/telephonycore_payload.img}"
OUT="${2:-$ROOT/out/framework-telecom_patched.jar}"
[ -f "$PAYLOAD" ] || { echo "usage: $0 [telephonycore_payload.img] [out.jar]" >&2; exit 2; }
if [ -z "${DEBUGFS:-}" ] || [ ! -x "$DEBUGFS" ]; then
    DEBUGFS=$(command -v debugfs 2>/dev/null || true)
fi
for cand in "$DEBUGFS" /opt/homebrew/opt/e2fsprogs/sbin/debugfs /usr/local/opt/e2fsprogs/sbin/debugfs /usr/sbin/debugfs; do
    [ -n "$cand" ] && [ -x "$cand" ] && DEBUGFS=$cand && break
done
[ -x "$DEBUGFS" ] || { echo "debugfs not found (brew install e2fsprogs)" >&2; exit 1; }
APKTOOL=${APKTOOL:-apktool}
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
"$DEBUGFS" -R "dump /javalib/framework-telecom.jar $WORK/framework-telecom.jar" "$PAYLOAD" 2>/dev/null ||
    { echo "debugfs: /javalib/framework-telecom.jar not in $PAYLOAD" >&2; exit 1; }
[ -s "$WORK/framework-telecom.jar" ] || { echo "empty framework-telecom.jar" >&2; exit 1; }
$APKTOOL d -q -f -r -o "$WORK/ftc" "$WORK/framework-telecom.jar"
DIRS=$(python3 -I "$ROOT/switcher/patches/guest_telecom_audio_route.py" "$WORK/ftc")
$APKTOOL b -q -o "$WORK/ftc-rebuilt.jar" "$WORK/ftc"
cp "$WORK/framework-telecom.jar" "$WORK/out.jar"
for d in $DIRS; do
    DEX="$(echo "$d" | sed 's/^smali_//; s/^smali$/classes/').dex"
    rm -rf "$WORK/vdex" && mkdir -p "$WORK/vdex"
    unzip -q -o "$WORK/ftc-rebuilt.jar" "$DEX" -d "$WORK/vdex"
    (cd "$WORK/vdex" && zip -q -0 "$WORK/out.jar" "$DEX")
    echo "replaced $DEX"
done
python3 -I "$ROOT/scripts/check-dex.py" "$WORK/out.jar"
mkdir -p "$(dirname "$OUT")"
mv -f "$WORK/out.jar" "$OUT"
echo "built $OUT"
