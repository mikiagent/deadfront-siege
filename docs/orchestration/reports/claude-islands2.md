# ISLANDS2 — country-shaped, longer, bigger islands (claude, branch claude/mmo-islands2)

Owner request (2026-10-27): islands too square/circular; more islands that look like Japan, Croatia;
long islands with country-like borders; bigger; the starter island not too large.

## Approach

- **New coast generator (IslandShape generator 2)**, next to the old one. A radial r(phi) cannot make a
  long, folded coast, so generator 2 builds a land *field* in the island's own frame: a curved spine
  (bow + wiggle) with a noisy width profile and blunt-to-pointed ends, capes (tapered capsules), bays and
  narrow fjord inlets (capsule cuts), a domain warp, a 4-5 octave fractal edge, and for archipelagos a
  band of long islets parallel to one flank (stretched noise, 18 m+ off the coast so a sound stays open).
  It is sampled on the 161x161 heightmap grid, holes are filled, specks drowned, the largest component
  is the **mainland**, and an exact signed distance (sub-cell seeds + two-pass vector propagation) gives
  metric coast distance. `rad()` keeps its meaning (shore0 minus metres inland), so every consumer
  (beach profile, harbour, tile map, scatter) works unchanged.
- **Three types** in data (`data/islands/<id>.json` `"shape"`: type, size_m, long_m, short_m): `spine`
  (Japan-like), `archipelago` (Croatia-like: islets + inlets on one flank), `compact` (short but ragged).
  The box is calibrated along the mainland's principal axes (81-pt grid, then up to 3 full-res refits).
- **Features on the built land**: a medial axis; the landing beach near one end (coast facing a grid
  axis, dry 19 m clearing) with the **camp 26 m behind it**; the plateau (cliff terraces) at the far
  end; mesa (dropped if the river would cut it); crater moved onto the land (its guard rows move with it).
- **Rivers fixed** (gen 2): spring inside the plateau with a narrow valley cut (the hill stays around
  it), 4.4 m wide spring (resolved on the grid), no camp-disc zeroing (the channel is held 12 m outside
  the clearing instead), channel runs through the beach to the sea, polyline resampled at 3 m.
- **Islets** are scenery: land, but never dry/walkable (no scatter, spawns, building, TilePath).
- **Harbour**: generator-2 islands search the beach around the shape's landing first (rays from the
  open sea hit outer headlands on folded coasts); the old ray search remains the fallback.
- **Perf work** (keeps the bigger squares inside budget): open-sea tiles take a fast path in the tile
  loop (same output), the tile image is written as one RG8 byte buffer (same output), generator-2 ground
  cover samples the dry box instead of an origin disc.
- **Home**: generator 2 too for new worlds, compact, 350 x 290 m in the same 416 m square (today's
  375 x 300 box cannot fit a ragged coast with 20 m of sea a side), legacy camp (0,8) and core kept dry,
  a south cove 56 m below the camp; the five ISLANDPICK shapes are five seeds (Coastal = archipelago
  type via `shape_type` in island_shapes.json); the pick screen previews generator 2.
- **5 new islands** (existing climates/tiers and species only): `savannah_15b`, `temperate_20b`,
  `tundra_40`, `swamp_45`, `swamp_60`. 20 islands total, 19 voyages.

## Before / after per island (paired runs, same machine, gen1 = SG_GEN=1)

Land = main landmass along its principal axes (home: its east-west box). Areas are land tiles above
the water plane. New islands' gen-1 column is just the old generator on that id (no real "before").
Build ms = mean of two alternated runs each (machine shared with other agents; noisy).

