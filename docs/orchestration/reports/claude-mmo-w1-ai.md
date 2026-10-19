# W1-AI report: wild AI that wakes, flees, levels and scales

Branch `claude/mmo-w1-ai` (from `claude/mmo-overhaul`). Commits: `f28ef5f` (WIP from the interrupted attempt, kept), `9331a9f`, `2db0176`, `956aa7e` (first report), `fac5939` (review round 1), `e42f997` (sweep LOD/no-rig fix that round 1 left uncommitted), `6bf167d` (review round 2), plus this report update. Nothing pushed or merged. Meshy credits spent: 0.

## What shipped

- **CreatureBrain** (`game/scripts/creatures/brains/creature_brain.gd`)
  - Shared `_pre_think` runs before every species `_think`: timers, the leash, night sleep, walk home and the temp-home expiry. Raptor, tyrant and base brains all go through `tick()`.
  - Sleep branch. Grazers wake at dawn, or when a survivor or pet comes within `wake_m` of the body. A woken grazer stays up `woken_awake_s`.
  - Flight runs from `attack_target` (always the last damage source), starting from the animal's own position, so the herd clamp no longer applies while fleeing.
  - A fleeing animal keeps running until the threat is past the leash. The 3 s "far" give-up now applies only to chasers.
  - One leash per pack: the alpha's ring. A leash break releases every member on that target together, and nobody re-acquires for 0.5 s (`BrainFlight.REACQUIRE_HOLD_S`).
  - Flight, the leash, walk-home and the temporary home live in `BrainFlight` (`brain_flight.gd`), a component each brain owns as `brain.flight` (public surface: `track`, `fresh`, `leash_break`, `let_go`, `end`, `walk_home`, `flee`, `set_temp_home`, `tick_home`, `can_reacquire`, `reacquire_at`, `home_until`). Night sleep and the LOD freeze are in `BrainRest`, pack lookups in `PackIndex`.
  - Alert and attack facing turn every physics frame (`_face_target`), at the old 60 Hz rates, instead of inside the 10 Hz think (which snapped alert turns and slowed bite tracking 6x).
  - Temperaments (skittish, defensive, territorial) come from `ai.json` and are merged default -> temperament -> archetype.
  - Idle pack slots are sized from real body radii. Reach is measured to the target's capsule (`reach_to`, `_size_excess`), so pets and wild animals can bite giants.
  - The post-kill and post-flight `spawn_home` is temporary and reverts after 120 s.
  - Every `[ai]` print goes through `_log`, which prints only with `Game.debug_overlay`. (The `debug_lines` counter is gone: it only counted when the overlay was on, so the check on it could not fail.)
  - `signal state_changed(prev, next)` is emitted once per transition in `_set_state`. This is the audio hook.
  - Think rate is 10 Hz, staggered by a random phase (`_should_think(frame)`). Idle (roam/sleep) brains farther than 60 m from every player freeze. Pets, combat and scenes with no player never freeze.
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
  - `ai.json`: `chase_speed_mult` 0.7 per carnivore archetype (today's value, pending the owner's decision), `flee_speed_mult`, `wake_m`, `woken_awake_s`, a `temperaments` block, a temperament for each grazer archetype, and skittish `flee_min_mps` 6.5 (a flee speed floor; `creature.gd` applies it before statuses and traps, so a snared grazer is still slowed).
  - `rules.json`: `wild_level_stat_rate`.
- **Labs and tests**
  - New `wild_ai_sweep_lab` (scene + script). The walk-out "no [ai] print" check registers a `Logger` (`OS.add_logger`) and counts real engine output lines starting with `[ai]`; a probe line proves the logger sees output. Lone flight runs at average IVs and at the worst IVs (all 0). Perf reports the median of five 1 s windows and the machine load average.
  - `ai_validation_lab` now exits 1 when pet repeat damage or post-kill pack coherence fails. Its survivor was moved out of sight of the idle pack, and it steps inside the leash for the post-kill check.
  - New `game/tests/t_ai.gd` (one file; the cases run on the first frame that has the Data autoload). Cases: state_changed once per transition, profile merge, level scaling, solo spawn and tame pack, leash for all 19 species, hit beyond the leash flees, hit while asleep stays awake, temp home expires, pack slots clear bodies, re-acquire hold (not before 0.5 s, yes after), think rate (raptor 10 of 60 frames, tyrant windup 60 of 60), worst-IV flee speed >= 6 m/s.

## Acceptance checklist (exact lines, HEAD `6bf167d`, 2026-10-19)

Sweep: `--lab=wild_ai_sweep_lab` headless through gslot, three runs after the round-2 changes (logs in `scratchpad/w1/ai/`):
- `sweep_r2_1.log`: exit 1, `[aisweep] FAIL lone zebraceratops (worst IVs) flight ahead=7.52 from_home=56.03 (want >= 8, >= 25)` with `flee_min_mps` 6.2. Raised to 6.5.
- `sweep_r2_2.log`: exit 1, `[aisweep] FAIL 24 creatures physics_ms_avg=3.45 > 2.0 (load { 6.15 4.04 5.75 })`. Every other check passed. The windows were `[2.61, 4.31, 3.64, 3.45, 2.07]`; the same code read 0.98 and 1.00 on the runs before and after, so I read this as box load (Blender at 100 % CPU at the time), not the code. No code change between r2_2 and r2_3.
- `sweep_r2_3.log`: exit 0, `[aisweep] PASS`. All lines below come from this run.

