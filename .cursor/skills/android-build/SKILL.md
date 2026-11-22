---
name: android-build
description: >-
  Build and install the OneOS full debug APK (Gradle, guest_manager, series,
  packSets). Use when assembling the app, fixing oneosFiles/sessionScripts
  errors, or after patcher lands switcher assets.
disable-model-invocation: true
---

# OneOS Android build

## Prerequisites

- **JDK 21**: `export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home`
- **Android SDK**: `app-android/local.properties` with `sdk.dir=…` (or `ANDROID_HOME`)
- **guest_manager.apk**: `scripts/build-guest-manager.sh --debug` (release needs `~/.oneos-release/keystore.properties`)

## Full OneOS APK

Pick **series** from `app-android/packages/series.txt` for the phone (e.g. `s25` for S25 Ultra, `s26` for S26).

```bash
cd app-android
./gradlew :app:assembleFullDebug -Poneos.series=s25
```

**packSets** embeds local overlay dirs under `out/` — only when those trees exist:

```bash
./gradlew :app:assembleFullDebug -Poneos.packSets=true -Poneos.series=s25
```

If `oneosFiles` complains about unknown files in `switcher/assets/`, each name must be in `sessionScripts` or `switcherNotShipped` in `app-android/app/build.gradle.kts`.

## Install

```bash
adb -s "$SERIAL" install -r app/build/outputs/apk/full/debug/app-full-debug.apk
```

After install, user should **Prepare** on device so stage scripts/embed hashes refresh.

## Probe flavor

```bash
./gradlew :app:assembleProbeDebug
```

## Common failures

| Error | Fix |
| --- | --- |
| guest_manager missing | `scripts/build-guest-manager.sh --debug` |
| SDK location not found | `local.properties` or `ANDROID_HOME` |
| overlay dir missing for packSets | build overlays or drop `-Poneos.packSets=true` |
| session script not in embed list | add to `RootScript.kt` / `oneos_root.sh` + `build.gradle.kts` sessionScripts |