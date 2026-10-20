# dsc camp pieces: Blender models for the 18 kinds that were still Kenney placeholders

Owner brief: the camp read as a mixed world because 18 placeable buildings fell back to salmon-pink
Kenney models. Each now has its own hand-built GLB from the same kit (`tools/blender/structures/lib.py`,
the shared 1024 `structures_atlas.png`), the same palette and edge density as the tent/workbench/well set,
and a manifest row (`art_status` REVIEW, upgrade path filled by `check_manifest.py --write`).

A dsc (DeepSeek) worker built the first pass. Claude Code (implementer, round 2) fixed the review findings
listed below. The fixes were small parameter changes that needed visual judgment against in-game shots, so
they were made directly in the builder, not handed to a second dsc worker.

The atlas and the 24 merged GLBs are byte-identical (gate step 3 checks the hash file). The only edits to
shared helpers are optional arguments with defaults (`_teepee(z0=0.04)`, `_stone_ring(cx=0, cy=0)`), so the
merged builders produce the same output.

## Round 2 fixes (review of 2026-10-20)

| finding | fix |
|---|---|
| **major** dirt disc buries ground detail: `PropVisuals.ensure_foundation` draws an opaque disc at y = 0.08 m under every building except straw_roll. 73-76 % of each field's top area was under it, so the fields read as empty pallets, and the fires showed no glow | New `GROUND = 0.08` in `structures.py`. Field: the bed top is at 0.10 m, a dark `soot` tilled layer sits over it as the furrow floor, ridges run from 0.105 to 0.19 m with narrower crowns so the dark furrows show between them, and the border logs are centred at 0.13 m. Bedroll, tent_canvas floor (sheet, mat, pillow, crate, pot, pole stones), campfire_stand, fishing_stand and stone_grill ember/ash beds, and the log_shelter yard fire, rope coil and firewood now sit on the disc. Measured with the reviewer's `buried.py`: 0 % of the upward-facing area is below 0.085 m for the eight affected pieces (cabin_bed was never affected and stays at 1 %, the boot soles). |
| preview sheets had no disc | `preview.py` draws the disc (radius = half the footprint diagonal + 1 m, at 0.08 m, skipped for straw_roll) after framing, so the sheets show what the game shows. |
| minor cabin_bed mattress 1.56 m, shorter than the 1.8 m survivor | Frame `L = 2.0`, mattress `L - 0.16 = 1.84 m`, foot rail moved out. The stool and lamp moved to the camera-side long edge by the head, and the boots moved beside the foot. The bed is centred on its AABB (2.04 x 1.29 m, within 2x2 + 5 %). |
| minor bedroll pad 1.56 m | Pad 1.8 m on a 1.94 m sheet with seam bands at both ends. |
| minor fence_fortified 1.38 m, lower than the plain fence | Stakes are 2.0-2.2 m with 0.32 m points, rails at 0.45 and 1.45 m, the front row reaches 1.3-1.5 m, and the brace runs up to 1.5 m. AABB height is 2.22 m. Still a 2 m modular run. |
| minor log_shelter doorway 1.49 m | Eave 1.98 m, ridge 3.0 m: 1.9 m clear under the lintel. Side walls have five logs (about 0.9 m). 1636 tris. |
| (found while fixing) log_shelter yard fire ring | The ring of stones was centred on the hut, under the roof, not on the yard fire at (-0.85, -1.4). It is now centred on the fire. |
| minor field collider 0.82 m tall (hoe handle) | The hoe lies across the near rows, the stakes are shorter, and nothing rises above 0.33 m. AABB height is 0.34 m (field_small and field_large). |
| minor out-of-scope files on the branch | Commit `009c6a00`: every file outside this package now matches `claude/mmo-overhaul` at `cdb2c165`, so `git diff claude/mmo-overhaul` lists only this package's paths. The six Meshy `.glb.import` files and 30 generated `.uid` files are untracked again (they stay on disk in this worktree), and `TASK.md` moved from the repo root to `tools/dsc/camp/TASK.md`. |
| minor tri budget under the brief's 300 floor | straw_roll gets 16-segment roll and ties and a third tie (324 tris), bedroll gets the second seam band (304), signpost gets two nail heads (336). Every kind is now inside 300-2500. |
| minor report contradicted itself | Rewritten (this file). |

## Round 3 (finishing the r1 findings, 2026-10-20)

- **Fields skip the foundation disc.** `PropVisuals.ensure_foundation` returns early for field_small and
  field_large as it does for straw_roll; `preview.py` skips the disc for them too, so the sheets match.
  The bed (solid from the terrain up to 0.10 m) stays as a raised bed.
- **Furrows clearly darker than ridges.** The ridges use `clay_dark` (warm brown) over the `soot` furrow
  floor. The round-2 `dirt` ridges read pale tan, like slats; now the fields read as tilled soil in
  Forward+, gl_compatibility and at 844x390.
