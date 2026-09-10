#!/usr/bin/env bash
# Generate N isolated lane dirs + baked hunt.lua from the template.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-4}"
TEMPLATE="$ROOT/scripts/shiny_charmander_hunt.template.lua"
FARM="$ROOT/hunt"
mkdir -p "$FARM"
for i in $(seq 1 "$N"); do
  d="$FARM/inst$i"
  mkdir -p "$d"
  # Escape path for sed replacement
  sed \
    -e "s|__INST__|$i|g" \
    -e "s|__HUNT_DIR__|$d|g" \
    -e "s|__FARM_STOP__|$FARM/STOP_ALL|g" \
    "$TEMPLATE" > "$d/hunt.lua"
  echo "wrote $d/hunt.lua"
done
echo "Copy your US FireRed ROM to $FARM/rom/FireRed.gba (not shipped)."
echo "Copy a pre-take Oak-lab battery.sav into each instN/ once, then never share it."
