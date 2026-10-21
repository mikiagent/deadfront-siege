# GUIDE (claude/mmo-guide): the walkthrough finger

Scope: durango-prompts 22. The owner wrote: "notice the game ui and how the resource gathering looks. The finger icon is a walkthrough guide".
Before this package the game had no tutorial pointer or hint system on any branch. The standing orders
(`data/world/objectives.json`, `scripts/core/objectives.gd`) only showed text on the Orders card.

Branch head: see `git log claude/mmo-guide`. `claude/mmo-overhaul` @ ddaab662 (WATER, specs 23-24) is merged into the branch,
and every gate below ran on that merged tree with the hooks patch applied.

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
  - The radial re-solves its layout every frame. The finger re-reads the rect every frame and runs at `process_priority` 100, after the radial and the camera.
- **Off-screen, behind-camera and hidden targets.**
  - The finger clamps to the safe-area edge (20 px in), where the line from the centre to `cam.unproject_position` leaves the screen. The projection is mirrored when the target is behind the camera.
  - A target under a HUD block (vitals, Orders card, minimap) counts as hidden in the same way. Before this run, the finger at 844x390 pointed at a tree under the minimap.
  - The finger points out along that line. Where the hand would land on the vitals, the Orders card or the minimap, it slides in along the same line in 4 px steps until it clears.
- **Where the hand sits.** Eight placements are tried: below-right, below-left, above-right, above-left, then square-on.
  - The hand never goes on the vitals or the Orders card. If no placement keeps it off them, the finger hides.
  - The hand prefers the placement that covers the least of the minimap and of the open radial's labels and title. These soft blocks never hide the finger.
