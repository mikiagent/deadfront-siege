# W1-UI report (claude, branch claude/mmo-w1-ui)

This pass's logs and screenshots are in the scratchpad, under
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1ui-r6/`.
Paths below are relative to that folder. Earlier passes are under `../w1/ui/`.
The final code is commit 826ab9e. This report is the only commit after it.

## Status: the gate is green on the branch

The orchestrator chose option (a) on 2026-10-20: for this package W1-UI owns `hunt_hud.gd` and `inventory_ui.gd`
and may land hook 1 in `main.gd`. **The hooks patch landed as real code in c4c84f9.** The patch file is deleted,
so nothing is left to apply. It contained:

- main.gd: `DisplayMode.install(get_tree().root)` and `DisplayMode.install_theme()` at the top of `_ready`.
- inventory_ui.gd: three equipment columns when four do not fit, and the profile level line through `LevelDisplay.player_label()`.
- hunt_hud.gd: on a portrait phone (`is_phone`) the context row starts at the left, one row up, and CLAIM goes under the quest card.

`ui_real_capture_lab` prints `[uireal] PASS` and exits 0 on the branch for all eight runs: 1600x900, 844x390, 667x375
and 390x844, each in Forward+ and gl_compatibility. The base branch is merged in properly (f630c58).
`git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul` exits 0 and prints only the tree id.

**Player level:** a new survivor reads `Lv. 1` on the HUD badge (`1`), the XP line (`Lv. 1  5.0%`), the atlas
(`Lv. 1`) and the bag (`Survivor · Lv. 1`). The stored `World.pioneer_level` still starts at 0, as saves expect.
`LevelDisplay.player_level()` adds 1, and every player-level display reads it there: the HUD badge, the XP line, the
level-up banner, the atlas, the bag and the lab fallback panel in world_ui. ui-level-01 is closed.

## Review 6 findings and what changed

| # | Finding | What I did | Check that catches it |
|---|---|---|---|
| 1 | Blocker: the lab is red on the branch; the fix sits in protected files | Landed the hooks patch under option (a) (c4c84f9) | Lab PASS at all 8 size/renderer runs (checklist below) |
| 2 | Radial: a huge finite anchor collapses the hexes | `ContextRadial.hex_positions` clamps the anchor to the view grown by one ring (radius + hex), next to the NaN guard | t_ui: `[t_ui] huge anchor (-1e9, 1e9): six hexes, min_dist=96.0`. Mutation (clamp removed): `[t_ui] FAIL anchor (-1e9, 1e9) keeps six hexes apart (min 0.0)`, exit 1 (`t_ui_mut_anchor.log`) |
| 3 | Gather radial label lands on the survivor's nameplate at 844x390 | `HuntHud.nameplate_rect()` is the one source for the nameplate rect. The HUD draws from it, and the gather radial adds it to the hexes' avoid list and the labels' blockers. **The first fix moved the label onto the HANDS caption.** I saw it in `old/844x390_fwd/radial_844x390.png` and the nameplate-only gate passed it. So: the landscape `UiTokens.hud_reserved` now includes HANDS (stacked above the rail), labels treat the HUD zones as blockers, and when no spot is clear `pick_label_rect` takes the least-covered one (the preferred side on a tie, so run_all's boxed-in case holds) | Lab: every radial label and hex is checked against all `hud_blocks` plus the nameplate: `[uireal] radial: 2 option labels and 2 hexes checked against 16 HUD blocks, nameplate [P: (387.5001, 197.0615), S: (70.0, 29.0)]`. On the code before the HANDS fix it failed: `[uireal] FAIL radial: label0 [P: (265.8696, 259.7754), S: (99.0, 26.0)] stays off HeldItemSlot [P: (238.0, 196.0), S: (64.0, 82.0)]`, exit 1 (`844x390_fwd_prefix.log`). t_ui: the landscape zones must cover the HANDS slot |
| 4 | map_screen: a dead `yaw` key and consts declared mid-file | Removed `yaw` and its rotation math: the draw uses a north-up transform and taps use `pos - centre`. Moved `PHONE_CARD_TOP`/`PHONE_MAP_TOP` up with the other consts | t_ui: the atlas `_layout()` keys must be `centre/fit/scale/size_m`. t_ui owned-source scan: no `const` after the first `func` in any owned file (only map_screen had them) |
| 5 | A new survivor reads `Lv. 0` | Orchestrator decision: `Lv. 1`. `LevelDisplay.player_level()` returns stored + 1. The HUD badge, XP line and level-up banner (hunt_hud) and world_ui's panel now read it | t_ui: `[t_ui] player level: new survivor reads Lv. 1; direct reads outside LevelDisplay=0`. The scan covers the owned files, hunt_hud, inventory_ui and the lab; writes and the `pioneer_changed` argument are allowed. Lab: the bag's profile must end with `LevelDisplay.player_label()` |
| 6 | Sync commit d2c8e8a copied docs instead of merging | This pass merges `claude/mmo-overhaul` with a real merge (f630c58). Its one conflict, `docs/orchestration/mmo/STATUS.md`, resolved to the base version, which W1-UI does not own. The branch's STATUS.md now equals the base's | `git diff claude/mmo-overhaul -- docs/orchestration/mmo/STATUS.md` is empty; merge-tree exits 0 |
| 7 | t_ui prints a WARNING and a backtrace (`grab_focus` on a FOCUS_NONE hex) | Dropped the `grab_focus` call. The test asserts `FOCUS_NONE` and still pushes the click. t_ui now installs a `Logger` (`OS.add_logger`) for the whole run and fails on any engine error or warning | `[t_ui] engine errors/warnings during the checks: 0`. Mutation (`grab_focus` back): `[t_ui] FAIL engine WARNING This control can't grab focus. Use set_focus_mode() and set_focus_behavior_recursive() to allow a control to get focus. (scene/gui/control.cpp:3006 grab_focus)`, exit 1 |

