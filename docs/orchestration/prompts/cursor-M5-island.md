# Cursor milestone M5 — the first island

Everything so far ran on a flat green square. M5 builds the tier-25 temperate unstable island the raptor slice lives on, with real vegetation, climate, day and night, camp, a crater, and the sink timer. Do this after M1b and M4a.

## Read first
- `AGENTS.md`, `docs/orchestration/plan.md`, your M3 report
- `docs/prd/durango-wild-lands-systems-prd.md` §4.1–4.6 (islands, camp, craters, climates, weather), §6.4 (fatigue sources), §11.2 (animal AI: drink, sleep, herds)
- `game/data/nature_manifest.json` — 150 CC0 models already converted to GLB under `game/assets/nature/`, grouped into families with climate tags, harvest yields, and tool class. This replaces the placeholder harvest nodes from M0.
- `docs/orchestration/prompts/addendum-mobile.md` (mobile performance rules apply hard here: `MultiMeshInstance3D` for vegetation, LOD or culling distance, creature cap)

## Tasks

1. **Island data** `game/data/islands/temperate_25.json`: climate `temperate`, tier 25, size (roughly 240 × 240 m, `# ASSUMPTION:`), lifetime in real minutes, spawn tables by family (from the manifest, filtered by climate) with densities, creature spawns (velociraptor packs, one deinonychus pair, one utahraptor near the crater), camp position, crater position, harbour position.

2. **Terrain**: a heightmap-driven `HeightMapShape3D` or a subdivided plane with noise (`FastNoiseLite`), gentle rolling hills, one river band (water plane with a `wet` trigger area), a beach ring at the coast, and sea beyond the edge. Bake a `NavigationRegion3D` from it. Keep the mesh under 100k triangles.

3. **Vegetation and nodes**: scatter each family according to its density using `MultiMeshInstance3D` per model for pure dressing (grass, flowers, distant trees) and real `HarvestNode` instances (from M0, now loading the family's GLB as its visual) for anything harvestable within the playable area. Harvest yields come from the manifest, stamped with `{"climate": "temperate", "level": 25}` attributes and the manifest's `tool_class`. Add the missing item ids the manifest references to `items.json`. Trees fall with a short animation and become a `WoodLog` prop for a second harvest (`# ASSUMPTION:`).

4. **Camp**: a cleared area at the harbour side with a bonfire, a workbench placeholder, a camp shed (mission turn-in later), and a `Coziness` zone that halves fatigue gain (PRD §6.4). Free "return to camp" verb from the map button.

5. **Day and night**: drive the existing `Game.time_of_day` into the sun rotation, a `WorldEnvironment` colour ramp, and creature behaviour: raptor packs hunt harder at night (perception +50%), herbivores sleep. Show the clock on the HUD.

6. **Climate and fatigue**: temperate needs weak cold resistance. Fatigue gains from walking, gathering, rain, and being wet per PRD §4.4.1 numbers; a fatigue inspector panel on tap of the fatigue bar listing each source. Rain as a periodic weather state with a particle layer and the `wet` status.

7. **Crater**: a plant crater with guardian creatures at tier +1 and rare nodes around it; discovering it (entering its radius the first time) prints `[world] crater discovered` and drops fatigue.

8. **Sink timer**: the island's remaining lifetime on the map screen; when it hits zero while the player is on it, a 60 s warning then forced return to camp. (No persistence yet.)

9. **Lab**: `--lab=island_lab` loads the island with the survivor at camp. Screenshot from the isometric camera at camp and at the crater into `docs/orchestration/reports/`.

## Simulator findings to fix in this milestone (seen on the iPhone 17 Pro simulator, 2026-09-17)
- The island renders almost black under the `mobile` renderer at midday: check the sun energy, the WorldEnvironment ambient/sky on the mobile path, and that the terrain material is not unlit-dark. Verify with `tools/sim_run.sh` (it screenshots the simulator).
- Godot logs `mouse_get_position(): Mouse is not supported by this display server` every frame on iOS. Read the pointer position from the InputEventScreenTouch / `tap` event instead of polling the mouse.
- The F3 HUD's draw-call counter reads 0; use `RenderingServer.get_rendering_info(RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)`.

## Acceptance
- `tools/smoke.sh` passes; the island lab boots headless under 5 s and prints `[world] island temperate_25 nodes=<n> creatures=<n>`.
- Frame rate stays above 60 on this Mac with the full island; report the count of MultiMesh instances and HarvestNodes.
- Every family used on the island resolves to a model in `game/assets/nature/` (no missing-file errors).
- Write `docs/orchestration/reports/cursor-M5-island.md` and commit as `M5: temperate island`.
