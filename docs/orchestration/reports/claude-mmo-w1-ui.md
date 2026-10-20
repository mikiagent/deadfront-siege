# W1-UI report (claude, branch claude/mmo-w1-ui)

Logs and screenshots are in the scratchpad: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/w1/ui/`.
Final code is commit c2cd75e plus this report. Runs r24 to r26 and t_ui/run_all/smoke r25 are on that code.

## Read this first: the gate is red until three hooks land together

The canvas fit (hook 1, main.gd) cannot land alone. It makes the lab exit 1 in two protected files:

| If hook 1 lands without... | What players see | Lab line (no hooks) |
|---|---|---|
| hook 5 (inventory_ui.gd) | On a landscape phone (844x390, and 667x375 on its 804 px canvas) the bag's Legs/Ring column and its close button are cut at the right edge (`r26_nohooks/bag_844x390.png`) | `[uireal] FAIL bag: equip_col [P: (576.0, 114.0), S: (280.0, 372.0)] inside the 844x390 view` and `[uireal] FAIL bag: close_btn [P: (812.0, 12.0), S: (44.0, 44.0)] inside the 844x390 view` (`lab844x390_r26_nohooks.log`, exit 1) |
| hook 6 (hunt_hud.gd) | On a 390x844 portrait phone, HARBOUR sits on SKILLS and CLAIM sits on the quest card | `[uireal] FAIL hud: SKILLS#7 [P: (244.02, 750.0), ...] overlaps HARBOUR#9 [P: (246.422, 750.0), ...]` and `[uireal] FAIL hud: CLAIM#11 [P: (310.422, 234.0), ...] overlaps quest [P: (220.0, 240.0), ...]`, plus three caption lines (`lab390x844_r23_nohooks.log`, exit 1; that run predates only the portrait skills column tweak, which the HUD does not use) |

Without hook 1 the bag fits on a landscape phone, but everything is drawn at 0.43 scale (5.6 pt text).
So hooks 1, 5 and 6 are one integration step. With all three applied, the lab passes at every size
(table below). The earlier report said hook 1 "can land alone". That was wrong, and it is corrected here.

## Review 4 findings and what changed

| # | Finding | What I did | Check that catches it |
|---|---|---|---|
| 1 | Blocker: lab red at 844x390 once the fit lands (bag, protected) | Hooks 1, 5 and 6 are now one step with one diff (below). I applied all three and ran the lab at 844x390 (both renderers), 667x375, 390x844 and 1600x900: each prints `[uireal] PASS`. Then I reverted them | `lab844x390_r25_hooks_glc.log`, `lab667x375_r26_hooks.log`, `lab390x844_r24_hooks.log`, `lab1600x900_r26_hooks_glc.log` (PASS lines below). Without hooks: the bag lines above |
| 2 | Major: the report said hook 1 can land alone | Rewritten: the table above, plus "Integrator hooks" | n/a (report) |
| 3 | Major: portrait 390x844 HUD overlaps | Hook 6 lands with hook 1. With it: `[uireal] PASS screens=hud,craft,craft_detail,skills,atlas,radial,plate,bag,charcreate` at 390x844. HUD shot inspected (`r21_hooks/hud_390x844.png`) | the lab's HUD block gate (the FAIL lines above) |
| 4 | Minor: landscape skills showed 3 of 12 rows | On a landscape phone the sheet is opaque and edge to edge, like craft. It covers the vitals fully (allowed: no text shows over them), and the rows sit in two columns. Name column fixed, XP bar takes the spare width (no gap before `Lv.`). Shows 10 of 12 at 844x390 and 12 of 12 at 667x375 | Lab: `[uireal] skills: rows fully visible 10/12` and `_expect(shown >= 8)`. The vitals check now accepts "clears the vitals, or encloses them with an opaque panel". t_ui: `landscape skills sheet ... covers the vitals band` |
| 5 | Minor: card titles 13 px apart in a row at 1600x900; 48 px landscape controls | Desktop cards: title and story from the top, `Starts:` pinned to the bottom. Body and name are 56 px, ENTER THE RIFT 64 px, on every layout. The new alignment gate then caught a portrait wrap ("Weapon / Tools Lv. 20" took two lines and pushed its title 16 px off). Phone cards now show the skill alone; the subtitle already says Lv. 20 | Lab: `[uireal] charcreate cards: rows=2 title_y_spread=0.0 start_y_spread=0.0` at every size, every card line inside its card, controls >= 56 px. Before the phone fix: `[uireal] FAIL charcreate: card titles and head starts line up across each row (spread (16.0, 16.0))` (`lab390x844_r21_hooks.log`) |
| 6 | Minor: crossbow reads as a thin line, hammer as a blob | Ranged uses `cactus_spine` (a dart), Weapon / Tools uses `work_pick`. Both are flagged in code for W1-ICONART skill art | t_ui: each skill symbol must fill >= 12 % of its icon. The crossbow fills 6 %. `[t_ui] skill symbols: 12, thinnest silhouette 0.16`. A metric cannot judge a blob, so I checked the hammer replacement by eye (`r21_hooks_glc/skills_1600x900.png`) |
| 7 | Minor: notch inset path not run on a device or mobile web | Not done: no device, and no web export on this shared machine. I do not call the phone fit done (see "Not done") | n/a |
| 8 | Minor: `item_text.gd` outside Owns; sync copies | `ItemText` folded into the owned `level_display.gd` (`LevelDisplay.nice_name`, `LevelDisplay.stat_lines`). Files deleted, callers and t_ui updated. Sync copies: all 11 are byte-identical to the base tip (checked with `git diff --quiet claude/mmo-overhaul HEAD -- <file>` per file). History is not rewritten. No more copy-syncs | `git diff --name-only --diff-filter=A claude/mmo-overhaul HEAD` lists only owned paths (report, lab .gd/.tscn/.uid, level_display.gd/.uid, t_ui.gd/.uid). `git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul` prints only a tree id (rc 0) |

