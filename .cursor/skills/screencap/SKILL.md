---

name: screencap
description: >-
  Captures the connected phone screen via adb screencap, pulls a fresh PNG, and
  inspects that file (never cached or old screenshots). Use for /screencap,
  "what's on screen", UI checks after switch/prepare, or verifying OneOS gates.
disable-model-invocation: true
---

# OneOS screencap (/screencap)

Always capture **now**. Do not reuse images from earlier turns, attachments, or `screenshot.png` left on disk unless you just wrote them in this same invocation.

## Device

1. `adb devices` — set `SERIAL` (user phone often `RFCY70YWGFY`; not assumed if missing).
2. Root/adb quirks: see **device-root-adb** when shell needs `su 0 sh -c`.

## Capture (every call)

Use a **unique path** per capture so nothing stale is read (timestamp or PID):

```bash
SERIAL="${SERIAL:-$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
OUT="/tmp/oneos-screencap-$(date +%Y%m%d-%H%M%S).png"
adb -s "$SERIAL" exec-out screencap -p > "$OUT"
```

- Prefer `exec-out` + stdout redirect (clean PNG). Fallback: `adb shell screencap -p /sdcard/oneos_cap.png` then `adb pull`.
- If the file is tiny or not PNG magic, retry once; report adb errors.

## Inspect

1. **Read** the file at `OUT` with the image read tool (same turn, that path only).
2. Describe what matters for the task (OneOS refusal text, boot animation, Samsung vs guest UI, dialogs).
3. Tell the user the capture path if they want the file.

## No other task (bare `/screencap`)

If the user only invokes `/screencap` (or equivalent) with **no** separate instruction:

1. Capture and read the image as above.
2. **Errors implied fix intent** — treat the screen as a bug report and **start fixing** without asking “what should I do?” when you see any of:
   - OneOS **Switch / Prepare / Home** refusal or gate text (e.g. last session, restart, free space, restore settings)
   - Android **crash** or **App isn’t responding** for OneOS or the guest
   - Stuck **“Shutting down One UI”**, black guest boot, or boot animation that should have finished
   - KernelSU / permission / root errors blocking OneOS
3. **Not an error** (normal Home, settings, success): briefly say what’s on screen; do not invent work.
4. **Fix path** (pick by message on screen; use other skills as needed):
   - Session / restart / last session → **reset-state** (device), then recheck or **screencap** again
   - Unfinished session / restore → app recover or reset-state flow
   - Guest soft-reboot / module install timing → **soft-reboot** + **patcher** if repo fix missing
   - Code/script regression → **patcher** (land + build + Prepare)
   - Unclear guest boot → **guest-diagnose** (logs), then patcher or reset-state
5. Keep the user posted in short steps; capture again after a fix when the UI should have changed.

## Rules

- **Never** answer "what's on screen" from memory or an old screenshot path.
- **Never** skip capture because a similar image was taken earlier in the chat.
- Multi-user / work profile: if capture is black or wrong user, note it; try `-s` serial only (no guessing user id unless the user asks).

## When there *is* another task

Follow the user’s instruction first; use the screenshot only as evidence. If their task and the screen disagree, trust the screen and say why.
