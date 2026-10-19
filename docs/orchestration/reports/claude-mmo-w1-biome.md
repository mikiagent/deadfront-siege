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
  (ash only in volcanic), shader knobs; top-level `water_only_families: ["Lilypad"]`; per-row `special_families` (berry_bush only where BushBerries grows) and `compat_gain`.
- `terrain_tiles.gdshader`: new uniforms `slope_dry_lo/hi`, `slope_rock_lo/hi`, `macro_strength`,
  `macro_scale`. `foliage_sway.gdshader`: `tip_tint`, `root_dark`, `tip_gain`. Defaults equal the old
  hard-coded constants.
- `game/scripts/world/biome_material.gd` (`BiomeMaterial`): `rows/row/climates`, `apply_terrain(m,
  climate)`, `terrain(climate, map_size, tile_map)`, `foliage(climate)`, `noise_texture()`.
- `biome_lab` (script + scene) and `game/tests/t_biome.gd`.
- Texture imports: VRAM Compressed (`compress/mode=2`) with mipmaps. Basis UASTC is near 1 byte
  per texel for detailed noise (4.5-5.1 MB a set with mipmaps, RDO loss 3.0 saved under 3 %), so it cannot
  meet 3 MB. VRAM Compressed is fixed at 0.5 bpp: 2,796,464 bytes a set per platform.

`climate_palette.gd` is unchanged: it still feeds island_runtime's tile colours, and nothing in this
package needed it changed.

## Review round 1 (fixes)

| Finding | Fix | Check that would have caught it |
|---|---|---|
| major: flat cloud textures, one Voronoi rock for all climates | Rewrote `recipes.py`: blade-tip, soil-gap and litter specks plus overlays at 480/160/40/18 per tile on grass; pebbles, grit and three overlays on dirt; shells and grain on sand. Each climate has its own rock: granite boulders (grassland), jointed slate with moss (temperate), red sandstone strata (savannah), mossy boulders (tropical), pitted coral limestone (blue_tropical), frost-shattered blocks (tundra), snow-capped granite (snowfield), cross-bedded sandstone (desert), algae boulders (swamp), columnar basalt (volcanic). Joints fade in and out along their length (`fade`), so they no longer read as paving. | `bake_terrain.py` measures pixel detail (mean of lum minus 3x3 blur, over mean lum) for the Poly Haven layer each set replaces and fails any baked layer under it: `[bake] PASS 10 climates, 0 layers under the Poly Haven detail floor or over their cap`. `t_biome` repeats it on a 128 px crop. With the old temperate ground and volcanic rock put back, it printed `[t_biome] FAIL temperate ground detail 0.0106 under the Poly Haven ground 0.0564` and `[t_biome] FAIL volcanic rock detail 0.0132 under the Poly Haven rock 0.0650`. |
| major: snow, tundra and desert clip in gl_compatibility | Bake caps: snow 0.80 linear peak, desert 0.70, tundra 0.72, light sands 0.72-0.74 (`cap` in recipes; bake log prints `peak_lin`). That was not enough: compat lights the ground about twice as bright as Forward+ (grassland 0.662 vs 0.491 lab mean). So a per-row `compat_gain` (snowfield 0.62, tundra 0.75, desert 0.62) multiplies the ground tints under gl_compatibility only (`BiomeMaterial.compat_gain`). | Compat lab: snowfield mean 0.943 -> (0.645, 0.687, 0.737), desert 0.962 -> (0.694, 0.573, 0.366). Snow ripples and desert ripples are visible in `lab4gl/biome_snowfield.png` and `lab3gl/biome_desert.png`. `t_biome` checks that compat_gain dims compat only. |
| minor: lab never reaches the rock band | `biome_lab.height()` adds a mesa with 2 m walls over 1 m (about 63 degrees). The mound comment now says it reaches only the dry band. | `t_biome`: `[t_biome] lab steepest v_slope 0.55 >= 0.50` (fails if under the largest `slope_rock_hi`). Rock shows on the mesa wall in every lab shot. |
| minor: volcanic and snowfield dirt read as concrete | Volcanic dirt is charred soil with grit and rust patches. Snowfield dirt is dark frozen mud with slush patches. | Seen in `lab4/biome_volcanic.png` and `lab4/biome_snowfield.png` (bottom-left square and top strip). |
| minor: no berry allowlist | `special_families` per row: mud, clay and tree_stump everywhere (today's behaviour), berry_bush only in grassland and temperate (the climates whose vegetation has BushBerries). | `t_biome` fails when `berry_bush` in special_families disagrees with `BushBerries` in the climate's vegetation. |
| minor: palette and knob typos were ignored | `t_biome` checks every palette key as `tint_<key>` and every knob against the shader's uniforms. `get_shader_uniform_list()` is empty headless, so it falls back to the uniform declarations. | With `ash` -> `assh` and `tex_scale` -> `tex_scalee`: `[t_biome] FAIL savannah palette key assh has no tint_assh uniform`, `[t_biome] FAIL savannah shader knob tex_scalee is not a uniform`. |
| minor: stale byte sizes | All sets reimported. The new sizes are below. | n/a |
| minor: failed parse re-read on every call | `BiomeMaterial.rows()` sets `_loaded` before parsing, so a broken file is reported once. `climates()` reads `rows()` once. | Code check. |
| minor: no mipmaps | Mipmaps are on for all 40 layers. | `t_biome` fails any set that imports without mipmaps or is not VRAM compressed. |

Two more fixes from this round:
- `biome_lab.gd` no longer names the `Game` autoload. t_biome loads `BiomeLab` before autoloads exist, and the error was swallowed, so the test printed PASS. The lab now uses `/root/Game/PerfHud`.
- The bake log label `mean_lin` was wrong: byte bake buffers hold sRGB. It now says `mean_srgb`.

### Camp with the hook applied (probe, not committed)

I added `BiomeMaterial.apply_terrain(m, _climate)` to island_runtime `_terrain_material()`, took the
shots and reverted the line with `git checkout`. Island: `[world] island temperate_25 nodes=378 creatures=24`.
Same ground-only crop (x 950-1350, y 120-420, `camp_crop.py`):

| shot | pixel detail | rel | lum std | chroma std |
|---|---|---|---|---|
| current ground, Forward+ (reviewer `camp_before_fwd.png`) | 0.0084 | 0.0285 | 0.0188 | 0.0189 |
| current ground with mipmaps on (probe `camp_oldmip_fwd.png`) | 0.0024 | 0.0081 | 0.0140 | 0.0142 |
| new temperate, hooked, Forward+ (`camp_hook2_fwd.png`) | 0.0056 | 0.0176 | 0.0178 | 0.0175 |
| current ground, compat (reviewer `camp_before_gl.png`) | 0.0062 | 0.0203 | 0.0171 | 0.0210 |
| new temperate, hooked, compat (`camp_hook2_gl.png`) | 0.0087 | 0.0197 | 0.0302 | 0.0237 |

In a still Forward+ frame the hooked ground has less per-pixel detail than today's ground (0.0056 vs
0.0084). The probe row shows why: about two thirds of today's figure is aliasing from the old set's
missing mipmaps. That aliasing is the shimmer this round also fixes. With mipmaps on both sets, the new
set has 2.3x the pixel detail and more luminance and hue variation. In compat it beats today's ground
outright. At 1:1 (`camp_crops3.png`) the new ground shows clumps and leaf litter; today's mipmapped
ground is a smooth wash. Because the still-frame number is lower, the register rows below stay at REVIEW
and KEEP, not done or REPLACE.

