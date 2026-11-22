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
if [ -z "$APKTOOL" ]; then
    APKTOOL=apktool
fi
JAR=$(cd "$(dirname "$JAR")" && pwd)/$(basename "$JAR")
PATCHER=$(cd "$(dirname "$PATCHER")" && pwd)/$(basename "$PATCHER")
mkdir -p "$(dirname "$OUT")"
OUT=$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")
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
       [ -z "$(cd "$W/src/$FULL" && find . -name 'OneOS*.smali' 2>/dev/null)" ]; then
        cat "$W/apktool.err" >&2
        exit 1
    fi
    LAST=$(ls -d "$W"/src/smali_classes* 2>/dev/null | sed 's/.*smali_classes//' | sort -n | tail -1)
    OWN="smali_classes$((${LAST:-1} + 1))"
    (cd "$W/src/$FULL" && find . -name 'OneOS*.smali') | while read -r f; do
        mkdir -p "$W/src/$OWN/$(dirname "$f")"
        mv "$W/src/$FULL/$f" "$W/src/$OWN/$f"
        echo "services.jar: $FULL is past 65536 method references, $f moved to $OWN"
    done
    DIRS="$DIRS $OWN"
    run_apktool b -q -o "$W/rebuilt.jar" "$W/src"
fi
cp "$JAR" "$W/out.jar"
for d in $DIRS; do
    DEX="$(echo "$d" | sed 's/^smali_//; s/^smali$/classes/').dex"
    rm -rf "$W/dex" && mkdir -p "$W/dex"
    unzip -q -o "$W/rebuilt.jar" "$DEX" -d "$W/dex"
    if command -v zip >/dev/null 2>&1; then
        (cd "$W/dex" && zip -q -0 "$W/out.jar" "$DEX")
    else
        # The Windows toolchain has the JDK but no Info-ZIP. jar's
        # --no-compress update keeps the replacement dex stored as ART expects.
        jar --update --file "$W/out.jar" --no-compress -C "$W/dex" "$DEX"
    fi
    python3 - "$W/out.jar" "$DEX" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    info = archive.getinfo(sys.argv[2])
    if info.compress_type != zipfile.ZIP_STORED:
        raise SystemExit(f"{sys.argv[2]} is not stored")
    if archive.testzip() is not None:
        raise SystemExit("rebuilt jar failed its ZIP integrity check")
PY
    echo "replaced $DEX"
done
# A dex-container original (One UI 9.5's telephony-common.jar) needs all rebuilt dex files; no class may go missing.
python3 -I "$ROOT/scripts/dex-container-fix.py" "$JAR" "$W/rebuilt.jar" "$W/out.jar"
python3 "$ROOT/scripts/check-dex.py" "$W/out.jar" >&2 || true
mv "$W/out.jar" "$OUT"
echo "built $OUT"
if [ "$(basename "$OUT")" = "services_patched.jar" ] || [ "$(basename "$JAR")" = "services_patched.jar" ]; then
    echo "patch-built-jar: update guards.txt for the jar's new sha256 (make-overlays.sh, or packages/<set>.guards.txt and out/overlays_*/guards.txt)" >&2
fi
