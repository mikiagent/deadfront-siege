# W1-UI report (claude, branch claude/mmo-w1-ui)

## Fourth pass, 2026-10-20 (resumed after the usage limit)

- **Safe-area clamp (finished from the interrupted edit).** `DisplayMode.side_inset_px` returns 0 when
  the safe area is empty (not reported yet at boot). `logical_size` keeps at least `MIN_USABLE` = 75 % of
  a landscape phone's width usable, so a bogus inset can't shrink the canvas toward 1 px. t_ui:
  `a portrait safe area in landscape clamps to 1072x495 logical`.
- **Portrait HANDS caption** (owned, held_item_slot.gd) sat on the HUD's drawn `Lv. 0 5.0%` line. On
  `is_phone` canvases the slot lifts 24 px. The lab's `hud_blocks` now mirrors that drawn level line
  (hunt_hud.gd:975-977), so the gate checks it: `HeldItemSlot=310,648 64x82 ... level=309,746 65x15`
  at 390x844. Before the lift the slot spanned y 672-754, which overlaps the line.
- **New regression from the base branch, in a protected file.** The armor merge (836839a) gave the bag
  four equipment columns (Head/Body/Arms/Legs) on every non-`is_phone` canvas. A landscape phone needs
  868 px for that, so at 844x390 the Legs/Ring column and the close button run 12 px off the right edge
  (`r17/bag_844x390.png`). The lab catches it and exits 1 at 844x390 on exactly two lines (below).
  I did not raise `LANDSCAPE_MIN_W` to 868. That would put 12 px text at 11.67 pt on an 844 pt phone,
  and the spec's acceptance requires `min_font_px >= 12` there (on glass, not logical px). The fix
  belongs in inventory_ui.gd: integrator hook 5, tested in one run and then reverted.
- **Portrait HUD hook tested.** Hook 6 (hunt_hud.gd, protected) moves CLAIM under the quest card and
  puts the context row one row above the rail. With it the 390x844 lab passes every screen. It was
  applied for one run and then reverted.
- **Branch hygiene.** The sync commit d2c8e8a had copied STATUS.md, which conflicted with the base's
  8ca2496. STATUS.md is now back to the merge-base version, and `git merge-tree --write-tree --name-only
  HEAD claude/mmo-overhaul` prints only a tree id (rc 0). There was one `--import` after the base merge,
  because new class_name files (PetStats, PlayerEquipment, BrainRest) had failed to parse before it.

## Third review pass, 2026-10-19

 The reviewer found two blockers, two majors and four minors. All are
fixed, and each has a lab or test check that fails on the old code. The protected screens (HUD,
bag) now keep their landscape rows on every landscape phone, so boot hook 1 can land without hook 2.

## Review findings and what changed

