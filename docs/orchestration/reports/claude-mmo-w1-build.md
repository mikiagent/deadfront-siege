# W1-BUILD report: building correctness

Branch `claude/mmo-w1-build` (work tree `.claude/worktrees/mmo-w1-build`), cut from `claude/mmo-overhaul` at `ea2d167`.
No credits spent. Only files the spec owns were edited, plus the new `game/tests/t_build.gd`.

## What shipped

- **Every kit places.** `BuildPlacer.kit_for(kind)` reads the kit from `items.json` `place_as`, so the
  24 kits route without a hand-kept table. `_spawn` now builds `steamer` (CraftStation) and
  `field_small` / `field_large` (FieldPlot). `_kit_id()` stays as a wrapper for `run_all.gd`.
- **Pay after spawn.** `confirm()` checks the runtime and the kit, spawns, and only then spends the
  kit. A spawn failure leaves the bag alone. The pre-kit raw-material costs (pen, bonfire,
  workbench, drying rack) moved into one `_RAW_COST` table with the same numbers.
- **One shared pack-up.** `BuildPlacer.pack_up_node(node, player)` handles every placed kind. It
  returns the kit plus basket contents and a pen's occupant, all or nothing, using a dry run on a
  copy of the bag (`BuildPlacer.fits_in_bag`). When it refuses, the structure and the bag stay
  exactly as they were. Every class I own got a one-line `pack_up(player) -> bool`
  (PlacedBuilding, CraftStation, Bonfire, FieldPlot, FieldCatapult). FieldCatapult used to have no
  `pack_up` (the shift-tap script error). Kind rules live on `pack_up_block_reason()`: used bedding,
  a lit campfire, a damaged catapult or a planted field refuse. Camp pieces and cargo always refuse.
- **Manual rotation sticks.** Fence/gate auto-alignment runs only until the player rotates, and
  never while a building is being moved in layout mode.
- **Gates.** `PlacedBuilding.gate_open` saves as `"open"` in `to_dict`/`from_dict`.
  `interact(player)` toggles it (ready for W2-PLAYER). Open moves the body to collision layer 2,
  which is tap-only, so it can still be tapped shut. Closed puts it back on layer 1. Either change
  re-flags the gate's TilePath cells at once. A plank leaf sits in the Kenney fence-doorway opening
  and swings out when the gate opens.
- **TilePath builds once.** Terrain walkability and weights are sampled in `setup()`. After that:
  - `BuildGrid` occupy/release/reserve calls `TilePath.update_cells(cells)` and re-flags only those
    cells, keyed by Vector2i.
  - A bare `mark_dirty()` (harvest nodes depleting or regrowing, occupancy cleared) makes the next
    `path()` diff the harvest and build blocker sets and re-flag only the cells that changed.
  - `path()` sets `last_reachable`, which is false when the route stops short of the goal.
  - A path cut off at `max_len` no longer jumps its last point straight to the goal.
  - `BuildGrid.blocks_path(cell)` treats an open gate as passable.
- **Player-facing reasons.** `BuildPlacer.reason_text(code)` turns `too_far`, `reserved`,
  `overlap`, `unclaimed`, `water`, `slope`, `missing_kit` and `spawn_failed` into short sentences.
  Notices and the ghost label use them. The ghost label is now 48 px at 0.006 m/px (it used to be
  32 px at 0.005), has an outline and sits above the name plates. A refused spot shows only the
  reason, without the cost line.
- **Conservation in field actions.** `FieldPlot` harvest refuses on a full bag and the crop stays.
  Watering puts the water bucket back when the empty bucket will not fit. Both used to drop the
  item.
- **Catapult label** reads `max_hp`, and is set in `_ready` as well as in physics.
- **build_lab** now checks every result:
  - It walks east from the camp to a real shore water cell, claims it, and expects `rejected water`.
  - It places manual rotations through `rotate_clockwise()` and checks that they are kept.
  - It prints `[build] PASS` and exits 0, or prints `[build] FAIL ...` and exits 1.
  - Screenshot runs frame a fence run with a gate (opened when the shot name contains `open`) and
    an invalid ghost.
