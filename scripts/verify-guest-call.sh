#!/bin/sh
# Acceptance check for Pixel guest telephony (dialer +79091545004, two-way audio).
# Usage: scripts/verify-guest-call.sh [adb-serial]
set -eu
SERIAL=${1:-${ANDROID_SERIAL:-}}
ADB() { if [ -n "$SERIAL" ]; then adb -s "$SERIAL" "$@"; else adb "$@"; fi; }
[ "$(ADB devices | awk '/device$/{print $1}' | head -1)" ] || {
    echo "no adb device" >&2
    exit 1
}
NUM='+79091545004'
echo "=== preflight"
ADB shell 'settings get global mobile_data_always_on; cmd phone ims get-ims-service -s 0 -d -f 1 2>&1 | tail -1'
echo "=== dial from Phone UI (launch + DIAL prefill; tap green on device)"
ADB shell 'am force-stop com.google.android.dialer; am start -a android.intent.action.DIAL -d tel:'"$NUM"
echo "waiting 20s — place call with green button if needed"
sleep 20
echo "=== telecom"
ADB shell 'dumpsys telecom 2>/dev/null' | rg -i 'state=ACTIVE|state=DIALING|state=RINGING|Invalid audio|Foreground call' | head -12
echo "=== dialer crash"
ADB shell 'logcat -d -t 30' 2>/dev/null | rg -i 'invalid audio route|VoiceFragmentPeer|FATAL.*dialer' | tail -8 || true
echo "=== audio mode"
ADB shell 'dumpsys audio 2>/dev/null' | rg 'Actual mode|MODE_IN_CALL' | head -3
echo "=== cellular data during call"
ADB shell 'dumpsys telephony.registry 2>/dev/null' | rg 'mDataConnectionState=|SUSPENDED|CONNECTED' | head -6
echo "=== ping"
ADB shell 'ping -c 2 -W 2 8.8.8.8' || true
echo "=== end call"
ADB shell 'input keyevent KEYCODE_ENDCALL; cmd telecom cleanup-stuck-calls' 2>/dev/null || true
