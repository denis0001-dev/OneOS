#!/usr/bin/env python3
"""Sanity-check guest_telecom_audio_route.py on a minimal CallAudioState stub."""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATCHER = ROOT / "switcher/patches/guest_telecom_audio_route.py"

STUB = """
.class public Landroid/telecom/CallAudioState;
.super Ljava/lang/Object;
.source "CallAudioState.java"

.method public constructor <init>(ZII)V
    .locals 0

    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    return-void
.end method
""".strip()


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        smali = Path(td) / "smali" / "android" / "telecom"
        smali.mkdir(parents=True)
        (smali / "CallAudioState.smali").write_text(STUB + "\n")
        out = subprocess.check_output(
            [sys.executable, "-I", str(PATCHER), td],
            text=True,
        ).strip()
        if out != "smali":
            print("unexpected dex dir:", out, file=sys.stderr)
            return 1
        body = (smali / "CallAudioState.smali").read_text()
        if "oneos_telecom_audio_route" not in body:
            print("patch marker missing", file=sys.stderr)
            return 1
        if "const/4 p2, 0x1" not in body:
            print("route coerce missing", file=sys.stderr)
            return 1
    print("PASS: guest_telecom_audio_route.py")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
