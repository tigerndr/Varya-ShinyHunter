# Varya-ShinyHunter

Multi-instance **mGBA** Lua soft-reset farm for a **full-odds shiny Charmander** on Pokémon FireRed (US).

Named after the in-game trainer **Varya**. Scripts are GPLv3. You bring your own legal ROM and save — nothing copyrighted ships here.

## What it does

Each lane:

1. Soft-resets with **A+B+Start+Select** (full GBA reset → new initial seed)
2. Continues into Oak’s lab from a **pre-take** battery save
3. Walks to the **rightmost** Poké Ball (Charmander on this layout)
4. Takes the starter (no nickname)
5. Reads party slot 0 in memory, decrypts **species**, applies the real Gen 3 shiny test
6. Logs every PID + species; on a hit, battery-saves and writes `SHINY_FOUND` + farm `STOP_ALL`

### Shiny check (not a palette guess)

US FireRed party slot 0 is at `0x02024284` (PID at +0, OTID at +4, encrypted data at +32).

```
(TID ^ SID ^ PID_hi ^ PID_lo) < 8
```

That is **1/8192**. The bot never writes a shiny PID into memory. XOR uses a portable `bxor` (Lua 5.2–safe). Species is decrypted from the growth substructure so a wrong ball cannot be logged as Charmander.

## Isolation model (one ROM file per lane)

**This is the only supported launch model.** Each process opens `hunt/instN/FireRed.gba`. mGBA then writes `FireRed.sav` **next to that ROM**. Four windows on `hunt/rom/FireRed.gba` will tear one battery and fake PIDs — do not do that.

```
hunt/
  rom/FireRed.gba              # source copy YOU supply (gitignored)
  STOP_ALL                     # farm-wide pause
  inst1/
    FireRed.gba                # per-lane ROM copy (gitignored)
    FireRed.sav                # per-lane battery (gitignored)
    hunt.lua                   # baked from template (gitignored)
    hunt_status.txt            # live status (gitignored)
    pid_log.txt                # append-only provenance (gitignored)
    SHINY_FOUND / STOP
  inst2/ ...
```

Same TID/SID across copied pre-take saves is correct. Independent seeds come from separate processes + staggered soft resets.

> **Caveat:** lockstep soft resets on one host can correlate seeds. `launch_farm.sh` staggers starts; treat cross-lane `pid_log.txt` uniqueness as a sanity check.

## Setup

1. Install [mGBA](https://mgba.io/) with Lua (`mgba-qt`).
2. Clone this repo.
3. Put your US FireRed ROM at `hunt/rom/FireRed.gba`.
4. Generate lanes (copies ROM into each `instN/`, bakes `hunt.lua`):

```bash
chmod +x tools/generate_lanes.sh tools/launch_farm.sh
./tools/generate_lanes.sh 4
```

5. Reach Oak’s lab **before** taking a starter, battery-save, then **copy** that save to each lane as `hunt/instN/FireRed.sav` (once).
6. Launch:

```bash
./tools/launch_farm.sh 4
```

7. In each mGBA window: **Tools → Scripting → Load** `hunt/instN/hunt.lua`.  
   (Do **not** load `scripts/*.template.lua` — `__INST__` is not valid Lua until baked.)

Optional: `MGBA_BIN=/path/to/mgba-qt STAGGER_SEC=5 ./tools/launch_farm.sh 4`

Re-running `generate_lanes.sh` refuses to clobber a live `pid_log.txt` unless you pass `--force`.

## Provenance

| File | Role |
|------|------|
| `pid_log.txt` | Source of truth — PID, OTID, xor, shiny, **species** |
| `hunt_status.txt` | Latest cycle + recent PIDs for a watch script |
| `SHINY_FOUND` | Written on hit (before/after save menu walk) |
| screenshots | `shiny_Charmander_<cycle>.png` (+ `_saved`) |

Empty-party streak ≥ 8 **or** wrong-species streak ≥ 8 stops that lane only.

## Odds vs pace

One independent roll is Geo(1/8192). Four independent lanes ≈ Geo(4/8192). Mean wait scales with real rolls/minute — measure from the logs.

## Legal

- You must own the game / a legal dump. **No ROMs or saves in this repository.**
- Scripts © contributors, licensed under **GPL-3.0** (see `LICENSE`).
- This is a tool for auditing full-odds soft resets. It is not a shiny injector.

## Privacy

Public releases omit personal names, locations, private logs, and machine paths. Keep live `pid_log.txt` and saves out of git (already gitignored).
