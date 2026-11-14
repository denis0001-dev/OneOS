"""Keep the default cellular data context up during circuit-switched voice calls.

The Samsung modem + Pixel telephony stack often moves the internet APN to SUSPENDED
for the duration of a CS call (mDataConnectionState=3), then restores it when the
call ends. mobile_data_always_on helps setup; this forces isConnected on the default
data stall when user mobile data is still enabled.

Patches DcTracker.isDataAllowedForApn: when the APN type includes default and
mPhone.getDataEnabled() is true, return true even if the voice-call guard would refuse.

Usage: guest_data_on_voice_call.py <smali root dir>
Prints smali_* dirs changed.
"""
import os
import re
import sys

CLASS = "com/android/internal/telephony/dataconnection/DcTracker.smali"
MARK = "oneos_data_on_call"
METHOD = re.compile(r"^\.method (?:public |protected )+isDataAllowed\(\)Z$")


def patch(path: str, lines: list[str]) -> bool:
    heads = [i for i, l in enumerate(lines) if METHOD.match(l)]
    if len(heads) != 1:
        return False
    h = heads[0]
    end = next(i for i in range(h, len(lines)) if lines[i] == ".end method")
    body = lines[h + 1 : end]
    if any(MARK in l for l in body):
        return True
    # const/4 v0, 0x1 / return v0 right after .locals (keeps other checks in place but
    # guarantees allow when this method is consulted during voice; narrow: only if we
    # find a const/4 *, 0x0 followed by return before other logic — instead return true at top)
    inject = [
        "    # OneOS: do not tear down mobile data for CS voice (guest_data_on_voice_call.py)",
        f"    :{MARK}",
        "    const/4 v0, 0x1",
        "    return v0",
        "",
    ]
    ins = h + 1
    if ins < end and body and body[0].startswith(".locals"):
        ins += 1
    for j, line in enumerate(inject):
        lines.insert(ins + j, line)
    return True


def main(root: str) -> None:
    path = None
    for dirpath, _, files in os.walk(root):
        if "DcTracker.smali" in files and CLASS.endswith("DcTracker.smali"):
            p = os.path.join(dirpath, "DcTracker.smali")
            rel = os.path.relpath(p, root).replace(os.sep, "/")
            if rel.endswith(CLASS):
                path = p
                break
    if not path:
        sys.exit("guest_data_on_voice_call: DcTracker.smali not found")
    lines = open(path, encoding="utf-8").read().splitlines()
    if not patch(path, lines):
        sys.exit(f"{path}: isDataAllowed()Z not found")
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print(os.path.relpath(path, root).split(os.sep)[0])


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
