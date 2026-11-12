#!/bin/sh
# Build OneOSSettingsGoogle.apk: ignore null legacy VPN profiles in Network settings.
# Donor must be the image's own SettingsGoogle.apk (platform cert, byte-for-byte base).
#
# Usage: scripts/build-pixel-settings-vpn.sh <SettingsGoogle.apk> <out apk>
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IN="$1"
OUT="$2"
[ -f "$IN" ] && [ -n "$OUT" ] || { echo "usage: $0 <SettingsGoogle.apk> <out apk>" >&2; exit 2; }
APKTOOL=${APKTOOL:-/tmp/apktool.jar}
case "$APKTOOL" in
    *.jar) run_apktool() { java -jar "$APKTOOL" "$@"; } ;;
    *) run_apktool() { "$APKTOOL" "$@"; } ;;
esac
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
IN=$(realpath "$IN"); OUT=$(realpath -m "$OUT")
run_apktool d -q -f -r -o "$W/src" "$IN"
DIRS=$(python3 -I "$ROOT/switcher/patches/guest_settings_vpn_null.py" "$W/src")
[ -n "$DIRS" ] || { echo "guest_settings_vpn_null changed nothing" >&2; exit 1; }
if ! run_apktool b -q -o "$W/rebuilt.apk" "$W/src" 2> "$W/apktool.err"; then
    cat "$W/apktool.err" >&2
    exit 1
fi
cp "$IN" "$W/out.apk"
for d in $DIRS; do
    DEX="$(echo "$d" | sed 's/^smali_//; s/^smali$/classes/').dex"
    rm -rf "$W/dex" && mkdir -p "$W/dex"
    unzip -q -o "$W/rebuilt.apk" "$DEX" -d "$W/dex"
    (cd "$W/dex" && zip -q -0 "$W/out.apk" "$DEX")
    echo "replaced $DEX"
done
mv "$W/out.apk" "$OUT"
shasum -a 256 "$OUT"
echo "built $OUT"
