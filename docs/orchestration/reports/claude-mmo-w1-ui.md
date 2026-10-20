# W1-UI report (claude, branch claude/mmo-w1-ui)

Rerun 2026-10-19 after the owner's ruling that the phone view is landscape. The phone check is now
844x390 (plan-register W1-UI acceptance, STATUS owner decision). The earlier passes built the phone
canvas for portrait 390x844 only. At 844x390 that gave `phone=false`, the skills panel over the
vitals, a broken atlas and a broken character creation screen (`r7/` shots). This pass fixes all of that.

## What shipped

- **Phone canvas, either way up.** `DisplayMode.logical_size` gives a phone one logical px per point:
  844x390 pt becomes an 844x390 canvas (iPhone landscape pixels at 3x as well). A 1600x900 desktop
  keeps 1600x900, and a portrait tablet gets a canvas 1000 px wide. `UiTokens.is_phone(view)` is now
  `is_narrow(view) or view.y < SHORT_MAX`: narrow (portrait) or short (landscape). The new
  `UiTokens.is_narrow` picks the one-pane portrait layouts. `hud_reserved` has a landscape set: a
  vitals band, the map/quest/rail column on the right, and the left rail. Closes ui-phone-01.
- **Landscape layouts (844x390)** for the screens this package owns:
  - Craft keeps its three columns. Craft / Craft ×5 are pinned in a footer under them, because the
    detail column is about 230 px tall and the buttons were below its fold.
  - Skills runs from under the vitals band to the bottom edge with every column visible. The panel
    is 282 px tall instead of 200: three full rows instead of two.
  - Atlas: one island card, the map placed between the card and the legend and above the buttons.
    Before this, "Harbour routes" was drawn over the island cards.
  - Character creation fits on one screen: 4x2 cards, then Body / name / Enter on one row. Before
    this it used 34 px type and showed only one row of cards.
- **Character cards** on every size now have three lines: the name (24 px on desktop), the story,
  and a gold `Starts: <skill> Lv. 20`. Before, each card was one 16 px string in a large empty card.
- Gather radial: the node name and its level share one backing. The teal `Lv. 1` used to sit on the
  bright bush with nothing behind it. Plate pill alpha is now 0.96: the world label behind it was
  still readable at 0.9.
- Carried from the earlier passes, unchanged: the runtime token Theme (`DisplayMode.build_theme`/
  `install_theme`), white symbols (`HexButton.symbol`/`white_symbol`), `UiTokens.draw_centered` and
  the 12 px floor, the radial that turns the whole ring, focusable HexButton with a focus ring,
  `LevelDisplay` (`Lv. N`, `Lv. —`), craft stat lines, the atlas legend and display names, the plate
  pill and centred glyphs, the portrait one-pane craft, and `ui_real_capture_lab`.
- Fix: t_ui still expected landscape to keep the design canvas. The plan-sync commit had already
  changed `logical_size`, so t_ui failed on that commit. It is updated, and it passes now.

## Acceptance checklist (logs in scratchpad `w1/ui/`, final code)

