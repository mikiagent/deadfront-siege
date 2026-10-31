# WAVES: animated sea, shore swash, weather sea state (claude/mmo-waves)

Owner: "I want wave effects on the water too, that would be awesome". Mid-task bug from the owner: "water see-through glitch when on the beach". Both are on this branch. Nothing is pushed or merged; the owner reviews first.

## What shipped

- **Sea** (`game/scripts/world/water.gdshader`)
  - A rolling swell of summed Gerstner waves along one prevailing wind. The 30 m and 17 m waves move the sea mesh. The 9 m wave, and the 5.5 m wave on high quality, only shade it, per pixel, so the 8-16 m sea quads never facet.
  - Crests are lighter and troughs darker, so the swell reads from the high game camera. Noise ripples, plus a fine glint layer on high quality, catch the sun.
  - Two breaker foam lines run in from 0.55 m of depth to the waterline, half of a 7 s cycle apart. Their timing is jittered along the coast so the beach never breaks as one ring.
  - Whitecaps show on the crests from about half way to a full storm, and the sea turns greyer.
  - Surf only runs on sea-facing coasts. A surf mask built from river distance and the coast radius (`SeaWaves.surf_mask`) keeps it out of the river, its banks and inland water.
- **Shore** (`game/scripts/world/shore_wash.gdshader`, built by `SeaWaves.build_shore_skin`)
  - A skin is laid 4 cm over the drawn ground's own beach triangles, using the same grid and diagonal. When the runtime has the TERRAINSMOOTH refined surface (`_surf`), the skin uses that.
  - Each breaker runs up the sand as a foam lip over a thin sheet of water, then drains back and leaves bubbles.
  - Each breaker also leaves a wet darkening line at that cycle's high mark. The line fades until the next breaker, so it advances and recedes with the run-up.
  - The skin costs one draw call, 1,252 vertices on home (2,671 on the refined surface), and about 10 ms at build (19 ms on the refined surface).
- **Weather** (`game/scripts/world/sea_waves.gd`, a `SeaWaves` node under the island runtime)
  - Sea state = rain_amount x 0.5, plus 0.5 in a storm, so clear is 0, rain about 0.35 and a storm 1.
  - It eases over about 6 s. Weather is read by property name (`rain_amount`, `storm`, `raining`), so a runtime without weather stays calm.
  - Clear to storm:
    - swell 0.08 to 0.40 m
    - chop 0.25 to 1.0
    - foam 0.55 to 1.0
    - run-up 0.07 to 0.20 m of height above the sea
    - the wind swings up to 0.5 rad
  - Uniforms are set only when the state moves by more than 0.003.
- **Quality**: `--water-quality=low|high`. Low is the default on web and phones (`OS.has_feature("mobile"/"web")`). It uses 16 m quads instead of 8 m, three shading waves instead of four, and no glint layer. Both quality levels run on Forward+ and gl_compatibility.
- **Gameplay**: unchanged.
  - The logical sea stays at -0.05 (`HarbourSite.WATER_Y`), and nothing in gameplay reads the shader.
  - Near the shore the swell can only rise, never dip, out to about 5 m of depth. A sea quad spans 8-16 m, and a dipping offshore vertex had dragged the drawn waterline down the beach.
- **Lab**: `scenes/dev/waves_lab.tscn` takes:
  - `--view=shore|edge|sea` and `--weather=`;
  - `--shot-dir=` and `--frames=N` (frames for an mp4);
  - `--perf`, which times waves vs the old shader vs a hidden sea;
  - `--bare --old-shader=PATH`, which shows the pre-waves sea for a before/after pair.

## The see-through bug

- **Repro (canon shader, same spot)**: `waves/beach_canon_before_1600x900.png`. Open water had a 0.95 alpha floor, so the seabed showed through it as hard-edged lighter patches. The deep plane z-fighting the seabed made it worse (TERRAINSMOOTH fixes that separately). From the beach these patches show in the water beside you.
- **Fix**: water now fades from 62 % at the waterline to solid at 1.6 m (`mix(0.62, 1.0, smoothstep(0.0, 1.6, depth))`). The shallows still show the bed; open water never does. `waves/beach_waves_after_1600x900.png` shows the same spot after the fix.
- **Regression check**: `t_waves` starts `tests/t_waves_render.gd` in a 160x120 window on each renderer. It reads the red that a block 0.15 m under the sea adds to the pixel straight below the camera.

  | | deep water | shallow water |
  |---|---|---|
  | the old alpha | 0.141 | |
  | now, Forward+ | 0.000 | 0.294 |
  | now, gl_compatibility | 0.000 | 0.239 |

  The thresholds are deep < 0.02 and shallow > 0.1. I confirmed the check fails on the old alpha.
