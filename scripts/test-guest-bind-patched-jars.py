#!/usr/bin/env python3
"""guest_bind_patched_jars.sh is invoked from guest_prepare and guest_softreboot."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIND = ROOT / "switcher/assets/guest_bind_patched_jars.sh"
PREPARE = ROOT / "switcher/assets/guest_prepare.sh"
SWITCH = ROOT / "switcher/assets/oneos_switch.sh"
ROOTSH = ROOT / "app-android/app/src/full/assets/root/oneos_root.sh"


def main() -> None:
    text = BIND.read_text()
    assert "services_patched.jar" in text
    assert "framework_patched.jar" in text
    assert "framework-telecom_patched.jar" in text
    prep = PREPARE.read_text()
    assert "guest_bind_patched_jars.sh" in prep
    assert prep.index("guest_bind_patched_jars.sh") < prep.index("soft reboot: starting the guest again")
    assert "CROSS_WINDOW_BLUR_SUPPORTED" in SWITCH.read_text()
    assert "guest_bind_patched_jars.sh" in ROOTSH.read_text()
    print("PASS: guest_bind_patched_jars wiring")


if __name__ == "__main__":
    main()