Two more problems turned up while running the gate:

- **HANDS on the level line (owned held_item_slot.gd).** At 667x375 (804 px canvas) the slot at the rail's
  end ran into the HUD's centred `Lv. 0 5.0%` line: `[uireal] FAIL hud: HeldItemSlot [P: (312.0, 357.0),
  S: (64.0, 82.0)] overlaps level [P: (369.5, 434.0), S: (65.0, 15.0)]`. A notched iPhone has the same
  problem, because its inset pushes the rail right. On landscape phones the slot now stacks above the
  rail's last hex (SKILLS). One position fits every landscape phone, and the level line no longer meets
  it (`r21_hooks/hud_668x376.png`, `r25_hooks_glc/hud_844x390.png`; the failing run's shot was not kept).
- **Portrait skill names cut.** At 390x844 the row cut "Weapon / Tools" to "Weapon / ...". The portrait
  `Lv.` column is now 48 px and the XP column 72 px. The lab now fails any clipped skills label whose
  text is wider than its column (`r24_hooks/skills_390x844.png` shows the full name).

## Acceptance checklist

| Item | Output line (log) |
|---|---|
| 844x390, web renderer, hooks 1+5+6, final code | `[uireal] phone=true min_font_px=12 logical_width=844 window_pt=844x390 min_pt=12.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r25_hooks_glc` (`lab844x390_r25_hooks_glc.log`, exit 0) |
| 844x390, Forward+, hooks 1+5+6 | `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r20_hooks` (`lab844x390_r20_hooks.log`, exit 0; code before the HANDS and phone-card changes) |
| 844x390, Forward+, final code, no hooks (what ships if hook 1 lands alone) | the same phone line, then exit 1 on the two bag lines only (table at the top, `lab844x390_r26_nohooks.log`). No owned screen fails |
| 667x375 (macOS opens 668x376), hooks 1+5+6, final code | `[uireal] window=668x376 logical=804x453 content_scale=(804, 453)`, `[uireal] phone=true min_font_px=9 logical_width=804 window_pt=668x376 min_pt=9.97 floor_pt=9.97 (...)`, `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r26_hooks` (`lab667x375_r26_hooks.log`, exit 0) |
| 390x844, hooks 1+5+6, final code | `[uireal] phone=true min_font_px=12 logical_width=390 window_pt=390x844 min_pt=12.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,craft_detail,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r24_hooks` (`lab390x844_r24_hooks.log`, exit 0) |
| 1600x900, web renderer, hooks 1+5+6, final code | `[uireal] phone=false min_font_px=13 logical_width=1600 window_pt=1600x900 min_pt=13.00 floor_pt=12.00 (...)` then `[uireal] PASS screens=hud,craft,skills,atlas,radial,plate,bag,charcreate shots=.../w1/ui/r26_hooks_glc` (`lab1600x900_r26_hooks_glc.log`, exit 0) |
| Skills rows (final code) | `[uireal] skills: rows fully visible 10/12` (844x390), `12/12` (667x375 and 1600x900), `8/12` (390x844) |
| Skills text clears the scrollbar | `[uireal] skills: rightmost text 790, scrollbar starts 820` (844x390) |
| Card alignment (final code, all four sizes) | `[uireal] charcreate cards: rows=2 title_y_spread=0.0 start_y_spread=0.0` (`rows=4` at 390x844) |
| Landscape craft: Craft pinned in the view | `[uireal] craft sheet: CraftOne [P: (460.0, 314.0), S: (180.0, 64.0)] in footer=true vscrolls=3` (844x390) |
| No text over the vitals in skills or craft | Lab vitals check passes at all four sizes. Skills on a landscape phone covers them with an opaque sheet (`r20_hooks/skills_844x390.png`). Craft is opaque full screen |
| Gate fails without the fit (third pass, `lab844x390_r16_nofit.log`) | `[uireal] FAIL a 844x390 pt phone window must get the 844 px phone canvas (is_compact false, logical width 1947)`, `[uireal] FAIL phone window 844x390 pt: text at least 12.0 pt on screen (got 5.6)` (exit 1). Unit form in t_ui: `[t_ui] gate: 844x390 without fit -> 2 failures` |
| Canvas | `[t_ui] canvas: 844x390 -> (844.0, 390.0) compact=true narrow=false is_phone=false; 667x375 -> (804.0, 452.0); 1600x900 -> (1600.0, 900.0) compact=false` |
| No emoji, no font literal under 12 | `[t_ui] scanned 23 owned files: emoji=0 small_font=0` |
| draw_centered | `[t_ui] draw_centered: 40 px at x=100 starts at 80.0` |
| Radial, anchor above the view | `[t_ui] radial above view: centres 150.4 px apart (hex 64)` |
| Craft `Lv —` | `[t_ui] craft: 5 unmakeable hand recipes read 'Lv. —'`. Lab: `[uireal] craft rows=35 with_lv_dash=35 first="Lv. — · 2.0s  ·  Missing items"` |
| Distinct legend colours | `[t_ui] atlas legend: 8 kinds, min colour distance 0.35` |
| Skill symbols | `[t_ui] skill symbols: 12, thinnest silhouette 0.16` |
| t_ui (`t_ui_r25.log`) | `[t_ui] PASS` (exit 0) |
| Existing suite (`run_all_r25.log`) | `[tests] PASS` (exit 0) |
| Smoke (`smoke_r25.log`, `tools/smoke.sh --no-import` through gslot) | `[smoke] ok player_pos=(0.0, 0.900182, 0.0) phase=day` then `SMOKE PASS` |

The spec writes `'Lv —'`. The screens print `Lv. —`, the one level format every screen uses.

## Screenshots inspected (Read tool), this pass

- `r20_hooks/skills_844x390.png`: edge-to-edge sheet, two columns,
  ten rows visible, XP bars fill the row, dart and pick symbols read clearly.
- `r21_hooks/skills_668x376.png`: all twelve rows.
- `r21_hooks_glc/skills_1600x900.png`: name, `Lv.` and a long XP bar with no dead gap. Ranged (dart) and
  Weapon / Tools (pick) are clear silhouettes.
- `r23_nohooks/skills_390x844.png` ("Weapon / To..." cut), then `r24_hooks/skills_390x844.png` (full name).
- `r21_hooks_glc/charcreate_1600x900.png`: titles on one line per row, stories under them, `Starts:` lines
  level along the bottom. The middle of each card is empty (about 130 px).
- `r21_hooks/charcreate_390x844.png` (Technician's head start wrapped, title 16 px low), then
  `r22_hooks/charcreate_390x844.png` (skill alone, aligned).
- `r20_hooks/charcreate_844x390.png`, `r25_hooks_glc/charcreate_844x390.png`: 56 px Body/name, 64 px
  ENTER THE RIFT, everything inside 390 px.
- `r20_hooks/bag_844x390.png`, `r21_hooks/bag_668x376.png`: with hook 5, three equipment columns and the
  close button inside the view. `r26_nohooks/bag_844x390.png`: without it, the Legs/Ring column and
  the close button are cut, as the reviewer saw.
- `r26_hooks_glc/bag_1600x900.png`: four columns. The Legs/Ring column touches the panel's right border
  (protected bag; the gate passes).
- `r20_hooks/hud_844x390.png` (HANDS at the rail end, before the fix), `r21_hooks/hud_668x376.png` and
  `r25_hooks_glc/hud_844x390.png` (stacked above SKILLS, clear of `Lv. 0 5.0%`).
- `r21_hooks/hud_390x844.png`: portrait with hook 6. HARBOUR is above MENU, CLAIM is under the quest
  card, the HANDS caption is above the level line. Nothing overlaps.

Earlier passes' shots (r13-r19) are listed in git history (this file at f2704dd).

## Integrator hooks

1. **Hooks 1, 5 and 6 are one step: apply this diff in one commit.** It was tested as a whole
   (lab PASS at 844x390 in both renderers, 667x375, 390x844 and 1600x900; lines above) and then reverted.
   `git apply` it on the merged branch (inventory_ui.gd and hunt_hud.gd are owned by the owner UI pass
   / W2-SCREENS / W2-HUD; main.gd by the integrator). The regressions each part causes when missing
   are in the table at the top.
   ```diff
   diff --git a/game/scripts/core/main.gd b/game/scripts/core/main.gd
   --- a/game/scripts/core/main.gd
   +++ b/game/scripts/core/main.gd
   @@ -7,6 +7,8 @@ extends Node3D
    @onready var iso_camera: Camera3D = $IsoCamera
    
    func _ready() -> void:
   +	DisplayMode.install(get_tree().root)
   +	DisplayMode.install_theme()
    	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
    	if Game.lab_name != "":
    		default_playfield.visible = false
   diff --git a/game/scripts/ui/hunt_hud.gd b/game/scripts/ui/hunt_hud.gd
   --- a/game/scripts/ui/hunt_hud.gd
   +++ b/game/scripts/ui/hunt_hud.gd
   @@ -581,7 +581,9 @@ func _refresh_context(delta: float) -> void:
    	_ctx_hexes.clear()
    	var r := get_viewport_rect().size
    	var inset := _safe_insets()
   -	var x := r.x - 16.0 - inset.x - 74.0 - 60.0
   +	var phone := UiTokens.is_phone(r)
   +	# Portrait: no room beside the rail, so the context row sits one row above it, from the left.
   +	var x := 16.0 + inset.w if phone else r.x - 16.0 - inset.x - 74.0 - 60.0
    	for a in actions:
    		var h := HexButton.new(70.0)
    		h.glyph = str(a.get("glyph", ""))
   @@ -595,10 +597,11 @@ func _refresh_context(delta: float) -> void:
    		add_child(h)
    		if id == "claim":
    			# Land claim lives by the minimap (it is about the map, not the fight).
   -			h.position = Vector2(_minimap.position.x + MAP_PX - 70.0, _minimap.position.y + MAP_PX + 44.0)
   +			# Portrait: the quest card is under the map, so the claim hex goes under the card.
   +			h.position = Vector2(_minimap.position.x + MAP_PX - 70.0, _minimap.position.y + MAP_PX + (52.0 + 72.0 + 8.0 if phone else 44.0))
    		else:
   -			h.position = Vector2(x, r.y - 70.0 - 26.0 - inset.y)
   -			x -= 78.0
   +			h.position = Vector2(x, r.y - 70.0 - 26.0 - inset.y - (96.0 if phone else 0.0))
   +			x += 78.0 if phone else -78.0
    		_ctx_hexes.append(h)
    
    func _refresh_place_hexes() -> void:
   diff --git a/game/scripts/ui/inventory_ui.gd b/game/scripts/ui/inventory_ui.gd
   --- a/game/scripts/ui/inventory_ui.gd
   +++ b/game/scripts/ui/inventory_ui.gd
   @@ -466,6 +466,8 @@ func _apply_slot_metrics(view: Vector2, safe: Vector4) -> void:
    	var panel_w := maxf(280.0, view.x - (24.0 + safe.w + safe.x))
    	var panel_h := maxf(280.0, view.y - (24.0 + safe.z + safe.y))
    	var slot := 64.0
   +	# Four equipment columns need 9 slots of 64 px beside the 180 px profile; compact landscape canvases get three.
   +	var equip_cols := 4 if panel_w >= 180.0 + 9.0 * 64.0 + sep * 11.0 else 3
    	if phone:
    		slot = floorf((panel_w - sep * 4.0) / 5.0)
    		slot = clampf(slot, 56.0, 80.0)
   @@ -481,15 +483,15 @@ func _apply_slot_metrics(view: Vector2, safe: Vector4) -> void:
    		var profile_floor := 280.0
    		var h_gaps := sep * 4.0
    		# Bag 5 wide + equipment 4 wide (head/body/arms/legs in one row keeps it to three rows).
   -		var inner_seps := sep * 7.0
   +		var inner_seps := sep * float(3 + equip_cols)
    		var chrome := 44.0 + sep + 36.0 + sep
    		var label_h := float(UiTokens.meta(view)) + 4.0
    		var grid_h := panel_h - chrome - label_h - sep * 2.0
    		var by_h := floorf((grid_h - sep * 3.0) / 4.0)
   -		var by_w := floorf((panel_w - h_gaps - profile_floor - inner_seps) / 9.0)
   +		var by_w := floorf((panel_w - h_gaps - profile_floor - inner_seps) / float(5 + equip_cols))
    		slot = maxf(64.0, minf(by_w, by_h))
    		var bag_w := 5.0 * slot + sep * 4.0
   -		var equip_w := 4.0 * slot + sep * 3.0
   +		var equip_w := float(equip_cols) * slot + sep * float(equip_cols - 1)
    		if _bag_col:
    			_bag_col.custom_minimum_size = Vector2(bag_w, 0)
    			_bag_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
   @@ -498,7 +500,7 @@ func _apply_slot_metrics(view: Vector2, safe: Vector4) -> void:
    			_equip_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    	_slot_px = slot
    	if _equip_grid:
   -		_equip_grid.columns = 3 if phone else 4
   +		_equip_grid.columns = 3 if phone else equip_cols
    	var sz := _slot_vec()
    	for child in _grid.get_children():
    		if child is Control:
   ```
   After applying it, run the lab at 844x390, 667x375 and 390x844 and require `[uireal] PASS` with exit 0.
2. `game/scripts/ui/hunt_hud.gd:68` (W2-HUD): `set_anchors_preset(Control.PRESET_FULL_RECT)` ->
   `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`. Independent of 1.
3. `game/tests/run_all.gd`: run `res://tests/t_ui.gd` and require `[t_ui] PASS`. Independent of 1.
4. Merge: `git merge-tree --write-tree --name-only HEAD claude/mmo-overhaul` prints only a tree id
   (rc 0) against base 8ca2496.

