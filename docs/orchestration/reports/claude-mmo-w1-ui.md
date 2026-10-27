# W1-UI report (claude, branch claude/mmo-w1-ui)

Logs and screenshots for this pass are in the scratchpad under
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1ui-r10/`.
Paths below are relative to that folder. `final/` and `final2/` hold the acceptance lab runs and `mutf/` the mutation run.
The `final_*.log` files are the tests and labs. Review 8's pass is under `../w1ui-r8/`. The reviewers' evidence is under `../finish-review/ui/r2/`.

The code is commit f122d8a. Review 9 is ececc43, d41f41a and f122d8a, plus the merges d1e013a and c0eac838.
Merge c0eac838 brought in a STATUS.md-only base commit after the final runs, so no code changed after them.
This report is the only commit after that merge.

## Status

- `claude/mmo-overhaul` moved twice: DSC-MINORS, then two STATUS.md commits. I merged it both times with a real merge
  (d1e013a, c0eac838). There were no conflicts. `git log HEAD..claude/mmo-overhaul` prints nothing.
- The owner's see-through request ("partially see through not fully see through... not a clear hole") belongs to W2-OCCLUDE.
  STATUS.md records it there (2026-10-20, finish-3). No W1-UI file draws world geometry, so this package changes nothing for it.
- The five round-2 blockers and the round-2 major were fixed in review 8 (rows 1-6 below, unchanged).
  This pass fixes the second reviewer's findings (rows 14-19). It also adds lab gates for everything that moves over the HUD:
  toasts, notices, building labels, station hexes, creature plates and the survivor's figure.
  All eight lab runs print `[uireal] PASS`. The mutation run, which restores the reviewed defects, prints 50 FAIL lines at 844x390 and 44 at 667x375.

## Findings and what changed

Rows 1-13 are the round-2 review. Review 8 fixed them; the full text is in git history (afe669a). They are shortened here.

| # | Finding | What changed | Check that catches it |
|---|---|---|---|
| 1 | Blocker: MENU sheet 192 px off the top at 844x390 | Pinned header plus a `SheetRows` scroll, two columns on a landscape phone, hung from the vitals' corner | `[uireal] sheet menu [P: (8.0, 6.0), S: (336.0, 272.0)]: 5/5 rows fully shown, rows scroll=false` at 844x390 and 667x375 |
| 2 | Blocker: HANDS on both sheets' Close | HANDS and the creature plates hide while `HuntHud.sheet_open()` | Lab `sheet <kind>: HANDS is hidden or off the sheet`, `creature plates hide while it is open` |
| 3 | Blocker: whistle hexes on the minimap, GUARD off the top | Landscape: SIC/HEEL/GUARD in a row under the vitals; `hud_reserved` zone 6 | `[uireal] pet out: pets=1 whistles=3`, then every block checked (all 8 runs) |
| 4 | Blocker: End Combat on ROLL/SIC, target bar across vitals and quest | Compact landscape and portrait combat layouts; the target plate in the centre band | Lab `combat` state: every control and drawn block in the view, none overlapping |
| 5 | Blocker: 13-line level-up stack over the rail and off the bottom | On phones, a three-line banner in the centre band | Lab `levelup` state |
| 6 | Major: the lab only checked the idle HUD | Lab states for the sheets, level-up, pet out and combat; `hud_blocks` reads `HuntHud.drawn_blocks` | 44 FAIL lines on the review-7 code (`../w1ui-r8/mut/`) |
| 7 | Minor: skills `Lv. 0`, key-1 title never granted | Orchestrator ruling 2026-10-20: skill numbering belongs to W2-SKILLS. Title: see row 14 | Row 14 |
| 8 | Minor: colour 🦖 on ANIMALS | White `raptor_talon` through `HexButton.white_material`; t_ui cap 11 -> 10 | `[t_ui] hunt_hud.gd: 10 lines with emoji (cap 10, W2-HUD)` |
| 9 | Minor: ring turning untested | t_ui radial-turn case (same radius from the anchor) | `[t_ui] radial turn: 2 hexes off the block at [...], radii 96.0, 96.0` |
| 10 | Minor: `_on_level_up` ignored its argument | `LevelDisplay.shown(stored)` | t_ui level-up banner case |
| 11 | Minor: atlas map about 220 px at 844x390 | 288 px landscape map | Lab atlas blocks, 8 runs |
| 12 | Minor: 176x72 plate covered the survivor | Compact plate (name and bar, 172x40) unless the creature is the target or tameable | `[uireal] plate Lv. 1  Compsognathus glyphs=0 pill=(172.0, 40.0)` on phones |
| 13 | Minor: animal screen has no backdrop (protected) | Handoff to W2-SCREENS (see "What is left") | Shot only |
| 14 | Major (second reviewer): the level-1 title "Venture into the World" shows nowhere | `LevelDisplay.current_title(level)` returns the highest titles.json key at or under the shown level. The bag profile shows it under the name from character creation on, with no toast. The level-up banner still announces keys 3 and up | t_ui `[t_ui] ok current_title 9 levels, new survivor holds "Venture into the World"`. Lab: `bag: profile shows the held title "Venture into the World"`. Shot `final/844x390_glc/bag_844x390.png`: `Survivor / Venture into the World / Survivor · Lv. 1` |
| 15 | Major: on phones, moving HUD text overlaps the HUD. The banner runs over the rail, `+N item` toasts cross the quest card, camp pills draw over the quest text, and COOK covers "Cargo Warp" | `HuntHud.taken_rects()` lists what the HUD holds this frame: every drawn block, every visible hex (HUD, station and gather radials) with its caption, the HUD controls, HANDS, and the survivor's figure (`figure_rect`, head to name). Toasts, then notices, take the nearest free spot up or down (`UiTokens.free_spot`). On phones the toasts stack under the vitals (they covered the survivor in the centre), and notices centre on the free band between the vitals and the map. Building labels lay out against the same rects (`layout_labels(..., avoid, keep_off)`). A label whose object the HUD hides is dropped. The survivor is only stepped around, so a building behind the survivor keeps its label. Landscape `hud_reserved` zone 1 runs to 112, so station hexes clear the quest card (it ends at 106). Portrait gained a map-column zone. The banner was already fixed in review 8 (row 5) | New lab states `camp_bonfire`, `station_bonfire`, `camp_workbench`, `station_workbench`, `busy` (3 toasts, 2 notices, pet out) and `busy_levelup`, at all 8 runs. Each checks every block and hex for overlap and in-view, and keeps the moving text off the survivor (`_check_figure`). They also require the labels, all toasts and notices, and the station hexes to be drawn, so dropping everything cannot pass. 844x390 `busy`: `toast0=8,189 toast1=8,221 toast2=8,253 notice0=339,122 notice1=379,226 pill0=462,8 pill1=338,77`, quest card `422,34` |
| 16 | Minor: the first level-up toast read `+2 level` | Fixed in review 8: there is no level toast; the banner announces the level | `grep '&"level"' game/scripts` finds nothing |
| 17 | Minor: the opaque plate pill hid the survivor's name | Creature plates (canvas layer 58, above the HUD) take the nearest free spot up or down off `taken_rects()` (name, figure, blocks, hexes) and off earlier plates. With no free spot, they hide. Before, a plate only lifted, and a portrait plate climbed off the top. Two plate fixes rode along. A dodged hit emitted `0.0` and read `-0` over the plate; it now reads `DODGE`, and a damage tick under 1 HP is not shown. Statuses applied together stacked on one spot as garbled text; they now stack down over the plate | Lab `plate_front` state: the lab picks the spot toward the camera where the compy's plate would cover the survivor's name (`[uireal] plate_front: compy 5.75 m toward the camera, feet at y 281, name at y 201`). The plate must show and keep off every HUD rect: `plate_front pill [P: (336.0, 226.06), S: (172.0, 40.0)] shown=true checked against 25 HUD rects`. With avoidance off: `FAIL plate_front: pill [P: (336.0, 177.47), S: (172.0, 40.0)] stays off the HUD rect [P: (391.5, 201.06), S: (62.0, 21.0)]` (that rect is the name). Shots `final/844x390_glc/plate_front_844x390.png` (fixed) and `mutf/844x390_glc/plate_front_844x390.png` (the name hidden) |
| 18 | Minor: a desktop browser window under 500 px tall and wide gets phone layouts | `DisplayMode.handheld()`: on the web, a phone canvas needs a touchscreen. Native windows keep the shape rule, so `--resolution 844x390` still stands in for a phone | t_ui `[t_ui] ok desktop_short_window desktop=(1600, 900) compact=false touch=(1200, 480) compact=true 844x390=(844, 390) handheld=true` |
| 19 | Minor: HANDS drew over character creation | HANDS hides while a node in group `character_creation` exists | Lab: `charcreate: HANDS hides while character creation is up`. Shot `final/844x390_glc/charcreate_844x390.png` has no HANDS |

### Mutation run (`mutf/`)

`mutf/` is a scratch worktree at f122d8a with the reviewed behaviour put back, all at once:
- toasts at a fixed spot in the centre;
- labels laid out without the HUD rects;
- landscape zone 1 back to 96;
- HANDS not hiding under character creation;
- plates ignoring the HUD rects;
- the survivor's figure left out of `taken_rects`.

The lab exits 1 at 844x390 with 50 FAIL lines and at 667x375 with 44. Samples:
- `FAIL busy: quest [P: (422.0, 34.0), ...] overlaps toast0`
- `FAIL station_bonfire: quest ... overlaps xhex28` (COOK on the quest card)
- `FAIL camp_bonfire: quest ... overlaps pill1`
- `FAIL busy: notice0 [P: (339.0, 167.06), S: (304.0, 30.0)] stays off the survivor`
- `FAIL plate_front: pill ... stays off the HUD rect` (the name)
- `FAIL charcreate: HANDS hides while character creation is up`

The scratch worktree is removed.

## Acceptance checklist (f122d8a; the later merge only touched STATUS.md)

| Item | Output line (log) |
|---|---|
| ui_real_capture_lab 844x390 gl_compatibility (`final/844x390_glc.log`) | `[uireal] phone=true min_font_px=12 min_font_pt=12.00 logical_width=844 window_pt=844x390 floor_pt=12.00`, then `[uireal] PASS screens=hud,craft,skills,atlas,radial,sheet_menu,sheet_build,levelup,pet_out,plate,plate_front,combat,camp_bonfire,station_bonfire,camp_workbench,station_workbench,busy,busy_levelup,bag,charcreate shot_only=animals`, rc=0 |
| 844x390 Forward+ (`final/844x390_fwd.log`) | same `phone=true min_font_px=12` line and the same PASS line, rc=0 |
| 667x375 both renderers (`final2/667x375_{glc,fwd}.log`) | `[uireal] phone=true min_font_px=12 min_font_pt=9.97 logical_width=804 window_pt=668x376 floor_pt=9.97` and PASS, rc=0 |
| 1600x900 both renderers (`final/1600x900_{fwd,glc}.log`) | `[uireal] phone=false min_font_px=13 min_font_pt=13.00 logical_width=1600 window_pt=1600x900 floor_pt=12.00` and PASS, rc=0 |
| 390x844 both renderers (`final2/390x844_{glc,fwd}.log`) | `[uireal] phone=true min_font_px=12 ... logical_width=390` and PASS (with `craft_detail`), rc=0 |
| New HUD states, all 8 runs | `[uireal] busy: toasts=3 notices=2 levelup=false`, `[uireal] busy_levelup: toasts=3 notices=2 levelup=true`, `[uireal] camp bonfire: 4 labels, quest card [P: (422.0, 34.0), S: (240.0, 72.0)]` (844x390), `[uireal] station bonfire: 1 hexes, 1 labels`, `[uireal] plate_front pill ... shown=true checked against 25 HUD rects` |
| Review-8 states, all 8 runs | `[uireal] sheet menu [P: (8.0, 6.0), S: (336.0, 272.0)]: 5/5 rows fully shown, rows scroll=false` (phones), `[uireal] pet out: pets=1 whistles=3` |
| t_ui (`final_t_ui.log`) | `[t_ui] scanned 23 owned files: emoji=0 small_font=0`, `[t_ui] hunt_hud.gd: 10 lines with emoji (cap 10, W2-HUD)`, `[t_ui] draw_centered: 40 px at x=100 starts at 80.0`, `[t_ui] radial above view: centres 150.4 px apart (hex 64)`, `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`, the four `[t_ui] ok ...` lines in rows 14, 17 and 18, `[t_ui] ok free_spot 5 rows, 4 placed clear of the taken blocks`, `[t_ui] ok layout_avoid single=1 inside_dropped=true three=3`, `[t_ui] engine errors/warnings during the checks: 0`, `[t_ui] PASS`, rc=0 |
| Existing suite (`final_run_all.log`) | `[tests] PASS`, rc=0. The exit lines `5 ObjectDB instances were leaked` / `1 resources still in use` are the same as in review 8 |
| Smoke (`final_smoke.log`, `tools/smoke.sh --no-import` through gslot) | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day`, then `SMOKE PASS`, rc=0 |
| ui_family_lab, headless (`final_ui_family.log`) | `[uifamily] inventory=true animals=true unlimited=true active_cap=3 stego=stegosaurus`, rc=0 |
| ui_screenshot_lab, windowed 1600x900 (`final_ui_screenshot.log`) | `[uishot] PASS screens=hud,inventory,animals,craft,atlas,death,radial sizes=1600x900,390x844 shots=/tmp/deadfront-ui-shots`, rc=0 |
| dsc verify (`dsc1_verify.log`) | `mutation spot_noop caught` ... `mutation desktop_phone caught` (6 of 6), `VERIFY PASS`, rc=0 |
| Merge with the base | `git log HEAD..claude/mmo-overhaul` is empty after c0eac838 |
| Godot crashes | No new `~/Library/Logs/DiagnosticReports/Godot-*.ips` this pass (the newest is from 02:03 on 2026-10-20) |

