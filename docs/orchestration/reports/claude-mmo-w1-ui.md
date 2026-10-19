# W1-UI report (claude, branch claude/mmo-w1-ui)

## What shipped

- `DisplayMode.logical_size/fit/install`: a portrait phone (narrower than 720 pt) gets one logical px per point, so `UiTokens.is_phone` is true at runtime. A 1600x900 desktop keeps the 1600x900 design canvas. Closes ui-phone-01.
- `UiTokens`: 12 px type floor (`TYPE_MIN`), `draw_centered` (used by hex_button, status_glyph, gather_ring, respawn_ring, eat_progress, held_item_slot and craft_card) and controller focus helpers (`focus_first`, `first_focusable`). `UiSymbols` (new, `ui_symbols.gd`): white symbol icons in place of system emoji. `UiTheme` (new, `ui_theme.gd`): `build()`/`install()`, a token Theme merged into the default theme at runtime. HexButton is focusable and draws a focus ring.
- ContextRadial turns the whole ring when it hits the view edge, instead of clamping each hex onto the same spot.
- Craft: a recipe the bag cannot make reads `Lv. —`; the card shows stat lines and has one action row; the background is opaque so the HUD vitals do not show through. On a phone it shows one pane at a time: a horizontal chip row of stations over the recipe list, then the detail as a sheet with a Back button, and Craft / Craft ×5 pinned in a 64 px footer.
- Skills sheet: an aligned grid inside the content area, with an opaque panel. It is `top_level` because its host HUD has zero size.
- Atlas: north-up, distinct legend colours, display names. On a phone the layout is header, one island card, map, a two-row legend, zoom, then actions.
- Creature plates: a backing pill, and the status glyph letters are centred inside their rings.
- `LevelDisplay`: the single source for the player level and the one level format (`Lv. N`, `Lv. —`). Fatigue panel, atlas, craft, skills, plates and the gather radial all print through it.
- `set_anchors_and_offsets_preset` fixes for owned screens whose rect was empty: gather_radial, map_screen, pickup_toast, station_menu and skills_sheet.
- New `game/tests/t_ui.gd` and a real-scene capture lab `ui_real_capture_lab`.
- Cleanup: the interrupted WIP commit had picked up 15 unrelated `.uid` files. They are now untracked again (commit f3421e4).

## Acceptance checklist (rerun 2026-10-19 after the review, logs in scratchpad/w1/ui/*_r6.log)

| Item | Output line |
|---|---|
| Lab at 390x844 is a phone with a 12 px floor | `[uireal] phone=true min_font_px=12 logical_width=390 window_pt=390x844 (...)` then `[uireal] PASS screens=hud,craft,craft_detail,skills,atlas,radial,plate,charcreate shots=.../w1/ui/r6` (exit 0) |
| Same, web renderer (gl_compatibility) | same `phone=true min_font_px=12` line, `[uireal] PASS ...r6_glc` (exit 0) |
| Lab at 1600x900 is desktop with width 1600 | `[uireal] phone=false min_font_px=13 logical_width=1600 window_pt=1600x900 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,charcreate ...` (exit 0) |
| Gate fails without the canvas fit (review blocker 1) | `--no-fit` at 390x844: `[uireal] phone=false min_font_px=3 logical_width=1600 window_pt=390x844`, `[uireal] FAIL a portrait 390x844 pt window must get the phone canvas (is_phone is false, logical width 1600)`, `[uireal] FAIL phone-width window: text at least 12 px on screen (got 3)` (exit 1). Unit: `[t_ui] gate: 390x844 without fit -> 2 failures` |
| Phone craft: Craft pinned, one scroll pane (review major) | `[uireal] craft sheet: CraftOne [P: (16.0, 768.0), S: (175.0, 64.0)] in footer=true vscrolls=1` |
| Skills text clears the scrollbar | `[uireal] skills: rightmost text 1136, scrollbar starts 1156` (1600x900), `rightmost text 338, scrollbar starts 358` (390x844) |
| No emoji, no font literal below 12 in owned ui files | `[t_ui] scanned 25 owned files: emoji=0 small_font=0` |
| draw_centered unit test | `[t_ui] draw_centered: 40 px at x=100 starts at 80.0` |
| Radial with an anchor above the view keeps hexes apart | `[t_ui] radial above view: centres 150.4 px apart (hex 64)` |
| NaN anchor gives a finite ring | `[t_ui] NaN anchor -> [(827.6746, 342.8006), (827.6746, 493.1994)]` |
| Hex focus: accept presses, a tap drops focus | `[t_ui] hex focus: accept pressed=2, focus after tap=false` |
| Craft card 'Lv. —' | `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`; lab: `[uireal] craft rows=35 with_lv_dash=35 first="Lv. — · 2.0s  ·  Missing items"` |
| Distinct atlas legend colours | `[t_ui] atlas legend: 8 kinds, min colour distance 0.35` |
| t_ui overall | `[t_ui] PASS` |
| Existing suite | `[tests] PASS` (run_all.gd, exit 0) |
| Smoke | `SMOKE PASS` (tools/smoke.sh --no-import through gslot) |

