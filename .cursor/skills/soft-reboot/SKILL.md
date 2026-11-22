---
name: soft-reboot
description: >-
  Handles KernelSU guest soft-reboot (ksud:soft-reboot), module install guards,
  and chained-reboot failures during Pixel guest on Samsung. Use when guest dies
  ~70s after switch, logs mention soft-reboot during install, sys.boot_completed,
  NeoZygisk/Vector install, or reload-guest-ksud. Also for /soft-reboot.
disable-model-invocation: true
---

# OneOS guest soft-reboot

Guest-only restart without full phone reboot. **Dangerous** if fired while One UI still reports boot completed and install scripts overlap.

## Concepts

| Piece | Role |
| --- | --- |
| `setprop oneos.guest.powerctl ksud:soft-reboot` | Switch watcher asks for guest soft reboot |
| `$STAGE/tmp/guest_softreboot.sh` | Staged script: restart guest processes only |
| `ksud.guest` / `reload-guest-ksud.sh` | Wrapper must **exec** real ksud (not empty `ksud.real`) |
| `.softreboot_install` / `tmp/softreboot.installing` | Skip soft-reboot while module install runs |
| `tmp/softreboot.gen` / `softreboot.last` | Debounce repeated soft-reboots (`oneos_switch.sh` ~90s cooldown) |
| Clear `sys.boot_completed` before module install | Avoid guest restart while One UI still “up” |

## Diagnose (device)

```bash
SERIAL="${SERIAL:-…}"
adb -s "$SERIAL" shell 'su 0 sh -c "
  getprop oneos.guest.powerctl
  getprop sys.boot_completed
  ls -la /data/local/tmp/oneos/tmp/softreboot.* /data/adb/oneos/.softreboot_install 2>/dev/null
  tail -30 /data/local/tmp/oneos/data/oneos_bootui/events.log 2>/dev/null
"'
```

**Chained soft-reboot signature**: guest ~60–90s after switch; log shows module install + `ksud soft-reboot` while `sys.boot_completed=1`; zygote injected then system_server timeout.

## Fix in repo (patcher / switcher assets)

When the failure is reproducible, land fixes in:

- `switcher/assets/guest_prepare.sh` — ksud wrapper, `mkdir -p` before `/system/xbin` tmpfs, install + softreboot guards
- `switcher/assets/guest_softreboot.sh` / `guest_runtime.sh` — `.softreboot_install`, install trap, baseline locks
- `switcher/assets/oneos_switch.sh` — `switch.lock`, soft-reboot cooldown
- `switcher/assets/reload-guest-ksud.sh` — hotfix paths; add to `oneos_root.sh` SCRIPTS and `RootScript.kt`

Then **android-build** → install APK → **Prepare** on phone.

## Safe manual soft-reboot (testing)

Only when **guest is actually running** and install is not active:

```bash
adb -s "$SERIAL" shell 'su 0 setprop oneos.guest.powerctl ksud:soft-reboot'
```

If install is running or One UI session is confused, use **reset-state** first.

## Module install checklist

1. `touch` / guard files prevent soft-reboot during install (see `guest_runtime.sh` bootstrap).
2. After NeoZygisk/Vector: prefer **one** soft-reboot when watchers agree gen/last timestamps.
3. Keep **rezygisk disabled** when SEPolicy blocks it (Vector-only path).
4. Run staged `reload-guest-ksud.sh` after Prepare if ksud paths were wrong on device.

## Tests in repo

```bash
python3 scripts/test-guest-softreboot-kill.py
python3 scripts/test-guest-runtime-baseline.py
```

Run after editing soft-reboot or baseline logic.

## Escalation

- Stuck switch before guest boot: **reset-state**, not repeated soft-reboot.
- Guest boot timeout / return audit: **guest-diagnose**.
- Return to One UI failed: full reboot may still be needed (`return_to_oneui.sh` fail-closed).
