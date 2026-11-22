#!/usr/bin/env bash
# Build, install, and launch OneOS full debug APK (/run). Run from anywhere.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SERIAL="${SERIAL:-$(adb devices 2>/dev/null | awk 'NR>1 && $2 == "device" { print $1; exit }')}"
SERIES="${SERIES:-s25}"
PACK_SETS=0
LAUNCH=1
FLAVOR=full

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    echo "usage: $0 [--series s25|s26|fold|…] [--pack-sets] [--no-launch] [--probe] [--serial SERIAL]"
    exit 2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --series) SERIES="$2"; shift 2 ;;
        --pack-sets) PACK_SETS=1; shift ;;
        --no-launch) LAUNCH=0; shift ;;
        --probe) FLAVOR=probe; shift ;;
        --serial) SERIAL="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "unknown arg: $1" >&2; usage ;;
    esac
done

if [ -z "${SERIAL:-}" ]; then
    echo "run-oneos: no adb device (set SERIAL=…)" >&2
    exit 1
fi

if [ -z "${JAVA_HOME:-}" ] && [ -d /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home ]; then
    export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
fi

cd "$ROOT/app-android"
GRADLE=(./gradlew)
if [ "$FLAVOR" = probe ]; then
    GRADLE+=(:app:assembleProbeDebug)
else
    GRADLE+=(:app:assembleFullDebug -Poneos.series="$SERIES")
    [ "$PACK_SETS" = 1 ] && GRADLE+=(-Poneos.packSets=true)
fi

echo "run-oneos: serial=$SERIAL series=$SERIES packSets=$PACK_SETS flavor=$FLAVOR"
"${GRADLE[@]}"

if [ "$FLAVOR" = probe ]; then
    APK="$ROOT/app-android/app/build/outputs/apk/probe/debug/app-probe-debug.apk"
    PKG=com.fahadali.oneos.probe
    ACT=.ui.MainActivity
else
    APK="$ROOT/app-android/app/build/outputs/apk/full/debug/app-full-debug.apk"
    PKG=com.fahadali.oneos
    ACT=.ui.MainActivity
fi

[ -f "$APK" ] || { echo "run-oneos: missing $APK" >&2; exit 1; }

adb -s "$SERIAL" install -r "$APK"
if [ "$LAUNCH" = 1 ]; then
    adb -s "$SERIAL" shell am force-stop "$PKG"
    adb -s "$SERIAL" shell am start -a android.intent.action.MAIN \
        -c android.intent.category.LAUNCHER -n "$PKG/$ACT"
fi
echo "run-oneos: done ($APK)"