| island | type | gen1 land (m) | gen2 land (m) | gen1 aspect | gen2 aspect | gen1 area m2 | gen2 area m2 | solidity 1->2 | islets | square 1->2 | build ms 1->2 | ratio | scene nodes 1->2 | mem after build MB 1->2 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| home_grassland@meadow | compact | 352x304 | 355x291 | 0.86 | 0.82 | 63350 | 51663 | 0.86->0.73 | 1 | 416->416 | 5898->3478 | 0.59 | 5058->5023 | 315->313 |
| home_grassland@forest | compact | 354x303 | 351x288 | 0.86 | 0.82 | 61464 | 48804 | 0.83->0.62 | 0 | 416->416 | 4642->3102 | 0.67 | 5063->5019 | 318->313 |
| home_grassland@rocky | compact | 355x302 | 353x293 | 0.85 | 0.83 | 63772 | 68474 | 0.86->0.86 | 0 | 416->416 | 5182->4193 | 0.81 | 5060->5097 | 317->317 |
| home_grassland@riverside | compact | 353x304 | 352x292 | 0.86 | 0.83 | 65548 | 44579 | 0.83->0.65 | 1 | 416->416 | 5116->3156 | 0.62 | 5086->4994 | 326->307 |
| home_grassland@coastal | archipelago | 358x303 | 353x293 | 0.85 | 0.83 | 76006 | 61358 | 0.86->0.75 | 4 | 416->416 | 5281->3820 | 0.72 | 5124->5105 | 318->326 |
| desert_35 | spine | 448x324 | 599x295 | 0.72 | 0.49 | 69056 | 81382 | 0.81->0.66 | 3 | 416->672 | 5116->5674 | 1.11 | 8397->8268 | 353->364 |
| desert_50 | archipelago | 415x377 | 602x316 | 0.91 | 0.53 | 78768 | 90491 | 0.81->0.67 | 8 | 464->672 | 5188->5374 | 1.04 | 8263->8206 | 345->367 |
| savannah_15 | compact | 325x269 | 429x271 | 0.83 | 0.63 | 45922 | 59250 | 0.88->0.69 | 3 | 368->544 | 5608->4658 | 0.83 | 5283->5390 | 342->351 |
| savannah_15b | spine | 350x218 | 539x227 | 0.62 | 0.42 | 54416 | 57146 | 0.87->0.67 | 2 | 416->608 | 5593->4675 | 0.84 | 5254->5275 | 346->342 |
| savannah_45 | compact | 428x269 | 517x339 | 0.63 | 0.66 | 65083 | 75890 | 0.87->0.61 | 0 | 416->640 | 6911->5428 | 0.79 | 5160->5245 | 344->353 |
| swamp_45 | spine | 391x331 | 605x269 | 0.85 | 0.44 | 66431 | 70299 | 0.85->0.63 | 3 | 416->672 | 5098->4547 | 0.89 | 6025->5272 | 340->352 |
| swamp_55 | compact | 402x337 | 551x354 | 0.84 | 0.64 | 70007 | 96032 | 0.83->0.67 | 3 | 464->672 | 5803->5359 | 0.92 | 5762->5362 | 351->357 |
| swamp_60 | archipelago | 358x308 | 620x335 | 0.86 | 0.54 | 63934 | 89428 | 0.83->0.64 | 12 | 416->704 | 5705->5303 | 0.93 | 6099->5343 | 358->358 |
| temperate_20 | spine | 313x230 | 528x234 | 0.74 | 0.44 | 47698 | 68328 | 0.88->0.70 | 2 | 368->608 | 4737->4757 | 1.00 | 7131->6358 | 370->373 |
| temperate_20b | compact | 335x273 | 472x299 | 0.81 | 0.63 | 50987 | 65202 | 0.81->0.61 | 2 | 416->576 | 4864->4432 | 0.91 | 7258->7176 | 368->376 |
| temperate_25 | archipelago | 321x276 | 478x258 | 0.86 | 0.54 | 43344 | 54174 | 0.84->0.61 | 10 | 368->560 | 4512->4070 | 0.90 | 7165->6237 | 373->379 |
| temperate_35 | archipelago | 403x285 | 579x316 | 0.71 | 0.55 | 67381 | 83292 | 0.89->0.65 | 11 | 416->672 | 6516->5606 | 0.86 | 7123->6500 | 372->384 |
| temperate_45 | spine | 345x300 | 580x262 | 0.87 | 0.45 | 59338 | 74985 | 0.88->0.66 | 5 | 416->656 | 5365->4821 | 0.90 | 7055->6380 | 370->377 |
| tropical_25 | spine | 281x241 | 500x212 | 0.86 | 0.42 | 45341 | 62810 | 0.87->0.74 | 5 | 368->576 | 4672->4161 | 0.89 | 5295->5385 | 352->381 |
| tropical_40 | spine | 375x278 | 597x260 | 0.74 | 0.43 | 64432 | 71797 | 0.86->0.69 | 1 | 416->672 | 5071->4729 | 0.93 | 5195->5165 | 356->363 |
| tundra_30 | compact | 355x302 | 509x334 | 0.85 | 0.66 | 57000 | 65881 | 0.85->0.61 | 1 | 416->608 | 4188->3881 | 0.93 | 5033->5080 | 360->366 |
| tundra_40 | archipelago | 359x306 | 577x300 | 0.85 | 0.52 | 60272 | 87946 | 0.86->0.67 | 6 | 416->656 | 3995->4103 | 1.03 | 5047->5105 | 352->369 |
| tundra_55 | spine | 402x271 | 644x269 | 0.67 | 0.42 | 78699 | 103176 | 0.89->0.77 | 4 | 464->720 | 5295->5107 | 0.96 | 5090->5108 | 362->374 |
| volcanic_60 | compact | 410x325 | 560x361 | 0.79 | 0.65 | 76408 | 101653 | 0.86->0.62 | 4 | 464->672 | 3676->3601 | 0.98 | 5024->5061 | 355->378 |
| TOTAL | | | | | | | | | | | 124036->108039 | 0.871 | | |

Spines aspect 0.42-0.49, archipelagos 0.52-0.55, compacts 0.63-0.66 (was 0.62-0.91). Solidity
0.61-0.77 (was 0.81-0.89). Long axes +34 % to +80 %; mainland area +5 % to +55 % on the existing 14.
Home: same box (a bit under), area 45-68k m2 (was 61-76k): the ragged coast eats some of it.

