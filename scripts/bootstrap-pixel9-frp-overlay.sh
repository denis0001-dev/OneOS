#!/bin/sh
# Populate out/overlays_pixel_komodo_r16 for the fork's FRP-native pixel9-sultra set.
# Downloads unchanged payloads from fahadalijaved/OneOS-files sets-1, drops in the
# FRP services jar and guards.txt from app-android/packages/.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/out/overlays_pixel_komodo_r16"
LIST="$ROOT/app-android/packages/pixel9-sultra.sha256"
GUARDS="$ROOT/app-android/packages/pixel9-sultra.guards.txt"
SERVICES="${1:-/tmp/oneos-frp-only/out.jar}"
FRP_SHA=f6a8dfcf2d9c7ac2b559733bf1a1b6b655d2744698c1f6a1b51a8200b818daf9
GH=https://github.com/fahadalijaved/OneOS-files/releases/download/sets-1

mkdir -p "$OUT"
[ -f "$SERVICES" ] || { echo "missing FRP services jar: $SERVICES (run scripts/build-frp-services-jar.sh)" >&2; exit 1; }
got=$(shasum -a 256 "$SERVICES" | awk '{print $1}')
[ "$got" = "$FRP_SHA" ] || { echo "$SERVICES is $got, want $FRP_SHA" >&2; exit 1; }

while read -r line; do
    case "$line" in ""|"#"*) continue ;; esac
    sha=${line%% *}
    name=${line#*  }
    dst="$OUT/$name"
    case "$name" in
        services_patched.jar)
            cp -f "$SERVICES" "$dst"
            ;;
        guards.txt)
            cp -f "$GUARDS" "$dst"
            ;;
        *)
            if [ -f "$dst" ] && [ "$(shasum -a 256 "$dst" | awk '{print $1}')" = "$sha" ]; then
                :
            else
                echo "fetch $name"
                curl -fsSL -o "$dst" "$GH/$sha"
            fi
            ;;
    esac
    got=$(shasum -a 256 "$dst" | awk '{print $1}')
    [ "$got" = "$sha" ] || { echo "$name: got $got want $sha" >&2; exit 1; }
done < "$LIST"
echo "OK $OUT (pixel9-sultra r17 + guest_no_frp_policy)"