No `--import` this pass: no new class_name files and no assets.

## Screenshots inspected (Read tool), this pass

- 844x390 gl_compatibility (`final/844x390_glc/`):
  - `busy`: toasts stack under the whistles at the left. "Need a stone knife" sits between the quest card and the survivor. "Too heavy" sits under the survivor's name. The Workbench label is above the quest card, Bonfire is faded beside it, and nothing overlaps.
  - `plate`: the compy plate sits between the quest card and the survivor's head. The status floats stack down over the plate; the top one grazes the card's bottom edge while it fades (see "What is left").
  - `combat`: unchanged from review 8. The target's world plate hides (no free spot), and the HUD target plate carries name, HP and KN/GR/BL.
  - `station_workbench`: CRAFT hex beside the survivor, Cargo Warp and Workbench labels above it, quest card clear.
  - `bag`: the title line.
  - `charcreate`: no HANDS.
  - `sheet_menu`: as in review 8.
- 844x390 Forward+ (`final/844x390_fwd/levelup_844x390.png`): the banner in the band, nothing under it.
- 844x390 earlier in this pass (`a/`, `f/`):
  - `camp_bonfire`: Tent above the quest card; Bonfire, Workbench and Cargo Warp under it.
  - `station_bonfire`: the COOK hex under the quest card.
  - `busy_levelup`: banner in the band, toasts left, notices centred.