**Perf vs plan 1.7**: total build time 0.87x of before (no island above 1.11x); scene nodes equal or
fewer; static memory after build +0-29 MB. Web load was not measured (headless only); the native
paired runs are the proxy. The unstable build is still above the plan's 3.0 s target on this
(loaded) machine, as it was before.

## Silhouettes (top-down, from the built tile map)

- Before: `/var/folders/xw/c1xrp24n76nbnlq85qnmbfrw0000gn/T//isl/before/*.png`, montage `/var/folders/xw/c1xrp24n76nbnlq85qnmbfrw0000gn/T//isl/montage_before.png`
- After: `/var/folders/xw/c1xrp24n76nbnlq85qnmbfrw0000gn/T//isl/after/*.png`, montage `/var/folders/xw/c1xrp24n76nbnlq85qnmbfrw0000gn/T//isl/montage_after.png`
(yellow = camp, red = dock arrival, brown = river, black = cliffs, olive = islets.)
Regenerate: `SG_PNG_DIR=<dir> [SG_GEN=1]` with t_shapegates.

## Saves decision

Generator 2 moves land, so **saves are versioned, not migrated**: `home.shape_gen` and
`away.shape_gen` are stamped on every save. A save **without** the stamp is a generator-1 save: its
home and the island it stands on rebuild on generator 1 (and keep their gen-1 size and harbour hint,
`harbour_gen1`), so every saved building and claim keeps its ground. A new voyage (World.travel) and a
new world (World.start_new) use generator 2. A world that never ran start_new (tests, labs) keeps the
gen-1 home by default. SaveSanitizer types the stamp; loader clamps it to 1..current.
Consequence: **existing players keep their old-shape home forever** and only see new coasts on new
voyages (owner question below). Test: `t_shapesave` with fixture `tests/fixtures/save_islands_gen1.json`
(the v3 away golden + 3 baskets on temperate_25 and 2 on the home, each on its own claim, on cells that
are dry on gen 1 and **sea on gen 2**, which the test asserts as a control): loads on gen 1, all
baskets rebuilt on dry land, nothing refunded, re-save stamps 1/1, reload stays gen 1, home on gen 1
too, a new voyage builds gen 2, a gen-2 save round-trips as gen 2, forged stamps clamp.

## Gates (final runs)

- import: clean (0 ERROR)
- `[t_shapegates] PASS` (extended: perf, PNGs, islets never dry, river incl. head on hill and no-river
  = fail on gen 2, size along principal axes, aspect/solidity/growth/islets, >=2 of each type, >=18 voyages)
- `[t_shapesave] PASS away=3 home=2 buildings on generator-1 land`
- `[t_islandgen] PASS islands=20 (16 shape-only)`
- `[t_harbour] PASS islands=20`; `[t_save] PASS` (5 deliberate SCRIPT ERRORs, as on base)
- `[t_water] PASS`, `[t_build] PASS`, `[t_domain] PASS`, `[t_mapui] PASS`, `[t_islandpick] PASS`,
  `[t_biome] PASS 10 climates`, `[t_biomes] PASS`; t_biomedress, t_biomeprops, t_ground2d, t_props,
  t_claims2, t_buildsys rc 0
- every other t_*.gd rc 0 except t_mounts (fails on base: coelophysis saddle)
- `SMOKE PASS` (tools/smoke.sh --no-import); `[tests] PASS` (run_all; 3 TouchControls compile-order
  errors as on base)

Test changes, stated plainly: t_shapegates' WIP river gate measured the channel centre as the "hill"
(impossible: one water plane) - now the ground around the spring; the size gate's target is each
island's shape block. t_islandgen: targets/square from the shape block, non-home aspect gate is now
<= 0.70 along principal axes (owner asked for long islands; old gate was 0.70-0.92), headland count only
on the home, fixed spawns/crater read where the build put them; 5 new islands added to its shape list.

## Docs

`docs/current/world-biomes.md` regenerated (`tools/docs_wiki/gen_game_data.py`, now merging
world/islands.json rows and listing each island's generator-2 coast). `game/data_sheets/islands.csv`
differed only by the 5 new rows; it was regenerated with `--force-sheets` (all other sheets identical).

## Assumptions

- New islands' spawns reuse species already on that climate's islands (swamp_60 far shore: dilophosaurus;
  brachiosaurus left out - an ambient titan). Ids with `b` suffix for second islands of a tier.
- Islets are unreachable scenery (no boats/wading to them).
- Home on generator 2 shrinks to 350 x 290 m box (fits the 416 m square with sea on all sides).
- "Bigger" = long axis >= 1.25x the old tier box and mainland area >= 1.10x the measured gen-1 area.

## Owner questions

1. Old saves keep the old (round) home and the island they stand on. Migrate them instead (would drown
   or refund buildings standing where the new coast is sea)? Today: kept, nothing lost.
2. Home is ~10-30 % less land than before (ragged coast, same box). OK, or grow its square past 416 m?
3. Should islets become reachable (sand bars / boats) or stay scenery?
4. Shapes are seeded noise; float differences between native and web builds could in principle change a
   coast at a threshold (same risk as before). Worth a web check of one island.
