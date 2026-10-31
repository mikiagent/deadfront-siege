# claude-isocam: isometric diagonal back, zoom-in tilts behind the survivor, a corner-door guild

Branch `claude/mmo-isocam`, cut from `origin/claude/mmo-overhaul` (b68998e8), canon merged in again after the merge gate. Not merged to canon.

Owner (2026-10-30, overrides NORTHUP's yaw 0): "if the buildings face south we dont have that isometric thing going on anymore. i like the isometric look better ... move the orientation such that the town is the same but north changes and the perspective is back to durango isometric. also make some buildings where the south corner is the door ... change the angle so it can go more horizontal so the camera looks like it's behind the player and slightly up, we can zoom out and get isometric".

## 1. Diagonal view (no flag)
- `IsoCamera.YAW_DEG` 0 -> 45 (looks north-west; the camera sits south-east of the survivor), `project.godot` `camera_yaw_deg` 45. The town did not move: its south-facing grid fronts and the east faces now read as Durango diamonds, and a building's south-east corner is the one nearest the camera.
- Movement: `PlayerSim.cam_dir` already reads the live camera basis, so stick-up walks up the screen (north-west). Checked in t_northup.
- Minimap: already drawn turned by the camera yaw; it now carries an **N marker** on the rim where world north lies (`hunt_hud._draw_minimap_bezel`, `minimap_north`). The atlas stays north-up with its compass.
- X/Y readout: unchanged, world coordinates (X = x, Y = -z).
- Occlusion / sight lines: use the live camera position and `IsoCamera.right/focus/parallax`, nothing yaw-specific. t_occlude2 PASS.
- Cards: re-baked at yaw 45 (`--lab=card_bake`, `[cardbake] PASS cards=24`, then `--import`). The bake reads the camera basis and its light uses `YAW_DEG - 10`, so it follows the constant; 24 albedo/normal pairs and `card2d.json` pivots/boxes changed. Live cards (CardProp, PropCards) take the active camera's basis every frame.
- Sun / moon: lighting.json's yaw bands were tuned for camera yaw 0, so `WorldLighting` now adds `IsoCamera.yaw_deg` to them (two lines in `world_lighting.gd`, chosen so they do not touch the lines lookpass changes).
- Dev A/B: `--cam-yaw=0 --cam-notilt` is the NORTHUP camera (north-up, iso range only); `--cam-fov` / `--cam-pitch` still override the iso end.

## 2. Zoom-coupled pitch (the curve)
`# ASSUMPTION`, logged as IC2/IC3 in `docs/vision/WildLandsMMO_Open_Questions.md`:
- 7-18 m (`ISO_MIN_SIZE`..`MAX_SIZE`): the unchanged iso view, pitch -38.7, 4.3 deg lens, default 14 m.
- 7 -> 3.5 m (`MIN_SIZE` is now 3.5): `t = smoothstep((7 - size) / 3.5)`; pitch lerps -38.7 -> -22, FOV 4.3 -> 40 deg, the focus lifts 0 -> 1.0 m (her chest). Distance stays `size / (2 tan(fov/2))`: 93 m at 7 m, ~4.8 m at 3.5 m. Six wheel notches, pinch uses the same range. Yaw never changes.
- The close top edge sits at -22 + 20 = 2 deg under the horizon: no sky band.
- Far plane: the ground at the top edge (`view_depth`, real wide-lens geometry) + 30 m + 150 m x t. Shadows and the near band use `ground_half_depth` = `min(view_depth, 40 m)`, so one shadow map never spreads over 250 m.
- Fog: `_fit_perspective` scaled fog by 40 m / distance (8x at 5 m back, the close view was a white haze); it now never goes above the profile's own density. The iso range is unchanged (t_lighting checks it).
- The extra parallax lean and the tall-crown fade fade out with t (a wide lens already leans everything; crowns ahead of her are not over her).
- The pose changes only on a zoom change (`_posed_size`), so labs that turn the camera themselves keep their angle.

## 3. The Adventurer's Guild (corner door), reworked after the merge gate
- First version (a separate 10x8 hall placed before the rows) shifted the town's random layout and added 7 batches (t_tutorial: 226 > 220) and broke tut_dagger / skip-tutorial via the changed layout.
- Now: the first south-facing row house west of the dock avenue on the dock side becomes the guild (6 x 6 m at x -87, z 290, by the arrival). `house(..., corner_door = true)` cuts its south-east corner (nearest the camera) on a 45 deg chamfer: kit doorway, door leaf and awning on the ground floor, a window upstairs, plain slivers either side, corner posts at the chamfer ends. Every random draw a plain house would make is still made, so the rest of the town lays out exactly as canon (217 batches, same as canon; +20 instances).
- Interaction: one `TownBuilding` (`AdventurersGuild`, role `adventurers_guild`) carries the building's collision box; a tap anywhere on it runs the Faction Hall desk's branch (tutorial orders while they run, then the Factions screen). Own role, so the tutorial's "guild" order still points at the Faction Hall.

## 4. Town streaming (owner: "do perspective based loading and only load a certain radius around the player")
- `TownDress.stream(at)`: the batches stay grouped by their 120 m chunk; a chunk is in the tree only while the player is within `STREAM_R` = 140 m of its square (# ASSUMPTION: widest game zoom's half-view + one chunk, open question IC6), checked every 0.5 s with the townsfolk. Batches that stream back in are re-filed with Occlusion (it forgets a node that leaves the tree). Detached batches are freed with the town.
- t_tutorial's 220 budget now counts the batches loaded around the player (`loaded_batches()`), and checks they stream out 2 km away and back in.
- With 120 m chunks the tutorial town is small enough that it is all loaded from the square; smaller chunks would load less but cost more draw calls. Island props (VegBatch, PropCards, ground cover) already cull per cell by visibility range and are unchanged.

## Shots (docs/orchestration/reports/isocam/)
Off-screen windowed, self-quitting runs (`--position 6000,3000 ... -- --skip-charcreate --lab=tutorial --new-game --northup-shot=DIR --shot-sizes=... --shot-spots=...`; `northup_shot.gd` gained the two flags).
- `before/`: canon (ba65da3b) at 14 (default), 7 (closest), 18 (widest), dock and square, 1600x900 and 844x390, plus the atlas.
- `after/`: 14, 5 (mid tilt), 3.5 (closest, behind her), 18, at dock, square and guild, both sizes, plus the atlas.
- Looked at: no sky, no fog wash close up (fixed, see above), no popping at the far plane in these views, the survivor stays centred and lit; the corner door faces the camera at every zoom.

## Gates
t_camera PASS (updated: yaw 45, the curve, one-frame zoom at both ends, tap ray at every zoom, far/shadow bands), t_northup PASS (rewritten for the diagonal: screen compass, SE corner lowest, stick up = north-west, minimap N marker, yaw fixed when zoomed in), t_mapui PASS (no t_minimap exists; t_mapui covers the minimap and atlas), t_card2d PASS, t_perfgates PASS, t_lighting, t_structart, t_switch2d, t_controls, t_eyetrails, t_levelbadge, t_web, t_targetui, t_hudrules, t_gather, t_tactical, t_weather, t_occlude2 PASS, run_all `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS.
- t_playerturn: 1 FAIL `tap_walk_away_target_gone: no position jitter (1 velocity flips)`; canon ba65da3b fails the same case, so not from this change.

## For the next agent
- lookpass (`claude/mmo-lookpass`) re-tunes `sun_yaw_deg` (-38..-62) for the yaw-0 camera. With this branch the band is camera-relative, so their values land 45 deg further round; they should re-check their shots after merging this.
- `world_lighting.gd` changes are three lines (moon yaw, sun band, fog cap) placed away from lookpass's hunks; a merge should be clean but re-run t_lighting.
- Credits spent: 0.
