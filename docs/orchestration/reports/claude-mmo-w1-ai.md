# W1-AI report: wild AI that wakes, flees, levels and scales

Branch `claude/mmo-w1-ai` (from `claude/mmo-overhaul`). Commits: `f28ef5f` (WIP from the interrupted attempt, kept), `9331a9f`, `2db0176`, plus this report. Nothing pushed or merged. Meshy credits spent: 0.

## What shipped

- **CreatureBrain** (`game/scripts/creatures/brains/creature_brain.gd`)
  - Shared `_pre_think` runs before every species `_think`: timers, the leash, night sleep, walk home and the temp-home expiry. Raptor, tyrant and base brains all go through `tick()`.
  - Sleep branch. Grazers wake at dawn, or when a survivor or pet comes within `wake_m` of the body. A woken grazer stays up `woken_awake_s`.
  - Flight runs from `attack_target` (always the last damage source), starting from the animal's own position, so the herd clamp no longer applies while fleeing.
  - A fleeing animal keeps running until the threat is past the leash. The 3 s "far" give-up now applies only to chasers.
  - One leash per pack: the alpha's ring. A leash break releases every member on that target together, and nobody re-acquires for 0.5 s (`REACQUIRE_HOLD_S`).
  - Temperaments (skittish, defensive, territorial) come from `ai.json` and are merged default -> temperament -> archetype.
  - Idle pack slots are sized from real body radii. Reach is measured to the target's capsule (`reach_to`, `_size_excess`), so pets and wild animals can bite giants.
  - The post-kill and post-flight `spawn_home` is temporary and reverts after 120 s.
  - Every `[ai]` print goes through `_log`, which prints only with `Game.debug_overlay` and counts lines in `debug_lines`.
  - `signal state_changed(prev, next)` is emitted once per transition in `_set_state`. This is the audio hook.
  - Think rate is 10 Hz, staggered by a random phase. Idle (roam/sleep) brains farther than 60 m from every player freeze. Pets, combat and scenes with no player never freeze.
- **Tyrant/raptor/pet brains**
  - Tyrant timed moves still resolve every physics frame (`_full_rate`), and a leash drop mid-swing ends the move.
  - Raptor bite exit has 0.4 m hysteresis. Pet reach adds the target's size excess.
  - Pet state changes go through `_set_state`.
- **Creature** (`creature.gd`)
  - Level is species tier + ring `level_offset` + row `tier_offset`. The Spawner passes its parent runtime, because `World.runtime` is still null during the build.
  - Wild health, attack and defense scale with levels above tier (`rules.json wild_level_stat_rate`).
  - The O(N^2) `_separation_steer` is removed.
  - `move_and_slide` is skipped while standing still on the floor, and `set_status_fx` is called only when the value changes.
  - The hidden debug label is no longer formatted every frame.
  - The authored `hit_react` plays when present (the old test was inverted), gated by stagger immunity.
  - Tames leave their wild pack (`pack_id = 0`).
  - Nav steering now refreshes the agent path (`get_next_path_position()`) and skips waypoints already passed. A stale path held the alpha in place in `ai_validation_lab`.
- **Spawner**
  - Solo spawns are pack 0.
  - Each spawn row's `tier_offset` is looked up from the island def by ring + species (see the hooks section).
- **Corpse**
  - The dead body takes a collision exception with its own loot cylinder, so it rests on the terrain.
  - Butchering XP is paid only when loot units actually moved.
- **Data**
  - `ai.json`: `chase_speed_mult` 0.7 per carnivore archetype (today's value, pending the owner's decision), `flee_speed_mult`, `wake_m`, `woken_awake_s`, a `temperaments` block, and a temperament for each grazer archetype.
  - `rules.json`: `wild_level_stat_rate`.
- **Labs and tests**
  - New `wild_ai_sweep_lab` (scene + script).
  - `ai_validation_lab` now exits 1 when pet repeat damage or post-kill pack coherence fails. Its survivor was moved out of sight of the idle pack, and it steps inside the leash for the post-kill check.
  - New `game/tests/t_ai.gd`, plus `game/tests/t_ai_cases.gd`. The cases need the Data autoload, so they are loaded on the first frame, like `run_all.gd` does.

## Acceptance checklist (exact lines; runs on 2026-10-19, load average 6-9 on the shared box)

Sweep: `--lab=wild_ai_sweep_lab` headless, run twice in a row, both ended `[aisweep] PASS`, exit 0 (logs `scratchpad/w1/ai/sweep6_1.log`, `sweep6_2.log`).

