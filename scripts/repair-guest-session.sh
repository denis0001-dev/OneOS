#!/system/bin/sh
# One-off: restart guest UI activator, audio, and host cutout overlays (running session).
set -eu
STAGE=/data/local/tmp/oneos
BB=$(which busybox)
PID=$(pidof system_server | awk '{print $1}')
[ -n "$PID" ] || { echo "no guest system_server"; exit 1; }
run() { "$BB" nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh "$@"; }

echo "=== audio: restart host HAL, then guest audioserver"
setprop ctl.restart vendor.audio-hal-aidl
n=0
while [ $n -lt 30 ] && ! run service check android.hardware.audio.core.IModule/default 2>/dev/null | grep -q ': found'; do
    n=$((n + 1))
    sleep 0.2
done
run pkill -9 audioserver 2>/dev/null || true
sleep 1
run /system/bin/audioserver >/dev/null 2>&1 &
echo "audioserver pid $(run pidof audioserver 2>/dev/null | awk '{print $1}')"
n=0
while [ $n -lt 40 ] && ! run service check media.audio_policy 2>/dev/null | grep -q ': found'; do
    n=$((n + 1))
    sleep 0.5
done
echo "media.audio_policy: $(run service check media.audio_policy 2>/dev/null | head -1)"

OVERLAY_SH="$STAGE/apply-host-cutout-overlays.sh"
[ -f "$OVERLAY_SH" ] || OVERLAY_SH=/data/local/tmp/apply-host-cutout-overlays.sh
if [ -f "$OVERLAY_SH" ]; then
    echo "=== overlays"
    sh "$OVERLAY_SH"
fi
echo "=== systemui"
run pkill -TERM com.android.systemui 2>/dev/null || true
sleep 3

echo "=== UI activator (background)"
pkill -f '>/data/local/tmp/ui_activator.log' 2>/dev/null || true
: > /data/local/tmp/ui_activator.log
GUEST_OPLUS=0; GUEST_MIUI=0; GUEST_VIVO=0
[ -f "$STAGE/rootfs/system/framework/oplus-services.jar" ] && GUEST_OPLUS=1
[ -f "$STAGE/rootfs/system_ext/framework/miui-services.jar" ] && GUEST_MIUI=1
[ -f "$STAGE/rootfs/system/framework/vivo-services.jar" ] && GUEST_VIVO=1
GUEST_AOSP_SYSUI=1
[ "$GUEST_OPLUS" = 1 ] && [ ! -f "$STAGE/rootfs/system/framework/org.lineageos.platform.jar" ] && GUEST_AOSP_SYSUI=0
[ "$GUEST_MIUI" = 1 ] && GUEST_AOSP_SYSUI=0
GUEST_FOLD_FORM=0; GUEST_BLUR=1; GUEST_POSTURE_LIVE=0; GUEST_OXYGEN=0; WIFI_VERBOSE=0
GUEST_DENSITY=auto
export STAGE BB GUEST_OPLUS GUEST_MIUI GUEST_VIVO GUEST_AOSP_SYSUI GUEST_FOLD_FORM GUEST_BLUR GUEST_POSTURE_LIVE GUEST_OXYGEN WIFI_VERBOSE GUEST_DENSITY
"$BB" sed -n '2059,3401p' "$STAGE/oneos_switch.sh" | "$BB" sh </dev/null >>/data/local/tmp/ui_activator.log 2>&1 &
echo "activator pid $! (log: /data/local/tmp/ui_activator.log)"