The spec text says `'Lv —'`. It now reads `Lv. —` because the review asked for one level format and every other screen, including the protected HUD, prints `Lv. N`. The dash meaning is unchanged.

## Review findings and what changed

| Finding | Fix | Check that catches it |
|---|---|---|
| Blocker: gate passes with no canvas fit | `gate_failures()` in the lab: a window narrower than 720 pt must have `phone=true` (when portrait) and text of at least 12 pt. The size is in points (`DisplayMode.window_points`). | `--no-fit` run exits 1 (above); t_ui `_test_gate_verdict` |
| Blocker: landscape charcreate at 5-7 px | `phone_landscape` uses `DisplayMode.is_phone_landscape(window_points)`, not the logical canvas. Seen: `r6/charcreate_844x390.png` shows 8 readable cards and 34 px type | t_ui: `is_phone_landscape(844x390)` true, `(1947x900)` false |
| Major: phone craft has 3 nested scroll panes | One pane at a time. Stations become a chip row, recipes fill the screen, the detail opens as a sheet, and Craft / Craft ×5 sit in a 64 px footer | lab: `vscrolls=1`, CraftOne in the footer and inside the view |
| Minor: HUD overlaps once the hook lands | Not fixable here (hunt_hud.gd and touch_controls.gd are protected). See Integrator hooks: land `DisplayMode.install` with or after W2-HUD | none in this package |
| Minor: SP label under the scrollbar | `ScrollPad` margin = scrollbar width + 8 | lab `skills:` line; t_ui `scrollbar_reserve` |
| Minor: legend tree swatch, harbour dot, phone legend overlap | Light ring round every swatch. The harbour is a square with a dark edge on the map and in the legend. The phone legend uses 3 columns with labels ellipsised to the column | t_ui: ring luminance, each phone label fits its column; seen in `r6/atlas_390x844.png` |
| Minor: translucent plate pill | `PILL_ALPHA` 0.9. In `r6/plate_zoom_1600x900.png` the world label behind is now a faint shape, not readable text | t_ui `PILL_ALPHA >= 0.88` |
| Minor: "1 recipes", Lv format | `CraftUI.recipe_count`; every level string goes through `LevelDisplay.label`/`NONE` | t_ui: plural check; a scan for hand-written `Lv %d`/`Lv —` strings in owned files |
| Minor: ui_tokens god file | Theme moved to `UiTheme` (ui_theme.gd), symbols to `UiSymbols` (ui_symbols.gd). ui_tokens.gd drops from 314 to 221 lines | compile + t_ui `_test_theme` |
| Minor: NaN anchor returns [] | A non-finite anchor centres the ring; an empty best falls back to the unturned ring | t_ui NaN line |
| Minor: focus test too thin | push_input `ui_accept` to a focused HexButton (pressed), a mouse tap (focus dropped), `first_focusable` skips hidden and non-focusable controls | t_ui hex focus line |

## Screenshots inspected (Read tool)

