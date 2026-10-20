# W1-UI report (claude, branch claude/mmo-w1-ui)

Logs and screenshots are in the scratchpad: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/ui/` (paths below are relative to it).
Final code is commit 8355ec8 plus a comment-only `# ASSUMPTION:` line in hex_button.gd and this report. Runs r27 to r30 are on that code or the code noted beside them.

## Read this first: the gate stays red until the integrator patch lands

Acceptance item 1 (the lab exits 0 at 844x390) **is not met on this branch alone, and cannot be met within W1-UI's Owns.**
Three of the files it needs are protected (main.gd: integrator; inventory_ui.gd: W2-SCREENS; hunt_hud.gd: W2-HUD).
The fix is one patch file: `docs/orchestration/reports/claude-mmo-w1-ui-hooks.patch`. It contains hook 1 (the canvas fit
in main.gd), hook 5 (bag columns), hook 6 (portrait HUD), and, new this pass, the bag's level line. Apply it in one commit,
not in parts. `git apply --check` passes on HEAD, and the three files are byte-identical to the base tip 8d872e3
(`git diff --quiet HEAD claude/mmo-overhaul -- <the three files>` exits 0), so it applies there too.

| If the patch is missing or partial | What players see | Lab line without it |
|---|---|---|
| bag level line (inventory_ui.gd:439) | The bag says `Survivor · Lv. 1`; the HUD and atlas say `Lv. 0` | `[uireal] FAIL bag: profile shows the player level Lv. 0 like the HUD and atlas (got "Survivor / Survivor  ·  Lv. 1")` (`lab1600x900_r30_nohooks_notheme_glc.log`, exit 1) |
| hook 1 alone, without hook 5 | On a landscape phone the bag's Legs/Ring column and its close button are cut at the right edge | `[uireal] FAIL bag: equip_col [P: (576.0, 114.0), S: (280.0, 372.0)] inside the 844x390 view`, `[uireal] FAIL bag: close_btn [P: (812.0, 12.0), S: (44.0, 44.0)] inside the 844x390 view` (`lab844x390_r26_nohooks.log`) |
| hook 1 alone, without hook 6 | On a 390x844 phone HARBOUR sits on SKILLS and CLAIM sits on the quest card | `[uireal] FAIL hud: SKILLS#7 [P: (244.02, 750.0), ...] overlaps HARBOUR#9 [...]`, `[uireal] FAIL hud: CLAIM#11 [P: (310.422, 234.0), ...] overlaps quest [...]` (`lab390x844_r23_nohooks.log`) |

With the whole patch applied, the lab prints `[uireal] PASS` and exits 0 at 1600x900, 844x390, 667x375 and 390x844
(checklist below). I applied it, ran those, and reverted it. **ui-level-01 is partial** until the patch lands: the HUD,
atlas, fatigue panel and skills agree on one level, but the bag only does with the patch.

## Review 5 findings and what changed

