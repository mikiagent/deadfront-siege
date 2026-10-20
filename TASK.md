# TASK: write game/tests/t_buildsys.gd (table-driven tests for modular building)

## Why
DEADFRONT (Godot 4.7.1, typed GDScript, project in `game/`) has a new ARK-style building system:
modular pieces (foundation, wall, doorway, door, window, ceiling, roof, roof_peak, pillar, stairs,
ramp) in four tiers (thatch, wood, stone, metal) that snap to sockets on a 2 m lattice, with
durability, creature damage, repair, in-place upgrade, collapse of unsupported pieces, owner-only
paths through walls, and save schema 4. The reviewer (Claude) wrote the system; you write its
test. The test is the guard every later package runs, so it must FAIL when the system breaks, not
only pass when it works. `./verify_buildsys.sh` is the spec (read-only): it runs your test on the
real code and then on twelve deliberately broken copies of the system, and each broken copy must
make your test fail.

## Read first (do not edit any of them)
- `game/data/structures.json` (every number: module_m 2.0, storey_m 2.5, snap_radius_m, tiers with
  rank/creature_mult/requires_level, pieces, piece_tiers blueprints, placed_kinds, repair_fraction,
  demolish_refund).
- `game/scripts/world/structure_piece.gd` (class StructurePiece): slot codes CELL 0, EDGE_X 1,
  EDGE_Z 2, CORNER 3, DOOR_X 4, DOOR_Z 5, ON_FLOOR 6, STAIRWELL 7; static `defs()`, `piece_def`,
  `tier_def`, `blueprint`, `is_piece_kind`, `tier_rank`, `cost(kind, tier) -> {item: count}`,
  `max_durability`, `placed_kind`, `pose`, `make(kind, tier, slot, rot, floor0, variant)`,
  `from_dict(row)` (returns null for a malformed row); instance `to_dict()`, `health`, `tier`,
  `slot`, `rot`, `floor0`, `door_open`, `set_door_open`, `interact`, `set_tier`, `destroy`.
- `game/scripts/world/structure_grid.gd` (class StructureGrid, reached as
  `World.runtime.build_grid.structures`): `check(kind, slot, rot, tier) -> {reason, floor0, ...}`,
  `register`, `piece_at`, `pieces`, `collapse_unsupported`, `blocks_cell`, `path_blocked_cells`,
  `restore`, `to_rows`, static `module_of`, `module_cells`, `neighbours`, `cell_edges`.
- `game/scripts/world/structure_health.gd` (class StructureHealth): `of(node, create)`,
  `is_structure`, `take_damage`, `hp`, `max_hp`, `missing`, `heal_full`.
- `game/scripts/world/structure_placer.gd` (class StructurePlacer): `snap`, `place`, `upgrade`,
  `repair`, `demolish`, `repair_cost`, `tier_gate`, `can_pay`, `pay`.
- `game/scripts/world/build_placer.gd`: `begin_piece(kind, tier)`, `aim_at(world)`,
  `rotate_clockwise()`, `confirm(player)`, `cancel()`, `upgrade/repair/demolish(target, ..., player)`,
  `valid`, `reason`, `piece_at` (the last snap result), `rot_step`, `reason_text(code)`.
- `game/scripts/world/tile_path.gd`: `path(from, to, max_len, for_owner)`, `last_reachable`.
- `game/scripts/combat/creature_attack.gd`, `game/scripts/world/field_catapult.gd`,
  `game/scripts/core/save_migrations.gd` (`migrate`, `CURRENT_SCHEMA` is 4).
- The worked example of everything above: `game/scripts/dev/snap_build_lab.gd` (run it with
  `--lab=snap_build_lab`, it prints `[snap] PASS`). Copy its set-up (LabKit, home_grassland, the
  claim fixture, `_find_site`, `_snap_place`) instead of inventing your own.
- House style for SceneTree tests: `game/tests/t_build.gd` (how it waits for autoloads, loads the
  island with LabKit and `World.load_island`, and frees what it made).

## What to write: ONE file, `game/tests/t_buildsys.gd`
- `extends SceneTree`, a `## ` header saying what it checks and the run line
  (`Godot --headless --path game --script res://tests/t_buildsys.gd`).