Directory: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/ui/r6/` (plus `r6_glc/`)

- `craft_390x844.png`: a chip row (By hand, Workbench, then a partly visible next chip), then 10 recipe rows reading `Lv. — · Ns · Missing items`. Only one vertical scroll is visible.
- `craft_detail_390x844.png` and `r6_glc/craft_detail_390x844.png`: Back to recipes, result, stats, ingredients and `Needs Stone`. Craft and Craft ×5 sit in the footer at the bottom of the screen (disabled because the bag is empty).
- `craft_1600x900.png`: three columns. The tabs read `1 recipe`/`N recipes` and the Craft buttons sit in the detail. The header hint line is not visible here (see Not done).
- `skills_1600x900.png`: `SP 0` and the row right edges end left of the scrollbar.
- `atlas_390x844.png`: a 3-column legend with no overlap. The harbour is a blue square. The tree swatch has a light ring and is visible.
- `plate_zoom_1600x900.png`: B, K and G sit inside their rings. The world label behind the pill shows only as a faint shape.
- `charcreate_844x390.png`: 8 cards in 4 columns with readable names and skills, and the body/name/start row at the bottom.

## Left for W2-HUD (seen in screenshots, files protected for this package)

- In the phone HUD (`radial_390x844.png`) several labels overlap: SKILLS and the HARBOUR hex, HANDS/DEBUG and the `Lv. 0 5.0%` line, and CLAIM over the orders card. All of these come from hunt_hud.gd and touch_controls.gd.
- The HuntHud root has zero size (hunt_hud.gd:68 uses `set_anchors_preset` in `_ready`). The lab reports this as `[uireal] KNOWN hud: ...` and does not fail on it. Delete the `KNOWN_ZERO_SIZE` entry in ui_real_capture_lab.gd when the fix lands.

## Assumptions

- `skills_sheet.gd:9`: item symbols stand in for skill art until skill icons exist.
- `level_display.gd:5`: the pioneer level (`World.pioneer_level`) is the one player level.
- `display_mode.gd` shortcut: landscape phones and portrait tablets keep the 1600x900 design canvas. Only character creation has a landscape layout. At 844x390 the lab prints `[uireal] WARN landscape phone 844x390 pt: smallest text 5 pt ...` and does not fail. Landscape is the shipped handheld orientation, so this is the main gap left (see Not done).
- No `game/ui/deadfront_theme.tres`. The theme is built from tokens at runtime by `UiTheme.build()`, so one source of truth stays in code.
- `ui_theme.gd` and `ui_symbols.gd` are new files in `game/scripts/ui/`, a directory this package does not own. The review asked for the split. No other package creates these names.

## Integrator hooks

In `game/scripts/core/main.gd` `_ready()`, first lines. Land these together with, or after, the W2-HUD overlap fixes: with the phone canvas on, the protected HUD overlaps CLAIM/ORDERS, HARBOUR/SKILLS and HANDS/DEBUG/`Lv. 0 5.0%` (see Left for W2-HUD). Until then, gate the first line behind a flag:

```gdscript
	# ASSUMPTION: flag name; drop the condition once W2-HUD's phone overlap fixes are merged.
	if OS.get_cmdline_user_args().has("--phone-canvas") or ProjectSettings.get_setting("deadfront/ui/phone_canvas", false):
		DisplayMode.install(get_tree().root)
	UiTheme.install()
```

In `game/tests/run_all.gd` (or the test runner list): run `res://tests/t_ui.gd` and require `[t_ui] PASS`.

For W2-HUD, in `game/scripts/ui/hunt_hud.gd:68`: replace `set_anchors_preset(Control.PRESET_FULL_RECT)` with `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`.

## Labs to register

- `ui_real_capture_lab` (`game/scripts/dev/ui_real_capture_lab.gd` + `game/scenes/dev/ui_real_capture_lab.tscn`). Run windowed: `--resolution 390x844 -- --lab=ui_real_capture_lab --shot-dir=DIR`. Add `--no-fit` for the gate's self-test, which must exit 1 at 390x844.

## Not done / risks

- The phone HUD overlaps listed above are outside this package.
- Landscape phones (844x390) still use the 1600x900 canvas. Every screen except character creation draws text at about 5 pt there. Fixing this needs a landscape layout per screen, including the protected HUD. That is outside the review's scope, and the lab prints a WARN for it.
- The desktop craft header hint (`Hand recipes craft anywhere...`) is not visible in `craft_1600x900.png`. It was already like this before this pass and was not investigated.
- Not tested on a real device. Windowed runs: Forward+ at 390x844, 1600x900 and 844x390, gl_compatibility at 390x844.
- The screenshots also show untextured stand-in props (basket crate, workbench, harbour slab). They belong in the asset replacement register, not in this UI package.
