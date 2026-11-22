---
name: patcher
description: >-
  Permanently lands guest/switcher patches in the OneOS fork, updates package
  hashes and channel embeds, runs patch tests, and builds the full debug APK.
  Use for /patcher, patcher mode, services_patched.jar changes, switcher assets,
  or when asked to make device hotfixes permanent in the repo.
disable-model-invocation: true
---

# OneOS patcher mode

**Patcher mode** means: no ad-hoc “fix on phone only” — changes belong in git under `switcher/`, `scripts/`, and `app-android/`, then a verified build ships them via **Prepare**.

## Entering mode

User says `/patcher`, **patcher mode**, or gives a concrete patch task.

### No task in the message (promote last turn)

If the user invokes patcher **without** a new task:

1. Inspect **uncommitted** changes: `git status`, `git diff`.
2. Include conversation context: edits made only on device, `adb push` to stage, or “temporary” script tweaks must move into the correct repo paths (`switcher/assets/`, `switcher/patches/`, Kotlin if needed).
3. Remove one-off comments/debug; match surrounding style.
4. Complete the **land checklist** below and build.

Do not commit unless the user asked (see user git rules).

## Where patches live

| Kind | Location |
| --- | --- |
| Smali / jar patchers | `switcher/patches/*.py`, `OneOS*.java`, helper `.sh` in `switcher/patches/` |
| Session / guest runtime | `switcher/assets/*.sh`, `guest_prepare.sh`, `oneos_switch.sh`, … |
| App staging / root verbs | `app-android/app/src/full/assets/root/oneos_root.sh`, `RootScript.kt` |
| Prebuilt artifacts | `app-android/packages/` (`sizes.txt`, `channel-embed.txt`, set blobs) |
| Catalog / docs | `docs/app/patch-catalog.md`, `docs/guest-*.md` when behaviour is user-visible |

## Land checklist

Copy and complete:

```
Patcher progress:
- [ ] Change in correct tree (not only /data/local/tmp/oneos on phone)
- [ ] Hash/size updates if staged binaries changed (sizes.txt, channel-embed.txt)
- [ ] files.sha256 list: Prepare/finish on device refreshes; repo ships sources + embeds
- [ ] RootScript.kt + oneos_root.sh SCRIPTS agree on new .sh assets
- [ ] Relevant scripts/test-*.py or unit tests run
- [ ] android-build (full + packSets when testing Pixel guest)
- [ ] adb install -r; user Prepare on phone
```

### Jar / overlay workflow

```bash
# Example: patch an existing services_patched.jar
scripts/patch-built-jar.sh <in.jar> switcher/patches/some_patcher.py <out.jar>
# Then update packages/sizes.txt + channel-embed.txt (sha256 of out.jar)
```

Smali helpers: `scripts/make-overlays.sh`, `scripts/check-dex.py`. See `docs/guest-screen-lock.md`, `docs/guest-frp-policy.md` for patterns.

### Switcher-only script fix

Edit under `switcher/assets/`. If the file is listed in `RootScript.SCRIPTS` / `oneos_root.sh` `SET_*`, bump embed hash in `app-android/packages/channel-embed.txt` when the build packs it locally.

### Build (default full guest test)

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
cd app-android && ./gradlew :app:assembleFullDebug -Poneos.packSets=true -Poneos.series=pixel9fork
adb -s "$SERIAL" install -r app/build/outputs/apk/full/debug/app-full-debug.apk
```

JDK 21 required; `guest_manager.apk` must exist in `switcher/assets/`. Details: **android-build**.

## Temporary vs permanent

| Temporary (avoid leaving here) | Permanent (patcher mode) |
| --- | --- |
| `adb push` to `$STAGE` without repo edit | Same change in `switcher/assets/` + embed |
| Editing scripts only on phone under `$STAGE/bin/` | Prepare after APK install |
| Manual hash on device | `sizes.txt` / `channel-embed.txt` in repo |

## Output for the user

After landing:

1. Short summary of **what** was patched and **why**.
2. Files touched (grouped: patcher py, assets, packages, app).
3. Tests run + build result.
4. Reminder: **Prepare** then retry switch; **soft-reboot** / **reset-state** if those gates apply.

## Related skills

- **android-build** — Gradle, packSets, install.
- **pr-branch** — branch/PR workflow when patcher work should ship on `try-pr-*`.
- **soft-reboot** / **reset-state** — device ops after patched APK is installed.
