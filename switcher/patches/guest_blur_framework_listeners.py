"""Framework: force CrossWindowBlurListeners.CROSS_WINDOW_BLUR_SUPPORTED=true.

Usage: guest_blur_framework_listeners.py <smali root dir>
"""
import os
import re
import sys

CLASS = re.compile(
    r"^\.class .+Landroid/view/CrossWindowBlurListeners;$"
)


def main(root: str) -> None:
    hits = []
    for dirpath, _, files in os.walk(root):
        if "CrossWindowBlurListeners.smali" not in files:
            continue
        path = os.path.join(dirpath, "CrossWindowBlurListeners.smali")
        if not CLASS.match(open(path).readline().strip()):
            continue
        hits.append(path)
    if len(hits) != 1:
        sys.exit(f"guest_blur_framework_listeners: found {len(hits)} CrossWindowBlurListeners")
    path = hits[0]
    lines = open(path).read().split("\n")
    if any("oneos_blur_framework" in l for l in lines):
        print(os.path.relpath(path, root).split(os.sep)[0])
        return
    anchor = None
    for k, l in enumerate(lines):
        if "supports_background_blur" in l and "const-string" in l:
            anchor = k
            break
    if anchor is None:
        sys.exit("guest_blur_framework_listeners: property const-string not found")
    end = anchor
    while end < len(lines) and "CROSS_WINDOW_BLUR_SUPPORTED:Z" not in lines[end]:
        end += 1
    if end >= len(lines):
        sys.exit("guest_blur_framework_listeners: sput not found after property")
    indent = re.match(r"^(\s*)", lines[anchor]).group(1)
    new = [
        f"{indent}# OneOS: cross-window blur supported for guest sessions (oneos_blur_framework)",
        f"{indent}const/4 v0, 0x1",
        f"{indent}sput-boolean v0, Landroid/view/CrossWindowBlurListeners;->CROSS_WINDOW_BLUR_SUPPORTED:Z",
    ]
    del lines[anchor : end + 1]
    lines[anchor:anchor] = new
    open(path, "w").write("\n".join(lines))
    print(os.path.relpath(path, root).split(os.sep)[0])


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
