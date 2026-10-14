# Nature wave: rocks, ground plants and natural props

Art-only wave (no gameplay, recipes, yields, costs, climates, collision or sleep changes). Generated with Milan's existing Meshy credits; nothing was upgraded or purchased. No API key appears in any file, log or patch.

## Shipped (16 accepted GLBs, all passed the checks below)

Nature, under `game/assets/nature/generated/`; props, under `game/assets/props/meshy/` (stumps and logs are `prop` rows).

| File | Size W x H x D (m) | Triangles | Texture | File size |
|---|---|---|---|---|
| rock-a.glb | 2.092 x 1 x 2.285 | 30,722 | JPEG 1024px | 982 KB |
| rock-moss-a.glb | 2.092 x 1 x 2.285 | 30,722 | JPEG 1024px | 992 KB |
| rock-snow-a.glb | 2.092 x 1 x 2.285 | 30,722 | JPEG 1024px | 953 KB |
| cactusflowers-a.glb | 0.353 x 0.8 x 0.306 | 30,510 | JPEG 1024px | 1156 KB |
| corn-a.glb | 0.393 x 1 x 0.432 | 31,186 | JPEG 1024px | 1092 KB |
| grass-a.glb | 0.507 x 0.7 x 0.53 | 24,400 | JPEG 1024px | 1293 KB |
| grass-short-a.glb | 0.623 x 0.3 x 0.659 | 28,025 | JPEG 1024px | 1405 KB |
| wildgrass-a.glb | 0.519 x 0.8 x 0.45 | 25,593 | JPEG 1024px | 1318 KB |
| plant-a.glb | 0.269 x 0.7 x 0.278 | 26,197 | JPEG 1024px | 943 KB |
| wheat-a.glb | 0.351 x 0.9 x 0.373 | 27,191 | JPEG 1024px | 1010 KB |
| treestump-a.glb | 1.155 x 0.7 x 1.124 | 30,831 | JPEG 1024px | 979 KB |
| treestump-moss-a.glb | 1.155 x 0.7 x 1.124 | 30,831 | JPEG 1024px | 987 KB |
| treestump-snow-a.glb | 1.155 x 0.7 x 1.124 | 30,831 | JPEG 1024px | 1009 KB |
| woodlog-a.glb | 1.2 x 0.352 x 0.724 | 31,304 | JPEG 1024px | 1008 KB |
| woodlog-moss-a.glb | 1.2 x 0.352 x 0.724 | 31,304 | JPEG 1024px | 1006 KB |
| woodlog-snow-a.glb | 1.2 x 0.352 x 0.724 | 31,304 | JPEG 1024px | 1029 KB |

Every file: meters, Y up, one merged mesh, one opaque material (no alpha, so no cutout-card exception), base at Y=0, bounding box centered on X/Z, transforms applied, a single 1024 px JPEG base-color texture, no terrain plane or pad. Checked independently of the authoring tool with `tools/nature_wave_verify.py` (reads the GLB directly). Smoke: `tools/smoke.sh` printed `SMOKE PASS` with the project's Godot 4.7.1.

Accepted-only labeled sheets (front, side, three-quarter, game camera pitch -35.264 / yaw 45 at orthographic size 15 and 17 m, 1.72 m survivor stand-in): `docs/art/nature-wave/sheets/<name>.jpg`. Rejected models are not in the repo.

## Credits (balance 323 -> 43, 280 spent; all `meshy-6-lite`, costs read from each task before and after)

Text-to-3D preview 5, texture refine 10, retexture 10.