| Finding | Fix | Check that would have caught it |
|---|---|---|
| Blocker: `is_phone` changed meaning, so the protected HUD and bag took their portrait rows at 844x390 | `UiTokens.is_phone` is `view.x < 720` again (its base meaning). New `UiTokens.is_compact` (narrow or short) drives type sizes and the owned landscape layouts. `is_narrow` is decided by shape. Owned files no longer call `is_phone` | The lab now gates HUD and bag blocks. With the old `is_phone` restored at 844x390 it fails (`lab844_oldphone_r15.log`): `FAIL hud: CLAIM#11 ... overlaps quest`, `FAIL bag: bag_col starts beside the others in the top half (y 344)`, `FAIL bag: equip_col ... (y 737)` |
| Blocker: character creation used the canvas, so without the fit a landscape phone got the desktop layout at 0.43 | `CharacterCreation.layout_for(view, fitted)` picks the layout on `DisplayMode.fitted_size(window)` (the canvas the fit would give) and scales every size by canvas/fitted. The screen is the same with or without `DisplayMode.install` | t_ui: `[t_ui] charcreate: unfitted 844x390 k=2.31 short=true; fitted k=1.00`. The `--no-fit` lab run fails only on the two fit lines, with no charcreate failures. `r16_nofit/charcreate_844x390.png` matches `r16/charcreate_844x390.png` |
| Major: landscape phones under 720 pt (667x375, 640x360) were "narrow" and got portrait layouts | `is_narrow` is `x < 720 and y > x`. `DisplayMode.logical_size` gives a landscape phone at least `LANDSCAPE_MIN_W` = 804 usable px (inside the safe area), so 667x375 becomes 804x452. At 760 px the protected bag's equipment column and close button ran off the edge (`r14/bag_668x376.png`), so the floor is 804 | Old rules at 667x375 (`lab667_oldrules_r15.log`): `FAIL atlas: card0 ... overlaps legend`, `FAIL atlas: zoom ... overlaps card0`, `FAIL charcreate: EnterRift [P: (24.0, 661.0) ...] inside the 668x376 view`, plus HUD overlaps. New code at 667x375: `[uireal] PASS` (below). t_ui covers 667x375, 640x360 and a notched 852x393 |
| Major: the gate skipped the HUD, never opened the bag, and did not check charcreate controls or atlas blocks | HUD: every visible HUD control checked as its drawn hexagon plus caption (`HexButton.hex_rect`/`caption_rect`, from the same geometry `_draw` uses), the minimap, the held slot, and the drawn vitals and quest card (mirrored from hunt_hud with its own `is_phone` branch). All inside the view, no pair overlapping. Atlas: `MapScreen.layout_rects()` (map, legend, cards, close, actions, zoom). Bag: columns side by side in the top half on a landscape canvas, inside the view across. Charcreate: every card, Body button, name field and ENTER THE RIFT inside the view, none overlapping. The `KNOWN_ZERO_SIZE` exemption is gone | The two old-rules runs above. The lab sets `Game.debug_overlay = false` before the HUD builds. Labs default it on, and the DEBUG hex then sat on the quest card |
| Minor: STATUS.md / plan-register.md copied into a code commit, STATUS.md conflicted | Both files are back to `claude/mmo-overhaul`'s version | `git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul` prints only a tree id (no conflicts) |
| Minor: craft_ui and map_screen grew; `CraftUI._nice` called across classes | `ItemText.nice_name` / `ItemText.stat_lines` (new `game/scripts/ui/item_text.gd`) and `LevelDisplay.recipe_label`. craft_ui, station_radial and map_screen call those. craft_ui is 555 lines (base 511, was 593) | t_ui: `nice_name falls back to the capitalised id`, `a tool has stat lines`, `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'` |
| Minor: atlas north-up, minimap camera-up | The atlas draws an N marker at the map's top-right corner. The minimap is in protected hunt_hud: listed for W2-HUD | `r16/atlas_1600x900.png`, `r16/atlas_844x390.png` |
| Minor: plate pill ghosting, crock pot = stone grill symbol, skills Close below the fold, loose story spacing | `PILL_ALPHA` 1.0. Crock pot uses `boiled_meat` (a cauldron). The campfire shared the bonfire symbol too and now uses `skewer`. The skills header (title, SP, Close) is pinned above the scroll. Card stories use `line_spacing` -8 | t_ui: `plate pill is opaque`, `[t_ui] craft stations: 10 with 10 distinct symbols`. Lab: `skills Close is pinned inside the view` and `sits in the header, outside the scroll` |

Also fixed, found by the new HUD gate: the held-tool slot (HANDS, owned) sat on the protected CLAIM
hex in landscape. On a landscape phone it now ends the left rail (`r16/hud_844x390.png`).

## What shipped (whole package)

- `DisplayMode`: phone canvas fit (`logical_size`, `install`, `fitted_size`, notch-aware landscape
  floor), runtime token theme (`build_theme`, `install_theme`).
- `UiTokens`: `is_phone` (unchanged meaning), `is_narrow` (portrait), `is_compact` (phone type and owned
  landscape layouts), `draw_centered`, 12 px `TYPE_MIN`, focus helpers, `hud_reserved`.
- Screens: craft (three columns plus pinned Craft footer on landscape, one pane on portrait, `Lv. —`,
  stat lines), skills (aligned grid, pinned header), atlas (north-up, distinct legend, display names,
  N marker), character creation (name/story/head start cards, fit-independent), gather radial (whole
  ring turns, one backing for name and level), plates (opaque pill, centred glyphs), white symbols,
  focusable HexButton with a ring, `LevelDisplay`, `ItemText`.
- `ui_real_capture_lab` (real island, root viewport, eight screens) and `t_ui`.

## Acceptance checklist (logs in scratchpad `w1/ui/`; r17-r19 are this pass on the merged base, r15/r16 the third pass)

