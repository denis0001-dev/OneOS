# Guest FRP policy

Samsung's real FRP partition stays One UI's (`guest_pdb_readonly.py`). Guest
framework code can still treat FRP as active from staged secrets, which blocks
PIN changes and package installs (`Can't install packages while in secure FRP`).

`switcher/patches/guest_no_frp_policy.py` turns off FRP policy **inside the
guest** only (locksettings, PDB service APIs, oemlock, package install FRP gate).

## Fork (pixel9-sultra): native in the channel

On this fork the patch is part of the normal overlay build and package set:

- `scripts/make-overlays.sh` applies `guest_no_frp_policy` with the other
  `services_patched.jar` guards (same line as `guest_pdb_init_survives`, etc.).
- `app-android/packages/pixel9-sultra.guards.txt` and `pixel9-sultra.sha256`
  pin `services_patched.jar` at the FRP build (`f6a8dfcf…` for r16 + FRP on top
  of upstream `725ba58e…`).

Rebuild the set overlay and app:

```sh
scripts/bootstrap-pixel9-frp-overlay.sh    # or make-overlays.sh on a GSI tree
# embed in the APK (no separate download for the jar):
./gradlew -p app-android :app:assembleFullDebug -Poneos.series=s25 -Poneos.packSets=true
```

After **Prepare** on the phone, the channel ships the patched jar; you do **not**
need `scripts/apply-frp-patch-phone.sh` for day-to-day use.

`oneos_switch.sh` still supports an optional attic override when
`oneos_frp_policy` exists (legacy / local experiments). Remove it if you rely on
the channel only:

```sh
adb shell su -M -c 'rm -f /data/local/tmp/oneos_frp_policy /data/local/tmp/oneos/data/oneos_frp_policy /data/local/tmp/oneos/attic/services_patched.frp.jar'
```

## Phone-only workflow (upstream or quick test)

```sh
export ANDROID_SERIAL=<device>
scripts/build-frp-services-jar.sh
scripts/apply-frp-patch-phone.sh
```

Use this when the installed app still downloads upstream `725ba58e…`
`services_patched.jar`, or before the fork APK with r17 manifests is installed.
Prepare restores the app's channel jar; re-apply after Prepare if you stay on
that workflow.
