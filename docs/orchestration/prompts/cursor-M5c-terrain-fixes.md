# Cursor milestone M5c — make the island look like Durango (reference shot)

Reference: `docs/reference/durango-look-reference.webp` (a real Durango screenshot the
owner wants matched). What it shows, in words, since you may not be able to open it:
- The ground is **flat** and reads as one continuous textured surface: sand and packed
  dirt with soft, irregular blends between zones. **No visible tile grid.** Only near
  the water does the sand darken (wet band) before the shallow water and foam.
- Vegetation is **tall and dense**: palm trunks 7–9 m with the crown above the camera
  frame, big leafy bushes 1.5–2 m tall in clumps of 3–6, casting soft shadows.
- Every structure (a straw hut, a campfire) sits on a **dark circular dirt patch** with
  a rough, noisy edge, 1–2 m wider than the object. That circle is what hides the grid.
- The camera is closer: the survivor is about 1/6 of the screen height.
- Soft directional shadows and slightly desaturated, warm light.

M5b (commit 7b9045c) landed the tile terrain, but the result is an empty checkerboard
(`docs/orchestration/reports/m5b-terrain-camp.png`). Fix it against the reference.

## Tasks

1. **Flat, continuous ground.** Reduce relief to Durango's: inland height amplitude
   ≤ 0.5 m over 20 m (keep only a gentle ridge far inland and the beach/river slopes).
   In `terrain_tiles.gdshader`: grid line **off by default** (`Game.show_grid` on only
   while the build placer is active, and F6); blend tile types across a 1.5 m band with
   a noise-perturbed edge instead of hard tile borders; scale textures so one repeat
   covers ~4 m; per-tile random rotation/flip so no repeat is visible; a 12 m
   low-frequency brightness noise; slightly desaturate grass toward the reference's
   olive tone. Add a **wet sand** tile type (darker sand) for the two tile rows before
   the water, then foam, then shallow water.

2. **Tall, dense vegetation.** Use the nature pack's tall models: `PalmTree` on
   tropical/temperate shores, `CommonTree`/`Willow`/`PineTree` inland, scaled to 7–10 m
   (uniform scale factor per instance, ±15 % jitter); bushes (`Bush`, `BushBerries`,
   `berry_bush`) scaled to 1.5–2.2 m; place vegetation in **clumps** (Poisson-ish: pick
   a clump centre, drop 3–6 plants within 3 m) so the island has thickets and clearings.
   Restore density: ≥ 100 harvest nodes on the unstable island, ≥ 40 at home (M5b cut
   them to 19). Keep every plant tappable (`HarvestNode`) but render through per-model
   `MultiMeshInstance3D` batches (instance index per node; depleted = scale 0) so the
   draw budget holds (`[world] draws camp<=320 crater<=250`). Trees cast shadows;
   `DirectionalLight3D` shadows on with `directional_shadow_max_distance` 60 m
   (already off on iOS if the device path needs it: keep the existing `OS` check).

3. **Dirt circles under structures.** Replace M8b's square foundation slab with a
   circular dirt patch: a flat disc mesh (radius = footprint half-diagonal + 1.0 m,
   24 segments) using the mud texture with a noise-eroded alpha edge (shader), sitting
   0.02 m above the ground, under every placed building, the camp props, the bonfire,
   the harbour dock end, and the taming pen. Harvest trees get a smaller 0.8 m dirt disc
   at the trunk. The disc appears with the ghost while placing (green/red tint) so the
   player sees the footprint as a circle, while the grid overlay still shows the
   occupied cells.

4. **Camera.** `IsoCamera.default_size` 24 → 15, `min_size` 10, `max_size` 28
   (pinch still works); the survivor should be ~1/6 of the screen height on a phone.

5. **Light.** Warm key light (1.0, 0.95, 0.85) energy 1.3, ambient 0.7 slightly blue,
   subtle SSAO off (mobile), fog light. Night: lantern from M5b stays.

## Acceptance
- Headless `--lab=island_lab`: `nodes>=100 creatures=24 spawn_rejected=0`,
  `[world] draws camp<=320 crater<=250`; `--lab=home_lab`: `nodes>=40`.
- Screenshots `docs/orchestration/reports/m5c-look-camp.png` (camp with dirt circles
  under bonfire/workbench/tent, palms and bushes around, no grid), `m5c-look-shore.png`
  (wet sand, foam, water), `m5c-look-placing.png` (ghost with its dirt circle and the
  grid overlay visible only then), `m5c-look-night.png` (lantern radius).
- Smoke passes; report `docs/orchestration/reports/cursor-M5c-terrain-fixes.md`;
  commit as `M5c: Durango look — flat textured ground, tall vegetation, dirt circles`.
- No autoloads, no `project.godot`, no `game/shell/`, no `tools/`.
