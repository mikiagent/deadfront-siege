# W1-UI report (claude, branch claude/mmo-w1-ui)

This pass's logs and screenshots are in the scratchpad, under
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1ui-r8/`.
Paths below are relative to that folder: `final/` holds the acceptance runs and `mut/` the mutation runs.
Review 7's pass is under `../w1ui-r7/`, review 6's under `../w1ui-r6/`. The reviewer's evidence is under `../finish-review/ui/r2/`.

The code is commit 9c26af7. Review 8 is 12bcf11 (merge), 12dc802, c6de7dc, a362f72 and 9c26af7 (which only adds
`# ASSUMPTION:` comments). This report is the only commit after it.

## Status

`claude/mmo-overhaul` moved (W1-STRUCTART merged, plus the 2026-10-20 rulings). I merged it with a real merge: 12bcf11. There were no conflicts.
`git log HEAD..claude/mmo-overhaul` is empty after it.

The real-scene gate now checks the HUD in five more states: the menu sheet, the build sheet, a level-up, a bonded
pet out, and a hunt with the pet out. On the review-7 code it fails at 844x390 with 44 FAIL lines (see `mut/`). On this branch it prints
`[uireal] PASS` and exits 0 at all eight runs (1600x900, 844x390, 667x375 and 390x844, each in Forward+ and gl_compatibility).

## Review 8 findings and what changed

