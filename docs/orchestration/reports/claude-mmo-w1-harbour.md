# W1-HARBOUR report: the harbour stands on the coast

Branch `claude/mmo-w1-harbour` (work tree `.claude/worktrees/mmo-w1-harbour`), cut from
`claude/mmo-overhaul` at `bd75fa0`. No credits spent. Owner complaint (2026-10-19): the harbour was
a grey block in the middle of the land (audit gap world-harbour-07, `harbour_to_water_m=187`).

## What shipped

- **Coast placement (`game/scripts/world/harbour_site.gd`, new).** `HarbourSite.find(rt, hint)`
  takes 360 bearings. On each bearing it walks in from the open sea to the first land and points
  the dock at the nearest grid axis. It then moves the base inland up to 3 m until the pose is
  legal. Of the legal poses it picks the one nearest the hint: the island json `harbour`, or the
  camp when the json has none. The dock points along the harbour's local -Z, the same convention
  as the Blender `pier.glb`. Rot 0/1/2/3 sends the dock to world -Z/-X/+Z/+X.
- **Rule (`HarbourSite.check`, data in `rules.json` `"harbour"`).** The 3x6 footprint is legal
  when all three hold:
  - the base row (row 0) is on land;
  - every cell from `dock_from_row` (2) to the tip is over water, which keeps the base within
    2 m of the shoreline;
  - the tip is at least `boat_depth_m` (0.4) below the water line.

  Anything else is refused with `needs_shore` or `dock_needs_water`. `BuildGrid.can_place` now
  returns these codes for `&"harbour"`, so a BuildPlacer layout move inland or pointing landward
  is refused. The notice reads "Can't drop here: Dock Needs Water".
- **Island build (`island_runtime.gd`).** The harbour is placed at `HarbourSite.find(...)`. A
  saved `World.camp_layout["Harbour"]` pose that breaks the rule (every pre-change save had the
  inland pose) snaps back to the coast. New `arrival_point()`: the sand just behind the dock's
  base, at the water's edge. The home cargo basket stands beside the dock's base and is walked
  inland until it is on dry land. The camp stays inland where it was.
- **Arrival.** `World.travel` lands the survivor at the json `harbour`. Every island's json is now
  the dock's arrival point:
  - updated `islands/home_grassland.json` and `islands/temperate_25.json`;
  - 13 new files, `islands/<id>.json`, each holding only `id` + `harbour` + a note, for the
    catalogue islands that had no harbour data (`World._load_islands` merges them over
    `world/islands.json`).

  `t_harbour` fails if a json value drifts more than 1 m from the arrival point, and prints the
  value to use.
- **Approach strip.** On the 480 m islands the waterline lies about 15 m past `land_radius()`,
  which is where `spawn_ok` and TilePath stop. Without a fix, a survivor arriving at the water
  could not tap-move at all. So I added two things:
  - A 3 m wide, 30 m long strip from the arrival point inland counts as walkable for
    non-strict `spawn_ok`.
  - `TilePath._build_region` merges `runtime.harbour_approach_rect()`.

  `HarbourSite.find` only accepts a pose whose strip reaches dry land. Scatter keeps the dock,
  the strip and the basket clear (`near_harbour`). A layout move of the harbour rebuilds pathing
  so the strip moves with it.
- **Spawns.** The creature keep-out around the harbour went from 15 m to the camp's 25 m. The
  harbour is now where travel lands you.
- **Visual (`harbour.gd`).** The grey 3x0.4x6 box is gone. If a `props_manifest` `buildings.harbour`
  row exists, its `glb` (or Kenney `model`) is used. Otherwise the harbour is a composite of
  textured Kenney props:
  - four `floor` plank sections, 2 m wide and 8 m long, standing 0.5 m above the water on ten
    `tree-log` piles;
  - a `structure-canvas` shed at the land end;
  - crates, a barrel, a bucket and a fish on the deck;
  - two stump bollards with rope coils (TorusMesh), plus a loose coil on the deck;
  - a three-log raft moored alongside, since no boat model exists in `game/assets/props`.

  The collider covers the deck and the shed, so tapping the dock opens the harbour from anywhere,
  as before.
- **Lab `harbour_lab`.** Options: `--island=<id>` and `--frame=wide`. It stands the survivor on
  the arrival point, frames the dock and prints one `[harbour] lab ...` line.
  **Test `t_harbour.gd`.**