## Labs to register

- `ui_real_capture_lab` (`game/scripts/dev/ui_real_capture_lab.gd` + `game/scenes/dev/ui_real_capture_lab.tscn`).
  Windowed: `--resolution 844x390 -- --lab=ui_real_capture_lab --shot-dir=DIR`; also 667x375, 390x844
  and 1600x900 (add `--rendering-method gl_compatibility` for the web renderer).
  **Register it as red, not green, until integrator hook 1 lands.** On the branch as it stands it exits 1 at
  844x390 and 667x375 (protected bag) and at 390x844 (protected HUD). It passes at 1600x900. `--no-fit`
  is the gate's self-test and must exit 1 on a phone window.

## What shipped (whole package)

- `DisplayMode`: phone canvas fit (`logical_size`, `install`, `fitted_size`, notch-aware landscape
  floor), runtime token theme (`build_theme`, `install_theme`).
- `UiTokens`: `is_phone` (base meaning), `is_narrow` (portrait), `is_compact` (phone type and owned
  landscape layouts), `draw_centered`, 12 px `TYPE_MIN`, focus helpers, `hud_reserved`.
- Screens: craft (three columns plus a pinned Craft footer on landscape, one pane on portrait, `Lv. —`,
  stat lines), skills (aligned grid, pinned header, edge-to-edge two-column sheet on landscape phones),
  atlas (north-up, distinct legend, display names, N marker), character creation (name, story and head
  start cards with aligned rows; fit-independent), gather radial (the whole ring turns), plates (opaque
  pill, centred glyphs), white symbols, focusable HexButton with a ring, held-tool slot placement,
  `LevelDisplay` (levels, item names, stat lines).