| Item | Output line |
|---|---|
| Lab 844x390, Forward+, final code (`lab844x390_r19.log`) | `[uireal] phone=true min_font_px=12 logical_width=844 window_pt=844x390 min_pt=12.00 floor_pt=12.00 (smallest: craft .../CraftHint "Hand recipes craft anywh" 12.0 px)`, then exit 1 on the protected bag only: `[uireal] FAIL bag: equip_col [P: (576.0, 114.0), S: (280.0, 372.0)] inside the 844x390 view`, `[uireal] FAIL bag: close_btn [P: (812.0, 12.0), S: (44.0, 44.0)] inside the 844x390 view`. HUD, craft, skills, atlas, radial, plate and charcreate raise no failures |
| Lab 844x390 with bag hook 5 applied for one run (`lab844x390_r17_bagfix.log`) | same `phone=true min_font_px=12 logical_width=844` line, then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r17_bagfix` (exit 0) |
| Lab 1600x900, web renderer gl_compatibility, final code (`lab1600x900_r19_glc.log`) | `[uireal] phone=false min_font_px=13 logical_width=1600 window_pt=1600x900 min_pt=13.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r19_glc` (exit 0) |
| Lab 390x844, final code (`lab390x844_r18.log`) | `[uireal] phone=true min_font_px=12 logical_width=390 ...`, then exit 1 on protected hunt_hud only: `FAIL hud: SKILLS#7 [P: (244.02, 750.0), ...] overlaps HARBOUR#9 [P: (246.422, 750.0), ...]` (plus its two caption lines) and `FAIL hud: CLAIM#11 [P: (310.422, 234.0), ...] overlaps quest [P: (220.0, 240.0), ...]` (plus its caption line) |
| Lab 390x844 with HUD hook 6 applied for one run (`lab390x844_r18_hudfix.log`) | `[uireal] PASS screens=hud,craft,craft_detail,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r18_hudfix` (exit 0) |
| Lab 844x390, gl_compatibility, third pass (`lab844x390_r16_glc.log`) | `[uireal] PASS ...` before the base's bag change; not re-run this pass |
| Lab 1600x900 (`lab1600x900_r16.log`) | `[uireal] phone=false min_font_px=13 logical_width=1600 window_pt=1600x900 min_pt=13.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r16` (exit 0) |
| Lab 667x375 (macOS opens 668x376; `lab667x375_r16.log`) | `[uireal] window=668x376 logical=804x453 content_scale=(804, 453)`, `[uireal] phone=true min_font_px=9 logical_width=804 window_pt=668x376 min_pt=9.97 floor_pt=9.97 (...)`, `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate ...` (exit 0) |
| Gate fails without the fit (`lab844x390_r16_nofit.log`) | `[uireal] FAIL a 844x390 pt phone window must get the 844 px phone canvas (is_compact false, logical width 1947)`, `[uireal] FAIL phone window 844x390 pt: text at least 12.0 pt on screen (got 5.6)` (exit 1) |
| HUD/bag gate catches review blocker 1 (`lab844_oldphone_r15.log`, old `is_phone` restored for one run, then put back) | `FAIL hud: CLAIM#11 [P: (764.422, 234.0), S: (57.156, 66.0)] overlaps quest [P: (674.0, 240.0), S: (154.0, 72.0)]`, `FAIL bag: bag_col starts beside the others in the top half (y 344)` (exit 1) |
| Atlas/charcreate gate catches review major 3 (`lab667_oldrules_r15.log`, old predicates and 1:1 canvas for one run) | `FAIL atlas: card0 [P: (24.0, 108.0), S: (620.0, 112.0)] overlaps legend [...]`, `FAIL charcreate: EnterRift [P: (24.0, 661.0), S: (620.0, 64.0)] inside the 668x376 view` (exit 1) |
| Landscape craft: Craft pinned in the view | `[uireal] craft sheet: CraftOne [P: (460.0, 314.0), S: (180.0, 64.0)] in footer=true vscrolls=3` |
| Skills text clears the scrollbar | `[uireal] skills: rightmost text 782, scrollbar starts 812` (844x390) |
| No text over the vitals in skills or craft | the lab's vitals-band check passes at 844x390, 667x375 and 1600x900. Craft is opaque full screen (`r16/craft_844x390.png`) |
| Canvas unit lines (`t_ui_r16.log`) | `[t_ui] canvas: 844x390 -> (844.0, 390.0) compact=true narrow=false is_phone=false; 667x375 -> (804.0, 452.0); 1600x900 -> (1600.0, 900.0) compact=false` |
| No emoji, no font literal under 12 | `[t_ui] scanned 24 owned files: emoji=0 small_font=0` |
| draw_centered | `[t_ui] draw_centered: 40 px at x=100 starts at 80.0` |
| Radial, anchor above the view | `[t_ui] radial above view: centres 150.4 px apart (hex 64)` |
| Craft `Lv —` | `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`. Lab: `[uireal] craft rows=35 with_lv_dash=35 first="Lv. — · 2.0s  ·  Missing items"` |
| Distinct legend colours | `[t_ui] atlas legend: 8 kinds, min colour distance 0.35` |
| Safe-area clamp (`t_ui_r19.log`) | covered by the `[t_ui] PASS` run: `a portrait safe area in landscape clamps to 1072x495 logical` is an `_expect` that prints only on failure |
| t_ui (`t_ui_r19.log`) | `[t_ui] PASS` (exit 0) |
| Existing suite (`run_all_r19.log`) | `[tests] PASS` (exit 0) |
| Smoke (`smoke_r19.log`) | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` then `SMOKE PASS` (`tools/smoke.sh --no-import` through gslot) |

The spec writes `'Lv —'`. The screens print `Lv. —`, the one level format every screen uses.

## Screenshots inspected (Read tool)

Directory: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/ui/`