- **siege_probe** prints the label and whether it uses `max_hp`. It now exits 1 when the platform
  is never destroyed.

Commits: `fe90c2e`, `2ebc882`, plus the report commit.

## Acceptance checklist (lines copied from the final runs on the finished code)

Logs: `scratchpad/w1/build/final_*.log` (session scratchpad).

| Item | Output |
|---|---|
| All 24 place_as kits route (field_small, field_large, steamer were UNPLACEABLE) | `[build] route field_small_kit ok`, `[build] route field_large_kit ok`, `[build] route steamer_kit ok` and 21 more `ok` lines, one per kit; no FAIL |
| A forced `_spawn` failure leaves the kit in the bag | `[build] spawn-fail placed=false kit 1->1` |
| pack_up on every kind returns its kit (and basket contents); full bag refuses, structure stays, units conserved | 24 lines like `[build] pack_up basket ok full_bag_refused=true units_conserved=true kit_back=true contents_back=true` (catapult and makeshift_taming_pen included) |
| Catapult pack_up raises no SCRIPT ERROR | `[item] packed catapult`; `final_t_build SCRIPT_ERROR=0` |
| Manual fence rotation kept | `[build] fence manual rot requested=1 placed=1`; build_lab: `[build] placed fence at (-3,9) rot=90`, `[build] placed gate at (-1,9) rot=270` |
| Gate open state round-trips; open = route exists, closed = none | `[build] gate closed reachable=false layer=1 \| open reachable=true layer=2 points=2 \| reclosed reachable=false \| to_dict open=true round_trip=true` |
| TilePath occupy/release <= 5 ms on temperate_25 (was 440-572 ms) | `[build] tilepath full_rebuild=500.4 ms occupy=0.020 ms release=0.010 ms path_query=0.03 ms dirty_refresh+query=0.44 ms cell_blocked=true cell_freed=true (walkable before=true)` |
| path() to an enclosed target returns reachable=false | same gate line: `closed reachable=false` |
| t_build overall | `[t_build] PASS`, exit 0 |
| build_lab rejects water inside a claimed rect, prints PASS, exit 1 on mismatch | `[build] rejected water`, `[build] restored 6`, `[build] PASS`, `LAB EXIT 0`. An earlier run with the old probe printed `[build] FAIL water rejected` and `LAB EXIT 1` |
| --siege-probe still reports destruction; label uses max_hp | `[siege] label=Catapult 200/200 max_hp=200 label-uses-max-hp=true`, `[siege] destroyed-after=11s occupancy-cleared=true`, `SIEGE EXIT 0` |
| Existing suite | `[tests] PASS`, `RUN_ALL EXIT 0` |
| Smoke (`tools/smoke.sh --no-import` through gslot, `GODOT_PATH` set to a wrapper that adds `--audio-driver Dummy`) | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day`, `SMOKE PASS` |

Extra checks in t_build:

- Refusals:
  - `[build] pack_up tent with sleeps_left=5 refused=true reason="Used bedding can't be repacked"`
  - `[build] pack_up campfire with seconds_left=60.0 refused=true reason="A lit campfire can't be repacked"`
  - `[build] pack_up catapult with hp=150.0 refused=true reason="A damaged catapult can't be packed up"`
  - `[build] pack_up field_small with crop_id=wheat refused=true reason="Harvest or clear the field first"`
- Field actions on a full bag: `[build] field full bag: units 21->21 crop_kept=true buckets=2 | with room: wheat=3`

## Screenshots inspected

All are build_lab at the game's default 15 m zoom, in `scratchpad/w1/build/`:

- `build_gate_closed.png`: Forward+, 1600x900. The leaf fills the doorway, and the ghost on a fence
  cell reads "Spot is taken".
- `build_gate_open.png`: Forward+, 1600x900. The leaf has swung out and the doorway is clear.
- `build_gate_closed_gl.png`: gl_compatibility, 1600x900. Same scene, brighter as expected; the
  label is legible.
- `build_gate_closed_phone.png`: 390x844. The label is the right size, but the staged ghost sits at
  the right edge, so the text runs off screen. The phone HUD is still at its tiny runtime scale
  (ui-phone-01, W1-UI).
- `*_crop.png`: close-ups of the gate, closed and open.

Visual limits:

- Building name plates (HUD) can overlap the ghost label when the ghost is next to other buildings.
  The plates belong to W2-HUD.
- The gate leaf is plain planks until W1-STRUCTART ships a gate model.

## Assumptions (all marked `# ASSUMPTION:` in code)

