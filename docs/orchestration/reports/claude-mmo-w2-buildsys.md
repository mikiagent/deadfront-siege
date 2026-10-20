# W2-BUILDSYS: ARK-style modular building with structure HP, tiers and repair

Branch `claude/mmo-w2-buildsys`, base `claude/mmo-overhaul` merged in (last at 5d21c491, base tip 85c2b63b).
Closes build-struct-01, build-def-01, build-tier-01, build-place-02, phys-wall-01, dino-ai-17 (with the W2-ECO
hook below). Not closed: build-storage-01 (chests/large box) and build-sign-01 (sign text), see Limits.

The owner's 2026-10-20 see-through correction ("partially see through, not a clear hole") applies here
through W2-OCCLUDE: walls use its whole-object "between" fade (about half the pixels stay), roofs and
ceilings its "inside" fade (a faint outline stays). I bound to it in a scratch merge and looked at the pixels.

## What shipped

- `game/data/structures.json`: one lattice (2 m modules, 2.5 m storeys), four tiers (thatch/wood/stone/metal:
  rank, tint, creature damage multiplier 1.0/0.8/0.35/0.15, Construction level 0/5/20/35), eleven pieces
  (foundation, wall, doorway, door, window, ceiling, roof, roof ridge, pillar, stairs, ramp) with slot,
  footprint, levels, support rule, what they block, occlusion mode and XP; `piece_tiers`: 44 blueprints in the
  spec-10 section-11 shape (material_slots with role/item/quantity/counts_for_level/counts_for_attributes,
  minimum/maximum_level, required_skill_node, required_building_ability, supported_building_effects,
  max_durability, `model`). `model` is the swap point: a res:// GLB path there replaces the procedural stand-in
  for that piece and tier (`model_contract` in the file says origin, axes and scale). `placed_kinds`: durability
  and repair materials for all 24 kit kinds plus a default. Costs use bag materials only (branch, fibre_stalk,
  plank, twine, stone, iron_ingot, rope, clay); items.json and recipes.json are untouched.
- `structure_piece.gd` (StructurePiece, StaticBody3D): one piece at a slot (module x, module z, level, code:
  cell, edge x/z, corner, door x/z, on-floor, stairwell). Pose, keys, cost, durability, spec-10 instance row
  (`to_dict`: id, blueprint_id, tier, owner_id, level, inherited_attributes, max/current_durability, position,
  rotation, container_id), a type-checked `from_dict` for untrusted saves, door open/close (`interact`),
  in-place `set_tier`, `destroy` (collapses what it held). Walls, doorways, windows, closed doors and pillars
  are on layer 1|16 so creatures collide; the owning survivor gets a collision exception (HANDOFF 8: owned
  walls are passable for the player, blocking for enemies).
- `structure_grid.gd` (StructureGrid, `BuildGrid.structures`): occupancy by slot, placement rules with reason
  codes (occupied, no_support, stairwell, max_level, unclaimed, water, resource, reserved, overlap, slope,
  no_blueprint), structural support level by level with span from a supported slab (max_span 2) and
  `collapse_unsupported`, socket candidates, enemy path cells (level-0 blockers; a doorway is open, a door
  blocks while closed), `restore` / `to_rows` for saves, and roof groups (below).
