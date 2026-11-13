"""Pixel framework: accept Samsung vendor audio usages from the shared QTI HAL.

Guest audioserver loads audio product strategies through Samsung's audio HAL.
Strategies can carry vendor usages (e.g. 1005). AOSP AudioAttributes$Builder.setUsage
only allows 0-16 and throws IllegalArgumentException; system_server then dies
starting AudioService (S25 Ultra pixel9-sultra, 2026-11-10).

Usages >= 1000 are treated as valid vendor/OEM values before the stock packed-switch.

Usage: guest_audio_vendor_usage.py <apktool decoded framework.jar dir>
Prints smali_* directories changed, one per line; nothing when already patched or missing.
"""
import os
import re
import sys

MARK = "oneos_vendor_audio_usage"
VENDOR_MIN = 1000
BUILDER = os.path.join("android", "media", "AudioAttributes$Builder.smali")


def fail(msg):
    sys.exit("guest_audio_vendor_usage: " + msg)


def patch_builder(text):
    if MARK in text:
        return None
    m = re.search(
        r"^\.method public (?:\w+ )*setUsage\(I\)Landroid/media/AudioAttributes\$Builder;\n(.*?)^\.end method\n",
        text,
        re.M | re.S,
    )
    if not m:
        return None
    inner = m.group(1)
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
    return text[: m.start(1)] + inner + text[m.end(1) :]


def main():
    if len(sys.argv) != 2:
        fail(__doc__)
    root = sys.argv[1]
    for d in sorted(os.listdir(root)):
        if not d.startswith("smali"):
            continue
        path = os.path.join(root, d, BUILDER)
        if not os.path.isfile(path):
            continue
        text = open(path, encoding="utf-8").read()
        new = patch_builder(text)
        if new is not None:
            open(path, "w", encoding="utf-8").write(new)
            print(
                f"guest_audio_vendor_usage: {d}/AudioAttributes$Builder.smali: setUsage vendor gate",
                file=sys.stderr,
            )
            print(d)
            return
        if MARK in text:
            print(f"guest_audio_vendor_usage: already patched in {d}", file=sys.stderr)
            print(d)
            return
    fail("AudioAttributes$Builder.smali setUsage not found")


if __name__ == "__main__":
    main()
