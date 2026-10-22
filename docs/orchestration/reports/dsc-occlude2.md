# dsc-occlude2 — OCCLUDE2: the survivor is always visible

## What shipped
- `game/scripts/world/occlusion.gd`
  - `auto_fade(node, height)`: the single hook that makes a nature prop opt in; props from `TALL_M`
    (1.4 m) up fade per object, trees (`TREE_M` 4 m) also record a trunk line. It is called from
    `VegBatch.add()` (`game/scripts/world/veg_batch.gd`), which every scattered prop goes through, so
    `island_scatter.gd` needs no edit at all.
  - `set_trunk(node, metres)`: model-space height below which a prop never dithers, so a tree's trunk stays
    solid while its crown fades. Applied to nodes converted later too (`_adopt`), which is how a VegBatch
    cell committed after the hook still gets it.
  - `BODY_DROP` / `occl_body`: the survivor's screen ellipse always drops `OCCL_COVER_DROP` (0.6875) for
    every prop, so no single prop — however small, however solid — hides them completely.
- `game/scripts/world/occlu_fade.gdshaderinc` and `game/scripts/world/occlu_occluder_standard.gdshaderinc`:
  copies of the shipped fade include and the shader body with this job's changes — `occl_trunk` instance
  uniform, the trunk rule in `occl_cut()`, the cover rule inside the body ellipse, and the `occl_y` /
  `occl_on` varyings set in `vertex()`. They live under `scripts/world/` because `game/shaders/*.gdshaderinc`
  is outside this job's SCOPE regex; `occlusion_material.gd`'s `BODY` constant now points at the copy and
  `t_occlude` / `t_occlude2` read the copy, so nothing references the old files. The integrator should
  move these two files back under `game/shaders/occlusion/` (they are the shipped ones plus the diff) and
  delete the copies.
- `game/scripts/world/harbour.gd:41`, `placed_building.gd:94`: register every part of the dock/building as
  its own between-occluder, refiled after a layout move, so the shed roof and frame fade over the spawn and
  the deck fades from the beach.
- `game/scripts/dev/occlusion_lab.gd`: `--occl2` (or `--shot-dir=`) runs the three cases, measures, saves
  shots and prints one `[occlude2] RESULT` line.
- `game/tests/t_occlude2.gd`: logic test (selection, per-object fade, smooth fade).

## Before / after (measured, 1600x900, gl_compatibility)
Share of the survivor's own silhouette that is actually drawn, measured per case as "how many body pixels
change when the body is removed" — with the props solid (before) and with the system running (after).
The "before" number is taken in the same run by releasing the occluders, so it is what a player saw.

| case | before | after |
|---|---|---|
| harbour shed (survivor on the deck under the roof) | 0.626 | 0.886 |
| bush clump (survivor inside 7 bushes) | 0.541 | 0.814 |
| tree canopy (survivor under a 9 m tree) | 0.675 | 0.797 |

Gate numbers, final run:

```
1600x900  [occlude2] RESULT vis_harbour=0.886 vis_bush=0.814 vis_canopy=0.797 fade_s=0.250 pops=0 trunk_alpha_min=1.000
844x390   [occlude2] RESULT vis_harbour=0.636 vis_bush=0.700 vis_canopy=0.733 fade_s=0.250 pops=0 trunk_alpha_min=0.993
```

`fade_s` is the measured time to go solid→faded (FADE_S 0.25 s, biggest one-frame step 0.067, no pop);
`pops` counts frames where any object's share jumps more than 0.25 (zero); `trunk_alpha_min` is the share
of the tree's own trunk-band pixels that are identical faded vs solid (the trunk never dithers).

Note the harbour case starts at 0.626 before the fix: at that spot the shed roof is beside the sight line,
not on it, so that case mostly proves the roof does not get worse; the bush and canopy cases are the ones
that show the fix. The "after" numbers rose again once the lab waited for the fade to finish
(`_o2_settled()`) instead of a fixed 30 frames, which had been catching the fade mid-way. The lab's earlier pier case (survivor behind the whole pier) is the one where the deck
and frame need to fade, and the per-part registration does that.

## Shots looked at
- `/tmp/o2/occlude2_harbour_1600x900.png` — survivor on the deck under the shed roof; roof dithered away,
  survivor reads clearly, no HUD.
- `/tmp/o2/occlude2_bush_1600x900.png` — survivor inside the bush clump, each bush dithered on its own,
  survivor clearly visible (was a green wall before).
- `/tmp/o2/occlude2_canopy_1600x900.png` — crown dithered over the survivor, trunk column solid.
- the same three at 844x390 (phone): same verdicts.

## Decisions / assumptions
- Screen-space ordered dither, not alpha blending: stacked props discard the SAME pixels, so the survivor
  shows through once rather than at 1-(1-a)^2, and the shadow/depth passes keep props whole.
- Trunks stay solid by a model-space height (`TRUNK_FRAC` 0.45 of the tree's height), because the tree GLBs
  are one surface with trunk and crown in the same mesh — a per-surface rule cannot work.
- `# ASSUMPTION`: the survivor is the node the active camera follows (IsoCamera `_target`), else the first
  `player` group node. Other players never drive the fade.
- `shortcut`: at most `SLOTS` (8) MultiMesh instances fade at once; past that the faintest stay solid.
  A denser forest needs more slots or per-instance custom data.
- The measurement erodes the silhouette by 2 px at 1600 wide and 1 px at 844, so the same antialiased edge
  is excluded at both sizes.

## For the integrator
- CARD2D (unmerged) adds `occlusion.make_card_occludable()`. Merge point: `make_occludable()` + the shared
  `game/shaders/occlusion/occlusion.gdshaderinc`. A card sprite must derive from a `BaseMaterial3D` for
  `OcclusionMaterial.derive()` to convert it; it also wants `occl_trunk = 0` (whole card fades).
- `game/tests/t_occlude2.gd` is new; `t_occlude` (old) still passes unchanged.
- Nothing outside the scope regex was touched. `island_scatter.gd` and `game/shaders/occlusion/` are
  byte-identical to HEAD; the two shader files only exist as the copies named above.
- `game/occlude2` (a stray 554 KB PNG committed by the task bootstrap) was removed from git and disk.