This pass:
- `r17/bag_844x390.png`: the base's four-column equipment grid cut at the right edge (Legs, second
  Ring), with the close button half off.
- `r17_bagfix/bag_844x390.png`: with hook 5, three equipment columns (Head/Body/Arms, Legs/Weapon/Tool,
  Ring/Ring/Food 1) and the close button inside the view.
- `r19/hud_844x390.png`: the landscape HUD on the merged base. Rail plus HANDS at bottom left, HARBOUR
  and CLAIM at bottom right, quest card left of the map. Nothing overlaps.
- `r17_glc/hud_1600x900.png`, `r17_glc/craft_1600x900.png`, `r17_glc/skills_1600x900.png` (web renderer):
  clean. `r17_glc/bag_1600x900.png`: four equipment columns fit, with the Legs/Ring slots flush against
  the panel's right border (protected bag; the gate passes).
- `r17/hud_390x844.png`: portrait before this pass's changes. CLAIM on the quest card, HARBOUR on SKILLS,
  HANDS caption on `Lv. 0 5.0%`.
- `r18_hudfix/hud_390x844.png`: portrait with the HANDS lift and hook 6. CLAIM under the quest card,
  HARBOUR above MENU, HANDS caption above the level line. Nothing overlaps.

Third pass:

- `r16_glc/hud_844x390.png`, `r13/hud_844x390.png`: the HUD's landscape rows. The vitals block is
  300 px, the quest card sits left of the map, CLAIM is under the map and HARBOUR is at the bottom
  right. HANDS ends the left rail. Nothing overlaps.
- `r15/hud_668x376.png`: the same layout on the 804 px SE canvas, clean.
- `r16_glc/bag_844x390.png`, `r15/bag_668x376.png`: profile, bag and equipment side by side. At
  844x390 the fourth bag row and the food slots need a scroll (see "Left for W2-SCREENS").
- `r14/bag_668x376.png`: the 760 px canvas tried first. The equipment column and close button run
  off the right edge, which is why the floor is 804.
- `r13/charcreate_844x390.png`, `r16_nofit/charcreate_844x390.png`: the same 4x2 cards and one
  Body / name / ENTER row, with and without the fit. `r15/charcreate_668x376.png` also fits.
- `r13/atlas_844x390.png`, `r15/atlas_668x376.png`, `r16/atlas_1600x900.png`, `r16/atlas_390x844.png`:
  card, map, legend, zoom and buttons apart, with the N marker on the map corner.
- `r13/skills_844x390.png`, `r15/skills_668x376.png`, `r16/skills_1600x900.png`: Close pinned in the
  header. On desktop all twelve rows fit under it.
