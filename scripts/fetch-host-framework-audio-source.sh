#!/bin/sh
# Pull the host One UI framework.jar for building host_framework_audio_patched.jar.
# Usage: [SERIAL=…] scripts/fetch-host-framework-audio-source.sh [s25|s26]
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SERIES=${1:-s25}
case "$SERIES" in s25|s26) ;; *) echo "fetch-host-framework-audio-source: unknown series $SERIES" >&2; exit 2 ;; esac
OUT="$ROOT/app-android/packages/host-framework-audio-sources/$SERIES.jar"
mkdir -p "$(dirname "$OUT")"
SERIAL=${SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}
[ -n "$SERIAL" ] || { echo "fetch-host-framework-audio-source: no adb device" >&2; exit 1; }
adb -s "$SERIAL" exec-out su 0 cat /system/framework/framework.jar >"$OUT.$$"
mv -f "$OUT.$$" "$OUT"
[ -s "$OUT" ] || { echo "fetch-host-framework-audio-source: empty $OUT" >&2; exit 1; }
echo "fetch-host-framework-audio-source: wrote $OUT ($(wc -c <"$OUT") bytes from $SERIAL)"