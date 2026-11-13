#!/usr/bin/env bash
# Push and run live-guest-blur-ksud.sh on the phone (One UI root).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERIAL="${SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
[ -n "$SERIAL" ] || { echo "no adb device"; exit 1; }
SRC="$ROOT/switcher/assets/live-guest-blur-ksud.sh"
adb -s "$SERIAL" push "$SRC" /data/local/tmp/oneos/live-guest-blur-ksud.sh
adb -s "$SERIAL" shell "su 0 sh -c 'chmod 755 /data/local/tmp/oneos/live-guest-blur-ksud.sh && STAGE=/data/local/tmp/oneos sh /data/local/tmp/oneos/live-guest-blur-ksud.sh'"
