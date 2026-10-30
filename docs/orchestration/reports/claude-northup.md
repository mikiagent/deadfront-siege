# NORTHUP: north is up, south is down

Owner (2026-10-29): "the game should be oriented such that north is up and south is down. Currently,
going left is going south."

## Axis convention (unchanged world data)

- North = -Z, south = +Z, east = +X, west = -X. This was already the world's convention: MapDoc row 0
  is the north edge (-z), HarbourSite/IslandShape put the dock on the southern-most coast (largest z),
  tutorial_isle wild-zone angle 270 = north.
- The camera was yawed 45 deg (copied from Durango's build-grid diamonds), so screen-up was north-west
  and screen-left was south-west. That was the bug.

## What changed

- `IsoCamera.YAW_DEG` 45 -> 0: the camera looks due north. Screen up = north, right = east.
  `project.godot` `shader_globals/camera_yaw_deg` default 45 -> 0; shader include comment updated.
  Every consumer already read the live camera or `IsoCamera.view_basis()` (movement `PlayerSim.cam_dir`,
  occlusion, CARD2D card facing, ground cover, prop cards, lightning ribbons, weather strike side,
  minimap rotation), so none needed code changes.
- HUD minimap: it turns by the camera yaw, so it is now north-up (comment updated). The atlas was
  already north-up.
- Coordinate readouts: Y now grows northward. HUD "X n  Y n" = (round x, -round z); the atlas's
  "You X · Y" and "Walking to X  Y" use (tile.x, -tile.y). A survivor on the tutorial dock reads Y -317.
- Sun and moon: the old band [-35,-85] kept the sun 80-130 deg off the yaw-45 view axis. Rotating it with
  the camera ([-80,-130]) lit only the back slope of a rot-0 tent (t_structart 0.25 < 0.35), because the
  camera now sees only the tent's south slope. ASSUMPTION: `sun_yaw_deg` [-55,-105] (55-105 deg off the
  view axis: shadows still fall to the side, tent canvas 0.39 lit), `moon_yaw_deg` -80 (the band's middle).
  lighting.json and the world_lighting.gd defaults. Owner may want to eyeball the shadow direction.
- Dev capture: `game/scripts/dev/northup_shot.gd` (+ a `--northup-shot=<dir>` hook in main.gd). It needs
  `--lab=tutorial --occupation=soldier --new-game` (its own save folder; creation auto-finishes).

## Tests

- New `game/tests/t_northup.gd`: N/S/E/W project up/down/right/left; stick up = (0,0,-1), stick left = west;
  holding move_up lowers z and raises the readout's Y; the tutorial dock bearing projects into the lower
  half from the island centre; minimap turn (camera yaw) is 0; project.godot default is 0. PASS.
- Updated where they encoded the old yaw: t_playerturn (creature-lab tap at z -12 was off the top of the
  north-up view; now z -8), t_camera (yaw 0), t_levelbadge (Y = -z), t_eyetrails (screen-right
  run heading from YAW_DEG).
- Screenshots (windowed, off-screen, self-quitting) in `docs/orchestration/reports/northup/`:
  game_1600x900 / game_844x390 (survivor on the dock: sea along the bottom, land up; minimap north-up
  with the island above her), map_1600x900 / map_844x390 (atlas: dock at the bottom of the island).

## Known limits / for the next agent

- CARD2D card textures were baked offline at the 45 deg view (card_bake.gd uses `IsoCamera.view_basis()`).
  They still face the camera, but show each prop from the old angle. Rebake with
  `Godot --path game -- --lab=card_bake` (windowed) then `--import` when convenient.
- Build grid now reads as squares, not diamonds (the Durango look the 45 deg came from).
- snap_build_lab says the iso camera sees the north wall; it now sees the south (+z) face. Dev-lab comment only.

## Test results (headless)

- PASS: t_northup, t_camera, t_levelbadge, t_mapui, t_tutguide, t_playerturn, t_switch2d, t_structart,
  t_weather, t_card2d, run_all (`[tests] PASS`), `tools/smoke.sh --no-import` (SMOKE PASS).
- t_controls exits rc=70 silently after "inventory is a right-side sheet": the same on an untouched
  origin/claude/mmo-overhaul checkout, so not from this change.
- t_fieldhud: 1 FAIL, TACKLE caption overlaps the AUTOABILITY hex at 1600x900 (HUD layout from the
  AUTOABILITY merge, not camera-related; see the base check in the hand-off).
