# CAMERA: Durango's camera, measured, and the parallax of tall trees

Branch `claude/mmo-camera` (work tree `.claude/worktrees/mmo-camera`), from `claude/mmo-overhaul` 618717ac.

Owner: "i think you want the angle to be closer to ground level. Look at Durango Wildlands screenshots for
comparison and make the camera angle the same", "for 2.5D, make the flat assets align with the camera angle at
all times", and (newest) "look at the screenshots with trees and note the parallax effect".

## The short version

- Durango's camera is a **long-lens perspective camera**: pitch **38.7 deg** down, vertical field of view
  **about 4.3 deg**, yawed **45 deg** to the build grid. Measured below from straight ground lines in three
  screenshots; an orthographic camera fits those lines 10-25 times worse.
- So Durango is **steeper** than our old camera (35.3 deg), not lower. What reads as "closer to the ground" is
  the zoom (its survivor is ~13 % of the screen height, ours was ~11 %) and the lens: the ground recedes a
  little (the top of the screen ~9 % smaller than the bottom) and tall things fan out and slide as you move.
- The long lens is also the answer to the tree question. Its vertical lines converge toward a point far below
  the screen, so trunks look almost parallel (2-3 deg of lean at the screen edges), yet a crown 10 m up is
  nearer the camera than its roots and slides against them as the camera passes. That slide is the parallax.
- IsoCamera now is that camera. Tall trees get the lens's lean plus the same again in a shader (our trees are
  7-11 m, Durango's 15-20 m), dither out above a height that drops as you zoom in, and keep the existing
  see-through fade over the survivor. The camera publishes global shader parameters CARD2D's cards can read.
- The old camera stays behind `--cam-ortho`.

## 1. Measuring the Durango camera

References: `docs/reference/durango-*.webp` (and the 2019 `durango-base-reference.jpg`). Tools and
intermediate images: scratchpad `cam/` (`tools/gridlines.py`, `fitline.py`, `fitcam.py`, `dots.py`).

### Method

1. **Straight ground lines.** The build-placing grid, two domain borders and the 2019 domain dots are straight
   lines on flat ground along the two grid axes. Each was found with a Hough-style search on a high-pass image
   (bright thin lines), giving its slope and position (`sheet_measure.png`, every fitted line drawn on the
   screenshot).
2. **Pinhole fit.** For a camera with no roll, principal point at the view centre and yaw 45 deg to the grid,
   all lines of one grid axis meet at a vanishing point `(cx +- f / cos(pitch), cy - f * tan(pitch))`. A grid
   search over pitch and focal length `f` minimises the slope error of every line; the vertical field of view
   is `2 atan(view height / 2f)`. Leave-one-out refits give the spread. The orthographic alternative (every
   line of an axis has the same slope) is scored on the same lines.
3. **Checks that do not need the fit:** a ground line through the screen centre has slope `sin(pitch)`;
   a circle on the ground is an ellipse with axis ratio about `sin(pitch)`; tiles shrink up the screen by the
   depth ratio; vertical posts and trunks lean toward a vanishing point `f / tan(pitch)` below the centre.
4. **Framing:** survivor height (head to feet) over the screen height, cropped at 3x
   (`m_survivors.png`); ground metres across with the survivor as a 1.8 m ruler.

### Numbers

| reference | lines | pitch | vertical FOV (leave-one-out) | slope rms, lens / ortho |
|---|---|---|---|---|
| placing grid, 1062x600 | 18 | 38.85 deg | 4.48 deg (4.44-4.53) | 0.0013 / 0.0313 |
| domain-claims border, view 1255x612 | 4 | 38.60 deg | 3.67 deg (3.35-3.86) | 0.0015 / 0.0153 |
| house-4x4 borders, view 1255x612 | 3 | 38.55 deg | 4.62 deg (3.86-6.23) | 0.0030 / 0.0225 |
| 2019 base (BlueStacks), view 1335x795 | 2 | 36.05 deg | 1.65 deg (2 lines: no spread) | exact |

