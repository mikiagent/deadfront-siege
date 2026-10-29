# Report: ISLANDSHAPES (shape families, southern-most dock, non-navigable topography), Claude

Branch `claude/mmo-islandshapes` (from `origin/claude/mmo-overhaul` a67768b3), worktree
`.claude/worktrees/mmo-islandshapes`. Not pushed, not merged. No paid generation, no credits spent.

Owner (verbatim): "Start at the southern-most port of any island. Be creative with the shapes ... remember
to make/generate props that help with topography so most of the area is flat but there are some large
rocks, plateaus, etc that are non-navigable". Follow-up: "mountains and volcanos could be good props too".

## What shipped
- **Shape families** (`game/data/world/island_families.json`, `IslandShape._apply_family`): bulky,
  round_peak, lobed (deep bays), crescent (lagoon + barrier islets), atoll (ring, central island on two
  sandbars, a reef pass), spiral (core + spiral arm of islets), chain (diagonal sandbar-linked spine with
  loose islets). One distance-like field unions islets/capsules, cuts lagoons/passes/rings, then lays
  sandbars back. Jagged coasts (noise) and a shallow turquoise shelf (-0.85 m, 6-50 m wide; lagoon floors
  all shelf). The 14 roster islands carry `shape_family` in `islands.json` (two of each family); rows
  without one draw by seed. `classic` (the old body, untouched) stays on the legacy meadow and the tutorial.
  Other Tamed Island picks draw bulky or lobed.
- **Rivers per family**: radial as before; polar (along an atoll ring / round a crescent's lagoon); linear
  down a chain's spine. Minimum arc = 0.55 x target long axis x `river_scale`.
- **Southern-most dock** (`HarbourSite.find`): every legal pose is collected and the farthest south (+z)
  wins (ties to the x = 0 midline); islets are skipped and the scan continues to the coast behind them.
  Arrival (new game pick, travel) is `arrival_point()`, so it is the southern-most port. The runtime now
  tracks the placed dock (`_harbour_pos`), not the stale json hint, for the 25 m landing ring and the
  scatter keep-clear; `near_harbour` also clears 8 m round the arrival point. The tutorial opts out
  (`dock_rule: hint`) to keep its hand-tuned dock by its town. Respawn is at the camp (no respawn-at-dock
  exists), unchanged.
- **Topography** (heightfield, `IslandShape._place_topo` / `_topo_at`): volcanoes (crater; lava glow disc,
  smoke on a live one, `IslandRuntime._volcano_fx`), mountains, ridges, mesas, each on a 2.4 m cliff skirt.
  Footprints -> `topo_mask` -> CLIFF tiles (not walkable, not buildable, no spawn, solid in TilePath),
  painted rock (ash on volcanic) and cut from the nav source. Placed inland and clear of the camp disc,
  river/ford/waterfall, the camp-to-south-coast walk, the row's crater and fixed spawns, and each other.
  Volcanic climate always gets a live volcano; some families roll a dormant one.
- **Rock outcrops** (`IslandProps._place_outcrops`): 3-8 clusters of 3-6 blocking rocks (cliff block,
  boulders, spire, sometimes a big cliff) on flat inland ground, off camp/dock/approach/walk/river/claims,
  on `surface_y`.
- Tools: `game/scripts/dev/islandshapes_sheet.gd` (headless map contact sheet, seconds);
  `islandgen_lab` gained `--topo-shots` and `--sheet`.

## Tests
- `t_islandgen` extended: family recorded and matches the row; roster spans >= 6 families; dock is the
  southern-most legal mainland pose, legal, on the mainland, arrival at it and within 25 m of the southern-
  most dry mainland; dock -> camp path and >= 85 % of mainland probes reachable from the dock; topography
  tiles are CLIFF / not dry / not walkable / no spawn, none near the dock, approach, camp or the walk;
  features rise from dry ground (grounded); outcrop rocks on the ground, solid in TilePath, off the dock.
  River and aspect checks are family-aware (classic unchanged).
- `t_harbour`: the moved-harbour case asks `find(..., hint mode)` for its alternate pose.
- `t_terrainsmooth`: BEACH_MAX 0.65 -> 0.70 (tropical_25 atoll measured 67 %; the per-climate +-0.15
  check still holds).
- `t_buildspeed` digests re-recorded. Proof they changed by design: a detached canon worktree
  (origin/claude/mmo-overhaul a67768b3) built exactly the old digests 8f711ab5 / 92c05535 / 9c9c8c7c;
  this branch builds ee9810de / 3baa8c61 / d7f9bb52. Home keeps its classic ground; its dock moved.
- Alone on a loaded box (load ~8.7): t_buildspeed PASS (best home 2337 / savannah 2564 / volcanic 1886 ms;
  canon in the same window: 3229 / 3428 / 2612), t_perfgates PASS (build 2189 / 2317 / 1758 ms).
- Final `bash tools/all_tests.sh` (JOBS=4): 137 tests, pass=136, fail=1 = t_buildspeed timing (home 2519
  vs 2500 ms under the parallel load); rerun alone: PASS (home 2185, savannah 2330, volcanic 1760 ms).
  `bash tools/smoke.sh --no-import`: SMOKE PASS.
- Owner rule mid-task "work headlessly for now": the in-game shots below came from windowed runs made
  before that rule (at --position 6000,3000, all finished, none left running). From now on the headless
  `islandshapes_sheet.gd` map is the contact sheet to use (`contact_sheet_map.png`).

## PNGs (`docs/orchestration/reports/islandshapes/`)
- `contact_sheet_top.png`: in-game top-down of all 16 islands (15 + tutorial), sorted by id.
- `contact_sheet_map.png`: headless map of the 15 islands with id + family (white dot = estimated dock,
  orange = camp).
- 1600x900 close-ups: `volcanic_60_volcano.png` (live), `temperate_35_volcano.png` (dormant),
  `tundra_30_mountain.png`, `savannah_15_mesa.png`, `desert_35_ridge.png`, `tundra_30_outcrop.png`.

## Assumptions (all in Open Questions, ISLANDSHAPES S1-S10)
Family deal per island; non-meadow Tamed picks reshaped; southern-most rule incl. the home meadow (a new
game's dock moves from ~(0, 62) to ~(18, 154), 90+ m from the camp); camp stays in the middle; topography
sizes/counts/keep-outs; outcrop sizes; shelf depth/reach; shorter rivers on thin families; islets not
walkable.

## Risks / for the next agent
- **Save note (no format change)**: no new save keys. A save whose `camp_layout` holds its dock keeps it
  while legal. A save on a non-meadow Tamed Island (forest/rocky/riverside/coastal) gets new ground outside
  the 75 m legacy core; buildings out there may now stand on changed ground.
- The tutorial does not follow the southern-most rule (opted out to keep its town layout); flip
  `dock_rule` if the owner wants it there too (the town would then be ~190 m from the dock).
- Outcrop rocks draw as the existing painted cards (cliff_block reads as a low slab at iso zoom); the big
  reads come from the heightfield features. Bespoke rock art would help.
- Tall peaks (up to ~19 m) can hide the survivor behind them; terrain has no occlusion fade.
- PNG close-ups are full 1600x900 (1.3-2.2 MB each).
