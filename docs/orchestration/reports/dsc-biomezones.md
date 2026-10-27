# BIOMEZONES (DeepSeek): biome-painted ground and map colours

Branch `claude/mmo-biomezones`, base `fda69ed5` (`claude/mmo-biomezones` dsc task commit). Task set:
`docs/orchestration/dsc/biomezones-TASK.md`; authoritative plan `docs/design/islands-and-loop-plan.md` §1.4 and §2.

## Merge note (read first)

`git merge claude/mmo-overhaul` and `git merge claude/mmo-w1-biome` **fail in this worktree**: the dsc sandbox
forbids writing `$GIT_DIR/worktrees/mmo-biomezones/*.lock` ("Operation not permitted"), and the same block hits
`git checkout <branch> -- path` and `git apply` of the index. I brought the commits in **by file** instead:

- `docs/design/islands-and-loop-plan.md` from `claude/mmo-overhaul` (ab12e0fb).
- From `claude/mmo-w1-biome`: `game/assets/terrain/**` (10 baked sets + their `.import`), `game/scripts/world/
  biome_material.gd`, `game/data/world/biomes.json`, `game/scripts/dev/biome_lab.gd|.tscn`, `game/tests/t_biome.gd`,
  and the 13-line `terrain_tiles.gdshader` / 7-line `foliage_sway.gdshader` diffs (`git apply`).
  **Not** taken from W1-BIOME: its `climates.json` edit that drops `Corn`, `TinOreNode` and `Wheat` from three
  climates' vegetation/materials (unrelated to biomes; that is a world-placement change for W2).

The integrator should still run both merges for real; nothing here conflicts with either, but the W1-BIOME
`biomes.json` rows are now extended (see below), so a plain merge of that branch over this one must keep the
`zones`, `zone_rules` and per-climate `zones` blocks.

## What shipped

| Area | File | What |
|---|---|---|
| zone table | `game/data/world/biomes.json` | `zones` (8 rows: meadow, forest, savanna, canyon, basalt, wetland, beach, rocky) each with ground `tint`, per-layer `mix` (ground/dirt/sand/rock), minimap `map` colour, `node_mult` (tree/bush/rock/plant) and `prop_mult` (grass/flower) density multipliers. `zone_rules` (thresholds, filter radius, `min_region_tiles`). Per climate: `zones.{base,lush,dry,rock}` (which zone a wet / dry patch becomes) + `zones.weights` (relative land share) + `zones.tints` (per-climate overrides, e.g. tundra and snowfield never wear the golden savanna tint; volcanic basalt overrides cactus-less desert). |
| zone assignment | `game/scripts/world/biome_zones.gd` (new, `class_name BiomeZones`) | `context(rt, climate, camp, seed)`, `zone_of(...)` (beach = low ground within 5 m of the land radius; wetland = within 12 m of the river; the climate's rock zone on slope > 27° or the top 15 % of dry elevation; otherwise a moisture noise through the climate's weights), `smooth(rt)` (src→dst 3x3/5x5 majority filter, then regions under `min_region_tiles` join their biggest neighbour), `biome_at(rt, x, z)`, `density(zone, group)`, `prop_density`, `palette_image(climate)` (8x2), `map_image(rt)`, `shares(rt)`. |
| tile map | `game/scripts/world/island_terrain.gd` | tile image is now **RG8** (R tile type, G zone); `_build_tile_types` paints the zone per tile and smooths; `set_tile_type` (harvest) keeps G; terrain material gets `biome_pal` + `biome_on = 1` and calls `BiomeMaterial.apply_terrain(m, climate)`. |
| painting | `game/scripts/world/terrain_tiles.gdshader` | `biome_pal` (8x2: tint row, layer-mix row), zone read at two noise-displaced points and blended (`biome_edge_m` 5 m, `biome_blend` 0.55) for soft painted edges; the zone tint multiplies the climate's own baked layer, and dark/desaturated zones (basalt, canyon) also flatten toward their own hue at the surface's brightness so a brown baked set cannot keep the basalt brown. |
| palettes | `game/data/world/climates.json` | palettes for the 7 climates that had none (desert, tundra, tropical, swamp, volcanic, snowfield, blue_tropical), plan colours. |
| map | `game/scripts/ui/hunt_hud.gd` | `_ensure_map_texture` now builds `BiomeZones.map_image(rt)`; the atlas (`map_screen.gd`) uses the same `_map_tex`, so it follows. |
| lab | `game/scripts/dev/biome_lab.gd` (+ `biome_patch.gd`, `scenes/dev/biome_lab.tscn`) | per-climate patches + per-island top/camp/map shots into `--shot-dir`, one `[biome] id=<id> zones=<n> share=<zone:pct,...> build_ms=<ms>` line per island (`--islands=` to choose). Static patch helpers live in `BiomePatch` so `t_biome` (a `--script` test) never loads a class that names `World`. |
| tests | `game/tests/t_biomes.gd` (new), `game/tests/t_biome.gd` (W1) | t_biomes: every island ≥ 3 zones, home has meadow/forest/wetland/rocky/beach, every climate has a palette, tile image G == zone array, `biome_at` works. t_biome gained a zone-palette check (≥ 4 distinct tints per climate, shader default `biome_on = 1`). |

