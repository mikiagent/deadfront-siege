# 3D-FLAT (full-3D package 2), step 1: flat land behind a switch

Branch `claude/mmo-3d-flat`. Owner 2026-10-30: "The terrain should be flat and depth is added through
props, structures, buildings, resources". No credits spent.

## What it does
- `rules.json terrain_relief`: `"heightmap"` (default, today's relief) or `"flat"`. A run can force it
  with `--flat` or `--relief`. `IslandRuntime.flat_enabled()` reads it.
- Under `"flat"` the shape generator puts every land cell above the beach on one plane (`IslandShape.FLAT_H`
  = 1.0 m, # ASSUMPTION: the old mean inland height). Sea, wet sand, the beach ramp and river channels keep
  their profile (the same 0.2-0.9 m weight the tutorial town plane uses), so coasts, docks and rivers stay.
  The town plane step is skipped since the whole island is already flat.
- Default unchanged: every existing test and save sees the heightmap.

## Check
`t_flatland`: with "flat", home_grassland and tutorial_isle have no land above the plane (0 of 8,707 and
0 of 23,708 land cells), the dock still lands her on dry ground, the sea is still deep; with "heightmap"
the relief is unchanged (tops 8.9 m and 11.0 m).

Shots (Mac, ab3d_lab `--only=rocks`): `3d-flat/ab3d_relief_jungle_rocks.png`, `ab3d_flat_jungle_rocks.png`.

## Before flipping the default (needs the owner)
Flat land removes the plateaus, mesas, cliffs and the waterfall the heightmap made. Package 5
(claude/mmo-3d-rocks) brings mountains and cliffs back as meshes; flipping the default before that leaves
islands without landmarks of height.

## Step 2: the island tests with `-- --flat` forced
- t_unstable_isles, t_props2d: PASS.
- t_islandgen: 41 failures, all expected: 40 "mesa / ridge / mountain / volcano rises from dry ground (top 1.0,
  foot 1.0)" (that relief is what flat removes) and "home_grassland has cliff faces". These checks move to
  package 5, which places those landmarks as meshes and asserts the meshes instead of the heights.
- t_landmarks: 1 failure, temperate_20 seed 3 has no landmark within 140 m of the landing (a mesa that
  stood there no longer counts as one). Same owner: package 5.
- Not run under flat: t_tutorial (long bot run).
So nothing outside the relief itself breaks; the default can flip once package 5 lands.
