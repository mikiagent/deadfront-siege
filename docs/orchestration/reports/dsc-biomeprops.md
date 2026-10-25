# BIOMEPROPS — the biome prop models render correctly again

Owner, 2026-10-22: "props are broken". Filed as "the hyphen model ids never existed, so the props
were never placed". **That is stale in this tree**: `git show` of the merge commit `55f60fb3` shows
`game/data/world/props.json` was already remapped to the shipped underscore GLBs, and
`island_props` places them (measured: home_grassland draws rock_spire, termite_mound, aloe, fern,
reeds, plume_grass, fallen_log, driftwood). The props really were broken, but by two other defects,
both now fixed and covered by a test.

## What shipped

| File | Change |
|---|---|
| `tools/blender/biome_props/bp_lib.py` | `paint()` stores the authored sRGB palette **verbatim** in `COLOR_0` (was pre-converted to linear). Docstrings corrected. |
| `game/assets/nature/biome/*.glb` (25) | Rebuilt with `Blender --background --factory-startup -P tools/blender/biome_props/build_all.py`; triangle budgets still hold; no palette constant or geometry changed. |
| `game/data/world/props.json` | `radius_m` raised so every biome model's AABB height is inside the kind's 0.5x..3x band (8 kinds changed). `size_m` placement ranges untouched, so the drawn sizes on the island are unchanged. |
| `game/tests/t_biomeprops.gd` | New headless acceptance: file / load / MeshInstance3D / vertex-colour albedo / COLOR_0 stored as sRGB / AABB-in-band for all 21 biome model refs across 11 kinds, plus island_props placement of every kind on home, desert and volcanic islands. |
| `game/scripts/dev/biomeprops_lab.gd`, `game/scenes/dev/biomeprops_lab.tscn` | New lab: a row of every kind on the home island from the game camera, PNGs into `--shot-dir`, one `[biomeprops] RESULT ...` line. |
| `job_biomeprops.conf` (job scratch, not repo) | The gate conf the task referenced but that did not exist; TEST/LAB/LAB_ASSERT/RELATED/SCOPE as the task text specifies. |

## Before / after (measured)

Colour, unshaded sample of the same `mesa_sandstone.glb` silhouette:

| | mean RGB | against authored sandstone (0.62, 0.38, 0.27) |
|---|---|---|
| before (linear-stored COLOR_0) | (0.265, 0.094, 0.034) | reads as a dark red-grey slab |
| after (sRGB-stored) | (0.548, 0.354, 0.251) | the authored palette |

Whole-set mean vertex luminance before the fix: basalt/obsidian 0.024-0.048, sandstone 0.146, logs
0.072-0.090, aloe 0.163 — i.e. everything at the dark end of its palette. After: the test's
`lum_min` floor of 0.15 passes on all 21 refs (lab measures 0.225 across kinds).

Size: 12 of 21 model references were outside their kind's `radius_m` band before (cliff_chunk_red
8.3 m on radius 1.2; rock_spire_b 9.05 m on 1.4; aloe 1.6 m on 0.3; reeds 1.86 m on 0.35). After: 21
of 21 in band.

`[biomeprops] RESULT kinds=11 vcol_ok=11 scale_ok=11 placed=8 missing_files=0 lum_min=0.225`
(headless; `placed` is the home-island count, mesa_cliff and basalt_column only have canyon/basalt
ground and appear on desert_35 / volcanic_60, which the test checks).

## Checks run

- `t_biomeprops` PASS (was 29 FAIL on the pre-fix tree). `t_props` PASS, `t_biome` PASS.
- `tools/smoke.sh --no-import` -> `SMOKE PASS`.
- `verify_job.sh biomeprops 1` PASS (created the missing conf to run it).

## Deferred (owner instruction on resume: background only, no visible windows)

- The lab's PNG frames and the human look were **not** taken in this session: headless never fires
  `RenderingServer.frame_post_draw`, and visible Godot windows were off-limits. Run
  `... --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=biomeprops_lab --shot-dir=DIR`
  (and again at 844x390) in a windowed session and look at `biomeprops_row.png`.
- The earlier visual evidence I did collect (`.dsc/IMAGES.md`) was from temporary probe scenes:
  brown vertex-painted spires/mounds on the island, and the sRGB-vs-linear A/B above.

## Assumptions

- The test's size rule is the task's: model AABB height in `0.5 * radius_m .. 3 * radius_m`. Fixing
  the collider radius rather than the art is the smaller change and leaves the owner-approved look
  (and the drawn island sizes) alone.
- `radius_m` doubles as the collider/footprint radius, so raising it widens prop footprint blocking.
  Only the three rock kinds move more than 0.3 m (cliff_rock 1.2->3.0, rock_spire 1.4->3.2); those
  are the big indestructible landforms, where a wider footprint is the correct read.
- No balance numbers (HP, damage, drops, densities) were touched.

## What the integrator needs

- Merge the branch; no scene or gameplay code outside `props.json` and the new test/lab changed.
- `game/data/world/biome_assets.json` was **not** rewritten (`write_manifest.py` would need a full
  rebuild run); its `size_m` rows are unchanged by this work because geometry is unchanged. Its
  `kind` labels still say "mesa"/"basalt_columns"/"cliff" where `props.json` says mesa_cliff /
  basalt_column / cliff_rock — pre-existing drift, out of scope here.
- Schedule the windowed lab look before the next deploy, so a human confirms the palette on the
  phone resolution.
