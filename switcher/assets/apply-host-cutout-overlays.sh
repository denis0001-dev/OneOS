#!/system/bin/sh
# One-off: apply host cutout / status bar / corner overlays in the running guest.
set -eu
STAGE=/data/local/tmp/oneos
PID=$(pidof system_server | awk '{print $1}')
[ -n "$PID" ] || exit 1
BB=$(which busybox 2>/dev/null)
[ -n "$BB" ] || BB=/data/adb/ksu/bin/busybox
[ -x "$BB" ] || BB=nsenter
[ -f "$STAGE/host_statusbar" ] || exit 2
HSB=$(sed -n 's/^height=//p' "$STAGE/host_statusbar" | head -n 1)
HRC=$(sed -n 's/^radius=//p' "$STAGE/host_statusbar" | head -n 1)
HRP=$(sed -n 's/^rect_px=//p' "$STAGE/host_statusbar" | head -n 1)
HHP=$(sed -n 's/^hole_px=//p' "$STAGE/host_statusbar" | head -n 1)
run() {
    if [ "$BB" = nsenter ]; then nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh "$@"
    else "$BB" nsenter -t "$PID" -m /system/bin/sh /data/oneos_genv.sh "$@"; fi
}
run /system/bin/cmd overlay fabricate --target android --name OneOSCutout \
    android:string/config_mainBuiltInDisplayCutout string "$HHP"
run /system/bin/cmd overlay fabricate --target android --name OneOSCutoutRect \
    android:string/config_mainBuiltInDisplayCutoutRectApproximation string "$HRP"
run /system/bin/env CLASSPATH=/data/oneos_overlay_dimen.dex /system/bin/app_process /system/bin \
    OneOSOverlayDimen OneOSStatusBarHeight android \
    "android:dimen/status_bar_height_default=$HSB" "android:dimen/status_bar_height_portrait=$HSB"
run /system/bin/env CLASSPATH=/data/oneos_overlay_dimen.dex /system/bin/app_process /system/bin \
    OneOSOverlayDimen OneOSCornerRadius android \
    "android:dimen/rounded_corner_radius=$HRC" \
    "android:dimen/rounded_corner_radius_top=$HRC" \
    "android:dimen/rounded_corner_radius_bottom=$HRC"
PAD=$(awk -v r="$HRC" -v h="$HSB" 'BEGIN { y = h / 3; p = 0; if (y < r) p = r - sqrt(r * r - (r - y) * (r - y)); printf "%d", p + 0.5 }')
if [ "${PAD:-0}" -gt 24 ]; then
    run /system/bin/env CLASSPATH=/data/oneos_overlay_dimen.dex /system/bin/app_process /system/bin \
        OneOSOverlayDimen OneOSCornerPadding com.android.systemui \
        "com.android.systemui:dimen/rounded_corner_content_padding=$PAD" \
        "com.android.systemui:dimen/ongoing_appops_dot_min_padding=$PAD"
fi
for o in OneOSCutout OneOSCutoutRect OneOSStatusBarHeight OneOSCornerRadius OneOSCornerPadding; do
    run /system/bin/cmd overlay enable --user 0 "com.android.shell:$o" 2>/dev/null || true
done
echo "applied height=$HSB radius=$HRC padding=$PAD"
run /system/bin/cmd overlay list --user 0 | grep -E 'OneOS(Cutout|StatusBar|Corner)' || true
