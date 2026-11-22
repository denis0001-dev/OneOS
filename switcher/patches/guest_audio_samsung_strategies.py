"""Guest audio: tolerate Samsung HAL product strategies with vendor usages.

Samsung's QTI HAL lists product strategies whose usages (e.g. 1005) AOSP rejects in
AudioAttributes$Builder.setUsage during native_list_audio_product_strategies.
AudioService then never starts (S25 Ultra Pixel guest).

loadProductStrategies() catches IllegalArgumentException from the native list call,
logs once, and continues with empty strategy lists.

Usage: guest_audio_samsung_strategies.py <apktool decoded services.jar dir>
Prints changed smali_* dirs, one per line.
"""
import os
import re
import sys

REL = os.path.join("com", "android", "server", "audio", "AudioSystemAdapter.smali")
MARK = "oneos_samsung_audio_strategies"
NATIVE = (
    "invoke-static {v0}, Landroid/media/audiopolicy/AudioProductStrategy;->"
    "native_list_audio_product_strategies(Ljava/util/ArrayList;)I"
)


def fail(msg):
    sys.exit("guest_audio_samsung_strategies: " + msg)


def patch_method(body):
    if MARK in body:
        return None
    m = re.search(
        r"^\.method public final loadProductStrategies\(\)Z\n(.*?)^\.end method\n",
        body,
        re.M | re.S,
    )
    if not m:
        return None
    inner = m.group(1)
    if NATIVE not in inner:
        return None
    inv_m = re.search(
        r"(\s*)\.line \d+\n\s*" + re.escape(NATIVE) + r"\n\n\s*move-result v2\n",
        inner,
    )
    if not inv_m:
        fail("native_list block not in expected form")
    ind = inv_m.group(1)
    wrapped = (
        f"{ind}:{MARK}_try_start\n"
        f"{ind}" + NATIVE + "\n\n"
        f"{ind}move-result v2\n"
        f"{ind}:{MARK}_try_end\n"
        f"{ind}.catch Ljava/lang/IllegalArgumentException; "
        f"{{:{MARK}_try_start .. :{MARK}_try_end}} :{MARK}_skip\n"
        f"{ind}.catch Ljava/lang/RuntimeException; "
        f"{{:{MARK}_try_start .. :{MARK}_try_end}} :{MARK}_skip\n"
    )
    inner = inner[: inv_m.start()] + wrapped + inner[inv_m.end() :]
    skip = (
        f"\n{ind}:{MARK}_skip\n"
        f"{ind}# OneOS ({MARK}): vendor usage from Samsung HAL product strategies\n"
        f'{ind}const-string v4, "AudioSystemAdapter"\n'
        f'{ind}const-string/jumbo v5, "loadProductStrategies: ignored Samsung vendor usage"\n'
        f"{ind}invoke-static {{v4, v5}}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;)I\n"
        f"{ind}invoke-static {{}}, Ljava/util/Collections;->emptyList()Ljava/util/List;\n"
        f"{ind}move-result-object v2\n"
        f"{ind}invoke-static {{v2}}, Ljava/util/Collections;->unmodifiableList(Ljava/util/List;)Ljava/util/List;\n"
        f"{ind}move-result-object v0\n"
        f"{ind}iput-object v0, p0, Lcom/android/server/audio/AudioSystemAdapter;->mAudioProductStrategies:Ljava/util/List;\n"
        f"{ind}iput-object v2, p0, Lcom/android/server/audio/AudioSystemAdapter;->mAudioProductStrategiesWithoutInternal:Ljava/util/List;\n"
        f"{ind}const/4 v1, 0x1\n"
        f"{ind}return v1\n"
    )
    if re.search(r"^(\s*)\.locals (\d+)\s*$", inner, re.M):

        def bump_locals(m):
            return f"{m.group(1)}.locals {max(int(m.group(2)), 6)}"

        inner = re.sub(r"^(\s*)\.locals (\d+)\s*$", bump_locals, inner, count=1, flags=re.M)
    inner = inner.rstrip() + skip + "\n"
    return body[: m.start(1)] + inner + body[m.end(1) :]


def main():
    if len(sys.argv) != 2:
        fail(__doc__)
    root = sys.argv[1]
    changed = []
    for d in sorted(os.listdir(root)):
        if not (d == "smali" or d.startswith("smali_")):
            continue
        p = os.path.join(root, d, REL)
        if not os.path.isfile(p):
            continue
        text = open(p, encoding="utf-8").read()
        new = patch_method(text)
        if new is not None:
            open(p, "w", encoding="utf-8").write(new)
            changed.append(d)
            print(f"guest_audio_samsung_strategies: {d}/{REL}", file=sys.stderr)
        elif MARK in text:
            changed.append(d)
    for d in changed:
        print(d)
    if not changed:
        fail("AudioSystemAdapter.smali loadProductStrategies not found")


if __name__ == "__main__":
    main()