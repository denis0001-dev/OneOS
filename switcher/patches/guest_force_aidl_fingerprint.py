"""Make the guest framework reach the phone's fingerprint HAL whatever transport it uses.

The guest's FingerprintService picks its sensor adapter from
FingerprintSensorConfigurations.resetLockoutRequiresHardwareAuthToken: false
adds HidlToAidlSensorAdapter wrappers and asks hwservicemanager for the HIDL
2.1 IBiometricsFingerprint HAL, true adds the native AIDL sensor. ColorOS 17
reports false, and on a phone whose HAL is AIDL only (Samsung, Pixel, most
2023+ devices) the guest then logs "Fingerprint HAL not available" and
FingerprintUpdateActiveUserClient retries forever with a NullPointerException,
so the keyguard never offers fingerprint.

The flag is replaced with a question the phone answers: is
android.hardware.biometrics.fingerprint.IFingerprint/default registered? It is
on every AIDL HAL; on a HIDL-only phone the lookup returns null and the image's
own value is used, which is what that image shipped for its own HAL.

Usage: guest_force_aidl_fingerprint.py <smali root dir>
Prints the smali_* directories (dex files) it changed, one per line.
"""
import os
import re
import sys

GET_PROVIDERS = re.compile(
    r"^\.method (?:private |public final )getProviders\("
    r"Landroid/hardware/fingerprint/FingerprintSensorConfigurations;\)Ljava/util/List;",
    re.M,
)
LOCALS = re.compile(r"^(\s*)\.locals (\d+)\s*$", re.M)

# ColorOS/HyperOS: move-result v3; Pixel/AOSP: move-result p1 (and a public getProviders).
INVOKE = re.compile(
    r"(?m)^(?P<indent>[ \t]*)"
    r"invoke-virtual \{p1\}, Landroid/hardware/fingerprint/FingerprintSensorConfigurations;->"
    r"getResetLockoutRequiresHardwareAuthToken\(\)Z[ \t]*\n"
    r"(?:[ \t]*\n)?"
    r"(?P<move>[ \t]*)move-result (?P<reg>v\d+|p\d+)[ \t]*\n"
)


def aidl_transport_block(indent, flag_reg, scratch):
    """scratch is a v* register not used by the flag read's original path."""
    one = f"{indent}:oneos_fingerprint_hidl"
    two = f"{indent}:oneos_fingerprint_transport"
    return f"""{indent}# OneOS: the image's flag names its own HAL's transport (false = HIDL 2.1).
{indent}# Ask the phone instead: the AIDL instance is there on every AIDL HAL, and
{indent}# its absence leaves a HIDL image with the value it shipped.
{indent}const-string {scratch}, "android.hardware.biometrics.fingerprint.IFingerprint/default"

{indent}invoke-static {{{scratch}}}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;

{indent}move-result-object {scratch}

{indent}if-eqz {scratch}, {one}

{indent}const/4 {flag_reg}, 0x1

{indent}goto {two}

{one}
{indent}invoke-virtual {{p1}}, Landroid/hardware/fingerprint/FingerprintSensorConfigurations;->getResetLockoutRequiresHardwareAuthToken()Z

{indent}move-result {flag_reg}

{two}
"""


def find(root, rel_suffix):
    hits = [os.path.join(d, f) for d, _, fs in os.walk(root) for f in fs
            if os.path.join(d, f).endswith(rel_suffix)]
    if len(hits) != 1:
        sys.exit(f"expected exactly one {rel_suffix}, found {len(hits)}")
    return hits[0]


def pick_scratch(flag_reg, locals_n):
    used = {flag_reg, "p0", "p1", "v0", "v1"}
    if flag_reg.startswith("v"):
        used.add(flag_reg)
    for n in range(locals_n):
        r = f"v{n}"
        if r not in used:
            return r
    return f"v{locals_n}"


def bump_locals(src, method_start, need_at_least):
    """Raise .locals inside getProviders to cover scratch registers."""
    m = GET_PROVIDERS.search(src, method_start)
    if not m:
        return src
    head = src[m.start():m.end()]
    loc = LOCALS.search(src, m.end())
    if not loc:
        sys.exit("getProviders: no .locals line")
    n = int(loc.group(2))
    if n >= need_at_least:
        return src
    rep = f"{loc.group(1)}.locals {need_at_least}\n"
    return src[:loc.start()] + rep + src[loc.end():]


def main(root):
    rel = os.path.join("com", "android", "server", "biometrics", "sensors",
                       "fingerprint", "FingerprintService.smali")
    path = find(root, rel)
    src = open(path).read()
    if GET_PROVIDERS.search(src) is None:
        sys.exit(f"{rel}: getProviders(FingerprintSensorConfigurations) not found")
    m_gp = GET_PROVIDERS.search(src)
    method_slice = src[m_gp.start():]
    hits = list(INVOKE.finditer(method_slice))
    if len(hits) != 1:
        sys.exit(f"{rel}: the getResetLockoutRequiresHardwareAuthToken read is not there once in getProviders (found {len(hits)})")
    h = hits[0]
    abs_start = m_gp.start() + h.start()
    abs_end = m_gp.start() + h.end()
    flag_reg = h.group("reg")
    loc_m = LOCALS.search(src, m_gp.end())
    locals_n = int(loc_m.group(2)) if loc_m else 4
    scratch = pick_scratch(flag_reg, locals_n)
    need = max(locals_n, int(scratch[1:]) + 1) + 1
    src = bump_locals(src, m_gp.start(), need)
    # offsets may have shifted if .locals grew
    m_gp = GET_PROVIDERS.search(src)
    method_slice = src[m_gp.start():]
    hits = list(INVOKE.finditer(method_slice))
    h = hits[0]
    abs_start = m_gp.start() + h.start()
    abs_end = m_gp.start() + h.end()
    flag_reg = h.group("reg")
    scratch = pick_scratch(flag_reg, need)
    block = aidl_transport_block(h.group("indent"), flag_reg, scratch)
    src = src[:abs_start] + block + src[abs_end:]
    open(path, "w").write(src)
    print("FingerprintService.getProviders: AIDL sensor when the AIDL HAL is registered, "
          "the image's flag otherwise", file=sys.stderr)
    print(os.path.relpath(path, root).split(os.sep)[0])


if __name__ == "__main__":
    main(sys.argv[1])
