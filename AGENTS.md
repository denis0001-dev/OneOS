# Agent guidance (OneOS)

Instructions for coding agents working in this repository. For deep workflows, read the matching skill under `.cursor/skills/<name>/SKILL.md` **before** improvising device or Gradle steps.

## What this project is

OneOS hot-switches between **Samsung One UI** (host) and a **staged guest Android image** (often a Pixel/GSI build) on a **rooted** phone (KernelSU). The guest runs as a container with its own zygote and `system_server` on the host kernel. The Android app lives in `app-android/`; session logic and patches live in `switcher/`. Stage path on device: `/data/local/tmp/oneos` (`$STAGE`).

**Experimental — high blast radius.** Prefer small, reviewable diffs; land fixes in git rather than one-off `adb push` to the phone.

## Repository map

| Area | Path | Notes |
| --- | --- | --- |
| OneOS APK | `app-android/` | Gradle; JDK **21**; series in `packages/series.txt` |
| Session scripts | `switcher/assets/*.sh` | Switch, prepare, guest start, return to One UI |
| Smali patchers | `switcher/patches/*.py` | Applied during overlay builds or `patch-built-jar.sh` |
| Package sets / pins | `app-android/packages/` | `*.sha256`, `*.guards.txt`, `channel-embed.txt`, `sizes.txt` |
| Local overlay trees | `out/overlays_*` | e.g. `out/overlays_pixel_komodo_r20` for **pixel9-sultra** |
| Overlay build | `scripts/make-overlays.sh` | Full rebuild from a guest `system.img` |
| Incremental jar patch | `scripts/patch-built-jar.sh` | One patcher on an existing `*_patched.jar` |
| Framework camera/audio chain | `scripts/patch-framework-camera.sh` | Called from `make-overlays.sh` |
| Docs | `docs/` | Behaviour, return flow, patch catalog (`docs/app/patch-catalog.md`) |
| Device skills | `.cursor/skills/*` | **Use these** for build, patch land, adb root, reset, diagnose |

Firmware and IPSW/GSI blobs (when porting): check `~/Documents/Прошивки` first; symlink into `out/` — do not duplicate multi-GB trees in the repo.

## Cursor skills (when to use)

| Skill | Use when |
| --- | --- |
| [patcher](.cursor/skills/patcher/SKILL.md) | Permanent fixes: patchers, assets, hashes, APK land checklist |
| [run](.cursor/skills/run/SKILL.md) | `/run`: build, install, launch OneOS on device (`assembleFullDebug`, packSets, pins) |
| [device-root-adb](.cursor/skills/device-root-adb/SKILL.md) | `su 0 sh -c`, `nsenter -t 1 -m`, stage mutations |
| [guest-diagnose](.cursor/skills/guest-diagnose/SKILL.md) | Failed guest boot, switch timeout, return audit, logcat |
| [reset-state](.cursor/skills/reset-state/SKILL.md) | Same-boot stuck session on One UI, no full reboot |
| [soft-reboot](.cursor/skills/soft-reboot/SKILL.md) | Guest dies ~70s, ksud soft-reboot / module install races |
| [session-recover](.cursor/skills/session-recover/SKILL.md) | Cross-boot recover, purge, heavy stage wipe |
| [screencap](.cursor/skills/screencap/SKILL.md) | Fresh UI screenshot via adb (never reuse stale PNGs) |
| [pr-branch](.cursor/skills/pr-branch/SKILL.md) | `upstream` / `try-pr-*` sync and PR hygiene |

Invoke patcher/**run** when the user says **/patcher**, **patcher mode**, or **/run** (build + install + launch).

## Shell search and discovery

**Never** run broad content searches or walks over huge directory trees, including:

- `/` (filesystem root)
- The home directory — **do not** `grep -r`, `rg`, or `find` under `~`, `$HOME`, `/Users/<user>`, or any path outside the workspace to “look for” images, overlays, or artifacts. Ask the user for a path or use repo docs and `out/` under the project.
- `/data` on the device (or `adb shell find /data …` without a tight, known subdirectory)

These scans are slow, often hang or time out, and routinely hit permission-denied noise.

Instead:

- Search only **known paths** from docs, skills, or the repo (`Grep` / `rg` in the workspace).
- On device, prefer explicit locations: `/data/adb/oneos`, `/data/local/tmp/oneos`, `/data/user/0/com.fahadali.oneos/…` — not whole-tree `find` or `grep -r`.
- Use `adb shell su 0 sh -c '…'` with a **single** targeted `ls` or `cat` when root is required (see **device-root-adb**).

## How guest patches ship (the supported model)

Guest behaviour is changed by **bind-mounting patched jars/APKs from the package set** over the guest rootfs — not by replacing the host One UI `/system/framework/framework.jar` inside the APK.

### Two build paths

1. **Full overlay tree** — `scripts/make-overlays.sh <system.img> [outdir]`  
   Produces `framework_patched.jar`, `services_patched.jar`, guards, etc. `patch-framework-camera.sh` applies framework patchers (camera ABI, `guest_audio_vendor_usage.py`, …).

