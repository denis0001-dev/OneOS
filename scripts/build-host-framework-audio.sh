#!/bin/sh
# One UI host framework.jar with vendor audio usages accepted in setUsage,
# for in-place return after a guest audioserver session (Invalid usage 1005).
#
# Usage: scripts/build-host-framework-audio.sh [path-to-host-framework.jar] [out.jar]
#   With no argument, reads the jar from the phone over adb (root).
#   Default out: build/generated/oneos/session/host_framework_audio_patched.jar
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${2:-"$ROOT/app-android/app/build/generated/oneos/session/host_framework_audio_patched.jar"}
SRC=${1:-}
mkdir -p "$(dirname "$OUT")"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if [ -z "$SRC" ]; then
    SERIAL=${SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}
    [ -n "$SERIAL" ] || { echo "no adb device; pass host framework.jar" >&2; exit 1; }
    adb -s "$SERIAL" exec-out su 0 cat /system/framework/framework.jar > "$TMP/host-framework.jar"
    SRC="$TMP/host-framework.jar"
fi
[ -s "$SRC" ] || { echo "empty or missing $SRC" >&2; exit 1; }
if "$ROOT/scripts/patch-built-jar.sh" "$SRC" \
        "$ROOT/switcher/patches/guest_audio_vendor_usage.py" "$OUT" 2>"$TMP/err"; then
    echo "built $OUT"
elif grep -qE 'already patched|changed nothing' "$TMP/err" 2>/dev/null; then
    cp "$SRC" "$OUT"
    echo "host framework: vendor audio patch not needed; copied unchanged -> $OUT"
else
    cat "$TMP/err" >&2
    exit 1
fi
chmod 644 "$OUT"
sha256sum "$OUT"