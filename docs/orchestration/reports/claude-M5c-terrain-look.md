# Claude M5c — Durango look: flat textured ground, gradual shore, tall clumped vegetation, dirt circles

Built by Claude after Cursor hit its usage limit. Reference: `docs/reference/durango-look-reference.webp`, `durango-shore-reference.webp`.

## What shipped
- `terrain_tiles.gdshader` rewritten: one continuous ground. Bands come from world height with noise-perturbed edges (grass → sand → wet sand → shallow bottom → deep); the tile map only carries overrides (bare/harvested, mud, dirt, rock, ash) with a soft edge. Two-scale rotated texture sampling kills the visible repeat. Grid line only while placing a building (`Game.show_grid`, toggled by `BuildPlacer.begin/cancel`, F6).
- `IslandRuntime._terrain`: flat relief (≈0.5 m undulation), low ridge far inland, soft river banks, a **wide gradual shore** (0.36–0.47 × size) whose waterline wanders with noise; `land_radius()` = 0.38 × size; tile types gained `WET`; navmesh walkable to −0.3 m; the player wades to −0.4 m (`_shoreline_guard`).
- `water.gdshader` + `_sea`: depth-based colour/opacity from a heightmap texture, foam band past the waterline with scrolling streaks, faint ridges in open water, ripple normals; deep plane below.
- Vegetation: `_plant_family` places **clumps** of 3–6 (thickets and clearings); tree clumps near the shore become `PalmTree` where the climate allows; heights scaled per role (palms 8–11 m, trees 7–10 m, bushes 1.5–2.2 m, rocks 0.7–1.3 m). All nodes render through per-model `VegBatch` MultiMeshes (`scripts/world/veg_batch.gd`); `HarvestNode.set_batched_visual` hides/shows its instance. Density floors: unstable 44 trees / 30 bushes / 16 rocks / 10 plants, home 12/12/6/6. Grass gets a green tint in `foliage_sway.gdshader`.
- `dirt_disc.gdshader` + `PropVisuals.make_disc_mesh/disc_material`: rough eroded-edge dirt discs replace the square foundation under every building/camp prop; tree trunks get a 0.9 m disc (one MultiMesh).
- Lighting: the island owns lighting (other directional lights off, other WorldEnvironments emptied — labs no longer stay bright at night); warm sun with soft shadows (orthogonal, 60 m), ambient 0.75; real night (sun 0.03, ambient 0.10 blue); hip lantern energy 4, range 10.
- Camera: default ortho size 15 (min 10, max 28) — the survivor is ~1/6 of the screen like the reference.
- `island_lab`: `--shot=…shore…` and `--shot=…night…` variants.

## Evidence
- `docs/orchestration/reports/m5c-look-camp.png`, `m5c-look-shore.png`, `m5c-look-night.png`, `m5c-look-home.png`
- Headless `--lab=island_lab`: `nodes=159 creatures=24 spawn_rejected=0`; `--lab=home_lab`: `nodes=51 creatures=3`
- `tools/smoke.sh` → `SMOKE PASS`

## Not done / next
- Draw-call log (`[world] draws camp=N`) not re-measured this pass; batching should keep it well under 320.
- Palms only appear near the shore of tree clumps; the camp has no palms yet (the reference hut is ringed by them): M8d/M8e can add a camp planting.
- Placement ghost does not yet show its dirt circle (M8d placement UI).
