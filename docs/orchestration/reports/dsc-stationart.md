# STATIONART: 3D models for the crafting stations and construction sites

Job: STATIONART (dsc-stationart). Branch/worktree: `mmo-stationart`. Owner spec:
`docs/design/durango-prompts/30_building_construction_and_crafting_stations.md` (the owner's guide 15),
read §6, §7, §8, §10, §12. This job builds **models only**; the code side (blueprints, escrow, work
timers, job queues) belongs to another package.

## What shipped

15 new GLBs in `game/assets/props/blender/`, built by the existing structure pipeline
(`tools/blender/structures/structures.py`, one builder function per model, registered in `BUILDERS`),
headless only:

```
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
  -P tools/blender/structures/build.py -- <names>
```

| model | tris | footprint (m) | AABB x/y/z (m) | what it is |
|---|---:|---|---|---|
| makeshift_workbench | 440 | 2x1 | 1.17 / 0.86 / 0.63 | tier 0: four lashed sticks, a flat stone slab, a split billet on it |
| basic_workbench | 448 | 2x1 | 1.86 / 0.99 / 0.81 | tier 1: rough planks on pillars, strap lashings, a spare plank stack |
| journeyman_workbench | 728 | 2x1 | 1.80 / 1.53 / 1.01 | tier 2: trimmed planks nailed down, a bench vice, a tool rack with hanging tools |
| expert_workbench | 868 | 2x1 | 2.00 / 1.11 / 0.93 | tier 3: processed planks, iron edge strip and corner brackets, two drawers, glue pots, jars |
| kiln | 696 | 2x2 | 2.10 / 1.65 / 1.60 | clay dome on a firebox, soot-lined mouth with embers, clay arch, chimney, firewood stack |
| loom | 460 | 2x1 | 1.72 / 1.55 / 0.50 | upright frame loom: posts, warp/heddle/top beams, warp threads, a partly woven cloth, a shuttle |
| large_loom | 684 | 3x2 | 2.53 / 1.60 / 1.06 | wider frame (22 warps), a weaver's bench, a finished cloth roll, two yarn baskets |
| oven | 584 | 2x2 | 1.75 / 1.36 / 1.59 | stone bread oven: masonry dome, arched mouth, flue, a baking peel and a bowl of dough |
| large_drying_rack | 540 | 3x1 | 3.10 / 1.95 / 0.62 | two-bay rack on three trimmed pillars, rope lashings, straps hooked over the rail |
| site_small_0 | 384 | 2x2 | 2.01 / 0.45 / 2.01 | staked-out square, sagging string outline, log pile and rolled straps |
| site_small_1 | 600 | 2x2 | 2.01 / 1.17 / 2.01 | scaffold frame half up (1.15 m), diagonal braces, smaller piles |
| site_small_2 | 468 | 2x2 | 2.01 / 2.07 / 2.01 | scaffold at full height (2.05 m), partial plank cladding on the front and right, a doorway lintel, a ladder |
| site_large_0 | 424 | 3x3 | 3.01 / 0.52 / 3.01 | as site_small_0 on a 3x3 m footprint |
| site_large_1 | 640 | 3x3 | 3.01 / 1.42 / 3.01 | as site_small_1 on a 3x3 m footprint (1.4 m frame) |
| site_large_2 | 552 | 3x3 | 3.01 / 2.52 / 3.00 | as site_small_2 on a 3x3 m footprint (2.5 m frame), scaffolding planks, a ladder |

Conventions, all inherited from the set (no existing builder's output changed):

- **one material**: the shared `structures_atlas` (1024 px, 8x8 tiles). No new tiles were painted, so
  the existing 40+ models are byte-identical in the atlas and rebuild unchanged.
- **origin at the ground centre** (Blender z = 0, x/y centred; each new builder ends with
  `_center_xy(p)`), **front faces -Y** in Blender = **+Z** in Godot, towards the iso camera.
- one glTF node per model (no sub-node pivots), no embedded image, 36-2500 triangles (384-868 here).
- real-world metres next to the 1.8 m survivor; every model is 0.4-2.5 m tall.

## Manifest

`game/data/props_manifest.json` gained **15 rows** (no existing row changed, 0 deletions): one per
model, each with `footprint`, `glb`, measured `aabb_m`, `art_status: REVIEW`, the standard `upgrade`
path and a `note`. `tools/blender/structures/check_manifest.py` was extended with the 15 kinds in
`KIND_GLB`, their footprints in `NEW_ROWS` and their notes in `NOTES`, and it rewrites the rows with
`--write`.

```
[check_manifest] PASS 56 kinds resolve to existing GLBs (56 Blender (4 of them stand-ins marked REPLACE), 0 Kenney marked REPLACE)
```

## Contact sheet

`docs/orchestration/reports/dsc-stationart-sheet.png`, rendered headless by the new
`tools/blender/structures/stationart_sheet.py`:

```
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup \
  -P tools/blender/structures/stationart_sheet.py -- docs/orchestration/reports/dsc-stationart-sheet.png
```

All 15 new models plus the old `workbench` for comparison, each on the game's opaque dirt disc
(`PropVisuals.ensure_foundation`), each with a **1.8 m figure** for scale, lit like the game (sun
elevation 50 deg, yaw -60 deg, sky ambient) and seen from the **game's iso camera**: pitch 38.7 deg
down, yaw 45 deg (`IsoCamera.PITCH_DEG` / `YAW_DEG`). The grid is laid out in screen space so the
sheet reads as rows, and each cell is labelled with the model name.

**What I saw in it and what I fixed:**

1. The four workbench tiers read as a clear progression: stone slab on sticks -> rough planks ->
   nailed planks with a tool rack -> iron-fitted bench with drawers and jars. Good.
2. The kiln's firebox mouth was hidden under an oversized dome. **Fixed**: the dome was shrunk and
   set back, the firebox made taller, the mouth widened and the arch moved up, so the glowing mouth
   now reads at the game camera.
3. The oven's dome read as one smooth grey blob. **Fixed**: it now uses the `cobble` masonry tile.
4. The site stage-2 cladding was on the back and left walls, which the iso camera never sees, so
   stage 2 looked like a bare frame. **Fixed**: the partial plank cladding moved to the two
   camera-facing sides (front -Y and right +X) and was shortened to about 60 % of the frame height,
   so the frame still shows above it and the site still reads as "under construction", not finished.
5. Stage 0's log pile was too small to read and sat on the hidden side. **Fixed**: bigger logs,
   moved to the camera side of the footprint.
6. The makeshift bench's slab read blue-grey (the `cobble` tile). **Fixed**: back to the `stone`
   tile with a split wooden billet on it, so it reads as a work surface.
7. The sheet's first draft had a diagonal layout (the grid was in world axes under a 45 deg yaw),
   no labels and a visible ground-plane edge. **Fixed**: screen-space layout, labels, a large ground
   plane.
8. The oven's side dish was a bright orange lump (the `meat_fat` tile read as raw meat). **Fixed**:
   a clay bowl of dough.

The old `workbench` is in the sheet as a reference: it is heavier and taller than the new tiers, so
the new tiers are the small-to-large progression the owner asked for, and they do not duplicate it.

## What I did not build

- **No code**: no blueprint, escrow, deposit, work-timer or job-queue logic. This job is models only.
- **No new atlas tiles**: the models reuse the set's 40 existing tiles. A dedicated `strap`, `nail`,
  `glue` or `cloth` tile would improve the later tiers but would change the atlas for every model in
  the set, which this job must not do.
- **No spinning wheel, dye vats or hide racks** (the owner's camp reference, `proc-art-01`): they were
  not in this job's list of 15 models.

## Assumptions

All sizes are **# ASSUMPTION** unless the owner's spec gives them; the spec gives only the
workbench ingredient lists, not dimensions.

1. Workbench tiers: 2x1 m footprint (the same cell as the existing `workbench` row), tops at 0.78 /
   0.85 / 0.90 / 0.95 m, so the tiers read as a size progression at the game camera.
2. `makeshift_workbench` is 1.2 x 0.6 m, top 0.78 m (task brief).
3. `kiln` 1.6 m tall overall, `loom` / `large_loom` 1.55-1.6 m tall, `oven` 1.4 m tall,
   `large_drying_rack` 3.1 m wide (task brief).
4. Construction sites: the 2x2 m and 3x3 m footprints are the **staked-out ground** areas. The
   scaffold frames are square in plan and 2.05 m (small) / 2.5 m (large) tall at stage 2, with the
   stage-1 frames at half that height. The six site models are separate models, not stages of one
   model with a `stages` array, because a construction site changes shape rather than swapping
   props; a `stages` array per site kind is the alternative the code package can pick.
5. Stage 2 keeps its plank cladding on the camera-facing sides only, so the site never reads as
   finished at the game camera.
6. The sites are placed on flat ground at z = 0 with the origin at the footprint centre; the game
   lays its own dirt disc under them.

## Verification

- `bash .../scratchpad/dsc/verify_stationart.sh m1` -> PASS (the four workbench tiers).
- `bash .../scratchpad/dsc/verify_stationart.sh m2` -> PASS (tiers + the five stations).
- `bash .../scratchpad/dsc/verify_stationart.sh 1` -> PASS (all 15: triangles, one material, origin
  at the ground).
- `python3 tools/blender/structures/check_manifest.py` -> PASS, 56 kinds.
- Full gate `bash .../scratchpad/dsc/verify_stationart.sh` (no argument: manifest + contact sheet +
  report + scope + a Godot import) -> see the run log below.
- Every model was inspected in the contact sheet render at the game camera angle; the fixes in the
  list above came out of that inspection, and the sheet was re-rendered after each fix.

## Notes for the next agent

- Rebuild any model with
  `Blender -b --factory-startup -P tools/blender/structures/build.py -- <name>`; the builders are
  plain functions at the end of `tools/blender/structures/structures.py` (section "station art
  (dsc-stationart)").
- `tools/blender/structures/stationart_sheet.py` renders the contact sheet; pass names after the
  output path to render a subset, e.g. `-- out.png kiln oven`.
- The manifest rows are named after the models, so the code package can look them up with
  `Data.props_manifest.buildings["kiln"].glb`. The six site rows are `site_small_0..2` and
  `site_large_0..2`.
- Nothing outside `tools/blender/structures/`, `game/assets/props/blender/`,
  `game/data/props_manifest.json` and `docs/orchestration/reports/` was touched.
