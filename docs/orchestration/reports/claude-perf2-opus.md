# claude-perf2-opus: island build, town cards, far-goal replans (2026-10-30)

Branch `claude/mmo-perf2-opus`, stacked on `claude/mmo-unstable-opus` (6fff0c2c, itself on integration
4a685bc4). Picks up the three items `claude-tutperf.md` left open.

## How it was measured

Headless on the cloud box, `BUILD_PROFILE=1` (PerfTrace stage marks), `World.load_island` three times per island
in one process. **This box is about 2.3x slower than Milan's Mac:** home builds in ~6 s here vs 2.5-3.0 s there,
and the run-to-run noise is ±10 %. Read the ratios, not the absolute numbers. Equality checks were run as
throwaway probes, not committed:
- a SHA-256 over every TilePath tile's solid flag and weight, home and savannah_15, before and after;
- `t_buildspeed`'s island digests.

## Changes

| Item | Change | File |
|---|---|---|
| Build: pathing grid | One `fill_solid_region` instead of a per-tile solid call. Water tiles read and write one byte, with no Vector3, no engine call and no Vector2i dictionary insert; `_terrain_blocked` became a byte mask. A dry tile reads only the slope its weight needs (it used to also sample the unused height), through a local copy of `surface_y` that does the same float steps in one call. Weight 1.0 tiles skip the engine call. | `scripts/world/tile_path.gd` |
| Build: prop biome sampling | `_sample_biomes` reads the zone and tile byte arrays directly and names each zone id once (biome_of depends on the id alone). Before, every 2 m sample (~190k on the tutorial) made two helper calls, a dynamic call and a string mapping. New stage marks `props.biomes`, `props.kinds`, `props.outcrops`. | `scripts/world/island_props.gd` |
| Town cards (637 ticking) | CardProp no longer has `_process`. A single `CardDriver` node (made with the first card, under the root) reads the active camera once per frame. It re-aligns every live card only when the camera basis changed, plus cards that entered since. A fixed iso camera now costs one basis compare per frame for the whole island. | `scripts/world/card_prop.gd` |
| Far-goal replans (7-12 ms / 1.5 s) | TilePath keeps the last route of 64+ tiles with its goal and a grid version. A replan to the same goal on an unchanged grid joins the walker to the nearest route tile within 12 tiles with a short A* and reuses the tail; the tail of an optimal route is still optimal. The grid version bumps on rebuild and on any refresh that moves a blocker. Owner paths, which open walls, are never cached. | `scripts/world/tile_path.gd` |

## Before / after (cloud box, ms)

| Stage | home before | home after | tutorial before | tutorial after |
|---|---|---|---|---|
| pathing.loop | 303-341 | 209-259 | 1579-1830 | 1119-1348 (one 2021 outlier under load) |
| props biome sampling | 113 | 12-22 | 529 | 57-65 |
| whole build (3 runs) | 5930-7126 (avg 6394) | 5739-6310 (avg 5990) | 11281-12154 (avg 11821) | 10433-11720 (avg 10915) |

That is about 6 % off home and 8 % off the tutorial on this box. On the Mac, home's 2.5-3.0 s should come down
by about 0.15-0.2 s, which reaches the 2.5 s budget only at the low end. **The home budget is not met with
margin**; see "Not done".

| Runtime | Before | After |
|---|---|---|
| CardProp `_process` calls per frame (tutorial town) | 637 | 0 (1 CardDriver) |
| Replan to a goal ~180 m away on home (`t_pathcache`) | 2.24 ms (fresh A*) | 0.44 ms (cached join) |

The tutorial's 180-260 m goals were 7-12 ms on the desktop. The cached join stays bounded by the 12-tile join
search plus the tail copy, whatever the distance.

## Kept identical

- `t_buildspeed` digests: home, savannah_15 and volcanic_60 are unchanged; the gate run checks them.
- The TilePath grid (solid flags and weights) is bit-identical on home and savannah_15 (probe hash above).

## Tests

- New `t_pathcache`. It covers:
  - a miss, then a hit from down the route;
  - the reused route still reaches the goal, and its prefix ends within 8 m of where a fresh one ends;
  - a grid change, another goal and a short route each re-run A*;
  - the cached replan is cheaper than a fresh one.
- `t_card2d` adds two checks: a card does not tick, and the driver turns a card with the camera.

## Not done / for the next agent

- Home is still over budget with little margin. The remaining large home stages (cloud ms) are:
  - cover.plan ~850: 78k Dictionary items, one per clump;
  - shape.fill ~500;
  - dress.plan ~450;
  - tiles.loop ~450;
  - cover.group ~380;
  - smooth.filter + merge ~330.

  These were already tuned by earlier passes. The next real cut is structural: cover/dress plans as packed
  arrays instead of a Dictionary per clump, and the tile loop's per-tile helper calls. Every one of them feeds
  the digest, so each needs the same before/after digest proof.
- The tutorial's tiles.loop (~1.8 s) and smoothing (~1.7 s) dominate its build and scale with its 880 m size.
- The HUD redraw-on-change item from the old report belongs to the hudredraw package and was not touched.
