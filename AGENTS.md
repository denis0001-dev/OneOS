# Agent guidance (OneOS)

Instructions for coding agents working in this repository.

## Shell search and discovery

**Never** run broad content searches or walks over huge directory trees, including:

- `/` (filesystem root)
- The home directory — **do not** `grep -r`, `rg`, or `find` under `~`, `$HOME`, `/Users/<user>`, or any path outside the workspace to “look for” images, overlays, or artifacts. Ask the user for a path or use repo docs and `out/` under the project.
- `/data` on the device (or `adb shell find /data …` without a tight, known subdirectory)

These scans are slow, often hang or time out, and routinely hit permission-denied noise.

Instead:

- Search only **known paths** from docs, skills (e.g. `device-root-adb`, `screencap`), or the repo (`Grep` / `rg` in the workspace).
- On device, prefer explicit locations such as `/data/adb/oneos`, `/data/local/tmp/oneos`, or app-specific dirs under `/data/user/0/com.fahadali.oneos/…` — not whole-tree `find` or `grep -r`.
- Use `adb shell su 0 sh -c '…'` with a **single** targeted `ls` or `cat` when root is required (see `.cursor/skills/device-root-adb/SKILL.md`).