# Cursor milestone M5b — make the island look like an island

Look at `docs/orchestration/reports/m5-island-camp.png` and `m5-island-crater.png`: the
terrain is one flat unshaded colour, the camp and crater are square planes lying on top
of it, the dirt zone is a hard-edged band, and the sea is a plain rectangle. The owner
called it "glitched out". Fix the look without changing gameplay data or the save schema.

## Read first
- `game/scripts/world/island_runtime.gd` (`_terrain`, `_build_terrain_mesh`, `_vert`, `_sea`, `_camp`, `_crater`, `_scatter`, `_multimesh_family`)
- Claude's commit bc0413f: `land_radius()`, `spawn_ok()`, `_ring_point()`; keep them working. If you move the beach start, update `land_radius()` to match.
- `docs/orchestration/reports/cursor-M5-island.md` "Simulator follow-ups" (unshaded was a workaround for a dark simulator render; the owner tests on a real phone now, so lit materials are wanted, with strong ambient light so nothing goes black).

## Tasks

1. **Relief.** Heightmap resolution 129×129 for islands ≥ 200 m (keep 65 for the 160 m
   home island). Height = 3-octave FastNoiseLite (freq 0.012 / 0.03 / 0.08, amplitudes
   3.5 / 1.2 / 0.35 m) + a low ridge (≤ 5 m) along one inland quadrant, smoothed beach
   ring from `0.40·size` to `0.46·size` down to −2.5 m with an ease-out curve, river
   carved with 3 m soft banks. Same seeds as today per climate so labs stay comparable.
   Update `HeightMapShape3D` and the nav bake accordingly.

2. **Lit terrain.** Vertex normals (`generate_normals` after `set_smooth_group`),
   `SHADING_MODE_PER_PIXEL`, roughness 1, `CULL_BACK`. Colour by height + slope with
   noise jitter: sand < 0.35 m, grass, dry grass on steep slopes, dark rock above
   ~5.5 m or slope > 40°, dirt/ash only where the climate says so (`climates.json`
   may gain a `palette` block: grass, dry, rock, sand colours per climate). Multiply
   the vertex colour by a tiling `NoiseTexture2D` albedo (world-xz UVs, 6 m repeat,
   seamless) so large flat areas are not one flat tone. Ambient light stays ≥ 0.9.

3. **No square pads.** Delete the camp `PlaneMesh`/cylinder pad and the crater pad.
   Paint the camp as a soft lighter-green disc and the crater as a darker rim + bowl
   in the vertex colours (radius blend), and lower the crater heights into a 1.5 m bowl.

4. **Sea and shore.** Sea plane with a lit, slightly transparent material, a darker
   deep-water plane 1.5 m under it, and a 3 m foam band drawn as a translucent ring
   where the terrain crosses y ≈ −0.1 (a second vertex-coloured strip mesh is fine).
   Gradient sky (`ProceduralSkyMaterial`) driven by the existing day/night code, light
   distance fog for depth (mobile-cheap).

5. **Vegetation on land only.** Trees, bushes and rocks use `spawn_ok(pos, false)`; grass
   and flowers also skip cells steeper than 35°. Tilt each MultiMesh instance to the
   terrain normal.

6. **Budget.** F3 draw calls in island_lab ≤ 320 at the camp, ≤ 250 at the crater;
   terrain stays chunked 4×4 (8×8 for 129 res) with `extra_cull_margin`.

## Acceptance
- Screenshots `docs/orchestration/reports/m5b-terrain-camp.png`, `m5b-terrain-crater.png`
  (island_lab) and `m5b-terrain-home.png` (home_lab): visible relief shading, no
  squares, soft beach into water, foam line, no flat single-colour expanses.
- Headless `--lab=island_lab` still prints `creatures=24 spawn_rejected=0` and no `[world] missing nature`.
- `tools/smoke.sh` → `SMOKE PASS`. Report `docs/orchestration/reports/cursor-M5b-terrain-look.md`.
  Commit as `M5b: island terrain look`.
- Do not edit `game/project.godot`, `tools/`, or anything under `game/assets/`.

## Addendum (owner, 2026-09-17 evening) — tiles, textures, grass, resource tiles

7. **Subtle tile grid.** The world is a 1 m tile grid (M8b builds on it). Draw a very
   subtle grid on the ground everywhere: a terrain shader (`ShaderMaterial` on the
   terrain chunks, replacing the StandardMaterial from task 2 but keeping vertex
   colour × noise albedo and lit shading) that darkens a 3 cm line at every whole-metre
   world x/z by ~8 % alpha, fading out beyond 25 m from the camera focus so it never
   reads as a mesh. A `Game.show_grid` toggle (F6) turns it off; it is on by default.

8. **Real textures.** Instead of a single noise albedo, blend three tiling textures by
   vertex colour zone: grass, dirt, sand (plus rock on slopes). Use CC0 textures
   (Poly Haven "aerial_grass_rock", "brown_mud_leaves_01", "aerial_beach_01" 1K
   diffuse only; download with the Blender MCP `download_polyhaven_asset` or
   directly from polyhaven.com; record the source in `docs/orchestration/resources.md`,
   files under `game/assets/terrain/`, import with `process/size_limit` 1024).
   Blend weights come from the vertex colour channels (r = dirt, g = grass, b = sand).

9. **Swaying grass.** The grass and flower MultiMeshes get a vertex shader that sways
   the top of each blade with `sin(TIME * 1.6 + world_x * 0.35 + world_z * 0.2)`
   scaled by vertex height (bottom vertices do not move), amplitude 0.06 m, plus a
   gust term. Cheap enough for the phone (no per-instance uniforms).

10. **More harvestables, on tiles.** Add node families in `nature_manifest.json`
    (data only, no new art): `mud` (river bank and beach edge tiles, yields `mud`
    item, tool none, pool 8), `tree_stump` (what a felled tree leaves: yields
    `wood_log` ×2 pool, tool axe), `berry_bush` (Bush model with a red tint,
    yields `berry`, tool none, pool 10), `clay` (river tiles, pick). Create the missing
    item ids in `items.json` with `# ASSUMPTION` levels. Every HarvestNode snaps to the
    tile centre on spawn (`floor(x) + 0.5`) so it sits on the grid.

11. **Harvested tile goes bare, then regrows.** When a node's pool hits 0 (M8a),
    the node is removed and its tile becomes a **bare dirt tile**: paint the tile's
    four vertices dirt in the terrain vertex colours (update the chunk mesh in place via
    `MeshDataTool` or keep a per-tile colour array and rebuild only that chunk), and
    place a small flat "dirt patch" quad if the chunk rebuild is too slow on the phone.
    Over `regen_seconds` (trees 240 s, bushes 90 s, mud/clay 60 s `# ASSUMPTION:`) the
    tile lerps back to grass; when fully green, the node respawns on the same tile.
    Save bare tiles and their timers with the existing `harvested` snapshot.

Acceptance additions: a screenshot `m5b-terrain-tiles.png` close to the camp shows the
subtle grid, textured ground, grass swaying (two frames 0.5 s apart differ), a bare dirt
tile where a bush was harvested, and a berry bush and mud node on the grid. Headless
`island_lab` prints `[world] tile bare (x,z)` when a node empties and
`[world] tile regrown (x,z)` after regen (use a debug `--fast-regen` user arg ×20).