| # | Finding | What I did | Check that catches it |
|---|---|---|---|
| 1 | Blocker: at 844x390 the MENU sheet is 470 px tall and runs 192 px off the top | The sheet has a pinned header (title and Close) and a `ScrollContainer` of rows (`SheetRows`). `HuntHud._fit_sheet` caps the rows at the room between the top of the view and the rail, so anything past that scrolls. On a landscape phone the rows sit in two columns (150x56 buttons, 16 px text), so the menu fits without a scroll. The sheet hangs from the vitals' corner and covers the whole vitals block, opaque. When it stood on the rail, it covered only half the vitals | Lab `_check_sheet` for menu and build. It checks that the sheet, its title and Close are inside the view, Close is at least 56 px tall and pinned outside the rows, every row is fully shown or the rows scroll (the menu must show all 5), and the vitals are either clear of the sheet or covered whole by an opaque sheet. Passing at 844x390: `[uireal] sheet menu [P: (8.0, 6.0), S: (336.0, 272.0)]: 5/5 rows fully shown, rows scroll=false`. On the reviewed layout: `[uireal] FAIL sheet menu [P: (16.0, -136.0), S: (328.0, 420.0)] inside the 844x390 view`, plus Close and the title outside the view |
| 2 | Blocker: HANDS covers both sheets' Close | `HuntHud.sheet_open()` is true while a HUD sheet or the skills sheet is open. `HeldItemSlot` hides while it is true, and so do the creature plates, which are on canvas layer 58, also above the HUD. `_refresh_context` moves an open sheet back to the top when it adds a context hex after it | Lab: `sheet <kind>: HANDS is hidden or off the sheet`, `creature plates hide while it is open`, and no HUD child added after the sheet may overlap it. With HANDS never hiding: `[uireal] FAIL sheet menu: HANDS is hidden or off the sheet ([P: (238.0, 196.0), S: (64.0, 64.0)])`. With the plates never hiding: `FAIL sheet menu: creature plates hide while it is open` |
| 3 | Blocker: the whistle hexes sit on the minimap and GUARD runs off the top | Landscape phone: SIC, HEEL and GUARD sit in a row under the vitals (`_layout_landscape_phone`). Portrait: a row over the quick-food row. Desktop: the column moved 12 px up, so SIC's caption clears HANDS (the new gate caught that 4 px overlap at 1600x900). `UiTokens.hud_reserved` has a new sixth landscape zone for the whistle row, so radials keep off it | Lab `pet_out` state: summons a bonded velociraptor, needs three whistles, then runs the overlap and in-view check on every control and drawn block. `[uireal] pet out: pets=1 whistles=3` at all 8 runs. Reviewed placement: `[uireal] FAIL pet_out: GUARD#13 [P: (772.02, -26.0), ...] inside the 844x390 view` and `... Minimap#0 ... overlaps SIC#9`. t_ui: `landscape HUD zones cover the whistle row under the vitals` |
| 4 | Blocker: in combat, End Combat sits on ROLL and SIC, and the target bar runs across the vitals and the quest card | Landscape phone: End Combat (154x56) goes under the map text, where the claim and context hexes stand outside a fight (they hide in one). The four skills sit in one row along the bottom right. Auto and Feed go above the NET/TACKLE seam, and the stance text goes left of NET. The target plate goes in the centre band between the vitals and the minimap, and the quest card gives way while a plate or the level-up banner shows (`_centre_band`). Portrait got its own layout too (`_layout_portrait`): its desktop cluster ran off the left edge and onto the rail. Desktop: Auto moved off ROLL's caption, and the stance text, which ran 2 px past the bottom, now sits on the bottom edge. The new gate caught both at 1600x900 | Lab `combat` state: `hunt.start` on a wild creature with statuses, pet still out. It needs the plate and End Combat, then checks every control and drawn block (`HuntHud.drawn_blocks` now records the plate). 844x390 blocks: `@Button@160#9=674,230 154x56 NET#10=522,294 ... ROLL#16=762,294 ... plate=320,10 342x104`. Reviewed placement: `FAIL combat: @Button@160#9 [P: (644.0, 163.8), ...] overlaps SIC#19`, `FAIL combat: vitals ... overlaps plate [P: (162.0, 10.0), S: (520.0, 104.0)]`, `... quest ... overlaps plate` |
| 5 | Blocker: the level-up banner's 13 lines run over the rail and off the bottom | On phones (landscape and portrait) the banner is one box in the centre band: `Lv. N  LEVEL UP`, the title line, and one stat line (`Will +6 · other stats +5 · Skill points 0`). If a target plate shows, the box sits under it. The desktop keeps its stack. I dropped the `+5  level` pickup toast, which read as five levels gained and sat on the banner | Lab `levelup` state: `_on_level_up(4)` (World is untouched), then the banner must be drawn and checked like every other block. Reviewed stack: `[uireal] FAIL levelup: levelup [P: (30.0, 120.0), S: (247.0, 380.0)] inside the 844x390 view` and overlaps with all four rail hexes and HANDS |
| 6 | Major: the gate only checks the idle HUD | Added states 1-5 above. `hud_blocks` no longer copies hunt_hud's geometry. It reads `HuntHud.drawn_blocks`, which `_draw` fills with what it paints: vitals, quest, map_title, map_text, statuses, level, plate, levelup. That removes the mirror assumption | The mutation run: all five reviewed defects together give 44 FAIL lines and exit 1 (`mut/lab_reviewed_behaviour_844x390_glc.log`) |
| 7 | Minor: skills read `Lv. 0`; the key-1 title is never granted | The orchestrator ruled on 2026-10-20 (STATUS.md): the level-1 title "Venture into the World" is held from character creation, with no level-up toast. Skills keep their internal levels in W1-UI, and W2-SKILLS moves them to Durango's 1-60 scale. No code change: no screen shows a held title, and the banner correctly never grants key 1 | t_ui `_test_level_up_banner` covers every key from 2 up |
| 8 | Minor: the colour 🦖 on the ANIMALS rail | ANIMALS draws the white `raptor_talon` symbol through `HexButton.white_material`. No creature silhouette exists among the 25 + 126 icons. t_ui's cap went from 11 to 10. Handoff list for W1-ICONART/W2-HUD (hunt_hud.gd lines): 311 and 341 `🍖` quick-food fallback, 319 `🔍` DEBUG, 391 `🕸 💥 🦵` NET/TACKLE/KICK, 410 `🦖 🛡` SIC/GUARD, 439 and 446 `🏃` CHASE, 751 `👁` level-up XP line, 1036 `💥`, 1041 `🕸`. Wanted: white symbols for animals or creatures (to replace the talon), net, tackle, kick, guard, attack (SIC), chase/run, inspect and XP | `[t_ui] hunt_hud.gd: 10 lines with emoji (cap 10, W2-HUD)` |
| 9 | Minor: ring turning is not unit-tested | t_ui case: anchor (800, 450) in a 1600x900 view, with a block on both right-hand slots. The test checks that the unturned ring sits on the block, then needs the result clear of it, with every hex centre 96 px from the anchor (a turn, not a slide) | `[t_ui] radial turn: 2 hexes off the block at [(753.92, 512.9619), (678.7206, 382.7127)], radii 96.0, 96.0`. With `TURN_STEPS := 1`: `[t_ui] FAIL turned ring clears the block (hex at (827.6746, 342.8006))` (`mut/t_ui_turn1_and_world_level.log`) |
| 10 | Minor: `_on_level_up` ignores its argument | `LevelDisplay.shown(stored)` returns stored + 1, and `player_level()` uses it. The handler formats the signal's level | The t_ui test now leaves `World.pioneer_level` at 0 and calls `_on_level_up(key - 1)`. Reading World again: `[t_ui] FAIL level-up to Lv. 5: banner "Lv. 1" with "Title Camp Builder acquired." ...` |
| 11 | Minor: the atlas map is about 220 px tall at 844x390 | On a landscape phone the square map can also run down between the action row and the zoom row when that is bigger: 288 px at 844x390 (272..560 x 72..360, was 222). At 804x452 the old place is bigger and stays (284 px). Away from home, the actions shrink to fit before the zoom row; before, three 200 px buttons ran under it. The lab runs at home, so that case is not exercised | The lab's atlas blocks (map, actions, zoom, cards, legend, close) pass at all 8 runs. Shot `final/844x390_glc/atlas_844x390.png` |
| 12 | Minor: a 176x72 opaque plate covers the survivor | On compact canvases, a creature that is emphasised but is neither the hunt target nor tameable shows only its name and bar, a 172x40 pill. The target and tameable creatures keep the status and tame rows | Lab, on phones: `[uireal] plate Lv. 1  Compsognathus glyphs=0 pill=(172.0, 40.0)`, gated at height <= 42 with no glyphs. In the hunt: `[uireal] combat plate Lv. 1  Compsognathus glyphs=3`. The desktop keeps every row (`glyphs=3 pill=(172.0, 74.0)`) |
| 13 | Minor: the animal screen has no backdrop at 844x390 | Not changed: `animal_screen.gd` is protected. For W2-SCREENS: in `AnimalScreen`, replace `set_anchors_preset(Control.PRESET_FULL_RECT)` with `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)` (the screen keeps an empty rect inside the tree), and give the sheet an opaque `UiTokens.panel_style(1.0)` backdrop. The lab still saves `animals_<w>x<h>.png` ungated | `[uireal] animals (protected, not gated): screen rect ...` line in each lab log |