- Wait in `_process` until `root.get_node_or_null("Data")` exists, then run every case once,
  print `[t_buildsys] PASS` and `quit(0)`, or one `[t_buildsys] FAIL <what>` line per failure and
  `quit(1)`.
- NEVER name game classes at parse time and never use them as static types (the verify greps for
  `StructurePiece.` etc. and for `: StructurePiece` / `as StructurePiece`). Inside functions:
  `var SP: GDScript = load("res://scripts/world/structure_piece.gd")`, then `SP.cost(&"wall", &"wood")`,
  `SP.CELL`, `SP.make(...)`; reach the grid as `root.get_node("World").runtime.build_grid.structures`;
  type variables as `Node`, `Object` or `Variant`.
- Island set-up (once, before the cases): LabKit floor/player/camera on a host Node3D (as t_build),
  `World.home_terrain = &"meadow"`, `World.load_island(host, &"home_grassland", Vector3(0, 1, 12), false)`,
  free the LabKit "Floor", await a few frames, set `player.skills.trees["construction"]["level"] = 40`,
  set `build_grid.ignore_distance = true`, and claim a test area the way snap_build_lab does
  (append Rect2i rects to `World.runtime.claims`). Seed materials with
  `load("res://scripts/dev/lab_kit.gd").give(player, id, n)`; empty an item from the bag with
  `player.inventory.consume(id, player.inventory.count_of(id))`.