I also dropped the lab's `--no-fit` and `--no-theme` flags (826ab9e). main.gd installs both before any lab starts,
so the flags could no longer turn them off. The verdict on a missing fit is still unit-tested: t_ui `_test_gate_verdict`,
`[t_ui] gate: 844x390 without fit -> 2 failures`.

## Acceptance checklist (final code 826ab9e; on the branch, nothing applied on top)

| Item | Output line (log) |
|---|---|
| 1600x900, web renderer (gl_compatibility) | `[uireal] phone=false min_font_px=13 logical_width=1600 window_pt=1600x900 min_pt=13.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shot_only=animals shots=.../w1ui-r6/1600x900_glc`, exit 0 (`1600x900_glc.log`) |
| 1600x900, Forward+ | Same two lines, `shots=.../w1ui-r6/1600x900_fwd`, exit 0 (`1600x900_fwd.log`) |
| 844x390, web renderer | `[uireal] phone=true min_font_px=12 logical_width=844 window_pt=844x390 min_pt=12.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shot_only=animals shots=.../w1ui-r6/844x390_glc`, exit 0 (`844x390_glc.log`) |
| 844x390, Forward+ | Same two lines, `shots=.../w1ui-r6/844x390_fwd`, exit 0 (`844x390_fwd.log`) |
| 667x375, both renderers | `[uireal] window=667x375 logical=804x452 content_scale=(804, 452)`, `[uireal] phone=true min_font_px=9 logical_width=804 window_pt=667x375 min_pt=9.96 floor_pt=9.96 (...)`, `[uireal] PASS ...`, exit 0 (`667x375_fwd.log`, `667x375_glc.log`) |
| 390x844, both renderers | `[uireal] phone=true min_font_px=12 logical_width=390 window_pt=390x844 min_pt=12.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,craft_detail,skills,atlas,radial,plate,bag,charcreate shot_only=animals ...`, exit 0 (`390x844_fwd.log`, `390x844_glc.log`) |
| t_ui (`t_ui.log`) | `[t_ui] scanned 23 owned files: emoji=0 small_font=0`, `[t_ui] draw_centered: 40 px at x=100 starts at 80.0`, `[t_ui] radial above view: centres 150.4 px apart (hex 64)`, `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`, `[t_ui] atlas legend: 8 kinds, min colour distance 0.35`, `[t_ui] player level: new survivor reads Lv. 1; direct reads outside LevelDisplay=0`, `[t_ui] huge anchor (-1e9, 1e9): six hexes, min_dist=96.0`, `[t_ui] engine errors/warnings during the checks: 0`, then `[t_ui] PASS`, exit 0. The log has no `SCRIPT ERROR` or `WARNING` line |
| Existing suite (`run_all.log`) | `[tests] PASS`, exit 0 |
| ui_family_lab, headless (`ui_family.log`) | `[uifamily] inventory=true animals=true unlimited=true active_cap=3 stego=stegosaurus`, exit 0 |
| ui_screenshot_lab, windowed 1600x900 (`ui_screenshot.log`) | `[uishot] PASS screens=hud,inventory,animals,craft,atlas,death,radial sizes=1600x900,390x844 shots=/tmp/deadfront-ui-shots`, exit 0 |
| Smoke (`smoke.log`, `tools/smoke.sh --no-import` through gslot) | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` then `SMOKE PASS` |
| Merge with the base | `git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul` exits 0 and prints only the tree id |

These lines hold at all eight runs: `[uireal] charcreate cards: rows=2 title_y_spread=0.0 start_y_spread=0.0` (rows=4 at
390x844), with `symbols=8` at 1600x900. Skills rows fully visible: `12/12` at 1600x900 and 667x375, `10/12` at
844x390, `8/12` at 390x844. Landscape Craft is pinned:
`[uireal] craft sheet: CraftOne [P: (460.0, 314.0), S: (180.0, 64.0)] in footer=true vscrolls=3` (844x390).
The spec writes `'Lv —'`; the screens print `Lv. —`, which is the one level format.

After merging the base I ran one `--import` (alarm 900, exit 0, no ERROR lines). The merge brought in W1-HARBOUR's new
`HarbourSite` class_name, and without the import `--script` runs hit parse errors in build_grid.gd.

## Screenshots inspected (Read tool), this pass

- `1600x900_glc/hud_1600x900.png`: badge `1`, `Lv. 1  5.0%` bottom centre, `Survivor` nameplate.
- `1600x900_glc/bag_1600x900.png`, `844x390_glc/bag_844x390.png`, `667x375_glc/bag_667x375.png`: `Survivor · Lv. 1`.
  At 844x390 and 667x375 there are three equipment columns, and the close button sits inside the panel.
- `1600x900_glc/atlas_1600x900.png`, `844x390_glc/atlas_844x390.png`: `You X 0 Y 18  Lv. 1`. Still north-up after the
  yaw removal, N marker top right, legend colours distinct.
- Radial before the fixes: reviewer's `../w1-review/ui/r3/shots/merged_radial_844x390_fwd.png`, where `Berries Lv. 1` covers `Survivor`.
  After the nameplate fix alone: `old/844x390_fwd/radial_844x390.png`, where the nameplate is clear but the label covers the HANDS caption (`HA` shows).
  Final: `844x390_fwd_fix2/radial_844x390.png` and `844x390_glc/radial_844x390.png` show `Survivor`, HANDS, both hexes and both
  labels clear of each other. `Fibre Stalk Lv. 1` sits above its hex, because the right side is the map column.
  `667x375_fwd/radial_667x375.png` is clear. `1600x900_fwd/radial_1600x900.png` is unchanged from before.
  `390x844_glc/radial_390x844.png` is tight but clear: `Berries Lv. 1` ends a few px left of the HANDS hex.
- `844x390_glc/hud_844x390.png`, `390x844_fwd/hud_390x844.png`: the landscape rail with HANDS above SKILLS. In portrait,
  CLAIM sits under the quest card and HANDS sits above the level line (hook 6).
- `/tmp/deadfront-ui-shots/inventory_1600x900.png` (ui_screenshot_lab, stored level 100): `Gatherer · Lv. 101`, and the HUD
  badge in `radial_edge_1600x900.png` reads `101`. All screens agree at a high level too.

## Integrator hooks

None for main.gd: hook 1 landed on the branch. Two notes remain:

1. `game/scripts/ui/hunt_hud.gd:69` (now W2-HUD's): `set_anchors_preset(Control.PRESET_FULL_RECT)` ->
   `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`. It is not in the landed patch, and I left it out on purpose. The HUD's
   `mouse_filter` is IGNORE, so it would not eat taps. But giving the HUD a real rect can move any child anchored to it,
   and I have not run that. Run the lab at all four sizes if it lands.
2. `run_all.gd`: no edit. Under the plan, `tools/test.sh` (W1-QA) runs every `t_*.gd`, which includes `t_ui.gd`.

## Labs to register

`tools/labs.txt` does not exist yet. Proposed line, one lab:

`ui_real_capture_lab  windowed  --resolution 844x390 -- --lab=ui_real_capture_lab --shot-dir=DIR   # also 1600x900, 667x375, 390x844; add --rendering-method gl_compatibility for web; expect "[uireal] PASS", exit 0`