| Item | Output line |
|---|---|
| Lab 844x390 (Forward+), `lab844_r12.log` | `[uireal] phone=true min_font_px=12 logical_width=844 window_pt=844x390 (smallest: craft .../CraftHint "Hand recipes craft anywh" 12.0 px)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,charcreate shots=w1/ui/r12` (exit 0) |
| Lab 844x390 web renderer (gl_compatibility), `lab844_glc_r10.log` | same `phone=true min_font_px=12 logical_width=844` line, `[uireal] PASS ... shots=w1/ui/r10_glc` (exit 0) |
| Lab 1600x900, `lab1600_r11.log` | `[uireal] phone=false min_font_px=13 logical_width=1600 window_pt=1600x900 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,charcreate shots=w1/ui/r11` (exit 0) |
| Portrait still works, `lab390_r10.log` | `[uireal] phone=true min_font_px=12 logical_width=390 window_pt=390x844 (...)` then `[uireal] PASS screens=hud,craft,craft_detail,skills,atlas,radial,plate,charcreate shots=w1/ui/r10` (exit 0) |
| Gate fails without the fit at 844x390, `lab844_nofit_r10.log` | `[uireal] phone=false min_font_px=5 logical_width=1947 window_pt=844x390`, `[uireal] FAIL a 844x390 pt phone window must get the phone canvas (is_phone is false, logical width 1947)`, `[uireal] FAIL phone window 844x390 pt: text at least 12 pt on screen (got 5)` (exit 1) |
| Landscape craft: Craft pinned and inside the view | `[uireal] craft sheet: CraftOne [P: (460.0, 314.0), S: (180.0, 64.0)] in footer=true vscrolls=3` |
| Skills text clears the scrollbar | `[uireal] skills: rightmost text 792, scrollbar starts 812` (844x390); `1136` / `1156` (1600x900) |
| Skills panel clears the vitals | the lab's vitals-overlap check passes at 844x390 and 1600x900 (it failed at 844x390 in `lab844_r7.log`: `FAIL skills panel [P: (8.0, 100.0), S: (828.0, 200.0)] clears the vitals block ...`) |
| Canvas unit lines, `t_ui_r11.log` | `[t_ui] canvas: 844x390 -> (844.0, 390.0) phone=true narrow=false; 1600x900 -> (1600.0, 900.0) phone=false`, `[t_ui] gate: 844x390 without fit -> 2 failures` |
| No emoji, no font literal under 12 | `[t_ui] scanned 23 owned files: emoji=0 small_font=0` |
| draw_centered | `[t_ui] draw_centered: 40 px at x=100 starts at 80.0` |
| Radial, anchor above the view | `[t_ui] radial above view: centres 150.4 px apart (hex 64)` |
| Craft 'Lv —' | `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`; lab: `[uireal] craft rows=35 with_lv_dash=35 first="Lv. — · 2.0s  ·  Missing items"` |
| Distinct legend colours | `[t_ui] atlas legend: 8 kinds, min colour distance 0.35` |
| t_ui | `[t_ui] PASS` (exit 0) |
| Existing suite, `run_all_r11.log` | `[tests] PASS` (exit 0) |
| Smoke, `smoke_r11.log` | `SMOKE PASS` (`tools/smoke.sh --no-import` through gslot) |

The spec writes `'Lv —'`. The screens print `Lv. —`, the one level format every screen uses (an
earlier review asked for that). The dash means the same thing.

## Screenshots inspected (Read tool)

