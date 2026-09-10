#!/usr/bin/env bash
# Generate N isolated lane dirs + baked hunt.lua from the template.
# Also stages per-lane ROM copies so each mGBA process gets its own sibling .sav.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
N="${1:-4}"
TEMPLATE="$ROOT/scripts/shiny_charmander_hunt.template.lua"
FARM="$ROOT/hunt"
ROM_SRC="$FARM/rom/FireRed.gba"
mkdir -p "$FARM/rom"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "missing template: $TEMPLATE" >&2
  exit 1
fi

for i in $(seq 1 "$N"); do
  d="$FARM/inst$i"
  mkdir -p "$d"
  # Never truncate pid_log.txt / status — only rewrite hunt.lua (+ optional ROM copy)
  # Use relative HUNT_DIR from repo root so baked paths stay portable
  rel="hunt/inst$i"
  sed \
    -e "s|__INST__|$i|g" \
    -e "s|__HUNT_DIR__|$ROOT/$rel|g" \
    -e "s|__FARM_STOP__|$FARM/STOP_ALL|g" \
    "$TEMPLATE" > "$d/hunt.lua"
  if [[ -f "$ROM_SRC" ]]; then
    # Per-lane ROM copy → mGBA writes FireRed.sav beside THIS copy only
    if [[ ! -f "$d/FireRed.gba" ]] || [[ "$ROM_SRC" -nt "$d/FireRed.gba" ]]; then
      cp -f "$ROM_SRC" "$d/FireRed.gba"
    fi
  else
    echo "note: place US FireRed at $ROM_SRC then re-run to copy into each inst" >&2
  fi
  echo "wrote $d/hunt.lua"
done
echo "Next: copy a pre-take Oak-lab battery.sav into each hunt/instN/FireRed.sav (once)."
echo "Launch with: ./tools/launch_farm.sh $N"