- One function per case with exactly these names, each printing `[t_buildsys] ok <name without
  _test_>` (for example `[t_buildsys] ok data_rows`) when it passes. Cases that report a table size
  print it on that line (`[t_buildsys] ok reasons cases=14`).
  1. `_test_data_rows`: every key of `pieces` has a blueprint for every tier; `tier_rank` is 0,1,2,3
     for thatch..metal; `max_durability` strictly increases with rank for every piece; every
     material item exists in `Data.items`; every kit kind (each `place_as` in `Data.items`) has a
     `placed_kinds` row or falls back to `default`.
  2. `_test_costs`: a TABLE of at least 8 (kind, tier, expected cost dict) rows written out by hand
     from structures.json (e.g. wall/wood = {plank: 4, twine: 2}, foundation/stone = {stone: 12,
     plank: 3}, door/metal = {iron_ingot: 2, stone: 2}, roof/thatch = {branch: 4, fibre_stalk: 4},
     ramp/wood = {plank: 3, twine: 2}); `SP.cost` must equal each exactly. Then place one wood wall
     on a wood foundation through the placer with exactly that cost in the bag and check the bag
     holds none of it afterwards; with one plank short, `confirm` must return false and place nothing.
  3. `_test_reasons`: a TABLE (Array of Dictionaries) of at least 12 placement situations and the
     exact `check()` reason each gives: "" for a valid foundation; "occupied" (same slot twice);
     "no_support" (wall on bare ground, ceiling with no wall under it, door with no doorway, roof
     floating); "max_level" (a wall at level 6); "stairwell" (ceiling over stairs); "unclaimed"
     (a cell outside every claim); "water" (find a water cell by scanning `World.runtime.spawn_ok`
     as build_lab's `_find_water_probe_cell` does, and claim it first); "resource" (the module under
     a HarvestNode from the "harvest" group, claimed first); "reserved" (a module holding one of
     `build_grid.reserved_cells()`); "no_blueprint" (an unknown kind). Print `ok reasons cases=N`.
  4. `_test_snap`: with a foundation down, `begin_piece(&"wall", &"wood")` and `aim_at` points 0.3 m
     off each of its four edge midpoints: `piece_at["slot"]` is that edge each time and `valid` is
     true; aiming 10 m from any piece gives `valid == false`; `rotate_clockwise()` changes
     `rot_step` and an oriented piece (ramp, roof) keeps that rotation after `confirm`.
  5. `_test_collapse`: a TABLE of small structures (built through `register` or the placer) and the
     number of pieces that fall when one support is destroyed: foundation + wall + ceiling + upper
     wall, destroy the wall -> 2 fall; same with a pillar on the far corner -> 0 fall, then destroy
     the pillar -> 2 fall; a ceiling spanning one module from a supported ceiling stays, and falls
     with it when that one goes; destroying a doorway drops its door.
  6. `_test_damage_tiers`: for each tier, a wall of that tier takes `amount * creature_mult` from
     `StructureHealth.take_damage(amount)` (thatch 1.0, wood 0.8, stone 0.35, metal 0.15 from
     structures.json); a velociraptor (spawn with a Spawner as snap_build_lab does, brain and
     physics off) biting a wall through `creature.apply_species_on_hit(&"attack_primary", wall)`
     lowers its hp; enough damage destroys the wall (queued for deletion) and the ceiling it alone
     held collapses.
  7. `_test_kits_and_camp`: a placed fence (kit) gets a StructureHealth from `of(node, true)` with
     `max_hp` = its `placed_kinds` max_durability; a raptor bite lowers it; a camp piece
     (`persist_building == false`) and cargo (`is_cargo == true`) are not structures (`of(node, true)`
     returns null); a catapult hit through `receive_siege_hit` lowers the catapult's own `hp` and
     destroys it at 0.
  8. `_test_repair_upgrade`: damage a wood wall by a known amount; `repair_cost` equals
     ceil(blueprint qty * repair_fraction * missing / max) per item; repair with one item short is
     refused and changes nothing; with the exact cost it restores full hp and leaves none of it in
     the bag; upgrade wood -> stone with the stone cost keeps the same node (instance id), slot and
     position and gives stone max durability; stone -> wood and stone -> stone are refused
     ("not_higher"); thatch is allowed at Construction 0 but stone is refused ("locked") at 0.
  9. `_test_paths`: a closed ring of four level-0 walls around one foundation (or a 2x2 room with a
     doorway and a closed door): `TilePath.path(outside, inside)` gives `last_reachable == false`;
     with `for_owner = true` it is true; right after the owner query the creature path is closed
     again; opening the door (`interact`) makes it reachable; the cells of a level-1 wall never
     block (`blocks_cell` false).
  10. `_test_rows_round_trip`: for a TABLE of pieces (every kind at least once, several tiers, a
      damaged one, an open door, rotations 0-3), `to_dict()` then `from_dict()` gives the same kind,
      tier, slot, rot, floor0, hp and door state; `structures.restore(rows, runtime)` rebuilds them in
      the grid and drops a piece whose support row is missing.
  11. `_test_bad_rows`: a TABLE of at least 8 malformed rows that `from_dict` must reject (return
      null): unknown kind, missing position, position of 3 numbers, a string in position, slot code
      7 (STAIRWELL), slot code 9, a coordinate of 1e9, kind not a string. And rows it must accept
      with clamping: tier "gold" becomes thatch, current_durability 1e9 clamps to max, level 999
      clamps to 60. Print `ok bad_rows cases=N` (N = rejected rows).
  12. `_test_migrations`: `SaveMigrations.migrate` takes a schema 0, 1, 2 and 3 dict to schema 4 and
      keeps their building rows; schema 5 is rejected (empty dict); `CURRENT_SCHEMA == 4`.
- Free every node you create; between cases demolish or `destroy()` the pieces you placed so cases
  do not see each other's structures (or build each case on its own spot inside the claim).
- Keep the file under 700 lines, typed GDScript, short why-comments only.

## Rules
- Edit ONLY `game/tests/t_buildsys.gd`. Never edit the building system, the lab, structures.json,
  run_all.gd, TASK.md or verify_buildsys.sh. If a case cannot pass on the real code, write what you
  saw in `DSC_NOTES.md` (one short paragraph per problem) and keep the case honest; do not weaken it.
- Run Godot ONLY through
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh`,
  with a timeout, never with --editor, for example:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 300; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_buildsys.gd`
  It plays no sound; never play audio any other way.
- Milestones: (1) set-up + cases 1-4 pass on the real code; (2) cases 5-9; (3) cases 10-12; (4)
  `./verify_buildsys.sh` prints `VERIFY PASS` (it takes about 10 minutes: 13 Godot runs).
- Commit only game/tests/t_buildsys.gd (and its .uid if Godot made one) with a clear message ending
  with the line `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`. Never commit TASK.md,
  verify_buildsys.sh, DSC_NOTES.md, .dsc/ or .dsc.json. Do not push.
- Done = `./verify_buildsys.sh` exits 0 and prints `VERIFY PASS`.
