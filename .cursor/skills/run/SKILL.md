---
name: run
description: >-
  Build, install, and launch the OneOS full debug APK on the connected phone
  (/run). Use after patcher lands changes, when the user says /run, or wants
  the app rebuilt and opened on device.
disable-model-invocation: true
---

# OneOS run (/run)

End-to-end: **Gradle assemble** → **adb install** → **launch MainActivity**. Prefer the bundled script (one short command).

## Default command

From repo root (or any cwd):

```bash
.cursor/skills/run/scripts/run-oneos.sh
```

Options: `--series s25` (default `s25`), `--pack-sets`, `--no-launch`, `--probe`, `--serial RFCY70YWGFY`. Env: `SERIAL`, `SERIES`, `JAVA_HOME`.

```bash
SERIAL=RFCY70YWGFY .cursor/skills/run/scripts/run-oneos.sh --pack-sets
```

Report build result, install, and `am start` output. Remind **Prepare** when switcher assets or overlay jars changed.

## packSets

Use `--pack-sets` only when every `out/overlays_*` dir for that series exists. Otherwise build without it (local jars via `packages/channel-embed.txt`). After `patch-built-jar.sh`, refresh pins first (**patcher** skill).

## Prerequisites

- **JDK 21** (script sets Homebrew `@21` if `JAVA_HOME` unset)
- **guest_manager.apk**: `scripts/build-guest-manager.sh --debug` when Gradle complains
- One `adb devices` line in `device` state

## Common failures

| Error | Fix |
| --- | --- |
| guest_manager missing | `scripts/build-guest-manager.sh --debug` |
| SDK location not found | `app-android/local.properties` or `ANDROID_HOME` |
| `overlays_* is missing` with packSets | omit `--pack-sets` |
| pin / guards mismatch | update packages + channel-embed |
| multiple devices | `--serial` or `SERIAL=…` |

## Related

- **patcher** — land changes before **run**
- **device-root-adb** — root after install