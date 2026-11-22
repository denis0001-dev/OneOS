#!/usr/bin/env python3
"""verify-return tolerates pruned KSU live tables when allowlist.saved is intact."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = (ROOT / "switcher/assets/guest_runtime.sh").read_text()
VERIFY = RUNTIME.split("verify-return)", 1)[1].split("\nesac", 1)[0]


class VerifyReturnRestoreTest(unittest.TestCase):
    def test_allowlist_checked_before_live_root_cmp(self):
        allow = VERIFY.find("sha256sum -c \"$B/allowlist\"")
        audit = VERIFY.find("--host-audit")
        root_cmp = VERIFY.find('cmp -s "$B/root"')
        self.assertGreater(allow, 0)
        self.assertGreater(audit, allow)
        self.assertGreater(root_cmp, audit)

    def test_drift_restores_from_switch_baseline(self):
        self.assertIn("restore_host_root_from_baseline", RUNTIME)
        self.assertIn("restore_packages_from_baseline", RUNTIME)
        self.assertIn("capture_grant_packages", RUNTIME)
        self.assertIn("grant-packages.txt", RUNTIME)
        self.assertIn("sync_host_root_from_baseline", RUNTIME)
        self.assertIn("release_allowlist_protection", RUNTIME)
        self.assertIn("restore-host-grants)", RUNTIME)
        self.assertIn("live grant table drifted", VERIFY)
        self.assertIn("persisted allowlist unchanged", VERIFY)
        self.assertIn("allowlist.protected", VERIFY)
        self.assertIn("--host-grant-core", RUNTIME)

    def test_verify_always_syncs_before_allowlist_release(self):
        sync = VERIFY.find("sync_host_root_from_baseline")
        release = VERIFY.find("release_allowlist_protection")
        self.assertGreater(sync, 0)
        self.assertGreater(release, sync)


if __name__ == "__main__":
    unittest.main()