Also changed while doing the above:
- CHASE moved into the quick-food row (slot 2). At the rail's left edge it sat on the first food hex at every size.
- The build sheet's "No building kits" note wraps under the rows. In the two-column grid it had stretched the sheet to 708 px.
- `UiTokens.hud_reserved` landscape zone 3 now covers the whole row above the rail (quick food, chase, HANDS), not only HANDS. t_ui checks the first food hex.

## Acceptance checklist (on the branch, nothing applied on top)

The eight lab runs, t_ui, run_all, smoke, ui_family_lab and ui_screenshot_lab ran on a362f72 (`final/`). __MARKNOTE__

| Item | Output line (log) |
|---|---|
__LABROWS__
| HUD states, all 8 runs | `[uireal] sheet menu ...: 5/5 rows fully shown, rows scroll=false`, `[uireal] sheet build ...: 1/1 rows fully shown, rows scroll=false`, `[uireal] pet out: pets=1 whistles=3`, `[uireal] combat plate Lv. 1  Compsognathus glyphs=3`. The landscape sheet is at `[P: (8.0, 6.0), S: (336.0, 272.0)]` at 844x390 and 667x375 |
| Radial and atlas, all 8 runs | `[uireal] radial: 2 option labels, 2 hexes and the title checked against 18 HUD blocks ... (most of a part on it 0.0%)` (0.6% at 390x844), `[uireal] atlas cards: 4 of 15 charted islands` |
| t_ui (`final/t_ui.log`) | `[t_ui] scanned 23 owned files: emoji=0 small_font=0`, `[t_ui] hunt_hud.gd: 10 lines with emoji (cap 10, W2-HUD)`, `[t_ui] draw_centered: 40 px at x=100 starts at 80.0`, `[t_ui] radial above view: centres 150.4 px apart (hex 64)`, `[t_ui] radial turn: 2 hexes off the block at [...], radii 96.0, 96.0`, `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`, `[t_ui] player level: new survivor reads Lv. 1; direct reads outside LevelDisplay=0`, `[t_ui] level-up banner: 6 titled levels, banner level and title key agree`, `[t_ui] engine errors/warnings during the checks: 0`, `[t_ui] PASS`, exit 0 |
| Existing suite (`final/run_all.log`) | `[tests] PASS`, exit 0. The exit-time `5 ObjectDB instances were leaked` / `1 resources still in use` lines are the same as in review 7's log |
| Smoke (`final/smoke.log`, `tools/smoke.sh --no-import` through gslot) | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` then `SMOKE PASS`, exit 0 |
| ui_family_lab, headless (`final/ui_family.log`) | `[uifamily] inventory=true animals=true unlimited=true active_cap=3 stego=stegosaurus`, exit 0 |
| ui_screenshot_lab, windowed 1600x900 (`final/ui_screenshot.log`) | `[uishot] PASS screens=hud,inventory,animals,craft,atlas,death,radial sizes=1600x900,390x844 shots=/tmp/deadfront-ui-shots`, exit 0 |
| Merge with the base | `git log HEAD..claude/mmo-overhaul` is empty after merge 12bcf11 |

No `--import` this pass: review 8 adds no class_name files and no assets.

## Screenshots inspected (Read tool), this pass

- 844x390 (`e/844x390_glc/`, `final/844x390_*`): `sheet_menu`: the menu covers the vitals, title and Close on top, Bag/Craft/Map/Save/Debug in two columns, no HANDS. `sheet_build`: 300 px wide, the note wraps under "Move buildings". `pet_out`: SIC/HEEL/GUARD under the vitals, the map is clear. `combat`: the plate between the vitals and the map (`Compsognathus Lv. 1`, `KN GR BL` under the bar), End Combat under the map text, NET/TACKLE/KICK/ROLL along the bottom right, Auto above them, `Attack Stance` left of NET, CHASE and FISTS in the row above the rail. `levelup`: `Lv. 5 LEVEL UP / Title Camp Builder acquired. / Will +6 · other stats +5 · Skill points 0` in the band, nothing else moved. `plate`: the slim name and bar over the compy. `atlas`: the 288 px map.
  Reviewer's before shots: `../finish-review/ui/r2/sheets/after/844x390_glc/sheet_menu.png`, `combat/after/844x390_glc/{pet_out,combat}.png`, `pairs/after/844x390_glc/levelup.png`.
- 667x375 (`final/667x375_glc/combat_667x375.png`, `levelup_667x375.png`): same layout. The plate name ellipsises to `Compsognath…` in the 302 px band.
- 1600x900 (`final/1600x900_*`): `combat`: Auto under ROLL's caption, stance text inside the bottom edge, the whistle column above HANDS. `levelup`: the desktop stack is unchanged. `sheet_menu`: one column standing on the rail, with Close in the header.
- 390x844 (`d/390x844_glc/combat_390x844.png`, `levelup_390x844.png`): the portrait layout from the bottom up: rail, food row with CHASE, whistles with End Combat to their right, the skill row, then Feed/Auto and the stance text. The plate and banner sit full-width under the map text.

## Integrator hooks

None. Hook 1 (main.gd) landed on the branch in c4c84f9. Two notes remain:

1. `game/scripts/ui/hunt_hud.gd:77` (owned for this package): `set_anchors_preset(Control.PRESET_FULL_RECT)` ->
   `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`. I left it out on purpose. The HUD's `mouse_filter` is IGNORE and the gate
   reads every control's rect, but I have not run it with a real HUD rect.
2. `run_all.gd`: no edit. `tools/test.sh` (W1-QA) runs every `t_*.gd`, `t_ui.gd` among them.

## Labs to register

`tools/labs.txt` does not exist yet. Proposed line:

`ui_real_capture_lab  windowed  --resolution 844x390 -- --lab=ui_real_capture_lab --shot-dir=DIR   # also 1600x900, 667x375, 390x844; add --rendering-method gl_compatibility for web; expect "[uireal] PASS screens=...sheet_menu,sheet_build,levelup,pet_out,plate,combat...", exit 0`

