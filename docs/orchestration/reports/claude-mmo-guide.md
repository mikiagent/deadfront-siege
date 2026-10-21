# GUIDE (claude/mmo-guide): the walkthrough finger

Scope: durango-prompts 22. The owner wrote: "notice the game ui and how the resource gathering looks. The finger icon is a walkthrough guide".
Before this package the game had no tutorial pointer or hint system on any branch. The standing orders
(`data/world/objectives.json`, `scripts/core/objectives.gd`) only showed text on the Orders card.

Branch head: see `git log claude/mmo-guide`. `claude/mmo-overhaul` @ 809be2e8 (HUD-DAYNIGHT, W2-DATA sync) is merged into the branch,
and every gate below ran on that merged tree with the hooks patch applied. Fix round 1 (the review's 2 majors and 4 minors) is
in the section "Review round 1" below; the bullets here describe the branch as it is now.

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
  - Along the edge it also keeps off the HUD's other controls (CLAIM, HANDS, the day/night dial, the hex row and their captions), with at most 20 px of the hand off the screen. Blocks that come and go (notices, toasts, level-ups, name tags) do not move it. Where no spot is clear of those, the nearest spot off the vitals, the card and the minimap is used.
  - It keeps last frame's edge spot while that spot is still clear and at most a quarter of the way round the edge farther than the nearest clear spot. A clear spot on the line from the centre still wins. Without this, at 844x390 the spot left of the card and the spot below the minimap took turns as the tree moved, and the hand swapped across the screen 3 times on the walk to the tree.
  - A clamped hand does not tap. It nudges 6 px toward the target 0.7 times a second, with no press squash, so it reads as "this way", not "tap here".
- **Where the hand sits.** Eight placements are tried: below-right, below-left, above-right, above-left, then square-on.
  - The hand never goes on the vitals or the Orders card. If no placement keeps it off them, the finger hides.
  - The hand prefers the placement that covers the least of the minimap and of the open radial's labels and title. These soft blocks never hide the finger.
  - On a gather hex it keeps off that hex's own label wherever any placement allows. On a craft order it keeps off the HUD's other controls wherever any placement allows, and its tip sits on the MENU hex's upper rim, so the icon stays in sight.
  - The hand's footprint is its outline at both ends of the tap plus the drop shadow. Before, it was that box grown 10 px on every side, which also kept it 10 px off blocks in front of the tip.
- **Motion** (new this run, for the owner's 2026-10-21 rule "watch out for glitchy movement of UI"):
  - A new target, or an anchor that moves more than 24 px in a frame, makes the hand glide over from where it was drawn instead of jumping. The glide is an ease-out capped at 2000 px/s.
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
  - No screen the HUD does not own is up (`GuideFinger._world_covered`, in the finger, so no new hook): WorldUI's sheet (terrain pick, harbour routes, map, pause), its arrival welcome (`ArrivalWelcome`), or character creation (the `character_creation` group, as HANDS checks it). The finger's layer 66 is above WorldUI (40) and character creation (60).
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

## Hooks (`docs/orchestration/reports/claude-mmo-guide-hooks.patch`, 8 files, +39 -3)

| # | File | Change |
|---|---|---|
| H1 | `scripts/core/world.gd` | `var guide_done: PackedStringArray`; `start_new` clears it |
| H2 | `scripts/core/save_game.gd` | writes `"guide_done"`; `_apply` reads it with `Guide.done_from_save(data)` (old saves: every order before `objective`) |
| H3 | `scripts/core/save_sanitizer.gd` | `"guide_done": []` in `SHAPE` (a non-list is erased, so the default applies) |
| H4 | `scripts/core/objectives.gd` | `static func step(i) -> Dictionary`: the step as objectives.json defines it, `{}` past the list |
| H5 | `scripts/ui/gather_radial.gd` | `func hex_rect_for(item) -> Rect2`: the hex that gathers `item`; empty while closed or not offered |
| H6 | `scripts/ui/hunt_hud.gd` | `control_for(id)` (`&"craft"` returns the MENU hex) and `play_covered()` (sheet, bag, craft, atlas, animals, plate, death) |
| H7 | `scripts/player/player_view.gd` | `setup_ui` mounts the finger right after the radial: `GuideFinger.mount(p)`. Every survivor gets it, so labs built on LabKit get it with no LabKit change. |
| H8 | `data/world/objectives.json` | order 1 hint; `"guide": {"creature": ...}` on meat and tame; `_about` names the field |

`git apply --check` of the patch (regenerated after the 809be2e8 merge, so its index lines match the current base; fix round 1 changed no hook):
- it is what the work tree holds: `git diff` of the 8 files is byte-identical to the patch, and `git apply -R --check` is clean;
- clean on `claude/mmo-overhaul` @ 809be2e8, checked against a scratch index of that commit.

## Before / after

All shots are under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/guide/shots/`.
They come from the windowed `guide_lab` on a fresh scratch save (`user://runs/guide_lab`, wiped at launch). I opened every PNG listed here.

**Before** (`before/`, the base with no guide, 1600x900 and 844x390):
- `before_node_*.png`: the first order reads "Gather 3 branches / Tap a tree and pick Branch fr..." and nothing on screen points anywhere. The nearest safe branch tree is 26 m away, off screen to the upper right.
- `before_hex_*.png` and `before_gone_*.png` come from a lab tap on that off-screen tree's projected point. A player cannot make that tap. The radial then piled up over the vitals: a lab artifact, not a game state.

**After** (`r1b/<size>_<renderer>/`, fix round 1, 1600x900 and 844x390, Forward+ and gl_compatibility, 32 PNGs, all opened):
- `node_*.png`: at spawn the tree is off screen to the upper right, and the top-right corner holds the Orders card, the day/night dial, the minimap and CLAIM.
  - At 1600x900 the hand is on the right edge below CLAIM and points up-right. Before fix round 1 it sat 190 px in from the edge on the camp tent's roof.
  - At 844x390 it is on the top edge between the vitals and the Orders card and points right. Before, it sat on open grass beside the survivor.
- `node_near_*.png`: after a 3 s walk the tree is on screen. The tip is on its trunk, 7.5 to 7.8 px from the aim point, with the hand to the left pointing right.
- `hex_*.png`: after a real tap the radial is open and the tip is inside the Branch hex, mid-walk. At both sizes the hand lies left of the hex and "Branch Lv. 1" is clear. (The review was right that the earlier 1600x900 shot hid the label down to "...n Lv. 1"; my old report said it was clear.)
- `gone_*.png`: the hex is picked (green dot on the tree's tag), the gather has started and the finger is gone.
- `next_*.png`: order 2, "Pick up 2 stones". The nearest rock is off screen below, so the hand sits on the bottom edge and points down at it.
- `plate_*.png`: a compy hunt is up with the creature plate showing, and no finger.
- `craft_*.png` (new): order 4, "Twist fibre into twine". The hand stands above the MENU hex pointing down, its tip on the hex's upper rim. The MENU icon and the ANIMALS hex are clear.
- `beside_*.png` (new): the survivor stands next to the tree and the radial is open.
  - At 1600x900 the hand is left of the Branch hex and the label is clear.
  - At 844x390 the radial puts the Branch hex half over the Orders card. The tip is on the strip of the hex below the card and the hand hangs below it, over most of the "Branch Lv. 1" label: below is the only placement off the card. Before fix round 1 the finger vanished here.

In `ui_real_capture_lab` (`uireal8/<size>_<renderer>/`), I opened `charcreate_*` in all 4 runs, `hud`, `busy` and `camp_bonfire` at 1600x900 Forward+ and 844x390 Forward+, `hud_844x390` on gl_compatibility, and `radial`, `sheet_menu` and `resize_other_844x390` at 1600x900 Forward+:
- `charcreate_*.png`: CREATE YOUR SURVIVOR with no finger. Before, it tapped the Office Worker card at 844x390 and the Technician card at 1600x900.
- `hud_*.png`, `camp_bonfire_*.png`, `busy_*.png`: the hand is on the screen edge (right edge below CLAIM or between the minimap and COOK, or the top edge left of the Orders card), pointing toward the off-screen tree, and taps nothing.
- `resize_other_844x390.png`: after the resize the hand is on the top edge between the vitals and the card. Before, it sat on the "Workbench" label.
- `radial_*.png` (a bush radial, another node) and `sheet_menu_*.png`: no finger.

## Gates (fix round 1: each run for real on the branch head with the hooks patch applied; output quoted)

- **t_guide**: `[t_guide] PASS`, 0 SCRIPT ERROR. It resolves steps 0-10 (the table above, printed as `[t_guide] step 0 branches -> { "kind": "gather", "item": "branch" }` up to `step 10 tame -> { "kind": "creature", "id": "zebraceratops" }`) and checks:
  - step 11 resolves to an explicit none, and `step()` past the list is empty;
  - the order 1 hint does not say "wheel";
  - old-save defaults, kept strings, the forged non-list dropped by the sanitizer, and the JSON shape;
  - the tree pick: safe beats near, no safe tree falls back to the nearest, depleted trees are skipped, the last tree is kept (no hopping) or dropped;
  - the hand is at least 64 px tall: `[t_guide] hand 70 px tall at 844x390, 86 px at 1600x900`;
  - placements stay off the vitals and the card, including the MENU and CLAIM corners. A target on the vitals hides the finger. Soft labels are avoided but never hide the finger;
  - placement hysteresis: the current placement stays while it fits, gives way when it runs off screen or onto a label, and does not flip back while the other side is 10 px from a block (mutation check from round 0: with both margins at 0 this fails);
  - edge clamps, including the mirrored behind-camera case;
  - fix round 1: an edge point under the map and the card walks along the edge; past the map it walks past CLAIM too; a clear edge point is kept as it is; the kept edge spot left of the card does not swap below the minimap, stays up to a quarter of the way round farther and no more, and loses to a clear edge point (mutation check above); a clamped hand nudges less than a tap; `clear_part` for a hex half under the card, wholly under it and clear of it; the MENU finger keeps off ANIMALS with its tip on the rim.
- **guide_lab**: `[guide] PASS` at 1600x900 and 844x390 on Forward+ and gl_compatibility, with 0 SCRIPT ERROR each. Lines from 844x390 Forward+ unless marked:
  - `[guide] finger shown 0 ms after the island's first frame (that frame took 99 ms; ...)`. The finger is up on the first frame the island draws. On gl_compatibility that first frame alone takes 1.9-2.0 s of shader compiles, finger or not, so the lab times from that frame.
  - `[guide] tree off screen at (973.5433, -22.55316): tip on the edge (408.4893, 20.26604), finger 0 deg off the tree`. At 1600x900: `tip on the edge (1576.583, 358.8218)`.
  - `[guide] tree at (599.4291, 184.0959): tip (591.7284, 184.0773), 7.7 px away`. The limit is 24 px. The other runs: 7.5 to 7.8 px.
  - `[guide] radial walk: 341 frames, 0 with the tip off the Branch hex, survivor moved 5.2 m; 0 frames on the Branch label where a placement off it fitted`. The window is 3 s of real taps and a sideways walk. The other runs: 274, 273 and 320 frames, all with 0 off and 0 on the label.
  - `[guide] tap at (536.2241, 139.9441) picked branch on frame 910; finger hidden from frame 910`. This is a real mouse press and release at the drawn tip, through `Input.parse_input_event`.
  - It stays hidden for the rest of order 1 (0 frames shown over 2 s). The save holds `guide_done ["branches"]`.
  - `[guide] reloaded: order 0 guide_done=["branches"]` (`SaveGame.load_now`), with 0 frames shown over 1.5 s after that.
  - The next order's finger is on a rock 0.09-0.41 s after the order advances, with 0 drops over 60 frames.
  - The finger is hidden under the bag, craft, the menu sheet, the skills sheet, a radial open on another node, the terrain pick, the pause sheet, the arrival welcome, character creation and the creature plate. It returns when each closes; the plate case only checks hidden.
  - `[guide] craft order twine: tip (48.00014, 306.8) on MENU hex ..., over hexes []`.
  - `[guide] beside the tree: finger on the Branch hex 30 of 30 frames`; on 844x390 gl_compatibility `28 of 30 frames (2 with under 26 px of it off the card)`.
  - `[guide] clamped frames: { "frames": 363, "inward": 0, "on_hud": 0, "worst": 25.4 }`. Worst over the other runs: 25.1, 26.4 and 25.4 px from the safe-area border (EDGE 20 plus the nudge).
  - **Motion**, measured frame by frame over the walk to the tree, the 3 s radial walk and the next order's 60 frames:
    - jump: the tip moved more than 24 px at more than 3000 px/s;
    - snap: the hand turned more than 30 degrees at more than 12 rad/s;
    - swap: a new placement for the same target;
    - fade (new): a cross-fade to a new spot where a glide would cross the vitals or the card;
    - hop: a new target.

    The gate is 0 jumps, 0 snaps, at most 1 swap, at most 1 fade and 0 hops. All four runs pass:
    - 844x390: `walk to the tree: { "frames": 336, "jumps": 0, "snaps": 0, "swaps": 1, "hops": 0, "radial_jumps": 0, "fades": 1 }`. The fade is the one move from the top edge to the right edge (`fade: tip (399.3186, 19.39745) -> (825.7068, 236.3287)`). The swap happens at the tree, under the Orders card's corner.
    - 1600x900: `walk to the tree: { "frames": 320, "jumps": 0, "snaps": 0, "swaps": 0, "hops": 0, "radial_jumps": 0, "fades": 0 }`.
    - `radial walk`: 0 jumps, 0 snaps, 0 or 1 swap, 0 fades in every run.
- **Every test.** `t_ai`, `t_build`, `t_canim`, `t_combat`, `t_data`, `t_daynight_dial`, `t_guide`, `t_harbour`, `t_iconart`, `t_items`, `t_light`, `t_lighting`, `t_occlude`, `t_player`, `t_save`, `t_server_domain`, `t_srvdom`, `t_structart`, `t_tame`, `t_ui`, `t_uiicons`, `t_w2_skills`, `t_water` and `t_web` all PASS. `t_save` prints only its 5 deliberate SCRIPT ERROR lines (the same ones as in round 0); every other test prints 0. `run_all` prints `[tests] PASS`. `tools/smoke.sh --no-import` prints `SMOKE PASS`.
- **ui_real_capture_lab**: `[uireal] PASS` at 1600x900 and 844x390, on Forward+ and gl_compatibility, with 0 SCRIPT ERROR each.
- No `--import` was needed in this round: no new `class_name`.

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
- The motion numbers (glide 12/s capped at 2000 px/s, turn 10 rad/s, margins 6 and 18 px, 20 % label hysteresis, a 0.25 s cross-fade, an edge spot kept up to a quarter of the way round farther, a 6 px nudge at 0.7 Hz) are my picks. The owner's rule names no numbers.

## Not done, and what the next agent needs

- I did not run the craft, station or creature targets live in a lab (orders 3-10). t_guide covers their resolution only.
- I did not check the finger in portrait (390x844), on the web export or on a device.
- At 844x390, beside the tree, the hand on the Branch hex covers most of its "Branch Lv. 1" label (the radial put the hex on the card; see Found, not fixed). Mid-walk at 844x390 the label is clear.
- During a cross-fade the two half-faded hands show their ink outline through the white for 0.25 s. I judged that from the code, not from a frame capture: no shot lands inside a fade.
- To integrate: apply the hooks patch, then run `--import` once, because two new `class_name` files are on the branch.
- Credits spent: none.
