# PERFGATES — measure the plan §1.7 budget and gate every package on it

dsc, 2026-10-28, worktree `mmo-perfgates`. Task: build the measurement, do not optimise.

## What shipped

| File | What it is |
|---|---|
| `game/data/perf_budget.json` | The §1.7 budget as data: island ids, build ceilings, harvest bands, node ceiling, ground-cover mechanism + ceiling, creature cap, heap ceiling, the not-headless list, and an `enforce` flag. |
| `game/tests/t_perfgates.gd` | Headless gate. Builds home + two unstable islands through `World.load_island`, measures per island, judges against the json, prints one line per island plus `OVER` lines and the `not measured headless` line. |
| `game/scripts/dev/perf_lab.gd` | Windowed lab: home camp, survivor beside the tent, 20 s of frames, prints `[perfgates] RESULT draws= prims= shadow_prims= frame_p95_ms= frame_mean_ms=` and saves a PNG. |
| `game/scenes/dev/perf_lab.tscn` | The lab scene (`--lab=perf_lab`). |
| `docs/design/islands-and-loop-plan.md` §1.7 | The "Today" column only, updated with the numbers below. |

Verify: `verify_job.sh perfgates 1` PASS (no SCRIPT ERROR), `2` PASS. Stage 2's windowed run is
currently deferred by the owner's `HEADLESS_ONLY` flag, so **the lab numbers below are from my own
manual runs, not from the gate** — the gate has not approved them.

## The table

"Plan Today" = what §1.7 said before this package. "Measured now" = this package, dev Mac
(15 cores, load average 13–14 from other worktrees; see the caveat under build time).

| Measure | Budget | Plan's "Today" | Measured now |
|---|---|---|---|
| Island build, native | <= 2.5 s home, <= 3.0 s unstable | home 0.8–1.4 s, unstable 2.9–3.6 s | **home 4.3–4.5 s, unstable 2.7–5.4 s** (over) |
| Island build, web | <= 6 s behind the fade | not measured | not measured headless — needs a browser run (`tools/production_soak.mjs` path) |
| HarvestNodes per island | home 450–600, unstable 500–750 | 216 / 210–397 | **600 / 600 / 600** (all three at the top of their band) |
| Scene nodes after build | <= 6,000 | 2,036 / 3,549 | **5,067 home / 5,343 savannah / 5,036 volcanic** (inside, close to the ceiling) |
| Ground-cover instances | MultiMesh in 32 m cells, 120 m range, no shadow | 96 / 185 | **78,090 home / 61,509 savannah / 0 volcanic** — 77 / 55 cells, every cell 32 m, shadow off, range >= 120 m (checked, not assumed) |
| Camp view 1600x900 | prims < 900k, shadow < 3.0M, draws < 450 | home 2.83M total, 315 draws | **draws 324, base prims 80,763, total with shadows 334,988** (inside) |
| Camp view 844x390 | (phone target) | — | draws 299, base prims 78,872, total with shadows 448,105 |
| Frame time, web build | p95 <= 16.7 ms desktop; <= 33 ms at 844x390 with 4x throttle | not measured | not measured headless. Native p95 at the camp: 10.6 ms at 1600x900, 8.3 ms at 844x390 (not the web number) |
| Heap per island | <= +90 MB | +24 / +58 MB | **+171 MB home / +187 MB savannah / +171 MB volcanic** (over) — native `MEMORY_STATIC` delta, a different measure from the plan's web heap |
| Creatures | home 11; unstable cap 24 | 8 / 24 | **8 home / 24 savannah / 6 volcanic** (home short of 11; volatile island has 6 fixed rows and no ring spawns) |

Six verdicts are over budget: two build times per island set and all three heap deltas. Nothing was
optimised, per the task.

## Shots looked at

- `/tmp/perf_shots16/perf_lab_1600x900.png` — the real camp view at 1600x900: survivor beside the
  tent, HUD, minimap, quest card, ground-cover cards textured (no grey cards), no shader errors.
- `/tmp/perf_shots/perf_lab_844x390.png` — phone landscape, same scene, HUD and cover still draw.