Directory: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/ui/`

- `r8/craft_844x390.png` and `r10_glc/craft_844x390.png`: three columns. The full hint line
  fits. The Craft / Craft ×5 footer is under the detail column. No vitals: the screen is opaque.
- `r8/skills_844x390.png`: the panel starts under the vitals band, and Survival, Gathering and
  Butchering are fully visible with level, XP bar and owned count. No text over the vitals.
- `r8/atlas_844x390.png`: header, one island card, the map clear of the legend and of the buttons,
  7 legend rows with separate colours, Harbour routes, and zoom. Nothing overlaps.
- `r10_glc/charcreate_844x390.png`: 8 cards in 4 columns with a white name and a gold skill line.
  Body / Woman / Man / name / ENTER THE RIFT sit on one row inside the view.
- `r12/radial_844x390.png` and `r9/radial_1600x900.png`: "Berry Bush / Lv. 1" on one backing,
  next to the hex.
- `r12/plate_zoom_844x390.png`, `r9/plate_zoom_1600x900.png`: the B, K and G letters sit inside
  their rings. The label behind the pill shows only as a faint shape.
- `r9/craft_1600x900.png`, `r9/skills_1600x900.png`, `r9/atlas_1600x900.png`,
  `r11/charcreate_1600x900.png`: the desktop layouts are unchanged, apart from the new card hierarchy.
- `r10/charcreate_390x844.png`, `r10/atlas_390x844.png`: portrait is intact.
- `r8/hud_844x390.png` and `r12/radial_844x390.png` show the protected HUD's portrait phone branch
  running in landscape. See "Left for W2-HUD".

## Left for W2-HUD and W2-SCREENS (protected files; seen in the screenshots)

- Because `is_phone` is true at 844x390, `hunt_hud.gd` now takes its portrait phone branch there. The
  vitals strip stretches to the minimap. The quest card drops under the minimap onto HANDS/CLAIM and
  the `Lv. 0 5.0%` line (`r8/hud_844x390.png`). The fix is three lines, listed under Integrator hooks.
  Evidence that it works: `r7/hud_844x390.png` is the same 1:1 canvas with the desktop branch. It is
  clean: 300 px vitals and the quest card left of the map.
- `inventory_ui.gd:344,453,465` and `animal_screen.gd:77` also switch to their portrait layouts at
  844x390 (one column, slots about 155 px wide). Use `is_narrow` there as well. Not captured, so not verified.
- `HuntHud` root has zero size (`hunt_hud.gd:68`). The lab reports it as `[uireal] KNOWN hud: ...`.
  Delete `KNOWN_ZERO_SIZE` in the lab when that is fixed.
- World label pills (hunt_hud.gd:1327) draw over the survivor's name ("Harbour" over "Survivor").

## Assumptions

- `ui_tokens.gd` `SHORT_MAX := 500.0`: a canvas shorter than this is a landscape phone (the same
  bound as `DisplayMode.is_phone_landscape`, which also needs a 1.75:1 shape).
- `level_display.gd:5`: the pioneer level is the one player level.
- `skills_sheet.gd:9`: item symbols stand in for skill art.
- `ui_tokens.gd` `hud_reserved` mirrors hunt_hud geometry until W2-HUD exports rects. The landscape set was measured from `r8/hud_844x390.png`.
- No `game/ui/deadfront_theme.tres`: the theme is built from tokens at runtime, so one source stays in code.
- Landscape character creation uses 48 px controls, to fit 390 px of height. That is above `TARGET_MIN` 44 and below the AGENTS 64 px guideline.

## Integrator hooks

1. `game/scripts/core/main.gd` `_ready()`, first lines:
   ```gdscript
   	DisplayMode.install(get_tree().root)
   	DisplayMode.install_theme()
   ```
   Land this together with hook 2. If hook 2 cannot land yet, gate the first line behind a flag:
   `if OS.get_cmdline_user_args().has("--phone-canvas"):`. Without the canvas, landscape phones keep the 1947x900 canvas and 5 pt text.
2. `game/scripts/ui/hunt_hud.gd` (protected; W2-HUD or the owner): replace `UiTokens.is_phone(r)` with
   `UiTokens.is_narrow(r)` at lines 148, 916 and 1071 (also at 421 and 425 for the death card).
   Type sizes still follow `is_phone` through `UiTokens.body/meta/heading`.
3. `game/scripts/ui/hunt_hud.gd:68`: `set_anchors_preset(Control.PRESET_FULL_RECT)` ->
   `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`.
4. `game/tests/run_all.gd`: run `res://tests/t_ui.gd` and require `[t_ui] PASS`.
5. Merge: the only conflict with `claude/mmo-overhaul` is `docs/orchestration/mmo/STATUS.md` (the plan-sync commit copied it). Take overhaul's version. The code merges cleanly (`git merge-tree`).

## Labs to register

- `ui_real_capture_lab` (`game/scripts/dev/ui_real_capture_lab.gd` + `game/scenes/dev/ui_real_capture_lab.tscn`).
  Windowed: `--resolution 844x390 -- --lab=ui_real_capture_lab --shot-dir=DIR` (also 1600x900, 390x844).
  `--no-fit` is the gate's self-test and must exit 1 on a phone window.

## Not done / risks

- The protected HUD in landscape needs hook 2 (above). Until then, turning on the phone canvas trades
  5 pt text for overlapping HUD blocks.
- Not tested on a device or in desktop Chrome. Windowed runs only: Forward+ at 844x390, 1600x900 and 390x844, and gl_compatibility at 844x390.
- On desktop, a two-line card story has loose line spacing (`r11/charcreate_1600x900.png`). It is readable. Not investigated.
- The atlas card shows the home island as `Lv. 10`, its tier in world data, while starter creatures are Lv. 1. That is a data question, not a UI one.