The scene is `game/scenes/dev/ui_real_capture_lab.tscn`. It is green on the branch now; register it as a required gate.

## Assumptions (`# ASSUMPTION:` in code unless noted)

- `display_mode.gd` `LANDSCAPE_MIN_W := 804.0`: the bag's three columns need about 804 usable px. Narrower landscape
  phones get 804 px at a smaller scale: 10 pt smallest text on a 667 pt SE, 9.6 pt on a 640 pt Android, and about
  11.2 pt on a notched 844 pt iPhone.
- `display_mode.gd` `side_inset_px` / `MIN_USABLE := 0.75`: on mobile, the side safe-area insets come off before the floor
  applies, and the safe area never leaves less than 75 % of the width usable. Unit-tested only.
- `held_item_slot.gd`: mirrors hunt_hud's rail (four 64 px hexes, 10 px apart, 96 px up). The new landscape HANDS zone
  in `UiTokens.hud_reserved` (`Rect2(232, h - 200, 76, 96)`) mirrors that placement. A comment there says so; t_ui checks
  that the zone covers the slot.
- `ui_real_capture_lab.gd` `hud_blocks`: the vitals, quest and level-line rects mirror hunt_hud.gd `_draw` and `_draw_quest`.
- `skills_sheet.gd` SYMBOLS: item symbols stand in for skill art (W1-ICONART). The character cards reuse them.
- `craft_ui.gd` STATIONS: the crock pot uses the `boiled_meat` cauldron symbol and the campfire uses `skewer`.
- `level_display.gd`: no longer an assumption. The orchestrator decided that the shown level is stored + 1.
- `character_creation.gd` `STORY_TIGHTEN := 8`. Phone cards show the head-start skill without `Lv. 20` or a symbol.
- `hex_button.gd` focus: only the station menu opts its hexes into focus. The radials do not call `focus_first`, so a
  controller does not drive them yet (ui-gamepad-01 is shared with W2-SCREENS).