- 667x375 (`final2/667x375_glc/busy_668x376.png`, `a/667x375_glc/camp_bonfire_668x376.png`): same layout at 0.83 scale.
- 390x844 (`final2/390x844_glc/busy_390x844.png`; `c/390x844_glc/combat_390x844.png`; `e/390x844_glc/camp_workbench_390x844.png`):
  - `busy`: toasts under the vitals, notices under the survivor.
  - `combat`: the world plate hides inside the combat cluster.
  - `camp_workbench`: Bonfire is the only label. The map column covers the tent.
- 1600x900:
  - `final/1600x900_glc/busy_1600x900.png`: toasts and notices stacked top-centre, the level-up stack is unchanged on the left, and the compy plate shows all rows.
  - `final/1600x900_glc/plate_front_1600x900.png`: the plate sits under the survivor's name.
  - `b/1600x900_fwd/station_bonfire_1600x900.png`: COOK above the bonfire.
- Mutation (`mutf/844x390_glc/plate_front_844x390.png` and `mut3/`): the compy plate sits on "Survivor".

## dsc usage

One worker, `claude/mmo-w1-ui-dsc1` (sub-worktree `.claude/worktrees/mmo-w1-ui-dsc1`):
`dsc cook start TASK.md --once --verify ./verify_ui.sh --budget 2 --max-hours 4 --effort high`.