- `structure_mesh.gd` (StructureMesh): the procedural stand-ins. Bevelled boxes per tier (thatch bundles,
  wood planks, stone courses, riveted metal), sill and cap bands that mark each storey, door and window
  frames, gable roofs and a ridge, stairs with stringers, a sloped skirt down to the lowest corner, box-projected
  UVs over a subtle noise grain (triplanar was dropped: W2-OCCLUDE's derived material does not replicate it).
- `structure_health.gd` (StructureHealth): durability on every piece and, lazily, on every placed kit
  (catapult, fence, workbench...). Creature damage reaches structures only through it, scaled by the tier's
  creature multiplier; at 0 a piece is destroyed and what it held collapses, a kit is freed. Camp pieces,
  the harbour and cargo are not structures. API for brains: `of`, `is_structure`, `blocker_between`,
  `siege_target(creature, goal)` (the blocking wall, only while TilePath says the goal is unreachable).
- `structure_placer.gd` (StructurePlacer) + `build_placer.gd`: the BuildPlacer API. `begin_piece(kind, tier)`
  selects; the ghost snaps to the nearest free socket that accepts the piece within `snap_radius_m`
  (pointer ray, or `aim_at(world)` for labs/tests) with green snap points on free sockets and red on refused
  ones; `rotate_clockwise()`, `confirm(player)`, `cancel()` work as for kits, so the HUD's existing
  rotate/place/cancel hexes drive pieces with no HUD change. `upgrade(target, tier, player)`,
  `repair(target, player)`, `demolish(target, player)` return bool and give a notice with the reason.
  Costs: place = blueprint; upgrade = the new tier's blueprint, same node, slot and pose, full new durability;
  repair = repair_fraction (0.5) of the blueprint x missing share (kits: their placed_kinds list x missing
  share), rounded up; demolish refunds 0.5 x health share (camp cargo takes what the bag cannot). Construction
  level gates tiers; placing gives the piece's construction XP; 8 m reach (flat).
- Roofs and the occlusion adapter: `StructurePiece._occlusion(node, mode)` is the one adapter to W2-OCCLUDE
  (`Occlusion.make_occludable(node, "between"|"inside")` / `release`), guarded by
  `ResourceLoader.exists("res://scripts/world/occlusion.gd")`; without it pieces simply stay opaque. Walls and
  pillars register per piece ("between"). Roofs and ceilings hang their look under one `RoofGroup` node per
  storey of a connected building, registered "inside": a per-piece inside fade was useless (first bound shot:
  only the 2x2 m piece overhead faded, while from the iso pitch the roof hiding an indoor survivor is the part
  nearest the camera). Pieces that bridge two groups merge them.
- `tile_path.gd`: structure cells are part of the build blockers (they were dropped on a dirty refresh);
  `path(..., for_owner)` / `path_result(..., for_owner)` give the owner's path through its own walls and doors.
- `build_grid.gd`: kits may stand fully on a foundation (on its deck height), never half on one; nothing goes
  on a resource node's cell (index built once the island has its nodes); `blocks_path(c, for_owner)`.
- `creature_attack.gd`: structure targets go through StructureHealth (the catapult too, by the same path) and
  skip the melee line check (the structure is the obstacle). `field_catapult.gd`: `receive_siege_hit` uses it.
- Saves: piece rows ride in the home/away building lists; `save_game.gd` restores pieces before kits (a kit on
  a foundation needs its floor) and keeps kit wear (`durability`). `save_migrations.gd`: schema 4 (a v3 save
  has nothing to rewrite; the step marks the version so a schema-3 build refuses a schema-4 file).
- `snap_build_lab` (+ scene) and `game/tests/t_buildsys.gd` (dsc2, below).

## Acceptance (run here, lines seen)

- **t_buildsys PASS**: `[t_buildsys] PASS` with `ok data_rows`, `ok costs`, `ok reasons cases=14`, `ok snap`,
  `ok collapse`, `ok damage_tiers`, `ok kits_and_camp`, `ok repair_upgrade`, `ok paths`, `ok rows_round_trip`,
  `ok bad_rows cases=9`, `ok migrations` (final run on 4b2da0ef; ASSUMPTION comments added after).
- **snap_build_lab** headless: `[snap] PASS`, 36 ok lines, among them `house: 52 pieces and its ramp placed
  through socket snapping (got 53)`, `every piece within 1 cm of its socket (worst 0.0000 m)` (sockets worked
  out in the lab from the lattice alone, the placer aimed 0.3-0.4 m off each), `stairs keep their stairwell
  clear`, `no ceiling over the stairs`, `the pillar still holds the ceiling`, `removing the last support
  collapses the ceiling and the wall on it (fell 2)`, `creatures collide with walls (layer 17, mask 1)`, `the
  owner walks through its own wall`, `raptor bite on the wood wall through StructureHealth: 69.0 (want 69.0)`,
  `repair took exactly 1 plank / 1 twine`, `the upgrade swaps in place (same node, same socket)`, `stone
  durability 3000`, `a creature cannot path into the closed house`, `the owner's path goes through its own
  door`, `an open door lets a creature path in`, `a creature locked out gets the blocking piece as its siege
  target (door_5_8_0_5)`, `schema 4 save holds 57 piece rows`, `load restores every piece: 57/57, 0 differ`,
  `the basket on the foundation comes back`, `a schema-3 save migrates to 4`, `the schema-3 save loads with its
  kits and no pieces`.
- **build_lab** `[build] PASS`; **siege probe** exit 0, `destroyed-after=21s occupancy-cleared=true` (the
  catapult now takes the raptor's bites through StructureHealth); **island_lab** exit 0,
  `island temperate_25 nodes=378 creatures=24` (unchanged from the merge log). Final-code reruns: see the
  gate lines at the end of this file.
- **Every test**: run_all `[tests] PASS`, SMOKE PASS, t_ai, t_build, t_buildsys, t_canim, t_combat,
  t_harbour (islands=15), t_iconart, t_items, t_light, t_lighting, t_save (its 5 deliberate SCRIPT ERRORs, as
  on base), t_structart, t_tame, t_web all PASS.
- **Wild dinosaurs attack structures that block them**: with the W2-ECO hook applied (scratch tree), a real
  velociraptor with its brain on, aggro on a survivor shut in a one-module room, retargeted the north wall and
  bit it within 2 s: `[probe] t=1 state=approach target=wall_6_9_0_2`, `[struct] wall hit dmg=74.2
  hp=1126/1200`, `[probe] PASS raptor broke into the wall` (probe script not committed; it is the hook's check).

## Screenshots inspected (scratchpad/shots/, 1600x900 windowed unless noted)

- `house_out_fwd.png` (Forward+) and `house_out_compat.png` (gl_compatibility), this branch alone: a snapped
  2-storey 3x3 house reads as a house: plank walls with posts, sill and cap bands at each storey, framed door
  and windows on both storeys, a stone ramp to the door, thatch gable roof in visible courses; same look in both
  renderers. Not grey boxes.
- With W2-OCCLUDE bound (scratch merge of `claude/mmo-w2-occlude` 22d25492 + this branch, not committed):
  `house_out_fwd_bound.png`, `house_out_compat_bound.png`: survivor outside at the door, house fully solid.
  `house_in_fwd.png`, `house_in_compat.png`: survivor inside on the ground floor; the whole roof and the upper
  floor fade to a faint dithered outline (not a hole), the two front walls between camera and survivor fade
  to about half, the survivor is visible through them, the far walls and the upper window stay solid, the
  house keeps its shadow. Same in both renderers.
- `ghost_fwd.png` and `ghost_phone_compat.png` (844x390 landscape, compat): a wood foundation ghost snapped
  beside the house, green snap points on the free cells around it, the HUD's ROTATE / PLACE / CANCEL hexes
  under it. On the phone the ghost and points read; the ghost's cost label is too small (Limits).
- One bad framing found and fixed: an outside shot that pointed the camera at a marker in the house made the
  occlusion system treat the marker as the survivor and fade the roof; the lab now always follows the survivor.

## DeepSeek workers

- **dsc1** (`claude/mmo-w2-buildsys-dsc1`, ~$0.03): typed the 36 missing blueprint rows (9 pieces x 4 tiers)
  and the 25 placed-kind rows into structures.json from formulas and a table I wrote in its TASK.md. Its
  read-only `verify_structures.sh` checked every value, key order, formatting, that only two keys changed and
  that every item exists: `VERIFY PASS (rows piece_tiers=44 placed_kinds=25)`. What I changed: took only
  structures.json from its branch (it had committed TASK.md and the verify script too), then opened thatch at
  Construction 0 (skill levels start at 0).
- **dsc2** (`claude/mmo-w2-buildsys-dsc2`, ~$0.18): wrote `game/tests/t_buildsys.gd` (12 table-driven cases)
  against `verify_buildsys.sh`, which runs it on the real code and on twelve deliberate breakages (half costs,
  no collapse, tier multiplier ignored, owner path ignored, walls not blocking, foundations on trees, bad slot
  codes loading, schema stuck at 3, free repair, downgrades allowed, camp pieces damageable, snapping from any
  distance): `VERIFY PASS (reason rows=14, bad rows=9, 12/12 mutations caught)`; I read the clean and mutation
  logs. What I changed: split its `a ; b` statement joins onto their own lines (house style) and re-ran it on
  the current code (PASS).

## Integrator hooks

Files other packages own. `docs/orchestration/reports/claude-mmo-w2-buildsys-hooks.patch` holds hooks 1-3 as
one patch; `git apply --check` passes on this branch, it compiles (import + run), and the hooked scratch tree
ran the probe above (full-suite result at the end of this file).

1. **W2-PLAYER, `game/scripts/player/player.gd`**: `signal structure_tapped(piece: StructurePiece)`; taps on a
   piece: a door toggles (`interact`), any other piece emits `structure_tapped`; `_is_interactable` accepts
   `StructurePiece`; the survivor's own click-to-move path goes through its own walls:
   `_path_points = p.path(global_position, _path_goal, 96, true)`.
2. **W1-UI / W2-HUD, `game/scripts/ui/hunt_hud.gd`**: `var _build_tier: StringName = &"thatch"` and
   `var _structure: StructurePiece`; `bind()` connects `structure_tapped` to a `&"structure"` sheet; the Build
   sheet gets a tier row (Thatch / Wood / Stone / Metal, 72x64 buttons) and one button per piece
   (`StructurePlacer.label(kind, tier)`, e.g. "Wood Wall  plank ×4 · twine ×2") calling
   `player.placer.begin_piece(kind, _build_tier)`; the structure sheet shows tier, piece and hp, and
   Upgrade to the next tier (`StructurePlacer.next_tier`), Repair with its cost (`repair_cost`) and Demolish.
   Rotate / place / cancel need nothing: the existing hexes already drive a piece ghost.
3. **W2-ECO, `game/scripts/creatures/brains/creature_brain.gd`**: every brain, in `tick()` before `_think`:
   `_break_in()` asks `StructureHealth.siege_target(creature, attack_target.global_position)` once a second and
   retargets the blocking wall; `hunting_player` and the leash treat any structure like the catapult
   (`StructureHealth.is_structure`, `not StructureHealth.of(t, true).dead`). A destroyed piece is freed, so
   `_valid_target()` ends the attack and the hunter re-acquires its prey through the gap.
4. **dsc camp worker, `game/data/props_manifest.json`** (not edited here): the four W1-STRUCTART stand-in rows
   `buildings.floor`, `buildings.wall`, `buildings.wall_doorway`, `buildings.roof` (1 m, `art_status
   "REPLACE"`) are superseded by structures.json. Set each row's `"upgrade"` to
   `"superseded: W2-BUILDSYS modular pieces live in game/data/structures.json; a Blender model swaps in at piece_tiers.<kind>.<tier>.model (2 m module, see model_contract)"`
   and `"art_status": "superseded"`. New Blender pieces need no manifest row.
5. **W2-INT, `tools/labs.txt`**: register `snap_build_lab` (headless prints `[snap] PASS`; `--shot=<png>`
   frames the house, `--snap-inside` puts the survivor inside, `--snap-ghost` stages a ghost).
6. **Already done here, outside the owned list**: `game/tests/t_save.gd` (W1-SAVE, merged) compared the
   re-saved v3 golden field by field, so the schema bump failed it on `/schema: 3.0 vs 4.0`. I added `/schema`
   to that comparison's skip list and a check that the re-save is at the current schema (3 lines). Revert it
   only together with the schema bump.
7. **W2-OCCLUDE**: nothing to change. Notes: roofs register a group node with no meshes yet and rely on
   `child_entered_tree` adoption (works on 22d25492); on a group merge the adapter calls `release` on the old
   group first so its meshes are re-adopted; the derived material warned `uv1_triplanar is not replicated`,
   which is why the stand-ins now carry UVs.

## Assumptions (# ASSUMPTION in code, or values in structures.json)

- Offline every structure belongs to the local survivor (`owner_id "local"`); W3 replaces the collision
  exception with a per-owner server check.
- Tier gates Construction 0/5/20/35, no skill node until W2-SKILLS defines one (`requires_node`).
- All numbers in structures.json are first-pass: tier HP 400/1200/3000/7000 per wall-sized piece scaled by
  piece size, creature multipliers, costs (wall: 4 primary + binding), placed_kinds durability and repair lists,
  repair_fraction 0.5, demolish_refund 0.5, snap radius 3 m, max span 2.
- Upgrade costs the new tier's whole blueprint (ARK), no credit for the old tier.
- Camp pieces, the harbour and cargo are indestructible (they are rebuilt every load anyway).
- Pieces use the kits' 8 m reach, measured flat.
- A schema-3 save needs no rewrite; schema 4 only adds piece rows and kit `durability`.

## Limits and what is left

- **Chests, the large box and sign text** (build-storage-01, build-sign-01) are not done: chests need new kit
  items and recipes, which this package may not add (W2-DATA). `container_id` is in every piece row for spec 10.
- **Spec 10 (construction quality)** is a later layer (W2-CONSTRUCT): the data is in its shape (blueprints with
  material_slots and level bounds; instances with level, inherited_attributes, max/current_durability, owner,
  container_id), but pieces are built from counted materials, level 1, no attributes, no construction sites.
- Real creatures only break walls once hook 3 lands; this branch routes the damage, the brains are W2-ECO's.
- Shortcuts in code: a roof group never splits when a middle piece goes (the halves fade together until the
  island reloads); the owner's collision exception lives on the current Player node (a re-instanced Player
  walks into its walls until the pieces reload).
- A wall blocks one row of 1 m path cells on one side of its edge, so path tests are about crossing, not about
  the exact inner cells; pets (creatures) are blocked by owned walls like wild ones.
- Stand-ins only: no Blender modular models yet (the four 1 m W1-STRUCTART stand-ins do not fit the 2 m
  lattice). The ghost's cost label (Label3D, 48 px at 0.006) is unreadable on a phone at the lab's zoom.
- The lab and test seed materials and set Construction 40 as fixtures; nothing here was earned in play.
- Godot crash report: `~/Library/Logs/DiagnosticReports/Godot-2026-10-20-131531.ips` appeared at 13:15:29
  during this session: SIGABRT in HIServices `_RegisterApplication` 47 ms after launch, before any project code,
  parent process already exited. I could not tie it to one command: my Godot launches in flight then were a
  headless `--import` in the scratch tree and a scratch probe, both through gslot, and other agents' runs share
  the same coalition. No other new .ips since the session began.
