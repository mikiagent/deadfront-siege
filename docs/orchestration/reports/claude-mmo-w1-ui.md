# W1-UI report (claude, branch claude/mmo-w1-ui)

## What shipped

- `DisplayMode.logical_size/fit/install`: a portrait phone (narrower than 720 pt) gets one logical px per point, so `UiTokens.is_phone` is true at runtime. A 1600x900 desktop keeps the 1600x900 design canvas. Closes ui-phone-01.
- `UiTokens`: 12 px type floor (`TYPE_MIN`), `draw_centered` (used by hex_button, status_glyph, gather_ring, respawn_ring, eat_progress, held_item_slot and craft_card), white symbol icons in place of system emoji, `build_theme()`/`install_theme()` (a token Theme merged into the default theme at runtime), and controller focus helpers (`focus_first`). HexButton is focusable and draws a focus ring.
- ContextRadial turns the whole ring when it hits the view edge, instead of clamping each hex onto the same spot.
- Craft: a recipe the bag cannot make reads `Lv —`; the card shows stat lines and has one action row; the background is opaque so the HUD vitals do not show through.
- Skills sheet: an aligned grid inside the content area, with an opaque panel. It is `top_level` because its host HUD has zero size.
- Atlas: north-up, distinct legend colours, display names. On a phone the layout is header, one island card, map, a two-row legend, zoom, then actions.
- Creature plates: a backing pill, and the status glyph letters are centred inside their rings.
- `LevelDisplay`: the single source for the player level, used by the fatigue panel and the atlas.
- `set_anchors_and_offsets_preset` fixes for owned screens whose rect was empty: gather_radial, map_screen, pickup_toast, station_menu and skills_sheet.
- New `game/tests/t_ui.gd` and a real-scene capture lab `ui_real_capture_lab`.
- Cleanup: the interrupted WIP commit had picked up 15 unrelated `.uid` files. They are now untracked again (commit f3421e4).

## Acceptance checklist (run 2026-10-19 on this branch, logs in scratchpad/w1/ui/*_r5.log)

| Item | Output line |
|---|---|
| Lab at 390x844 is a phone with a 12 px floor | `[uireal] phone=true min_font_px=12 logical_width=390 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,charcreate shots=.../w1/ui/r5` (exit 0) |
| Lab at 1600x900 is desktop with width 1600 | `[uireal] phone=false min_font_px=13 logical_width=1600 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,charcreate ...` (exit 0) |
| No emoji, no font literal below 12 in owned ui files | `[t_ui] scanned 23 owned files: emoji=0 small_font=0` |
| draw_centered unit test | `[t_ui] draw_centered: 40 px at x=100 starts at 80.0` |
| Radial with an anchor above the view keeps hexes apart | `[t_ui] radial above view: centres 150.4 px apart (hex 64)` |
| Craft card 'Lv —' | `[t_ui] craft: 5 unmakeable hand recipes read 'Lv —'`; lab: `[uireal] craft rows=35 with_lv_dash=35 first="Lv — · 2.0s  ·  Missing items"` |
| Distinct atlas legend colours | `[t_ui] atlas legend: 8 kinds, min colour distance 0.35` |
| t_ui overall | `[t_ui] PASS` |
| Existing suite | `[tests] PASS` (run_all.gd, exit 0) |
| Smoke | `SMOKE PASS` (tools/smoke.sh --no-import through gslot) |

## Screenshots inspected (Read tool)

Directory: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/ui/r5/`

- `craft_1600x900.png`, `craft_390x844.png`: the panel is opaque and no text sits over the vitals. Every row reads `Lv — · Ns · Missing items`. On the phone the result, ingredients and Craft button sit below the fold of the result pane and need a scroll.
- `skills_1600x900.png`, `skills_390x844.png`: an aligned grid between the vitals and the map, with no text over the vitals. On the phone the long name `Weapon / To...` is cut off with an ellipsis.
- `atlas_1600x900.png`, `atlas_390x844.png`: north-up map with seven distinct legend dots. The phone layout has no overlaps.
- `plate_zoom_1600x900.png`, `plate_zoom_390x844.png`: the B, K and G letters sit fully inside their rings. The pill is translucent, so a world label behind it still shows faintly.
- `radial_1600x900.png`, `radial_390x844.png`, `charcreate_390x844.png`: the gather hex and its label are readable. Character creation fits the phone with nothing clipped.

## Left for W2-HUD (seen in screenshots, files protected for this package)

- In the phone HUD (`radial_390x844.png`) several labels overlap: SKILLS and the HARBOUR hex, HANDS/DEBUG and the `Lv. 0 5.0%` line, and CLAIM over the orders card. All of these come from hunt_hud.gd and touch_controls.gd.
- The HuntHud root has zero size (hunt_hud.gd:68 uses `set_anchors_preset` in `_ready`). The lab reports this as `[uireal] KNOWN hud: ...` and does not fail on it. Delete the `KNOWN_ZERO_SIZE` entry in ui_real_capture_lab.gd when the fix lands.

## Assumptions

- `skills_sheet.gd:9`: item symbols stand in for skill art until skill icons exist.
- `level_display.gd:5`: the pioneer level (`World.pioneer_level`) is the one player level.
- `display_mode.gd` shortcut: landscape phones and portrait tablets keep the 1600x900 design canvas.
- No `game/ui/deadfront_theme.tres`. The theme is built from tokens at runtime by `UiTokens.build_theme()`, so one source of truth stays in code.

## Integrator hooks

In `game/scripts/core/main.gd` `_ready()`, first lines:

```gdscript
	DisplayMode.install(get_tree().root)
	UiTokens.install_theme()
```

In `game/tests/run_all.gd` (or the test runner list): run `res://tests/t_ui.gd` and require `[t_ui] PASS`.

For W2-HUD, in `game/scripts/ui/hunt_hud.gd:68`: replace `set_anchors_preset(Control.PRESET_FULL_RECT)` with `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`.

## Labs to register

- `ui_real_capture_lab` (`game/scripts/dev/ui_real_capture_lab.gd` + `game/scenes/dev/ui_real_capture_lab.tscn`). Run windowed: `--resolution 390x844 -- --lab=ui_real_capture_lab --shot-dir=DIR`.

## Not done / risks

- The phone HUD overlaps listed above are outside this package.
- Phone craft needs a scroll to reach the Craft button.
- Not tested on a real device or in the web renderer (gl_compatibility); only the Forward+ desktop windowed runs above.
- The screenshots also show untextured stand-in props (basket crate, workbench, harbour slab). They belong in the asset replacement register, not in this UI package.
