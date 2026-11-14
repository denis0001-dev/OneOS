#!/usr/bin/env python3
"""Sanity-check guest_force_aidl_fingerprint.py on a decoded services tree."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCHER = ROOT / "switcher/patches/guest_force_aidl_fingerprint.py"
JAR = Path("/tmp/OneOS/.work/fp-port/services_patched.jar")
DECODE = Path("/tmp/OneOS/.work/fp-port/decode")


def main():
    if not DECODE.is_dir():
        print("decode tree missing; pull services_patched.jar and apktool d first",
              file=sys.stderr)
        sys.exit(2)
    rel = "smali/com/android/server/biometrics/sensors/fingerprint/FingerprintService.smali"
    before = (DECODE / rel).read_text()
    subprocess.check_call([sys.executable, "-I", str(PATCHER), str(DECODE)])
    after = (DECODE / rel).read_text()
    assert "OneOS: Samsung's HAL is AIDL v3 only" in after
    assert "getResetLockoutRequiresHardwareAuthToken" not in after or before.count(
        "getResetLockoutRequiresHardwareAuthToken") >= 2
    print("ok")


if __name__ == "__main__":
    main()
