# Guest FRP policy (local / experimental)

Samsung's real FRP partition stays One UI's (`guest_pdb_readonly.py`). Guest
framework code can still treat FRP as active from staged secrets, which blocks
PIN changes and package installs (`Can't install packages while in secure FRP`).

`switcher/patches/guest_no_frp_policy.py` turns off FRP policy **inside the
guest** only (locksettings, PDB service APIs, oemlock). It is wired into
`scripts/make-overlays.sh` for official set builds; until the channel ships it,
use the phone scripts below.

## Phone workflow

```sh
export ANDROID_SERIAL=<device>
scripts/build-frp-services-jar.sh    # pulls stage services_patched.jar, patches, writes /tmp/oneos-frp-only/out.jar
scripts/apply-frp-patch-phone.sh   # attic jar, oneos_frp_policy marker, hashes, oneos_switch.sh hook
```

**Important:** OneOS **Prepare** (including a fresh container) restores the app's
stock `services_patched.jar` and `oneos_switch.sh`, which removes this workaround.
On One UI, run `scripts/apply-frp-patch-phone.sh` again **after every Prepare**
and before you switch to Pixel.

After **Prepare**, `oneos_switch.sh` copies
`attic/services_patched.frp.jar` back when `/data/local/tmp/oneos_frp_policy` (or legacy `data/oneos_frp_policy`) exists.

Remove the workaround:

```sh
adb shell su -M -c 'rm -f /data/local/tmp/oneos/data/oneos_frp_policy /data/local/tmp/oneos/attic/services_patched.frp.jar'
# then OneOS Prepare to restore channel services_patched.jar
```
