"""Patch host ksud so module commands use the guest mount namespace.

KernelSU's ksud enters mount namespace via a /proc/.../ns/mnt path baked into
the binary. Inside a guest, pid 1 is One UI's init. OneOS rewrites /proc/ to
/data/ and stages data/1/ns/mnt -> /proc/self/ns/mnt (guest_prepare.sh).

Usage: guest_ksud_mount_namespace.py <ksud-in> <ksud-out>
"""
from __future__ import annotations

import os
import shutil
import sys

PROC9 = bytes.fromhex("062f70726f632fc007")
DATA9 = bytes.fromhex("062f646174612fc007")
NEEDLE = b"/ns/mnt"


def patch_bytes(data: bytearray) -> None:
    pos = 0
    hits: list[int] = []
    while True:
        i = data.find(NEEDLE, pos)
        if i < 0:
            break
        hits.append(i)
        pos = i + 1
    if len(hits) != 1:
        sys.exit(f"guest_ksud_mount_namespace: /ns/mnt found {len(hits)} times, expected 1")
    ko = hits[0]
    if ko < 9:
        sys.exit("guest_ksud_mount_namespace: /ns/mnt offset too small")
    before = bytes(data[ko - 9 : ko])
    if before == DATA9:
        return
    if before != PROC9:
        sys.exit(f"guest_ksud_mount_namespace: expected /proc/ prefix, got {before.hex()}")
    data[ko - 8 : ko - 4] = b"data"


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(f"usage: {sys.argv[0]} <ksud-in> <ksud-out>")
    src, dst = sys.argv[1], sys.argv[2]
    tmp = dst + ".tmp"
    shutil.copyfile(src, tmp)
    data = bytearray(open(tmp, "rb").read())
    patch_bytes(data)
    with open(tmp, "wb") as f:
        f.write(data)
    os.chmod(tmp, 0o755)
    os.replace(tmp, dst)


if __name__ == "__main__":
    main()
