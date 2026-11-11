#!/bin/sh
# Quick FRP patch state on the phone (run on One UI).
set -e
SERIAL="${ANDROID_SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" && $1 !~ /^emulator/ {print $1; exit}')}"
[ -n "$SERIAL" ] && export ANDROID_SERIAL="$SERIAL"
adb shell "su -M -c '
ST=/data/local/tmp/oneos
echo === services jar ===
sha256sum \$ST/services_patched.jar \$ST/attic/services_patched.frp.jar 2>/dev/null
grep \" services_patched.jar\$\" \$ST/files.sha256 2>/dev/null
J=\$(sha256sum \$ST/services_patched.jar 2>/dev/null | awk \"{print \\\$1}\")
M=\$(head -1 /data/local/tmp/oneos_frp_policy 2>/dev/null)
[ -n \"\$M\" ] && [ \"\$J\" = \"\$M\" ] && echo jar_matches_marker || echo \"WARN: jar (\$J) != marker (\$M)\"
HOOK=\$(grep -c FRP_PATCH= \$ST/oneos_switch.sh 2>/dev/null || echo 0)
[ \"\$HOOK\" -gt 0 ] || echo WARN: stock_oneos_switch_no_frp_hook
echo === marker ===
cat /data/local/tmp/oneos_frp_policy 2>/dev/null || cat \$ST/data/oneos_frp_policy 2>/dev/null || echo no_marker
echo === switch hook ===
grep -c FRP_PATCH= \$ST/oneos_switch.sh 2>/dev/null || echo 0
echo === last switch frp line ===
grep -i \"FRP policy\" \$ST/../oneos_switch.log /data/local/tmp/oneos_switch.log 2>/dev/null | tail -3
'"
