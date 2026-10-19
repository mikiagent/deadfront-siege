# W1-BIOME report: per-climate ground

Branch `claude/mmo-w1-biome`. Closes the W1 share of world-biome-01 and world-placement-08 (data
only; the island hook is W2-TERRAIN / W2-SCATTER).

## What shipped

- `tools/blender/terrain/bake_terrain.py` + `recipes.py`: headless Blender (Cycles emission bake,
  4 threads) of 10 seamless 1024 px sets, one per climates.json key, each `ground/dirt/sand/rock.jpg`
  under `game/assets/terrain/<climate>/`. Noise is sampled on a 4D torus, so tiles wrap with no
  seam (the bake prints seam vs interior step per layer; they match). Full rebake: about 50 s.
  `Blender -b -P tools/blender/terrain/bake_terrain.py -- [climate ...] [--size N]`.
- `game/data/world/biomes.json`: per climate texture paths, palette (shader multipliers; shallow and
  deep absolute), foliage tint and tip tint, ground-cover families (subset of the climate's
  vegetation), palm allowlist (PalmTree only in tropical and blue_tropical), special-tile allowlist
  (ash only in volcanic), shader knobs; top-level `water_only_families: ["Lilypad"]`.
- `terrain_tiles.gdshader`: new uniforms `slope_dry_lo/hi`, `slope_rock_lo/hi`, `macro_strength`,
  `macro_scale`. `foliage_sway.gdshader`: `tip_tint`, `root_dark`, `tip_gain`. Defaults equal the old
  hard-coded constants.
- `game/scripts/world/biome_material.gd` (`BiomeMaterial`): `rows/row/climates`, `apply_terrain(m,
  climate)`, `terrain(climate, map_size, tile_map)`, `foliage(climate)`, `noise_texture()`.
- `biome_lab` (script + scene) and `game/tests/t_biome.gd`.
- Texture imports: project default Basis Universal with `rdo_quality_loss=1.0` (sets were up to
  3.15 MB at 0.0).

`climate_palette.gd` is unchanged: it still feeds island_runtime's tile colours, and nothing in this
package needed it changed.

## Acceptance checklist

- [x] biomes.json has every climates.json climate and every texture exists:
  `[t_biome] PASS 10 climates` (the test also checks 1024 px width, the ground-cover and palm
  allowlists against vegetation, and the ash allowlist against materials).
- [x] biome_lab windowed writes 10 PNGs with distances >= 0.08:
  `[biome_lab] PASS 10 patches, 0 pairs under 0.08`. The closest pair is
  `[biome_lab] close grassland/savannah dist=0.150`; tropical/blue_tropical and tundra/snowfield are
  also above 0.15. Means: grassland (0.492, 0.582, 0.345), savannah (0.640, 0.555, 0.345),
  temperate (0.335, 0.479, 0.224), tropical (0.346, 0.632, 0.258), tundra (0.670, 0.675, 0.656),
  desert (0.816, 0.679, 0.450), swamp (0.348, 0.323, 0.214), snowfield (0.884, 0.911, 0.923),
  blue_tropical (0.340, 0.547, 0.439), volcanic (0.222, 0.219, 0.212).
  What the screenshots show: desert is rippled sand, tundra is frozen grey-brown dirt with snow
  patches, volcanic is cracked basalt with ash drifts, swamp is olive peat and mud with algae.
- [x] island_lab camp unchanged: before/after windowed shots differ by `DIFF mean_abs=0.0050%
  mean_shift=[-0. 0. -0.]` (limit 1 %); `[world] island temperate_25 nodes=378 creatures=24
  spawn_rejected=0` both times.
- [x] Each set is 1024 px and <= 3 MB imported (bytes): blue_tropical 1,363,895; desert 1,682,308;
  grassland 1,375,149; savannah 1,547,625; snowfield 1,447,881; swamp 1,132,719; temperate
  1,386,004; tropical 1,441,036; tundra 1,444,825; volcanic 1,000,274. The bake scripts regenerate
  them: `[bake] PASS 10 climates`.
- [x] `tools/smoke.sh --no-import`: `SMOKE PASS`. `run_all.gd`: `[tests] PASS`. Headless
  biome_lab: `[biome_lab] headless: built 10 materials, no pixels`.

## Screenshots inspected (scratchpad `w1/biome/`)

`lab/biome_<climate>.png` (all 10 are written; I looked at desert, swamp (before and after the
tweak), tundra, volcanic and tropical), `tex/sheet.png` (all 40 layers), `island_camp_before.png`,
`island_camp_after.png`.

## Assumptions

- # ASSUMPTION (data, not code): "10 climates" means the 10 keys in climates.json, home grassland
  included (it gets its own lighter meadow set).
- Baked textures are the final albedo, so palette tints default to white. dry, wet, mud, bare and
  ash are multipliers; shallow and deep are absolute colours.
- Ground-cover families are taken from each climate's own vegetation list (grass, flower, herb, reed
  and tuft families); Lilypad is water-only everywhere.

## Integrator hooks

None needed for W1. For W2-TERRAIN, in island_runtime `_terrain_material()` after the existing
setters: `BiomeMaterial.apply_terrain(m, _climate)`. For W2-SCATTER, use `BiomeMaterial.foliage(_climate)`
in place of the bare FOLIAGE_SHADER material, and read `ground_cover`, `palm_allowlist` and
`water_only_families` from `BiomeMaterial.row(climate)` (the desert palms come from
island_runtime.gd:738, which only excludes tundra and volcanic).

## Labs to register

- `biome_lab` (`game/scripts/dev/biome_lab.gd`, `game/scenes/dev/biome_lab.tscn`). Windowed:
  `--resolution 1600x900 -- --lab=biome_lab --biome-out=<dir>`; it exits 1 if any non-exempt pair
  is under 0.08.

## Asset replacement register (docs/orchestration/mmo/asset-replacement.md, not on this branch)

The owner asked that low-quality assets be marked for replacement. The register is not on this
branch and is not mine to edit, so these are the rows for the orchestrator to apply:

- World and nature / Terrain ground: status `REVIEW` (10 baked sets + BiomeMaterial done; shows in
  game once W2-TERRAIN hooks it).
- New row: `assets/terrain/{aerial_grass_rock,aerial_beach_01,brown_mud_leaves_01,rocky_trail}_diff_1k.jpg`
  (shared Poly Haven 1k set, the same meadow on every climate; also used by prop_visuals.gd:157) |
  Superseded by the per-biome sets | W2-TERRAIN | `REPLACE` (delete once nothing references them).

## Not done or left

- Nothing is hooked into islands (by spec: W2-TERRAIN and W2-SCATTER).
- The baked textures are colour maps only (no normal or roughness maps). The rock cracks share one
  voronoi seed across climates. Volcanic ash and tundra snow repeat visibly at the 4-7 m tile scale.
- gl_compatibility pixels were not checked for biome_lab (the spec does not ask for it).
- No Meshy or Tripo credits spent.
