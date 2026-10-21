# GUIDE (claude/mmo-guide): the walkthrough finger

Scope: durango-prompts 22. The owner wrote: "notice the game ui and how the resource gathering looks. The finger icon is a walkthrough guide".
Before this package the game had no tutorial pointer or hint system on any branch. The standing orders
(`data/world/objectives.json`, `scripts/core/objectives.gd`) only showed text on the Orders card.

Branch head: see `git log claude/mmo-guide`. `claude/mmo-overhaul` @ 809be2e8 (HUD-DAYNIGHT, W2-DATA sync) is merged into the branch;
the base has moved only to acc684a6 since (STATUS and workflow-script commits, no game file), and the hooks patch applies clean there. Every gate below
ran on the branch head with the hooks patch applied. Fix rounds 1 and 2 are in "Review round 1" and "Review round 2" below; the
bullets here describe the branch as it is now.

## What shipped

- **A white pointing hand.** It is drawn as vectors in Durango style: a gloved right hand seen from the back, a grey cuff, an ink outline and a soft shadow, with no text.
  - It taps gently: the tip eases back up to 10 px along the finger and presses in again 1.1 times a second, and the hand squashes 4 % on the press.
  - Height is 70 px on a landscape phone (844x390) and 86 px on a desktop canvas.
  - It sits on its own CanvasLayer 66, above the gather radial (64) and the work ring (65) and below the modals (96).
  - It uses `MOUSE_FILTER_IGNORE`, so a tap on the hand lands on whatever is under it.
- **What it points at** (`Guide.plan`, from the step's own data):

  | # | Order | Plan | Target on screen |
  |---|---|---|---|
  | 0 | branches | gather `branch` | nearest safe tree, then its Branch hex once the radial opens |
  | 1 | stone | gather `stone` | nearest rock, then its Stone hex |
  | 2 | fibre | gather `fibre_stalk` | nearest bush or grass, then its hex |
  | 3 | twine | craft (hand recipe) | the HUD's MENU hex (Menu, then Craft) |
  | 4 | knife | craft (hand recipe) | the MENU hex |
  | 5 | axe | station `workbench` | nearest workbench |
  | 6 | logs | gather `wood_log` | nearest tree with Wood Log, then its hex |
  | 7 | meat | creature `compsognathus` (`guide` field) | nearest living wild compy |
  | 8 | cook | station `campfire` / `bonfire` | nearest of either |
  | 9 | net | craft (hand recipe) | the MENU hex |
  | 10 | tame | creature `zebraceratops` (`guide` field) | nearest wild zebraceratops |
  | 11+ | sail, survival, visits, raid | explicit none | no finger |

  The plan picks the target this way:
  - An item that a nature family's `harvest` lists is gathered.
  - Otherwise, an item that a recipe outputs is crafted: by hand when the recipe has no station, else at its station.
  - A `"guide": {"creature": id}` field in objectives.json names the creature where the order is not about a grown or crafted item. Only meat and tame carry one.
- **The gather target.**
  - It is the nearest `HarvestNode` whose `options()` offer the item (not blocked, not depleted).
  - It prefers a node outside every living hostile creature's aggro radius (ASSUMPTION below).
  - It keeps the last tree while that tree is still as safe and at most 1.5 times as far as the nearest one, so the finger does not hop between trees.
  - Once the radial opens on that node, the finger moves to the item's hex through the new `GatherRadial.hex_rect_for(item)`.
    It aims at the part of the hex that is clear of the vitals and the Orders card. Beside the tree at 844x390 the radial puts the Branch hex half on the card.
  - The radial re-solves its layout every frame. The finger re-reads the rect every frame and runs at `process_priority` 100, after the radial and the camera.
- **Off-screen, behind-camera and hidden targets.**
  - The finger clamps to the safe-area edge (20 px in), where the line from the centre to `cam.unproject_position` leaves the screen. The projection is mirrored when the target is behind the camera.
  - A target under a HUD block (vitals, Orders card, minimap) counts as hidden in the same way. Before this run, the finger at 844x390 pointed at a tree under the minimap.
  - The hand points at the target from there. Where it would land on the vitals, the Orders card or the minimap, it walks along the edge to the nearest clear spot, on an 8 px grid so it holds still. It never slides inward, where it tapped the camp tent.
  - Along the edge it also keeps off the HUD's other controls (CLAIM, HANDS, the day/night dial, the hex row and their captions), with at most 20 px of the hand off the screen.
  - Level-ups, notices and toasts are soft (fix round 2): it prefers a spot off them, but it stays on one rather than move onto a HUD control. Name tags and pills still do not move it. Where no spot is clear of the controls, the nearest spot off the vitals, the card and the minimap is used.
  - When it first clamps (fix round 2), it prefers a spot whose line runs at most 16 px within 20 px of the vitals or the card, and it may turn up to 20 degrees off the target for that, through 5-degree steps that all fit. Pointing past the minimap is fine. At 844x390 at spawn no such spot exists (see Review round 2), so the hand keeps the round 1 spot.
  - It keeps last frame's edge spot while that spot fits as well (its line aside) and is at most a quarter of the way round the edge farther than the nearest clear spot. A clear spot on the line from the centre still wins. Without this, at 844x390 the spot left of the card and the spot below the minimap took turns as the tree moved, and the hand swapped across the screen 3 times on the walk to the tree.
  - A clamped hand does not tap. It nudges 6 px toward the target 0.7 times a second, with no press squash, so it reads as "this way", not "tap here".
- **Where the hand sits.** Eight placements are tried: below-right, below-left, above-right, above-left, then square-on.
  - The hand never goes on the vitals or the Orders card. If no placement keeps it off them, the finger hides.
  - The hand prefers the placement that covers the least of the minimap and of the open radial's labels and title. These soft blocks never hide the finger.
  - On a gather hex it keeps off that hex's own label wherever any placement allows, with the tip anywhere in the middle half of the hex (fix round 2: at 844x390 the card sits 2 px above the Branch hex, and a hand on its side fits between them only with the tip 4 px above the hex's centre). On a craft order it keeps off the HUD's other controls wherever any placement allows, and its tip sits on the MENU hex's upper rim, so the icon stays in sight.
  - The hand's footprint is its outline at both ends of the tap plus the drop shadow. Before, it was that box grown 10 px on every side, which also kept it 10 px off blocks in front of the tip.
