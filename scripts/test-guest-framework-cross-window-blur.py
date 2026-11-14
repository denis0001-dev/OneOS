#!/usr/bin/env python3
"""guest_framework_cross_window_blur.py forces CROSS_WINDOW_BLUR_SUPPORTED in <clinit>."""
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCHER = ROOT / "switcher/patches/guest_framework_cross_window_blur.py"
FW = ROOT / "out/overlays_pixel_komodo_r16/framework_patched.jar"


class GuestFrameworkCrossWindowBlurTest(unittest.TestCase):
    def test_patches_clinit(self):
        if not FW.is_file():
            self.skipTest("framework_patched.jar not in out/")
        import zipfile

        with tempfile.TemporaryDirectory() as tmp:
            src = Path(tmp) / "src"
            import os

            apk = os.environ.get("APKTOOL", "apktool")
            subprocess.run(
                [apk, "d", "-q", "-f", "-r", "-o", str(src), str(FW)],
                check=True,
            )
            rel = (
                subprocess.run(
                    [sys.executable, "-I", str(PATCHER), str(src)],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                .stdout.strip()
            )
            text = (src / rel / "android/view/CrossWindowBlurListeners.smali").read_text()
            self.assertIn("OneOS: treat cross-window blur as supported", text)
            self.assertNotIn("SystemProperties;->getBoolean", text.split("<clinit>")[1].split(".end method")[0])


if __name__ == "__main__":
    unittest.main()
