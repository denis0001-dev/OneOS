"""Turn off factory-reset-protection policy inside the guest framework.

The phone's real FRP partition stays One UI's (guest_pdb_readonly.py). GMS and
LockSettingsService still treat FRP as active from staged secrets and
PersistentDataBlockService state, which blocks PIN changes and shows FRP setup
flows. The guest is disposable stage data: FRP must not gate credentials or PDB
APIs here.

In system_server (com.android.server.locksettings, pdb, oemlock, TradeInMode):

1. LockSettingsService.enforceFrpNotActive() returns immediately.
2. LockSettingsStorage.isFactoryResetProtectionActive() always false.
3. PersistentDataBlockService.isFrpActive() always false; activateFrp() is a
   no-op; enforceFactoryResetProtectionInactive() returns immediately;
   automaticallyDeactivateFrpIfPossible() always true (guest reports FRP off).
4. PersistentDataBlockService$1.isFactoryResetProtectionActive() always false.
5. OemLockService.isFactoryResetProtectionActive() always false.
6. TradeInModeService.isFrpActive() always false when present.

Does not change the host PDB or Samsung FRP. GMS may still show account-specific
device-protection UI that does not consult these APIs.

Usage: guest_no_frp_policy.py <apktool decoded services.jar dir>
Prints each smali_* directory it changed, one per line.
"""
from __future__ import annotations

import os
import re
import sys

MARK = "OneOS: guest FRP policy disabled"
MODS = r"(?:private |public |protected |final |static |synchronized )*"


def fail(msg: str) -> None:
    sys.exit(f"guest_no_frp_policy: {msg}")


def find_smali_dirs(root: str, relpath: str) -> list[str]:
    hits = [
        d
        for d in sorted(os.listdir(root))
        if d.startswith("smali") and os.path.isfile(os.path.join(root, d, relpath))
    ]
    return hits


def method_body_start(lines: list[str], header_i: int) -> int:
    j = header_i + 1
    while j < len(lines):
        s = lines[j].strip()
        if s == "" or s.startswith((".locals", ".param", ".end param", ".annotation", ".end annotation")):
            j += 1
            continue
        break
    return j


def patch_void_at_entry(lines: list[str], header_re: re.Pattern[str], rel: str, name: str) -> bool:
    heads = [i for i, line in enumerate(lines) if header_re.match(line)]
    if len(heads) != 1:
        fail(f"{rel}: {name} found {len(heads)} times, expected once")
    if any(MARK in lines[i] for i in range(heads[0], min(heads[0] + 12, len(lines)))):
        return False
    j = method_body_start(lines, heads[0])
    lines[j:j] = [
        f"    # {MARK} ({name})",
        "    return-void",
        "",
    ]
    return True


def patch_false_at_entry(lines: list[str], header_re: re.Pattern[str], rel: str, name: str) -> bool:
    heads = [i for i, line in enumerate(lines) if header_re.match(line)]
    if len(heads) != 1:
        fail(f"{rel}: {name} found {len(heads)} times, expected once")
    if any(MARK in lines[i] for i in range(heads[0], min(heads[0] + 12, len(lines)))):
        return False
    j = method_body_start(lines, heads[0])
    lines[j:j] = [
        f"    # {MARK} ({name})",
        "    const/4 v0, 0x0",
        "    return v0",
        "",
    ]
    return True


def patch_true_at_entry(lines: list[str], header_re: re.Pattern[str], rel: str, name: str) -> bool:
    heads = [i for i, line in enumerate(lines) if header_re.match(line)]
    if len(heads) != 1:
        fail(f"{rel}: {name} found {len(heads)} times, expected once")
    if any(MARK in lines[i] for i in range(heads[0], min(heads[0] + 12, len(lines)))):
        return False
    j = method_body_start(lines, heads[0])
    lines[j:j] = [
        f"    # {MARK} ({name})",
        "    const/4 v0, 0x1",
        "    return v0",
        "",
    ]
    return True