- **Motion** (new this run, for the owner's 2026-10-21 rule "watch out for glitchy movement of UI"):
  - A new target, or an anchor that moves more than 24 px in a frame, makes the hand glide over from where it was drawn instead of jumping. The glide is an ease-out capped at 2000 px/s.
  - A new placement turns the hand at 10 rad/s instead of snapping it round.
  - The current placement stays while it covers at most 20 % of the hand's area more labels than the best one. It gives way 6 px before it would touch a HUD block or the screen edge. Another placement takes over only when it is 18 px clear. This stops the flip-flop the lab caught at 844x390, where the hand swapped sides 3 times in 3 s beside the Orders card.
  - On a gather hex the tip tracks the hex exactly, with no glide, because the gate wants the tip inside the hex from the frame the radial opens.
  - If an eased hand would touch the vitals or the card, it snaps to its final place instead. The "never on them" rule wins over smoothness.
- **When it shows.** All of these must hold:
  - The current order is not done.
  - Its id is not in `World.guide_done`.
  - A target resolves.
  - `HuntHud.play_covered()` is false. That covers a sheet (menu, build, skills), the bag, craft, the atlas, the animal screen, the creature plate and the death screen.
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

`git apply --check` of the patch (regenerated after the merge, so its index lines match the current base):
- clean on the branch;
- clean on `claude/mmo-overhaul` @ ddaab662, checked against a scratch index of that commit.

## Before / after

All shots are under `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/guide/shots/`.
They come from the windowed `guide_lab` on a fresh scratch save (`user://runs/guide_lab`, wiped at launch). I opened every PNG listed here.

**Before** (`before/`, the base with no guide, 1600x900 and 844x390):
- `before_node_*.png`: the first order reads "Gather 3 branches / Tap a tree and pick Branch fr..." and nothing on screen points anywhere. The nearest safe branch tree is 26 m away, off screen to the upper right.
- `before_hex_*.png` and `before_gone_*.png` come from a lab tap on that off-screen tree's projected point. A player cannot make that tap. The radial then piled up over the vitals: a lab artifact, not a game state.

**After** (`final5/<size>_<renderer>/`, 1600x900 and 844x390, Forward+ and gl_compatibility, 24 PNGs):
- `node_*.png`: at spawn the tree is off screen.
  - At 1600x900 the hand sits on the right edge over the camp tent and points up-right at it.
  - At 844x390 the edge would be the minimap, so the hand slid in along the line, clear of the minimap and the Orders card. It sits just right of the survivor and points up-right.
- `node_near_*.png`: after a 3 s walk the tree is on screen. The tip is on its trunk, 7.6 to 8.1 px from the aim point, with the hand to the left pointing right.
- `hex_*.png`: after a real tap the radial is open and the tip is inside the Branch hex, mid-walk.
  - At 1600x900 the hand lies left of the hex, clear of "Branch Lv. 1" and the other labels.
  - At 844x390 it lies below the hex and covers most of the "Branch Lv. 1" label. Every placement there touches a label or the card, and this one covers least.
- `gone_*.png`: the hex is picked (green dot on the tree's tag), the gather has started and the finger is gone.
- `next_*.png`: order 2, "Pick up 2 stones". The nearest rock is off screen below, so the hand sits on the bottom edge and points down at it.
- `plate_*.png`: a compy hunt is up with the creature plate showing, and no finger.

In `ui_real_capture_lab` (`uireal6/`), `hud_*.png` shows the finger on the edge pointing at the off-screen tree. `radial_*.png` shows a bush radial with no finger, because the radial is open on another node.

## Gates (each run for real in this run, on the merged tree; output quoted)

- **t_guide**: `[t_guide] PASS`. It resolves steps 0-10 (the table above, printed as `[t_guide] step 0 branches -> { "kind": "gather", "item": "branch" }` up to `step 10 tame -> { "kind": "creature", "id": "zebraceratops" }`) and checks:
  - step 11 resolves to an explicit none, and `step()` past the list is empty;
  - the order 1 hint does not say "wheel";
  - old-save defaults, kept strings, the forged non-list dropped by the sanitizer, and the JSON shape;
  - the tree pick: safe beats near, no safe tree falls back to the nearest, depleted trees are skipped, the last tree is kept (no hopping) or dropped;
  - the hand is at least 64 px tall: `[t_guide] hand 70 px tall at 844x390, 86 px at 1600x900`;
  - placements stay off the vitals and the card, including the MENU and CLAIM corners. A target on the vitals hides the finger. Soft labels are avoided but never hide the finger;
  - hysteresis (new): the current placement stays while it fits, gives way when it runs off screen or onto a label, and does not flip back while the other side is 10 px from a block. Mutation check: with both margins set to 0 this last check fails (`FAIL a hand moved off a side does not flip back ... (-0.5236)`);
  - edge clamps, including the mirrored behind-camera case.
- **guide_lab**: `[guide] PASS` at 1600x900 and 844x390 on Forward+ and gl_compatibility, with 0 SCRIPT ERROR each. Lines from 844x390 gl_compatibility unless marked:
  - `[guide] finger shown 0 ms after the island's first frame (that frame took 1232 ms; ...)`. The finger is up on the first frame the island draws. On gl_compatibility the first frame alone takes 1.2-1.3 s of shader compiles, finger or not, so the lab times from that frame.
  - `[guide] tree off screen at (973.5433, -22.55316): tip on the edge (558.075, 141.3272), finger 0 deg off the tree`
  - `[guide] tree at (599.5232, 184.0518): tip (591.9187, 184.0164), 7.6 px away`. The limit is 24 px.
  - `[guide] radial walk: 400 frames, 0 with the tip off the Branch hex, survivor moved 5.2 m`. The window is 3 s of real taps and a sideways walk. The other runs show 345, 388 and 356 frames, all with 0 off.
  - `[guide] tap at (545.1741, 148.749) picked branch on frame 1118; finger hidden from frame 1118`. This is a real mouse press and release at the drawn tip, through `Input.parse_input_event`.
  - It stays hidden for the rest of order 1 (0 frames shown over 2 s). The save holds `guide_done ["branches"]`.
  - `[guide] reloaded: order 0 guide_done=["branches"]` (`SaveGame.load_now`), with 0 frames shown over 1.5 s after that.
  - The next order's finger is on a rock 0.07-0.37 s after the order advances, with 0 drops over 60 frames.
  - The finger is hidden under the bag, craft, the menu sheet, the skills sheet, a radial open on another node and the creature plate. It returns when each closes; the plate case only checks hidden.
  - **Motion (new)**, measured frame by frame over the walk to the tree, the 3 s radial walk and the next order's 60 frames:
    - jump: the tip moved more than 24 px at more than 3000 px/s;
    - snap: the hand turned more than 30 degrees at more than 12 rad/s;
    - swap: a new placement for the same target;
    - hop: a new target.

    The gate is 0 jumps, 0 snaps, at most 1 swap and 0 hops. All four runs pass:
    - `walk to the tree: { "frames": 444, "jumps": 0, "snaps": 0, "swaps": 1, "hops": 0, ... }` at 844x390. The one swap happens as the tree passes under the Orders card's corner: the hand moves from below the trunk to its left, turning at the eased rate. At 1600x900 there are 0 swaps.
    - `radial walk: { "frames": 398, "jumps": 0, "snaps": 0, "swaps": 0, "hops": 0, "radial_jumps": 1 }`.
    - Mutation check (on the first easing commit, c6a13d4f): with the turn and the glide made instant, 1600x900 Forward+ fails with `walk to the tree jump: ... (75 px in 8 ms)`.
    - Before the margin and hidden-target fixes, the first final run failed at 844x390 on both renderers: `jumps 1, swaps 2` on the walk, `snaps 2, swaps 3` on the radial walk.
- **Every test.** `t_ai`, `t_build`, `t_canim`, `t_combat`, `t_data`, `t_guide`, `t_harbour`, `t_iconart`, `t_items`, `t_light`, `t_lighting`, `t_occlude`, `t_player`, `t_save`, `t_server_domain`, `t_srvdom`, `t_structart`, `t_tame`, `t_ui`, `t_uiicons`, `t_w2_skills`, `t_water` and `t_web` all PASS. `t_save` prints only its 5 deliberate SCRIPT ERROR lines; every other test prints 0. `run_all` prints `[tests] PASS`. `tools/smoke.sh --no-import` prints `SMOKE PASS`.
- **ui_real_capture_lab**: `[uireal] PASS` at 1600x900 and 844x390, on Forward+ and gl_compatibility, with 0 SCRIPT ERROR each.
- `--import` ran once after the merge: WATER's new `class_name WaterAccess` was missing from the cloned cache.

## Found, not fixed (other packages own it)

- **The gather radial's hexes jump while the survivor walks.** STATUS already lists "hexes ... jump while walking". The lab now measures it. During the 3 s radial walk the Branch hex jumped:
  - 6 times at 1600x900 on both renderers, about 140 px each time, flipping back and forth between two ring turns: `(1124.973, 359.4391) -> (1196.418, 477.1123)` and back `(1165.138, 483.3455) -> (1091.791, 366.0503)`;
  - once at 844x390, 25 px: `(666.4307, 162.3801) -> (655.1109, 139.547)`.

  The cause is `GatherRadial._layout`, which runs `ContextRadial.hex_positions` every frame and turns the ring to clear the plant, its title and the HUD, with no hysteresis. The finger has to stay on the hex, so it jumps with it. The lab counts these frames as `radial_jumps` and does not charge them to the hand.
  CONTROLS ("UI glitching on resource nodes") or GATHERUI should fix this by giving the ring's turn a hysteresis like the hand's. I did not touch it: CONTROLS is running.
- At 844x390 in combat, the CLAIM hex sits on the "End Combat" button (`plate_844x390.png`). This was there before GUIDE.

## Assumptions

- `# ASSUMPTION:` "hostile" means a living wild creature whose AI profile is not `is_herbivore`. Its radius is the leash ring the creature draws while on the survivor (`CreatureBrain.aggro_radius()`).
- `# ASSUMPTION:` with no safe node, the nearest node still gets the finger, because the order needs it.
- The finger is "done" for a gather order when the right hex is picked, not when 3 branches are in the bag. The spec says to hide on the pick.
- Craft orders point at the MENU hex. The HUD has no direct craft button in hud mode (the touch layer's CRAFT button is hidden there), so `control_for(&"craft")` returns `_menu_hex`. The finger hides while the menu sheet is open, as every sheet hides it, so it does not point at the sheet's Craft row.
- Meat points at compsognathus because its hint names them. Deriving it from butcher tables could pick a raptor.
- Station orders point at the station itself. When the station's menu opens, the finger keeps pointing at the station and does not move to the station's CRAFT hex.
- The motion numbers (glide 12/s capped at 2000 px/s, turn 10 rad/s, margins 6 and 18 px, 20 % label hysteresis) are my picks. The owner's rule names no numbers.

## Not done, and what the next agent needs

- I did not run the craft, station or creature targets live in a lab (orders 3-10). t_guide covers their resolution only.
- I did not check the finger in portrait (390x844), on the web export or on a device.
- At 844x390 the hand on the Branch hex covers most of its "Branch Lv. 1" label. No placement there is free of labels and the card.
- To integrate: apply the hooks patch, then run `--import` once, because two new `class_name` files are on the branch.
- Credits spent: none.
