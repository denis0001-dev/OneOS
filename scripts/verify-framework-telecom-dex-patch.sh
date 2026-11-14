#!/bin/sh
# Confirm CallAudioState ctor coerces route/mask 0 in a built framework-telecom_patched.jar.
# Usage: verify-framework-telecom-dex-patch.sh [jar]
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
JAR="${1:-$ROOT/out/framework-telecom_patched.jar}"
[ -f "$JAR" ] || { echo "missing jar: $JAR" >&2; exit 1; }
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
DEXDUMP=$(ls "$ANDROID_HOME"/build-tools/*/dexdump 2>/dev/null | tail -1)
[ -x "$DEXDUMP" ] || { echo "dexdump not in ANDROID_HOME=$ANDROID_HOME" >&2; exit 1; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
unzip -q -o "$JAR" classes.dex -d "$TMP"
OUT=$("$DEXDUMP" -d "$TMP/classes.dex" 2>/dev/null) || { echo "dexdump failed" >&2; exit 1; }
echo "$OUT" | rg -q 'CallAudioState.<init>:\(ZIILandroid' &&
    echo "$OUT" | rg -A6 'CallAudioState.<init>:\(ZIILandroid' | rg -q 'if-nez v2' &&
    echo "$OUT" | rg -A6 'CallAudioState.<init>:\(ZIILandroid' | rg -q 'const/4 v2, #int 1' &&
    echo "$OUT" | rg -A8 'CallAudioState.<init>:\(ZIILandroid' | rg -q 'const/16 v3, #int 15' ||
    { echo "FAIL: CallAudioState route/mask coercion not in dex" >&2; exit 1; }
echo "PASS: framework-telecom dex patch ($JAR)"
