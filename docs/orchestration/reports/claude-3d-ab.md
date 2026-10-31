# 3D A/B (package 1 of the full-3D plan)

Branch claude/mmo-3d-ab, base claude/mmo-overhaul@432c79c9. Plan: docs/design/full-3d-plan.md.
Side-by-side sheet: project files 3d-ab/ab3d_side_by_side.jpg (rows jungle_camp, jungle_trees,
jungle_rocks, home_trees; columns today's cards, 3D models at today's camera, 3D models at a 30 deg lens
pitched -45).

## How it was run

Cloud box, Godot 4.7.1 Linux, Xvfb + Mesa llvmpipe (software GL), `--rendering-method gl_compatibility`
(the web renderer), 1600x900:

    Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
      --lab=ab3d_lab --shot-dir=DIR --tag=cards
    ... --models --tag=models
    ... --models --cam-fov=30 --cam-pitch=-45 --tag=models_wide

Frame times are a software rasterizer's (~1 s a frame): compare columns with each other only. Draw calls,
primitives and VRAM are renderer counters and do not depend on the GPU.

## Results

| View | Variant | Draw calls | Primitives | VRAM MB |
| --- | --- | --- | --- | --- |
| jungle_camp | cards | 150 | 397,548 | 279.9 |
| jungle_camp | models | 170 | 407,740 | 241.9 |
| jungle_camp | models_wide | 193 | 445,280 | 241.9 |
| jungle_trees | cards | 137 | 305,688 | 279.9 |
| jungle_trees | models | 120 | 312,002 | 241.9 |
| jungle_trees | models_wide | 123 | 326,574 | 241.9 |
| jungle_rocks | cards | 135 | 393,912 | 279.9 |
| jungle_rocks | models | 187 | 403,792 | 241.9 |
| jungle_rocks | models_wide | 189 | 432,980 | 241.9 |
| home_trees | cards | 159 | 740,446 | 291.7 |
| home_trees | models | 141 | 670,122 | 269.7 |
| home_trees | models_wide | 166 | 660,136 | 269.9 |

Read: the 3D variants cost about the same triangles (+/-10 %), up to ~40 % more draw calls where rocks and
logs stand (each GLB model is its own MultiMesh), and 8-14 % LESS video memory (the painted atlases are
bigger than the GLB textures). The 30 deg lens adds 5-15 % draw calls and primitives at the same zoom.
None of these numbers is a blocker for a mid-range phone; the real phone number still needs a device run.

## Findings that shape the plan

1. **Trees and palms do not draw in the 3D path.** Under `--models` every tree/palm harvest node keeps its
   ground disc but no mesh appears (no shadow either), in both lenses, with or without `--no-occlusion`,
   and with the shader-instance buffer raised to 65,536. The GLBs load and measure right (palm 12 m,
   birch 15 m, common 8 m). The `--models` path has been dormant since SWITCH2D (10-21) and rotted.
   Cause not found inside this package's time box; package 3 (claude/mmo-3d-resources) owns the fix.
2. **The 3D models we have are placeholders.** Of the 139 model paths in data/nature_manifest.json, 90 GLBs
   carry no textures (flat vertex colour), 30 paths no longer exist, 19 are textured. In the sheet the 3D
   rocks and logs read as grey blocks next to today's painted art. The 3D look depends on new art
   (packages 4-6), not on flipping the switch.
3. **Download size does not change at the switch.** The web pack already ships both the painted sprites and
   the GLBs (tools/export_web.sh: build ~320 MB, cap 330 MB). Going 3D adds only the new models (estimate
   +50-150 MB for ~350 textured models with LODs) and removes the painted sprites once retired (-25 MB).
   Creature and survivor textures (survivor 69 MB of the web pack) are the bigger lever (package 8).
   A fresh export was not run here (no export templates on the cloud box).
4. **Compatibility renderer already overflows its shader-instance buffer** on both variants ("Too many
   instances using shader instance variables", 70-126 per run, max 4,096 items here; web is 1,024).
   Occlusion already turns itself off on web for this reason. Package 8 must settle it.
5. **Shadow discs stand alone** where trees are missing; the disc layer must follow the tree visual.

## Not done here (needs a device)

- Phone frame time: needs the Mac + a phone (tools/install_device.sh) or the web soak (tools/web_soak).
- A real export size of each variant.

## Code in this package

- `IsoCamera`: `--cam-fov=<deg>`, `--cam-pitch=<deg>` dev flags; defaults unchanged.
- `IslandProps`: under `--models`, a scenery kind that lists GLBs draws them instead of its cards.
- `scenes/dev/ab3d_lab.tscn`, `scripts/dev/ab3d_lab.gd` (`--only=<view>` to run one view).