- No `game/ui/deadfront_theme.tres`: the theme is built from tokens at runtime.

## What is left / risks

- **Phone fit needs one device or mobile-web run.** There is no device here and no web export on this shared machine. The notch path and
  `DisplayServer.screen_get_scale()` on mobile web are unit-tested only. On a device, record the boot line
  `[display] window (W, H) -> logical (w, h)` and the lab's `[uireal] phone=... min_pt=...` line.
- The level-up banner (hunt_hud, now reading `LevelDisplay`) still shows `👁 %d` for pioneer XP. That is a system emoji in the HUD,
  which W1-UI's t_ui scan does not cover (hunt_hud is not in its owned list). It is for W1-UIICONS/W2-HUD.
- The gather title (name + level) sits at the bush's ground point, in the ring's centre. When the ring turns away from the HUD it can sit
  under both hexes, as in the 844x390 shot. It is readable and off everything; I did not change it.
- Portrait 390x844 radial is crowded near HANDS (clear by a few px, gate PASS).
- On the protected bag at 1600x900, the four-column Legs/Ring slots touch the panel's right border. On a 390 pt landscape phone the
  bag's fourth row and food slots need a scroll.
- Animal screen has no backdrop (`animal_screen.gd`: `set_anchors_preset` inside the tree keeps an empty rect). The lab still saves
  `animals_<w>x<h>.png` on every run, and nothing on that screen is gated. This is for W2-SCREENS.
- The HUD minimap turns with the camera while the atlas is north-up (W2-HUD). `UiTokens.hud_reserved` and the lab's
  `hud_blocks` mirror hunt_hud geometry; replace both with rects the HUD exports.
- The white-symbol shader is checked on Forward+ and gl_compatibility on macOS (Metal), not on a phone GPU.
- The atlas card shows the home island as `Lv. 10` (its tier in world data). That is a data question.
