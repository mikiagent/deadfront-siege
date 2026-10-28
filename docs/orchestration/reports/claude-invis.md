# INVIS: the survivor's model disappeared

Owner: "player model has disappeared in the current version" (night, Lv 9, Exhausted 75 %, in the river, DRINK showing).

## Root cause

Not swimming, mood idles, occlusion or the Wet sheen. Canon's `game/.godot/global_script_class_cache.cfg` was
written at 17:17; WEATHER r2 (merged 17:24) added `class_name FireWeather` and `class_name LightningBolt`, and
canon was then launched from source without an import. Godot only knows class_names from that cache, so
`data.gd`, `status_effects.gd`, `world_weather.gd`, `bonfire.gd`, `build_grid.gd` and `build_placer.gd` failed to
compile. Data never loaded, so the survivor rig never set up: no body, only her night lamp on the water.
The owner's log (`deadfront-mmo-main/logs/godot2026-10-28T17.46.55.log`) has exactly this signature: FireWeather
parse errors, then 200k `tile_of` / `tick` on Nil / `soak` / `swimming` on Nil errors.
Reproduced with canon's cache copied into this worktree and the owner's save: `invis/before_night_river_1600x900.png`.

## Fix

- `game/scripts/core/class_cache_guard.gd` (no class_name, so it loads with a stale cache): lists class_names
  under `res://scripts` and `res://shell` that the loaded cache lacks. `ShellLoader._init` (first autoload) calls
  `heal()` on editor builds: on a stale cache it runs `--headless --import`, relaunches the same command
  (absolute `--path`) and quits. Headless runs only print the error with the import command (no detached relaunch
  under a test harness). Exports are untouched (they carry their own cache).
  After: `invis/after_night_river_1600x900.png` (same stale cache, the game re-imported and relaunched itself).
- `WaterAccess.SWIM_DEPTH_M` 0.75 -> 1.3 m (chest-deep on the 2 m survivor). At 0.77 m (the home river's deepest
  point) she trod water with swim_idle's -0.4 m lift, legs in the riverbed. 1.3 m is where treading water puts her
  feet. `# ASSUMPTION` in code; docs/current/survival-needs.md updated.

## Tests

- New `t_playervisible`: the guard finds no missing class here and catches a cache without FireWeather /
  LightningBolt; dry / river / deepest river / deep sea x noon / night x fatigue 0 / 50 / 75: body mesh visible,
  head in the IsoCamera frustum and >= 0.3 m above the water, not swimming where she can stand, swimming in deep sea.
- `t_water` deep spot moved past the new swim depth (1.5 m).
- Gates: t_water, t_player, t_weather, t_occlude, t_occlude2, t_occlfix, t_fieldhud, t_playervisible PASS;
  run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.

## For the next agent

- Canon is still stale until this merges or someone runs
  `Godot --headless --path <canon>/game --import`. Every merge that adds a class_name needs an import before
  a source launch; `smoke.sh --no-import` after such a merge hides it.
- Credits spent: 0.
