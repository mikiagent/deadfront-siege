# CONTROLS (claude/mmo-controls): resource-node UI jitter, WASD + joystick, pathfinding, interactions

Owner (newest): "UI glitching up and down on resource nodes when clicking around. Do wasd control and a virtual
joystick for movement on the bottom left that only appears when hold and drag on the left side. Improve the
pathfinding and movement, player interactions with buildings, crafting stations, and resources".

Steps: B1 jitter (done), B2 WASD + joystick (done), B3 pathfinding + movement and B4 interactions (not started).

Hooks: `docs/orchestration/reports/claude-mmo-controls-hooks.patch` (other owners' files; the integrator applies
it at merge). The branch itself only adds new files.

## B1: gather radial and node labels hold still (done)

### Cause (reproduced on the base)

- `GatherRadial._process` re-solved the whole layout every frame (`ContextRadial.hex_positions` turns the ring off
  the HUD, the plant, the title and the survivor's nameplate; `title_spot` puts the title under or over the plant;
  `_draw` slid the title and re-picked every label side). The survivor's nameplate moves against the node on every
  frame of a walk, so the ring turned, the title flipped above and below, and labels changed side.
- `IsoCamera` was physics-interpolated although it moves itself every frame in `_process`. `unproject_position()`
  then read a camera that the renderer was not drawing, so screen UI drifted against the plant even when nothing
  re-solved (the mutation run below shows it).
- Node label pills were ordered by `int(40 - distance)`: every node within the same metre tied, `sort_custom` is not
  stable, and tied pills traded rows frame to frame. The survivor's figure is a soft blocker and sits at the screen
  centre while the world scrolls, so every pill the survivor walked past hopped a row.

### What shipped

- New `game/scripts/ui/radial_hold.gd` (`RadialHold`): the radial solves its layout when it opens; each frame the
  hexes, the title and the labels move by the anchor's screen motion. Where that would put them further onto the
  HUD (`UiTokens.hud_reserved`) than the solve left, or further off the safe area than the solve left plus
  `SLACK` (1024 px², a quarter of a hex), they move along one axis only or hold still on screen and the node slides
  under them. Once they lag the node by `MAX_DRIFT` (64 px, one hex) the radial solves again: that is the "space
  really ran out" case. Holding until the layout fails is the hysteresis; a jiggle at an edge cannot flip it back.
  Closing, or opening on another node, starts a fresh solve.