| # | Finding | What I did | Check that catches it |
|---|---|---|---|
| 1 | Blocker: lab red at 844x390; the fix is in protected files | Not fixable inside Owns (see above). The hooks are now one file, `claude-mmo-w1-ui-hooks.patch`, so they land as one commit. Lab PASS with it at all four sizes. Without it the lab is red at every size, now including 1600x900 (finding 2) | The bag and HUD lines in the table above |
| 2 | Major: bag shows `Lv. 1`, HUD and atlas `Lv. 0`; ui-level-01 listed as closed | Bag line added to the patch: `World.pioneer_level + 1` -> `LevelDisplay.player_label()`. ui-level-01 marked partial. With the patch the bag shows `Survivor · Lv. 0` (`r27_hooks_glc/bag_1600x900.png`, `r28_hooks/bag_844x390.png`) | Lab: the bag's profile must end with `LevelDisplay.player_label()`. Without the patch: the FAIL line above. With it: PASS |
| 3 | Minor: every HUD hex is FOCUS_ALL; controller path untested | HexButton now defaults to `FOCUS_NONE`, so the HUD's hexes (hunt_hud builds them with the defaults) can never hold focus or take Space and the arrows. The station menu, the one hex menu that calls `focus_first`, sets `FOCUS_ALL` on its hexes. `UiTokens.force_focus` lets a test run the controller path without a joypad | t_ui `_test_controller_focus`: `[t_ui] controller focus: menu opens on hex 0, ui_right x2 -> hex 1,1, after close: <Object#null>; HUD hex focus=false`. With the old `FOCUS_ALL` default it fails: `[t_ui] FAIL a HUD hex (HexButton defaults) takes no focus from grab_focus or a click` (`t_ui_r27_oldfocus.log`, exit 1). Note: Godot only navigates between controls under the same root Control, so the arrows could not reach a HUD hex from the station menu (a separate root). The real risk was focus landing on a HUD hex at all, which the default now rules out |
| 4 | Minor: white symbols built per pixel in GDScript | Deleted `white_symbol` and its cache. One shared canvas material (`HexButton.white_material()`: rgb from the draw's tint, alpha from the texture) whitens the icon on the GPU. HexButton applies it itself unless `color_icon`; the skills rows, craft station tabs, plate knife and character cards set it. `HexButton.symbol()` now returns the icon itself | t_ui: `HexButton.symbol(["club"])` is the icon, and a skills symbol carries the shared material. Lab (pixels): `[uireal] skills white symbols: 12 checked, most coloured 0.00` and `[uireal] charcreate white symbols: 8 checked, most coloured 0.00` (1600x900). HUD shots match the CPU version (`r28_hooks/hud_844x390.png` against `r25_hooks_glc/hud_844x390.png`) |
| 5 | Minor: desktop cards have ~130 px of empty middle | The head-start skill's white symbol (56 px, from `SkillsSheet.SYMBOLS`) sits centred in that band. Phone cards keep the skill name alone (no room) | Lab: every desktop card must show a symbol inside the card: `[uireal] charcreate cards: rows=2 title_y_spread=0.0 start_y_spread=0.0 symbols=8` (1600x900). Shot `r27_hooks_glc/charcreate_1600x900.png` |
| 6 | Minor: craft header hint cut in portrait | Hidden on every phone canvas, not only portrait: the new gate also caught it cut at 667x375 (`"...fills once per it..."`). The station tabs already show where each station is | Lab: the hint must be hidden or fit. Before the compact change: `[uireal] FAIL craft: header hint "Hand recipes craft anywh" fits its 418 px, or is hidden` (`lab667x375_r28_hooks.log`, exit 1). After: PASS (`lab667x375_r29_hooks.log`) |
| 7 | Minor: gate geometry in production screens; const below functions | `MapScreen.layout_rects` moved into the lab (`atlas_blocks`); map_screen is 403 lines. `legend_col_w` and `phone_legend_y` stay: `_draw` and `_layout` use them. skills_sheet has no gate-only code: `panel_rect`, `is_sheet` and `scrollbar_reserve` drive its own layout. `STORY_TIGHTEN` and the new `CARD_SYMBOL_PX` are at the top of character_creation.gd; HexButton's `CAPTION_PX` and its static var moved to the top too | Lab still checks the atlas blocks: PASS at all four sizes |
| 8 | Minor: the token theme restyles protected screens | Compared with the theme on and off (`--no-theme`, new lab flag) at 1600x900. **Bag:** the only change is the gear buttons `1 2 3` and the close `×`. They are flat without the theme and get the rounded, bordered button style with it (`r30_nohooks_notheme_glc/bag_1600x900.png` against `r27_hooks_glc/bag_1600x900.png`). **Animal screen:** no visible difference; its buttons carry their own style overrides. The lab now saves an animal-screen shot on every run (not gated). It showed an unrelated, theme-independent bug, listed under "For W2-SCREENS" | Shots inspected (below). The lab prints `[uireal] animals (protected, not gated): screen rect [P: (0.0, 0.0), S: (0.0, 0.0)], backdrop (0.0, 0.0)` |

## Acceptance checklist

Runs with the patch applied (then reverted):

| Item | Output line (log) |
|---|---|
| 1600x900, web renderer | `[uireal] phone=false min_font_px=13 logical_width=1600 window_pt=1600x900 min_pt=13.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shot_only=animals shots=.../w1/ui/r27_hooks_glc` (`lab1600x900_r27_hooks_glc.log`, exit 0). Code: 8355ec8 except two lines it lacked (the animals print and a guard that skips the white check on phone cards) and the craft hint rule (`is_narrow` then, `is_compact` now). None of them changes anything at 1600x900 |
| 844x390, web renderer, final code | `[uireal] phone=true min_font_px=12 logical_width=844 window_pt=844x390 min_pt=12.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shot_only=animals shots=.../w1/ui/r29_hooks_glc` (`lab844x390_r29_hooks_glc.log`, exit 0) |
| 844x390, Forward+ | Same phone line, then `[uireal] PASS ... shots=.../w1/ui/r28_hooks` (`lab844x390_r28_hooks.log`, exit 0; craft hint still shown there, before the compact change) |
| 667x375 (macOS opens 668x376), final code | `[uireal] window=668x376 logical=804x453 content_scale=(804, 453)`, `[uireal] phone=true min_font_px=9 logical_width=804 window_pt=668x376 min_pt=9.97 floor_pt=9.97 (...)`, `[uireal] PASS ... shots=.../w1/ui/r29_hooks` (`lab667x375_r29_hooks.log`, exit 0) |
| 390x844 | `[uireal] phone=true min_font_px=12 logical_width=390 window_pt=390x844 min_pt=12.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,craft_detail,skills,atlas,radial,plate,bag,charcreate shot_only=animals shots=.../w1/ui/r28_hooks` (`lab390x844_r28_hooks.log`, exit 0). Same code note as 1600x900; `is_narrow` implies `is_compact`, so the hint rule is unchanged here |

Runs on the branch as it is (no patch):

| Item | Output line (log) |
|---|---|
| 1600x900 without the patch (and without the theme) | `[uireal] FAIL bag: profile shows the player level Lv. 0 like the HUD and atlas (got "Survivor / Survivor  ·  Lv. 1")`, exit 1; nothing else fails (`lab1600x900_r30_nohooks_notheme_glc.log`) |
| 844x390 without the patch | The two bag lines in the table at the top (`lab844x390_r26_nohooks.log`, earlier code, same bag geometry). The bag level line now fails there too |
| t_ui (`t_ui_r30.log`) | `[t_ui] controller focus: menu opens on hex 0, ui_right x2 -> hex 1,1, after close: <Object#null>; HUD hex focus=false`, `[t_ui] skill symbols: 12, thinnest silhouette 0.16`, `[t_ui] scanned 23 owned files: emoji=0 small_font=0`, `[t_ui] draw_centered: 40 px at x=100 starts at 80.0`, `[t_ui] radial above view: centres 150.4 px apart (hex 64)`, `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`, `[t_ui] atlas legend: 8 kinds, min colour distance 0.35`, then `[t_ui] PASS` (exit 0) |
| Existing suite (`run_all_r30.log`) | `[tests] PASS` (exit 0) |
| Smoke (`smoke_r30.log`, `tools/smoke.sh --no-import` through gslot) | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` then `SMOKE PASS` |
| Merge | `git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul` exits 0 and prints only the tree id |

Still true from earlier passes (unchanged code paths, lines in the logs named): skills rows `10/12` at 844x390,
`12/12` at 667x375 and 1600x900, `8/12` at 390x844 (all four r27-r29 logs); skills text clears the scrollbar
(`[uireal] skills: rightmost text 790, scrollbar starts 820`, 844x390); landscape Craft pinned
(`[uireal] craft sheet: CraftOne [P: (460.0, 314.0), S: (180.0, 64.0)] in footer=true vscrolls=3`); card
alignment `title_y_spread=0.0 start_y_spread=0.0` at all four sizes; the gate fails without the fit (`[t_ui] gate:
844x390 without fit -> 2 failures`). The spec writes `'Lv —'`; the screens print `Lv. —`, the one level format.

## Screenshots inspected (Read tool), this pass

- `r27_hooks_glc/charcreate_1600x900.png`: each card has a white symbol centred between story and `Starts:`
  (club, belt, plank, pick, thread, herbs, skewer, wheat). Titles and head starts still level across each row.
- `r27_hooks_glc/skills_1600x900.png`, `r28_hooks/skills_844x390.png`: all row symbols white, same as before the shader.
- `r27_hooks_glc/craft_1600x900.png`: station tab symbols white, tab text keeps its gold/grey/white colours,
  the selected tab keeps its teal fill (the material only changes textures). Hint shown on desktop.
- `r29_hooks_glc/craft_844x390.png`, `r28_hooks/craft_390x844.png`: no hint; `Craft · By hand` and Close clear.
  `r28_hooks/craft_668x376.png` shows the cut hint the gate caught (`...once per it...`).
- `r27_hooks_glc/bag_1600x900.png`, `r28_hooks/bag_844x390.png`: `Survivor · Lv. 0`, matching the HUD's `Lv. 0 5.0%`.
  `r30_nohooks_notheme_glc/bag_1600x900.png`: `Lv. 1` (no patch) and flat gear buttons (no theme).
- `r27_hooks_glc/hud_1600x900.png`, `r28_hooks/hud_844x390.png`: rail symbols white; identical to `r25_hooks_glc/hud_844x390.png`
  (CPU whitening). ANIMALS keeps its colour dino, as hunt_hud sets `color_icon` there.
- `r27_hooks_glc/animals_1600x900.png`, `r30_nohooks_notheme_glc/animals_1600x900.png`, `r28_hooks/animals_844x390.png`,
  `r28_hooks/animals_390x844.png`: theme on and off look the same. With no backdrop, the world shows through, the title sits on the
  vitals, the ACTIVE row covers the quest card and minimap, and at 844x390 CLOSE covers HARBOUR (see "For W2-SCREENS").

Earlier passes' shots (r13-r26) are listed in git history (this file at 5c305ef).

## Integrator hooks

1. **Apply `docs/orchestration/reports/claude-mmo-w1-ui-hooks.patch` in one commit** (`git apply` it on the merged
   branch). It holds hook 1 (main.gd: `DisplayMode.install(get_tree().root)` and `DisplayMode.install_theme()` at the top
   of `_ready`), hook 5 (inventory_ui.gd: three equipment columns when four do not fit, plus the level line
   `"%s\n%s  ·  %s" % [name, occupation, LevelDisplay.player_label()]`), and hook 6 (hunt_hud.gd: on `is_phone`, the
   context row starts at the left one row up, and CLAIM goes under the quest card). Afterwards run the lab at 1600x900, 844x390,
   667x375 and 390x844 and require `[uireal] PASS` with exit 0 at each. Do not land hook 1 without the rest (table at the top).
2. `game/scripts/ui/hunt_hud.gd:68` (W2-HUD): `set_anchors_preset(Control.PRESET_FULL_RECT)` ->
   `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`. Independent of 1.
3. `game/tests/run_all.gd`: run `res://tests/t_ui.gd` and require `[t_ui] PASS`. Independent of 1.

## For W2-SCREENS and the owner UI pass

- **Animal screen has no backdrop** (`game/scripts/ui/animal_screen.gd:16`, protected). It calls `set_anchors_preset(Control.PRESET_FULL_RECT)`
  inside the tree, which keeps its empty rect. The lab measures it as `screen rect [P: (0.0, 0.0), S: (0.0, 0.0)], backdrop (0.0, 0.0)` at every
  size, so its dim ColorRect and sheet Panel draw nothing. This is the same bug as hook 2 and the one fixed in skills_sheet and map_screen.
  Suggested line: `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`. I did not run it, so it is unverified. The theme plays no part
  (same shot with `--no-theme`).
- The token theme is merged into the engine default theme, so unstyled Buttons in protected screens pick it up. Seen: the bag's
  gear and close buttons. Re-check the animal screen after its backdrop is fixed; the lab saves `animals_<w>x<h>.png` on every run.

## Labs to register

- `ui_real_capture_lab` (`game/scripts/dev/ui_real_capture_lab.gd` + `game/scenes/dev/ui_real_capture_lab.tscn`).
  Windowed: `--resolution 844x390 -- --lab=ui_real_capture_lab --shot-dir=DIR`, also 667x375, 390x844 and 1600x900
  (add `--rendering-method gl_compatibility` for the web renderer). `--no-fit` is the gate's self-test and must exit 1 on a phone
  window; `--no-theme` is for before/after shots. Both flags only work while main.gd does not install the fit and theme itself
  (that is, before the patch; after it main.gd does both before the lab starts).
  **Register it as red until the patch lands:** on the branch alone it exits 1 at every size (bag level, plus bag
  columns on landscape phones and HUD overlaps in portrait).

## What shipped (whole package)

- `DisplayMode`: phone canvas fit (`logical_size`, `install`, `fitted_size`, notch-aware landscape
  floor), runtime token theme (`build_theme`, `install_theme`).
- `UiTokens`: `is_phone` (base meaning), `is_narrow` (portrait), `is_compact` (phone type and owned
  landscape layouts), `draw_centered`, 12 px `TYPE_MIN`, focus helpers with `force_focus` for tests, `hud_reserved`.
- Screens: craft (three columns plus a pinned Craft footer on landscape, one pane on portrait, `Lv. —`,
  stat lines, no header hint on phones), skills (aligned grid, pinned header, edge-to-edge two-column sheet on landscape phones),
  atlas (north-up, distinct legend, display names, N marker), character creation (name, story, skill symbol and head start
  on desktop cards with aligned rows; fit-independent), gather radial (the whole ring turns), plates (opaque
  pill, centred glyphs), white symbols through one shader material, HexButton with a focus ring (focusable where a menu opts in),
  held-tool slot placement, `LevelDisplay` (levels, item names, stat lines).
- `ui_real_capture_lab` (real island, root viewport, eight gated screens plus an animal-screen shot, block/overlap/type/row/
  alignment/white-symbol/level gates) and `t_ui`.

## Assumptions (`# ASSUMPTION:` in code unless noted)

- `display_mode.gd` `LANDSCAPE_MIN_W := 804.0`: the bag's three columns (with the patch) need about 804 usable
  px. Narrower landscape phones get 804 px at a smaller scale: 10 pt smallest text on a 667 pt SE,
  9.6 pt on a 640 pt Android, and about 11.2 pt on a notched 844 pt iPhone (its ~47 pt side insets leave
  750 pt usable, so the canvas is ~905x418). Lower the floor when W2 narrows the bag.
- `display_mode.gd` `side_inset_px` / `MIN_USABLE := 0.75`: on mobile the side safe-area insets come off
  before the floor applies; the safe area never leaves under 75 % of the width usable. Unit-tested only.
- `held_item_slot.gd`: mirrors hunt_hud's rail (four 64 px hexes, 10 px apart, 96 px up). On landscape
  phones the slot stacks above the last rail hex. On portrait it sits 24 px higher to clear the level line.
- `ui_real_capture_lab.gd` `hud_blocks`: the vitals, quest and level-line rects mirror hunt_hud.gd `_draw`
  and `_draw_quest`.
- `skills_sheet.gd` SYMBOLS: item symbols stand in for skill art (W1-ICONART). Ranged = `cactus_spine`,
  Weapon / Tools = `work_pick`. The character cards reuse them.
- `craft_ui.gd` STATIONS: crock pot uses the `boiled_meat` cauldron symbol and campfire uses `skewer`.
- `level_display.gd`: the pioneer level is the player level, shown as stored (`Lv. 0` at start).
- `character_creation.gd` `STORY_TIGHTEN := 8`. Phone cards show the head-start skill without `Lv. 20` or a symbol.
- `hex_button.gd` focus: only the station menu opts its hexes into focus. The gather and station radials do not call
  `focus_first`, so a controller does not drive them yet (ui-gamepad-01 is shared with W2-SCREENS).
- No `game/ui/deadfront_theme.tres`: the theme is built from tokens at runtime.

## Not done / risks

- **Acceptance item 1 and ui-level-01 wait on the patch** (top of this file). The plan owner can instead re-scope item 1
  to leave out the protected bag; I have not done that, since it is not my call.
- **Phone fit is not done until one device or mobile-web run.** No device here, and no web export on this shared
  machine. The notch path (`side_inset_px`) and `DisplayServer.screen_get_scale()` on mobile web are unit-tested only.
  On the device, record the boot line `[display] window (W, H) -> logical (w, h)` and the lab's `[uireal] phone=... min_pt=...` line.
- On a notched iPhone the 12 px floor is about 11.2 pt on glass (Assumptions).
- The white-symbol shader is checked on Forward+ and the gl_compatibility renderer on macOS (Metal), not on a phone GPU.
- Protected bag at 1600x900: the four-column Legs/Ring slots touch the panel's right border. The bag keeps 64 px slots, so on a
  390 pt tall landscape phone its fourth row and food slots need a scroll.
- Protected HUD: the minimap turns with the camera while the atlas is north-up (W2-HUD). `UiTokens.hud_reserved` and the lab's
  `hud_blocks` mirror hunt_hud geometry; replace both with rects the HUD exports.
- Animal screen backdrop (For W2-SCREENS above).
- skills_sheet is 315 lines (base 159): the grid, pinned header, scrollbar reserve and landscape sheet. None of it is gate-only.
- The atlas card shows the home island as `Lv. 10` (its tier in world data), while starter creatures are Lv. 1. That is a data question.
- The sync commit d2c8e8a copied 11 docs files instead of merging. All 11 are identical to the base tip.
