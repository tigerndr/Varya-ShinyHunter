# Varya-ShinyHunter

Multi-instance **mGBA** Lua soft-reset farm for a **full-odds shiny Charmander** on Pokémon FireRed (US).

Named after the in-game trainer **Varya**. Scripts are GPLv3. You bring your own legal ROM and save — nothing copyrighted ships here.

## What it does

Each lane:

1. Soft-resets with **A+B+Start+Select** (full GBA reset → new initial seed)
2. Continues into Oak’s lab from a **pre-take** battery save
3. Walks to the **rightmost** Poké Ball (Charmander on this layout)
4. Takes the starter (no nickname)
5. Reads party slot 0 in memory and applies the real Gen 3 shiny test
6. Logs every PID; on a hit, battery-saves and writes `SHINY_FOUND` + farm `STOP_ALL`

### Shiny check (not a palette guess)

US FireRed party slot 0 is at `0x02024284` (PID at +0, OTID at +4).

```
(TID ^ SID ^ PID_hi ^ PID_lo) < 8
```

That is **1/8192**. The bot never writes a shiny PID into memory.

## Layout (isolation)

```
hunt/
  rom/FireRed.gba              # YOU supply (gitignored)
  STOP_ALL                     # farm-wide pause
  inst1/
    battery.sav                # copy of pre-take lab save (gitignored)
    hunt.lua                   # baked from template
    hunt_status.txt            # live status (gitignored)
    pid_log.txt                # append-only provenance (gitignored)
    SHINY_FOUND                # hit flag (gitignored)
    STOP                       # per-lane halt (gitignored)
  inst2/ ...
  inst3/ ...
  inst4/ ...
```

**Share the ROM only.** Never share `battery.sav`, status, or PID logs across processes while hunting. Same TID/SID across copied saves is correct; independent *seeds* come from separate processes soft-resetting on their own wall clocks.

> **Caveat:** if every lane soft-resets in near-lockstep on one host, initial seeds can correlate. Stagger launches a few seconds apart and treat `pid_log.txt` uniqueness across lanes as a sanity check.

## Setup

1. Install [mGBA](https://mgba.io/) with Lua support (`mgba-qt`).
2. Clone this repo.
3. Generate lanes:

```bash
chmod +x tools/generate_lanes.sh
./tools/generate_lanes.sh 4
```

4. Put your US FireRed ROM at `hunt/rom/FireRed.gba`.
5. Reach Oak’s lab **before** taking a starter, battery-save, then **copy** that `.sav` into each `hunt/instN/battery.sav` (once).
6. Point each mGBA at `hunt/instN/FireRed.gba` (or the shared ROM with a per-instance save directory — your launcher must keep saves isolated). Load `hunt/instN/hunt.lua` in Tools → Scripting.

Example launch sketch (adjust paths):

```bash
for i in 1 2 3 4; do
  sleep $((i * 3))   # stagger seeds
  mgba-qt "hunt/rom/FireRed.gba" &
  # then load hunt/inst$i/hunt.lua in that window
done
```

Exact save-path flags vary by mGBA version; the hard rule is **one battery file per lane**.

## Provenance

| File | Role |
|------|------|
| `pid_log.txt` | Source of truth — every roll with PID, OTID, xor, shiny flag |
| `hunt_status.txt` | Latest cycle + recent PIDs for a watch script |
| `SHINY_FOUND` | Written on hit (before/after in-game save) |
| screenshots | `shiny_Charmander_<cycle>.png` (+ `_saved`) |

Empty-party streak ≥ 8 stops that lane only (missed ball / pathing fault).

## Odds vs pace

One independent roll is Geo(1/8192). Four independent lanes ≈ Geo(4/8192). Mean wait scales with your real rolls/minute — measure from the logs, don’t trust marketing cycle counts without non-zero unique PIDs.

## Legal

- You must own the game / a legal dump. **No ROMs or saves in this repository.**
- Scripts © contributors, licensed under **GPL-3.0** (see `LICENSE`).
- This is a tool for auditing full-odds soft resets. It is not a shiny injector.

## Privacy

Public releases intentionally omit personal names, locations, private logs, and machine paths. Keep your live `pid_log.txt` and saves out of git (already gitignored).
