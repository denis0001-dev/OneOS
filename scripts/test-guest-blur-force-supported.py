#!/usr/bin/env python3
"""guest_blur_force_supported.py removes exactly one static blur gate."""
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / ".work/fp-port/decode2/smali_classes3/com/android/server/wm/BlurController.smali"


class GuestBlurForceSupportedTest(unittest.TestCase):
    def test_removes_cross_window_blur_gate(self):
        if not SRC.is_file():
            self.skipTest("decode2 BlurController.smali not in workspace")
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "smali_classes3/com/android/server/wm"
            dest.mkdir(parents=True)
            shutil.copy(SRC, dest / "BlurController.smali")
            out = subprocess.run(
                [sys.executable, "-I", str(ROOT / "switcher/patches/guest_blur_force_supported.py"), tmp],
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertEqual(out.stdout.strip(), "smali_classes3")
            text = (dest / "BlurController.smali").read_text()
            self.assertNotIn("CROSS_WINDOW_BLUR_SUPPORTED", text)
            self.assertIn("updateBlurEnabled()V", text)


if __name__ == "__main__":
    unittest.main()
