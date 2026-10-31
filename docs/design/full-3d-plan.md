# Full 3D: staged conversion plan

Decision (Milan, 2026-10-30 18:02): "keep pushing to full 3D". Assessment and research:
https://claude.ai/artifact/HAW4gtMigZH1S6NcmcfXRZ (Claude Doc "Full 3D for WildLands: assessment").

Binding constraints from Milan, 2026-10-30:
- "The terrain should be flat and depth is added through props, structures, buildings, resources, etc."
- "The town should follow the same building rules the player follows and lock to the grid, ideally with
  the default orientation of the player (facing south)" (build thread owns this; independent of 3D).
- Window lights "face normally" (build thread, in flight).

## Shape of the end state

| Layer | Today | End state |
| --- | --- | --- |
| Terrain | Heightmap with mountains, ridges, mesas, cliffs | Flat land at one height; coast, shallows and rivers stay as tile types; relief comes from 3D rock and mountain meshes |
| Resources (79 families) | CARD2D painted/baked cards | 3D GLBs (already exist; `--models`) with a quality pass |
| Trees and palms | Painted cards | 3D GLBs with LOD, shadows on tall trees only |
| Cliffs, spires, mesas, arches, pillars, waterfalls, mountains | Painted cards | 3D meshes (Blender procedural first) |
| Mid scenery (logs, stumps, termite mounds, big ferns) | Painted cards | 3D GLBs |
| Small clutter (shells, pebbles, flowers, small ferns, leaf litter) | Painted cards | STAYS CARDS |
| Ground grass (GROUND2D) | Painted cards | STAYS CARDS (what full 3D games do) |
| Buildings, town, stations, creatures, survivor | 3D | 3D (unchanged) |
| Camera | Fixed north-up, 4.3 deg telephoto, pitch 38.7 | Fixed north-up, wider lens from the A/B; rotation only after a playtest |

## Packages, in order

One package per branch, build -> review -> A/B for visuals -> integrator merge, as GAUNTLET says. Each
stage ships behind a flag or data switch first and becomes the default only after its gate passes.

| # | Branch | Replaces | Stays | Gate (beyond tools/all_tests.sh) | Size |
| --- | --- | --- | --- | --- | --- |
| 1 | claude/mmo-3d-ab | nothing (lab + dev flags only) | everything | ab3d_lab shots + RESULT lines (docs/orchestration/reports/claude-3d-ab.md), Milan looks | done |
| 2 | claude/mmo-3d-flat | heightmap relief: land flat at one height, slope rules off on land, nav/surface_y simplified | coastline shapes, beach/shallow/deep tiles, rivers as flat water, biome tints | t_islandgen, t_landmarks, t_tutorial, t_unstable_isles green; spawns, landmarks, dock and town on flat ground; HUMAN: islands still read as places | 3-4 |
| 3 | claude/mmo-3d-resources | rules.json resource_render "card" -> "model"; FIRST fix the dormant 3D path (trees/palms do not draw under `--models`, see the A/B report) and the 30 dead model paths | card path behind `--cards` (t_card2d keeps testing it) | depleted/regrow states, TapZones, see-through fade on 3D trees; HUMAN A/B vs cards | 1-2 |
| 4 | claude/mmo-3d-trees | weak tree/palm GLBs | n/a | tall trees only cast shadows, mesh LOD + visibility ranges; perf gate below | 2 |
| 5 | claude/mmo-3d-rocks | cliff/spire/mesa/arch/pillar/waterfall cards; the 5 kinds without models (stone_arch, pillar, waterfall, vines, shells: vines and shells stay cards) | small rocks as cards if they read better | mountains and ridges placed as meshes on the flat ground (what package 2 removed); blocking + indestructible rules unchanged (t_props2d rules) | 2-3 |
| 6 | claude/mmo-3d-scenery | remaining mid scenery cards (fallen_log, tree_stump, termite_mound, big ferns, reeds clumps) | small clutter + GROUND2D | IslandProps draws GLB where models exist; scenery tint replaced by "not clickable" read in 3D (no outline on scenery, outline on resources) | 2-3 |
| 7 | claude/mmo-3d-light | flat card shading | n/a | window/torch/fire light as real lights (after the build thread's window fix), shadow budget, lighting grade A/B | 2 |
| 8 | claude/mmo-3d-perf | n/a | n/a | web export under PAYLOAD_MAX_MB, web frame time no worse than today on the soak, creature texture compression + work-file prune (biggest size win) | 2-3 |
| 9 | claude/mmo-3d-camera | FOV_DEG 4.3 / PITCH_DEG -38.7 constants | north-up, fixed yaw | lens from the A/B (`--cam-fov`, `--cam-pitch`), sky drawn, fog/shadow cascades/cull ranges refit, sky_shadows revisited, occlusion and tap targets re-checked; t_camera updated | 2-3 |
| 10 | claude/mmo-3d-cleanup | card code paths, baked-card tooling (card_bake), t_card2d for converted kinds | GROUND2D, clutter cards, PropCards for clutter | no dead flags; docs/current updated | 1 |
| later | claude/mmo-3d-rotate | fixed yaw | n/a | only if Milan asks after playing package 9: 90 deg Q/E snaps + compass first | 3-5 |

Total: about 17-23 packages, art-bound in 4-6. Packages 2 and 3 can run in parallel (different files:
island_terrain.gd vs rules.json/island_scatter.gd). 5 depends on 2. 9 goes last among visuals because every
earlier A/B is judged at the current lens.

## Key A/B findings

- Trees and palms do not draw in the dormant `--models` path (fix in package 3).
- 90 of 139 nature model paths are untextured placeholders and 30 are dead: the 3D look comes from new art (packages 4-6), not from the switch.
- 3D costs about the same triangles, up to ~40 % more draw calls where rocks stand, and 8-14 % less VRAM than the cards.
- Phone frame time and a real export size still need a device run (Mac + phone or the web soak).

## Art sourcing

Blender procedural first (trees, palms, rocks, cliffs, mountains are well suited), Kenney/CC0 kits second,
Tripo/Meshy only within existing balances (never buy credits). Creatures keep their pipeline unchanged.

## What package 1 (this branch) added

- `IsoCamera`: `--cam-fov=<deg>` and `--cam-pitch=<deg>` dev flags (defaults unchanged).
- `IslandProps`: `--models` now also draws scenery kinds that list GLBs as 3D instead of cards (it already
  did this for resources through `IslandScatter.cards_enabled`).
- `scenes/dev/ab3d_lab.tscn` + `scripts/dev/ab3d_lab.gd`: shots and live render counters per variant.
- Results: docs/orchestration/reports/claude-3d-ab.md.
