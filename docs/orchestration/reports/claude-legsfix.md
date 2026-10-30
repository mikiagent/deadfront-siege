# LEGSFIX: "where did my legs go?"

Owner (verbatim): "where did my legs go?", then "i think the testing agents have my player model halfway
in the ground. probably not a big deal".

## What it is

She was never in the ground. A new game (including the dev quick start `-- --skip-charcreate --new-game`)
and every sail land her at the dock's arrival point, which is one row behind the base: about 0.7 m from the
landward edge of the dock shed. On the north-up camera (pitch 38.7 deg, looking north) the shed's frame and
roof (2.1 to 2.6 m high) lie on the sight line between the camera and her hips, legs and feet. Occlusion
fades the shed to about half, and the dithered roof is drawn over her lower half. In a windowed agent run,
that reads as a survivor cut off at the waist or sunk into the ground. The other agents' quick-start
windows all start there, which is why it looked like "the testing agents". See
`legsfix/before_tutorial_isle_landing.png`.

Measured there: her toes are 0.1 m above the floor collider (0.92 vs 0.82), her hips are 1.15 m above the
floor, and her leg mesh (`body_legs`) is visible. The position is fine; only the view is blocked.

Ruled out:
- **The owner's own save.** Read-only: a copy of
  `~/Library/Application Support/deadfront-mmo-main/save_1.json` (11:42 today, tutorial_isle, y 2.10) was
  loaded in an isolated run dir. Load re-seats her at `surface_y + 1`, and she stands on the floor with
  her legs visible (toes 1.26, floor 1.10).
- **The other suspects:** a hidden leg mesh (`body_legs` was visible at the landing and after the save
  load), visibility ranges (town polish added none to the player's meshes), and the rest or sleep visual
  drop (Visual y was 0, rig y was -1 as designed). Not checked: whether a worn leg armor piece or a clip
  that scales the leg bones can hide or shrink the legs.

Save dir: no test wrote into the owner's save dir. His game uses `deadfront-mmo-main` (a different
project name from the worktrees' "WildLands MMO"). Test, `--shot` and `--script` runs go to
`user://runs/<name>/`. One risk: a plain windowed run with `-- --skip-charcreate --new-game` and no
`--shot`/`--lab` has run name "" and writes `user://save_1.json` of that project's user dir. That is not
his dir today, but it would be if the canon checkout's project name were used.

## Fix

`IslandRuntime.arrival_point()` (the landing, used by new game, tutorial, sail, warp and the island-reset
landing) now returns row `LANDING_ROW` = -3 behind the dock base. That point is on the 30 m approach strip
and 2 rows further inland, past the roof's sight line. When that tile is under water it falls back toward the
dock, ending at row -1. `HarbourSite.arrival_point` (scatter clearings, approach strip, rings) is unchanged.

Load already snaps her onto the terrain (`SaveGame._apply`: `surface_y + 1`, with the dry-land rescue),
and spawns use `arrival_point() + UP`, so no new snapping was needed.

## Test

`game/tests/t_legsfix.gd` covers tutorial_isle and home_grassland, landing her as the game does:
- her leg meshes are visible
- she is on a floor collider
- her toes are within -0.08 to +0.25 m of the floor
- her hips are 0.8 m or more above the floor
- no other visible mesh crosses the sight line from the camera to her legs, hips and feet

Before the fix, both islands failed on `pier_shed_frame` and `pier_shed_roof`. After, it passes.

Shots: `docs/orchestration/reports/legsfix/{before,after}_{tutorial_isle,home_grassland}_landing.png`.

## Gates

See the final report (gates run: t_legsfix, t_harbour, t_islandgen, t_island_reset, t_landmarks, t_tutorial,
t_tutguide, t_save, t_playervisible, t_player, run_all, smoke).

## Notes

- Built on canon fc08395e. POSEFIX (claude/mmo-posefix) had not landed, so this branch does not include
  its deterministic line. The two do not touch the same files.
- Credits spent: none.