## Assumptions (`# ASSUMPTION:` in code unless noted; review 8 added the last six)

- `display_mode.gd` `LANDSCAPE_MIN_W := 804.0`: the bag's three columns need about 804 usable px. Narrower landscape
  phones get 804 px at a smaller scale: 10 pt smallest text on a 667 pt SE, 9.6 pt on a 640 pt Android.
- `display_mode.gd` `side_inset_px` / `MIN_USABLE := 0.75`: on mobile the side safe-area insets come off before the floor applies. Unit-tested only.
- `held_item_slot.gd`: mirrors hunt_hud's rail (four 64 px hexes, 10 px apart, 96 px up). `UiTokens.hud_reserved` mirrors the HUD's zones for the radials.
- `skills_sheet.gd` SYMBOLS: item symbols stand in for skill art (W1-ICONART). The character cards reuse them.
- `craft_ui.gd` STATIONS: the crock pot uses the `boiled_meat` cauldron symbol and the campfire uses `skewer`.
- `character_creation.gd` `STORY_TIGHTEN := 8`. Phone cards show the head-start skill without `Lv. 20` or a symbol.
- `hex_button.gd` focus: only the station menu opts its hexes into focus (ui-gamepad-01 is shared with W2-SCREENS).
- `ui_tokens.gd` `xp_line_zone`: 180x26 px at the bottom centre.
- `gather_radial.gd`: the title clears the bottom edge by 24 px. In `pick_label_rect`, the plant counts at a tenth of the weight of text.
- `ui_real_capture_lab.gd`: a hex or label may graze the plant's hull by at most 5 % of its own box; the title may not touch it.
- No `game/ui/deadfront_theme.tres`: the theme is built from tokens at runtime.
- `hunt_hud.gd` `_centre_band`: on phones, the quest card gives way to the target plate and the level-up banner while they show. Nothing else free on a 390 px canvas fits a 70-100 px block.
- `hunt_hud.gd` `_layout_landscape_phone` / `_layout_portrait`: these placements are mine, not from the PRD. The combat reference only says End Combat on the right and the skills bottom right.
- `hunt_hud.gd` ANIMALS: the white `raptor_talon` stands in for a creature symbol (W1-ICONART).
- `hunt_hud.gd` `_on_level_up`: no `level` pickup toast; the banner says it.
- `creature_plates.gd`: on compact canvases only the hunt target or a tameable creature keeps the status and tame rows.
- `map_screen.gd`: the landscape map may run down between the action row and the zoom row.

