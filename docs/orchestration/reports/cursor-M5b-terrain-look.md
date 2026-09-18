# Cursor M5b terrain look report

## What shipped
- Reworked `game/scripts/world/island_runtime.gd` terrain generation for unstable/home islands with dynamic heightmap resolution (`129` for islands >= 200 m, `65` for home), 3-octave noise relief, inland ridge, smooth beach falloff, river carve, and crater bowl shaping.
- Replaced the old unshaded terrain with lit chunked terrain using `terrain_tiles.gdshader`: per-tile textures, vertex tinting, subtle 1 m grid overlay (`Game.show_grid`, F6), noise modulation, and climate palette support from `game/data/world/climates.json`.
- Removed camp/crater square pad meshes; camp and crater are now painted into terrain color/shape, and crater depression is in the heightfield itself.
- Upgraded water presentation with layered sea planes + foam ring, procedural sky, and distance fog driven by day/night.
- Added tile runtime state (`tile_types`) and harvest feedback: when a node depletes it marks a bare tile and logs `[world] tile bare (x,z)`; on regrow it restores the tile and logs `[world] tile regrown (x,z)`.
- Added/updated data for terrain resources and visuals:
  - `game/data/nature_manifest.json`: `mud`, `clay`, `berry_bush`, `tree_stump`.
  - `game/data/items.json`: `mud`, `berry`.
  - `game/assets/terrain/*.jpg`: Poly Haven diffuse textures.
  - `docs/orchestration/resources.md`: texture source/licence record.
- Added swaying vegetation shader (`foliage_sway.gdshader`) for grass/flowers and tightened culling ranges for terrain chunks and node visuals to keep draw calls in budget.
- Added shoreline walk blocking in `Player` (no swimming), plus hip lantern light behavior that ramps at dusk/night and flickers slightly.

## Acceptance checks
- Screenshots captured:
  - `docs/orchestration/reports/m5b-terrain-camp.png`
  - `docs/orchestration/reports/m5b-terrain-crater.png`
  - `docs/orchestration/reports/m5b-terrain-home.png`
  - `docs/orchestration/reports/m5b-terrain-tiles.png`
- Draw-call budget (`island_lab`, F3 equivalent log):
  - `[world] draws camp=236` (<= 320)
  - `[world] draws crater=183` (<= 250)
- Headless unstable island acceptance:
  - `[world] island temperate_25 nodes=19 creatures=24 spawn_rejected=0`
  - no `[world] missing nature` lines
- Fast regen debug acceptance (`--fast-regen`):
  - `[world] tile bare (33,-81)`
  - `[world] tile regrown (33,-81)`
- `tools/smoke.sh`:
  - `SMOKE PASS`

## Assumptions
- `mud`/`clay` node regen set to 60 s, `berry_bush` to 90 s, tree/stump resources to 240 s.
- To stay inside the mobile-oriented draw budget, harvest-node densities were reduced versus M5 and culling tightened.

## Notes for next milestone
- Terrain shader and tile-state plumbing are now in place for future per-tile systems.
- Save schema is unchanged; tile bare/regrow metadata is stored inside the existing `World.harvested` payload.
