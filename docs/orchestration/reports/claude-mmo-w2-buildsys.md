# W2-BUILDSYS: ARK-style modular building with structure HP, tiers and repair

Branch `claude/mmo-w2-buildsys`, base `claude/mmo-overhaul` merged in (last at e2320ec8, base tip 6e26ef2a:
docs only since 1c89134a, which brought W2-OCCLUDE, W1-UIICONS and DSC-CAMP). Review r1 stopped before any run.
Closes build-struct-01, build-def-01, build-tier-01, build-place-02, phys-wall-01, build-storage-01 (chest and
large box), build-sign-01 (signboard with text), dino-ai-17 (with hook 3 below).

## Contents-never-lost pass (2026-10-20 evening, finish-6)

- **Owner's question, "this vision check is too exhaustive, is it really necessary?"** For this package its two
  items were cheap and both are real, but neither needed a multi-agent audit: reading the four cited lines took
  minutes. Item 1 closed live loss paths (below). Item 2 is two numbers, and one part of it overreaches the doc
  (the flat 160, see below). The audit itself was already stopped (`vision-check.md`); nothing more was audited here.
- **Docs, checked line by line.** Spec 10:102 "A change in building state must not silently delete stored
  items." Spec 11:155 "Handle demolished stations, ... without losing items or duplicating output." PRD:582
  "Storage: baskets (~100 slots early) → boxes → large boxes (pillar requirements)". Spec 05:14 "basket about 100
  slots; level-60 Large Leaf Box up to 160 ... These are references rather than universal capacities." Spec 10:90
  "a level-60 Large Leaf Box holding 160 spaces. Do not impose this value on every box." Sign text: the specs and
  PRDs give no limit (PRD:972 names "sign flair" as a cosmetic, nothing more), so 48 characters stays an assumption.
- **Capacity (structures.json):** chest 20 -> 100, large box 40 -> 160. The chest is the "box" rung after the
  ~100-slot basket. 160 is a level-60 figure (10:90); pieces have no building level in play yet (all level 1), so
  it is flat for now: # ASSUMPTION in the file's doc, and W2-CONSTRUCT's base_capacity_at_level replaces it. The
  basket kit stays at 60 (placed_building.gd's existing assumption).
- **Nothing a structure held is deleted any more.** What was lost before (proved by running the new test on the
  old code, 24 FAIL lines such as `FAIL demolish: item l35643c0344bd7322 is kept exactly once (seen 0 times)`):
  a demolished chest's contents after its refund had filled the cargo, a destroyed chest's contents past a full
  cargo ("lost (logged)"), every item in a kit destroyed by damage (a basket's storage, a pen's animal), demolish
  refunds past a full cargo, and a chest whose save row was skipped on load. Now one function,
  `StructureHealth.salvage(stacks, at, by)`, puts them in the bag of whoever took the structure down, then home
  cargo, then a **loot bag** at the spot (`loot_bag.gd`, new: a tappable bag icon in the placed_building group, so
  the existing building tap opens it with Take all; saved as a building row `{kind: loot_bag, x, y, z, contents}`
  and restored by `SaveGame._restore_buildings`; gone when emptied; it settles on the floor still under it). A
  build without this code refunds such a row into the cargo (unknown kind), so nothing is lost there either.
  Demolish puts contents first, then the refund, in one salvage (one bag). A kit destroyed by damage gives back
  `BuildPlacer.stored_items` (split out of the pack-up returns) and, when it has one, the duck-typed
  `salvage_contents() -> Array` of ItemStack, which W2-PROCESS stations implement (they remove what they return).
  Pack-up is unchanged: `pack_up_blocker` still calls the structure's `pack_up_block_reason()` (W2-PROCESS's
  loaded-station refusal needs no change here); a chest is not a kit, so pack-up refuses it and keeps it whole.
