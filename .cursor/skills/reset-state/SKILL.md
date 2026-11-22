---
name: reset-state
description: >-
  Clears stuck OneOS session state without rebooting (persist_session.active,
  guest allowlist bind, stage locks). Use when the app says "Part of the last
  session is still running", switch/prepare is refused, or after a failed
  switch on Samsung KernelSU devices. Also for /reset-state.
disable-model-invocation: true
---

# OneOS reset state (no reboot)

Unstick One UI when a guest session died mid-switch but markers and guest-root baseline mounts remain.

## Before you act

1. Confirm the user is on **One UI** (home works, not stuck on a black guest boot).
2. Read **device-root-adb** for root shell: `adb shell 'su 0 sh -c "…"'` (plain `adb shell su` often fails).
3. Set `SERIAL` from `adb devices` if multiple phones.

## Symptoms → cause

| App / root message | Likely cause |
| --- | --- |
| "Part of the last session is still running" | `persist_session.active` same `boot_id`, and/or stage mounts/loops |
| "a session of this stage is still running" | Same-boot `persist_session.active` |
| "mounted in the stage" | Init mount under `/data/local/tmp/oneos` |
| Guest-root leftover | Bind mount on `/data/adb/ksu/.allowlist` from `tmp/guest_runtime_baseline/` |

Official **Last session → Restore** calls `oneos_root.sh recover`, which **refuses same boot** (`guest_props.sh recover` exit 3). For a dead session on One UI **without reboot**, use **manual restore** below (same as a successful return).

## Procedure (init mount namespace)

Run on device as root. Prefer the bundled script from the repo:

```bash
SERIAL="${SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
adb -s "$SERIAL" push .cursor/skills/reset-state/scripts/reset-state.sh /data/local/tmp/oneos-reset-state.sh
adb -s "$SERIAL" shell 'su 0 sh /data/local/tmp/oneos-reset-state.sh'
```

Or inline the same steps:

1. **Kill strays** (if any): `oneos_switch.sh`, `guest_runtime.sh baseline`, `ui_activator`, `oneos_wdog_feeder.sh`.
2. **Teardown allowlist bind**: if `mount | grep allowlist.saved`, `busybox umount /data/adb/ksu/.allowlist`.
3. **Remove locks**: `$STAGE/tmp/switch.lock`, `$STAGE/tmp/guest_runtime_baseline/.running`, `$STAGE/bin/.lock`.
4. **Restore One UI persist props** (removes `persist_session.active` on success):

   ```bash
   STAGE=/data/local/tmp/oneos
   BB=/data/adb/ksu/bin/busybox
   ONEOS_APP=1 STAGE="$STAGE" "$BB" nsenter -t 1 -m -- /system/bin/sh "$STAGE/guest_props.sh" restore-persist --recover
   ```

5. **Stale baseline flag**: if allowlist is normal f2fs but `$STAGE/tmp/guest_runtime_baseline/allowlist.protected` exists, `rm` it.

Do **not** delete `persist_session.active` alone without step 4 unless props are already known-good.

## Verify

```bash
adb -s "$SERIAL" shell 'su 0 sh -c "
  S=/data/local/tmp/oneos
  test ! -f \$S/persist_session.active && echo OK_no_persist || echo FAIL_persist
  grep -F \$S /proc/1/mountinfo && echo FAIL_mounts || echo OK_mounts
  grep -F \$S/system.raw /sys/block/loop*/loop/backing_file 2>/dev/null || echo OK_no_raw_loop
"'
```

Then **force-stop OneOS** and reopen so Home re-runs the stage check.

## When reboot is still required

Refuse and tell the user to reboot if any of:

- Stage **bridges** on `/data/data`, `/data/user`, `/data/user_de`
- `system.raw` on a loop device
- Guest zygote/system_server still running for the session
- `restore-persist` exits non-zero (props fail-closed; marker kept)

Cross-boot unfinished session (different `boot_id` in marker): app **Last session → Restore** or `oneos_root.sh recover` is appropriate.

## After reset

1. **Prepare** (ships new scripts to stage; required after repo script changes).
2. Retry **Switch**; use **guest-diagnose** if guest boot fails again.

## Related

- `scripts/remove-oneos-data.sh` — full stage wipe (`--force` cross-boot); not for light reset.
- **session-recover** — app-aligned recover path and attic rules.