- `verify_camp.sh` step 4 accepts `game/scripts/world/prop_visuals.gd` (allowed by the brief).
- Branch merged with `claude/mmo-overhaul` (W1-UI, W1-SRVDOM, codex-animals, W2-PLAYER); `git diff
  claude/mmo-overhaul` outside `work/` and `tools/` lists only the report, `props_manifest.json` and
  `prop_visuals.gd`.
- In-game shots after the change (probe lab with all 18 kinds plus workbench/well/tent and survivor
  stand-ins; Forward+ 1600x900, gl_compatibility 1600x900, gl_compatibility 844x390), looked at:
  fields read as dark-furrowed soil inside a log frame with no dirt disc; fence taller than a survivor;
  survivor fits under the shelter lintel; bed longer than the survivor; campfire coals glow; tent floor
  and bedroll visible. Shots: implementer scratchpad `camp/shots/{fwd,gl,phone}_*.png`.

## Per kind

| kind | tris | AABB (m, x × y up × z) | atlas tiles |
|---|---|---|---|
| large_box | 568 | 1.95 × 1.46 × 1.05 | plank, wood, wood_dark, iron, rope, hide, weave, soot |
| chest | 432 | 0.83 × 0.48 × 0.62 | plank, wood, iron, wood_dark, soot |
| barrel | 308 | 0.77 × 0.90 × 0.77 | wood, wood_dark, soot, water, iron |
| bucket | 396 | 0.36 × 0.45 × 0.34 | wood, wood_dark, soot, water, iron, rope |
| signpost | 336 | 1.01 × 1.87 × 0.34 | bark, wood, wood_dark, sign_board, rope, cobble, log_end, iron |
| bedroll | 304 | 0.84 × 0.38 × 1.94 | hide, weave, fiber, leather_dark, rope, wood |
| straw_roll | 324 | 0.82 × 0.47 × 1.86 | hide, thatch, fiber, rope |
| campfire_stand | 796 | 0.93 × 0.94 × 0.91 | stone, ash, ember, wood_dark, rope, bark, meat_drying, meat_dried, iron, clay, clay_dark |
| technical_workbench | 644 | 1.78 × 1.25 × 0.84 | plank, deck_dark, wood, wood_dark, bark, log_end, iron, rope, stone_dark, water |
| grindstone | 448 | 0.87 × 0.71 × 0.49 | wood, wood_dark, stone_dark, stone, iron, rope, water, fiber |
| fishing_stand | 1512 | 0.94 × 1.07 × 0.73 | stone_dark, stone, ash, char, ember, wood_dark, wood, rope, fish, hide, soot |
| stone_grill | 840 | 1.34 × 0.54 × 1.35 | stone, stone_dark, cobble, ash, char, ember, fish, meat_drying, meat_raw, clay, clay_dark, iron |
| tent_canvas | 804 | 2.90 × 2.27 × 1.85 | wood, wood_dark, canvas, canvas_slope, leather_dark, rope, stone, hide, weave, fiber, clay, clay_dark, plank |
| fence_fortified | 1052 | 2.06 × 2.22 × 0.56 | bark, log_end, wood, wood_dark, rope, stone |
| field_small | 756 | 1.79 × 0.34 × 1.80 | dirt, clay_dark, soot, bark, log_end, wood, wood_dark, iron, weave, fiber, water |
| field_large | 1008 | 2.79 × 0.34 × 2.80 | same as field_small |
| log_shelter | 1636 | 3.39 × 3.14 × 3.33 | bark, log_end, wood, wood_dark, thatch, rope, hide, plank, fiber, clay, clay_dark, stone, ash, ember, char |
| cabin_bed | 620 | 2.04 × 1.15 × 1.29 | plank, wood, wood_dark, bark, log_end, hide, leather_dark, fiber, rope, canvas, clay, ember |

Sheets: `work/sheets/<kind>.png` and `work/sheets/all.png` (all 18 next to tent/workbench/well, with
the foundation disc). The 12 changed kinds and all.png were rendered again in round 2. `work/` is review
material and does not merge.

## Caveats for the integrator and Cursor

- **Foundation disc.** The models assume the 0.08 m disc, except straw_roll and the two fields, which
  `PropVisuals.ensure_foundation` now skips (round 3, the one `prop_visuals.gd` edit the brief allows).
  A field is its own dirt: its 0.10 m raised bed stands on the terrain, not in a round patch twice its
  size. If Cursor ever skips the disc for another kind, that model's ground detail floats about 8 cm up.
- **11 of the 18 kinds cannot be placed in game yet.** Only stone_grill, field_small, field_large,
  straw_roll, log_shelter and cabin_bed have kits, and `BuildPlacer._spawn` handles only those. chest
  shows only as the camp CargoWarp. campfire_stand, technical_workbench, grindstone, tent_canvas,
  bedroll, large_box, barrel, bucket, fence_fortified, signpost and fishing_stand have no kit and no
  `_spawn` case, so players never see them, and the chest/large_box storage and barrel water checks have
  no in-game path. Orchestrator call: give them kits and `_spawn` cases (Cursor), or accept them as
  art-only for now.