def patch_pm_install_frp(root: str) -> set[str]:
    """Never block PackageInstaller commits with secure-FRP (belt-and-suspenders)."""
    rel = os.path.join("com", "android", "server", "pm", "PackageInstallerSession.smali")
    needle = (
        "Landroid/service/persistentdata/PersistentDataBlockManager;->isFactoryResetProtectionActive()Z"
    )
    changed: set[str] = set()
    for smali_dir in find_smali_dirs(root, rel):
        path = os.path.join(root, smali_dir, rel)
        text_lines = open(path, encoding="utf-8").read().splitlines()
        if any(MARK in line for line in text_lines):
            continue
        out: list[str] = []
        hit = False
        for i, line in enumerate(text_lines):
            out.append(line)
            if needle in line:
                j = i + 1
                while j < len(text_lines) and text_lines[j].strip() == "":
                    out.append(text_lines[j])
                    j += 1
                if j < len(text_lines) and "move-result" in text_lines[j]:
                    out.append(text_lines[j])
                    out.append(f"    # {MARK} (PackageInstaller FRP)")
                    out.append("    const/4 v0, 0x0")
                    j += 1
                    for k in range(j, len(text_lines)):
                        out.append(text_lines[k])
                    hit = True
                    break
        if hit:
            open(path, "w", encoding="utf-8").write("\n".join(out) + "\n")
            changed.add(smali_dir)
            print(f"guest_no_frp_policy: patched {os.path.join(smali_dir, rel)}", file=sys.stderr)
    return changed


def patch_file(root: str, relpath: str, patches: list[tuple[str, str]]) -> set[str]:
    """patches: list of (method_suffix, kind) where kind is void|false|true."""
    changed: set[str] = set()
    for smali_dir in find_smali_dirs(root, relpath):
        path = os.path.join(root, smali_dir, relpath)
        lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
        if not lines or lines[-1].endswith("\n"):
            text_lines = [l.rstrip("\n") for l in lines]
        else:
            text_lines = lines
        rel = os.path.join(smali_dir, relpath)
        any_patch = False
        for suffix, kind in patches:
            hdr = re.compile(r"^\.method " + MODS + re.escape(suffix) + r"$")
            name = suffix.split("(")[0]
            if kind == "void":
                if patch_void_at_entry(text_lines, hdr, rel, name):
                    any_patch = True
            elif kind == "true":
                if patch_true_at_entry(text_lines, hdr, rel, name):
                    any_patch = True
            else:
                if patch_false_at_entry(text_lines, hdr, rel, name):
                    any_patch = True
        if any_patch:
            open(path, "w", encoding="utf-8").write("\n".join(text_lines) + "\n")
            changed.add(smali_dir)
            print(f"guest_no_frp_policy: patched {rel}", file=sys.stderr)
    return changed


def main() -> None:
    if len(sys.argv) != 2:
        fail(__doc__)
    root = sys.argv[1]
    if not os.path.isdir(root):
        fail(f"not a directory: {root}")

    changed: set[str] = set()
    changed |= patch_file(
        root,
        os.path.join("com", "android", "server", "locksettings", "LockSettingsService.smali"),
        [("enforceFrpNotActive()V", "void")],
    )
    changed |= patch_file(
        root,
        os.path.join("com", "android", "server", "locksettings", "LockSettingsStorage.smali"),
        [("isFactoryResetProtectionActive()Z", "false")],
    )
    changed |= patch_file(
        root,
        os.path.join("com", "android", "server", "pdb", "PersistentDataBlockService.smali"),
        [
            ("isFrpActive()Z", "false"),
            ("activateFrp()V", "void"),
            ("enforceFactoryResetProtectionInactive()V", "void"),
            ("automaticallyDeactivateFrpIfPossible()Z", "true"),
        ],
    )
    changed |= patch_file(
        root,
        os.path.join("com", "android", "server", "pdb", "PersistentDataBlockService$1.smali"),
        [("isFactoryResetProtectionActive()Z", "false")],
    )
    changed |= patch_file(
        root,
        os.path.join("com", "android", "server", "oemlock", "OemLockService.smali"),
        [("isFactoryResetProtectionActive()Z", "false")],
    )
    trade = os.path.join("com", "android", "server", "TradeInModeService.smali")
    if any(os.path.isfile(os.path.join(root, d, trade)) for d in os.listdir(root) if d.startswith("smali")):
        changed |= patch_file(
            root,
            trade,
            [("isFrpActive()Z", "false")],
        )
    changed |= patch_pm_install_frp(root)

    if not changed:
        fail("no files patched (missing classes or already patched?)")
    for d in sorted(changed):
        print(d)


if __name__ == "__main__":
    main()
