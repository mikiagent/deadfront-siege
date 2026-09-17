# Cursor milestone M1 — creature runtime

Bring creatures to life on the clip contract, working first with placeholder meshes so you are never blocked on art. When the art agent delivers `game/assets/creatures/<species>/` files, the same scene must pick them up with no code change.

## Read first
- `AGENTS.md`, `docs/orchestration/plan.md`, your M0 report
- `game/data/creatures/SCHEMA.md` — the contract. Clip names, per-clip files under `anim/`, the +Z/-Z rule, `height_meters`.
- `docs/prd/dinosaur-roster-and-3d-pipeline.md` §2.1 (theropods), §4.5 (clip contract), and `docs/prd/durango-wild-lands-systems-prd.md` §11.2–11.3 (AI, archetypes)
- `game/data/creatures/velociraptor.json`, `deinonychus.json`, `utahraptor.json`

## Tasks

1. **CreatureDef** Resource built by `Data` from each JSON: species, rig, tier, archetype, stats (hp, attack, defense, speed), status_applied, capture_tier, tameable, height_meters, real_length_m, variants. Speed in JSON is Durango-scale (400–700); expose `move_speed_mps = speed / 100.0` and mark it `# ASSUMPTION:`.

2. **Creature scene** `scenes/creatures/creature.tscn` (`scripts/creatures/creature.gd`, `class_name Creature`): CharacterBody3D + CollisionShape3D sized from `height_meters`/`real_length_m` + NavigationAgent3D + `CreatureView` child + `Health` component + `CreatureBrain` child. `spawn(def: CreatureDef, variant := &"")` configures everything. Print `[creature] <species> spawned pack=<id>`.

3. **CreatureView** (`scripts/creatures/creature_view.gd`): a Node3D rotated 180 degrees on Y (SCHEMA §3). On setup, if `res://assets/creatures/<species>/<species>.glb` exists, instantiate it; otherwise build a placeholder from primitives (a capsule body lying horizontal, a box head, a long tapered tail, two leg cylinders) scaled from the def and tinted per species. Check the imported model's AABB height against `height_meters` and print a `[creature]` warning outside 15%.

4. **Clip loader** (`scripts/creatures/creature_clips.gd`): for each name in the contract, load `res://assets/creatures/<species>/anim/<name>.glb` if present, take the animation from its AnimationPlayer, verify every track path resolves against the main model's Skeleton3D (log `[creature] missing bone <path>` instead of crashing), and add it under that clip name into one AnimationLibrary on the creature's AnimationPlayer. If the rig GLB already embeds `walk`/`run`, keep those. For the placeholder, synthesize simple procedural Animations (idle bob, walk/run leg swing at different rates, attack lunge, heavy attack with a 0.6 s hold then lunge, hit flinch, knockdown tilt-to-side-and-hold, death collapse, alert head raise) so the state machine is fully exercised without art.

5. **AnimationTree** state machine (`scripts/creatures/creature_anim.gd`): states idle, locomotion (1D blend walk→run on speed), attack_primary, attack_heavy, hit_react, knockdown (holds last frame until `release_knockdown()`), death (holds), alert. Expose signals `attack_windup(clip)`, `attack_hit(clip)`, `attack_done`, `knockdown_started`, `knockdown_ended`, `died`. `attack_hit` fires from an animation method track or a time fraction per clip stored in `game/data/creatures/anim_events.json` (default: 0.55 of the clip); `attack_windup` fires at clip start for `attack_heavy`. Combat in M2 keys the telegraph and the roll window to these.

6. **Brains** (`scripts/creatures/brains/`): `CreatureBrain` base with states roam, alert, chase, attack, flee, downed, dead, and a `perception` radius from tier. `RaptorPackBrain` (archetypes `raptor_pack`, `apex_raptor`): one leader per pack, members take flank slots at ±60 degrees and 3 m around the target, `attack_heavy` (the pounce) when 4–7 m away and off cooldown, `attack_primary` in melee range, flee below 30% HP, regroup on leader. Pack aggro: hitting one alerts the pack. Use NavigationAgent3D for all movement; no direct position writes.

7. **Health** component: `max_hp` from stats, `take_damage(amount, source)` → `hit_react` unless mid-attack; at zero → `death`, brain dead, collision layer off, leaves a `Corpse` node (M4 butchers it).

8. **Spawner** `scenes/world/spawner.tscn`: species, count, radius, pack toggle.

9. **Lab** `scenes/dev/creature_lab.tscn`: floor with navmesh and the markers as obstacles, player, spawner with 3 velociraptors as a pack, one deinonychus, one utahraptor. Keys 1–9 force a clip on the nearest creature (1 idle, 2 walk, 3 run, 4 attack_primary, 5 attack_heavy, 6 hit_react, 7 knockdown, 8 death, 9 alert); F deals 100 damage to the nearest; a 3D label over each creature shows brain state and current clip.

## Acceptance
- `tools/smoke.sh` passes.
- With no GLB files present, the lab runs on placeholders and all nine clips are reachable by key.
- If GLBs are present (check `game/assets/creatures/*/`), real meshes load facing the correct way (a creature walking toward +X in world faces +X), and any missing clip logs one clear line and falls back to idle.
- The raptor pack chases the player, flanks, pounces, and disengages at low HP. Run with `run_project` and read `get_debug_output`; paste the relevant lines into your report.
- Write `docs/orchestration/reports/cursor-M1-creature-runtime.md`.
