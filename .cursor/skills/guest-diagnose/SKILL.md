---
name: guest-diagnose
description: >-
  Pull OneOS guest/session diagnostics (diag_* logs, logcat, stage audit) when
  guest boot fails, switch times out, or return_to_oneui is suspect. Use after
  screencap shows a stuck guest or silent failure.
disable-model-invocation: true
---

# OneOS guest diagnose

## Quick device read

```bash
SERIAL=…
adb -s "$SERIAL" shell 'su 0 sh -c "
  STAGE=/data/local/tmp/oneos
  getprop oneos.guest
  ls -la \$STAGE/.oneos_stage \$STAGE/persist_session.active 2>/dev/null
  tail -20 \$STAGE/oneos_switch.log 2>/dev/null
  tail -20 \$STAGE/guest_prepare.log 2>/dev/null
"'
```

## Stage logs (on phone)

Under `$STAGE` (host path `/data/local/tmp/oneos`):

- `oneos_switch.log`, `guest_prepare.log`, `guest_start.log` / pivot logs
- `diag_*` dirs (display, bt, telephony, etc. — see `docs/`)
- `data/oneos_bootui/events.log` for boot UI / soft-reboot

Pull with adb as root when permissions block:

```bash
adb -s "$SERIAL" pull /data/local/tmp/oneos/oneos_switch.log /tmp/
```

## Logcat (focused)

```bash
adb -s "$SERIAL" logcat -d -b system -b crash | tail -100
adb -s "$SERIAL" logcat -d | rg -i 'oneos|OneOS|system_server|Zygote' | tail -80
```

## When to escalate

| Signal | Next step |
| --- | --- |
| Same-boot “last session” on One UI | **reset-state** |
| Guest dies ~70s, soft-reboot in log | **soft-reboot** + patcher for guards |
| Return audit failed | Full reboot may be required |
| Missing patched jars after soft-reboot | **patcher** / upstream Prepare |

## Related

- **screencap** — UI symptom first.
- **patcher** — land reproducible script fixes.