- Hooks (patch): `gather_radial.gd` +13 lines (holds via RadialHold, keeps the drawn title spot and label rects
  while held, `process_priority = 1` so it runs after the camera's follow); `iso_camera.gd` +3 lines
  (`physics_interpolation_mode = OFF`: it follows the target's interpolated transform itself);
  `hud_pills.gd` (pills ordered by screen y at 1/1000 px, so the order holds while the camera shifts all of them
  alike; while the survivor walks the pills hold their spots and fade to 0.35 where they cross it instead of
  stepping off it; a pill whose row changes glides 5 px per frame instead of hopping in one frame, and is not drawn
  while its glide passes under a HUD block, e.g. a level-up banner that opened over it).
  GatherRadial's public API is unchanged; gather rules, timings, yields, target selection and the hex look are
  untouched.
- New `game/scripts/dev/gather_jitter_lab.gd` + `game/scenes/dev/gather_jitter_lab.tscn`: boots home_grassland
  with the real HUD, taps a node 15-30 m off through the player's tap path, picks a hex, logs every frame of the
  walk, then taps four more nodes in a row. Per frame: each hex, the title and each label against the node's anchor
  (gate <= 2 px, no side swap), and each node label pill against its own object (gate <= 6 px; read from
  `HudPills._last_offset`; a tree without it is measured by matching each pill to last frame's pill of its size).
  On a landscape phone the HUD leaves only a band beside the survivor, so the lab zooms out fully and sets the
  survivor down 16 m left of a node on a clear line (lab setup, not gameplay).
- New `game/tests/t_controls.gd` (B1 cases; B2-B4 add theirs): the real survivor and IsoCamera, a radial on a node
  15 m off; the survivor walks to it from the left, right, above and below (~2.7 s each): <= 2 px per frame and no
  hex changes side. Edge case: pan until the node is 10 px from the left edge; nothing moves while the layout fits,
  it gives way once it runs off, every hex stays at least 3/4 on screen; then a 3 px jiggle there for 1 s never
  re-solves (nothing moves against the node by more than the jiggle).

### Numbers (before = branch without hooks, after = with hooks)

gather_jitter_lab, windowed, per frame. Walk = one ~3.5 s walk to a node with the radial open; click = four nodes
tapped in a row, 50 frames each.

| run | hex max px/frame (frames > 2 px) | title max | label max | side swaps | pill jumps |
|---|---|---|---|---|---|
| before 1600x900 Forward+, walk | 60.91 (92) | 60.91 | 231.51 | 40 | 88 (max 60.91) |
| after  1600x900 Forward+, walk | 0.00 (0) | 0.00 | 0.00 | 0 | 0 per object (max 0.00) |
| before 1600x900 Forward+, click | 136.09 (110) | 43.88 | 316.24 | 117 | 32 (max 54.30) |
| after  1600x900 Forward+, click | 0.00 (0) | 0.00 | 0.00 | 0 | 0 per object (max 5.00) |
| before 1600x900 gl_compat, walk | 60.23 (100) | 60.23 | 231.58 | 40 | 98 (max 57.33) |
| after  1600x900 gl_compat, walk | 0.00 (0) | 0.00 | 0.00 | 0 | 0 per object (max 0.00) |
| before 1600x900 gl_compat, click | 140.20 (96) | 43.09 | 328.45 | 101 | 34 (max 54.76) |
| after  1600x900 gl_compat, click | 0.00 (0) | 0.00 | 0.00 | 0 | 0 per object (max 5.00) |
| before 844x390 gl_compat, walk | 25.38 (18) | 194.61 | 190.29 | 5 | 10 (max 76.72) |
| after  844x390 gl_compat, walk | 0.00 (0) | 0.00 | 0.00 | 0 | 0 per object (max 5.00) |
| before 844x390 gl_compat, click | 152.32 (29) | 180.44 | 267.76 | 15 | 16 (max 69.07) |
| after  844x390 gl_compat, click | 1.26 (0) | 1.26 | 1.26 | 0 | 0 per object (max 5.00) |

Before has no per-object offsets, so its pill jumps are size-matched. The same size-matched count after is 0-2
per run (max 66 px): these are pops, where one label hides as another of its kind shows. The per-object count
separates them. The walks lasted 3.5 s (16.8 m at 1600x900; 11.9 m on the phone, where the survivor is set down
16 m from the node). Logs: scratchpad `controls/before/`, `controls/after/` (`jitter_<size>_<renderer>.log`).

t_controls (headless):
- Before (6adc4b55 without hooks): 10 FAIL. The walks move 323-329 px per frame at most with 8-23 hex side swaps.
  Edge: 50 frames moved while the layout still fit, and the 3 px jiggle moved it 115.96 px.
- After (with hooks): PASS. Walks 0.00 px and 0 swaps. Edge: 0 moves while it fits, least of a hex on screen 0.79.
  Jiggle 3.00 px, which is the jiggle itself: the layout holds still on screen and never re-solves.
- Mutation (hooks without the `iso_camera.gd` line): 6 FAIL. Walks 7.52-125.76 px per frame, 2 swaps; edge 47
  moves with room. The camera hook is load-bearing.

### Gates

All gates ran in scratch tree `trees/controls-gates`: 6adc4b55 plus the hooks patch (its staged diff equals the
committed patch). `--import` printed 0 SCRIPT ERROR.
- Every `game/tests/t_*.gd` (22, t_controls included) PASS. t_save prints its 5 deliberate SCRIPT ERRORs; every
  other test prints 0. run_all prints `[tests] PASS`. smoke prints `SMOKE PASS`.
- ui_real_capture_lab prints `[uireal] PASS` at 844x390 gl_compat, 1600x900 gl_compat and 1600x900 Forward+, with
  0 SCRIPT ERROR.
- ui_real_capture_lab at 667x375 gl_compat FAILS with `radial: hex0 [P: (361.3007, 371.4283), S: (64.0, 64.0)] stays
  off level [P: (369.5, 433.0), S: (65.0, 15.0)]`. The base without hooks fails the same way, with the same
  coordinates (scratch run), so this package did not cause it.
- An earlier hooks version failed uireal at 844x390 (`busy_levelup`: a pill glided under the level-up banner). The
  pill is now hidden while it is under a HUD block, and that run passes.
- gather_jitter_lab prints `[jitter] PASS` at 1600x900 Forward+, 1600x900 gl_compat and 844x390 gl_compat, with 0
  SCRIPT ERROR. The base fails 10 checks in each of the three runs.

### Shots (scratchpad `controls/before/`, `controls/after/`, all opened)

The lab saves `walk_0.3s`, `walk_1.5s`, `walk_2.7s` and `click_1` at each size and renderer (`_<WxH>_<fwd|glc>.png`).
Each shot is one frame, so the jitter shows in the numbers, not in a single shot.
- Before shots, 844x390 at 0.3 s and 1.5 s: between the two shots the "Fibre Stalk" label slid along its hex, and the
  "Wild Grass" title moved against the plant.
- After shots: the hexes, title and labels sit in the same place around the plant's ground ring in every frame.
- At 1600x900, a pill over the walking survivor is faded ("Bush Berries" in `click_1`).
- The uireal shots at 844x390 (`radial`, `busy_levelup`) are clean: no pill under the level-up banner.

### Assumptions and limits

- `RadialHold.SLACK = 1024 px²` off the screen (a label can sit up to ~39 px past the safe edge) and
  `MAX_DRIFT = 64 px` are tuning, not from a reference. The HUD gets no slack: the held layout never moves further
  onto it than its solve left (ui_real_capture_lab checks hexes and labels stay off the HUD).
- While held, the radial no longer dodges the survivor's nameplate as the survivor walks up to the node; it was
  laid out clear of it when it opened. At 844x390 the "Fibre Stalk" label ends over the name on arrival
  (`after/walk_2.7s_844x390_glc.png`). B4 will know the reach point, so it can solve the radial against the
  nameplate's spot there (one call into the same solve, no re-solve on arrival).
- Pills still pop when the "two of any one kind" set changes (another bush of the same kind comes nearer) or a node
  crosses the 8 m label range (that one fades). The lab counts these as pops (8-25 per run), not jumps. A stickier
  per-kind choice would be the next step if the owner still sees popping.
- While walking, a pill over the survivor fades to 0.35 instead of stepping off. When the survivor stops it glides
  off (ui_real_capture_lab still checks pills stay off the standing survivor).
- Creature plates are not touched: TARGETUI owns them.

### For the integrator and the next steps

- Apply `claude-mmo-controls-hooks.patch`: `gather_radial.gd` and `hud_pills.gd` (W1-UI) and `iso_camera.gd`.
  `--import` once (new class_name `RadialHold`).
- GATHERUI (the hex look, later) should keep the four RadialHold calls in GatherRadial: `solved` in `_layout`,
  `follow` in `_process`, `picked` at the end of the label pass, and `reset` in `close`. It should also keep
  reusing the held title and label rects while `held`.
- t_controls.gd is shared by B2-B4: add their cases to it.

## B2: WASD and the floating left-half move stick (done)

### What was there (base)

- Keys already worked: `InputSetup` binds WASD and the arrows to `move_*`, `PlayerSim._walk` turns `Input.get_vector`
  into a camera-relative, normalised direction at `walk_speed` (5.5 m/s; Shift = `sprint`, 8.5 m/s), and any move
  input clears the tap-to-move path, its ground marker and a gather walk. One gap: a recipe that was still walking
  to its station stayed pending, so the craft started the next time the survivor stopped within range of the bench.
- Touch: `TouchJoystick` was a fixed stick in a bottom-left zone, read in `_input` (ahead of the HUD), and hidden in
  the tap-only mode that phones, the web build and `--touch` boot in (only F4's "tap+joystick" mode showed it).
  So on a phone, a drag on the left half did hold-to-walk.

### What shipped

- New `game/scripts/ui/float_stick.gd` (`FloatStick`, extends `TouchJoystick`): a full-rect, pass-through control
  that only takes points on the left half. A touch there that drags past 12 px floats a semi-transparent base
  and knob centred on the press (the base is kept inside the safe area). The knob clamps to the base, and pushing
  it to the rim presses `sprint` (the knob turns teal). Release hides the stick and releases the actions. A press
  that never drags is replayed as a tap on release, so tap-to-walk, select and interact still work. A second
  finger that lands within 200 ms makes a pinch, not a stick, and while buildings are placed or arranged the
  stick stays off. Mouse events pass through, so desktop click-to-move is unchanged.
- Hooks (patch, on top of B1's):
  - `touch_controls.gd`: +10/-8 lines. The stick goes on its own canvas layer (0) under every HUD layer, so a HUD
    control on the left half keeps its touch. It is on in every touch mode. `blocks_screen_point` asks the stick.
  - `player_input.gd`: +3/-2 lines. A finger's emulated mouse press no longer arms the desktop-click fallback. That
    fallback picked a station under a press the stick had taken.
  - `player_actions.gd`: +2/-1 lines. `cancel_work` also drops a recipe that is still walking to its station.
  Gather rules, timings and yields are unchanged, and so are target selection, the hex look and GatherRadial's
  API.
- `game/tests/t_controls.gd` B2 cases, headless, on the real survivor and IsoCamera:
  - Keys: W, Up, D, Left, S, W+D and Down+Left each walk along the camera axis at walk speed. Shift+W sprints.
  - A move key drops the tap path, its marker, a gather walk and a craft walking to its station.
  - A desktop click on the left half still walks.
  - Stick: nothing inside the dead zone, then it floats up centred on the press, walks, clamps and sprints at
    the rim, and release stops the survivor without a tap. A short tap on the left half walks.
  - Refusals: a right-half press still taps and a right-half drag floats no stick. A press on a HUD Button floats
    no stick, nor does a pinch or a drag while arranging buildings. A corner press keeps the base whole on screen.
- New `game/scripts/dev/move_stick_lab.gd` + `game/scenes/dev/move_stick_lab.tscn`: the same thumb moves in the real
  game. It boots home_grassland with the real HUD and `--touch` and injects touches. It saves `stick_walk` and
  `stick_run` shots. It also presses the MENU hex and drags off it: no stick.

### Numbers (before = 7c668b78 with B1's hooks only, after = with this patch)

| check | before | after |
|---|---|---|
| t_controls | FAIL 2: the craft stayed pending (`t_controls_recipe`); the touch layer's tap-only mode had no floating stick (`virtual_joystick.gd`, visible=false), so the stick cases could not run | PASS, 0 SCRIPT ERROR |
| keys W / Up / D / Left / S / W+D / Down+Left | 5.50 m/s, along the camera axis (dot 1.0000) | same |
| Shift+W | 8.50 m/s | same |
| stick at 8 px (inside the dead zone) | no stick | no stick, 0.00 m/s, no tap |
| stick part deflection | none | centred on the press, 5.50 m/s |
| stick past the rim | none | knob 1.000, `sprint` held, 8.50 m/s |
| stick release | none | hidden, 0.00 m/s, no tap |
| move_stick_lab 844x390 gl_compat `--touch` | FAIL (no floating stick) | PASS: knob 0.56 walks 5.50 m/s, rim 1.000 sprints 8.50, release 0.00, a short tap walks, MENU hex keeps its press |
| move_stick_lab 1600x900 gl_compat / Forward+ `--touch` | not run | PASS, same numbers (knob 0.45 at part deflection) |

### Gates

All gates ran in scratch tree `trees/controls-gates`: 7c668b78 plus the hooks patch. Its staged diff equals the
committed patch, and `--import` printed 0 SCRIPT ERROR. The ASSUMPTION comments in `float_stick.gd` landed in the
next commit; they are comments only.
- Every `game/tests/t_*.gd` (22) PASS. t_save prints its 5 deliberate SCRIPT ERRORs; every other test prints 0.
  run_all prints `[tests] PASS` and smoke prints `SMOKE PASS`.
- ui_real_capture_lab prints `[uireal] PASS` at 844x390 gl_compat, 1600x900 gl_compat and 1600x900 Forward+, with
  0 SCRIPT ERROR.
- move_stick_lab prints `[stick] PASS` at the same three settings, and gather_jitter_lab (B1) prints `[jitter] PASS`
  at all three. Both have 0 SCRIPT ERROR.

### Shots (scratchpad `b2/after/shots/`, all opened)

- `stick_walk_<size>_<glc|fwd>.png`: the base sits on the press point above the bottom rail. The knob is part way
  up and right, and the survivor walks that way.
- `stick_run_<size>_<glc|fwd>.png`: the knob is clamped on the rim and teal (sprint), stamina is at 95, and the
  survivor runs.
- At 844x390 the base sits between the vitals and the MENU/ANIMALS hexes, just left of HANDS, and the hexes draw
  over it.
- The uireal `hud` and `radial` shots at 844x390 (opened) show no stick at rest.

### Assumptions and limits

- The rim presses `sprint`, the same action as Shift (8.5 m/s, 9 stamina/s), which is how the old stick worked.
  The 7.0 m/s run pace stays with tap-to-walk. A part deflection walks at 5.5 m/s whatever the deflection, as keys
  do.
- `# ASSUMPTION:` the stick radius is 58 px on a compact canvas and 72 px otherwise, and the pinch window is
  200 ms. Neither comes from a reference.
- On the left half, a tap acts on release instead of on press. Hold-to-walk now only works on the right half: a
  held drag on the left is the stick.
- A press on a pass-through container (a creature plate's status row) on the left half does not start the stick.
  These are small, and TARGETUI owns the plates.
- F4's tap-only and tap+joystick modes now behave the same. The mode names stay so the integrator's file changes
  as little as possible.
- The web build turns the touch layer on even on desktop Chrome. Mouse events pass through the stick, and
  t_controls shows that a left-half click still walks.

### For the integrator and the next steps

- Apply `claude-mmo-controls-hooks.patch`. It now covers `touch_controls.gd`, `player_input.gd` and
  `player_actions.gd` as well as B1's files. Run `--import` once (new class_name `FloatStick`).
- B3 (pathfinding + movement) and B4 (interactions) have not started. B4 can use `cancel_work` dropping a craft
  that is walking to its station. A tap on the left half now arrives on release.