## Open decisions

None left from review 7: the orchestrator ruled on the starter title and the skill numbering on 2026-10-20 (row 7).

## What is left / risks

- **The creature plates (layer 58) still draw over HUD controls (layer 1) when a creature stands under them.** At 390x844 a
  compy's plate hid most of `Attack Stance`. Taps go through, because the plates ignore the mouse. They now hide under the HUD sheets.
  The general fix, plates keeping off the HUD's rects or a layer order of world < plates < HUD, touches the HUD's label pills
  (the plate is opaque so that world labels do not show through it). That is W2-HUD's call.
- The lab never sets quick food, so the two food hexes are not in any gated state. CHASE now sits beside them, and on landscape the row is in
  `hud_reserved`. On a portrait phone the context row (one row above the rail) still overlaps the food hexes; that was already true before this branch.
- On a portrait phone the combat cluster fills the lower half of the screen, around the survivor. Portrait is superseded (owner: phones are played landscape).
- **Phone fit needs one device or mobile-web run.** There is no device here and no web export on this shared machine.
- hunt_hud.gd keeps 10 lines of colour emoji (list in row 8).
- The HUD minimap turns with the camera while the atlas is north-up (W2-HUD).
- The white-symbol shader is checked on Forward+ and gl_compatibility on macOS (Metal), not on a phone GPU.
- The atlas card shows the home island as `Lv. 10` (its tier in world data). That is a data question.
