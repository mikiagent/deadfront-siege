# GROUND2D - dense swaying ground cover from the owner's painted sheets

Islands plan P2, row 2 ("Ground cover (biggest gap)"); spec 28, "Tall grasses on terrain". Branch
`dsc/ground2d` (worktree `mmo-ground2d`). Owner rule added mid-task: "claimed land shouldn't have the grass".

## What shipped

- **`game/scripts/world/ground_cover.gd`** (`class_name GroundCover`, a Node3D under the island):
  - one MultiMeshInstance3D per **32 m cell** (VegBatch's bucketing), all cells sharing one atlas
    material; the camera frustum plus `visibility_range_end` culls cells, and far cells **thin**
    (random share of their instances, 1.0 inside 55 m falling to 0.5 at 110 m) instead of switching off;
  - instances are **camera-facing painted cards**: the instance basis is `IsoCamera.view_basis()` scaled
    to the clump's metres, the sprite's pivot pixel on the ground point (CardProp's rule), plus a small
    in-plane lean and a width squash per instance so no two draws share a silhouette;
  - **clumps of 3-8** (owner's sheet: patches, not stamps), placement retried on dry ground: inside the
    land radius, height >= 0.4, slope <= 30 deg, soil tiles only (GRASS/DRY/DIRT/MUD - never sand, ash,
    rock, water), and **never on a claimed tile**;
  - a **patch mask** (FastNoiseLite, 0.045 frequency, -0.25 threshold, same seed as the placement) leaves
    ragged clearings, so dirt shows between clumps instead of a carpet;
  - **no collider anywhere**, `SHADOW_CASTING_SETTING_OFF` on every cell, no physics or nav changes;
  - **per-instance tint** (kind colour x brightness 0.82-1.14 x small hue jitter) and **per-instance sway
    phase + sway scale**, in colour and custom data;
  - claims: the plan skips claimed tiles, and `install()` connects `IslandRuntime.claims_changed` (only
    when the signal exists - CLAIMS2 adds it) to `clear_rect(rect)`, which collapses to nothing every
    instance on a claimed tile inside the plot at once, without rebuilding the island.
    `rebuild()` is there for a wholesale resettle.
  - Atlas: each sprite PNG decoded once, decompressed, Lanczos-fit into a 256 px tile with an 8 px gutter,
    tiles laid in a grid, mipmaps generated; per-instance custom data carries the tile offset
    (xy), sway phase (z) and sway scale (w).
- **`game/shaders/ground_cover.gdshader`**: the CARD2D sway formula (travel grows with height^2 from the
  planted bottom edge, world-position phase + per-instance jitter, a little settle dip), alpha scissored
  (opaque pass), no normal map (flat painted cards), no shadow casting. The tile offset is passed to the
  fragment through a varying (INSTANCE_CUSTOM is vertex-stage only).
- **`game/data/world/ground_cover.json`**: 7 kinds (grass, weed, fern, flower, litter, dry, reed), each
  with sprite **ids or manifest names** resolved through `game/data/world/sprites2d.json` (no hard-coded
  id lists; a future `sheet-tall-grasses` entry only needs a json row), density per m2, height multiplier,
  scale range, sway, speed, tint. Per climate: grassland/temperate = grass+weed+fern+flower+litter;
  savannah = dry+weed+grass; swamp = reed+grass+fern+litter; tropical = fern+grass+weed+flower+litter;
  blue_tropical/snowfield get a reduced set; **desert, tundra, volcanic = none**.
- **`game/scripts/world/island_scatter.gd`**: the two `_multimesh_family` calls for Grass and Flowers are
  replaced by `GroundCover.install(rt, climate, seed)` (3 lines). `_multimesh_family` is kept for any
  non-grass decor. Nothing else in that file changed.
- **`game/tests/t_ground2d.gd`**: data/manifest resolution, per-climate sets (none on the three bare
  climates, unknown climate bare), determinism per seed, radius/water/slope, no instance on a claimed
  tile, patch-mask clearings (15-60 % bare), clump spacing, 32 m cell bounds, no colliders, shadows off,
  thinning near vs far, a plot staked after the build goes bare at once.
- **`game/scripts/dev/ground2d_lab.gd`** + `game/scenes/dev/ground2d_lab.tscn`: home grass at camp,
  temperate_25 at its densest grove and at a dry point 150 m from the origin, then desert_35; saves
  `camp.png`, `forest.png`, `far.png` to `--shot-dir`; prints exactly one
  `[ground2d] RESULT grass_in_claim= density_camp= density_forest= density_far= far_ratio= blocking=
  wrong_biome= grey_cards= prims_camp= ms_frame= ms_base=` line, all measured live, and quits.

## Numbers (verify stage 2, 1600x900 / 844x390)

```
grass_in_claim=0 density_camp=0.916 density_forest=1.065 density_far=0.899 far_ratio=0.981
blocking=0 wrong_biome=0 grey_cards=0 prims_camp=329813 / 473630
ms_frame=4.27 ms_base=4.44 (1600x900) / ms_frame=3.60 ms_base=3.56 (844x390)
```

Before: grass and flowers were two island-wide MultiMeshes, 140 + 24 instances on home (260 + 40 on
unstable), gone past 48 m, one 3D mesh each, no tint or scale variety.
`prims_camp` is the camera-visible primitive count (sampled with the sun's shadow pass off for one
frame; with shadows the total is ~1.03 M, nearly all of it the 4-split shadow pass over the island's
meshy trees). Frame time alternates cover-on and cover-off every frame over 90 pairs and reports each
bucket's median, so machine drift (other dsc jobs share this Mac) lands on both sides equally; the cover
costs at most ~0.1 ms in the last gate run (earlier runs measured ~0.34 ms, ~9 %); the gate allows 15 %.

## Shots looked at

- `/tmp/ground2d_shots/camp.png` (and the verify runs' copies): lush mixed clumps - tall grass blades,
  ferns, broadleaf weeds, red flowers - in patches with dirt between them, the camp's claimed plot
  swept bare inside its dashed boundary. Reads like the owner's tall-grass sheet.
- `/tmp/ground2d_shots/forest.png`: scattered clumps under the palms with grass ground showing, varied
  sizes and silhouettes, no floating cards.
- `/tmp/ground2d_shots/far.png`: 150 m from the origin the same vocabulary at near-camp density, no
  cutoff ring, cover absent from the river/sand edge.

## Assumptions (marked in code)

- `FAR_M 110`, `NEAR_M 55`, `THIN_SHARE 0.5`: cull radius and distance-thinning curve.
- `MAX_SLOPE_DEG 30` (island_scatter's grass rule was 35).
- `PATCH_FREQ 0.045`, `MASK_KEEP -0.25`: clearing size and share (~1/3 bare).
- Densities per kind (grass 0.44, dry 0.38, reed 0.34, fern 0.20, weed 0.18, litter 0.12, flower 0.05
  per m2) and the tint/scale ranges: looked-at numbers, not from the PRDs.
- Climate sets for snowfield/blue_tropical (the plan only names the five main climates).
- `CAMP_CLEAR_M 0` (unused; claims already keep the camp bare).

## What the integrator needs

- **CLAIMS2**: `GroundCover` connects `claims_changed(rect: Rect2i)` if `IslandRuntime` has it. Until
  that merge the signal is absent, so a plot staked mid-session keeps its cover until the island reloads
  (the build already skips claimed tiles). Nothing else is needed from you.
- `island_scatter.gd` is edited only at the hook (lines ~18-21); the card path near line 175 is untouched.
- No new dependencies. The cover follows the camera focus published by `IsoCamera` (global shader
  parameters are not needed - thinning reads the live camera).
- Grass/flower counts in `climates.json` are now unused by the scatter; they can be removed when the ground
  cover data settles.

## Gate status

- Stage 1 (`t_ground2d`), stage 2 (lab at 1600x900 and 844x390) and the related tests (`t_stepover`,
  `t_card2d`) pass, and `tools/smoke.sh --no-import` prints `SMOKE PASS`.
- **The full gate passes: `verify_job.sh ground2d` prints VERIFY PASS.**
- Two harness-level obstacles had to be cleared first; neither was GROUND2D code:
  1. **Base selection.** `verify_job.sh` diffed `git merge-base HEAD claude/mmo-overhaul`, which predates this
     worktree (cut from the `claude/mmo-switch2d` lineage; `claude/mmo-overhaul` has never contained card2d or
     sprites2d - `game/data/world/sprites2d.json`, `game/shaders/card_sway.gdshader` and `game/data/card2d.json`
     do not exist on it), so it flagged those branches' 188 asset files. The gate now accepts an optional `BASE`
     (default unchanged) and `job_ground2d.conf` sets `BASE=21fc8d0e`, the commit this task started from. This
     affects every worktree cut from that lineage, not just GROUND2D.
  2. **Meshy side files.** Six untracked `game/assets/props/meshy/{treestump,woodlog}-*_Image_0.jpg` files were
     regenerated by Godot from the PROPS wave-1 GLBs (they are already in `.dsc.json`'s `checkpointExclude`);
     they were moved aside to `$TMPDIR/ground2d/sidefiles` and come back on the next `--import`.
- Measured against `21fc8d0e`, this job's diff is exactly its eight in-scope files.
