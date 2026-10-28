# BUILDSPEED — island build back under the §1.7 budget

## What shipped

Island build time is under the islands plan's §1.7 budget on all three budgeted islands, and the
budget gate on it is now switched on. Nothing the build places changed: every tiles / harvest /
scatter / prop digest is byte-identical to the one recorded before the work started.

- `game/tests/t_buildspeed.gd` (new): builds home + the two unstable islands 5× each, digests
  everything the build places (tile types, fresh-water mask, harvest node ids and positions,
  ground-cover / browse / prop scatter transforms, quantised to 1 mm, SHA-256 over a
  `PackedInt64Array`) and compares it with the digests recorded before optimisation (`BEFORE`).
  It also gates build time: the fastest of the 5 runs must be under budget, and no single run may
  exceed budget + `overrun_pct` (35 %).
- `game/scripts/world/perf_trace.gd` (new): phase timer, off unless `BUILD_PROFILE=1` /
  `ISL_TIME=1` or a test turns it on; marks are one bool check in normal play.
- `game/data/perf_budget.json`: `build_ms` gained `overrun_pct: 35` and its own `enforce: true`, and
  the top-level `enforce` note now says exactly what is still not enforced and why.
- `game/tests/t_perfgates.gd`: builds each island 5× and judges the fastest (a loaded box only ever
  adds wall-clock time to a build, it never makes one finish early), printing the worst beside it,
  and gates `build_ms` on its own `enforce` flag so the still-missing heap figure cannot veto it.

## Before / after (same box, same runs, `t_buildspeed` budget figures)

| island | budget | before | after (fastest of 5) | worst of 5 |
|---|---|---|---|---|
| home_grassland | 2500 ms | 4.0-4.5 s | **2306-2349 ms** | 2359-2446 |
| savannah_15 | 3000 ms | 3.8-4.1 s | **2328-2470 ms** | 2450-2550 |
| volcanic_60 | 3000 ms | 2.4-3.0 s | **1840-1985 ms** | 1991-2189 |

`t_perfgates` (own 5 builds per island, same code path): home 2306, savannah 2328, volcanic 1840 ms.
Digests before = after for all three islands.

## Where the time came from (home, warm build, ms)

| phase | before | after |
|---|---|---|
| shape (fill + resettle + margins) | 550-680 | 300-320 |
| tiles.loop | 260 | 175-195 |
| smooth.filter + merge | 360 | 180-190 |
| tiles.image | 18 | 14-15 |
| scatter.cover (plan + group + sort + commit) | 1150-1300 | 455-500 |
| scatter.dress | 500-600 | 210-240 |
| props | 180-270 | 140-200 |
| pathing | 300-400 | 155-170 |
| spawns (first-run lazy caches) | 100-400 | 60-100 |

The individual changes are listed in `.dsc/docs/buildspeed.md`; the ones that mattered:

- **Ground cover sort** — 78k dicts through `sort_custom` with a lambda (0.35-0.41 s) became a
  `PackedInt64Array` of `hash<<32|slot` sorted by the engine, then an in-place permutation (0.02 s).
- **Ground cover plan** — per-kind sprite constants (pw/ph/base_h/scale/tint) hoisted out of the
  per-instance loop (0.72 → 0.33 s); `_ground` refuses on the cheap tests (tile, claim) before the
  height/slope samples and reads height before slope.
- **Dress** — `_near_water` / `_near_sand` read the tile arrays in place instead of 49
  `tile_type_at_world` calls per spot; `spot_ok` derives the tile index once for walk/tile/zone.
- **Tiles** — `BiomeZones.fast_state`/`zone_of_state` turn per-tile dictionary reads into array
  reads; the biome smoothing is a sliding column histogram with zone counts packed 8 bits apiece
  into one int per column; the tile image is one RG8 `PackedByteArray` + `set_data`.
- **Shape** — the calibration loop ran three heightmap fills; the margin settle measures the
  analytic coastline, so its refill was pure waste. Two fills → one final fill.
- **Pathing** — `TilePath._rebuild` drops a `tile_centre` whose `surface_y` was thrown away, fuses
  height+slope only where a weight is actually read (44 % of the region is solid and needs
  neither), and only calls `HarbourSite` for tiles inside the approach rect.

## Decisions worth knowing

- **Time gate on the fastest run, not the worst.** This box runs several agents' Godot jobs at once:
  the same build measured 2.3-2.7 s quiet and 5.4-7.5 s under load. Load only ever *adds* time, so
  the fastest sample is the island's own cost; the worst is still printed and capped at budget +
  35 % so a genuine regression (which moves every sample) still fails.
- **`build_ms` gates on its own flag.** The heap figure is still over budget (+171 / +179 / +157 MB
  against 90) and that miss belongs to another job; the top-level `enforce` stays false so heap
  breaches stay reported instead of failing the run, while `build_ms.enforce` is true.
- `MultiMesh.buffer` bulk writes were tried and rejected: the headless (dummy) renderer returns an
  empty buffer, and a windowed round trip mangles the origin row. Cover instances are written with
  `set_instance_transform` / `_color` / `_custom_data`.

## Verified

- `t_buildspeed` PASS (digests equal to `BEFORE`, all three islands under budget, no run over the
  single-run ceiling).
- `t_perfgates` PASS, `budget source=docs/design/islands-and-loop-plan.md#17-performance-budget
  islands=3 judged=19 breaches=3` (the three heap rows only).
- Related tests PASS: `t_perfgates`, `t_build`, `t_gather`, `t_save`, `t_islandgen`, `t_water`,
  `t_harbour`, `t_ground2d`, `t_biomes`, `t_biomedress`, `t_biome`, `t_props`, `t_props2d`,
  `t_islandpick`; `tools/smoke.sh` -> `SMOKE PASS`.

## What the next agent needs

- The heap budget is the only §1.7 headless miss left: set the top-level `enforce` to true in
  `game/data/perf_budget.json` once the heap is under 90 MB.
- `docs/design/islands-and-loop-plan.md` is protected for this job, so its §1.7 "Today" column still
  shows the old 4.3-4.5 s and the "work needed to hit it" note still lists the three items done
  here. The owner (or whoever owns that file) should refresh it.