- **Pitch 38.7 deg** (the three current screenshots agree to 0.3 deg). Cross-checks: the placing grid's slope
  at the centre is 0.627 (38.8 deg); its centre tile is 167 x 106 px (0.635, 39.4 deg); the fire pit in
  `durango-look-reference` is a 174 x 107 px dark ellipse (0.615, 37.9 deg); campfire stone rings in
  `durango-corpse-harvest` read 0.65-0.66 (the stones have height, so an upper bound). The 2019 build looked a
  little flatter (36 deg) but has only two lines.
- **FOV 4.3 deg** (3.7-4.6 across the three). The placing grid's tiles: 160 px wide at y=50 against 167 px at
  the centre (-4.2 %); the fit predicts -3.9 %. Across a whole screen height the top is ~8-9 % smaller than
  the bottom.
- **Verticals are almost parallel, as the orchestrator saw.** In `durango-forest-flat-trees` the trunk 710 px
  left of centre leans ~1.4 deg outward (the trunks also curve by about 1 deg); the hut posts in
  `durango-communication-center` are vertical within about a degree. A 4.3 deg lens predicts 2.6 deg at that
  trunk; a 30 deg lens would give over 25 deg. So "parallel trunks" rules out a normal perspective camera,
  not perspective: it is a long lens.
- **Yaw 45 deg** to the grid: the placing tiles' left and right corners sit on the same row (303 / 303 px);
  the hut's wall edges slope 0.73 and 0.64 (within ~2 deg of 45).
- **Framing.** Survivor height / screen height: placing 15.3 %, look 15.0 %, combat promo 13.9 %, domain 12.7 %,
  house 11.4 %, communication centre 9.9 %; zoomed right in: 2019 base 23 %, knife combat 26.5 %. Usual view:
  median **13 %**. With the survivor as a 1.8 m ruler that is 17-28 m of ground across the screen (median
  ~22 m) and a view 9.4-13.8 m tall at the focus. The minimap was not used.
- **Parallax.** Durango's tall trees are tall (the forest trunks run 490-620 px of an 874 px screen: 10-20 m).
  Under this lens a crown h metres up slides sideways against its roots by `h * sin(pitch) / distance` per
  metre the camera moves; the canopies over the survivor are dithered.

## 2. What shipped

- `game/scripts/camera/iso_camera.gd` (IsoCamera, rewritten):
  - Perspective, `PITCH_DEG = -38.7`, `YAW_DEG = 45`, `FOV_DEG = 4.3`, `PROJECTION`, `view_basis()`,
    `projection_mode()`, `distance_for(size)`, `cull_range(r)` are public (CARD2D's draft already calls
    `IsoCamera.view_basis()` and `PITCH_DEG`; its card bake now gets the measured angle).
  - `size` is still the zoom in both projections: metres of view height at the focus. The camera stands
    `size / (2 tan(FOV/2))` back (default 14 m -> 186.5 m, 116.6 m up; 7-18 m -> 93-240 m), so labs, the
    wheel (12 % a notch) and pinch keep setting `size`. Default 14 (survivor 13.5 % of the screen), range 7-18
    (26 % to 10 %, Durango's span). The old game view was 17 m at 35.3 deg (11 %).
  - near/far hug the focus (near = focus - ground to the bottom edge - 35 m, room for a 20 m crown just
    below the screen; far = focus + ground to the top edge + 30 m): depth stays precise this far out.
  - Follow and shake feel unchanged: the follow eases the focus point toward the survivor exactly as the old
    position lerp did (identical while the distance is fixed), and the camera stands `distance` back from it,
    so a zoom takes effect in the same frame instead of gliding in behind the fingers. The camera is still
    not physics-interpolated (CONTROLS B1).
  - `--cam-ortho`: the old orthographic camera (pitch -35.264, 40 m back, zoom 10-28, no parallax).
    `--cam-ortho --cam-size=17` is the old game view exactly.
  - Every frame the current IsoCamera publishes the global shader parameters below and `IsoCamera.focus`,
    `.parallax`, `.right` for CPU code.
- `game/shaders/camera/camera.gdshaderinc` + `project.godot [shader_globals]`: the camera contract.

  | global | meaning |
  |---|---|
  | `camera_focus` (vec3) | world point the camera looks at (its smoothed follow point). World xyz: use `.xz` for the ground. |
  | `camera_pitch_deg` | camera Euler x, negative looks down (-38.7) |
  | `camera_yaw_deg` | camera Euler y (45) |
  | `camera_distance` | camera to focus along the view, metres |
  | `parallax_strength` | extra sideways lean of tall props: metres of shift per metre of height per metre the prop stands right/left of the focus along the camera's right axis. `PARALLAX_GAIN * sin(pitch) / distance` = 0.0034 at the default zoom (equal to the lens's own lean); 0 under `--cam-ortho`. |
  | `tall_fade_height` | tall props dither out above this height over their base (1.2 x zoom: 16.8 m at the default, 8.4 m at full zoom-in); 0 = off |

  Helpers: `camera_main_forward()`, `camera_main_right()`, `camera_is_main_pass(INV_VIEW_MATRIX)` (apply the
  lean and fade only in the main camera's pass, never in shadow passes), `camera_parallax_world(origin, h)`,
  `camera_tall_fade(h)`.
- `game/shaders/occlusion/occluder_standard.gdshaderinc`: the tall props (every VegBatch tree or palm 2.4 m
  or taller, the W2-OCCLUDE "between" props) lean by `camera_parallax_world` in the main pass and dither
  above `tall_fade_height`; the see-through fade over the survivor is unchanged. Shadows keep the unleaned shape,
  as a real lens would.
- `game/scripts/world/world_lighting.gd`:
  - Shadows for the perspective camera: one shadow map (`SHADOW_ORTHOGONAL`) from the camera's near plane to
    just past the ground's top edge, fading only past that edge. Two findings from `camera_lab` experiments:
    Godot ends split i at `split_i * max_distance` and starts split 0 at the camera's near plane (fractions of
    near..max left a 4 m band of shadow); and with near at 105-145 m, gl_compatibility drew no shadows at all
    from PSSM2 or PSSM4 at the default zoom while Forward+ did. The single map draws in both. Its slice is
    ~60 m deep and the view's size across: 1.6 cm texels on the 4096 desktop atlas, 6.5 cm on the 1024 mobile
    one, in one shadow pass instead of four. The orthographic camera gets PSSM4 and its old fit back.
  - Fog is depth-based: it is thinned by 40 m / camera distance so the ground at the focus keeps the fog it
    had at 40 m.