| Item | Tasks (credits) |
|---|---|
| rock-a | preview `01a13bbc-ecba-7625-a2cd-5927c4930e33` (5), refine `01a13bbe-9e43-74a7-8bb3-5c3522a27874` (10) |
| First 12 previews | 12 x 5 = 60 (cactusflower, cactusflowers, corn, flowers, grass, grass-short, lilypad, plant, treestump, wheat, woodlog, wildgrass); IDs `01a13bc0-6b7e-773c-941c-b8ce62650b59` (cactusflower), `01a13bc0-758a-743b-b6c1-122f0c1a4f9d` (cactusflowers), `01a13bc0-7c0c-7491-95df-8e842ff59485` (corn), `01a13bc0-8419-75d7-be4a-66380b527b81` (flowers), `01a13bc0-8c5a-77ba-a792-94ec024080f3` (grass), `01a13bc0-94ea-711c-9b02-f2a32fe9fa1f` (grass-short), `01a13bc0-9adc-70b1-8b24-278a8c85b36c` (lilypad), `01a13bc0-a18a-743d-a5b1-e149baa06a15` (plant), `01a13bc0-a794-72f6-9c1a-aa21ba29b7d9` (treestump), `01a13bc0-adcc-739d-8d90-c07a1533ee1b` (wheat), `01a13bc0-b444-70d5-a5e7-b74077c6ef38` (woodlog), `01a13bc0-c2ff-7641-a6b4-4d89fa41d9f1` (wildgrass) |
| Refines of accepted first-round previews | cactusflowers `01a13bc3-4dff-7094-af13-0f3f98ea4bac`, corn `01a13bc3-58ac-7524-be6c-c69bfdafdb98`, treestump `01a13bc3-63be-767a-8859-c81521b23906`, woodlog `01a13bc3-6a26-709b-afea-ed1c7a55adff`, wildgrass `01a13bc3-7063-735c-be53-75a397afb8e9` (5 x 10 = 50) |
| Reroll previews (stronger "no soil/mound/disc" prompt) | cactusflower `01a13bc3-7750-755a-848f-1c1730fb9afb`, flowers `01a13bc3-7dc8-70d9-92e0-11b0b0b2f56d`, grass `01a13bc3-86d1-75d6-bd4e-a4aac0642323`, grass-short `01a13bc3-8cd5-76f6-9c5c-ed2f7e1af98e`, plant `01a13bc3-9521-73a8-b474-3cf0abca9fa0`, wheat `01a13bc3-9da7-7042-90c7-2a633c6fb182`, lilypad `01a13bc3-a46c-73cb-9b47-0cc155824877` (7 x 5 = 35) |
| Refines of reroll previews | grass `01a13bc6-3f1a-7158-a6f6-d7766ee65cc5`, grass-short `01a13bc6-4a44-77f5-99db-034510707af9`, plant `01a13bc6-5801-73d7-9fbd-ac1684cb396d`, wheat `01a13bc6-5efc-75ab-a52b-1683e56e82a3`, flowers `01a13bc6-5187-75eb-b473-ee70f5aa8752` (5 x 10 = 50) |
| Moss/snow retextures (all rejected) | rock-moss `01a13bc6-a88c-72bb-96d5-ea286faf00c5`, rock-snow `01a13bc6-afc4-76e8-b589-db8046864497`, treestump-moss `01a13bc6-b981-72ac-9f67-aa2f434abd23`, treestump-snow `01a13bc6-bf4b-75fb-a69a-b2e70a271cfe`, woodlog-moss `01a13bc6-c5bb-76f3-91c1-6087114c7904`, woodlog-snow `01a13bc6-cc6f-747c-a5f4-0fb88b44e062` (6 x 10 = 60) |
| Third-round previews (both rejected) | flowers `01a13bc9-d338-71ef-bd0a-35084dbcf875`, lilypad `01a13bc9-dc72-7019-a234-f21f20892493` (2 x 5 = 10) |

Source task for each shipped file: rock-a, rock-moss-a, rock-snow-a from the rock-a refine; cactusflowers-a, corn-a, treestump-*, woodlog-*, wildgrass-a from the first-round refines; grass-a, grass-short-a, plant-a, wheat-a from the reroll refines.

## Acceptance and rejection

Accepted: the 16 files above.

Rejected (kept out of the repo):
- Retextured moss/snow variants (6 tasks, 60 credits): the rock "moss" and "snow" came back as plain blue-grey slate with neither; the stump and log versions barely showed moss or snow. Replaced by free local painting (below).
- First-round previews with a ground disc or soil mound: cactusflower, flowers, grass-short, grass, lilypad; plant and wheat were also too sparse (one thin stalk).
- cactusflower reroll: a lone skinny column, flower a speck, still a small base disc.
- flowers (both attempts): the first was thin stems that vanish at game distance; the second a 1.4 m mat of ragged leaf shards.
- lilypad (both attempts): a thick layered disc, then a crumpled vertical blob; neither is a thin flat leaf cluster.
- wildgrass first texture had a painted dirt ring on a soil pad (rescued by the pad trim, which is why it ships).

Not delivered, and why: **Flowers** and **Lilypad** (two failed attempts each; stopped rather than try a third) and **CactusFlower** (see mapping).

## Processing done locally (free, reproducible; `tools/nature_wave_finish.py`)

