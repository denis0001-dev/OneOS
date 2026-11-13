#!/system/bin/sh
# Hot-fix guest KernelSU ksud (module install customize.sh needs /data/adb/ksud).
# No guest soft reboot or return to One UI. Run as root on the phone, or from
# oneos_switch / adb while a session stage exists.
set -eu
STAGE=${STAGE:-/data/local/tmp/oneos}
KW="$STAGE/data/oneos_ksu"
GADB="$STAGE/data/oneos_root/adb"
RADB="$STAGE/rootfs/data/adb"
for c in /data/adb/ksu/bin/busybox /data/adb/ap/bin/busybox /data/adb/magisk/busybox; do
    [ -x "$c" ] && BB=$c && break
done
[ -n "${BB:-}" ] || BB=$(command -v busybox 2>/dev/null || true)
[ -f "$KW/ksud.guest" ] && [ -s "$KW/ksud.guest" ] || {
    echo "reload-guest-ksud: $KW/ksud.guest missing; run Prepare or switch once with KernelSU" >&2
    exit 1
}
install_wrapper() {
    dest=$1
    mkdir -p "$(dirname "$dest")"
    cp -f "$KW/ksud" "$dest" && chmod 755 "$dest"
}
# Same wrapper as guest_prepare.sh (keep in sync).
cat > "$KW/ksud" <<'KSUDWRAP'
#!/system/bin/sh
# OneOS: KernelSU's ksud inside a guest system. Commands that drive init would
# act on the phone's own init (One UI's), so they never run from here.
case "$1" in
    soft-reboot)
        if [ -f /data/adb/oneos/.softreboot_install ] ||
           [ -f /data/local/tmp/oneos/tmp/softreboot.installing ]; then
            echo "OneOS: soft reboot skipped during module install (this restart applies changes)"
            exit 0
        fi
        setprop oneos.guest.powerctl "ksud:soft-reboot"
        echo "OneOS: soft reboot of this system requested"
        exit 0 ;;
    post-fs-data|services|boot-completed|late-load|insmod|boot-patch|boot-patch-v2|boot-restore)
        echo "OneOS: 'ksud $1' acts on One UI's boot; not run inside this system" >&2
        exit 1 ;;
    debug)
        if [ "$2" = su ]; then
            shift 2
            n=$#
            for a in "$@"; do case "$a" in -g|--global-mnt) ;; *) set -- "$@" "$a" ;; esac; done
            shift $n
            set -- debug su "$@"
        fi ;;
esac
for _k in /data/oneos_ksu/ksud.guest /data/local/tmp/oneos/data/oneos_ksu/ksud.guest; do
    if [ -x "$_k" ] && [ -s "$_k" ]; then exec "$_k" "$@"; fi
done
echo "OneOS: ksud.guest missing in this system" >&2
exit 127
KSUDWRAP
chmod 755 "$KW/ksud"
[ -d "$GADB" ] && install_wrapper "$GADB/ksud"
[ -d "$RADB" ] && install_wrapper "$RADB/ksud"
mkdir -p "$STAGE/rootfs/data/oneos_ksu"
cp -f "$KW/ksud.guest" "$STAGE/rootfs/data/oneos_ksu/ksud.guest" 2>/dev/null && chmod 755 "$STAGE/rootfs/data/oneos_ksu/ksud.guest" || true
# Live guest: patch /data/adb/ksud in system_server's mount namespace.
PID=$(pidof system_server 2>/dev/null | awk '{print $1}')
if [ -n "$PID" ] && [ -n "$BB" ]; then
    case "$(readlink "/proc/$PID/root" 2>/dev/null)" in
        "$STAGE/rootfs"|"$STAGE/rootfs"/*)
            TMP=/data/local/tmp/oneos-ksud-wrap.$$
            cp -f "$KW/ksud" "$TMP" && chmod 755 "$TMP"
            if "$BB" nsenter -t "$PID" -m cp -f "$TMP" /data/adb/ksud &&
               "$BB" nsenter -t "$PID" -m chmod 755 /data/adb/ksud; then
                echo "reload-guest-ksud: /data/adb/ksud updated in guest (system_server)"
            else
                echo "reload-guest-ksud: could not write /data/adb/ksud in guest namespace" >&2
            fi
            rm -f "$TMP"
            ;;
        *)
            echo "reload-guest-ksud: system_server is One UI; stage adb paths updated only"
            ;;
    esac
fi
# KernelSU manager bundled lib (install path uses /data/adb/ksud; keep lib in sync).
MPID=$(pidof me.weishu.kernelsu 2>/dev/null | awk '{print $1}')
if [ -z "$MPID" ]; then
    MPID=$(pidof com.rifsxd.ksunext 2>/dev/null | awk '{print $1}')
fi
if [ -n "$MPID" ] && [ -n "$BB" ]; then
    APK=$("$BB" nsenter -t "$MPID" -m pm path me.weishu.kernelsu 2>/dev/null | sed -n 's/package://p')
    [ -z "$APK" ] && APK=$("$BB" nsenter -t "$MPID" -m pm path com.rifsxd.ksunext 2>/dev/null | sed -n 's/package://p')
    if [ -n "$APK" ]; then
        LIB=${APK%/base.apk}/lib/arm64/libksud.so
        if "$BB" nsenter -t "$MPID" -m test -f "$LIB" 2>/dev/null; then
            if "$BB" nsenter -t "$MPID" -m sh -c "cat > '$LIB' && chmod 755 '$LIB'" < "$KW/ksud"; then
                echo "reload-guest-ksud: manager libksud.so replaced with wrapper"
            fi
        fi
    fi
fi
echo "reload-guest-ksud: done (retry module install in the manager)"