## Acceptance checklist

- [x] biomes.json has every climates.json climate and every texture exists:
  `[t_biome] PASS 10 climates` (the test also checks 1024 px width, the ground-cover and palm
  allowlists against vegetation, and the ash allowlist against materials).
- [x] biome_lab windowed (Forward+) writes 10 PNGs with distances >= 0.08:
  `[biome_lab] PASS 10 patches, 0 pairs under 0.08`. Closest pairs:
  `[biome_lab] close temperate/swamp dist=0.095` and `[biome_lab] close grassland/savannah dist=0.135`.
  Means: grassland (0.491, 0.582, 0.303), savannah (0.624, 0.555, 0.307), temperate (0.336, 0.394, 0.164),
  tropical (0.326, 0.555, 0.208), tundra (0.548, 0.544, 0.509), desert (0.812, 0.677, 0.449),
  swamp (0.325, 0.306, 0.197), snowfield (0.757, 0.800, 0.850), blue_tropical (0.330, 0.542, 0.390),
  volcanic (0.191, 0.192, 0.179).
  gl_compatibility run: `[biome_lab] PASS 10 patches, 0 pairs under 0.08` (closest
  `[biome_lab] close temperate/swamp dist=0.139`).
  What the screenshots show: desert is rippled sand. Tundra is frozen grey-brown dirt with snow lying
  in drifts. Volcanic is dark lava plates with ash and scoria, with columnar basalt on the mesa wall.
  Swamp is olive peat with algae and dark mud.
- [x] island_lab camp unchanged: before/after windowed shots differ by `DIFF mean_abs=0.0050%
  mean_shift=[-0. 0. -0.]` (limit 1 %); `[world] island temperate_25 nodes=378 creatures=24
  spawn_rejected=0` both times. Not rerun in the review round: neither shader changed, and the hook is still not applied.
- [x] Each set is 1024 px and <= 3 MB imported per platform. VRAM Compressed with mipmaps is fixed-rate,
  so every set is 2,796,464 bytes of `.s3tc.ctex` plus 2,796,464 bytes of `.etc2.ctex` (all 10 measured).
  If an export ships both desktop and mobile formats, it carries 5.6 MB a set; W1-WEB owns that choice.
  The bake scripts regenerate the sets:
  `[bake] PASS 10 climates, 0 layers under the Poly Haven detail floor or over their cap`.