- **Pad trim** (`clip=0.05`): Meshy put a thin soil pad or mound under every small plant, which the brief forbids. Faces whose center is below 5% of the model's height were deleted (grass-a, grass-short-a, wildgrass-a, plant-a, wheat-a). Blades and stems are untouched.
- **Bark recolor** (`bark=1`): the stump and log textures were near-black grey. Dark texels were shifted toward brown. Applies to all stump and log files.
- **Moss and snow variants** (`variant=moss|snow`): painted into the base-color texture of the same mesh, by face normal through the UVs: snow on upward faces; moss in dark crack texels and on upward faces, both patchy, not coatings. The snow rock is darkened first. Same material-swap approach the trees used (README, "Material-swap variants"). Variants therefore share their base's geometry.
- Texture shrink to 1024 px JPEG for all.

## Exceptions and things to check

- **Height range 0.6-1.0 m:** `grass-short-a` is 0.3 m tall (a wide, low ground tuft; 0.6 m tall would be 1.3 m wide). `woodlog-*` are 1.2 m long and 0.35 m high (lying logs). `plant-a` is 0.7, `grass-a` 0.7, `wildgrass-a` 0.8, `wheat-a` 0.9, `corn-a` 1.0, `cactusflowers-a` 0.8. Rocks are 1.0 m high. `treestump-*` are 0.7 m high. Runtime family height overrides were not touched.
- **Footprints:** the rock is squat and wide, 2.09 x 2.29 m at 1.0 m high; the stump is 1.15 x 1.12 m including roots. Collision rules were not touched; check them against these footprints.
- **Triangle counts are 24k-31k per model** (Meshy output, not remeshed; the earlier trees are about 30k). That is heavy for batched MultiMesh foliage on mobile. A local decimate or a Meshy remesh (5 credits each, 43 left) is a reasonable follow-up.
- **Weak at game distance:** corn-a (slender, 0.4 m wide) and plant-a (one dominant stem) are the least readable at orthographic 15-17 m; flowers would have been worse, hence not shipped. Moss on the stump and log is subtle.
- Models were inspected as textured renders in Blender's Workbench renderer (flat studio light), not in Godot's lighting. Colors may read slightly different in game.

## Proposed mappings (not applied; Cleanup owns wiring, no manifest or resolver edits made)

Old family -> new path (res://):

| Old family | New path |
|---|---|
| Rock_1..Rock_7 | assets/nature/generated/rock-a.glb |
| Rock_Moss_1..Rock_Moss_7 | assets/nature/generated/rock-moss-a.glb |
| Rock_Snow_1..Rock_Snow_7 | assets/nature/generated/rock-snow-a.glb |
| CactusFlower_1 | assets/nature/generated/cactusflowers-a.glb (no CactusFlower of its own; the cluster stands in) |
| CactusFlowers_2..CactusFlowers_5 | assets/nature/generated/cactusflowers-a.glb |
| Corn_1, Corn_2 | assets/nature/generated/corn-a.glb |
| Grass, Grass_2 | assets/nature/generated/grass-a.glb |
| Grass_Short | assets/nature/generated/grass-short-a.glb |
| WildGrass | assets/nature/generated/wildgrass-a.glb |
| Plant_1..Plant_5 | assets/nature/generated/plant-a.glb |
| Wheat | assets/nature/generated/wheat-a.glb |
| TreeStump | assets/props/meshy/treestump-a.glb |
| TreeStump_Moss | assets/props/meshy/treestump-moss-a.glb |
| TreeStump_Snow | assets/props/meshy/treestump-snow-a.glb |
| tree_stump | assets/props/meshy/treestump-a.glb (clean) and treestump-moss-a.glb (moss) |
| WoodLog | assets/props/meshy/woodlog-a.glb |
| WoodLog_Moss | assets/props/meshy/woodlog-moss-a.glb |
| WoodLog_Snow | assets/props/meshy/woodlog-snow-a.glb |
| Flowers | unchanged (no accepted replacement) |
| Lilypad | unchanged (no accepted replacement) |

Integration notes for Cleanup: the direct felled-tree path in `game/scripts/world/harvest_node.gd` still loads `WoodLog_Moss.glb`, so the manifest entry alone will not change it. Rocks and foliage use first-MeshInstance3D MultiMesh extraction; every file here is exactly one mesh with one surface.

## Next agent

Re-run any file with `tools/nature_wave_finish.py` (options in its docstring), `tools/nature_wave_run.sh`, `tools/nature_wave_sheet.py`, `tools/nature_wave_verify.py`. Blender is at /Applications/Blender.app. Flowers and Lilypad still need a model if wanted; 43 credits remain.