- `ui_real_capture_lab` (real island, root viewport, eight screens, block/overlap/type/row/alignment
  gates) and `t_ui`.

## Assumptions (`# ASSUMPTION:` in code)

- `display_mode.gd` `LANDSCAPE_MIN_W := 804.0`: the bag's three columns (with hook 5) need about 804 usable
  px. Narrower landscape phones get 804 px at a smaller scale: 10 pt smallest text on a 667 pt SE,
  9.6 pt on a 640 pt Android, and about 11.2 pt on a notched 844 pt iPhone (its ~47 pt side insets leave
  750 pt usable, so the canvas is ~905x418). The alternative is clipped or overlapping screens. Lower
  the floor when W2 narrows the bag.
- `display_mode.gd` `side_inset_px` / `MIN_USABLE := 0.75`: on mobile the side safe-area insets come off
  before the floor applies; the safe area never leaves under 75 % of the width usable. Unit-tested only.
- `held_item_slot.gd`: mirrors hunt_hud's rail (four 64 px hexes, 10 px apart, 96 px up). On landscape
  phones the slot stacks above the last rail hex. On portrait it sits 24 px higher to clear the level line.
- `ui_real_capture_lab.gd` `hud_blocks`: the vitals, quest and level-line rects mirror hunt_hud.gd `_draw`
  and `_draw_quest`.