- [x] `tools/smoke.sh --no-import`: `SMOKE PASS`. `run_all.gd`: `[tests] PASS`. `t_biome.gd`:
  `[t_biome] PASS 10 climates`. Headless biome_lab: `[biome_lab] headless: built 10 materials, no pixels`.
  All were rerun after the last commit of this round.

## Screenshots inspected (scratchpad `w1/biome/`)

First round: `lab/biome_<climate>.png` (desert, swamp, tundra, volcanic, tropical), `tex/sheet.png`,
`island_camp_before.png`, `island_camp_after.png`.
Review round: `tex2/final_A.png` and `tex2/final_B.png` (all 40 layers; each cell shows the full tile
and a 1:1 crop), `tex2/rocks.png`, `lab4/biome_{temperate,tundra,swamp}.png`, `lab2/biome_{volcanic,snowfield}.png`,
`lab2gl/biome_{snowfield,desert}.png` (before compat_gain: clipped), `lab3gl/biome_{snowfield,savannah,desert}.png`,
`lab4gl/biome_tundra.png`, `camp_hook_fwd.png`, `camp_hook_gl.png`, `camp_crops.png`, `camp_crops3.png`.

## Assumptions

- # ASSUMPTION (data, not code): "10 climates" means the 10 keys in climates.json, home grassland
  included (it gets its own lighter meadow set).
- Baked textures are the final albedo, so palette tints default to white. dry, wet, mud, bare and
  ash are multipliers; shallow and deep are absolute colours.
- Ground-cover families are taken from each climate's own vegetation list (grass, flower, herb, reed
  and tuft families); Lilypad is water-only everywhere.
- # ASSUMPTION (data): berry_bush is allowed where the climate's vegetation lists BushBerries.
  mud, clay and tree_stump stay allowed everywhere, which is how island_runtime behaves today.
- # ASSUMPTION (data): compat_gain values (snowfield 0.62, tundra 0.75, desert 0.62) are tuned against
  today's compat environment. If W1-LIGHT changes compat exposure, retune them.
- Snowfield and desert ground are compared with the beach (sand) reference, not the grass one
  (`floor_ref`), because they are snow and dune sand.

## Integrator hooks

- Register t_biome with the suite. In `game/tests/run_all.gd` `_init()`, after `_test_ui_tokens()`:
  `var biome_rc := OS.execute(OS.get_executable_path(), ["--headless", "--audio-driver", "Dummy", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/t_biome.gd"])`
  then `if biome_rc != 0: failures.append("t_biome exit %d" % biome_rc)`. It takes about 20 s, most of it
  the detail check. A separate step in tools/smoke.sh is the alternative.

For W2: For W2-TERRAIN, in island_runtime `_terrain_material()` after the existing
setters: `BiomeMaterial.apply_terrain(m, _climate)`. For W2-SCATTER, use `BiomeMaterial.foliage(_climate)`
in place of the bare FOLIAGE_SHADER material, and read `ground_cover`, `palm_allowlist` and
`water_only_families` from `BiomeMaterial.row(climate)` (the desert palms come from
island_runtime.gd:738, which only excludes tundra and volcanic).

## Labs to register

- `biome_lab` (`game/scripts/dev/biome_lab.gd`, `game/scenes/dev/biome_lab.tscn`). Windowed:
  `--resolution 1600x900 -- --lab=biome_lab --biome-out=<dir>`; it exits 1 if any non-exempt pair
  is under 0.08.

## Asset replacement register (docs/orchestration/mmo/asset-replacement.md, not on this branch)

The register is not on this branch and is not mine to edit. Rows for the orchestrator:

- World and nature / Terrain ground (the 10 baked sets plus BiomeMaterial): `REVIEW`, not done. It
  needs a blind art check, and W2-TERRAIN must hook it in.
- `assets/terrain/{aerial_grass_rock,aerial_beach_01,brown_mud_leaves_01,rocky_trail}_diff_1k.jpg`
  (the shared Poly Haven set, also used by prop_visuals.gd:157): `KEEP` until a matched in-game
  comparison after the W2-TERRAIN hook shows the new sets are no worse. The camp probe above says
  they already are with mipmaps on both sets, but they are not in a still frame without them.
- New row: these Poly Haven imports have mipmaps off, so they shimmer at iso distance (two thirds of
  their still-frame detail is aliasing). Mark them `REVIEW` for whoever owns `game/assets/terrain/*.jpg.import`.

## Not done or left

- Nothing is hooked into islands (by spec: W2-TERRAIN and W2-SCATTER). W2-SCATTER must read
  `special_families` to stop berries on the volcano. The data is here; the gate is not.
- The textures are colour maps only (no normal or roughness maps), so the rock has no lighting relief.
  Tundra snow drifts and volcanic ash still repeat visibly at the 4-7 m tile scale.
- In a still Forward+ frame the hooked camp has less per-pixel detail than today's unmipmapped ground
  (0.0056 vs 0.0084). See the camp table.
- Pebble specks show as small rings at 1:1. They are invisible at camp distance.
- No Meshy or Tripo credits spent.