| Item | Output |
|---|---|
| All 19 species roam >= 0.5 m in 10 s | `[aisweep] roam species=19 stuck=[]` |
| Wake within 1 s with the survivor 2 m from the body | `[aisweep] wake_near herbivores=9 worst_s=0.12 slow=[]` |
| Sleeping herbivores wake and move >= 1 m within 10 s of dawn | `[aisweep] dawn herbivores=9 still_or_asleep=[]` |
| Hurt grazer (asleep, shot from 8 m; by day, shot past the leash) flees | `[aisweep] hurt_flight case=asleep_8m slept=true away=18.53 state=roam trail=["sleep", "alert", "flee", "roam"]` and `[aisweep] hurt_flight case=day_past_leash slept=false away=18.07 state=roam trail=["roam", "alert", "flee", "roam"]` |
| Lone zebraceratops chased at 5.5 m/s for 10 s: >= 8 m ahead, >= 25 m from home | `[aisweep] lone_flight ivs=avg speed_mult=1.005 ahead=10.58 from_home=59.09 avg_mps=5.91 state=flee` and `[aisweep] lone_flight ivs=worst speed_mult=0.850 ahead=10.69 from_home=59.19 avg_mps=5.92 state=flee` |
| Herbivore bitten by a pet 1.7 m away, survivor 90 m away, moves away from the pet | `[aisweep] pet_bite bitten=true away_from_pet=27.73 state=flee target_is_pet=true` |
| Authored hit_react plays | `[aisweep] hit_react species=10 played=9 missed=[] no_rig=["stegosaurus"]` (stegosaurus always gets the stand-in body, `creature_view.gd` force_safe_placeholder, so there is no rig to play it on) |
| Protoceratops in the gathering ring = tier-5 | `[aisweep] level protoceratops ring=gathering level=15 want=15` |
| Velociraptor in the crater = tier+5+row tier_offset | `[aisweep] level velociraptor ring=crater count=4 row_tier_offset=3 wrong=[]` |
| tier+5 health > tier health | `[aisweep] level_stats tier=25 hp_at_tier=643.1 hp_at_tier_plus5=900.3` |
| Raptor pack walk-out: <= 6 follower state changes, no `[ai]` print with the overlay off | `[aisweep] pack_walkout engaged=approach follower_changes=4 trail=["attack", "attack", "approach", "approach"] ai_lines=0 logger_probe=true` |
| Velociraptor pet damages a triceratops and a T. rex within 8 s | `[aisweep] pet_reach target=triceratops damage=4.4 s=0.75` and `[aisweep] pet_reach target=tyrannosaurus damage=4.2 s=0.78` |
| Corpse feet gap <= 0.05 m on temperate_25 | `[aisweep] corpse species=protoceratops killed=roaming feet_gap=0.000` and `[aisweep] corpse species=utahraptor killed=standing feet_gap=0.001` |
| 50 loot taps with a full bag give 0 XP | `[aisweep] loot_full_bag taps=50 xp_gained=0.0 level_change=0` |
| AI LOD: idle brains beyond 60 m freeze | `[aisweep] lod near45_moved=4.27 far80_moved=0.00` |
| 120 creatures physics_ms_avg <= 8.0 | `[aisweep] perf creatures=120 physics_ms_avg=4.27 (median of [4.31, 4.71, 4.27, 4.13, 3.94]) frames=301 budget=8.0 load={ 3.22 3.74 5.36 }` |
| 24 creatures physics_ms_avg <= 2.0 | `[aisweep] perf creatures=24 physics_ms_avg=1.00 (median of [1.03, 1.02, 0.96, 1.00, 0.82]) frames=301 budget=2.0 load={ 3.27 3.76 5.39 }` (see r2_2 above for the loaded-box FAIL) |
| ai_validation_lab PASS, exits 1 on pet-repeat / post-kill failures | `[aival] PASS` (`[aival] pet_repeat damage=1.2 bites=3 cd=0.80 target_live=true`, `[aival] post_kill targets=player/player/player states=approach/approach/approach`, `[aival] radius_deaggro=true state=disengage target=<null>`) |
| t_ai (state_changed once per transition, re-acquire hold, think rate, worst-IV flee speed, and the rest) | `[t_ai] PASS` (exit 0) |
| Existing suite | `[tests] PASS` (`--script res://tests/run_all.gd`, exit 0) |
| Smoke | `SMOKE PASS` (`tools/smoke.sh --no-import` through gslot, exit 0) |

