# Deprecated — do not use for new work

This folder was for building a **host** One UI `host_framework_audio_patched.jar` inside the APK. That approach is **rejected**.

**Supported path:** guest overlay jars in the package set (`framework_patched.jar` + `services_patched.jar` via `switcher/patches/guest_audio_vendor_usage.py` and `guest_audio_samsung_strategies.py`), shipped with **pixel9-sultra** / `out/overlays_pixel_komodo_r20`, using `scripts/patch-built-jar.sh` or `scripts/make-overlays.sh`. See repo **AGENTS.md** and `.cursor/skills/patcher/SKILL.md`.

Legacy scripts `scripts/build-host-framework-audio.sh` and `scripts/fetch-host-framework-audio-source.sh` may remain for local experiments only — agents should not wire them back into Gradle or session embeds.