- The task: four table-driven t_ui cases from an exact spec (`free_spot` rows with expected rects, `layout_avoid`, `current_title`, `desktop_short_window`).
- The gate, `verify_ui.sh` (mode 555): t_ui must pass clean, print the four `ok` lines and keep the existing cases. Six mutations must each make t_ui fail:
  - free_spot does nothing;
  - free_spot has no bottom edge;
  - labels ignore avoid;
  - hidden anchors are kept;
  - the title needs an exact key;
  - a desktop window gets the phone canvas.
- What dsc did: 16 calls, $0.0154 of $2.00, done in minutes. It wrote 111 lines in `game/tests/t_ui.gd` and committed 36fa1ab. Its commit also carried `TASK.md` and `verify_ui.sh` at the sub-worktree root.
- What I changed: nothing in its t_ui code. I reviewed the diff and ran `verify_ui.sh` myself (`VERIFY PASS`, 6/6 mutations caught). I took only `game/tests/t_ui.gd` into d41f41a (`git checkout claude/mmo-w1-ui-dsc1 -- game/tests/t_ui.gd`), so nothing new lands in the repo root.

The lab states stayed with me. They needed judgement on HUD failures as they surfaced (portrait plate, notices dropped in portrait, survivor figure), which a worker told not to touch the HUD could not resolve.

