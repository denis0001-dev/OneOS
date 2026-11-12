#!/usr/bin/env python3
"""Build OneOSSettingsGoogle.apk like build-systemui-bar.py: replace classes3.dex only."""
import argparse, copy, hashlib, pathlib, shutil, struct, subprocess, sys, tempfile, zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PATCHER = ROOT / "switcher/patches/guest_settings_vpn_null.py"
DONOR_SHA = "221a5c96973abda79ec0a6cbc2322990879e4a6f27e516f56118f0691dbf87c6"
APKTOOL = ["apktool"] if shutil.which("apktool") else ["java", "-jar", "/tmp/apktool.jar"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("donor", type=pathlib.Path)
    ap.add_argument("--zipalign", type=pathlib.Path, required=True)
    ap.add_argument("--output", type=pathlib.Path, required=True)
    a = ap.parse_args()
    a.donor = a.donor.resolve()
    a.output = a.output.resolve()
    assert hashlib.sha256(a.donor.read_bytes()).hexdigest() == DONOR_SHA, "unexpected SettingsGoogle donor"
    with tempfile.TemporaryDirectory(prefix="oneos-settings-vpn-") as tmp:
        w = pathlib.Path(tmp)
        decoded = w / "decoded"
        subprocess.run(APKTOOL + ["d", "-f", "-r", "-o", str(decoded), str(a.donor)], check=True)
        dex_dir = subprocess.check_output(
            [sys.executable, "-I", str(PATCHER), str(decoded)], text=True,
        ).strip().splitlines()[-1]
        assert dex_dir, "guest_settings_vpn_null changed nothing"
        subprocess.run(APKTOOL + ["b", "-o", str(w / "rebuilt.apk"), str(decoded)], check=True)
        if dex_dir == "smali":
            dex_name = "classes.dex"
        elif dex_dir.startswith("smali_classes"):
            dex_name = "classes" + dex_dir.removeprefix("smali_classes") + ".dex"
        else:
            raise SystemExit(f"unexpected dex dir {dex_dir}")
        new_dex = (decoded / "build/apk" / dex_name).read_bytes()
        with a.donor.open("rb") as raw, zipfile.ZipFile(a.donor) as src, zipfile.ZipFile(w / "raw.apk", "w") as dst:
            for info in src.infolist():
                if info.filename == dex_name:
                    dst.writestr(info.filename, new_dex, compress_type=zipfile.ZIP_STORED)
                    continue
                raw.seek(info.header_offset)
                header = raw.read(30)
                assert header[:4] == b"PK\x03\x04"
                nl, el = struct.unpack_from("<HH", header, 26)
                body = raw.read(nl + el + info.compress_size)
                desc = b""
                if info.flag_bits & 8:
                    desc = raw.read(4)
                    desc += raw.read(12 if desc == b"PK\x07\x08" else 8)
                entry = copy.copy(info)
                entry.header_offset = dst.fp.tell()
                dst.fp.write(header + body + desc)
                dst.filelist.append(entry)
                dst.NameToInfo[entry.filename] = entry
                dst.start_dir = dst.fp.tell()
                dst._didModify = True
        subprocess.run(
            [str(a.zipalign), "-f", "-P", "16", "4", str(w / "raw.apk"), str(w / "aligned.apk")],
            check=True,
        )
        original = a.donor.read_bytes()
        e = original.rfind(b"PK\x05\x06")
        cd = struct.unpack_from("<I", original, e + 16)[0]
        assert original[cd - 16 : cd] == b"APK Sig Block 42"
        size = struct.unpack_from("<Q", original, cd - 24)[0]
        block = original[cd - size - 8 : cd]
        result = bytearray((w / "aligned.apk").read_bytes())
        e = result.rfind(b"PK\x05\x06")
        cd = struct.unpack_from("<I", result, e + 16)[0]
        result = bytearray(result[:cd] + block + result[cd:])
        struct.pack_into("<I", result, e + len(block) + 16, cd + len(block))
        a.output.write_bytes(result)
    subprocess.run([sys.executable, str(ROOT / "scripts/check-dex.py"), str(a.output)], check=True)
    print(hashlib.sha256(a.output.read_bytes()).hexdigest(), a.output)


if __name__ == "__main__":
    main()
