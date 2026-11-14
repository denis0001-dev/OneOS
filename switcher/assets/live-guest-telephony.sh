#!/system/bin/sh
# Guest telephony hotfix (no full switch / guest reboot). Safe from adb shell while the
# Pixel guest is foreground: clears wedged Telecom calls, reasserts Samsung IMS, and
# refreshes the default dialer InCall bindings.
set -eu
STAGE=${STAGE:-/data/local/tmp/oneos}
G=/system/bin/sh /data/oneos_genv.sh
[ -f /data/oneos_genv.sh ] || G=

run() {
    if [ -n "$G" ]; then $G "$@"; else "$@"; fi
}

echo "=== live-guest-telephony ($(date +%T))"

echo "telecom: cleanup stuck calls"
run cmd telecom cleanup-stuck-calls 2>/dev/null || true
run cmd telecom cleanup-orphan-phone-accounts 2>/dev/null || true

echo "telecom: default dialer"
run cmd telecom set-default-dialer com.google.android.dialer 2>/dev/null || true
echo "default dialer: $(run cmd telecom get-default-dialer 2>/dev/null | tr -d '\r')"

if [ -e "$STAGE/data/oneos_sec_ims" ] && [ ! -L "$STAGE/data/oneos_sec_ims" ]; then
    echo "Samsung IMS"
    for s in 0 1; do
        run cmd phone ims set-ims-service -s "$s" -d -f 0,1 com.sec.imsservice >/dev/null 2>&1 || true
        b=$(run cmd phone ims get-ims-service -s "$s" -d -f 1 2>&1 | tr -d '\r' | tail -1)
        echo "slot $s bound: $b"
    done
    ss=$(run getprop gsm.sim.state 2>/dev/null | tr -d '\r')
    for s in 0 1; do
        st=$(echo "$ss" | cut -d, -f$((s + 1)))
        [ "$st" = LOADED ] || continue
        run am broadcast -a android.intent.action.ISIM_LOADED --ei phone "$s" >/dev/null 2>&1 &&
            echo "ISIM_LOADED slot $s"
    done
fi

echo "refresh InCall UI"
run am force-stop com.google.android.dialer 2>/dev/null || true
run am force-stop com.google.android.telecomui 2>/dev/null || true

if run service check android.hardware.audio.core.IModule/default 2>/dev/null | grep -q ': found'; then
    slot=$(run cat /data/oneos_call_slot 2>/dev/null | tr -d '\r\n' || true)
    [ -z "$slot" ] && slot=1
    hex=$(printf '0x%02x' "$slot")
    run service call android.hardware.audio.core.IModule/default 34 \
        i32 1 i32 1 i32 4 s16 g_call_sim_slot i32 1 i32 1 i32 4 s16 "$hex" i32 0 2>/dev/null | head -1 || true
    echo "g_call_sim_slot idle hint: $hex"
fi

ring=$(run dumpsys telecom 2>/dev/null | awk '/Ringing calls:/{f=1;next} f&&/^    [^ ]/{exit} f{print}' | grep -c . || true)
echo "live-guest-telephony: done (ringing call lines in dump: ${ring:-0})"
