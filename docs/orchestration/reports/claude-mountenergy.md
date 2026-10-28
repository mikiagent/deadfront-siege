# claude-mountenergy: creature energy pool and mounted sprint

Branch `claude/mmo-mountenergy` (cut from `claude/mmo-overhaul` 292e6c87). Owner ask, 2026-10-28:
holding Shift on a mount runs it, the energy bar shows the mount's energy, and dinosaurs have no
exhaustion but must not spam runs or specials.

## What changed
- **Creature energy API** (commit 71f77909, `game/scripts/creatures/creature.gd`):
  - State: `energy`, `energy_max`, `winded`, `running`.
  - Methods: `energy_frac()`, `can_sprint()`, `can_use_special(cost)`, `spend_energy(cost)`,
    `special_cost(clip)`, `try_special(clip)`, `walk_mps(run_mps)`, `tick_energy(delta, running)`,
    `setup_energy()`.
  - `_physics_process` ticks the pool every frame for every unridden creature. Drain applies while
    the brain is in a `sprint_states` state (approach, attack, flee, retreat, chase) and the
    creature moves. A winded creature is clamped to walk pace.
- **Data**: `game/data/creatures/ai.json` gains an `"energy"` block. `CreatureDef.energy` holds an
  optional per-species override (`{max, regen_per_s, run_drain_per_s, costs{clip:n}}`). A species
  clip entry written as an object with `energy_cost` also works. No species JSON was edited.
- **Mounted sprint** (`game/scripts/player/player_pets.gd`): `wants_mount_sprint()` is Shift or
  `sprint_toggled`. `mounted_move` runs the mount at its pet pace while it wants to sprint and is not
  winded, and walks it at 0.5 × that pace otherwise. Each frame it ticks the MOUNT's pool. The
  rider's vitals are never touched: the mounted path skipped `_walk` before this change too.
- **HUD** (`game/scripts/ui/hunt_hud.gd`): `static energy_reading(player)` returns the mount's pool
  while mounted, named and drawn amber, and the survivor's stamina otherwise. The face and the
  treadmill stay the survivor's.
- **Save**: energy is not saved. A reload starts full, and the pool refills in 11–32 s. No pet field
  was added, so `PET_KEYS` and the econ validators are untouched.
- **Brains: not edited.** At the coordinator's request the tactical-combat agent owns
  creature_brain, tyrant_brain and raptor_pack_brain. Heavies there still play without checking
  energy. Wiring: call `creature.try_special(clip)` before `play_clip(&"attack_heavy")` and fall
  back to `attack_primary` on false. Wild sprint gating does work today through creature.gd.
- Docs: `docs/current/creatures-capture-taming.md` (Energy section and mounts),
  `docs/current/hud.md`, `docs/current/controls.md`.

## Numbers (`# ASSUMPTION`: all of them, first pass)
| rule | value |
|---|---|
| pool | 80 + 6 × real_length_m |
| refill time 0→full | 10 + 0.5 × length s |
| run drain | 10/s |
| winded at / resume at | 5 % / 40 % of pool |
| walk pace (winded, or a mount without sprint) | 0.5 × run speed |
| special cost | attack_heavy 0.3 × pool, bite_combo 0.35 × pool, others free |

| species | pool | run from full s | winded→resume s | heavy |
|---|---|---|---|---|
| compsognathus | 98 | 9.3 | 4.0 | 29 |
| zebraceratops | 106 | 10.1 | 4.3 | 32 |
| deinonychus | 141 | 13.4 | 5.3 | 42 (bite_combo 49) |
| tyrannosaurus | 224 | 21.3 | 7.7 | 67 |
| brachiosaurus | 344 | 32.7 | 11.2 | 103 |

## Gates (headless)
- `t_energy` (new): `[t_energy] PASS`, 24 checks. It covers drain and refill, the hysteresis, a
  refused special, wild chase drain and the walk clamp, Shift and toggle on the mount, the bar
  reading the mount and then the survivor, and the survivor's stamina and exhaustion staying put.
  Measured on the zebraceratops: run 3.13 m/s, walk 1.57 m/s, winded 0.78 m per 30 frames.
- `[t_mounts] PASS`, `[t_ai] PASS`, `[t_turnrate] PASS`, `[t_canim] PASS`, `[t_natures] PASS`,
  `[t_fieldhud] PASS`, `[t_ui] PASS`, `[t_rest] PASS`, `[t_targetui] PASS`.
- `[t_save] PASS`, with its 5 known deliberate SCRIPT ERRORs.
- `[equiplab] PASS`.
- `SMOKE PASS` (`tools/smoke.sh --no-import`).
- run_all: `[tests] PASS`. Its SCRIPT ERRORs are the known ones: the TouchControls compile order and
  the deliberate econ fault.
- t_econ was not run, because no pet field changed.

## Risks and checks still owed on screen
- **Mount speeds:** the zebraceratops runs at about 3 m/s and walks at about 1.5 m/s. The survivor
  walks at 5.5 m/s, so riding without sprint is slow and riding with sprint is still slower than her
  walk. This is pre-existing (pet speed = stat speed / 100), but walking makes it more visible. The
  owner should decide the mount speed scale.
- The fatigue check in t_energy allows a +0.5 drift. Passive fatigue rose 0.22 over the run, and
  none of it came from the mount.
- Specials are not energy-gated in the brains yet. That waits on the tactical package.
- On screen, still to check: amber mount bar and name on desktop and on an 844×390 phone (where the
  name may drop); Shift and SPRINT on the zebraceratops changing gait from walk to run and back;
  the winded fall to a walk.
