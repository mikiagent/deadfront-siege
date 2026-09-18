# Cursor milestone M5c — terrain follow-ups: bring the island back, break the tile repeat

M5b (commit 7b9045c) landed the tile terrain. Two things regressed and must be fixed
before anything else; see `docs/orchestration/reports/m5b-terrain-camp.png` (an empty
field) and `m5b-terrain-tiles.png` (identical texture patch on every tile).

## Tasks

1. **Restore the world's density.** M5 placed 109 harvest nodes on temperate_25; M5b
   placed 19. Bring the counts back to the `terrains`/climate counts (≥ 100 nodes on the
   unstable island, ≥ 40 at home) **without** blowing the draw budget: keep every tree,
   bush, rock, mud, clay, berry bush and stump as a tappable `HarvestNode`, but render
   their meshes through per-family `MultiMeshInstance3D` batches (one batch per model;
   a node's visual is an instance index, hidden by moving the instance transform to
   scale 0 when depleted or felled) with `visibility_range_end` 90 m. Ground grass and
   flowers stay MultiMesh with sway. Report `[world] draws camp=N crater=N` again and
   keep them ≤ 320 / ≤ 250.

2. **Per-tile texture variation.** In `terrain_tiles.gdshader`, give each tile a random
   rotation (0/90/180/270), a random flip and one of two UV offsets, derived from a hash
   of the tile coordinates, and scale the textures so one tile shows ~1/3 of the texture
   instead of the whole image; add a low-frequency (12 m) brightness/hue noise across
   tiles so a field is not a uniform checkerboard. Keep the 1 m grid line subtle.

3. **Shore transition.** The sand ring meets grass in a hard staircase. Blend the last
   grass tile row into sand (tile-type "grass_sand" with a 50/50 mix) and blend sand into
   the shallow water bottom; keep the foam line.

4. **Night check.** Capture `m5c-terrain-night.png` at `Game.time_of_day = 0.9` near the
   camp: the hip lantern radius must read as a circle of light on the tiles.

## Acceptance
- Headless `--lab=island_lab` prints `nodes>=100 creatures=24 spawn_rejected=0` and
  `[world] draws camp<=320 crater<=250`; `--lab=home_lab` prints `nodes>=40`.
- Screenshots `m5c-terrain-camp.png` (trees, bushes, rocks visible around the camp, no
  visible tile repeat), `m5c-terrain-shore.png`, `m5c-terrain-night.png`.
- Smoke passes; report `docs/orchestration/reports/cursor-M5c-terrain-fixes.md`;
  commit as `M5c: terrain density and tile variation`.
- No autoloads, no `project.godot`, no `game/shell/`, no `tools/`.
