#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERIAL="${ANDROID_SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
[ -n "$SERIAL" ] || { echo "no adb device"; exit 1; }
for f in guest_bind_patched_jars.sh live-guest-lock-reload.sh guest_start.sh; do
  adb -s "$SERIAL" push "$ROOT/switcher/assets/$f" "/data/local/tmp/oneos_$f" 2>/dev/null ||
    adb -s "$SERIAL" push "$ROOT/switcher/assets/$f" "/data/local/tmp/$f"
done
adb -s "$SERIAL" shell "su 0 sh -c '
  ST=/data/local/tmp/oneos
  cp /data/local/tmp/guest_bind_patched_jars.sh \$ST/ 2>/dev/null || cp /data/local/tmp/oneos_guest_bind_patched_jars.sh \$ST/guest_bind_patched_jars.sh
  cp /data/local/tmp/guest_start.sh \$ST/guest_start.sh
  cp /data/local/tmp/guest_start.sh \$ST/data/guest_start.sh
  chmod 755 \$ST/guest_bind_patched_jars.sh \$ST/guest_start.sh \$ST/data/guest_start.sh
  STAGE=\$ST sh /data/local/tmp/live-guest-lock-reload.sh || STAGE=\$ST sh \$ST/live-guest-lock-reload.sh
'"
