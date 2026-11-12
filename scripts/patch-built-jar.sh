#!/bin/sh
# Apply one more smali patcher to an already-built guard jar (a set's
# services_patched.jar), without the guest image: decode the jar, run the
# patcher, rebuild, and put only the dex files the patcher names into a copy of
# the jar (the same step as make-overlays.sh; every other entry stays byte for
# byte). For sets whose image is no longer on the server.
#
# Usage: scripts/patch-built-jar.sh <built jar> <patcher.py> <out jar>
set -e
JAR="$1"; PATCHER="$2"; OUT="$3"
[ -f "$JAR" ] && [ -f "$PATCHER" ] && [ -n "$OUT" ] || { echo "usage: $0 <built jar> <patcher.py> <out jar>" >&2; exit 2; }
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APKTOOL=${APKTOOL:-$(ls "$ROOT"/mysticgsi/tools/apktool/*.jar 2>/dev/null | head -1)}
[ -n "$APKTOOL" ] || APKTOOL=apktool
JAR=$(realpath "$JAR"); PATCHER=$(realpath "$PATCHER"); OUT=$(realpath -m "$OUT")
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
case "$APKTOOL" in
    *.jar) run_apktool() { java -jar "$APKTOOL" "$@"; } ;;
    *) run_apktool() { "$APKTOOL" "$@"; } ;;
esac
run_apktool d -q -f -r -o "$W/src" "$JAR"
DIRS=$(python3 -I "$PATCHER" "$W/src")
[ -n "$DIRS" ] || { echo "$PATCHER changed nothing" >&2; exit 1; }
if ! run_apktool b -q -o "$W/rebuilt.jar" "$W/src" 2> "$W/apktool.err"; then
    FULL=$(sed -n 's/.*Could not smali folder: \(smali[_a-z0-9]*\).*/\1/p' "$W/apktool.err" | head -1)
    if [ -z "$FULL" ] || ! grep -q 'Unsigned short value out of range' "$W/apktool.err" ||
       [ -z "$(cd "$W/src/$FULL" && find . -name 'OneOS*.smali')" ]; then
        cat "$W/apktool.err" >&2
        exit 1
    fi
    LAST=$(ls -d "$W"/src/smali_classes* 2>/dev/null | sed 's/.*smali_classes//' | sort -n | tail -1)
    OWN="smali_classes$((${LAST:-1} + 1))"
    (cd "$W/src/$FULL" && find . -name 'OneOS*.smali') | while read -r f; do
        mkdir -p "$W/src/$OWN/$(dirname "$f")"
        mv "$W/src/$FULL/$f" "$W/src/$OWN/$f"
        echo "dex overflow: $FULL $f -> $OWN" >&2
    done
    run_apktool b -q -o "$W/rebuilt.jar" "$W/src"
    DIRS="$DIRS $OWN"
fi
cp "$JAR" "$W/out.jar"
for d in $DIRS; do
    DEX="$(echo "$d" | sed 's/^smali_//; s/^smali$/classes/').dex"
    rm -rf "$W/dex" && mkdir -p "$W/dex"
    unzip -q -o "$W/rebuilt.jar" "$DEX" -d "$W/dex"
    (cd "$W/dex" && zip -q -0 "$W/out.jar" "$DEX")
    echo "replaced $DEX"
done
python3 "$ROOT/scripts/check-dex.py" "$W/out.jar" >&2 || true
mv "$W/out.jar" "$OUT"
echo "built $OUT"
