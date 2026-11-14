#!/system/bin/sh
# Live guest telephony repair (no full switch back to One UI). Host root only.
# Clears wedged Telecom calls, re-binds Samsung IMS, nudges the call-audio HAL
# slot hint, and restarts the phone stack if nothing is active.
set -eu
STAGE=${STAGE:-/data/local/tmp/oneos}
[ "$(id -u)" = 0 ] || { echo "repair-guest-telephony: need uid 0" >&2; exit 1; }
for c in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox; do
    [ -x "$c" ] && BB=$c && break
done
[ -n "${BB:-}" ] || BB=$(command -v busybox 2>/dev/null || true)
[ -n "${BB:-}" ] || { echo "repair-guest-telephony: busybox not found" >&2; exit 1; }
PID=$(pidof system_server 2>/dev/null | awk '{print $1}')
[ -n "$PID" ] || { echo "repair-guest-telephony: no system_server" >&2; exit 1; }
case "$(readlink "/proc/$PID/root" 2>/dev/null)" in
    "$STAGE/rootfs"|"$STAGE/rootfs"/*) ;;
    *) echo "repair-guest-telephony: system_server is One UI; run during a guest session" >&2; exit 1 ;;
esac
run() { "$BB" nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh "$@"; }
G="timeout 20 $BB nsenter -t $PID -m /system/bin/sh /data/oneos_genv.sh"

active_calls() {
    run dumpsys telecom 2>/dev/null | grep -cE 'state=(RINGING|ACTIVE|DIALING|CONNECTING|ON_HOLD)' || true
}

echo "=== repair-guest-telephony: telecom cleanup ($(date +%T))"
if run cmd telecom cleanup-stuck-calls 2>/dev/null; then
    echo "telecom cleanup-stuck-calls: ok"
else
  echo "telecom cleanup-stuck-calls: unavailable (trying key events)"
    run input keyevent 6 2>/dev/null || true
fi
n=$(active_calls)
echo "telecom active-like calls after cleanup: $n"

if [ -e "$STAGE/data/oneos_sec_ims" ] && [ ! -L "$STAGE/data/oneos_sec_ims" ]; then
    echo "=== Samsung IMS ($(date +%T))"
    ims_bound() { $G /system/bin/cmd phone ims get-ims-service -s "$1" -d -f 1 2>&1 | tr -d '\r' | tail -1; }
    i=0
    while [ "$i" -lt 15 ] && ! $G /system/bin/service check phone 2>/dev/null | grep -q ': found'; do
        sleep 1
        i=$((i + 1))
    done
    SB=0
    for s in 0 1; do
        o=$($G /system/bin/cmd phone ims set-ims-service -s "$s" -d -f 0,1 com.sec.imsservice 2>&1 | tr '\n' ' ' | head -c 120)
        echo "slot $s set-ims-service: $o"
        b=$(ims_bound "$s")
        echo "slot $s bound: $b"
        [ "$b" = com.sec.imsservice ] && SB=1
    done
    if [ "$SB" = 0 ]; then
        $G /system/bin/cmd overlay fabricate --target android --name OneOSImsMmtel \
            android:string/config_ims_mmtel_package string com.sec.imsservice >/dev/null 2>&1 || true
        $G /system/bin/cmd overlay enable --user 0 com.android.shell:OneOSImsMmtel >/dev/null 2>&1 || true
        PP=$($G /system/bin/pidof com.android.phone 2>/dev/null | awk '{print $1}')
        if [ -n "$PP" ] && [ "$(active_calls)" = 0 ]; then
            $G /system/bin/kill -TERM "$PP" 2>/dev/null || true
            sleep 8
            for s in 0 1; do
                $G /system/bin/cmd phone ims set-ims-service -s "$s" -d -f 0,1 com.sec.imsservice >/dev/null 2>&1 || true
                echo "slot $s bound after phone restart: $(ims_bound "$s")"
            done
        fi
    fi
    ss=$($G /system/bin/getprop gsm.sim.state 2>/dev/null | tr -d '\r')
    for s in 0 1; do
        st=$(echo "$ss" | cut -d, -f$((s + 1)))
        [ "$st" = LOADED ] || continue
        $G /system/bin/am broadcast -a android.intent.action.ISIM_LOADED --ei phone "$s" >/dev/null 2>&1 &&
            echo "ISIM_LOADED broadcast slot $s"
    done
fi

echo "=== call audio slot hint ($(date +%T))"
if run service check android.hardware.audio.core.IModule/default 2>/dev/null | grep -q ': found'; then
    slot=$(run cat /data/oneos_call_slot 2>/dev/null | tr -d '\r\n' || true)
    [ -z "$slot" ] && slot=1
    hex=$(printf '0x%02x' "$slot")
    run service call android.hardware.audio.core.IModule/default 34 \
        i32 1 i32 1 i32 4 s16 g_call_sim_slot i32 1 i32 1 i32 4 s16 "$hex" i32 0 2>/dev/null | head -1 ||
        echo "HAL g_call_sim_slot send skipped"
    echo "idle VSID hint: $hex (last slot file: ${slot:-?})"
fi

if [ "$(active_calls)" = 0 ]; then
    echo "=== refresh InCall / phone UI ($(date +%T))"
    run am force-stop com.google.android.dialer 2>/dev/null || true
    run am force-stop com.google.android.telecomui 2>/dev/null || true
    sleep 1
    PP=$(run pidof com.android.phone 2>/dev/null | awk '{print $1}')
    [ -n "$PP" ] && run kill -HUP "$PP" 2>/dev/null || true
fi
echo "repair-guest-telephony: done; mVoiceRegState=$(run dumpsys telephony.registry 2>/dev/null | sed -n 's/.*mVoiceRegState=\([0-9]*\).*/\1/p' | head -1)"