Commits: `d79e5b6`, `b611baf`, `8d33216`, plus this report.

### Files touched outside the listed set (both unprotected, both needed by the acceptance)

- `game/scripts/world/build_grid.gd`: `can_place` for `&"harbour"` returns `HarbourSite.check`
  (it returned `""`, accepting any spot), and `footprint(&"harbour")` returns
  `HarbourSite.FOOTPRINT` (same 3x6). The task asks for the refusal on the BuildPlacer path, and
  the placer only asks `BuildGrid.can_place`.
- `game/scripts/world/tile_path.gd`: `_build_region` merges `harbour_approach_rect()` (3 lines).
  Without it, "camp-to-harbour path reachable" fails on temperate_20/25/35/45. Their whole coast
  lies outside the A* grid.

## Acceptance checklist (lines copied from the final runs on `8d33216`)

Logs: `<scratchpad>/w1x/harbour/final_*.log`.

| Item | Output |
|---|---|
| smoke | `SMOKE PASS` |
| run_all | `[tests] PASS` (exit 0) |
| t_harbour | `[t_harbour] PASS islands=15` (exit 0) |
| t_build (BuildGrid/TilePath touched) | `[t_build] PASS` (exit 0) |
| also run earlier on the same code minus comments | `[t_save] PASS`, `[t_ai] PASS`, `[t_tame] PASS`, `[t_items] PASS`, `[t_combat] PASS` |
| home: water <= 3 m (was 187 m on the audit) | `[t_harbour] home_grassland cell=(-1, 64) rot=2 harbour_to_water_m=0.00 base_to_shore_m=1.00 tip_depth_m=0.87 arrival=[0.5, 0, 63.5] camp_to_harbour_m=55 reachable=true nearest_creature_m=23` |
| temperate_25 | `[t_harbour] temperate_25 cell=(71, 178) rot=2 harbour_to_water_m=0.00 base_to_shore_m=0.25 tip_depth_m=0.44 arrival=[72.5, 0, 177.5] camp_to_harbour_m=180 reachable=true nearest_creature_m=76` |
| seed-17 catalogue islands (savannah_15 shown; desert, swamp, tropical, tundra, volcanic are identical) | `[t_harbour] savannah_15 cell=(-185, -40) rot=1 harbour_to_water_m=0.00 base_to_shore_m=0.56 tip_depth_m=0.47 arrival=[-178.5, 0, -38.5] camp_to_harbour_m=185 reachable=true nearest_creature_m=92` |
| seed-25 catalogue islands (temperate_20 shown; 35 and 45 identical) | `[t_harbour] temperate_20 cell=(-192, -8) rot=1 harbour_to_water_m=0.00 base_to_shore_m=0.25 tip_depth_m=0.46 arrival=[-185.5, 0, -6.5] camp_to_harbour_m=186 reachable=true nearest_creature_m=85` |
| inland placement refused | `[t_harbour] inland placement code=dock_needs_water` |
| per island, all asserted in t_harbour | pose legal; dock-tip cell is SHALLOW/DEEP and >= 0.4 m deep; base cell on land within 2 m of the shoreline; harbour_to_water_m <= 3; arrival is dry sand <= 3 m from water; json `harbour` within 1 m of the arrival point; TilePath camp to arrival `last_reachable=true`; arrival tile walkable; Visual has >= 20 meshes and no BoxMesh |
| also asserted | the coast pose is accepted by BuildGrid; the same spot with the dock pointing inland is refused; an old save's inland `camp_layout` pose snaps back to the coast |
| island_lab counts | `[world] mm=2 nodes=378 creatures=24`: unchanged (baseline 378/24 on `bd75fa0`) |
| home counts | `[world] island home_grassland nodes=211 creatures=8`: baseline 212/8. One node fewer because scatter keeps the 3x30 m approach strip clear. |

## Screenshots looked at (1600x900, `<scratchpad>/w1x/harbour/`)

- `home_fwd.png` (Forward+): the pier stands over water, with piles visible through the shallows.
  The canvas shed sits at the land end, cargo is on the deck, the raft is moored alongside, the
  basket stands on the grass beside it, and the survivor is at the dock's base. The HARBOUR hex
  shows (within 5 m).