- **t_buildsys** gains `salvage` (pack-up refused, demolish with a full bag and 2 free cargo slots, a raptor's
  bite destroying a 1 hp chest, loot bags through `_live_buildings` -> JSON -> SaveSanitizer -> restore, a chest
  row round trip, a broken chest row, a basket and a station with `salvage_contents()` destroyed by damage; every
  stamped instance counted exactly once across bag, cargo and loot bags) and `snap_resources` (a foundation ghost
  aimed at a tree, with a free socket beside it, never lands on the tree's module), and `repair_upgrade` now
  checks the upgrade takes exactly its blueprint and that one item short takes nothing. Proved: the old code
  fails `salvage` (24 lines); two mutations (no resource rule; upgrade checks but does not pay) give
  `FAIL a foundation ghost aimed at a tree is never valid on its module (try 1: )`, `FAIL no piece stands on the
  tree's module (foundation (-14, -9, 0, 0))` and `FAIL the upgrade took exactly its 8 stone (left 8)`.
- **Hook 4**: the base has no lab registry (no tools/labs.txt; main.gd loads `res://scenes/dev/<lab>.tscn` by
  name), so there is nothing to register: run it as `--lab=snap_build_lab`. The patch holds hooks 1-3, unchanged.

### Gates (this pass; scratch tree at 2c993dda, then 8d4e2ed1, hooks 1-3 applied, lines seen)

- `--import`: 0 SCRIPT ERROR / "Failed to compile". Every `game/tests/t_*.gd` PASS, 0 SCRIPT ERROR except t_save's 5
  deliberate ones: t_ai, t_build, t_buildsys, t_canim, t_combat, t_harbour (`islands=15`), t_iconart, t_items,
  t_light, t_lighting, t_occlude, t_player, t_save, t_server_domain, t_srvdom, t_structart, t_tame, t_ui, t_uiicons,
  t_web. run_all `[tests] PASS`; `tools/smoke.sh --no-import` `SMOKE PASS`. Re-run on 8d4e2ed1 (the loot bag's
  settle): `[t_buildsys] ok salvage`, `ok snap_resources`, `[t_buildsys] PASS`, snap_build_lab `[snap] PASS`.
- Labs headless, 0 SCRIPT ERROR, 0 "couldn't resolve track": snap_build_lab `[snap] PASS`, `--snap-touch`
  `[snap] PASS`, build_lab `[build] PASS`, siege probe `[siege] destroyed-after=12s occupancy-cleared=true` exit 0.
- Windowed on 8d4e2ed1, looked at each (scratchpad `bs2/`): `house_fwd.png` / `house_glc.png` (1600x900): the
  snapped 2-storey house, plank walls, storey band, framed door and windows on both storeys, ramp, gable roof; the
  same in both renderers. `inside_fwd.png` / `inside_glc.png`: roof and upper storey fade to a dithered outline,
  the front wall to about half; on gl_compatibility the survivor behind the dithered front wall is fainter than on
  Forward+ (W2-OCCLUDE's look, not changed here). Touch at 844x390 glc with `--touch`: `[snap] PASS`;
  `touch_ghost.png` (ghost, snap points, ROTATE/PLACE/CANCEL hexes, cost label), `touch_card.png` (Wood Wall
  card: Upgrade to Stone with its cost, Demolish, Building to Stone (5)), `touch_chest.png` (the bag panel opens;
  the chest's grid, now 100 slots, is below the fold as before).
- No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` (newest is still 2026-10-20-131531).
- Not done: no shot of a loot bag on the ground (it reuses the corpse's loot-bag icon; tested headless only);
  no blind A/B (the house look is unchanged from the reviewed shots).

## Finishing pass (earlier session)

- Merged the base twice (W2-PLAYER split, W1-UI HUD split, W2-OCCLUDE, W1-UIICONS). One merge fix in an owned
  file: `build_grid.gd` called `_cells_changed` (base name) where this branch has `cells_changed`; game.gd
  failed to parse until fixed.
- **Chests, large box, signboard**: three new pieces in structures.json (`slot: "on_floor"`, one per floor
  module, all four tiers). Chest 20 slots, large box 40 (`storage_slots`), signboard text up to 48 characters
  (`text_max`) drawn on the board. Contents and text ride in the piece row (`contents`, `text`,
  `container_id` = piece id) and are type-checked on load. A demolished chest's contents go to the demolisher's
  bag, then camp cargo; a collapsed or destroyed one goes to camp cargo (logged when there is none). Kits and
  furniture never share a floor module (both directions refused with `overlap`). The piece was first called
  `sign`, which is also the sign kit's kind: BuildPlacer took the kit for a piece (t_build caught it), so it is
  `signboard` and t_buildsys now fails on any piece/kit name clash.
- **Whole building**: `StructurePlacer.building_of/upgrade_all/repair_all` (+ BuildPlacer wrappers): a wall's
  card offers "Building to Stone (45) stone ×344 · plank ×88" and "Repair building", all or nothing.
- **Touch** (`structure_sheet.gd`, new): the HUD's Build sheet gets a tier row (Thatch/Wood/Stone/Metal, a locked
  tier shows its Construction level) and one two-line button per piece ("Wall / plank ×4 · twine ×2"). A tapped
  piece opens its card: Open/Close door, Open chest (n / 20 slots), signboard text field + Save text, Upgrade to
  <next tier> with cost, Repair with cost (when damaged), Demolish, and the whole-building rows. Floors, stairs
  and ramps are not tap targets (a tap there stays a move); only a direct ray hit opens a card, never the 1 m
  pick bubble (indoors every spot is within 1 m of a wall).
- **Placer for touch**: a piece ghost no longer follows the pointer (on a phone the pointer is wherever the
  last finger was, e.g. the PLACE hex, so the ghost jumped under the button). It starts one module in front of
  the survivor and moves only by taps on the world (`tap_ground` aims, then it snaps to the nearest free
  socket). The ghost's cost label scales with the orthographic camera to ~20 px on any screen (it was ~7 px on
  a 390 px tall phone) and sits 2 m up for pieces.
- **snap_build_lab --snap-touch** (`snap_touch.gd`, new): the whole loop by screen touches only
  (InputEventScreenTouch press/release at the controls' and world points): BUILD hex, tier, piece, tap ground,
  ROTATE, PLACE, CANCEL, tap a wall, Upgrade, Repair, chest Open, signboard text, Demolish, the house door's
  whole-building row. Headless it sizes the window to 844x390 (headless defaults to 64x64). It needs hooks 1-2
  and fails with `the HUD has the W2-BUILDSYS hook (open_structure)` without them.
- The lab house now also holds a chest and a signboard; its save/load check covers their contents and text.
- props_manifest.json: the four 1 m building stand-in rows' `upgrade` now points at structures.json (art_status
  stays REPLACE, t_structart requires it).

## What shipped

- `game/data/structures.json`: one lattice (2 m modules, 2.5 m storeys), four tiers (thatch/wood/stone/metal:
  rank, tint, creature damage multiplier 1.0/0.8/0.35/0.15, Construction level 0/5/20/35), eleven building pieces
  (foundation, wall, doorway, door, window, ceiling, roof, roof ridge, pillar, stairs, ramp; plus chest, large
  box and signboard from the finishing pass, 56 blueprints in all) with slot,
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

## Acceptance (run this session on 131f3210 + 23d4a548, lines seen)

- **snap_build_lab** headless: `[snap] PASS`, among its 40 ok lines: `house: 52 pieces, its ramp, a chest and a
  sign placed through socket snapping (got 55)`, `every piece within 1 cm of its socket (worst 0.0000 m)`,
  `removing the last support collapses the ceiling and the wall on it (fell 2)`, `raptor bite on the wood wall
  through StructureHealth: 86.7 (want 86.7)`, `repair took exactly 1 plank`, `the upgrade swaps in place (same
  node, same socket)`, `stone durability 3000`, `a creature cannot path into the closed house`, `the owner's path
  goes through its own door`, `a kit cannot stand on the chest's module (overlap)`, `schema 4 save holds 59 piece
  rows (got 59)`, `load restores every piece: 59/59, 0 differ`, `the chest comes back with its 7 stone`, `the sign
  comes back with its text`, `a schema-3 save migrates to 4`.
- **Touch, 844x390**: `--snap-touch` windowed at 844x390 gl_compatibility with `--touch`: `[snap] PASS` (three
  runs), and headless `[snap] PASS`; ok lines: `touch: BUILD, Wood, Foundation select a wood foundation ghost`,
  `a tap on the ground snaps the ghost`, `PLACE puts the foundation in the tapped module`, `the foundation took
  its planks`, `ROTATE turns the ghost`, `a wall placed on the tapped edge`, `a chest stands on the first
  foundation`, `tapping the wall opens its card`, `Upgrade to Stone swaps the wall in place at full stone
  durability`, `the upgrade took the stone blueprint`, `Repair brings the bitten wall back (2685 -> 3000 for
  { &"stone": 1, &"plank": 1 })`, `Open chest shows the chest's storage`, `the sign card saves its text ('Raptors
  east')`, `Demolish takes the wall down`, `the demolished wall refunds part of its stone`, `a house wall's card
  offers the whole building's upgrade (Building to Stone (45) stone ×344 · plank ×88)`. With hooks 1-2 applied
  (scratch, not committed).
- **t_buildsys** `[t_buildsys] PASS`: data_rows, costs, reasons cases=14, snap, collapse, damage_tiers,
  kits_and_camp, repair_upgrade, paths, rows_round_trip, bad_rows cases=9, migrations, furniture, building_all.
  New cases checked against three mutations, all caught: no spill on destroy (`its 5 stone come back to the
  bag (bag has 0)`), upgrade-all not all-or-nothing (`upgrade-all one item short is refused`), furniture
  ignoring kits (`a chest cannot go where a kit stands`).
- **Whole suite**, committed branch (no hooks): SMOKE PASS (`tools/smoke.sh --no-import`), run_all `[tests]
  PASS`, t_ai, t_build, t_buildsys, t_canim, t_combat, t_harbour (islands=15), t_iconart, t_items, t_light,
  t_lighting, t_occlude, t_player, t_save (its 5 deliberate SCRIPT ERRORs, as on base), t_server_domain, t_srvdom,
  t_structart, t_tame, t_ui, t_uiicons, t_web all PASS; build_lab `[build] PASS`; siege probe `destroyed-after=12s
  occupancy-cleared=true` exit 0; snap_build_lab PASS; --snap-touch FAILs as designed (no hooks).
- **Same suite with hooks 1-3 applied** (scratch): all of the above PASS, --snap-touch PASS.
- Not re-run this session: the wild-raptor break-in probe for hook 3 (its script was never committed; the hook
  is byte-identical to the one it passed with).

## Screenshots inspected (scratchpad bs/, looked at each)

- `house_fwd.png` (1600x900 Forward+), `house_glc.png` (1600x900 gl_compatibility): the snapped 2-storey 3x3
  house: plank walls with posts, storey bands, framed door and windows on both storeys, stone ramp, thatch
  gable roof in courses; same look in both renderers.
- `house_phone_glc.png` (844x390 glc, --touch): the house reads at phone size; the lab's fixture XP raises a
  level-up banner over its roof line for a few seconds (lab artefact).
- `inside_fwd.png`, `inside_glc.png`, `inside_phone_glc.png` (survivor inside, W2-OCCLUDE from the base): roof and
  upper storey fade to a dithered outline, the front walls to about half, the survivor shows through, the house
  keeps its shadow; no adapter errors. The ground-floor interior reads dark through the dithered ceiling, so the
  chest inside is not visible from outside (W2-OCCLUDE's look, unchanged here).
- Touch steps at 844x390 glc: `touch_ghost.png` (ghost with green/red snap points, ROTATE/PLACE/CANCEL hexes,
  cost label readable), `touch_card.png` (Wood Wall card: Upgrade to Stone, Demolish, Building to Stone (5), 64 px
  buttons in two columns), `touch_chest.png` (bag panel with the chest storage open), `touch_sign.png`
  (signboard and chest on the new foundations), `touch_house_card.png` (Wood Door card: Open door, Upgrade,
  Demolish, Building to Stone (45)).
- Found and fixed through the shots: the Build sheet's "No building kits" note ate the rows area on the phone
  (one row visible); a stale-frame capture (window throttled, fixed with force_draw); a first run where a wall
  in front hid the chest from the tap (the probe builds the wall on the far side now).

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

`docs/orchestration/reports/claude-mmo-w2-buildsys-hooks.patch` holds hooks 1-3 as one patch; `git apply --check`
passes on 8d4e2ed1, whose four hooked files are byte-identical to claude/mmo-overhaul 6e26ef2a, so it applies there
too. The hooked tree passed the whole suite and --snap-touch (below).

1. **W2-PLAYER, `game/scripts/player/player_input.gd`**: `interact_tap_target`: `elif col is StructurePiece:`
   find the `hud` group node and call `hud.open_structure(col)`; `is_interactable`: a `StructurePiece` is
   interactable when `is_tap_target()`; `pick_interactable`'s 1 m bubble skips `StructurePiece` (direct hits
   only). **`player_sim.gd`**: `pathing.path(p.global_position, p._path_goal, 96, true)` (the owner walks through
   its own walls and doors, HANDOFF 8).
2. **W1-UI / W2-HUD, `game/scripts/ui/hunt_hud.gd`** (+10 lines): in the `&"build"` sheet after the kit rows
   `StructureSheet.fill_build(player, func (t, cb): _sheet_btn(box, t, cb), _refresh_sheet, _close_sheet)` and
   `any = true`; a `&"structure"` sheet whose title is `StructureSheet.fill_card(box, player, btn, _close_sheet)`;
   `func open_structure(sp: StructurePiece)` sets `StructureSheet.card` and opens that sheet.
3. **W2-ECO, `game/scripts/creatures/brains/creature_brain.gd`**: unchanged from the first pass: `_break_in()`
   before `_think` retargets the blocking wall from `StructureHealth.siege_target` once a second;
   `hunting_player` and the leash treat any structure like the catapult.
4. **No registration needed**: the base has no lab registry, labs load by scene name. `--lab=snap_build_lab`
   (headless `[snap] PASS`; `--shot=<png>` frames the house, `--snap-inside` puts the survivor inside,
   `--snap-ghost` stages a ghost; `--snap-touch` runs the touch loop and needs hooks 1-2, `--snap-shots=<stem>`
   saves a PNG per touch step).
5. **Already done here, outside the owned list** (first pass): `game/tests/t_save.gd` skips `/schema` in the v3
   golden comparison and checks the re-save is at the current schema. Revert only with the schema bump.
6. **W2-OCCLUDE**: nothing to change; the adapter (`StructurePiece._occlusion`) works against the merged
   `Occlusion.make_occludable(node, "between"|"inside")` / `release`.

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
- Chest 100 slots, large box 160 flat (the level-60 reference, until building level exists); signboard 48
  characters (the docs give no limit); one piece of furniture per floor module; furniture costs and durability
  (structures.json) are first-pass.
- A structure destroyed by damage or collapse has no demolisher, so its contents skip the bag: home cargo, then a
  loot bag. A loot bag does not occupy build cells (a kit can be placed over one; the bag stays tappable).
- Whole-building actions cover pieces connected within one module and one storey; Upgrade all lifts every
  piece below the next tier to it, paid up front.

## Limits and what is left

- Floors (foundations, ceilings), stairs and ramps have no card of their own on touch (a tap there walks);
  they are upgraded and repaired through any wall's whole-building rows, but cannot be demolished one by one
  by touch.
- A piece hidden behind another (a chest behind a wall from the iso camera) takes the front piece's card; walls
  only fade when the survivor is behind them.
- The chest opens in the bag panel (inventory_ui.gd, W2-INV/W1-UI): at 844x390 the storage grid is below the
  fold and the HUD hexes draw over the panel. Signboard text is legible at 1600x900 but not at the phone's
  default zoom.
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
  lattice).
- The lab and test seed materials and set Construction 40 as fixtures; nothing here was earned in play.
- Godot crash report: `~/Library/Logs/DiagnosticReports/Godot-2026-10-20-131531.ips` appeared at 13:15:29
  during the first pass: SIGABRT in HIServices `_RegisterApplication` 47 ms after launch, before any project code,
  parent process already exited. I could not tie it to one command: my Godot launches in flight then were a
  headless `--import` in the scratch tree and a scratch probe, both through gslot, and other agents' runs share
  the same coalition. No other new .ips since the session began.
