# claude-lookpass: the tutorial town, made to look good with engine settings

Branch `claude/mmo-lookpass` (pushed, not merged), from `origin/claude/mmo-overhaul` 36d1fac8. No new
models and no paid generation. The camera is unchanged (north-up, same lens). SDFGI stays off.

## What changed, in the brief's priority order
1. **Sun**: it now peaks at 42 deg (was 58) and shines from the south-west (yaw -38..-62, was -55..-105), with a warmer colour (1.0, 0.9, 0.76). The south fronts the camera sees were in shade all day before; now they are sunlit, and the east and west roof slopes differ. Shadows fall north-east, beside the buildings.
2. **Sky and ambient**: a bluer, less saturated sky top (0.34, 0.5, 0.74) and a warm horizon (0.82, 0.8, 0.74). Ambient goes 0.30 -> 0.34. Shade still reads cool, a bit less teal than before.
3. **Grade**: AgX was already on. Contrast is 1.06. LIGHTPORT's golden hour is ported: from tod 0.56-0.64 the sun, fog and horizon warm to amber, then night turns them blue. LIGHTPORT's glow strength/bloom/soft-light and its `--tod` pin are not ported.
4. **SSAO + a little SSIL, Forward+ only** (`WorldLighting._screen_space`). Godot fades both out from 50 m to 300 m, but the iso camera stands 186-430 m back, so the first try showed nothing (PSNR 50 dB against SSAO off). `project.godot` now moves the fade to 600-900 m. SSAO is 5 / 2.5 m / light_affect 0.6, which darkens under shelter roofs and eaves. SSIL is 0.5 at quality "very low": at full quality it cost about 1 ms for little visible change. The web and phone renderers (gl_compatibility, mobile) never enable either; t_lighting checks this on both renderers.
5. **Fog**: 0.0026. The camera distance thins it to about 0.0006 at the game zoom, so roads stay clear.
6. **Town ground** (`TownDress._ground_look` + `terrain_tiles.gdshader`): a 1 m mask (RG8, 180x180) over the town. R is wear: it is 1 on streets and door paths and fades out over 3 m from every street, door path and taken cell. G marks inside the wall. The shader mixes two greens in ~12 m patches inside the town, and blends worn ground (between the dirt texture and the road tint) by the mask plus ~2.5 m noise. The default black texture leaves every other island unchanged.
7. **Grass**: about 24 k procedural tufts (5 blades each), 6 % of them flowers in four colours. Density is 9 per m2 on Forward+ and half that on the web/phone renderers. They thin with wear and stay off streets, door paths, cells and the square. One MultiMesh per 32 m chunk per kind, no shadows, `visibility_range_end` = the town's prop range. Normals point up, so tufts shade like the ground. Build time is unchanged (915 vs 977 ms).

The shot tool `townpolish_shots.gd` gained `--tods=name:tod,...` (day/dusk pairs), `--perf` (240-frame timing per shot, RESULT lines) and an `env` line (renderer, ssao, ssil, sdfgi, tonemap, fog).

## Shots (docs/orchestration/reports/lookpass/)
- `before/` and `after/`: the same 11 town spots (farms, pens, homes, market, workshops with a second spot each, harbour). Each spot has the game camera by day (0.42) and at dusk (0.74), plus a wide day shot, at 1600x900 and 844x390. That is 66 shots per side, off-screen at `--position 6000,3000`, self-quitting, `-- --skip-charcreate`.
- `compat_before/` and `compat_after/`: the game-camera shots at 844x390 on `--rendering-method gl_compatibility` (the web/phone look, no SSAO/SSIL).
- Good pairs to compare: `homes_game_day_1600x900` (fronts now lit, ground no longer a mint wash), `market_game_day_1600x900` (grass and worn edges), `harbour_game_day_1600x900`, `workshops2_game_dusk_1600x900` (golden dusk), and `compat_*/market_game_day_844x390`.

I looked at every shot I judged by. I fixed these along the way: AO was invisible (fade distance), the first tufts were sparse and too pale, the first wear band was a dark border (now it leans toward the road colour), and full-quality SSIL cost too much.

## Frame time (Mac, Forward+, 1600x900, vsync off, 22 game-camera day shots, mean of the per-shot means)
| Run | mean ms | median ms | p95 ms | primitives | draws |
|---|---|---|---|---|---|
| before 1 | 4.09 | 3.93 | 6.19 | 558 672 | 117 |
| before 2 | 3.86 | 3.79 | 5.53 | 574 355 | 119 |
| after, SSIL full quality (dropped) | 4.63 / 5.14 | 4.50 / 5.01 | 6.72 / 6.75 | ~633 k | 128-131 |
| after, no SSIL | 3.76 | 3.75 | 4.55 | 626 043 | 129 |
| **after, final (SSIL very low)** | **3.90** | **3.89** | **4.68** | 632 803 | 129 |
| before 3 (machine busy) | 6.56 | 5.91 | 11.52 | 581 945 | 119 |
| final 2 (machine busy, right after before 3) | 7.56 | 7.08 | 12.66 | 649 343 | 130 |

Other agents were running Godot on the same Mac, so the runs are noisy. The final build costs between 0 and 1 ms more per frame than canon on the Mac. It draws about 60-70 k more primitives (the grass) and about 11 more draw calls. GPU time read 0 on Metal (`viewport_get_measured_render_time_gpu`), so these are wall-clock frame times. Raw RESULT lines: `lookpass/perf/` (pb = before, pa = full SSIL, pn = no SSIL, pq = final). Phone and web frame time were not measured: this needs a device or the web soak.

## Gates (this branch)
| Gate | Result |
|---|---|
| t_perfgates | PASS. The OVER lines (savannah_15 185 MB, volcanic_60 161 MB heap) are the same numbers on canon; not this change |
| t_camera | PASS |
| t_weather | PASS |
| t_lighting (Forward+ and gl_compatibility) | PASS: golden-hour test ported, renderer gating checked |
| t_structart (tent faces the sun with the new yaw band) | PASS |
| run_all.gd | `[tests] PASS` |
| tools/smoke.sh --no-import | SMOKE PASS |

## Assumptions
Logged as LP1-LP5 in `docs/vision/WildLandsMMO_Open_Questions.md`: the sun band and elevation, the sky, ambient and fog values, the SSAO/SSIL strengths and fade, the golden-hour port, and the grass density, colours and wear width.

## For the next agent
- LIGHTPORT conflicts only in `world_lighting.gd` drive(), `_f()` and t_lighting's neutral check. Merge this first, then take LIGHTPORT's glow keys and `--tod` pin on top.
- The sun change is global: every island gets the lower south-west sun, except climates with their own elevation.
- Package 9 (camera lens) should re-check the SSAO radius and the SSAO/SSIL fade distances if the camera comes closer.
- The compatibility runs print 16 "Too many instances using shader instance variables" errors, and every run prints one "Parent node is busy" add_child error. Canon prints the same counts.