- Visibility ranges were metres from a camera 40 m away: `VegBatch` cells (120 m), tree discs (60 m) and
  decor (48 m) would all have vanished. They are now `IsoCamera.cull_range(80 / 20 / 8)`: the camera's
  farthest lab distance (30 m zoom, 400 m) plus the same ground radius. The narrow frustum and tight far plane
  do the culling.
- Tap picking (`player_input.ray`, `build_placer._ground_at`) runs to `cam.far` (the old 200 m ray stopped
  short of a camera 186-400 m away). Pinch zoom (`touch_gestures`) zooms an IsoCamera in either projection inside
  the camera's own range. Occlusion's sight test bends by the same lean as the shader (`Occlusion.unlean`).
  Screen UI (gather radial, RadialHold, pills, plates, station menus) already unprojects through the camera and
  needed nothing; the minimap turns with the camera's yaw, which is unchanged.
- Tests and labs: new `game/tests/t_camera.gd` (23 checks: constants, focus at the screen centre, size is the
  view height, tap ray, receding ground, edge lean, zoom in one frame, zoom band, pinch limits, unlean). `t_lighting` gains a
  perspective shadow and fog case. `t_structart` reads `IsoCamera.view_basis()`. `t_web` checks the
  cull range. `t_controls` zooms by the pitch ratio (23.8 m) so its node 15 m down the screen sits where it did
  (at 22 m the steeper pitch put it 23 px lower, where RadialHold steers around the HUD band: 2.75 px). The
  `gather_jitter_lab` zooms out to the old 22 / 28 m scaled by the same pitch ratio and snaps the camera
  after it (players now stop at 18 m).
- New `game/scripts/dev/camera_lab.gd` (+ scene): forest / home spots on an island with the real HUD, a
  parallax pan series with per-tree lean numbers, a pan clip, frame time, and a survivor motion probe.

Not touched: buildings, creatures, the HUD layout.

## 3. Gates

Godot only through gslot with a perl alarm; windowed for every shot.