Verdict for both: the lab stands where the player actually stands, so the numbers describe play and
not a stub. (They are in `/tmp`, not the repo; the gate will regenerate them into its own `--shot-dir`.)

## How the measures are taken (so the next agent can trust or dispute them)

- `build_ms` is wall-clock around `World.load_island` (which is `IslandRuntime.build` in full: shape,
  terrain, nav, camp, scatter, cover, props, pathing, spawns) with no player present.
- Harvest/creature counts are live group members under the new runtime, and each is cross-checked
  against `IslandRuntime.harvest_count` / `creature_count`; a disagreement fails the test.
- Scene nodes are the runtime subtree's own nodes (not `Performance.OBJECT_NODE_COUNT`, which includes
  the test's host and the autoloads).
- Heap is `Performance.MEMORY_STATIC` after minus before, with one warm-up build thrown away: the
  process's first island pays +213 MB because it also loads meshes/textures/clip caches the next build
  reuses, and the same island built later costs +170 MB. Charging that first-build cost to an island
  would report a cache, not an island.
- Ground cover is measured from `GroundCover`: instances, cell count, each cell's centre on a 32 m grid,
  `cast_shadow == OFF`, `visibility_range_end >= 120 m`. A headless run cannot say how many of those
  instances reach the screen, so this is placement, not draw.

## Assumptions (marked in the files)

- `# ASSUMPTION`: the plan gives ground cover a *mechanism*, not a count, so `max_instances` (80,000) is
  only a runaway-regression ceiling; today's 61k–78k sit under it.
- `enforce: false` in `perf_budget.json`: over-budget measures print `OVER ...` and are counted, but
  they do not fail the run while the plan's known misses are open, because this task measures and does
  not optimise. Measurement faults always fail (a build that does not happen, counters that disagree,
  a cover cell that is not a 32 m shadowless cell, cover on a climate that grows none).
- Volcanic grows no ground cover by data (`data/world/ground_cover.json`: volcanic/desert/tundra list
  no kinds), so `cover=0` there is asserted as correct rather than a miss.
- `shadow_prims` is the frame's total with the shadow pass on, matching the plan's "shadow < 3.0M;
  today 2.83M total" row; `prims` is the base pass with the sun's shadow switched off.

## Caveat on build time (read before optimising anything)

Build time on this machine is 3–4x the plan's "today" range, and it moves with machine load: the same
home build measured 4.53 s, 4.35 s and 4.34 s in three runs, savannah 4.12 s and 5.40 s. The untouched
`islandgen_lab` on the same box during this package reported home 4.04 s, savannah 3.91 s, volcanic
2.46 s. So the absolute number here is load, not a regression this package can attribute. Re-measure on
a quiet machine before anyone acts on it; the gate's relative value (same command, same machine) is
what it is for.

## What the integrator needs

1. Merge order: the four new files are self-contained; §1.7's "Today" column is the only shared-file edit.
2. `enforce` stays `false` until the plan's perf work lands (build time, heap, cover thinning). Flip it
   to `true` in `game/data/perf_budget.json` when it does — the test then fails on any over-budget
   measure without any code change.
3. The web rows (island build in Chrome, web p95 at 1600x900/844x390 with 4x throttle) still have no
   measurement anywhere. `perf_lab` measures native only; a browser run of
   `tools/production_soak.mjs` against a deployed build is the missing half.
4. The heap budget itself deserves a decision: the plan's +24/+58 MB was a web heap figure; the native
   static-memory delta is +171–187 MB per island whatever the plan meant. Someone should say which
   number the budget is about before it is enforced.
5. Every package that touches island build, scatter, cover or camp should run
   `Godot --headless --path game --script res://tests/t_perfgates.gd` and paste its three `table` lines
   in its report — that is the "every package must fit" part of the roadmap item.

## The gate was proved able to fail

With `enforce: true` and a deliberately impossible heap ceiling (1 MB), the same run prints
`FAIL over budget: ...` for five measures and exits 1; the file was restored afterwards. So `enforce`
is a real switch, not decoration, and the breach path is not dead code.
