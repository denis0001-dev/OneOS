"""Settings > Network & internet: skip null legacy VPN profiles (VpnPreferenceController).

LegacyVpnProfileStore can list VPN_ keys whose decode() returns null (stale or host-only
profiles in the guest). Pixel Settings then crashes on ConnectivityThread when it counts
"insecure" VPNs: filter(profile -> profile.type) without a null check.

Patches VpnPreferenceController's insecure-type predicate only when that exact lambda is
present and not already fixed.

Usage: guest_settings_vpn_null.py <apktool decoded Settings.apk dir>
Prints the smali_* directory it changed; nothing when the anchor is not there.
"""
import os
import re
import sys

REL = os.path.join("com", "android", "settings", "network", "VpnPreferenceController.smali")
LAMBDA = "$r8$lambda$Pbq7X1kYqVfFHncC1LZLkxPSKwU"
MARK = ":oneos_vpn_null_ret"


def fail(msg):
    sys.exit("guest_settings_vpn_null: " + msg)


def main():
    if len(sys.argv) != 2:
        fail(__doc__)
    root = sys.argv[1]
    hits = [d for d in sorted(os.listdir(root))
            if d.startswith("smali") and os.path.isfile(os.path.join(root, d, REL))]
    if not hits:
        return
    if len(hits) != 1:
        fail("VpnPreferenceController in %d dex dirs" % len(hits))
    d = hits[0]
    p = os.path.join(root, d, REL)
    t = open(p, encoding="utf-8").read()
    if MARK in t:
        print("guest_settings_vpn_null: already patched", file=sys.stderr)
        print(d)
        return
    m = re.search(
        r"^\.method public static synthetic " + re.escape(LAMBDA)
        + r"\(Lcom/android/internal/net/VpnProfile;\)Z\n    \.locals \d+\n\n"
        r"    \.line \d+\n"
        r"    iget p0, p0, Lcom/android/internal/net/VpnProfile;->type:I\n\n"
        r"    invoke-static \{p0\}, Lcom/android/internal/net/VpnProfile;->isLegacyType\(I\)Z\n\n"
        r"    move-result p0\n\n"
        r"    return p0\n"
        r"\.end method",
        t,
        re.M,
    )
    if not m:
        fail("insecure VPN predicate is not the shape this was written for")
    new_method = (
        ".method public static synthetic " + LAMBDA + "(Lcom/android/internal/net/VpnProfile;)Z\n"
        "    .locals 0\n\n"
        "    # OneOS (patches/guest_settings_vpn_null.py): decode() can be null.\n"
        "    if-eqz p0, " + MARK + "\n\n"
        "    .line 223\n"
        "    iget p0, p0, Lcom/android/internal/net/VpnProfile;->type:I\n\n"
        "    invoke-static {p0}, Lcom/android/internal/net/VpnProfile;->isLegacyType(I)Z\n\n"
        "    move-result p0\n\n"
        "    return p0\n\n"
        + MARK + "\n"
        "    const/4 p0, 0x0\n\n"
        "    return p0\n"
        ".end method"
    )
    t = t[:m.start()] + new_method + t[m.end():]
    open(p, "w", encoding="utf-8").write(t)
    print("guest_settings_vpn_null: Network & internet VPN summary ignores null profiles",
          file=sys.stderr)
    print(d)


if __name__ == "__main__":
    main()
