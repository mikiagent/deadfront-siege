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