- `r13/craft_844x390.png`, `r15/craft_668x376.png`: three columns plus the Craft footer. At 668 the
  hint line ends in an ellipsis.
- `r16/charcreate_1600x900.png`: the stories now have about 26 px line pitch (37 px before).
- `r13/plate_zoom_844x390.png`: opaque pill, no label showing through, B/K/G inside their rings.
- `r14/hud_390x844.png`: portrait HUD overlaps in the protected file (below): CLAIM on the quest
  card, HARBOUR on SKILLS, and the HANDS caption on the `Lv. 0 5.0%` line.
- `r16/charcreate_390x844.png`: two columns, everything on screen.

## Left for W2-HUD and W2-SCREENS (protected files)

- Landscape bag at 844x390: hook 5 (above, tested). Until it lands the lab exits 1 at 844x390 on the
  two bag lines, and players see the Legs/Ring column and the close button cut at the right edge.
- Portrait 390x844 (not the shipped orientation, but the package note asks for it): hook 6 (above,
  tested) fixes it. Without it the lab exits 1 there, and only on protected HUD geometry (`lab390x844_r18.log`):
  `FAIL hud: SKILLS#7 [P: (244.02, 750.0), ...] overlaps HARBOUR#9 [P: (246.422, 750.0), ...]`. The
  context row starts at `r.x - 150` (hunt_hud.gd:584) and lands on the left rail when the canvas is
  under ~460 px. Also `FAIL hud: CLAIM#11 [P: (310.422, 234.0), ...] overlaps quest [P: (220.0, 240.0), ...]`:
  in the `is_phone` branch the quest card (hunt_hud.gd:1073, `mp.y + MAP_PX + 52`) and the claim hex
  (hunt_hud.gd:598, `mp.y + MAP_PX + 44`) share the spot under the minimap.
- The bag (`inventory_ui.gd:489`, `slot = maxf(64.0, ...)`) keeps 64 px slots minimum, so on a 390 pt tall landscape phone
  its fourth row and the food slots need a scroll.
- The minimap turns with the camera while the atlas is north-up. Give the minimap an N marker too.
- `HuntHud` root has zero size (`hunt_hud.gd:68`). The lab checks the HUD's children instead.
- `UiTokens.hud_reserved` and the lab's `hud_blocks` mirror hunt_hud geometry. Replace both with
  rects the HUD exports.

## Assumptions

- `display_mode.gd` `LANDSCAPE_MIN_W := 804.0`: the bag's three columns need about 804 usable px and
  the HUD's rows about 740. Narrower landscape phones get 804 px at a smaller scale. Smallest text is
  10 pt on a 667 pt SE and 9.6 pt on a 640 pt Android, instead of overlapping or clipped screens.
  Lower it when W2 narrows those rows.
- `display_mode.gd` `side_inset_px`: on mobile the left and right safe-area insets are subtracted
  before the floor applies, so a notched iPhone keeps 804 px inside its safe area. Not tested on a device.
- `held_item_slot.gd`: the landscape position mirrors hunt_hud's rail (four 64 px hexes, 10 px apart, 96 px up).
- `ui_real_capture_lab.gd` `hud_blocks`: the vitals, quest and level-line rects mirror hunt_hud.gd `_draw` and `_draw_quest`.
- `held_item_slot.gd`: on `is_phone` (portrait) canvases the slot sits 24 px higher, to clear the level line hunt_hud draws at `r.y - HEX - 22`.
- `display_mode.gd` `MIN_USABLE := 0.75`: a landscape safe area never leaves less than 75 % of the width usable.
- `craft_ui.gd` STATIONS: crock pot uses the `boiled_meat` cauldron symbol and campfire uses `skewer`.
  Their kit icons alias the stone grill and bonfire symbols in the protected manifest.
- `character_creation.gd` `STORY_TIGHTEN := 8`.
- Carried over: `level_display.gd`, where the pioneer level is the player level; `skills_sheet.gd`, where
  item symbols stand in for skill art; no `game/ui/deadfront_theme.tres`, because the theme is built
  from tokens at runtime; landscape character creation uses 48 px controls.

## Integrator hooks

1. `game/scripts/core/main.gd` `_ready()`, first lines. They can land alone: no hunt_hud edit is
   needed for landscape any more.
   ```gdscript
   	DisplayMode.install(get_tree().root)
   	DisplayMode.install_theme()
   ```
