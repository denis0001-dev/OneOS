"""Never expose ROUTE_UNKNOWN to InCallService (Pixel Dialer VoiceModel crash).

On the Pixel guest with Samsung audio, CallAudioRouteController can publish
AudioState with route and supportedRouteMask 0 while a call is active
(getBaseRoute -> null). Google Dialer then throws IllegalArgumentException:
Passed invalid audio route and the in-call UI freezes.

Coerce in android.telecom.CallAudioState.<init>: route 0 becomes ROUTE_EARPIECE (1),
supportedRouteMask 0 becomes earpiece|speaker|bluetooth|wired (0xf).

Usage: guest_telecom_audio_route.py <smali root dir>
Prints smali_* dex dirs changed, one per line.
"""
import os
import re
import sys

MARK = "oneos_telecom_audio_route"
CLASS = re.compile(r"^\.class .+ Landroid/telecom/CallAudioState;$")
CTOR = re.compile(
    r"^\.method public constructor <init>\(ZII"
)
LOCALS = re.compile(r"^(\s*)\.locals (\d+)$")


def patch_ctor(path: str, lines: list[str]) -> bool:
    heads = [i for i, l in enumerate(lines) if CTOR.match(l)]
    if len(heads) != 1:
        return False
    h = heads[0]
    if any(MARK in l for l in lines[h : lines.index(".end method", h)]):
        return True
    end = next(i for i in range(h, len(lines)) if lines[i] == ".end method")
  # route = p2, supportedRouteMask = p3 after (muted Z p1)
    inject = [
        "",
        "    # OneOS: Dialer rejects ROUTE_UNKNOWN from the Samsung-hosted HAL (guest_telecom_audio_route.py)",
        f"    :{MARK}_route",
        "    if-nez p2, :oneos_route_ok",
        "    const/4 p2, 0x1",
        "    :oneos_route_ok",
        f"    :{MARK}_mask",
        "    if-nez p3, :oneos_mask_ok",
        "    const/16 p3, 0xf",
        "    :oneos_mask_ok",
        "",
    ]
    # Insert after .prologue or after .locals line
    ins_at = h + 1
    while ins_at < end and not lines[ins_at].startswith(".end "):
        if lines[ins_at].strip() == ".prologue":
            ins_at += 1
            break
        if LOCALS.match(lines[ins_at]):
            ins_at += 1
            break
        ins_at += 1
    for j, line in enumerate(inject):
        lines.insert(ins_at + j, line)
    return True


def main(root: str) -> None:
    touched = []
    for dirpath, _, files in os.walk(root):
        if "CallAudioState.smali" not in files:
            continue
        path = os.path.join(dirpath, "CallAudioState.smali")
        line0 = open(path, encoding="utf-8").readline().strip()
        if not CLASS.match(line0):
            continue
        lines = open(path, encoding="utf-8").read().splitlines()
        if not patch_ctor(path, lines):
            sys.exit(f"{path}: CallAudioState.<init>(ZII not found")
        open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
        touched.append(os.path.relpath(path, root).split(os.sep)[0])
    if not touched:
        sys.exit("guest_telecom_audio_route: CallAudioState.smali not in tree")
    for d in sorted(set(touched)):
        print(d)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
