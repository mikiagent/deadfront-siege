# Cursor M5 — temperate island

## What shipped
- `IslandRuntime` no longer uses a flat floor. It builds a 65×65 FastNoiseLite heightmap (`HeightMapShape3D` collision + chunked `SurfaceTool` mesh), a beach drop, a river band with a `wet` trigger, sea beyond the edge, and a threaded nav bake.
- Island data comes from `game/data/world/{rules,climates,islands}.json` with `game/data/islands/temperate_25.json` overlaying camp / harbour / crater positions. Material level is island tier + ring `level_offset`, clamped 1–60. Creature groups come from the catalogue `spawns` table (cap 24).
- Vegetation uses climate families from `nature_manifest.json`: `MultiMeshInstance3D` for grass/flowers (2 batches), `HarvestNode` GLBs for trees/bushes/rocks/plants. Trees fall, then become a `WoodLog_Moss` second harvest (`# ASSUMPTION:`).
- Camp (bonfire, workbench, tent shed from `props_manifest.json`, coziness zone) sits in the landing ring. Crater sits at r≈185 m inland with rare plants and a utahraptor guardian. Discovering it prints `[world] crater discovered`, dumps fatigue, and grants T-stones from `rules.json`.
- Day/night drives sun pitch/energy and environment colour. Raptors get +50% night perception. Herbivores sleep at night. HUD clock + FAT inspector lists fatigue sources (walk, gather, rain, wet, climate). Rain is a periodic particle weather state that applies `wet`.
- Simulator follow-ups: F3 draw calls use `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`; pointer position is stored from `InputEventScreenTouch` / mouse-button tap (no `get_mouse_position` polling); terrain/camp materials are unshaded vertex-colour so the mobile path is not unlit-dark.
- M6 save schema is unchanged (`schema: 1`).

## Acceptance checks run
- `tools/smoke.sh --no-import` → `SMOKE PASS`
- `-- --lab=island_lab` headless prints `[world] island temperate_25 nodes=109 creatures=24` (and `mm=2`)
- Screenshots: `docs/orchestration/reports/m5-island-camp.png`, `docs/orchestration/reports/m5-island-crater.png`
- No `[world] missing nature` lines. Every temperate family resolved to a GLB under `game/assets/nature/`

## Counts
- MultiMesh batches: **2** (Grass, Flowers)
- HarvestNodes: **109**
- Creatures: **24** (catalogue rings + one crater utahraptor)

## Assumptions
- `rules.json` `island_size_m.unstable` is 240 but rings extend to 240 m **radius**. The generator uses diameter `2 * far_shore` (480 m) so crater and far-shore rings sit on the mesh. Overlay numbers were not rewritten.
- Unmatched climate resist (`cold_weak` on temperate) costs 4 fatigue/min at night/dawn/dusk. PRD §4.4 has no number.
- Felled trees become a `WoodLog_Moss` prop for a second harvest; the stump tree respawns after regen.
- Large ortho meshes were being frustum-culled; terrain is chunked 4×4 and camp/crater have local ground planes with `extra_cull_margin`.

## What failed
- Nothing blocking. iOS `--validate` runs after this report (no upload).

## Credits spent
- Meshy credits: 0

## Next agent notes
- Home island still uses 160 m; if private-island rings ever use the same radii, reuse the diameter expansion.
- Nav bake is threaded (`bake_navigation_mesh(true)`); agents may wait a beat after travel before paths exist.
- Skill-gated gathering downrank from `rules.json` is not applied yet (M8).
