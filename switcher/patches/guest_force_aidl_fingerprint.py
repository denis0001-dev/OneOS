"""Make the guest framework open Samsung's AIDL v3 fingerprint HAL.

Samsung's fingerprint service on the host declares only
android.hardware.biometrics.fingerprint.IFingerprint/default (AIDL v3); there
is no HIDL 2.1 IBiometricsFingerprint service. When
FingerprintSensorConfigurations#getResetLockoutRequiresHardwareAuthToken is
false, initSensors / getProviders can prefer a HIDL-to-AIDL adapter and fail to
open the sensor ("Fingerprint HAL not available", NPE in
FingerprintUpdateActiveUserClient). Force the flag true so the native AIDL path
is used.

Enrollment metadata is mirrored from One UI in guest_prepare.sh; this patch only
changes which adapter reaches the same host HAL. Tested on Pixel (komodo)
services.jar and ColorOS 17.

Usage: guest_force_aidl_fingerprint.py <smali root dir>
Prints the smali_* directories (dex files) it changed, one per line.
"""
import os
import re
import sys

CFG = "Landroid/hardware/fingerprint/FingerprintSensorConfigurations;"
INVOKE = (
    f"    invoke-virtual {{p1}}, {CFG}->getResetLockoutRequiresHardwareAuthToken()Z"
)
MARKER = "OneOS: Samsung's HAL is AIDL v3 only"
REL = os.path.join("com", "android", "server", "biometrics", "sensors",
                   "fingerprint", "FingerprintService.smali")
PATTERN = re.compile(
    re.escape(INVOKE) + r"\n\n    move-result (\w+)\n",
    re.MULTILINE,
)


def main(root):
    hits = []
    for d in sorted(os.listdir(root)):
        if not d.startswith("smali"):
            continue
        path = os.path.join(root, d, REL)
        if os.path.isfile(path):
            hits.append(path)
    if len(hits) != 1:
        sys.exit(f"expected exactly one {REL}, found {len(hits)}")
    path = hits[0]
    src = open(path).read()
    if MARKER in src:
        print(os.path.relpath(path, root).split(os.sep)[0])
        return
    m = PATTERN.search(src)
    if not m:
        sys.exit(f"{REL}: getResetLockoutRequiresHardwareAuthToken read not found")
    reg = m.group(1)
    repl = (
        f"    # {MARKER}; initSensors/getProviders use native AIDL sensors.\n"
        f"    const/4 {reg}, 0x1\n"
    )
    out = PATTERN.sub(repl, src, count=1)
    open(path, "w").write(out)
    print("FingerprintService: forced resetLockoutRequiresHardwareAuthToken=true",
          file=sys.stderr)
    print(os.path.relpath(path, root).split(os.sep)[0])


if __name__ == "__main__":
    main(sys.argv[1])
