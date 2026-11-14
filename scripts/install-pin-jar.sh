#!/bin/sh
# Keep a patched services.jar in the guest's own data so a fixes update cannot
# defeat ColorOS-only transport fixes (AIDL fingerprint). A release update replaces
# $STAGE/services_patched.jar; the guest screen lock in /data/system/oneos_guest_lock*
# stays, but ColorOS may lose AIDL fingerprint forcing without this kept copy.
#
# The copy is stamped with the sha256 of the stage jar it was built from.
# guest_prepare.sh binds it only while that stamp matches the current stage jar.
#
# Usage: [APKTOOL=apktool] scripts/install-pin-jar.sh [--jar <services_patched.jar>] [--no-push] [--pixel]
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
STAGE=/data/local/tmp/oneos
PIN_DIR="$STAGE/data/local/tmp/oneos_pin"
SERIAL=${ANDROID_SERIAL:-}
ADB=${ADB:-adb}
jar=
push=1
pixel=

while [ $# -gt 0 ]; do
    case "$1" in
        --jar) [ $# -ge 2 ] || { echo "usage: $0 [--jar <services_patched.jar>] [--no-push] [--pixel]" >&2; exit 2; }; jar=$2; shift 2 ;;
        --no-push) push=0; shift ;;
        --pixel) pixel=1; shift ;;
        -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "usage: $0 [--jar <services_patched.jar>] [--no-push] [--pixel]" >&2; exit 2 ;;
    esac
done

adb_() { if [ -n "$SERIAL" ]; then "$ADB" -s "$SERIAL" "$@"; else "$ADB" "$@"; fi; }
su_() { adb_ shell "su -c '$*'"; }

mkdir -p "$root/out"
if [ -z "$jar" ]; then
    jar="$root/out/services_patched_stage.jar"
    echo "pulling $STAGE/services_patched.jar" >&2
    adb_ exec-out su -c "cat $STAGE/services_patched.jar" > "$jar"
fi
[ -s "$jar" ] || { echo "no jar: $jar" >&2; exit 1; }

base=$(sha256sum "$jar" | awk '{print $1}')
out="$root/out/services_pin.jar"
APKTOOL=${APKTOOL:-apktool}
if [ -n "$pixel" ]; then
    echo "patching $jar ($base): guest-local lock (Pixel UI)" >&2
    APKTOOL="$APKTOOL" sh "$root/scripts/patch-built-jar.sh" "$jar" \
        "$root/switcher/patches/guest_local_lock.py" "$out"
else
    echo "patching $jar ($base): ColorOS AIDL fingerprint transport" >&2
    APKTOOL="$APKTOOL" sh "$root/scripts/patch-built-jar.sh" "$jar" \
        "$root/switcher/patches/guest_force_aidl_fingerprint.py" "$out"
fi

unzip -p "$out" classes2.dex | grep -aq OneOSGuestLock ||
    { echo "the rebuilt jar has no guest lock helper; refusing to stage it" >&2; exit 1; }
if [ -z "$pixel" ]; then
    unzip -p "$out" classes.dex | grep -aq 'guest_force_aidl_fingerprint' ||
        unzip -p "$out" classes2.dex | grep -aq IFingerprintAidl;
fi
printf '%s\n' "$base" > "$root/out/services_pin.base.sha256"

[ "$push" = 1 ] || exit 0

[ "$(su_ id -u | tr -d '\r')" = 0 ] || { echo "no root on the phone (su -c id failed)" >&2; exit 1; }
adb_ push "$out" /data/local/tmp/services_pin.jar >/dev/null
adb_ push "$root/out/services_pin.base.sha256" /data/local/tmp/services_pin.base.sha256 >/dev/null
su_ "mkdir -p $PIN_DIR &&
     mv -f /data/local/tmp/services_pin.jar $PIN_DIR/services_patched.jar &&
     mv -f /data/local/tmp/services_pin.base.sha256 $PIN_DIR/base.sha256 &&
     chown root:root $PIN_DIR/services_patched.jar $PIN_DIR/base.sha256 &&
     chmod 644 $PIN_DIR/services_patched.jar $PIN_DIR/base.sha256 &&
     chcon -h u:object_r:system_file:s0 $PIN_DIR/services_patched.jar &&
     chcon -h u:object_r:system_data_file:s0 $PIN_DIR/base.sha256" >/dev/null
echo "kept $PIN_DIR/services_patched.jar (for $base); guest_prepare.sh binds it on the next switch" >&2