- **Motion** (new this run, for the owner's 2026-10-21 rule "watch out for glitchy movement of UI"):
  - A new target, or an anchor that moves more than 24 px in a frame, makes the hand glide over from where it was drawn instead of jumping. The glide is an ease-out.
  - The drawn hand never moves more than 2000 px/s times the frame's time in a frame (fix round 2). Before, a move under 24 px on top of a running glide went past that.
  - A new placement turns the hand at 10 rad/s instead of snapping it round.
  - The current placement stays while it covers at most 20 % of the hand's area more labels than the best one. It gives way 6 px before it would touch a HUD block or the screen edge. Another placement takes over only when it is 18 px clear. This stops the flip-flop the lab caught at 844x390, where the hand swapped sides 3 times in 3 s beside the Orders card.
  - On a new target (the tree giving way to its hex, the edge giving way to the tree) the placement is picked afresh and not kept.
  - On a gather hex the tip tracks the hex exactly, with no glide, because the gate wants the tip inside the hex from the frame the radial opens.
  - If an eased hand would touch the vitals or the card, it cross-fades over 0.25 s from where it was drawn to its final place instead of gliding over them. The "never on them" rule wins over the glide. Before fix round 1 it snapped there in one frame.
- **When it shows.** All of these must hold:
  - The current order is not done.
  - Its id is not in `World.guide_done`.
  - A target resolves.
  - `HuntHud.play_covered()` is false. That covers a sheet (menu, build, skills), the bag, craft, the atlas, the animal screen, the creature plate and the death screen.
  - No screen the HUD does not own is up: `WorldUI.covering()` (hook H9, fix round 2) for WorldUI's sheet (terrain pick, harbour routes, map, pause) and its arrival welcome, and the `character_creation` group for character creation, as HANDS checks it. The finger's layer 66 is above WorldUI (40) and character creation (60).
  - The gather radial is closed, or open on this order's hex. While the radial is open on another node the finger waits.
- **When it is done.**
  - Picking the right hex, or the order advancing, marks the step done: its id is added to `World.guide_done` and `SaveGame.save_now()` runs.
  - The finger never comes back for that step, including after a reload.
  - Old saves have no `guide_done`. They count every order before the saved `objective` as shown. The field is optional, so there is no rev bump.
  - `SaveSanitizer` drops a `guide_done` that is not a list.
- **Order 1 hint:** "Tap a tree and pick Branch from the wheel" now reads "Tap a tree and pick the Branch hex".

Files on the branch:
- new: `game/scripts/core/guide.gd`, `game/scripts/ui/guide_finger.gd`, `game/tests/t_guide.gd`, `game/scenes/dev/guide_lab.tscn`, `game/scripts/dev/guide_lab.gd` (with their `.uid`s)
- this report and `claude-mmo-guide-hooks.patch`

Everything in files other packages own is in the hooks patch.

## Hooks (`docs/orchestration/reports/claude-mmo-guide-hooks.patch`, 9 files, +72 -29)

| # | File | Change |
|---|---|---|
| H1 | `scripts/core/world.gd` | `var guide_done: PackedStringArray`; `start_new` clears it |
| H2 | `scripts/core/save_game.gd` | writes `"guide_done"`; `_apply` reads it with `Guide.done_from_save(data)` (old saves: every order before `objective`) |
| H3 | `scripts/core/save_sanitizer.gd` | `"guide_done": []` in `SHAPE` (a non-list is erased, so the default applies) |
| H4 | `scripts/core/objectives.gd` | `static func step(i) -> Dictionary`: the step as objectives.json defines it, `{}` past the list |
| H5 | `scripts/ui/gather_radial.gd` | `func hex_rect_for(item) -> Rect2`: the hex that gathers `item`; empty while closed or not offered. Fix round 2: the title's slide and the option labels' rects are placed at the end of `_layout()` instead of in `_draw()`, which only draws them, so `label_rects` and `title_box` are this frame's when the finger reads them (a move, no new logic) |
| H6 | `scripts/ui/hunt_hud.gd` | `control_for(id)` (`&"craft"` returns the MENU hex) and `play_covered()` (sheet, bag, craft, atlas, animals, plate, death) |
| H7 | `scripts/player/player_view.gd` | `setup_ui` mounts the finger right after the radial: `GuideFinger.mount(p)`. Every survivor gets it, so labs built on LabKit get it with no LabKit change. |
| H8 | `data/world/objectives.json` | order 1 hint; `"guide": {"creature": ...}` on meat and tame; `_about` names the field |
| H9 | `scripts/ui/world_ui.gd` | fix round 2: `static func covering() -> bool` (the sheet's `_panel` is visible, or the arrival welcome is up, now remembered in `_arrival` when `_show_arrival` builds it) |

`git apply --check` of the patch (regenerated in fix round 2):
- it is what the work tree holds: `git diff` of the 9 files is byte-identical to the patch;
- clean on `claude/mmo-overhaul` @ acc684a6, checked with `git apply --cached --check` against a scratch index of that commit.

## Before / after

All shots are under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/guide/shots/`.
They come from the windowed `guide_lab` on a fresh scratch save (`user://runs/guide_lab`, wiped at launch). I opened every PNG listed here.

**Before** (`before/`, the base with no guide, 1600x900 and 844x390):
- `before_node_*.png`: the first order reads "Gather 3 branches / Tap a tree and pick Branch fr..." and nothing on screen points anywhere. The nearest safe branch tree is 26 m away, off screen to the upper right.
- `before_hex_*.png` and `before_gone_*.png` come from a lab tap on that off-screen tree's projected point. A player cannot make that tap. The radial then piled up over the vitals: a lab artifact, not a game state.

**After** (`r2/<size>_<renderer>_<run>/`, fix round 2, 1600x900 and 844x390, Forward+ and gl_compatibility, 3 runs each). I opened `node`, `hex` and `gone` of run 1 in all four configurations, `levelup` at 1600x900 Forward+ and 844x390 gl_compatibility (and the earlier tuning runs' `levelup`, `beside`), and `node_near`, `next` and `craft` at 844x390 gl_compatibility:
- `node_*.png`: at spawn the tree is off screen to the upper right, and the top-right corner holds the Orders card, the day/night dial, the minimap and CLAIM.
  - At 1600x900 the hand is on the right edge below CLAIM and points up-right; its line leaves the screen at once (0 px along the vitals or the card).
  - At 844x390 it is on the top edge between the vitals and the Orders card and points right, along the card's top (79 px of its line within 20 px of the card). No edge spot does better here; see Review round 2, finding 2.
- `levelup_*.png` (new): a level-up right after spawn. At 1600x900 the stack is top-left and the hand stays on the right edge, off it (`on it=false fit=3`). At 844x390 the banner fills the top edge from x 320 to 662 (the card is hidden under it), the hand stays on it (`fit=2`): the only spot off it, below the minimap, is on CLAIM.
- `node_near_*.png`: after a 3 s walk the tree is on screen; the tip is on its trunk, 0.0 to 5.5 px from the aim point.
- `hex_*.png`: after a real tap the radial is open, mid-walk. At both sizes the hand lies left of the Branch hex, its tip inside the hex, and "Branch Lv. 1" is clear. (At 844x390 gl_compatibility the review's shot had the hand below the hex on the label; that was the stale title and labels plus the tip held at the hex's centre, both fixed.)
- `gone_*.png`: the hex is picked (green dot on the tree's tag), the gather has started and the finger is gone.
- `next_*.png`: order 2, "Pick up 2 stones": the rock is off screen below, the hand is on the bottom edge pointing down.
- `craft_*.png`: order 4: the hand stands above the MENU hex pointing down, the tip on its upper rim, MENU and ANIMALS clear.
- `beside_*.png`: at 844x390 the radial puts the Branch hex mostly on the Orders card; where at least 26 px of it is off the card the tip is on that strip and the hand hangs below, on the label (the radial's layout, Found, not fixed).

In `ui_real_capture_lab` (`uireal9/<size>_<renderer>/`) I opened `levelup`, `busy_levelup` and `charcreate` at 844x390 gl_compatibility:
- `levelup_844x390.png`: the hand is on the LEVEL UP banner's icon, as the review saw. It cannot move off it there (above, and Review round 2, finding 4).
- `busy_levelup_844x390.png`: the same; the toasts on the left edge are clear of it.
- `charcreate_844x390.png`: CREATE YOUR SURVIVOR with no finger.

## Gates (fix round 2: each run for real on the branch head with the hooks patch applied; output quoted)

- **t_guide**: `[t_guide] PASS`, 0 SCRIPT ERROR (rerun on the final code). Everything listed in round 1 still holds (steps 0-10 resolve, step 11 is an explicit none, old saves, the sanitizer, the tree pick, `hand 70 px tall at 844x390, 86 px at 1600x900`, placements, hysteresis, edge clamps, the kept edge spot, `clear_part`, the MENU rim). New in round 2:
  - `the drawn hand never moves faster than GLIDE_MAX`: a finger instance is driven by `_settle` through a glide while its anchor also moves 20 px a frame, for a node key and an edge key. Mutation check: with the cap removed it fails with `(2828 px/s)`.
  - a hand on the level-up banner moves to a clear spot when there is one; with CLAIM below the minimap it stays on the banner rather than move onto CLAIM; with no keep the first spot is a banner spot, not CLAIM;
  - `[t_guide] spawn hand at 844x390: r1 (412.0, 20.0) ran 80 px along the card; without CLAIM (824.0, 232.0), with it (412.0, 20.0)`: without CLAIM the spawn hand goes below the minimap and its line clears the card (the review's suggestion); with CLAIM it keeps the round 1 spot rather than cover CLAIM;
  - where there is room beside the card, `edge_aim` turns the hand up off it within 20 degrees; a clear line keeps the direct angle.
- **guide_lab**: 12 of 12 runs PASS, 3 per size and renderer (1600x900 and 844x390, Forward+ and gl_compatibility), 0 SCRIPT ERROR in each. In round 1's build the review had 3 failures in 8.
  - `finger shown 0 ms after the island's first frame` in all 12 (that frame takes 81-120 ms on Forward+ and 1.4-2.1 s on gl_compatibility).
  - Spawn: `tip on the edge (1576.6, 358.8), finger 0 deg off the tree, its line 0 px along the vitals and the card` at 1600x900; `tip on the edge (408.4, 20.3), finger 0 deg off the tree, its line 79 px along the vitals and the card` and `the best edge spot for a clear line is (412.0, 20.0) (clear=false)` at 844x390.
  - `level-up banner ...: clamped=true on it=false fit=3` at 1600x900; `on it=true fit=2` at 844x390 (never on a HUD control).
  - `tree at ...: tip ..., 0.0 to 5.5 px away` (limit 24).
  - `radial walk: 308-355 frames, 0 with the tip off the Branch hex, survivor moved 4.7-5.2 m; 0 frames on the Branch label where a placement off it fitted` in all 12.
  - The tap at the tip picks Branch and the finger is hidden from the same frame (`picked branch on frame 1097; finger hidden from frame 1097`), stays hidden for the rest of order 1 and after the save and reload; order 2's finger is up 0.22-0.43 s after the order advances, with 0 drops.
  - Hidden under the bag, craft, the menu and skills sheets, a radial on another node, the terrain pick, the pause sheet, the arrival welcome (now through `WorldUI.covering()`), character creation and the creature plate; back after each closes.
  - `craft order twine: tip (48.0, 816.8) on MENU hex ..., over hexes []` (306.8 at 844x390).
  - `beside the tree: finger on the Branch hex 30 of 30 frames` at 1600x900; 17-30 of 30 at 844x390, the rest with under 26 px of the hex off the card.
  - `clamped frames: { ..., "inward": 0, "on_hud": 0, "worst": 25.4 }` (worst 26.4 over all 12).
  - **Motion.** The jump test is now per frame: a jump is a tip move longer than (2000 px/s plus the tap's and the turn's share) times the finger's own frame time (its `_t` step), plus the hex's own move on a hex. Before, it was "over 24 px and over 3000 px/s", which passed at 60 fps and failed at 100. Gate unchanged otherwise: 0 jumps, 0 snaps, at most 1 swap, at most 1 fade, 0 hops.
    - 1600x900, all 6 runs: `walk to the tree: { "jumps": 0, "snaps": 0, "swaps": 0, "hops": 0, "fades": 0 }`; radial walk 0 jumps, 0 swaps, 0 fades (`radial_jumps` 6-17, the radial's own).
    - 844x390, all 6 runs: `walk to the tree: { "jumps": 0, "snaps": 0, "swaps": 1, "hops": 0, "fades": 1 }`, the one fade being the move from the top edge to the right edge (`fade: tip (399.3, 20.7) -> (825.7, 236.4)`); radial walk 0 jumps, 1 swap, 0 fades.
    - next order: 0 of everything in all 12.
- **Every test.** `t_ai`, `t_build`, `t_canim`, `t_combat`, `t_data`, `t_daynight_dial`, `t_guide`, `t_harbour`, `t_iconart`, `t_items`, `t_light`, `t_lighting`, `t_occlude`, `t_player`, `t_save`, `t_server_domain`, `t_srvdom`, `t_structart`, `t_tame`, `t_ui`, `t_uiicons`, `t_w2_skills`, `t_water` and `t_web` all PASS. `t_save` prints only its 5 deliberate SCRIPT ERROR lines; every other test prints 0. `run_all` prints `[tests] PASS`. `tools/smoke.sh --no-import` prints `SMOKE PASS`.
- **ui_real_capture_lab**: `[uireal] PASS` at 1600x900 and 844x390, on Forward+ and gl_compatibility, 0 SCRIPT ERROR each. It reads the radial's `label_rects` and `title_box`, which hook H5 now fills in `_layout`.
- No `--import` was needed: no new `class_name` this round.

## Review round 1

The review found 2 majors and 4 minors. I accept all six; none is wrong. Commits: dd1ab2b0 (the fixes) and cbfd1e8e (a regression the fixes caused at 844x390, caught by the motion gate, below). Every check named here ran in this round; the numbers are in Gates.

| # | Finding | Fix | Check |
|---|---|---|---|
| 1 | major: the finger stayed up and tapped over the terrain pick, the pause menu and the character-creation cards | `GuideFinger._world_covered()` hides it while WorldUI's sheet is up (`_panel.visible`: terrain pick, harbour routes, map, pause), while `ArrivalWelcome` is up, and while a `character_creation` node exists (the HANDS pattern). It is in the finger, so the hooks patch did not change. | guide_lab opens each of the four and expects the finger hidden, then back once it closes: `terrain pick open: finger shown=false`, the same for `pause sheet`, `arrival welcome` and `character creation`, in all 4 runs. `ui_real_capture_lab` `charcreate_*.png` shows no finger. |
| 2 | major: an off-screen target's hand slid inward and tapped the camp tent | The clamped hand stays on the safe-area border: where the edge point is under a HUD block it walks along the border, past the vitals, card and minimap and off the HUD's other controls, never inward. A clamped hand nudges 6 px toward the target instead of tapping. | guide_lab checks every clamped frame: tip within EDGE + nudge + 2 px of the safe border once the glide is over, and the hand off every HUD rect: `clamped frames: { "frames": 363, "inward": 0, "on_hud": 0, "worst": 25.4 }` (844x390 Forward+). t_guide: an edge point under the map and the card walks along the edge; past the map it walks past CLAIM too. Shots `node_*`. |
| 3 | minor: beside the tree at 844x390 the radial put the Branch hex on the Orders card and the finger vanished | The finger aims at the part of the hex clear of the vitals and the card (`clear_part`). | guide_lab `_beside_tree`: `finger on the Branch hex 30 of 30 frames` (844x390 Forward+), `28 of 30 frames (2 with under 26 px of it off the card)` (gl_compatibility). t_guide `clear_part` cases. The radial's ring not avoiding the card is GATHERUI's/CONTROLS', listed under Found, not fixed. |
| 4 | minor: the STICK allowance let the hand cover its own hex's label; my report said the 1600x900 hand was clear of it, and it was not | On a new target the placement is picked afresh (`prefer` is NAN when the key changes), and the hex's own label is kept off like a block wherever any placement allows. | guide_lab counts radial-walk frames where the hand covers the Branch label while another placement would not: `0 frames on the Branch label where a placement off it fitted` in all 4 runs. Shots `hex_*`. |
| 5 | minor: on craft orders the hand lay across the MENU icon and half of ANIMALS | The HUD's other controls are kept off like blocks wherever a placement allows, and the tip sits on the MENU hex's upper rim (30 % of its height up from the middle). | guide_lab `_craft_order`: `craft order twine: tip (48.0, 816.8) on MENU hex ..., over hexes []`. t_guide: with no controls kept off the hand lies along the row (the review's shot); with them it keeps off ANIMALS, tip on the rim. Shots `craft_*`. |
| 6 | minor: the finger rides the radial's hex jumps | No GUIDE change, as the review says. Still handed to CONTROLS/GATHERUI. | guide_lab counts them: `radial_jumps` 13 and 15 at 1600x900 in this round, 1 at 844x390. |

**Regression caught in this round.** The first build of fix 2 failed guide_lab at 844x390 on both renderers: `walk to the tree: the hand moves smoothly over 339 frames (jumps 4, snaps 2, swaps 1, hops 0)`.
- Cause: two clear spots, left of the Orders card on the top edge and below the minimap on the right edge, took turns as the tree's projection moved (CLAIM hides and shows on the walk, which toggles the right-hand spot). Each swap glided across the card, met it, and snapped.
- I dumped the walk's projections and HUD rects frame by frame and replayed `edge_spot` offline to pick the rule: the kept spot (bullets above) leaves one move in that walk, from the top edge to the right edge once the top spot no longer fits.
- That one move would cross the card, so a move that would touch the vitals or the card now cross-fades over 0.25 s instead of snapping. guide_lab counts a cross-fade as a `fade`, not a jump, and allows at most one per phase.
- Now: `walk to the tree: { "frames": 336, "jumps": 0, "snaps": 0, "swaps": 1, "hops": 0, "radial_jumps": 0, "fades": 1 }` at 844x390 Forward+.
- Mutation check: with the kept spot switched off (`kept = INF`), t_guide fails `a clamped hand left of the card stays there rather than swap below the minimap ((824.0, 224.0), kept (824.0, 224.0))` and the quarter-of-the-way check.

## Review round 2

The review found 1 major and 3 minors. I accept all four. Two of them can only be met in part at 844x390, with evidence below. Commits: 900425ba and the commit that carries this report. The checks are in Gates.

| # | Finding | Fix | Check |
|---|---|---|---|
| 1a | major: guide_lab flaky on gl_compatibility; the hand sat on the Branch label for one frame after the ring turned, because the radial set `label_rects` and the final `title_box` in `_draw`, after the finger's `_process` | Hook H5 places the title's slide and the labels at the end of `GatherRadial._layout` (a move: `_draw` only draws them). The finger reads this frame's rects. The finger also tries the tip at points in the middle half of the hex (the centre, then 4 px steps up and down, then a quarter left and right) to find a placement off the label. Without that the review's `hex_844x390.png` case had none: the card is 2 px above the hex, and the only side placement that fits between the card and the label needs the tip 4 px above the centre. | 0 frames on the Branch label where a placement fits, in all 12 runs, with no excused frames. `hex_844x390.png` on both renderers: hand left of the hex, label clear. |
| 1b | major: a move under 24 px on top of a running glide went past 2000 px/s (35 px in 10 ms on the right edge); the lab's px/s test depended on the frame rate | `_settle` caps the drawn anchor's move per frame at `GLIDE_MAX * delta` for every key but a hex. The lab's jump test is per frame against the finger's own frame time (above). I tried the review's other suggestion, easing every 8 px edge step: it dragged the hand across the card's corner at 844x390 (2 fades on the walk, the gate allows 1), so edge steps stay instant, and the cap bounds them. | t_guide `the drawn hand never moves faster than GLIDE_MAX` (fails at 2828 px/s without the cap). guide_lab: 12 of 12 PASS, 0 jumps in every phase. |
| 2 | minor: at 844x390 at spawn the hand sits left of the card pointing along it ("look at your orders") | When the hand first clamps it prefers a spot whose line clears the vitals and the card (at most 16 px of the line within 20 px of them), turning up to 20 degrees through 5-degree steps that all fit. A kept spot does not give way over its line alone: when it did, the spots left of the card and below the minimap took turns again (5 fades on the walk). | t_guide: without CLAIM the spawn hand goes below the minimap and its line clears the card; with room beside the card the hand turns up off it. guide_lab: `its line ... px along the vitals and the card` passes where an edge spot allows. |
| 2, the part not met | | At 844x390 no edge spot meets it for the spawn tree, so the hand keeps the round 1 spot. Evidence: below the minimap is the review's suggestion, but the hand there is on the CLAIM hex at every angle that points at the tree (`fit 1` in the trace). Left of the card, the hand's box (94-107 px wide at 0.9 scale) fills the 114 px between the vitals (x 308) and the card (x 422). A frame-by-frame trace at (396, 20) gave tilt fits `-4:8/3, -3:12/0, -2:18/0, -1:31/3` (steps up: px of line along the card / fit, 0 = on the card). A 20-degree turn fits, but the hand turning to it crosses the card at 10-15 degrees. With such turns allowed, one run cross-faded 5 times on the walk to the tree (the gate allows 1) as the turn followed the tree through those angles. The hand is never shrunk below 64 px, never put on CLAIM or the card, and never slid inward. | `[guide] the best edge spot for a clear line is (412.0, 20.0) (clear=false)` at 844x390 in all 6 runs; `node_844x390.png`. |
| 3 | minor: `_world_covered` reached into WorldUI's private `_i`, `_panel` and an `ArrivalWelcome` node name | Hook H9: `static func covering() -> bool` in world_ui.gd. It also remembers the welcome it builds (`_arrival`), so it no longer depends on the welcome being under WorldUI's own parent. The finger calls `WorldUiScript.covering()`. | guide_lab: hidden under the terrain pick, the pause sheet and the arrival welcome, back after each, in all 12 runs. |
| 4 | minor: the hand drew over the LEVEL UP banner | Level-ups, notices and toasts are soft for every placement (`pick_angle`) and for edge spots. An edge spot on one fits less well than a clear spot but better than one on a HUD control, so the hand never trades the banner for CLAIM. | t_guide banner cases; guide_lab `_level_up` right after spawn: `on it=false fit=3` at 1600x900, `fit=2` at 844x390. |
| 4, the part not met | | At 844x390 the banner covers the top edge from x 320 to 662 (the card is hidden under it), between the vitals and the minimap, so every top-edge spot is on it, and the next clear spot, below the minimap, is on CLAIM. The hand stays on the banner for its 6.5 s. The finger does not hide under a level-up because the spec lists sheets, modals, the plate and the death screen, not passing banners. | `levelup_844x390.png` in both labs. |

## Found, not fixed (other packages own it)

- **The gather radial's hexes jump while the survivor walks.** STATUS already lists "hexes ... jump while walking". The lab now measures it. During the 3 s radial walk the Branch hex jumped:
  - 13 times at 1600x900 Forward+ and 15 times on gl_compatibility in fix round 1 (6 in round 0), up to about 140 px, flipping back and forth between ring turns: `(1129.32, 354.0218) -> (1191.503, 494.7379)`, `(1096.532, 502.4877) -> (1029.802, 362.1337)` and back `(1025.772, 363.1685) -> (1095.589, 481.3021)`;
  - once at 844x390, 25 px: `(614.3423, 163.2059) -> (602.0806, 140.3111)`.

  The cause is `GatherRadial._layout`, which runs `ContextRadial.hex_positions` every frame and turns the ring to clear the plant, its title and the HUD, with no hysteresis. The finger has to stay on the hex, so it jumps with it. The lab counts these frames as `radial_jumps` and does not charge them to the hand.
  CONTROLS ("UI glitching on resource nodes") or GATHERUI should fix this by giving the ring's turn a hysteresis like the hand's. I did not touch it: CONTROLS is running.
- **The gather radial's ring does not keep off the Orders card.** At 844x390, with the survivor beside the tree (where walking to it leaves them), the radial puts the Branch hex half over the card, and the hex draws on top of the card's text (`beside_844x390.png`). The finger now aims at the strip of the hex below the card, so it shows, but the hand then covers most of "Branch Lv. 1": below is the only placement off the card. GATHERUI or CONTROLS should add the Orders card (`HuntHud.drawn_blocks["quest"]`) to the rects the ring turns away from.
- At 844x390 in combat, the CLAIM hex sits on the "End Combat" button (`plate_844x390.png`). This was there before GUIDE.

## Assumptions

- `# ASSUMPTION:` "hostile" means a living wild creature whose AI profile is not `is_herbivore`. Its radius is the leash ring the creature draws while on the survivor (`CreatureBrain.aggro_radius()`).
- `# ASSUMPTION:` with no safe node, the nearest node still gets the finger, because the order needs it.
- The finger is "done" for a gather order when the right hex is picked, not when 3 branches are in the bag. The spec says to hide on the pick.
- Craft orders point at the MENU hex. The HUD has no direct craft button in hud mode (the touch layer's CRAFT button is hidden there), so `control_for(&"craft")` returns `_menu_hex`. The finger hides while the menu sheet is open, as every sheet hides it, so it does not point at the sheet's Craft row.
- Meat points at compsognathus because its hint names them. Deriving it from butcher tables could pick a raptor.
- Station orders point at the station itself. When the station's menu opens, the finger keeps pointing at the station and does not move to the station's CRAFT hex.
- The motion numbers (glide 12/s capped at 2000 px/s, turn 10 rad/s, margins 6 and 18 px, 20 % label hysteresis, a 0.25 s cross-fade, an edge spot kept up to a quarter of the way round farther, a 6 px nudge at 0.7 Hz, and from round 2 a clamped line within 20 px of the vitals or the card for at most 16 px, a turn of at most 20 degrees in 5-degree steps, tip points 4 px apart in the hex) are my picks. The owner's rule names no numbers.

## Not done, and what the next agent needs

- I did not run the craft, station or creature targets live in a lab (orders 3-10). t_guide covers their resolution only.
- I did not check the finger in portrait (390x844), on the web export or on a device.
- At 844x390, beside the tree, the hand on the Branch hex covers most of its "Branch Lv. 1" label (the radial put the hex on the card; see Found, not fixed). Mid-walk at 844x390 the label is clear.
- At 844x390 the spawn hand still points along the Orders card, and it sits on the level-up banner while one shows (Review round 2, the parts not met). Moving CLAIM, or a smaller hand on phones, would open a spot; both are outside this package.
- I did not measure the finger's frame cost. A clamped hand with no clear spot scans the whole border once when it first clamps; kept spots bound the scan after that.
- During a cross-fade the two half-faded hands show their ink outline through the white for 0.25 s. I judged that from the code, not from a frame capture: no shot lands inside a fade.
- To integrate: apply the hooks patch, then run `--import` once, because two new `class_name` files are on the branch.
- Credits spent: none.