1. Owned land is the home island or any claimed tile, because in single player every claim is the
   player's (`BuildPlacer._on_owned_land`). Packing up on a claim of an unstable island now works.
   The old code refused off the home island, and so does player.gd today; see the hooks.
2. A lit temporary campfire cannot be repacked, otherwise pack-and-place would reset its 120 s
   (`Bonfire.pack_up_block_reason`).
3. A damaged catapult cannot be repacked, because no repair exists and packing would be a free
   repair.
4. A planted field refuses pack-up, so seeds, water and fertiliser are never lost.
5. An open gate lets everything through, creatures included. There are no owner-only gates yet.
6. The Kenney fence-doorway is an empty frame. The leaf geometry is placed from the GLB bounds: an
   opening 1.25 m wide on the back edge of the cell, at z = -0.92.

## Integrator hooks (protected or other-owned files; not edited)

1. `game/scripts/player/player.gd` `_building_interact` (W2-PLAYER), currently
   `if World.is_home() and Input.is_action_pressed("sprint"): b.pack_up(self)`. Replace it with:
   ```gdscript
   if Input.is_action_pressed("sprint"):
       BuildPlacer.pack_up_node(b, self)  # owned-land, room and kind rules live there
       return
   if b.has_method("interact") and b.interact(self):  # gates open/close
       return
   ```
   Stations, bonfires, fields and sleep spots return earlier in that function, so they still have no
   pack-up entry in real play. W2-PLAYER or W2-HUD should add a "Pack up" hex that calls
   `BuildPlacer.pack_up_node(station, player)`. The taming pen needs the same call, because it has
   no `pack_up` method of its own (W1-TAME owns `taming_pen.gd`).
2. `player.gd` `_request_tile_path` and `creature.gd` `_replan_path` (W1-AI): after
   `_path_points = p.path(...)`, read `p.last_reachable`. The survivor should show "Can't reach
   that" and stop at the partial path instead of wedging (phys-path-01, consumer side).
3. `island_runtime.gd` (W1-LIGHT) needs no change. `mark_pathing_dirty()` still works and is now
   cheap (about 0.4 ms diff refresh).

## Labs to register

- `build_lab` (`-- --lab=build_lab`): headless, prints `[build] PASS` and exits 0, or exits 1 on any
  mismatch. Runs in about 10 s.
- `--siege-probe` is a main-scene flag, not a lab. It exits 1 when the platform is never destroyed.
- `game/tests/t_build.gd` is a test, not a lab. W1-QA's `tools/test.sh` picks it up through the
  `t_*.gd` glob. It runs in about 15 s because it loads temperate_25.

## What failed or is left

- Packing up and placing again re-earns construction XP (+8) and pioneer XP (+30 on the home
  island) every time. Repacking used to be possible for a few kinds; now it works for every kind,
  so this XP farm is wider. A fix needs a marker on repacked kit stacks or per-kit identity
  (W1-ITEMS uid) and is not done here.
- Packing up a station while the survivor is crafting at it is not tested. StationCraft (W1-ITEMS)
  holds the refund on the player side.
- Placed fence and gate collision boxes sit at the centre of the cell, but the Kenney model sits on
  the cell's back edge. This mismatch predates W1-BUILD and was left alone. Pathing uses cells, so
  routes are unaffected.
- Found during testing: `godot --script` exits 0 on a parse error (my first t_build run printed
  `SCRIPT ERROR: Parse Error ...` with `EXIT 0`). W1-QA's runner must grep for PASS or SCRIPT ERROR
  and not trust the exit code.
- No `.uid` file was generated for `t_build.gd`; the editor or an import creates it.