- `skills_sheet.gd` SYMBOLS: item symbols stand in for skill art (W1-ICONART). Ranged = `cactus_spine`,
  Weapon / Tools = `work_pick`.
- `craft_ui.gd` STATIONS: crock pot uses the `boiled_meat` cauldron symbol and campfire uses `skewer`.
- `level_display.gd`: the pioneer level is the player level.
- `character_creation.gd` `STORY_TIGHTEN := 8`. Phone cards show the head-start skill without `Lv. 20`
  (the subtitle says it once).
- No `game/ui/deadfront_theme.tres`: the theme is built from tokens at runtime.

## Not done / risks

- **Phone fit is not done until one device or mobile-web run.** No device here, and no web export on
  this shared machine. The notch path (`side_inset_px`) and `DisplayServer.screen_get_scale()` on mobile
  web are unit-tested only. On the device, record the boot line `[display] window (W, H) -> logical (w, h)`
  and the lab's `[uireal] phone=... min_pt=...` line. The desktop web-renderer stand-in
  (gl_compatibility) passes at 1600x900 and 844x390.
- On a notched iPhone the 12 px floor is about 11.2 pt on glass (Assumptions). If the owner wants
  12 pt there, the bag must fit 750 px (W2-SCREENS).
- Protected bag at 1600x900: the four-column Legs/Ring slots touch the panel's right border.
- Protected HUD: the minimap turns with the camera while the atlas is north-up (W2-HUD: add an N marker).
  `UiTokens.hud_reserved` and the lab's `hud_blocks` mirror hunt_hud geometry. Replace both with rects
  the HUD exports.
- The bag (`inventory_ui.gd`, `slot = maxf(64.0, ...)`) keeps 64 px slots, so on a 390 pt tall landscape
  phone its fourth row and food slots need a scroll.
- Desktop character cards have about 130 px of empty middle (title and story at the top, head start at
  the bottom). They align, but they are sparse.
- map_screen is 421 lines (base 305): the gate's `layout_rects`, the N marker and the landscape layout.
- The atlas card shows the home island as `Lv. 10` (its tier in world data), while starter creatures
  are Lv. 1. That is a data question.
- The sync commit d2c8e8a copied 11 docs files instead of merging. All 11 are identical to the base tip,
  so a merge leaves them unchanged. I will not copy-sync again.