## Integrator hooks

None. Hook 1 (main.gd) landed on the branch in c4c84f9. Notes from review 8 still stand:
1. `game/scripts/ui/hunt_hud.gd:77` (owned): `set_anchors_preset` -> `set_anchors_and_offsets_preset` was left out on purpose.
2. `run_all.gd`: no edit. `tools/test.sh` (W1-QA) runs every `t_*.gd`.

## Labs to register

`tools/labs.txt` does not exist yet. Proposed line:

`ui_real_capture_lab  windowed  --resolution 844x390 -- --lab=ui_real_capture_lab --shot-dir=DIR   # also 1600x900, 667x375, 390x844; add --rendering-method gl_compatibility for web; expect "[uireal] PASS screens=...plate_front,combat,camp_bonfire,station_bonfire,camp_workbench,station_workbench,busy,busy_levelup...", exit 0`

## Assumptions (`# ASSUMPTION:` in code unless noted)

Review 9 added the last four.

- `display_mode.gd` `LANDSCAPE_MIN_W := 804.0`: narrow landscape phones get 804 px at a smaller scale (10 pt smallest text on a 667 pt SE).
- `display_mode.gd` `side_inset_px` / `MIN_USABLE := 0.75`: side safe-area insets come off before the floor applies. Unit-tested only.
- `held_item_slot.gd` mirrors hunt_hud's rail. `UiTokens.hud_reserved` mirrors the HUD's zones for the radials (no marker).
- `skills_sheet.gd` SYMBOLS: item symbols stand in for skill art.
- `craft_ui.gd` STATIONS: the crock pot uses `boiled_meat` and the campfire uses `skewer`.
- `character_creation.gd` `STORY_TIGHTEN := 8`. Phone cards show the head-start skill without `Lv. 20` or a symbol.
- `hex_button.gd` focus: only the station menu opts its hexes into focus.
- `ui_tokens.gd` `xp_line_zone`: 180x26 px at the bottom centre.
- `gather_radial.gd`: the title clears the bottom edge by 24 px. The plant counts at a tenth of the weight of text.
- `ui_real_capture_lab.gd`: a hex or label may graze the plant's hull by at most 5 % of its own box.
- No `game/ui/deadfront_theme.tres`: the theme is built from tokens at runtime.
- `hunt_hud.gd` `_centre_band`: on phones the quest card gives way to the target plate and the level-up banner.
- `hunt_hud.gd` `_layout_landscape_phone` / `_layout_portrait`: these placements are mine, not from the PRD.
- `hunt_hud.gd` ANIMALS: the white `raptor_talon` stands in for a creature symbol.
- `hunt_hud.gd` `_on_level_up`: no `level` pickup toast; the banner says it.
- `creature_plates.gd`: on compact canvases only the hunt target or a tameable creature keeps the status and tame rows.
- `map_screen.gd`: the landscape map may run down between the action row and the zoom row.
- `display_mode.gd` `handheld()`: a web page without a touchscreen is a desktop. A touch laptop gets phone layouts when its window is short.
- `hunt_hud.gd` toasts: on a phone, pickup toasts stack under the vitals at the left edge (no reference for it).
- `hunt_hud.gd` `figure_rect`: the survivor stands about 1.8 m tall.
- `ui_real_capture_lab.gd` camp states: portrait needs one camp label, not two. The map column covers half the camp, and `layout_labels` never steps sideways (marked `shortcut:`).