- `home_wide_fwd.png` (Forward+): the harbour on the south-west coast with the basket beside it,
  and the camp inland at the top right. Water, dock and camp are in one frame.
- `temperate25_fwd.png` (Forward+) and `temperate_25_compat.png`: dock on the beach with the sea in
  front. HARBOUR, WASH and DRINK hexes show.
- `savannah15_fwd.png` and `savannah_15_compat.png`: the seed-17 harbour sits at the river mouth,
  with the dock over the sea and the river channel beside it.
- `home_grassland_compat.png` (gl_compatibility): same read as Forward+, slightly lighter wood.
- `temperate25_wide_compat.png`: not usable. On 480 m islands the camp is 180 m inland. An ortho
  size of about 200 clips the far plane and the dock disappears. Camp and dock can share a frame
  only on home.
- `home_fwd_v1.png`: the first pass, which had the raft against the deck end. Fixed in `b611baf`.

## Integrator hooks

1. **When W1-STRUCTART lands**, add this row to `game/data/props_manifest.json` `buildings` (I did
   not edit that file):
   ```json
   "harbour": {"glb": "res://assets/props/blender/pier.glb", "footprint": [3, 6], "note": "harbour dock: HarbourSite keeps it on the coast; seaward end towards -Z"}
   ```
   `harbour.gd` instances the glb in place of the composite. The visual root sits at world
   y = -0.75, the pile feet, so the pier's deck (1.2 m above its feet) lands at the same 0.45 m as
   the composite. The Blender pier is 7.8 m long and the footprint is 6 m, so it overhangs 0.9 m
   at each end (the land end onto the beach). The row also makes the layout-mode ghost a 3x6 box,
   because `BuildPlacer._rebuild_ghost_visual` reads `PropVisuals.footprint`. Today the ghost is
   a 0.8 m box.
2. **Optional robustness, `game/scripts/core/world.gd` `travel()`** (protected). Arrival then
   follows the placed dock even if the json drifts. `t_harbour` guards the json today. After
   `load_island(host, to_id, pos, false)` at line 176, add:
   ```gdscript
   		if runtime and runtime.has_method("arrival_point") and _player():
   			_player().global_position = runtime.arrival_point() + Vector3.UP
   ```
3. Register the lab `harbour_lab` in `tools/labs.txt`:
   `harbour_lab  --island=<id> [--frame=wide]  [harbour] lab ... line; headless quits`.
4. Register `game/tests/t_harbour.gd` with the other `t_*.gd` gates. It runs in about 23 s and
   builds all 15 islands.

## ASSUMPTION markers

- `harbour_site.gd`: `boat_depth_m` 0.4 and `dock_from_row` 2. The PRDs give no draft; these
  float a raft.
- `harbour_site.gd`: `APPROACH_M` 30 m covers the widest gap between the land radius and the
  waterline.
- `harbour.gd`: deck 0.5 m above the water (`FEET_Y` -0.75 plus `DECK_H` 1.2).
- `island_runtime.gd`: the harbour's spawn keep-out is the camp's 25 m (was 15 m).

## What is left / risks

- **Ring design.** On the 480 m islands the harbour sits at r ≈ 182-192 m, inside the crater and
  far-shore spawn bands; `rules.json` rings assume harbour and camp share the 0-30 m landing ring.
  The camp stays at the centre, a 180 m walk away. At arrival the nearest creature is 32-92 m
  away (temperate_35/45: 32-33 m; volcanic_60: 203 m). Two options: move the unstable camp beside
  the harbour, or re-centre the rings on the harbour. That is a design call for the owner or W2.
- **Few distinct sites.** Terrain depends only on the seed (temperate = 25, everything else =
  17), so 12 islands share 2 harbour sites. Varying the islands belongs to the terrain package.
- **Shallow tip.** On the gentle 480 m beaches the dock tip is only 0.44-0.47 m deep. It passes
  the 0.4 m rule; the visual pier reaches 2 m past the footprint into deeper water.
- **Visuals.** The composite uses Kenney's salmon wood palette and a log raft stands in for a boat.
  The Blender pier (hook 1) and a boat model are the upgrade path. The jagged river-channel edges
  in the savannah shots come from the terrain mesh, not this package.
- **Derived data.** The json harbour values are derived from terrain generation. If the heightmap
  changes, `t_harbour` fails and prints the new value for each island.