- **Terrain merge**: I trial-merged `claude/mmo-terrain` into this branch in a throwaway worktree.
  - It merges cleanly (`island_terrain.gd` and `world-biomes.md` auto-merge).
  - On the merge, `t_waves` and `t_terrainsmooth` PASS, and so does the render probe (deep 0.000 on both renderers).
  - `waves/beach_storm_with_terrain_merge_1600x900.png` shows the result.
  - Its finer height texture does not affect the fix. The opacity is depth-based, and the surf mask samples its own grid (`textureSize`). The skin follows `_surf` when it exists.

## Frame cost

perf_lab camp view at 1600x900, 20 s, compared with canon at e844e349:

| | draws | prims | frame mean / p95 ms |
|---|---|---|---|
| Forward+ canon | 357 | 80,663 | 8.34 / 9.43 |
| Forward+ waves (high) | 349 | 132,969 | 8.33 / 9.44 |
| gl_compatibility canon | 356 | 80,663 | 10.15 / 12.10 |
| gl_compatibility waves (high) | 350 | 132,969 | 9.37 / 10.89 |
| gl_compatibility waves (low) | 351 | 91,303 | 9.84 / 12.48 |

- The extra primitives are the subdivided sea plane: home's 1,331 m plane at 8 m quads is +52k triangles, or +11k on low. That is well inside the plan's 900k budget.
- Frame time does not change measurably.
- waves_lab `--perf` (shore, storm, vsync off) puts waves vs the old shader vs a hidden sea within run-to-run noise on both renderers. For example, Forward+ high pass 2 is 4.744 / 4.727 / 4.651 ms. The full table is in the lab log.
- The engine returned 0 for GPU time on this Mac, so all figures are wall-clock. The difference is below what this machine can resolve.
- `t_perfgates`, run alone, mine vs canon:
  - scene nodes +2 (SeaWaves and ShoreWash);
  - heap +1.5-1.9 MB;
  - build_ms +67-247 ms, which is within run-to-run noise: the skin and mask take about 10 ms.
  - The OVER lines (build time, heap) are the plan's known misses and exist on canon too. Gate PASS.

## Gates

- `t_waves` PASS. It checks:
  - the shaders compile on both renderers;
  - storm swell is at least 3x clear, and storm is choppier, foamier and runs further up the beach;
  - with no weather, the sea is calm;
  - the logical sea, the plane height and the shader's water_y stay at -0.05, and wading depth and swimming are identical in clear and storm;
  - the shore skin runs along the sea coast (1,190 of its 1,252 vertices are surf; the test asks for over a third) and has no surf in the river;
  - no node growth over 90 frames;
  - the shore build takes under 250 ms;
  - the see-through probe.
- `t_perfgates` PASS, `t_web` PASS, `t_colors` PASS, `t_dismount` PASS (12 species), `t_water` PASS, `t_webshader` PASS.
- `run_all` prints `[tests] PASS`.
- `bash tools/smoke.sh --no-import` prints SMOKE PASS.

## Review media (`docs/orchestration/reports/waves/`)

- `waves_shore_clear_1600x900.png`, `waves_shore_storm_1600x900.png`: the beach at the game camera.
- `waves_sea_clear_1600x900.png`, `waves_sea_storm_1600x900.png`: swimming 30 m out. The storm swell bands and whitecaps are visible.
- `waves_shore_storm_1600x900_compat.png`: gl_compatibility at low quality, the web/phone path.
- `beach_canon_before_1600x900.png`, `beach_waves_after_1600x900.png`: the see-through bug, before and after.
- `beach_storm_with_terrain_merge_1600x900.png`: the trial merge with TERRAINSMOOTH.
- `waves_storm_shore.mp4` (0.26 MB, 10 s at 10 fps, 800x450): storm swash and breakers at the waterline.

## Assumptions and risks

- **Wind**: `# ASSUMPTION` no wind model exists. There is one prevailing direction (0.94, 0.34), and it swings up to 0.5 rad with the sea state.
- **Sea state**: there is no "rain mode" property on WorldWeather, only rain_amount, storm and raining. Rain reads as a third of the way to a storm.
- **Swash size**: the run-up is in metres of height, so on steep coasts the swash is narrow and on flat beaches it is wide. On cliffs the skin's triangles cover the face but draw nothing above the run-up.
- **Merge conflict**: `island_terrain.gd` `_sea` changes by 3 lines here. TERRAINSMOOTH edits nearby lines (deep plane and height_res); they auto-merged in the trial.
- **Not covered by tests**: the low-quality path is only seen in the compat shot. No phone or real web build was run.
- **Not mine**: the pale square near the beach in the shore shots, and the dark crack lines on compat sand, are canon terrain look. The TERRAINSMOOTH branch owns them.
