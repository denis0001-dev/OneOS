"""Force cross-window blur on in the guest when the host never set the RO prop.

BlurController.updateBlurEnabled() gates on
CrossWindowBlurListeners.CROSS_WINDOW_BLUR_SUPPORTED, which is initialized from
ro.surface_flinger.supports_background_blur at framework class load time. On
Samsung hosts the prop is often unset, so WM keeps mBlurEnabled=false even when
guest_props adds the RO prop and disable_window_blurs=0.

This replaces the sget-boolean with const/4 1 in updateBlurEnabled() only.
guest_blur_no_thermal.py still removes the thermal gate when present.

Usage: guest_blur_cross_window.py <smali root dir>
"""
import os
import re
import sys

CLASS = re.compile(
    r"^\.class (?:public |final )*Lcom/android/server/wm/BlurController;$"
)
METHOD = re.compile(r"^\.method (?:public |private |final )*updateBlurEnabled\(\)V$")
SGET = re.compile(
    r"^\s*sget-boolean v\d+, "
    r"Landroid/view/CrossWindowBlurListeners;->CROSS_WINDOW_BLUR_SUPPORTED:Z$"
)


def main(root: str) -> None:
    found = []
    for dirpath, _, files in os.walk(root):
        if "BlurController.smali" in files:
            path = os.path.join(dirpath, "BlurController.smali")
            if CLASS.match(open(path).readline().strip()):
                found.append(path)
    if len(found) != 1:
        sys.exit(f"guest_blur_cross_window: BlurController found {len(found)} times")
    path = found[0]
    lines = open(path).read().split("\n")
    if any("oneos_blur_cross_window" in l for l in lines):
        rel = os.path.relpath(path, root).split(os.sep)[0]
        print(rel)
        return
    heads = [k for k, l in enumerate(lines) if METHOD.match(l)]
    if len(heads) != 1:
        sys.exit("guest_blur_cross_window: updateBlurEnabled() not found exactly once")
    end = next(k for k in range(heads[0], len(lines)) if lines[k] == ".end method")
    hits = [k for k in range(heads[0], end) if SGET.match(lines[k])]
    if len(hits) != 1:
        sys.exit(f"guest_blur_cross_window: CROSS_WINDOW_BLUR_SUPPORTED read found {len(hits)} times")
    k = hits[0]
    indent = re.match(r"^(\s*)", lines[k]).group(1)
    reg = re.match(r"^\s*sget-boolean (v\d+),", lines[k]).group(1)
    lines[k] = f"{indent}# OneOS: cross-window blur on for guest sessions (oneos_blur_cross_window)"
    lines.insert(k + 1, f"{indent}const/4 {reg}, 0x1")
    open(path, "w").write("\n".join(lines))
    print(os.path.relpath(path, root).split(os.sep)[0])


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