Not mine, in `docs/orchestration/reports/dsc-biomezones-hooks.patch`: the one-line
`var biome_types: PackedByteArray` for `island_runtime.gd` (until it lands the array lives in the runtime's
metadata, `BiomeZones.install/biome_types`), the two hard-coded terrain seeds, and the scatter density hook.

## Numbers, before → after

Zone shares of land (biome_lab, `[biome]` lines):

| Island | Before | After |
|---|---|---|
| home_grassland | 1 ground look | 6 zones: meadow 39 %, beach 21 %, forest 17 %, rocky 11 %, wetland 6 %, savanna 6 % |
| savannah_15 | 1 look | 7 zones: savanna 58 %, meadow 14 %, canyon 12 %, wetland 6 %, rocky 4 %, beach 4 %, forest 2 % |
| desert_35 | 1 look | 6 zones: savanna 63 %, canyon 12 %, meadow 10 %, wetland 7 %, rocky 5 %, beach 4 % |
| volcanic_60 | 1 look | 5 zones: basalt 77 %, rocky 12 %, wetland 6 %, beach 4 %, meadow 1 % |

Island build, native gl_compatibility windowed, `build_ms` from the lab:

| Island | build ms | plan budget |
|---|---|---|
| home_grassland | 0.34–1.06 s (5 runs) | ≤ 2.5 s |
| savannah_15 | 2.09–2.83 s | ≤ 3.0 s |
| desert_35 | 2.07–2.82 s | ≤ 3.0 s |
| volcanic_60 | 1.95–2.44 s | ≤ 3.0 s |

The zone pass itself is a small share: the tile loop already computed height and slope per tile, so the added
work is 3 noise samples, the 5x5 filter and the region merge (home 160x160 = 25k tiles, unstable 480x480 =
230k). The unstable spread overlaps the scout's measured 2.9–3.6 s before this change, so the zone pass has not
pushed it over the 3.0 s budget at the low end but is inside the noise of the old numbers.

Texture sets: 10 sets x 4 layers x ~0.7 MB VRAM-compressed per platform = **≈ 2.8 MB a set, ≈ 28 MB for all ten**
(~1.5 MB of source JPEG each, 15.1 MB of JPEG in the repo, 18 MB on disk). The islands use 8 climates
(everything except `snowfield` and `blue_tropical`), so **≈ 5.6 MB per platform is currently unused**; dropping
those two, or shipping 512 px versions, is a WEBPACK decision, not done here.

## Shots I looked at (1600x900, gl_compatibility)

Saved copies in `.dsc/shots/` on the worktree (the originals are in the session scratchpad `/tmp/bz_shots`):