- Every `game/tests/t_*.gd` (28 with t_camera), on the final code: PASS, 0 SCRIPT ERROR except t_save's 5
  deliberate ones. `run_all`: `[tests] PASS`. `tools/smoke.sh --no-import`: `SMOKE PASS`. (`--import` after the
  class changes: 0 errors.) In that run t_player printed `[t_player] PASS` and then exited 143 (terminated from
  outside while quitting); run again alone: exit 0, PASS, 0 SCRIPT ERROR.
- `island_lab` headless: exit 0, 0 SCRIPT ERROR, `[world] mm=2 nodes=397 creatures=24`, every `[world]` line
  identical to the base.
- `gather_jitter_lab` (HUD and labels while walking and clicking). Base = 618717ac + camera_lab in a scratch
  tree. The lab's own set-up (which node it finds, how far the route walks) fails on the base in all three
  configurations, so read the hold numbers, not only the verdicts. Rounds A-D are the lab as it changed here:
  A the old 22 / 28 m zoom-out; B that zoom scaled by the pitch ratio (1.083, as much ground up and down the
  screen as before); C the camera applying a zoom at once (below); D the lab snapping the camera after its zoom
  (final).

  | run | walk: hex, title, labels max px/frame | click 4 nodes: max px/frame | pills per object (gate 6) | verdict |
  |---|---|---|---|---|
  | base 1600x900 gl_compat | 0.00 (route ended after 0.32 s) | 51.14 in 2 frames | 5.00, 0 jumps | FAIL 5 |
  | base 1600x900 Forward+ | 0.00 | 58.33 in 2 frames | 5.00, 0 jumps | FAIL 3 |
  | base 844x390 gl_compat | no node 15-30 m on screen | 0.00 (3 opens) | 5.00, 0 jumps | FAIL 1 |
  | new A 1600x900 gl_compat / Forward+ | 0.00 / 0.00 | 24.22 in 2 frames / 0.00 | 5.00, 0 jumps | FAIL 3 / PASS |
  | new B 1600x900 gl_compat / Forward+ | 0.00 / 0.00 | 0.00 / 0.00 | 5.00, 0 jumps | PASS / PASS |
  | new C 1600x900 gl_compat / Forward+ | 0.00 / 0.00 | 0.00 / 28.14 in 2 frames | 5.00, 0 jumps | PASS / FAIL 3 |
  | new D 1600x900 gl_compat | 0.00 (route ended after 0.32 s, as on the base) | 0.00 | 5.00, 0 jumps | FAIL 2 (set-up) |
  | new D 1600x900 Forward+ | 0.00 (3.51 s, 20.5 m) | 0.00 (2 opens) | 5.00, 0 jumps | FAIL 1 (set-up: 2 of 3 opens) |
  | new A-D 844x390 gl_compat | no node 15-30 m on screen | 0.00 (2 opens) | 5.00, 0 jumps | FAIL 2 (set-up) |

  Nothing moves against its anchor while walking in any run. The click step is the known GATHERFIX item ("one
  camera step while clicking between nodes", 45 px there): 51-58 px in every base run, 24-28 px in two of eight
  new desktop runs and 0.00 in the other six. The phone run cannot set itself up on today's base either
  (GATHERFIX known item 3).
- Survivor motion probe (`camera_lab --cam-motion`: walk right then up 3 s each at 60 fps; the survivor's screen
  velocity change per 1/60 s, frames the machine held skipped; gate 2 px):

  | run | new (final camera) | new (earlier rounds) | base |
  |---|---|---|---|
  | 1600x900 gl_compat | 0.44 | 1.19, 10.78, 2.61 | 30.82, 22.72 (a one-frame 21-29 px jump walking up) |
  | 1600x900 Forward+ | 3.85 | 3.52, 3.67, 2.73 | 3.60, 4.24 |
  | 844x390 gl_compat | 1.35 | 1.16, 0.60, 2.10 | 9.84, 9.84 (the same jump) |

  No camera-made jump: the base's repeatable 21-29 px jump walking up is gone, and what is left is the 1-4 px
  wobble at the start of a walk that the base has too (the step's sign flips while the survivor accelerates,
  with 14-19 ms frames on a busy machine; the one 10.8 px run had 11-12 ms frames under a 60 fps cap). The 2 px
  gate is stricter than the base meets; I left it at 2 and report the numbers: Forward+ fails it on both.
- Frame time at 1600x900 gl_compatibility: section 4. In short, draw calls -30 % and render CPU lower in every
  case; frame time faster in the forest and within the noise at the home spawn.

## 4. Frame time

`camera_lab --cam-perf`, windowed 1600x900 gl_compatibility, `--disable-vsync`, 300 frames standing then 300
walking. Base = 618717ac with the lab (old orthographic camera at the game's 17 m view); new = this branch at its
default 14 m. Runs interleaved base / new, 3 rounds, the forest spot and the home spawn, 3D at 1x and at 2x
(`--cam-ss2`, to lift the frame above the display cap). Median frame time of each run in brackets.

| spot | 3D scale | phase | base median ms (runs) | new median ms (runs) | base / new p95 ms (median) | render CPU ms base / new | draw calls base / new |
|---|---|---|---|---|---|---|---|
| forest | 1x | stand | 8.50 (11.7, 7.0, 8.5) | 7.02 (8.3, 7.0, 7.0) | 9.6 / 8.3 | 3.12 / 2.68 | 273 / 189 |
| forest | 1x | walk | 8.56 (12.1, 7.0, 8.6) | 7.06 (9.4, 7.1, 7.0) | 9.9 / 8.2 | 3.37 / 2.68 | 275 / 196 |
| forest | 2x | stand | 15.11 (15.1, 12.7, 15.6) | 7.61 (7.6, 10.0, 7.1) | 17.0 / 11.9 | 4.13 / 3.31 | 273 / 189 |
| forest | 2x | walk | 12.84 (12.8, 12.0, 14.5) | 8.01 (8.0, 9.8, 7.0) | 17.4 / 11.1 | 4.35 / 3.31 | 274 / 191 |
| home | 1x | stand | 7.78 (8.8, 7.0, 7.8) | 8.53 (8.5, 7.0, 8.6) | 8.9 / 10.6 | 3.96 / 3.85 | 265 / 184 |
| home | 1x | walk | 7.57 (10.2, 7.0, 7.6) | 9.31 (9.6, 7.0, 9.3) | 8.8 / 12.7 | 4.04 / 3.95 | 270 / 194 |
| home | 2x | stand | 10.28 (10.6, 10.3, 7.0) | 7.01 (7.0, 8.2, 7.0) | 11.2 / 8.2 | 3.65 / 3.51 | 261 / 184 |
| home | 2x | walk | 7.01 (7.0, 10.4, 7.0) | 7.00 (7.0, 8.3, 7.0) | 8.1 / 8.1 | 3.57 / 3.51 | 265 / 185 |

- The Mac holds frames at ~7.0 ms (its 144 Hz display) even with vsync off, and the machine was shared with
  other agents' Godot runs, so single runs swing by 3-8 ms. Read the columns that do not swing: **draw calls
  -30 %** in every case (273 -> 189 in the forest: one shadow pass instead of four, a view ~30 % smaller) and
  **render CPU time lower in every case** (forest 3.1 -> 2.7 ms, 4.1 -> 3.3 ms at 2x; home 4.0 -> 3.9 ms).
- Frame time: the forest is faster at both scales (1x 8.5 -> 7.0 ms, at the cap; 2x 15.1 -> 7.6 ms). The home
  spawn at 1x reads 7.8 -> 8.5 ms standing and 7.6 -> 9.3 ms walking on the medians, but run for run it is
  8.8 / 7.0 / 7.8 against 8.5 / 7.0 / 8.6: inside the noise, and its render CPU and draw calls are lower.
  At 2x home is 10.3 -> 7.0 ms. GPU time is not measured: the compatibility renderer reports 0.

## 5. Shots (all opened)

Scratchpad `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/cam/`;
the sheets are copied next to this report. The `after3` set, the clips and the zoom extremes were taken at
c83d971d; the last camera change (e6dfe535: a zoom applies at once) leaves a settled view the same, and
`final/` retakes all six (home and forest, 1600x900 both renderers, 844x390 --touch) on the final code:
`camera-final-shots.jpg`. Shadows in all six, same framing as `after3`.
- `zoom/sheet_zoom.png`: the forest at 7 m (closest: crowns above 8.4 m dither, the tree in front of her
  dithers too) and 18 m (farthest).

- `camera-durango-vs-new-phone.jpg` (`sheet_durango_vs_new_phone.png`): Durango communication centre and forest
  (phone screenshots) next to our home and forest at 844x390 gl_compat, all 420 px tall.
  `camera-durango-vs-new-desktop.jpg`: Durango communication centre and corpse harvest next to home and forest
  at 1600x900 gl_compat, all 450 px tall. Same angle and similar framing; Durango's HUD is smaller on the phone
  and its art is denser, which no camera changes.
- `camera-before-after.jpg` (`cam_before_after.png`): old camera (17 m, the game's view) against new (14 m) for
  home and forest at 1600x900 in both renderers and at 844x390 --touch. The new view is ~18 % closer and
  steeper, the domain square is visibly narrower at its far corner, tall trees fan out a little.
- `camera-parallax-frames.jpg` and `camera-parallax-pan.mp4` (`parallax_pan.gif`, 6.9 MB, in the scratchpad):
  the camera gliding 12 m past the forest, old orthographic camera (left) and new (right) at the same zoom.
  Left, every crown moves with its roots. Right, crowns slide against their trunks and the trunks fan out
  towards the edges. Lean per tree from the lab (`after3/forest_1600x900_glc.log`, every tall tree on screen
  in the pan series): the lens alone gives -3.1 to +3.1 deg from the left to the right edge, with the shader
  -6.1 to +6.0 deg; the centre column stays vertical.
- `after3/`: `home_*` and `forest_*` at 1600x900 gl_compat and Forward+ and 844x390 gl_compat --touch, each with
  a pan series; shadows present in all six (they were missing in gl_compat at 14 m with PSSM4: `exp2/sheet.png`).
- `camera-measure.jpg` (`sheet_measure.png`): the fitted lines on the four references.

## 6. For the next agent

- **CARD2D** (`.claude/worktrees/mmo-card2d`): read the camera from here, not from `[card2d]` project settings.
  `IsoCamera.view_basis()` and `PITCH_DEG` keep their names (merge: take this branch's iso_camera.gd and re-bake
  the cards at -38.7). In `card_sway.gdshader` declare `global uniform vec3 camera_focus;` etc. (or include
  `res://shaders/camera/camera.gdshaderinc`) and drop the local uniforms of the same names. Two contract
  differences from the draft: `camera_focus` is world xyz (the draft read `.xy` as world xz), and
  `parallax_strength` is in metres per metre of height per metre of sideways offset along the camera's right
  axis, applied with the card's height in metres (the draft used 0.055 per normalised height, in both screen
  axes). A card standing upright already gets the lens's own lean under this camera; the shader lean doubles it,
  as for the 3D trees. Gate it with `camera_is_main_pass(INV_VIEW_MATRIX)` so shadows stay put.
- **Interaction camera (spec 25 item 3)** is not in this package: follow is unchanged.
- Shadows: if a later Godot draws PSSM shadows in gl_compatibility this far out, splits as fractions of the max
  distance (`camera_lab --cam-exp=2,0,0` reproduces the failure) would sharpen the near ground; one map is
  1.6 / 6.5 cm today.
- Windowed Godot runs on this machine sometimes never draw (another Godot window covering ours); the shot
  scripts retry, and a run that times out without a shot is that, not a crash.

## Assumptions (`# ASSUMPTION:` in code)

- `PARALLAX_GAIN = 1.0`: tall props lean twice what the lens gives them. Durango's trees are about twice as
  tall as ours, so a 10 m crown slides like a 20 m one. Durango itself shows no exaggeration (its trunks lean as
  its lens predicts); set the gain to 0 for the lens alone.
- `TALL_FADE_PER_SIZE = 1.2`: owner, spec 25: "the tall trees fade out of zoom". Nothing of ours fades at the
  default zoom (from 16.8 m); at full zoom-in crowns above 8.4 m dither out. My reading of the owner's words.
- Default zoom from the survivor's share of the screen (13 %), not from metres: our survivor reads taller on
  screen than a 1.8 m Durango survivor, so we show ~25 m across a 16:9 screen where Durango shows ~22 m.

Credits spent: none (no Meshy, no Tripo).