2. `game/scripts/ui/hunt_hud.gd:68` (W2-HUD): `set_anchors_preset(Control.PRESET_FULL_RECT)` ->
   `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`.
3. `game/tests/run_all.gd`: run `res://tests/t_ui.gd` and require `[t_ui] PASS`.
4. Merge: no conflicts with `claude/mmo-overhaul` (8ca2496). `git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul`
   prints only a tree id.
5. `game/scripts/ui/inventory_ui.gd` `_apply_slot_metrics` (protected: the owner UI pass / W2-SCREENS). It fits
   the bag on landscape phones without shrinking type. Tested at 844x390 (`r17_bagfix`), then reverted:
   ```gdscript
   	var slot := 64.0
   	# Four equipment columns need 9 slots of 64 px beside the 180 px profile; compact landscape canvases get three.
   	var equip_cols := 4 if panel_w >= 180.0 + 9.0 * 64.0 + sep * 11.0 else 3
   	...
   		var inner_seps := sep * float(3 + equip_cols)                      # was sep * 7.0
   		var by_w := floorf((panel_w - h_gaps - profile_floor - inner_seps) / float(5 + equip_cols))   # was / 9.0
   		var equip_w := float(equip_cols) * slot + sep * float(equip_cols - 1)   # was 4.0 * slot + sep * 3.0
   	...
   		_equip_grid.columns = 3 if phone else equip_cols                  # was 3 if phone else 4
   ```
6. `game/scripts/ui/hunt_hud.gd` `_refresh_context` (protected: W2-HUD). With it portrait 390x844 passes
   the lab. Tested (`r18_hudfix`), then reverted. Landscape and desktop are unchanged (`is_phone` is false there):
   ```gdscript
   	var phone := UiTokens.is_phone(r)
   	# Portrait: no room beside the rail, so the context row sits one row above it, from the left.
   	var x := 16.0 + inset.w if phone else r.x - 16.0 - inset.x - 74.0 - 60.0
   	...
   			# Portrait: the quest card is under the map, so the claim hex goes under the card.
   			h.position = Vector2(_minimap.position.x + MAP_PX - 70.0, _minimap.position.y + MAP_PX + (52.0 + 72.0 + 8.0 if phone else 44.0))
   		else:
   			h.position = Vector2(x, r.y - 70.0 - 26.0 - inset.y - (96.0 if phone else 0.0))
   			x += 78.0 if phone else -78.0
   ```
   Portrait fits three context hexes left of HANDS. A fourth would reach the HANDS slot (x 310).

## Labs to register

- `ui_real_capture_lab` (`game/scripts/dev/ui_real_capture_lab.gd` + `game/scenes/dev/ui_real_capture_lab.tscn`).
  Windowed: `--resolution 844x390 -- --lab=ui_real_capture_lab --shot-dir=DIR`. Also run it at
  1600x900, 667x375 and 390x844 (390x844 currently exits 1 on the protected HUD lines above).
  `--no-fit` is the gate's self-test and must exit 1 on a phone window.

## New files

- `game/scripts/ui/item_text.gd` (`ItemText`). The reviewer asked for it. It sits in `game/scripts/ui/`
  beside `level_display.gd`, and no other package owns that path.

## Not done / risks

- Not tested on a device, and not in desktop Chrome: no web export was made, to spare the shared machine
  a 180 MB export. The stand-in is the web renderer (gl_compatibility) at 1600x900, which passes this pass
  on the merged base. Windowed runs: Forward+ at 844x390, 667x375 (third pass), 1600x900 and 390x844.
- The lab exits 1 at 844x390 until hook 5 lands, and at 390x844 until hook 6 lands. Both failures are in
  protected files. Every screen this package owns passes at both sizes.
- 667x375 and gl_compatibility at 844x390 were not re-run after the base's bag change. The bag needs
  868 px there too, so expect the same two bag lines at 667x375 (804 px canvas) until hook 5.
- The notch inset path (`side_inset_px`) only runs on mobile, so it has a unit test but no device run.
- map_screen is 421 lines (base 305). The gate's `layout_rects`, the N marker and the landscape
  layout account for the growth.
- The atlas card shows the home island as `Lv. 10`, its tier in world data, while starter creatures
  are Lv. 1. That is a data question.
