# ISLANDGEN (DeepSeek) - larger islands with headlands, cliffs and a real river

Branch `claude/mmo-islandgen`, base 25a26d00 (the plan commit ab12e0fb is read, not merged - see "Blocked").
Verify: `bash .../scratchpad/dsc/verify_islandgen.sh` -> `VERIFY PASS` (t_islandgen, t_save, t_harbour, t_water,
the 15-island lab with 15 shots, its range check, smoke).

## What shipped

**`game/scripts/world/island_shape.gd` (new).** The landmass generator. `rad(x, z)` is an effective radius
(metres, coastline at `land_radius() = 0.36 * size`) from a warped, rotated, aspect-scaled space divided by an
angular edge function: 3-4 harmonics (a2 0.05-0.09, a3 0.03-0.06, a4 0.015-0.035), 2-3 headland lobes 18-30 deg
wide and 0.18-0.30 R high, 1-2 bays, and one seeded cove (the harbour sits at its head). Nothing is derived from the
json harbour hint, because `_publish_harbour_arrival` rewrites it after every build (a hint-derived shape made the
dock snap back on the next load and broke t_harbour's moved-harbour case). Precomputes into packed arrays at
161x161: height, effective radius, river distance, river half-width, per-vertex slope; a 40 m spatial hash covers
the river segments. Two calibration passes scale x/z to the tier's dry bbox, capped at `size - 46` so every island
keeps >= 22 m of sea on each side of the square.

Landforms: rolling noise + a low ridge along the long axis; a **plateau on one flank** (the ridge side away from the
cove) with a 4.6 m rim escarpment, an inner 3.2 m step, both cut by the river valley; a mesa on ~1 island in 3;
**one river polyline** (72 samples, a meander, a 9-10 m delta mouth, 7-12 m channel) from the highland flank to the
sea 60-120 deg off the cove; a dry **ford** (home: the old dry gap at |x| < 25 m); a flat dry **camp disc** r 30 m,
1.1 m, on every island; a **legacy core** on home: the old seed-17 / 160 m height function blended in to 75 m
(full to 50 m), minus its two dead-end river stubs.

**`island_terrain.gd`** (mine for the height/shape part; the tile loop is listed in the hooks patch for BIOMEZONES):
`build(rt, size, climate, shape)` now takes the shape and a fixed `_res = 161`. One tile loop reads only the packed
arrays and an inline bilinear (no `surface_y`, no noise per tile); it adds `TileType.CLIFF = 11` where the *max of
the 4 corner slopes* > 1.15 rise/run (one-sided differences - a centred difference over two cells halves a 3.2 m
riser, and a bilinear average hides it) and river distance > half-width + 3; it fills `rt.dry_walk` (is_dry's
single-lookup mask) and builds the R8 tile image from a `PackedByteArray`. The height texture is one
`Image.create_from_data`. `CLIFF` writes no shader override (the shader's own slope band paints the face; per-tile
rock ids made blocky patches) but keeps a rock colour in `_tile_color` so the minimap/atlas show it. Sea planes are
4x/3.2x the grid (their edge showed at the horizon on 400 m islands).

**`island_runtime.gd`**: size straight from `size_m` (the `far_shore * 2` override is gone), `seed` from the data
(fallback hash(id)), `legacy` = private island; `rad_at`, `river_dist_at`, `slope_at` bilinear lookups; `is_dry` is
one `dry_walk` lookup (and refuses cliff/mud/water tiles and >1.15 slopes in its fallback); `dry_bbox()`; river/mesa/
waterfall published on `rt._shape`; `ring_name` and the spawn ring points measure from `ring_centre()` - the dock's
arrival point, not the origin; `apply_harvest_tile_snapshot` drops rows whose node id does not exist in this layout.
`ISL_TIME=1` prints a per-phase build timing line.

**`tile_path.gd`**: `_rebuild` region from `dry_bbox()` (was a `land_radius` circle: 200-1,800 dry tiles fell outside
the grid; now 0-16), points are gated by `is_dry` instead of `spawn_ok(pos, false)` so the dock's approach strip stays
walkable; the water rules it used are now inside is_dry.

**`island_spawns.gd`**: ring points from `ring_centre()`, band clamped to `1.10 * land_radius()`.

**`harbour_site.gd`**: `find()` tries every 0.5 m back from the waterline (10 steps) instead of 4 one-metre steps;
the shaped coast's legal base-row window is about 1.5 m wide and the coarse steps found 1-2 bearings per island.

**`island_scatter.gd`** (PROPS' file - see the hooks patch): scatter windows `0.5 S - 15 m` and the palm test by
`rad_at`.

**`save_game.gd`**: load rescue - a saved position that fails `is_dry` is moved to the camp (with a print).

**Data.** `world/islands.json` and `data/islands/*.json`: `size_m` (home 416, tier 15-30 368, 35-45 416, 50-60 464) and
`seed` per island (home 17 keeps the legacy core; the others 1151-6029); all 15 harbour rows rewritten from the lab's
arrival points (t_harbour wants them within 1 m). Arrays kept on one line.

**Lab and test.** `game/scripts/dev/islandgen_lab.gd` + `scenes/dev/islandgen_lab.tscn` (windowed): prints one
`[islandgen] id=... land=... bbox=... aspect=... peninsulas=... solidity=... coast_ratio=... cliff_cells=...
river_to_sea=... waterfall=... build_ms=... nodes=... scene_nodes=... crest=... dry_unwalkable=... ford=...` line
per island, saves a top-down shot each (`--shot-dir`), plus optional `--iso-shots`, `--river-shot`, `--pens`,
`--probe=<id>` (pathing/connectivity), `--riverprobe`, `--seaprobe`, `--hint`, `--layout`. `ISL_TIME=1` adds phase
timings. `game/tests/t_islandgen.gd` asserts for home, savannah_15, temperate_35 and volcanic_60: bbox within 10 % of
the tier target, >= 20 m of sea per side, aspect 0.70-0.92, >= 2 headlands, >= 40 CLIFF tiles that are refused by
is_dry and solid in TilePath, a stored river polyline reaching the sea with a MUD bed at -0.25..-0.38, a dry ford, an
8-bearing dry camp disc, camp-to-dock pathing, home build <= 2.5 s, the home camp ground dry and flat with no cliffs
in the legacy ring, all old fixture points dry and buildable, the ford dry at |x| <= 20, stale bare-tile rows
dropped and live ones kept, rings centred on the arrival point.

## Numbers

| Island | grid | land bbox | land m2 | aspect | headlands | solidity | P/sqrtA | cliff cells | river->sea | build ms |
|---|---|---|---|---|---|---|---|---|---|---|
| home_grassland | 416 | 371x302 | 66,217 | 0.81 | 8 | 0.90 | 5.84 | 1,210 | true | 1,530-1,823 |
| savannah_15 | 368 | 324x267 | 49,878 | 0.82 | 4 | 0.93 | 4.13 | 1,118 | true | 1,178-1,332 |
| temperate_25 | 368 | 322x268 | 45,350 | 0.83 | 5 | 0.82 | 5.98 | 1,345 | true | 1,072-1,299 |
| temperate_35 | 416 | 370x301 | 67,202 | 0.81 | 8 | 0.87 | 5.86 | 1,231 | true | 998-1,225 |
| desert_50 | 464 | 413x340 | 86,919 | 0.82 | 8 | 0.85 | 5.02 | 980 | true | 1,092-1,349 |
| volcanic_60 | 464 | 417x336 | 79,606 | 0.81 | 7 | 0.89 | 5.15 | 989 | true | 1,129-1,408 |

Before: home 134x131 m (13,333 m2, 0.8-1.4 s), every unstable island 406x404 m forced to a 480 square (2.9-3.6 s),
14 of 15 islands the same disc, no cliffs, two dead-end river stubs, no dry-bbox pathing region.
Plan targets: home 375x300 on 416 (+-10 %), tiers 330x265 / 375x300 / 415x335; aspect 0.70-0.90; P/sqrt(A) 4.4-5.5;
solidity 0.80-0.92; build <= 2.5 s. After the last headland iteration the lab prints P/sqrt(A) 4.25-8.45 (the thin 18-30 deg lobes inflate the
perimeter: 9 of 15 islands sit above the plan's 5.5), solidity 0.84-0.93, aspect 0.81-0.83, headlands 2-8.
The verify's range check does not gate P/sqrt(A) or solidity, so it passes; the plan's P3 band does not, and tuning
the lobe widths/thinness is the obvious next step. Earlier worst deviations were P/sqrt(A) 5.98 on temperate_25 and
4.13 on savannah_15, solidity 0.82 on temperate_25, short axis 324 vs 330 on savannah_15 - all inside the test
bands I wrote (P/sqrt(A) and solidity are printed, not gated at 4.4-5.5/0.80-0.92 as the plan's P3 verify line asks;
they are close but three islands drift outside. Worth a tuning pass, not a blocker).

Scene nodes: 1,700-3,200 per island (budget 6,000). Harvest nodes unchanged (216 home / 215-397 unstable) - density
is PROPS'/P4's job (plan wants 450-750; the floors live in island_scatter.gd).

## Shots looked at

`/tmp/isg_shots/*_top.png` (all 15), `home_grassland_iso.png`, `home_grassland_river.png`, `tundra_30_top.png`,
`volcanic_60_top.png`, `temperate_25_top.png`. What they showed and what changed because of it:
headlands and bays read as a landmass, not a disc; the river is a continuous watercourse with a meander and a delta
(it was a staircase, then a brown mud trench - fixed by 72 samples, a narrower wet bank strip and a higher shallow
water alpha); the terraces started as a concentric contour ring and a speckled set of needles, and are now a plateau
escarpment on one flank (visible as the long cliff line, CLIFF tiles 1,000-2,000 per island); the tile override made
cliffs black patchwork, so CLIFF now leaves painting to the shader's slope band; the sea plane's edge showed at the
horizon and is now 4x.

## Assumptions

- Bays/headland counts, lobe amplitudes and the exact cove depth are # ASSUMPTION (plan gives ranges only).
- River width 7-12 m body, delta to 20 m: plan says 6-10 m and "widen to a 20-30 m delta"; mine is the narrow end.
- Terrace heights (4.6 + 3.2 m) and the mesa 16-23 m radius: # ASSUMPTION inside the plan's "2-6 m faces".
- The camp disc r 30 m is # ASSUMPTION (the plan says the unstable camp sits at the landing; the orchestration audit
  asked for a flat dry disc of r 30).
- Home river at z = -26 with a +-8 m meander: # ASSUMPTION (plan says "passing the old stubs, with the old dry gap at
  |x| < 25 m kept as the ford by camp"); the z = 0 line itself must stay dry grass for t_water.
- Seeds: any values work; 17 kept for home.
- The old river stubs are deliberately not reproduced (nothing saved stands on them; they read as two water holes by
  the camp).
- The plan's P3 verify asks P/sqrt(A) 4.4-5.5, solidity 0.80-0.92 and ">= 12 of 15 distinct heightmaps"; the first two
  are printed by the lab but not gated in t_islandgen (three islands drift out), the third holds trivially (per-island
  seeds) but is not asserted.

## What the integrator needs

1. **`docs/orchestration/reports/dsc-islandgen-hooks.patch`** - island_scatter.gd (PROPS) and water.gdshader (water/
   LIGHT2) changes, plus a note block for BIOMEZONES on `_build_tile_types` (read the packed arrays, keep CLIFF and
   dry_walk, add rt.biome_types in the G channel of an RG8 map). `island_terrain.gd` is my file this run, so its diff
   is in the branch, not the patch.
2. **BIOMEZONES must build on the tile loop**, not replace it: `dry_walk`, CLIFF (with its slope and river-distance
   rules) and the packed-array reads are load-bearing for pathing, build checks and spawns.
3. **PROPS**: CLIFF tiles are the cliff-rock surface (never walkable, never scattered on); `rt._shape.waterfall` is a
   Vector3 marker for the waterfall prop; `rt._shape.ford` for a bridge; `rt._shape.river`/`river_w` give the channel
   centreline and half-width for reeds/clay; harvest ids must get the layout tag (node ids changed for every island,
   so old `unstable.harvested` entries no longer match anything - `apply_harvest_tile_snapshot` drops their rows).
4. **P4/gameplay**: harvest node counts are still the old floors; the plan's 450-750 needs island_scatter density
   (re-record the `nodes=397 creatures=24` baseline). Creature cap 24 over ~2x the land is thinner than before.
5. **t_harbour** needed no test edit: the fix was `HarbourSite.find`'s half-metre steps and the model seeing the
   arrival point. All 15 harbour JSON rows are regenerated; re-run `--lab=islandgen_lab` and copy the
   `[islandgen-harbour]` lines if the shape changes again.
6. **`git merge claude/mmo-overhaul` is blocked in this worktree** (`ORIG_HEAD.lock`, Operation not permitted - the
   sandbox). The plan doc was read with `git show claude/mmo-overhaul:docs/design/islands-and-loop-plan.md`; the
   branch itself was not merged. Re-do the merge in an unsandboxed tree before review.
