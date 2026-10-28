# Report: TERRAINSMOOTH (smoother ground, blended zone colours), Claude

Branch `claude/mmo-terrain` in worktree `.claude/worktrees/mmo-terrain`. Nothing is pushed or merged.
Owner's request: "make it so terrain is less choppy and colors blend at terrain color borders". This
is the roadmap's `ground-painting` item (islands-and-loop-plan §2 row 1).

The branch was rebased onto current canon. My first commit sat on `a9c8824c` (Merge SADDLES), and
that commit is no longer in `claude/mmo-overhaul`. Without the rebase, merging this branch would have
brought SADDLES back. Only my own unpushed commits were rewritten.

## What shipped
- **Refined render surface.** `IslandTerrain._refine` refines the 161² data grid 2x to 321², so cells
  are about 1.3 m instead of 2.6 m. Grid nodes keep their heights. Each new midpoint uses the cubic
  (-1, 9, 9, -1)/16 rule, clamped between its two neighbours, so curves stay smooth and cliffs and the
  shore never overshoot. The result is stored as `IslandRuntime._surf` / `_surf_res`.
- **One surface everywhere.** These all read `_surf`:
  - the mesh: 8x8 indexed `ArrayMesh` chunks with central-difference normals over the whole grid, so
    there are no seams at chunk edges and no flat facets;
  - the collision `HeightMapShape3D`;
  - the water shader's height texture;
  - `surface_y`, which follows the mesh's own triangles, so it matches the drawn ground exactly.
  The data grid `_heights` still drives the tile map, zones, the walk and fresh-water masks, TilePath,
  spawns and the nav bake. Those are unchanged by construction.
- **Faster mesh build.** SurfaceTool is gone, along with tangents and UVs (the shader uses neither).
  All chunks share one index buffer. Vertex colours are only computed near the camp and the crater.
- **Zone colours blend.** Before, each pixel looked up the nearest zone at 7 points in a disc. Now
  two mipmapped zone textures (tint and layer mix, one texel per 2 m) are read at the LOD of
  `biome_edge_m`, at two points warped by low-frequency noise (18 m and 9 m wavelengths). The two
  reads are averaged. This also costs fewer texture reads per pixel on mobile.
- **No tile stair steps.** Rock, ash, river mud and crater dirt come from a mipmapped mask texture
  (`_soft_tex`), read blurred and noise-warped. Harvested BARE tiles change in play, so they use a
  bilinear 4-texel mask over the 1 m tile map. The old two-sample nearest lookup is gone.
- **Macro variation** at 41 m, 15 m (`macro_scale`, default 12 changed to 15) and 6.5 m
  wavelengths. The old `p / macro_scale` lookup was really a 0.5 m grain, because the noise texture
  holds about 23 cycles per tile.
- **Palettes:** all 10 climates already had palettes in `climates.json`/`biomes.json` (W1-BIOME had
  landed), so nothing was added.
- **New lab and test:** `game/scripts/dev/terrain_lab.gd` + `scenes/dev/terrain_lab.tscn` (review
  shots, `--island=`, `--spots=`), and `game/tests/t_terrainsmooth.gd`.
- Docs: `docs/current/world-biomes.md` has a new section, "Ground: smooth terrain, blended zone colours".

## Measured
t_terrainsmooth:

| check | home_grassland | savannah_15 |
|---|---|---|
| step_max over 0.5 m (land, away from cliffs; bound 0.6) | 0.52 m | 0.47 m |
| facet crease mean/p99 (deg), old → new | 1.78/22.9 → 1.07/14.6 | 2.00/24.1 → 1.23/15.5 |
| surface_y vs drawn mesh (bound 0.01 m) | 0.00000 m | 0.00000 m |
| build-slope verdicts that match the old surface (bound 98.5 %) | 99.76 % (16 of 6636 cells flip) | 99.35 % (31 of 4776) |
| zone border (windowed run only) | 10-90 % width 9.0 m; largest 0.5 m step = 8 % of the change | |

Build time (`t_perfgates`, `ISL_TIME=1`, before and after interleaved on a loaded machine):

| island | before build_ms (2 runs) | after build_ms (2 runs) | terrain phase before → after |
|---|---|---|---|
| home | 4129, 3898 | 3956, 3795 | 828/773 → 799/741 ms |
| savannah_15 | 4702, 4152 | 4223, 4076 | 676/638 → 593/571 ms |
| volcanic_60 | 3324, 3385 | 2729, 2816 | 1161/1003 → 926/965 ms |

Memory (heap_mb): home 171.3 → 172.2, savannah 186.6 → 187.4, volcanic 170.9 → 172.4. The extra
1-1.5 MB is the refined height array, the mask and zone textures, and the bigger collision map.
scene_nodes went down by about 50 per island, because chunks that are all sea no longer get a nav
source node.

Gates (headless): t_terrainsmooth, t_perfgates, t_build, t_gather, t_claimprops, t_dismount, t_web,
t_colors, t_biome, t_water, t_harbour, t_islandgen, t_biomes, t_props, t_save, t_stepover, t_mounts,
t_buildsys, t_ground2d and t_props2d all PASS. run_all prints `[tests] PASS`.
`bash tools/smoke.sh --no-import` prints SMOKE PASS. t_islandgen's 6 s home-build check failed once
(8.9 s) while three Godot runs shared the machine. It passed alone.

## Shots (`docs/orchestration/reports/terrain/`, left = before, right = after)
These are captured at 1600x900 with the game camera at default zoom. Each half is scaled to 640x360
and the pair is palette-quantised to stay under 300 KB.
- `camp.png`, `zone_border.png` (forest/meadow), `river_bank.png`, `beach.png`, `cliff.png`
- `top.png`: top-down home island, with fog off for this shot only
- `compat_top.png`, `compat_river_bank.png`: gl_compatibility
- `volcanic_top.png`: ash and rock patches, blocky before and soft after

## Hand-off notes and risks
- **BUILDSPEED (`claude/mmo-buildspeed`) will conflict.**
  - Its `IslandTerrain.height_and_slope` reads `_heights` bilinear and claims to be "exactly
    surface_y". After this branch it should read `_surf` with the triangle rule.
  - Its t_buildspeed hashes will change: node y values follow the refined surface.
  - t_buildspeed is not in canon yet, so there was no fixture to update.
  - The terrain loops it touches (`_build_tile_types`, `_write_tile_image`) only gained a few lines
    here. Expect a small textual merge.
- About 0.4-0.7 % of build cells flip their slope verdict, because the corner heights now come from
  the curved surface. These are borderline cells at the 0.6 m spread limit.
- The zone colour profile can only be measured in a window. Headless runs print a note instead.
- I did not check whether the old shader would have failed the zone-blend check.
- `# ASSUMPTION:` none added. The 18 m / 9 m warp wavelengths and the mask thresholds are look
  choices, tuned on the shots.
- Not done: per-zone macro uniforms (the plan's "as per-zone uniforms"). Macro is per climate, through
  the existing `macro_strength`.
- Not changed, and visible in shots: the CLIFF risers themselves (4.6 m over one data cell, by
  design), and z-fighting between seabed terrain at -2.6 m and the deep-sea plane at the same height
  (blocky dark-blue patterns offshore in the top shot, there before this branch).
- gl_compatibility logs "Too many instances using shader instance variables" on both before and
  after. It is a canon issue, not from this branch.
