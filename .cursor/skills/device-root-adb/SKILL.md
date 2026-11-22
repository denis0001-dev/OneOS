---
name: device-root-adb
description: >-
  Run root commands on Samsung KernelSU hosts via adb (su 0 sh -c, busybox,
  nsenter). Use when adb shell su hangs, stage scripts need host root, or
  prepare/switch diagnostics require init mount namespace.
disable-model-invocation: true
---

# OneOS device root over adb

## Serial

```bash
SERIAL="${SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
adb -s "$SERIAL" …
```

User’s S25 Ultra is often `RFCY70YWGFY` — always confirm with `adb devices`.

## Root shell (Samsung KernelSU)

Plain `adb shell su` often hangs or lacks context. Prefer:

```bash
adb -s "$SERIAL" shell 'su 0 sh -c "id"'
adb -s "$SERIAL" shell 'su 0 sh -c "command here"'
```

For **init mount namespace** (props, stage on One UI):

```bash
BB=/data/adb/ksu/bin/busybox
STAGE=/data/local/tmp/oneos
adb -s "$SERIAL" shell "su 0 $BB nsenter -t 1 -m -- /system/bin/sh -c '…'"
```

## Guest vs host

- Commands **without** `nsenter` run in **adbd’s** namespace (often fine for reading logs).
- **Stage mutations** (`$STAGE/guest_prepare.sh`, props restore) usually need **host root** in **init** namespace (`nsenter -t 1 -m`).
- Inside an **active guest**, many paths are in the guest PID namespace — use guest adb only for guest-side reads unless using the OneOS root bridge.

## Push to stage

```bash
adb -s "$SERIAL" push switcher/assets/foo.sh /data/local/tmp/
adb -s "$SERIAL" shell 'su 0 cp /data/local/tmp/foo.sh /data/local/tmp/oneos/foo.sh'
```

Prefer **Prepare** after APK install instead of long-lived manual copies.

## Avoid

- Nested quoting failures — keep scripts on device and `su 0 sh /path/script.sh`.
- Assuming wireless adb is stable for huge pulls; prefer USB for multi-GB stage files.