# claude-tutperf: tutorial island lag (2026-10-29)

Branch `claude/mmo-tutperf` from `origin/claude/mmo-overhaul`. Owner report: "performance issues, lag" on a
fresh game on the tutorial island (880 m town island).

## How it was measured

`game/scripts/dev/tutperf_probe.gd` (`-- --tutperf-probe --new-game`, hooked in `main.gd` like the other
probes) finishes character creation, times the island build, then samples frames for 10 s standing in town,
20 s sprinting out toward the raptor ring (nav_to 260 m at 260°, waking wild zones on the way) and 10 s in
the wild. It prints FPS min/avg, frame mean/p95/worst, process/physics monitors, draws, primitives, node
count, the census of nodes ticking every frame (by script) and every frame over 25 ms, with which part of
the frame (process callbacks, physics callbacks, render submit) held it. `--tutperf-ablate` pauses one
subsystem at a time in town.

Windowed runs: 1600x900, `--position 6000,3000 --disable-vsync`. The display cap was sometimes still on
(145 fps flat), so mean frame time is not comparable between runs; hitches (worst, fps_min, spike count)
and counts are. Load: 5 Godot processes on the box (all 5 gslot slots busy) for every run, before and after.
After Milan's "work headlessly" rule the closing numbers were taken headless (frame time there is the
script/physics cost only; draws/prims are 0 headless). Windowed frame-rate numbers after the last change
still need one windowed run.

Temporary per-script timing (every `_process`, `_physics_process`, `_draw` wrapped, plus spawn and tile-path
timers) was used to find the offenders and removed before commit.

## Top offenders found

1. **Fog-of-war texture rebuilt on every reveal (the lag).** `MapFog.texture()` repainted the whole 440x440
   fog bitmap pixel by pixel in GDScript (~55 ms) whenever its version moved, and the 4 Hz walk reveal
   moves it every step. Walking anywhere new = a 55-60 ms hitch every 0.25 s (~40 hitches per 20 s walk).
   Not visible in any `_process`: it ran in the minimap's `draw` signal. Grows with island size: 4.7x the
   home island's pixels.
2. **Creature spawn on zone wake: 50-65 ms per first-of-species, 8-10 ms per further creature.** The
   model and clip GLBs were read from disk on the main thread, and every rig instantiated each clip's whole
   scene (mesh + skeleton) just to copy one Animation.
3. **Tile-path replan to a far goal: 7-12 ms every 1.5 s** while walking to a point 180-260 m away
   (AStarGrid2D over the full distance, then cut to 96 tiles). Not fixed (see below).
4. **Every-frame tickers:** 1,322 nodes ticking in town, 608 of them HarvestNodes running an empty
   `_process` (0.1 ms/frame desktop) and 637 CardProps (0.14 ms/frame). HUD `_draw` ~1.0-1.4 ms/frame plus
   the minimap 0.25 ms and the day/night dial up to 0.4 ms (the HUD redraws every frame unconditionally).
5. **Island build 5.6-5.9 s** (budget for the home island is 2.5 s; no tutorial budget existed). Largest
   phases: tiles.loop 898, smoothing 850, pathing.loop 833, props 469, cover.plan 452, shape.fill 373,
   dress.plan 342 ms. Not touched: islandshapes/tuttown agents are changing those builders right now.

Checked and not an issue on this island: far creatures (ZoneSpawners already spawn only within 110 m and
remove past 170 m; 0 creatures at build, 15 in the wild), ground-cover thinning (<3 ms every 0.2 s),
particles (7 in town, 22 in the wild), lights (4), draws 296-336 and primitives 386-440k (inside the plan's
450 / 900k camp-view budget).

## Fixes (perf only)

| Change | File |
|---|---|
| Fog texture keeps its Image; a reveal records a dirty rect, only that patch (+1 cell ring) is repainted and `ImageTexture.update` re-uploads. Full repaint only on setup/land change. | `scripts/ui/map_fog.gd` |
| Clip source Animation cached per GLB path; each rig still gets its own deep copy (remap unchanged), no more instantiate+free of the clip scene per creature. | `scripts/core/rigged_model.gd` |
| Each ZoneSpawner asks the loader for its species' model and clips on worker threads at build (once per species). | `scripts/world/zone_spawner.gd` |
| HarvestNode ticks only while a pool is regrowing (on at gather/restore, off when empty). | `scripts/world/harvest_node.gd` |

## Before / after

Windowed 1600x900, 5 Godot processes on the box both times.

| Phase | Measure | Before | After |
|---|---|---|---|
| walk (20 s) | frames > 25 ms | 40+ (every 0.25 s, 55-60 ms) | 2 (39 ms first compy spawn, 31 ms render) |
| walk | fps_min / frame worst | 8.6-11 / 91-116 ms | 19-24 / 42-52 ms |
| walk | frame p95 | 8.1-12.4 ms | 5.6-7.9 ms |
| walk | creature spawn, first of species | 50-65 ms | 10-39 ms |
| walk | creature spawn, each further one | 8-10 ms | 3.6-5 ms |
| town | nodes ticking every frame | 1,322 | 716 (HarvestNodes 608 -> 0) |
| town | fps avg / p95 (uncapped runs) | 254 / 4.7 ms | 257 / 4.7 ms (unchanged: town was never the problem on desktop) |
| all | draws / prims / scene nodes | 296-336 / 386-440k / 6.2-6.6k | same |
| build | tutorial island build | 5.6-5.9 s | 4.9-5.9 s (not targeted; noise) |

Headless after (same load): walk 0 frames over 25 ms, worst 21 ms; process 2.7 ms town / 7.3 walk / 3.4 wild;
ticking 716 town / 773 wild.

## Regression gate

`t_perfgates` builds `tutorial_isle` once more and gates counts from `data/perf_budget.json` "tutorial"
(enforced): nodes ticking under the island <= 900 (660 now, ~1,270 before), full harvest nodes ticking = 0,
creatures standing at build = 0, scene nodes <= 9,000 (5,619), and the island has wild zones. Build time is
printed and judged against 7.5 s but not enforced (one build on a shared box). `t_mapui` checks the patched
fog texture equals a full repaint after a walk.

## Not done / for the next agent

- Tile-path replan cost to far goals (7-12 ms every 1.5 s on desktop; ~3-4x on a phone). Options: replan
  only near the prefix end or when blocked, or cap the A* search to the 96-tile prefix.
- HUD redraws every frame (`hunt_hud.gd` ends `_process` with `queue_redraw()` on itself and the minimap);
  ~1.3-1.7 ms/frame desktop. Redraw-on-change needs the levelbadge/HUD owners.
- CardProps (637) still tick to face the camera; 0.14 ms/frame. A single camera-change driver would remove it.
- Tutorial build 5-6 s: needs the island builders (shape fill, tiles loop, smoothing, pathing loop) after the
  islandshapes work lands. Nav bake also warns it parses RenderingServer meshes (blocking readback).
- A windowed after-run for frame-rate numbers on the final commit (Milan asked for headless only for now).

## Checks

t_perfgates (with the tutorial case) PASS, t_tutorial PASS (own HOME), t_islandgen PASS, t_mapui PASS,
run_all `[tests] PASS`, smoke `SMOKE PASS`, all_tests 139: 138 pass + t_mapui (failed once on a headless
texture readback in the new check, fixed to compare the fog's own image, rerun alone PASS) = fail 0.
