"""Force cross-window blur supported in the guest framework (Pixel/AOSP guests).

CrossWindowBlurListeners.<clinit> reads ro.surface_flinger.supports_background_blur
once with default false. On a Samsung host that is often unset when zygote loads
framework classes, so SystemUI, Launcher and apps see isCrossWindowBlurEnabled()
false and draw a flat dim even when BlurController has mBlurEnabled=true and
guest_props override the prop for SurfaceFlinger later.

Usage: guest_framework_cross_window_blur.py <smali root dir>
Prints the smali_* directory changed. Exits unless exactly one CrossWindowBlurListeners
is patched in <clinit>.
"""
import os
import re
import sys

CLASS = re.compile(r"^\.class (?:public |final )*Landroid/view/CrossWindowBlurListeners;$")
CLINIT = re.compile(r"^\.method static constructor blacklist <clinit>\(\)V$")
BLUR_PROP = re.compile(r'const-string(/jumbo)? v\d+, "ro\.surface_flinger\.supports_background_blur"')


def patch_clinit(lines):
    start = None
    for k, line in enumerate(lines):
        if CLINIT.match(line):
            start = k
            break
    if start is None:
        sys.exit("guest_framework_cross_window_blur: <clinit> not found")
    end = next(k for k in range(start, len(lines)) if lines[k] == ".end method")
    block = lines[start : end + 1]
    if not any(BLUR_PROP.search(l) for l in block):
        sys.exit("guest_framework_cross_window_blur: blur property read not in <clinit>")
    out = []
    i = 0
    while i < len(block):
        if BLUR_PROP.search(block[i]):
            # Drop from property const-string through sput-boolean CROSS_WINDOW_BLUR_SUPPORTED.
            while i < len(block) and "CROSS_WINDOW_BLUR_SUPPORTED:Z" not in block[i]:
                i += 1
            if i >= len(block):
                sys.exit("guest_framework_cross_window_blur: sput CROSS_WINDOW_BLUR_SUPPORTED missing")
            indent = re.match(r"^(\s*)", block[i]).group(1)
            out.extend(
                [
                    f"{indent}# OneOS: treat cross-window blur as supported (Samsung host prop is wrong at class init)",
                    f"{indent}const/4 v0, 0x1",
                    block[i],
                ]
            )
            i += 1
            continue
        out.append(block[i])
        i += 1
    return lines[:start] + out + lines[end + 1 :]


def main(root):
    found = []
    for dirpath, _, files in os.walk(root):
        if "CrossWindowBlurListeners.smali" not in files:
            continue
        path = os.path.join(dirpath, "CrossWindowBlurListeners.smali")
        if not CLASS.match(open(path).readline().strip()):
            continue
        found.append(path)
    if len(found) != 1:
        sys.exit(f"guest_framework_cross_window_blur: CrossWindowBlurListeners found {len(found)} times")
    path = found[0]
    lines = open(path).read().split("\n")
    patched = patch_clinit(lines)
    open(path, "w").write("\n".join(patched))
    print(os.path.relpath(path, root).split(os.sep)[0])


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
