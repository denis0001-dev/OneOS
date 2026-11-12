#!/bin/sh
# Build OneOSSettingsGoogle.apk (VPN null guard); donor = komodo SettingsGoogle.apk.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
IN="${1:-/tmp/SettingsGoogle.apk}"
OUT="${2:-$ROOT/out/OneOSSettingsGoogle.apk}"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ZIPALIGN=$(ls "$SDK"/build-tools/*/zipalign 2>/dev/null | sort -V | tail -1)
[ -f "$IN" ] && [ -n "$ZIPALIGN" ] || { echo "usage: $0 <SettingsGoogle.apk> [out]; need ANDROID_HOME zipalign" >&2; exit 2; }
python3 "$ROOT/scripts/build-pixel-settings-vpn.py" "$IN" --zipalign "$ZIPALIGN" --output "$OUT"