## Open decisions

None. The 2026-10-20 rulings cover the starter title (row 14) and the skill numbering (W2-SKILLS).

## What is left / risks

- **Status floats are not gated.** They rise from the plate for about 1.2 s. Over a plate pushed up under the quest card, the top float grazes the card while it fades (`final/844x390_glc/plate_844x390.png`).
- **A hunt target's world plate hides when it has no free spot** (phones in a fight). The HUD's target plate, the red ring and the status badges remain.
- **Portrait camp labels** drop where the map column covers the camp, and a label never steps sideways. Portrait is superseded (owner: phones are played landscape).
- `animal_screen.gd` (protected) still has no backdrop at 844x390. For W2-SCREENS: replace `set_anchors_preset(Control.PRESET_FULL_RECT)` with `set_anchors_and_offsets_preset(...)` and give the sheet an opaque `UiTokens.panel_style(1.0)`.
- hunt_hud.gd keeps 10 lines of colour emoji. The handoff list for W1-ICONART/W2-HUD (current line numbers):
  - 311 and 341 `🍖`
  - 319 `🔍`
  - 391 `🕸 💥 🦵`
  - 410 `🦖 🛡`
  - 439 and 446 `🏃`
  - 751 `👁`
  - 1081 `💥`
  - 1086 `🕸`
- Skills read `Lv. 0` and the bag shows `Gathering 0` until W2-SKILLS re-keys skills (orchestrator ruling).
- **Phone fit still needs one device or mobile-web run.** There is no device here and no web export on this shared machine. `DisplayMode.handheld()` relies on `DisplayServer.is_touchscreen_available()` in the browser, which is untested on a phone.
- The dsc sub-worktree `.claude/worktrees/mmo-w1-ui-dsc1` (branch `claude/mmo-w1-ui-dsc1`) is kept for the record. Its branch carries a TASK.md and verify script at its root and should not be merged as a whole.