| Item | Output |
|---|---|
| All 19 species roam >= 0.5 m in 10 s | `[aisweep] roam species=19 stuck=[]` |
| Wake within 1 s with the survivor 2 m from the body | `[aisweep] wake_near species=protoceratops state=alert wake_s=0.06` |
| Sleeping herbivores wake and move >= 1 m within 10 s of dawn | `[aisweep] dawn herbivores=8 still_or_asleep=[]` |
| Lone zebraceratops chased at 5.5 m/s for 10 s: >= 8 m ahead, >= 25 m from home | `[aisweep] lone_flight ahead=10.06 from_home=58.56 avg_mps=5.86 state=flee` |
| Herbivore bitten by a pet 1.7 m away, survivor 90 m away, moves away from the pet | `[aisweep] pet_bite bitten=true away_from_pet=27.22 state=flee target_is_pet=true` |
| Protoceratops in the gathering ring = tier-5 | `[aisweep] level protoceratops ring=gathering level=15 want=15` |
| Velociraptor in the crater = tier+5+row tier_offset | `[aisweep] level velociraptor ring=crater level=33 want=33` |
| tier+5 health > tier health | `[aisweep] level_stats tier=25 hp_at_tier=643.1 hp_at_tier_plus5=900.3` |
| Raptor pack walk-out: <= 6 follower state changes, no disengage print with the overlay off | `[aisweep] pack_walkout engaged=approach follower_changes=4 trail=["attack", "attack", "approach", "approach"] debug_lines=0` (second run: `follower_changes=0`) |
| Velociraptor pet damages a triceratops and a T. rex within 8 s | `[aisweep] pet_reach target=triceratops damage=5.1 s=0.91` and `[aisweep] pet_reach target=tyrannosaurus damage=5.2 s=0.85` |
| Corpse feet gap <= 0.05 m on temperate_25 | `[aisweep] corpse species=protoceratops feet_gap=0.000` |
| 50 loot taps with a full bag give 0 XP | `[aisweep] loot_full_bag taps=50 xp_gained=0.0 level_change=0` |
| 120 creatures physics_ms_avg <= 8.0 | `[aisweep] perf creatures=120 physics_ms_avg=4.35 frames=241 budget=8.0` (second run 4.90) |
| 24 creatures physics_ms_avg <= 2.0 | `[aisweep] perf creatures=24 physics_ms_avg=1.16 frames=240 budget=2.0` (second run 1.31) |
| ai_validation_lab PASS, exits 1 on pet-repeat / post-kill failures | `[aival] PASS` (`[aival] pet_repeat damage=1.5 bites=4 cd=0.70 target_live=true`, `[aival] post_kill targets=player/player/player states=approach/approach/approach`) |
| t_ai: state_changed exactly once per transition | `[t_ai] PASS` |
| Existing suite | `[tests] PASS` (`--script res://tests/run_all.gd`) |
| Smoke | `SMOKE PASS` (`tools/smoke.sh --no-import` through gslot) |

How the sweep measures:
- Perf uses 120 mixed-species creatures in packs of three, spread 20-55 m around the survivor. All of them are inside the 60 m LOD, so every brain is live: this is the worst case, not the frozen case. The number is the average of `Performance.TIME_PHYSICS_PROCESS` over 4 s.
- Roam and dawn count the farthest distance reached from the start, not where the animal ends up.
- Every sweep creature uses average IVs (`CreatureGenetics.neutral()`) so the result does not depend on the genetics roll.
- The "was" baselines in the spec are the register's numbers. I did not re-measure the old code.

## Screenshots inspected

None. No acceptance item is visual, so I made no claim about appearance and took no windowed run.

## Assumptions (`# ASSUMPTION:` in code or data)

- `wake_m` 3.0 m from the body edge, and `woken_awake_s` 30 s (ai.json `_sleep`).
- Temperament mapping:

  | Temperament | provoke_hits | flee_speed_mult | Other | Archetypes |
  |---|---|---|---|---|
  | skittish | 3 | 1.6 | flees on sight | pack_mule, runner, antlered |
  | defensive | 1 | 1.2 | ignores you until hit | spiked_tail, club_tail, titan |
  | territorial | 1 | 1.2 | charges inside 6 m | horned_charger |

  The skittish speed was raised from the WIP's 1.5 to 1.6 so an average zebraceratops (6.4 m/s) clearly outruns a walking survivor (5.5 m/s).
- `chase_speed_mult` 0.7 for every carnivore archetype is today's value, kept until the owner answers (dino-ai-06).
- `wild_level_stat_rate` 0.08 per level above tier for health, attack and defense. At or below tier the listed stats are unchanged.
- The temporary home after a kill or a flight lasts 120 s.
- AI LOD radius is 60 m and think rate is 10 Hz (from the spec).

## Integrator hooks

- `game/tests/run_all.gd` (or `tools/test.sh`): also run `--script res://tests/t_ai.gd` and expect `[t_ai] PASS`.
- W1-LIGHT / IslandRuntime: `Spawner._row_tier_offset` finds the row's `tier_offset` by ring + species, because the runtime does not hand the row to the Spawner. Two rows of the same species in one ring with different offsets would be ambiguous. None exist today. Cleaner fix: `spawner.set_meta("tier_offset", int(row.get("tier_offset", 0)))` where island_runtime builds the Spawner. I would then read that meta first.
- Audio (W1-INT): connect `creature.brain.state_changed(prev, next)` for creature voices.

## Labs to register

- `wild_ai_sweep_lab` (`game/scripts/dev/wild_ai_sweep_lab.gd`, `game/scenes/dev/wild_ai_sweep_lab.tscn`). It runs headless in about 75 s and prints `[aisweep] PASS` with exit 0, or FAIL lines with exit 1.

## What failed or is left

- A low-IV zebraceratops (85 % speed) flees at about 5.4 m/s, and a walking survivor does catch it. That is a tuning question tied to the pending chase-speed decision.
- Perf was measured under a load average of 6-9 on the shared machine. Readings varied: an early run with a polluted order read 11.85 ms for 120 creatures. The current order loads every model before measuring.
- Per-frame animation calls (`play_locomotion` / `play_idle` every frame) are still a cost. I left them alone because `creature_anim.gd` belongs to W1-CANIM.
- `game/tests/t_ai_cases.gd` is a second new test file next to the owned `t_ai.gd`. It exists only because the cases need autoloads at compile time.
- The relayed user request in this run's harness, marking low-quality and low-poly assets for replacement, is not part of W1-AI and is not addressed here. It is asset-register work; see "Add the asset replacement register" (`1ef0c77`) on `claude/mmo-overhaul`.