- `home_grassland_top.png`: green island, lighter olive upland patch inland, sand fringe on every coast, camp
  clearing visible as a paler opening. Reads as one landmass with several ground patches, not a ring.
- `savannah_15_top.png`: golden ground, red canyon patches to the east, a green riverbank band following the river,
  grey-red rocky patches.
- `desert_35_top.png`: tan savanna ground with two red canyon patches and grey-red rocky patches; the sand fringe.
- `volcanic_60_top.png`: dark grey basalt over most of the island, a green riverbank strip, grey rocky high ground,
  sand fringe.
- `biome_<climate>.png` x10: the ten patches still separate (closest pair temperate/swamp 0.139); the patch test
  `PASS 10 patches, 0 pairs under 0.08`.
- `<id>_map.png`: home = green/olive/khaki patchwork + sand ring; desert = tan + red canyon + green river + grey rock.

Concept-art comparison (`docs/reference/biome-concept-*`): the red earth and black basalt now read on the ground
by hue, and the golden grass on savannah keeps the baked texture's detail instead of a flat tint. What still
reads "game grey" rather than concept art is the flat rock patch on basalt/desert highs (a large rocky zone is
one flat grey wash at top-down zoom) and every landform (cliffs, mesas, terraces) — that is ISLANDGEN's shape
package, not this one.

## Assumptions (`# ASSUMPTION:` in code)

- `biome_zones.gd` header + `zone_of`: every threshold (beach height 0.85 m and 5 m from the land radius, river
  12 m, slope 27°, top 15 % of dry land, moisture cutoff 0.9/0.5, camp clearing = inner third of 60 m,
  400 m² minimum region, 2-tile majority radius). The plan fixes the rule order but not the numbers; its
  "coast < 14 m" and "river < 12 m" are kept for the river and replaced by a height band for the beach, because a
  14 m coastal ring covered 40–50 % of a 120 m starter island's land when I tried it.
- Per-climate zone weights and tints (`biomes.json` `zones.weights` / `zones.tints`) are mine, from the plan's
  zone-set table and the concept art; the plan names the zones per climate, not their shares.
- Density multipliers `node_mult` / `prop_mult` are mine, from the plan's §1.4 table; nothing consumes them yet
  (that is the scatter/props hook).
- t_biomes' "sand is not blown white" cap of 0.95 is mine (the plan's brightest sand, blue_tropical `#f0e6c8`,
  is 0.94).

## What the integrator needs

1. Apply `docs/orchestration/reports/dsc-biomezones-hooks.patch` (island_runtime `biome_types` field), then change
   `BiomeZones.install()` to assign `rt.biome_types` and `BiomeZones.biome_types()` to return it (two one-liners,
   left so the field and the accessor cannot disagree).
2. `rt._seed` does not exist yet; `IslandTerrain._layout_seed()` seeds the moisture field from `World.island_id`
   today, so two islands of one climate already differ. When ISLANDGEN lands a per-island seed, point
   `_layout_seed` at it.
3. SCATTER: multiply per-instance counts by `BiomeZones.density(zone, group)` / `prop_density(zone, "grass"|"flower")`
   (hook 3 in the patch), so a forest gets its trees and a canyon its rocks.
4. PROPS: the same `biome_at` / `density` pair is the only API needed; big cliffs are ISLANDGEN's.
5. WEBPACK: 28 MB of terrain sets, 5.6 MB of it for two climates no island uses.

## Checks run

- `tools/smoke.sh --no-import` → `SMOKE PASS` (through `gslot.sh`; a bare run in this sandbox cannot write
  `~/Library/.../Godot` and segfaults).
- `[t_biomes] PASS`, `[t_biome] PASS 10 climates`, no `SCRIPT ERROR` in either.
- biome_lab windowed: 22 PNGs, `[biome]` line per island, no `SCRIPT ERROR`.
- Everything was run through `gslot.sh` with a perl alarm and output to a file; `--check-only` before each long run.
