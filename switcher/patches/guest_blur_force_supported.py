"""Treat cross-window blur as supported in WindowManager (Pixel/AOSP guests).

CrossWindowBlurListeners.CROSS_WINDOW_BLUR_SUPPORTED is set once at class init
from ro.surface_flinger.supports_background_blur. On a Samsung host that prop is
often unset or 0 until guest_props runs; after a soft reboot restore-props can
undo the override before the new system_server starts, so BlurController keeps
mBlurEnabled false even with disable_window_blurs=0. guest_props.sh still sets
the prop; this removes only the static gate in updateBlurEnabled() (same dex as
guest_blur_no_thermal.py). Developer options, power save and tunnel mode still
apply.

Usage: guest_blur_force_supported.py <smali root dir>
Prints the smali_* directory changed. Exits with a message unless exactly one
matching check is found in BlurController.updateBlurEnabled().
"""
import os
import re
import sys

CLASS = re.compile(r"^\.class (?:public |final )*Lcom/android/server/wm/BlurController;$")
METHOD = re.compile(r"^\.method (?:public |private |final )*updateBlurEnabled\(\)V$")
SGET = re.compile(
    r"^\s*sget-boolean (v\d+|p\d+), Landroid/view/CrossWindowBlurListeners;->CROSS_WINDOW_BLUR_SUPPORTED:Z$"
)
IF_EQZ = re.compile(r"^\s*if-eqz (v\d+|p\d+), :cond_\w+$")


def patch_blur_controller(path):
    lines = open(path).read().split("\n")
    heads = [k for k, l in enumerate(lines) if METHOD.match(l)]
    if len(heads) != 1:
        sys.exit("guest_blur_force_supported: updateBlurEnabled() not found exactly once")
    end = next(k for k in range(heads[0], len(lines)) if lines[k] == ".end method")
    hits = []
    for k in range(heads[0], end):
        m = SGET.match(lines[k])
        if not m:
            continue
        reg = m.group(1)
        j = k + 1
        while j < end and lines[j].strip() == "":
            j += 1
        if j < end and IF_EQZ.match(lines[j]) and IF_EQZ.match(lines[j]).group(1) == reg:
            hits.append((k, j))
    if len(hits) != 1:
        sys.exit(
            f"guest_blur_force_supported: CROSS_WINDOW_BLUR_SUPPORTED gate found {len(hits)} times"
        )
    k, j = hits[0]
    del lines[k : j + 1]
    open(path, "w").write("\n".join(lines))
    return os.path.relpath(path, os.path.dirname(os.path.dirname(path))).split(os.sep)[0]


def main(root):
    found = []
    for dirpath, _, files in os.walk(root):
        if "BlurController.smali" not in files:
            continue
        path = os.path.join(dirpath, "BlurController.smali")
        if CLASS.match(open(path).readline().strip()):
            found.append(path)
    if len(found) != 1:
        sys.exit(f"guest_blur_force_supported: BlurController found {len(found)} times")
    print(patch_blur_controller(found[0]))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
