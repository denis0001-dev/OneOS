"""Pixel framework: accept Samsung vendor audio usages from the shared QTI HAL.

Guest audioserver loads audio product strategies through Samsung's audio HAL.
Strategies can carry vendor usages (e.g. 1005). AOSP AudioAttributes$Builder.setUsage
throws IllegalArgumentException on the default arm of its packed-switch, and
system_server dies starting AudioService (S25 Ultra pixel9-sultra, 2026-11-10).

For usages >= 1000 (vendor/OEM range), jump into the same path as known usages.

Usage: guest_audio_vendor_usage.py <apktool decoded framework.jar dir>
Prints smali_* directories changed, one per line; nothing when already patched or missing.
"""
import os
import re
import sys

BUILDER = os.path.join("android", "media", "AudioAttributes$Builder.smali")
MARK = "oneos_vendor_audio_usage"
VENDOR_MIN = 1000


def fail(msg):
    sys.exit("guest_audio_vendor_usage: " + msg)


def patch_set_usage(body):
    if MARK in body:
        return None
    m = re.search(
        r"^\.method public (?:static )?(?:\w+ )*setUsage\(I\)Landroid/media/AudioAttributes\$Builder;\n(.*?)^\.end method\n",
        body,
        re.M | re.S,
    )
    if not m:
        return None
    inner = m.group(1)
    if inner.count('"Invalid usage "') != 1:
        fail("setUsage: expected one Invalid usage throw")
    sw = re.search(r"^(\s*)packed-switch p1, :pswitch_data_0\n", inner, re.M)
    if not sw:
        fail("setUsage: expected packed-switch on p1")
    if not re.search(r"^\s*:pswitch_0\n", inner, re.M):
        fail("setUsage: expected :pswitch_0 label")
    ind = sw.group(1)
    gate = (
        f"{ind}# OneOS ({MARK}): Samsung HAL product strategies use vendor usages.\n"
        f"{ind}const/16 v0, 0x{VENDOR_MIN:x}\n"
        f"{ind}if-lt p1, v0, :{MARK}\n"
        f"{ind}goto :pswitch_0\n"
        f"{ind}:{MARK}\n"
    )
    inner = inner[: sw.start()] + gate + inner[sw.start() :]
    return body[: m.start(1)] + inner + body[m.end(1) :]


def main():
    if len(sys.argv) != 2:
        fail(__doc__)
    root = sys.argv[1]
    changed = []
    for d in sorted(os.listdir(root)):
        if not (d == "smali" or d.startswith("smali_")):
            continue
        path = os.path.join(root, d, BUILDER)
        if not os.path.isfile(path):
            continue
        text = open(path, encoding="utf-8").read()
        new = patch_set_usage(text)
        if new is not None:
            open(path, "w", encoding="utf-8").write(new)
            changed.append(d)
            print(
                f"guest_audio_vendor_usage: {d}/AudioAttributes$Builder.smali: usages >= {VENDOR_MIN} accepted",
                file=sys.stderr,
            )
        elif MARK in text:
            changed.append(d)
    for d in changed:
        print(d)
    if not changed:
        fail("AudioAttributes$Builder.smali setUsage not found")


if __name__ == "__main__":
    main()