2. **Incremental patch on an existing jar** — when `out/overlays_*` already exists and only a patcher changed:

   ```bash
   export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
   scripts/patch-built-jar.sh out/overlays_pixel_komodo_r20/framework_patched.jar \
     switcher/patches/guest_audio_vendor_usage.py /tmp/framework_patched.jar.new
   mv /tmp/framework_patched.jar.new out/overlays_pixel_komodo_r20/framework_patched.jar
   ```

   Requires apktool (repo `mysticgsi/tools/apktool` or `APKTOOL` env). Framework jars may need dex-container fixes — follow output of `patch-built-jar.sh` and existing patterns in `make-overlays.sh`.

### Pin hashes after jar bytes change

Gradle **packSets** embeds local `out/overlays_*` and verifies against checked-in pins. Update **all** that apply to the set:

- `app-android/packages/<set>.sha256` (e.g. **pixel9-sultra**)
- `app-android/packages/<set>.guards.txt` and `out/overlays_*/guards.txt` if guards list changed
- `app-android/packages/channel-embed.txt` lines for embedded overlay paths
- Mirror test resource if present: `app-android/core/model/src/test/resources/packages/<set>.sha256`

Regenerate lines with `sha256sum` on the changed artifacts; align comments in `.sha256` / guards with patcher names (see `make-overlays.sh` guard echo lines).

### Example: Samsung vendor audio usage `1005` (guest)

| Symptom | Guest `IllegalArgumentException: Invalid usage 1005` in `AudioService` / `AudioAttributes$Builder.setUsage` |
| --- | --- |
| `guest_audio_vendor_usage.py` | Patch **guest** `framework_patched.jar` (accept usages ≥ 1000) |
| `guest_audio_samsung_strategies.py` | Patch **guest** `services_patched.jar` (`AudioSystemAdapter.loadProductStrategies` guard) |

Wire new patchers in `scripts/make-overlays.sh` / `patch-framework-camera.sh` so the next full overlay rebuild includes them. Ship via **pixel9-sultra** (dir `out/overlays_pixel_komodo_r20`) and build with `-Poneos.packSets=true`.

### Do **not** use (deprecated for agents)

- Embedding a **host** One UI `framework.jar` in the APK (`host_framework_audio_patched.jar`, `build-host-framework-audio.sh`, bind-mount host framework in `oneos_switch.sh` / `return_to_oneui.sh`). That path was rejected; guest overlay patches are the supported fix for guest audio crashes.
- “Fix on phone only” under `$STAGE` without the same change in `switcher/` + pins + APK.
- Committing multi-megabyte host framework pulls under `app-android/packages/` unless the user explicitly requests it.

## Build, install, launch (/run)

```bash
.cursor/skills/run/scripts/run-oneos.sh
```

See **run** skill for `--series`, `--pack-sets`, and `SERIAL`. User should **Prepare** after script or overlay changes.

- **`guest_manager.apk`** must exist (`scripts/build-guest-manager.sh --debug`).
- After install, the user should tap **Prepare** on the device so stage scripts and embed hashes refresh.
- New `.sh` in `switcher/assets/` must appear in `RootScript.kt`, `oneos_root.sh`, and `app/build.gradle.kts` `sessionScripts` / embed list or the build fails `oneosFiles`.

Series picker: `app-android/packages/series.txt`. Package set name (e.g. **pixel9-sultra**) is chosen at runtime from host+image manifest — see `oneos_root.sh` mappings and `build.gradle.kts` `packSets` table.

## Device operations (short)

| Goal | Skill |
| --- | --- |
| Root command on host | **device-root-adb** — `su 0 sh -c`, often `nsenter -t 1 -m` for props/stage |
| Stuck “last session” same boot | **reset-state** |
| Guest boot failure | **guest-diagnose** then **patcher** |
| ksud soft-reboot loop | **soft-reboot** |
| Prior boot unfinished session | **session-recover** |

Confirm `SERIAL` with `adb devices` (do not assume a specific serial unless the user gave one).

## Tests worth running after switcher changes

```bash
python3 scripts/test-guest-runtime-verify-return.py   # guest_runtime / return helpers
python3 scripts/test-guest-root.py                    # root script contracts
python3 scripts/test-guest-softreboot-kill.py          # after soft-reboot edits
```

Run targeted tests; do not commit unless the user asks.

## Git and PRs

- **No commits** unless the user explicitly requests (see user rules).
- Fork workflow: **pr-branch** (`upstream` = `fahadalijaved/OneOS`, feature branches often `try-pr-*`).
- Use `gh` for GitHub when opening PRs.

## Agent output expectations

When landing patches, report: **what/why**, files touched (grouped), tests and build result, and remind **Prepare** then retry switch. For display/UI checks, use **screencap** and read the freshly pulled PNG in the same turn.