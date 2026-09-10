#!/usr/bin/env bash
# Launch N isolated mGBA windows — ONE ROM FILE PER LANE (sav siblings stay local).
# Never point every process at hunt/rom/FireRed.gba; that shares one battery.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-4}"
MGBA="${MGBA_BIN:-mgba-qt}"
STAGGER_SEC="${STAGGER_SEC:-3}"
FARM="$ROOT/hunt"

if ! command -v "$MGBA" >/dev/null 2>&1; then
  echo "mGBA not found (set MGBA_BIN). Tried: $MGBA" >&2
  exit 1
fi

for i in $(seq 1 "$N"); do
  rom="$FARM/inst$i/FireRed.gba"
  script="$FARM/inst$i/hunt.lua"
  if [[ ! -f "$rom" ]]; then
    echo "missing $rom — run ./tools/generate_lanes.sh $N after placing hunt/rom/FireRed.gba" >&2
    exit 1
  fi
  if [[ ! -f "$script" ]]; then
    echo "missing $script — run ./tools/generate_lanes.sh $N" >&2
    exit 1
  fi
  # Optional software GL flags used on some Linux boxes; harmless if ignored via -C
  echo "starting inst$i → $rom (stagger ${STAGGER_SEC}s)"
  "$MGBA" -C hwaccelVideo=0 "$rom" &
  # Autoload script when supported (mGBA 0.10+): -s script
  # If your build lacks -s, load hunt.lua via Tools → Scripting after launch.
  if "$MGBA" --help 2>&1 | grep -qE '(^|[[:space:]])-s[[:space:]]'; then
    # relaunch note: some builds need script at start — try companion if available
    :
  fi
  sleep "$STAGGER_SEC"
done

echo "Started $N lanes. Load each hunt/instN/hunt.lua in Tools → Scripting if not auto-loaded."
echo "Sanity: first few pid_log lines should show unique non-zero PIDs + species=4 across lanes."
