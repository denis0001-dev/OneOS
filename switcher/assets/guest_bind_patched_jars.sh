#!/system/bin/sh
# Re-bind guarded / patched jars onto the guest tree.
# Host (guest_prepare, guest_softreboot): $STAGE/rootfs/...
# After pivot in guest_start (GUEST_INNER=1): /system/... and /apex/...
set -eu
STAGE=${STAGE:-/data/local/tmp/oneos}
ROOTFS=$STAGE/rootfs
for c in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox \
          /data/oneos_bin/busybox; do
    [ -x "$c" ] && BB=$c && break
done
[ -n "${BB:-}" ] || BB=$(command -v busybox 2>/dev/null || true)
[ -n "$BB" ] || { echo "guest_bind_patched_jars: no busybox"; exit 1; }

inner=0
case "${GUEST_INNER:-}" in 1|yes|true) inner=1 ;; esac
if [ "$inner" = 0 ] && [ ! -d "$ROOTFS/system/framework" ] && [ -d /system/framework ]; then
    inner=1
fi

bind_one() {
    src=$1 dst=$2 label=$3
    [ -f "$src" ] || return 0
    [ -f "$dst" ] || [ -L "$dst" ] || return 0
    [ ! -L "$(dirname "$dst")" ] || return 0
    $BB umount -l "$dst" 2>/dev/null || true
    $BB mount --bind "$src" "$dst" && echo "guest_bind_patched_jars: $label"
}

if [ "$inner" = 1 ]; then
    SVC_DST=/system/framework/services.jar
    FW_DST=/system/framework/framework.jar
    SF_DST=/system/bin/surfaceflinger
    TEL_DST=/system/framework/telephony-common.jar
    APEX_ROOT=/apex
    echo "=== guest_bind_patched_jars (guest root) $(date +%T)"
else
    [ -d "$ROOTFS/system/framework" ] || { echo "guest_bind_patched_jars: no $ROOTFS"; exit 1; }
    SVC_DST=$ROOTFS/system/framework/services.jar
    FW_DST=$ROOTFS/system/framework/framework.jar
    SF_DST=$ROOTFS/system/bin/surfaceflinger
    TEL_DST=$ROOTFS/system/framework/telephony-common.jar
    APEX_ROOT=$ROOTFS/apex
    echo "=== guest_bind_patched_jars (host) $(date +%T)"
fi

bind_one "$STAGE/services_patched.jar" "$SVC_DST" \
    "services_patched.jar -> $SVC_DST"
if [ -f "$STAGE/services_patched.jar" ]; then
    if [ "$(stat -c %d:%i "$SVC_DST" 2>/dev/null)" != \
         "$(stat -c %d:%i "$STAGE/services_patched.jar")" ]; then
        echo "guest_bind_patched_jars: ERROR services.jar not the guarded build"
        exit 1
    fi
fi
bind_one "$STAGE/framework_patched.jar" "$FW_DST" \
    "framework_patched.jar -> $FW_DST"
if [ -f "$STAGE/surfaceflinger_patched" ] && [ "${ONEOS_STOCK_SF:-0}" != "1" ]; then
    chmod 755 "$STAGE/surfaceflinger_patched" 2>/dev/null || true
    bind_one "$STAGE/surfaceflinger_patched" "$SF_DST" \
        "surfaceflinger_patched -> $SF_DST"
fi
bind_one "$STAGE/telephony-common_patched.jar" "$TEL_DST" \
    "telephony-common_patched.jar -> $TEL_DST"
FTJ_SRC="$STAGE/framework-telecom_patched.jar"
[ -f "$FTJ_SRC" ] || FTJ_SRC=/data/local/tmp/framework-telecom_patched.jar
if [ -f "$FTJ_SRC" ]; then
    for apex in com.android.telephonycore com.android.telephony; do
        for vdir in "$APEX_ROOT/$apex" "$APEX_ROOT/$apex"@*; do
            [ -d "$vdir" ] || continue
            FTJ="$vdir/javalib/framework-telecom.jar"
            [ -f "$FTJ" ] && [ ! -L "$FTJ" ] || continue
            bind_one "$FTJ_SRC" "$FTJ" "framework-telecom_patched.jar -> $FTJ"
        done
    done
fi
echo "guest_bind_patched_jars: done"
