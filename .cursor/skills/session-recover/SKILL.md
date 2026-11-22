---
name: session-recover
description: >-
  Recover or purge OneOS guest sessions via the app (Last session) or
  oneos_root.sh recover/purge/remove. Use for unfinished sessions, attic/old
  stages, or cross-boot restore — not same-boot stuck state (see reset-state).
disable-model-invocation: true
---

# OneOS session recover

## App path

**Last session → Restore** runs `oneos_root.sh recover`, which calls `guest_props.sh recover` and teardown rules in `return_to_oneui.sh`.

**Recover refuses same boot** when props fail-closed (exit 3) — for that, use **reset-state** instead (no full reboot).

## Root verbs (`oneos_root.sh`)

| Verb | When |
| --- | --- |
| `recover` | Unfinished session from a **prior** boot / safe return |
| `remove` | App “remove system”; clears logs helpers + can drop stage pieces |
| `purge` | Deletes an idle `oneos.old-<epoch>` copy |
| `reset-data` | Moves `$STAGE/data` aside (fresh guest data tree) |

Invoke via OneOS app root bridge — not by hand unless debugging.

## Full stage wipe (host)

Heavy reset (not light **reset-state**):

```bash
# see scripts/remove-oneos-data.sh in repo when present
adb shell 'su 0 rm -rf /data/local/tmp/oneos /data/local/tmp/oneos_incoming /data/local/tmp/oneos_logs'
# plus oneos.old-* / oneos.trash-* as needed
```

Requires **no active session** (no `system.raw` loop, no guest processes).

## After recover

1. **Prepare** if APK/scripts changed.
2. Retry **Switch**; **guest-diagnose** if boot fails.

## Related

- **reset-state** — same boot, One UI still up, no reboot.
- **device-root-adb** — how to run host root scripts.