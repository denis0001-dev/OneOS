#!/system/bin/sh
# Samsung IMS (com.sec.imsservice) in the AOSP guest: bootstrap and maintain.
# Usage:
#   oneos_guest_secims.sh bootstrap <guest system_server pid>
#   oneos_guest_secims.sh maintain_once <guest system_server pid>
set -e
STAGE="${ONEOS_STAGE:-/data/local/tmp/oneos}"
MODE=$1
PID=$2
BB=""
for c in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox; do
    [ -x "$c" ] && { BB=$c; break; }
done
[ -n "$BB" ] || BB=$(which busybox 2>/dev/null)
[ -n "$BB" ] || { echo "secims: no busybox"; exit 1; }

guest_ims_bound() {
    $BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh /system/bin/cmd phone ims get-ims-service -s "$1" -d -f 1 2>&1 |
        tr -d '\r' | tail -1
}

guest_set_ims() {
  $BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh \
    /system/bin/cmd phone ims set-ims-service -s "$1" -d -f 0,1 com.sec.imsservice 2>&1 |
    tr '\n' ' ' | cut -c1-120
}

wait_phone_svc() {
    i=0
    while [ $i -lt 30 ]; do
        $BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh /system/bin/service check phone 2>/dev/null |
            grep -q ': found' && return 0
        i=$((i + 1))
        sleep 2
    done
    return 1
}

send_isim_loaded() {
    ss=$($BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh /system/bin/getprop gsm.sim.state 2>/dev/null | tr -d '\r')
    sent=0
    for s in 0 1; do
        st=$(echo "$ss" | cut -d, -f$((s + 1)))
        [ "$st" = LOADED ] || continue
        $BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh \
            /system/bin/am broadcast -a android.intent.action.ISIM_LOADED --ei phone "$s" >/dev/null 2>&1
        sent=$((sent + 1))
    done
    echo "$sent"
}

slot_ok=0
both_slots_bound() {
    slot_ok=0
    for s in 0 1; do
        b=$(guest_ims_bound "$s")
        [ "$b" = com.sec.imsservice ] && slot_ok=$((slot_ok + 1))
    done
    [ "$slot_ok" -ge 1 ]
}

apply_overrides() {
    SB=0
    wait_phone_svc || echo "secims: phone service not up"
    for s in 0 1; do
        for try in 1 2 3; do
            o=$(guest_set_ims "$s")
            case "$o" in *"find service"*) sleep 5 ;; *) break ;; esac
        done
        b=$(guest_ims_bound "$s")
        echo "secims: slot $s override: $o bound: $b"
        [ "$b" = com.sec.imsservice ] && SB=1
    done
    if [ "$SB" = 0 ] && [ ! -e "$STAGE/data/oneos_sec_ims_phone_restart" ] && [ ! -L "$STAGE/data/oneos_sec_ims_phone_restart" ]; then
        $BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh /system/bin/cmd overlay fabricate \
            --target android --name OneOSImsMmtel android:string/config_ims_mmtel_package string com.sec.imsservice >/dev/null 2>&1
        $BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh /system/bin/cmd overlay enable --user 0 com.android.shell:OneOSImsMmtel >/dev/null 2>&1
        PP=$($BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh /system/bin/pidof com.android.phone 2>/dev/null)
        [ -n "$PP" ] && $BB nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh /system/bin/kill -9 $PP 2>/dev/null
        mkdir "$STAGE/data/oneos_sec_ims_phone_restart" 2>/dev/null || true
        sleep 15
        for s in 0 1; do
            guest_set_ims "$s" >/dev/null 2>&1
            echo "secims: slot $s bound after phone restart: $(guest_ims_bound "$s")"
        done
    fi
    both_slots_bound
}

isim_schedule() {
    [ -e "$STAGE/data/oneos_sec_ims_isim" ] || [ -L "$STAGE/data/oneos_sec_ims_isim" ] && return 0
    mkdir "$STAGE/data/oneos_sec_ims_isim" 2>/dev/null || return 0
    (
        for w in 10 20 40 80 120 180 300; do
            sleep "$w"
            [ -s "$STAGE/guest_mntns" ] || exit 0
            n=$(send_isim_loaded)
            echo "$(date +%T) secims: ISIM_LOADED for $n slot(s) at ${w}s"
        done
    ) </dev/null >>/data/local/tmp/secims_maintain.log 2>&1 &
}

case "$MODE" in
    bootstrap)
        [ -n "$PID" ] || exit 2
        [ -e "$STAGE/data/oneos_sec_ims" ] && [ ! -L "$STAGE/data/oneos_sec_ims" ] || exit 0
        apply_overrides && echo "secims: bootstrap ok" || echo "secims: bootstrap incomplete"
        isim_schedule
        ;;
    maintain_once)
        [ -n "$PID" ] || exit 2
        [ -e "$STAGE/data/oneos_sec_ims" ] && [ ! -L "$STAGE/data/oneos_sec_ims" ] || exit 0
        if both_slots_bound; then
            echo "$(date +%T) secims: maintain ok ($slot_ok slot(s))"
            exit 0
        fi
        echo "$(date +%T) secims: maintain rebind (had $slot_ok bound)"
        apply_overrides || true
        n=$(send_isim_loaded)
        echo "$(date +%T) secims: maintain ISIM_LOADED $n slot(s)"
        ;;
    *)
        echo "usage: $0 bootstrap|maintain_once <system_server pid>"
        exit 2
        ;;
esac
