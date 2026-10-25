# BIOMEPROPS — the biome prop models render correctly again

Owner, 2026-10-22: "props are broken". Filed as "the hyphen model ids never existed, so the props
were never placed". **That part is stale in this tree**: the merge commit `55f60fb3` already
remapped `game/data/world/props.json` to the shipped underscore GLBs, and `island_props` places them
(measured: home_grassland draws rock_spire, termite_mound, aloe, fern, reeds, plume_grass, fallen_log,
driftwood). What was really broken, and is fixed here, is the **size contract** between every model
and its collider, plus test coverage that would have caught it.

## What shipped

| File | Change |
|---|---|
| `game/data/world/props.json` | `radius_m` raised so every biome model's AABB height is inside the kind's 0.5x..3x band (8 kinds). `size_m` placement ranges untouched. |
| `game/tests/t_biomeprops.gd` | New headless acceptance: file / load / MeshInstance3D / vertex-colour albedo / COLOR_0 present / AABB-in-band for all 21 biome model refs across 11 kinds, plus island_props placement of every kind on home, desert and volcanic islands. |
| `game/tests/t_biome.gd` | Replaced with the BIOMEDRESS version (ad8bb5c4) of the same test, which load()s its classes on the first frame instead of naming them at compile time. The old copy printed 5 SCRIPT ERRORs ("Identifier not found: World / Data") before its PASS, so no gate that forbids SCRIPT ERROR could accept it. The new copy is the same test, same assertions, PASS with zero SCRIPT ERRORs. |
| `game/scripts/dev/biomeprops_lab.gd`, `game/scenes/dev/biomeprops_lab.tscn` | Lab: a row of every kind on the home island from the game camera, PNGs into `--shot-dir`, one `[biomeprops] RESULT ...` line. |
| `docs/orchestration/dsc/gates/job_biomeprops.conf` | The gate settings, committed to the branch so the integration gate runs the same checks (TEST/LAB/LAB_ASSERT/RELATED/SCOPE). |
| `tools/blender/biome_props/bp_lib.py` | **Unchanged behaviour** (the `srgb()` linear storage the BIOMEASSETS calibration chose); only a comment records the open colour-space question and points at this report. |

## Size fix (the defect this job closes)

12 of 21 biome model references sat outside their kind's `radius_m` band: cliff_chunk_red 8.3 m tall
on a radius of 1.2 (band 0.6..3.6), rock_spire_b 9.05 on 1.4, aloe 1.6 on 0.3, reeds 1.86 on 0.35,
termite_mound_b 3.44 on 1.1, driftwood 0.86 on 0.25, fern_clump_b 1.33 on 0.3, plume_grass 1.63 on
0.3. A prop the size of a house carried the footprint of a barrel: it read as a giant slab and its
collider was wrong. Radius raised to the smallest value that puts every model of the kind in band:

| kind | radius_m before -> after |
|---|---|
| cliff_rock | 1.2 -> 3.0 |
| rock_spire | 1.4 -> 3.2 |
| termite_mound | 1.1 -> 1.2 |
| driftwood | 0.25 -> 0.35 |
| fern | 0.3 -> 0.5 |
| reeds | 0.35 -> 0.7 |
| plume_grass | 0.3 -> 0.6 |
| aloe | 0.3 -> 0.6 |

`mesa_cliff` (3.2) and `basalt_column` (1.1) already fitted. `size_m` is untouched, so the drawn
sizes on the island are exactly what they were; only the collider footprint and the model/collider
consistency rule changed. Result: 21 of 21 references in band.

## Colour space: NOT changed, NOT decided

An earlier version of this branch stored COLOR_0 as raw sRGB on the theory that Godot's importer
linearises it (`vertex_color_is_srgb = true` on every imported material). That has been reverted.
The evidence is contradictory:

- `reports/dsc-biomeassets.md` ("Colour space: unverified in Godot", lines ~123-131) recorded a
  two-quad calibration in gl_compatibility where Godot displayed the stored value without an sRGB
  conversion, and raw-sRGB-stored assets then washed out pale in engine (sandstone peach, granite
  near-white). The scripts therefore store linear, which looked right.
- The importer does report `vertex_color_is_srgb = true`, which reads like the opposite.

Both readings are single measurements under different tonemapping (the calibration used linear
tonemapping and a constant ambient, not the game's AGX + sky ambient). A headless test cannot settle
it: a check on the stored numbers only encodes whichever convention the exporter happens to use,
which is why the test asserts nothing about colour space and the lab no longer prints a luminance
key. **No colour-space change is shipped on this branch.** The props keep the BIOMEASSETS
calibration until someone looks at them in the real lighting and picks a side; if raw sRGB turns out
to be right, it is one line in `bp_lib.paint()` (`v[layer] = srgb(fn(...))` → store the raw triple),
a headless rebuild (`Blender --background --factory-startup -P build_all.py`) and a reimport.

## Checks run

- `t_biomeprops` PASS; `t_biome` PASS (10 climates, zero SCRIPT ERROR); `t_props` PASS; `t_biomes`
  PASS; `tools/smoke.sh --no-import` -> `SMOKE PASS`.
- `verify_job.sh biomeprops` (full, no stage argument): **VERIFY PASS**, with
  `VERIFY HEADLESS-ONLY: visual lab deferred by owner` in place of the windowed lab pass.
- Lab, headless (numbers measured from the live scene):
  `[biomeprops] RESULT kinds=11 vcol_ok=11 scale_ok=11 placed=8 missing_files=0`.
  `placed` is the home-island count; mesa_cliff and basalt_column have no canyon/basalt ground
  there and are checked on desert_35 / volcanic_60 by the test.

## Deferred (owner: background only, no visible windows)

- The lab's PNG frames and the human colour verdict. Headless never fires
  `RenderingServer.frame_post_draw`, and visible Godot windows were off-limits. To finish it:
  `... --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=biomeprops_lab
  --shot-dir=DIR` and again at 844x390, then judge `biomeprops_row.png` against the palette. That is
  also the run that should decide the colour-space question above.
- The gate treats the missing visual pass as deferred, not as approval.

## Assumptions

- The size rule is the task's: model AABB height in `0.5 * radius_m .. 3 * radius_m`. Fixing the
  declared radius rather than the art is the smaller change and leaves the owner-approved look (and
  the drawn island sizes) alone.
- `radius_m` doubles as the collider/footprint radius, so raising it widens prop blocking. Only
  cliff_rock (1.2 -> 3.0) and rock_spire (1.4 -> 3.2) move far; both are the big indestructible
  landforms, where a wider footprint is the correct read.
- No balance numbers (HP, damage, drops, densities) were touched.

## What the integrator needs

- Merge the branch. Product changes are `props.json`, the new test + lab, and `t_biome.gd` taken from
  BIOMEDRESS (ad8bb5c4) so its SCRIPT ERRORs stop poisoning every gate that runs it.
- `game/data/world/biome_assets.json` was not rewritten (its `size_m` rows are unchanged because no
  geometry changed). Its `kind` labels still say "mesa"/"basalt_columns"/"cliff" where `props.json`
  says mesa_cliff / basalt_column / cliff_rock — pre-existing drift, out of scope here.
- Schedule the windowed lab look (and the colour decision) before the next deploy.