How the sweep measures:
- Perf uses mixed-species creatures in packs of three, spread 20-55 m around the survivor. All of them are inside the 60 m LOD, so every brain is live: this is the worst case, not the frozen case. The number is the median of five 1 s averages of `Performance.TIME_PHYSICS_PROCESS`, printed with `sysctl vm.loadavg`.
- Roam and dawn count the farthest distance reached from the start, not where the animal ends up.
- Sweep creatures use average IVs (`CreatureGenetics.neutral()`) except the worst-IV lone flight.
- The "was" baselines in the spec are the register's numbers. I did not re-measure the old code.

## Review round 2 (findings and what changed)

| Finding | Outcome |
|---|---|
| blocker: committed sweep failed (hurt grazer at 200 m beyond the LOD; stegosaurus counted as a miss) | Fixed in `e42f997`: survivor at 40 m, wait for `using_glb`, no-rig species listed as `no_rig`, `played > 0 and missed.is_empty()`. Lines above. |
| blocker: `debug_lines == 0` could not fail | Fixed: a `Logger` counts real `[ai]` output; a probe line must be seen (`logger_probe=true`) so 0 is meaningful. `debug_lines` deleted. |
| major: report described 956aa7e | Rewritten against `6bf167d`; `t_ai_cases.gd` note dropped (it was folded into `t_ai.gd` in `fac5939`); spawner already reads the `tier_offset` meta, so that hook is now "set the meta". |
| major: low-IV zebraceratops caught | Fixed with skittish `flee_min_mps` 6.5 rather than a higher multiplier (a multiplier would also speed up the 9 m/s runner). 6.2 was not enough in practice (7.52 m ahead, path wiggle costs speed). Sweep case at all-0 IVs added, plus a t_ai speed check. |
| minor: 10 Hz facing snaps / slows bite tracking | Fixed: `_face_target` turns every physics frame at the old rates. Not checked in pixels. |
| minor: creature_brain.gd grew | Flight/leash/temp home moved to `BrainFlight` (own state, owned component). creature_brain.gd is now 666 lines (base 613, was 759); creature.gd 854 (base 812). BrainRest stays a set of static helpers; it and BrainFlight still read brain fields such as `_valid_target()`, `_set_state()` and `profile`. |
| minor: no direct assertion for re-acquire hold, 10 Hz, tyrant full rate | Added t_ai `_test_reacquire_hold` and `_test_think_rate`. |
| minor: taming_pen.gd bypasses `_set_state` | Integrator hook below. |
| minor: perf headroom | Median of five windows plus load average in every perf line. It still failed once under load (r2_2), recorded above. |

## Screenshots inspected

None. No acceptance item is visual, so I made no claim about appearance and took no windowed run.

## Assumptions (`# ASSUMPTION:` in code or data)

- `wake_m` 3.0 m from the body edge, and `woken_awake_s` 30 s (ai.json `_sleep`).
- Skittish `flee_min_mps` 6.5 m/s: the flee speed floor, so a worst-IV grazer still outruns a walking survivor. Below about 1.01 speed IV, skittish flight speed no longer depends on the speed IV.
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
- W1-LIGHT / IslandRuntime: where island_runtime builds a Spawner from a spawn row, add `spawner.set_meta(&"tier_offset", int(row.get("tier_offset", 0)))`. `Spawner._row_tier_offset` already reads that meta first; without it, it falls back to looking the row up by ring + species, which is ambiguous only if one ring has two rows of the same species with different offsets (none today).
- W1-TAME / `game/scripts/world/taming_pen.gd:141`: replace `c.brain.state = &"flee"` with `c.brain._set_state(&"flee")` so `state_changed` (the audio hook) sees that transition.
- Callers outside W1-AI that used brain internals moved to `brain.flight`: `raptor_pack_brain.gd` and `ai_validation_lab.gd` are updated here. Anyone else calling `_disengage_track`, `_set_temp_home`, `_home_until` or `_reacquire_at` must use `brain.flight.track / set_temp_home / home_until / reacquire_at` (a grep of the branch found no other callers).
- Audio (W1-INT): connect `creature.brain.state_changed(prev, next)` for creature voices.

## Labs to register

- `wild_ai_sweep_lab` (`game/scripts/dev/wild_ai_sweep_lab.gd`, `game/scenes/dev/wild_ai_sweep_lab.tscn`). It runs headless in about 75 s and prints `[aisweep] PASS` with exit 0, or FAIL lines with exit 1.

## What failed or is left

- The 24-creature perf budget (2.0 ms) failed once in three round-2 runs, at load 6.15 with Blender pinning a core (median 3.45 ms). The other runs read 0.98 and 1.00 ms. The median-and-load line makes such a FAIL easy to judge; I did not raise the budget.
- Facing changes were checked by code and tests only, not in pixels.
- Per-frame animation calls (`play_locomotion` / `play_idle` every frame) are still a cost. I left them alone because `creature_anim.gd` belongs to W1-CANIM.
- `BrainRest` and `BrainFlight` read brain fields with leading underscores; a proper public brain surface would touch every species brain and is left for wave 2.