- **Stray Meshy JPGs (separate fix).** `game/assets/props/meshy/{treestump,woodlog}*.glb` are tracked on
  overhaul without their `.import` files. A fresh Godot import uses the default settings and extracts
  `*_Image_0.jpg` next to them, as an untracked file. The dsc worker had set `embedded_image_handling=3` in
  those `.import` files, which embeds the image uncompressed and grows each `.scn` to 2.8-3.6 MB in every
  web pack. That change is dropped from this branch. Fix it on its own, by gitignoring the extracted JPGs
  or adding them to the export filter.
- **ASSUMPTION:** `fishing_stand` and `signpost` are decorative placeables (the PRDs give no mechanic for
  them), and `stone_grill` is a cooking station variant with no new mechanic.

## Design decisions (from the first pass, still true)

- No raw boxes: shapes are segmented, bevelled by rotation, or built from the kit's `log`/`rock`/`cyl`
  primitives. Long planes are split so that no single facet catches the sun and reads as a plank.
- The front faces -Y (+Z in Godot, towards the camera) for every new piece. tent_canvas is the exception:
  like the existing tent, it is open on its long side.
- log_shelter: gable roof with the ridge running into the depth and the open gable front facing the
  camera, so the interior reads.
- fence_fortified keeps the plain fence's 2 m modular rhythm (neighbours meet end to end at ±1.0).
- bucket and barrel stay under their 1 m cell (0.36-0.77 m).

## What I verified

- `python3 -I tools/blender/structures/check_manifest.py`: PASS for 41 kinds. The manifest rows were
  rewritten with `--write` after the rebuild.
- The atlas and the 24 base GLBs match `tools/dsc/camp_base_glbs.sha256`.
- Burial: the reviewer's `buried.py` reports 0 % of the upward-facing area below 0.085 m for field_small,
  field_large, bedroll, tent_canvas, campfire_stand, fishing_stand, stone_grill and log_shelter. Before
  the fix the numbers were 73, 76, 51, 28, 37, 63, 20 and 1 %.
- In game, with the reviewer's probe lab (all 18 placed plus workbench/well/tent, survivor stand-ins) in
  Forward+ 1600x900, gl_compatibility 1600x900 and gl_compatibility 844x390: the fields read as tilled
  soil, with light ridges and dark furrows inside a log frame, including at phone size. The campfire_stand
  coals glow. The tent floor, the bedroll and the shelter's yard fire are visible. The fortified fence
  stands taller than a survivor, a survivor fits under the shelter lintel, and the bed is longer than the
  survivor.
- Full gate: see below.

## What I would improve

- Fish (`fishing_stand`, `stone_grill`) are the least convincing shapes: flattened icospheres with a prism
  tail.
- Fields would sell better with crops. The PRD has no crop art yet, so the shoots are flat fibre leaves.
- The `soot` furrow tile is grey-black more than dark brown. A dedicated `tilled` atlas tile would read
  warmer, but it needs an atlas change, which the gate forbids for this package.
- The set is albedo-only. A normal map would let the atlas grain work on big surfaces.

## Report for the next agent

- Squash only these paths: `tools/blender/structures/{structures,check_manifest,preview}.py`, the 18
  GLBs and their `.glb.import` files in `game/assets/props/blender/`, `game/data/props_manifest.json`,
  `game/scripts/world/prop_visuals.gd` (fields skip the disc), this report, and optionally `tools/dsc/{verify_camp.sh,camp_base_glbs.sha256,camp/TASK.md}`. Drop
  `work/`. Everything else on the branch equals overhaul `cdb2c165`.
- Rebuild a model with `Blender -b --factory-startup -P tools/blender/structures/build.py -- <name>`.
  Build named models only: a build with no names rewrites every GLB. Then run
  `python3 -I tools/blender/structures/check_manifest.py --write`, then
  `preview.py -- work/sheets/<name>.png <name>`.
- New `.glb.import` files are part of the change: without them, `t_structart` sees `StandardMaterial3D_*`
  instead of `structures_atlas.tres`.

## Full gate result

`./tools/dsc/verify_camp.sh` (full), 2026-10-20, after the last rebuild: exit 0, `VERIFY PASS`.

```
18/18  PASS <kind> -> <glb>
check_manifest PASS, atlas and 24 base-GLB hashes unchanged, scope clean against claude/mmo-overhaul
PASS t_structart / PASS t_build / PASS run_all / PASS build_lab / PASS smoke
```

In-game shots for review (outside the repo, in the orchestrator scratchpad): `camp-fix/shots/fix_{fwd,gl,phone}_*.png`,
taken with the same probe lab and camera set-ups as the reviewer's `camp-review/r1/shots/after_*`.
