#!/usr/bin/env python3
"""guest_runtime.sh baseline must not run twice in parallel."""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = (ROOT / 'switcher/assets/guest_runtime.sh').read_text()


def baseline_body():
    body = RUNTIME.split('\nbaseline)\n', 1)[1].split('\nverify-return)\n', 1)[0]
    assert body.rstrip().endswith(';;')
    return body.rstrip()[:-2]


class BaselineLockTest(unittest.TestCase):
    def test_parallel_baseline_refused(self):
        with tempfile.TemporaryDirectory() as d:
            stage = Path(d)
            (stage / 'data/oneos_root').mkdir(parents=True)
            (stage / 'data/oneos_root/enabled').touch()
            (stage / 'guest_root').write_bytes(b'')
            (stage / 'guest_root').chmod(0o755)
            (stage / 'tmp/guest_runtime_baseline').mkdir(parents=True)
            (stage / 'tmp/guest_runtime_baseline/.running').mkdir()
            bb = stage / 'busybox'
            bb.write_text('#!/bin/sh\ncase "$1" in timeout) shift; shift; exec "$@";; mount|umount) exit 0;; *) exec true;; esac\n')
            bb.chmod(0o755)
            adb_bb = stage / 'adb_bb'
            adb_bb.mkdir(parents=True)
            (adb_bb / 'busybox').write_text(bb.read_text())
            (adb_bb / 'busybox').chmod(0o755)
            env = {**os.environ, 'STAGE': str(stage), 'STATE': str(stage / 'data/oneos_root'), 'S': str(stage)}
            # Stub /data/adb paths used in the script.
            script = (
                'export PATH=/bin:/usr/bin\n'
                f'BB={bb}\n'
                'mkdir -p /tmp/fakeadb/ksu/bin\n'
                f'ln -sf {bb} /tmp/fakeadb/ksu/bin/busybox\n'
                + baseline_body().replace('/data/adb/ksu/bin/busybox', '/tmp/fakeadb/ksu/bin/busybox')
            )
            result = subprocess.run(['sh', '-ec', script], env=env, capture_output=True, text=True)
            self.assertEqual(1, result.returncode)
            self.assertIn('baseline already in progress', result.stderr)


if __name__ == '__main__':
    unittest.main()
