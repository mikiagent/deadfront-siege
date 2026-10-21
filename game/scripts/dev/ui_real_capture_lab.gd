extends Node3D
## Real-scene UI gate (W1-UI). Boots the home island with the real HUD on the canvas fit and token
## theme main.gd installs at boot (DisplayMode.install, DisplayMode.install_theme), then opens
## the HUD, craft, skills, atlas, a gather radial, the bag, the animal screen and character creation in the ROOT
## viewport (not a sized SubViewport, which hid the phone problem) and saves a PNG of each. Every
## screen must have size, sit inside the view, draw no text under 12 logical px and be neither blank
## nor blown out; the HUD, atlas, bag and character creation also check that their blocks and
## controls stay inside the view and do not overlap each other, and the gather radial's hexes and
## labels stay off the HUD and the survivor's nameplate. The HUD is also gated past idle: the menu
## and build sheets, a level-up, a bonded pet out, a hunt with the pet out, the camp's labels and
## station menus, and toasts and notices over a level-up (review: five overlaps passed while only the
## idle HUD was checked; then moving text crossed the quest card at 844x390 and 667x375). The
## animal screen (protected) is a shot only, for an eye check of the token theme on it; nothing on
## it is gated.
## Windowed: --resolution 844x390 -- --lab=ui_real_capture_lab [--shot-dir=DIR]
## (844x390 is the phone check: the owner plays phones landscape; 667x375, 390x844 and 1600x900 also
## run.) The verdict without the fit is unit-tested in t_ui (gate_failures), since boot now always fits.
## Prints "[uireal] phone=<bool> min_font_px=<n> min_font_pt=<f> ..." then "[uireal] PASS" (exit 0) or FAIL lines (exit 1).

const SETTLE_S := 3.0
const BLOWN_MAX := 0.2   ## share of near-white pixels allowed in a frame
const FLAT_MIN := 0.02   ## luma deviation under this is a blank frame

var _fails: Array[String] = []
var _out := ""
var _player: Player
var _hud: HuntHud
var _min_font := INF
var _min_font_where := ""
var _shots: PackedStringArray = []

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("ui-real")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false  # before the HUD builds: players never see the DEBUG hex (labs default it on)
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	var ui := kit["ui"] as CanvasLayer
	for c in ui.get_children():
		if c is HuntHud:
			_hud = c
	# Same layering as main.gd: bag and craft are modals above every other canvas layer.
	var modals := CanvasLayer.new()
	modals.name = "Modals"
	modals.layer = 96
	add_child(modals)
	_player.ui.reparent(modals)
	(_player.craft_ui as Node).reparent(modals)
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(SETTLE_S).timeout
	var root := get_tree().root
	var logical := root.get_visible_rect().size
	var phone := UiTokens.is_compact(logical)
	var narrow := UiTokens.is_narrow(logical)
	print("[uireal] window=%dx%d logical=%dx%d content_scale=%s" % [root.size.x, root.size.y, logical.x, logical.y, root.content_scale_size])
	if _hud == null:
		_fail("no HuntHud in the lab UI layer")
		_finish(phone, logical)
		return
	# The HUD root has no size (hunt_hud.gd:68), so its blocks are checked one by one instead.
	_check_blocks("hud", hud_blocks(_hud, _player, logical), logical)
	await _capture("hud", [], logical)
	# The day/night dial's label (a tap) opens left of the dial; it too keeps off every HUD block.
	var dial: DayNightDial = _hud.get("_daynight")
	dial.toggle()
	await _frames(2)
	_check_blocks("hud_daynight", hud_blocks(_hud, _player, logical), logical)
	await _capture("hud_daynight", [], logical)
	dial.toggle()
	# craft: a bag without inputs must read "Lv —", not the recipe's top level
	var craft := _player.craft_ui as CraftUI
	craft.show_ui()
	await _frames(3)
	var metas := _labels_named(craft, "RecipeMeta")
	var dash := 0
	for l in metas:
		if l.text.begins_with(CraftUI.NO_LEVEL):
			dash += 1
	print("[uireal] craft rows=%d with_lv_dash=%d first=\"%s\"" % [metas.size(), dash, metas[0].text if not metas.is_empty() else ""])
	_expect(dash > 0, "craft shows '%s' on a recipe the bag cannot make" % CraftUI.NO_LEVEL)
	# Portrait cut the header hint to "Hand reci...": shown means it fits.
	var hint := craft.find_child("CraftHint", true, false) as Label
	_expect(hint == null or not hint.is_visible_in_tree() or text_fits(hint), "craft: header hint \"%s\" fits its %.0f px, or is hidden" % [hint.text.left(24) if hint else "", hint.size.x if hint else 0.0])
	if narrow:
		_expect(_visible_vscrolls(craft) == 1, "portrait craft shows one vertical scroll pane, not %d" % _visible_vscrolls(craft))
	await _capture("craft", [craft], logical)
	if phone and not metas.is_empty():
		# Craft / Craft x5 sit in the pinned footer, inside the view: under the three panes on a
		# landscape phone, under the detail sheet (opened from a row) on a portrait one.
		if narrow:
			(metas[0].get_parent().get_parent().get_parent() as Button).pressed.emit()
			await _frames(3)
		var one := craft.find_child("CraftOne", true, false) as Control
		var view := Rect2(Vector2.ZERO, logical)
		var ok := one != null and one.is_visible_in_tree() and view.encloses(one.get_global_rect()) and one.size.y >= UiTokens.TARGET_PRIMARY
		print("[uireal] craft sheet: CraftOne %s in footer=%s vscrolls=%d" % [one.get_global_rect() if one else "missing", one != null and one.get_parent().name == "CraftFooter", _visible_vscrolls(craft)])
		_expect(ok, "phone craft detail: Craft button visible, inside the view, >= %d px tall" % UiTokens.TARGET_PRIMARY)
		_expect(one != null and one.get_parent().name == "CraftFooter", "phone Craft button is pinned in the footer, not inside a scroll")
		if narrow:
			await _capture("craft_detail", [craft], logical)
	craft.hide_ui()
	# skills: the real HUD path
	_hud.call("_toggle_skills")
	await _frames(3)
	var sheet := _hud.get_node_or_null("SkillsSheet") as SkillsSheet
	_expect(sheet != null and sheet.visible, "skills sheet opens from the HUD")
	if sheet:
		var panel := sheet.get_child(1) as Control
		var scroll := panel.find_child("SkillsScroll", true, false) as ScrollContainer
		var close_btn := panel.find_child("SkillsClose", true, false) as Control
		_expect(close_btn != null and close_btn.is_visible_in_tree() and Rect2(Vector2.ZERO, logical).encloses(close_btn.get_global_rect()), "skills Close is pinned inside the view (%s)" % [close_btn.get_global_rect() if close_btn else "missing"])
		_expect(close_btn != null and not scroll.is_ancestor_of(close_btn), "skills Close sits in the header, outside the scroll")
		var vbar := scroll.get_v_scroll_bar() if scroll else null
		if vbar and vbar.visible:
			var right := 0.0
			for l in _labels_in(sheet):
				right = maxf(right, l.get_global_rect().end.x)
			print("[uireal] skills: rightmost text %.0f, scrollbar starts %.0f" % [right, vbar.get_global_rect().position.x])
			_expect(right <= vbar.get_global_rect().position.x + 0.5, "skills text stays left of the scrollbar (%.0f > %.0f)" % [right, vbar.get_global_rect().position.x])
		# No text over the vitals: the panel clears them, or (landscape phone) hides them under an opaque sheet.
		var opaque := (panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a >= 0.99
		for zone in UiTokens.hud_reserved(logical).slice(0, 1):
			var pr := panel.get_global_rect()
			_expect(not pr.intersects(zone) or (opaque and pr.encloses(zone)), "skills panel %s clears the vitals block %s or covers it opaquely" % [pr, zone])
		# Rows readable without scrolling: under the vitals at 844x390 only 3 of 12 showed.
		var shown := 0
		var total := 0
		for c in _controls_in(sheet):
			if c is Button and str(c.name).begins_with("Skill_"):
				total += 1
				if scroll.get_global_rect().grow(0.5).encloses(c.get_global_rect()):
					shown += 1
		print("[uireal] skills: rows fully visible %d/%d" % [shown, total])
		# No label cut short: portrait cut "Weapon / Tools" to "Weapon / ...".
		for l in _labels_in(sheet):
			_expect(not l.clip_text or text_fits(l), "skills: \"%s\" fits its %.0f px column" % [l.text, l.size.x])
		_expect(shown >= mini(total, 8), "skills shows at least 8 of %d rows without scrolling (got %d)" % [total, shown])
		await _capture("skills", [sheet], logical)
		_check_white("skills", sheet)
		sheet.close()
	# atlas
	_hud.open_map()
	await _frames(3)
	var map := _hud.get_node_or_null("MapLayer/MapScreen") as MapScreen
	_expect(map != null and map.visible, "atlas opens from the HUD")
	if map:
		await _frames(2)
		_check_blocks("atlas", atlas_blocks(map), logical)
		# Every size lists the same charted islands (a phone once showed only the current one).
		var charted := 0
		for key in Data.world_islands.keys():
			charted += 0 if str(key).begins_with("_") else 1
		var cards := (map.get("_cards") as Control).get_child_count()
		print("[uireal] atlas cards: %d of %d charted islands" % [cards, charted])
		_expect(cards == mini(4, charted), "atlas lists %d island cards at every size (got %d)" % [mini(4, charted), cards])
		await _capture("atlas", [map], logical)
		map.close()
	# gather radial on the nearest real harvest node
	var node := _nearest_harvest()
	_expect(node != null, "a harvest node exists on the island")
	if node:
		var radial: GatherRadial = _player.get("_gather_radial")
		radial.open(node, node.options(), _player.inventory)
		await _frames(3)
		var hexes: Array[Control] = []
		for b in radial._buttons:
			hexes.append(b)
		_expect(not hexes.is_empty(), "gather radial shows hexes")
		for i in hexes.size():
			for j in range(i + 1, hexes.size()):
				var d := hexes[i].get_global_rect().get_center().distance_to(hexes[j].get_global_rect().get_center())
				_expect(d >= hexes[i].size.x - 0.5, "radial hexes %d and %d do not overlap (%.0f px)" % [i, j, d])
		# Option labels keep off the survivor's nameplate (at 844x390 "Berries Lv. 1" covered it) and,
		# with the hexes, off every HUD block (turned away from the nameplate, it landed on HANDS).
		var plate := radial.nameplate()
		_expect(plate.has_area() and not radial.label_rects.is_empty(), "radial: nameplate and option labels are on screen")
		var hud := hud_blocks(_hud, _player, logical)
		hud["nameplate"] = plate
		var parts := {}
		for i in radial.label_rects.size():
			parts["label%d" % i] = radial.label_rects[i]
		for i in hexes.size():
			parts["hex%d" % i] = hexes[i].get_global_rect()
		parts["title"] = radial.title_box
		# The name + level box keeps off the hexes and their labels (above the plant it sat under a hex).
		for k in parts:
			if k != "title":
				_expect(not radial.title_box.intersects(parts[k] as Rect2), "radial: title %s stays off %s %s" % [radial.title_box, k, parts[k]])
		# ...and off the plant being gathered and its selection ring: the title box hid both on a phone,
		# so it may not touch them. A hex or label may graze the ring (at most 5 % of its own box):
		# where the plant sits under the HUD at a screen edge (portrait) no ring keeps fully clear.
		var hull := radial.source_hull()
		_expect(hull.size() >= 3, "radial: the gathered source is on screen")
		var worst := 0.0
		for k in parts:
			for h in hud:
				_expect(not (parts[k] as Rect2).intersects(hud[h] as Rect2), "radial: %s %s stays off %s %s" % [k, parts[k], h, hud[h]])
			var share := cover_share(parts[k] as Rect2, hull)
			worst = maxf(worst, share)
			# ASSUMPTION: a 5 % graze of a hex or label reads as clear; the title may not touch.
			_expect(share <= (0.0 if k == "title" else 0.05), "radial: %s %s stays off the plant and its ring %s (covers %.0f%% of it)" % [k, parts[k], radial.source_rect(), share * 100.0])
		print("[uireal] radial: %d option labels, %d hexes and the title checked against %d HUD blocks and the source %s (most of a part on it %.1f%%), nameplate %s" % [radial.label_rects.size(), hexes.size(), hud.size(), radial.source_rect(), worst * 100.0, plate])
		await _capture("radial", hexes, logical)
		radial.close()
	# the HUD past idle, then the creature plate idle and in a hunt (letters inside their rings)
	await _hud_sheets_and_level_up(logical)
	await _pet_out(logical)
	await _capture_plate(logical)
	await _camp_and_station(logical)
	await _busy(logical)
	# bag (protected inventory_ui): it scrolls down, so its columns are checked across the view,
	# and off a portrait phone they must start side by side near the top (the portrait rows pushed
	# the slots and equipment below a 390 px landscape view).
	_player.ui.visible = true
	_player.ui.call("rebuild")
	await _frames(3)
	var bag := bag_blocks(_player.ui)
	_check_blocks("bag", bag, logical, true)
	if logical.x > logical.y:  # by shape, not by the predicates under test
		for col in ["profile_col", "bag_col", "equip_col"]:
			var top: float = (bag[col] as Rect2).position.y if bag.has(col) else INF
			_expect(top < logical.y * 0.5 and absf(top - (bag["profile_col"] as Rect2).position.y) < 8.0, "bag: %s starts beside the others in the top half (y %.0f)" % [col, top])
	# One player level: the bag printed pioneer level + 1 ("Lv. 1") beside the HUD's and atlas's "Lv. 0".
	var profile := _player.ui.get("_profile") as Label
	_expect(profile != null and profile.text.ends_with(LevelDisplay.player_label()), "bag: profile shows the player level %s like the HUD and atlas (got \"%s\")" % [LevelDisplay.player_label(), profile.text.replace("\n", " / ") if profile else "missing"])
	# The held title from character creation on (orchestrator 2026-10-20: level 1 holds titles.json "1").
	var held_title := LevelDisplay.current_title(LevelDisplay.player_level())
	_expect(held_title != "" and profile != null and profile.text.contains(held_title), "bag: profile shows the held title \"%s\"" % held_title)
	await _capture("bag", [], logical)
	_player.ui.visible = false
	# animal screen (protected): shot only, for the eye check of the token theme on it
	_hud.call("_open_animals")
	await _frames(3)
	await _capture("animals", [], logical, false)
	var animals := _hud.get_node_or_null("AnimalLayer/AnimalScreen") as Control
	if animals:
		# Its dim backdrop and sheet fill the screen's own rect; a zero rect leaves the world showing.
		print("[uireal] animals (protected, not gated): screen rect %s, backdrop %s" % [animals.get_global_rect(), (animals.get_child(0) as Control).size])
		animals.call("close_screen")
	# character creation: every card and control inside the view, none overlapping
	var cc := CharacterCreation.new()
	root.add_child(cc)
	await _frames(3)
	# HANDS (layer 64) drew on the creation cards (layer 60) on a fresh save.
	var hands: Control = _player.station_craft.held_slot if _player.station_craft else null
	_expect(hands == null or not hands.is_visible_in_tree(), "charcreate: HANDS hides while character creation is up")
	var cc_rects := {}
	for c in _controls_in(cc):
		if c is Button or c is LineEdit:
			cc_rects[str(c.name)] = c.get_global_rect()
	_expect(cc_rects.has("EnterRift") and cc_rects.has("NameField"), "character creation has the name field and ENTER THE RIFT")
	_check_blocks("charcreate", cc_rects, logical)
	# Cards in one row line up: titles at one y, head-start lines at one y, every line inside its card.
	var rows := {}
	var symbols := 0
	for c in _controls_in(cc):
		if c is Button and str(c.name).begins_with("Card_"):
			# Desktop cards: the head-start symbol fills the band that sat empty (~130 px).
			var band := c.find_child("CardSymbol", true, false) as Control
			var sym := band.get_child(0) as TextureRect if band and band.get_child_count() > 0 else null
			if sym and sym.texture and sym.is_visible_in_tree() and c.get_global_rect().encloses(sym.get_global_rect()):
				symbols += 1
			elif not phone:
				_fail("charcreate: %s shows its head-start symbol inside the card" % c.name)
			var lines := _labels_in(c)
			for l in lines:
				_expect(c.get_global_rect().grow(0.5).encloses(l.get_global_rect()), "charcreate: %s line \"%s\" inside its card" % [c.name, l.text.left(20)])
			if not lines.is_empty():
				(rows.get_or_add(roundi(c.get_global_rect().position.y), []) as Array).append(Vector2(lines[0].get_global_rect().position.y, lines[-1].get_global_rect().position.y))
	var spread := Vector2.ZERO
	for y in rows:
		var lo := Vector2(INF, INF)
		var hi := -lo
		for v: Vector2 in rows[y]:
			lo = lo.min(v)
			hi = hi.max(v)
		spread = spread.max(hi - lo)
	print("[uireal] charcreate cards: rows=%d title_y_spread=%.1f start_y_spread=%.1f symbols=%d" % [rows.size(), spread.x, spread.y, symbols])
	_expect(spread.x <= 1.0 and spread.y <= 1.0, "charcreate: card titles and head starts line up across each row (spread %s)" % spread)
	for key in ["Body_f", "Body_m", "NameField", "EnterRift"]:
		_expect(not cc_rects.has(key) or (cc_rects[key] as Rect2).size.y >= UiTokens.TARGET_PRIMARY - 0.5, "charcreate: %s is at least %d px tall (%s)" % [key, UiTokens.TARGET_PRIMARY, cc_rects.get(key)])
	await _capture("charcreate", [cc.get_child(0) as Control], logical)
	if symbols > 0:  # phone cards have no room for one
		_check_white("charcreate", cc)
	cc.queue_free()
	await _resize(logical)
	_finish(phone, logical)

## The canvas changes under a running game (a browser window resized, a tablet turned, a phone's
## toolbar collapsing): the HUD's context hexes and an open skills sheet lay out again on the new
## canvas. CLAIM kept its 1600x900 spot, off an 844x390 view, and the sheet kept one desktop column.
## The other size is a shot only for fonts (the type floor is gated on the run's own canvas).
func _resize(logical: Vector2) -> void:
	var win := get_window()
	var start := win.size
	var other := Vector2i(1600, 900) if UiTokens.is_compact(logical) else Vector2i(844, 390)
	for step: Array in [["resize_other", other], ["resize_back", start]]:
		var tag: String = step[0]
		_hud.call("_toggle_skills")  # open, then the canvas changes under it
		await _frames(3)
		win.size = step[1]
		await _frames(30)
		var now := get_tree().root.get_visible_rect().size
		var sheet := _hud.get_node_or_null("SkillsSheet") as SkillsSheet
		var grid := sheet.find_child("SkillsGrid", true, false) as GridContainer if sheet else null
		var panel := sheet.get_child(1) as Control if sheet else null
		var want := 2 if SkillsSheet.is_sheet(now) else 1
		print("[uireal] %s: window %s canvas %s, skills columns %d (want %d), panel %s" % [tag, win.size, now, grid.columns if grid else -1, want, panel.get_global_rect() if panel else "missing"])
		_expect(grid != null and grid.columns == want, "%s: the open skills sheet lays out for the %s canvas (%d columns, want %d)" % [tag, now, grid.columns if grid else -1, want])
		_expect(panel != null and Rect2(Vector2.ZERO, now).grow(1.0).encloses(panel.get_global_rect()), "%s: the skills panel sits inside the %s canvas (%s)" % [tag, now, panel.get_global_rect() if panel else "missing"])
		await _capture(tag + "_skills", [panel] if panel else [], now, tag == "resize_back")
		if sheet:
			sheet.close()
		await _frames(3)
		var blocks := with_world_hexes(hud_blocks(_hud, _player, now), _hud)
		var ctx: Array = _hud.get("_ctx_hexes")
		print("[uireal] %s: %d context hexes %s" % [tag, ctx.size(), ctx.map(func (h: HexButton) -> String: return "%s %s" % [h.caption, h.hex_rect()])])
		_expect(not ctx.is_empty(), "%s: a context hex shows on the %s canvas" % [tag, now])
		_check_blocks(tag, blocks, now)
		await _capture(tag, [], now, tag == "resize_back")

func _finish(phone: bool, logical: Vector2) -> void:
	var narrow := UiTokens.is_narrow(logical)
	# min_font_px: the smallest font size on the logical canvas; min_font_pt: its on-screen size in
	# points (window px / device scale), the unit the phone floor is gated in.
	var stretch := get_tree().root.get_final_transform().get_scale().x
	var min_px := int(floor(_min_font / stretch + 0.01)) if _min_font < INF else 0
	var pts := DisplayMode.window_points(get_tree().root)
	var min_pt := _min_font / DisplayMode.device_scale() if _min_font < INF else 0.0
	# "phone" is UiTokens.is_compact (the phone layouts); is_phone keeps its old meaning (under 720 px
	# wide) for the protected screens, so it reads false at 844x390.
	print("[uireal] phone means is_compact=%s; is_phone=%s (under 720 px wide, protected screens)" % [phone, UiTokens.is_phone(logical)])
	print("[uireal] phone=%s min_font_px=%d min_font_pt=%.2f logical_width=%d window_pt=%dx%d floor_pt=%.2f (smallest: %s)" % [phone, min_px, min_pt, int(logical.x), int(pts.x), int(pts.y), type_floor_pt(pts), _min_font_where])
	_fails.append_array(gate_failures(pts, phone, min_pt, int(logical.x)))
	if _fails.is_empty():
		print("[uireal] PASS screens=hud,hud_daynight,craft,%sskills,atlas,radial,sheet_menu,sheet_build,levelup,pet_out,plate,plate_front,combat,camp_bonfire,station_bonfire,camp_workbench,station_workbench,busy,busy_levelup,bag,charcreate,resize_other,resize_back shot_only=animals shots=%s" % ["craft_detail," if narrow else "", _out])
		get_tree().quit(0)
	else:
		for f in _fails:
			print("[uireal] FAIL %s" % f)
		get_tree().quit(1)

## Smallest text a phone window may show, in points: TYPE_MIN logical px on the canvas the fit
## gives it (12 pt at 1:1; 10.5 pt where a 667 pt landscape phone is scaled up to LANDSCAPE_MIN_W).
static func type_floor_pt(pts: Vector2) -> float:
	var want := DisplayMode.logical_size(Vector2i(pts.round()), 1.0)
	return float(UiTokens.TYPE_MIN) * minf(1.0, pts.x / float(maxi(1, want.x)))

## The gate's verdict on the canvas fit. A phone window, either way up, must get the phone canvas
## (is_compact true, the width logical_size gives it) and the type floor whatever the screens did;
## before this a missing fit (phone=false, 3 px text) passed because neither branch ran under 1600 px.
static func gate_failures(pts: Vector2, phone: bool, min_pt: float, logical_w: int) -> Array[String]:
	var out: Array[String] = []
	var handheld := DisplayMode.is_phone_window(pts) or DisplayMode.is_phone_landscape(pts)
	if handheld:
		var want := DisplayMode.logical_size(Vector2i(pts.round()), 1.0)
		if not phone or logical_w != want.x:
			out.append("a %dx%d pt phone window must get the %d px phone canvas (is_compact %s, logical width %d)" % [int(pts.x), int(pts.y), want.x, phone, logical_w])
		if min_pt < type_floor_pt(pts) - 0.05:
			out.append("phone window %dx%d pt: text at least %.1f pt on screen (got %.1f)" % [int(pts.x), int(pts.y), type_floor_pt(pts), min_pt])
	elif pts.y > pts.x and pts.x < DisplayMode.TABLET_MAX_PT:
		if logical_w > DisplayMode.TABLET_W:
			out.append("portrait tablet %dx%d pt gets a canvas at most %d wide (got %d)" % [int(pts.x), int(pts.y), DisplayMode.TABLET_W, logical_w])
	elif pts.x >= float(DisplayMode.DESIGN.x) and logical_w != DisplayMode.DESIGN.x:
		out.append("desktop keeps a %d px logical width (got %d)" % [DisplayMode.DESIGN.x, logical_w])
	return out

## Moving text (toasts, notices, building labels) keeps off the survivor's figure (HuntHud.figure_rect):
## at 844x390 the notices sat on the survivor at the centre of the screen.
func _check_figure(tag: String, blocks: Dictionary) -> void:
	var fig := _hud.figure_rect()
	_expect(fig.has_area(), "%s: the survivor's figure is on screen" % tag)
	for k in blocks:
		if str(k).begins_with("toast") or str(k).begins_with("notice") or str(k).begins_with("pill"):
			_expect(not (blocks[k] as Rect2).grow(-0.5).intersects(fig), "%s: %s %s stays off the survivor %s" % [tag, k, blocks[k], fig])

## Every rect inside the view (only across it, when `x_only`: the bag scrolls down) and no
## two overlapping. Prints the blocks so a failure names what hit what.
func _check_blocks(screen: String, rects: Dictionary, logical: Vector2, x_only: bool = false) -> void:
	var view := Rect2(Vector2.ZERO, logical).grow(1.0)
	var names: Array = rects.keys()
	var parts: PackedStringArray = []
	for n in names:
		var r: Rect2 = rects[n]
		parts.append("%s=%d,%d %dx%d" % [n, r.position.x, r.position.y, r.size.x, r.size.y])
		var inside := view.encloses(r) if not x_only else (r.position.x >= view.position.x and r.end.x <= view.end.x)
		_expect(inside, "%s: %s %s inside the %dx%d view" % [screen, n, r, logical.x, logical.y])
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			_expect(not a.grow(-0.5).intersects(b.grow(-0.5)), "%s: %s %s overlaps %s %s" % [screen, names[i], a, names[j], b])
	print("[uireal] %s blocks: %s" % [screen, " ".join(parts)])

## HUD blocks: its visible controls (hexes with their caption, the minimap, End Combat, the stance
## text), the held-tool slot, and the blocks it draws as HuntHud.drawn_blocks records them (vitals,
## quest card, map text, status badges, level line, target plate, level-up banner). An open sheet is
## checked on its own (_check_sheet): it covers the HUD on purpose.
static func hud_blocks(hud: HuntHud, player: Player, _r: Vector2) -> Dictionary:
	var out := {}
	for c in hud.get_children():
		var ctl := c as Control
		if ctl == null or not ctl.is_visible_in_tree() or ctl.top_level or ctl.size.x < 8.0 or ctl.size.y < 8.0 or ctl.name == "HudSheet":
			continue
		if ctl is Label and (ctl as Label).text.strip_edges() == "":
			continue
		var key := "%s#%d" % [ctl.name if not ctl is HexButton else (ctl as HexButton).caption, out.size()]
		if ctl is HexButton:
			# the drawn hexagon and its caption, not the control's square
			out[key] = (ctl as HexButton).hex_rect()
			if (ctl as HexButton).caption != "":
				out[key + ".caption"] = (ctl as HexButton).caption_rect()
		else:
			out[key] = ctl.get_global_rect()
	var held: Control = player.station_craft.held_slot if player and player.station_craft else null
	if held and held.is_visible_in_tree():
		out["HeldItemSlot"] = Rect2(held.get_global_rect().position, held.size + Vector2(0, 18))
	for k in hud.drawn_blocks:
		out[k] = hud.drawn_blocks[k]
	return out

## The menu and build sheets (at 844x390 the menu ran 192 px off the top and HANDS sat on its Close),
## then a level-up (its 13-line stack ran over the rail and off the bottom).
func _hud_sheets_and_level_up(logical: Vector2) -> void:
	Game.ensure_creature_plates()  # its layer sits above the HUD's: plates must hide under a sheet
	for kind in ["menu", "build"]:
		_hud.call("_toggle_sheet", StringName(kind))
		await _frames(3)
		var sheet := _hud.get("_sheet") as Control
		_check_sheet(kind, sheet, logical)
		await _capture("sheet_" + kind, [sheet] if sheet else [], logical)
		_hud.call("_close_sheet")
		await _frames(2)
	# Stored level 4 -> "Lv. 5", which brings a title: the banner's longest form. World is untouched.
	_hud.call("_on_level_up", 4)
	await _frames(3)
	var blocks := hud_blocks(_hud, _player, logical)
	_expect(blocks.has("levelup"), "levelup: the banner is drawn")
	_check_blocks("levelup", blocks, logical)
	await _capture("levelup", [], logical)
	_hud.set("_levelup_t", -1.0)
	await _frames(2)

## A sheet sits inside the view with its title and Close pinned above the rows; every row button is
## fully inside the rows' window or the rows scroll; nothing drawn after it (HANDS, a HUD hex added
## later) covers it.
func _check_sheet(kind: String, sheet: Control, logical: Vector2) -> void:
	_expect(sheet != null and sheet.is_visible_in_tree(), "sheet %s opens" % kind)
	if sheet == null:
		return
	var view := Rect2(Vector2.ZERO, logical).grow(0.5)
	var rect := sheet.get_global_rect()
	_expect(view.encloses(rect), "sheet %s %s inside the %dx%d view" % [kind, rect, logical.x, logical.y])
	# The vitals stay whole: clear of the sheet, or under it entirely (it is opaque there).
	var vitals: Rect2 = _hud.drawn_blocks.get("vitals", Rect2())
	var opaque := (sheet.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a >= 0.99
	_expect(not rect.intersects(vitals) or (opaque and rect.encloses(vitals)), "sheet %s %s clears the vitals %s or covers them whole and opaque" % [kind, rect, vitals])
	var rows := sheet.find_child("SheetRows", true, false) as ScrollContainer
	var close := sheet.find_child("SheetClose", true, false) as Control
	_expect(rows != null and close != null and not rows.is_ancestor_of(close), "sheet %s: Close is pinned outside the rows" % kind)
	if rows == null or close == null:
		return
	_expect(view.encloses(close.get_global_rect()) and close.size.y >= UiTokens.TARGET_PRIMARY - 0.5, "sheet %s: Close %s inside the view, >= %d px" % [kind, close.get_global_rect(), UiTokens.TARGET_PRIMARY])
	for l in _labels_in(sheet):
		if not rows.is_ancestor_of(l):
			_expect(view.encloses(l.get_global_rect()), "sheet %s: title \"%s\" %s inside the view" % [kind, l.text, l.get_global_rect()])
	var shown := 0
	var total := 0
	for b in sheet.find_children("*", "Button", true, false):
		if b == close:
			continue
		total += 1
		if rows.get_global_rect().grow(0.5).encloses((b as Control).get_global_rect()):
			shown += 1
	var scrolls := rows.get_v_scroll_bar().visible
	print("[uireal] sheet %s %s: %d/%d rows fully shown, rows scroll=%s" % [kind, rect, shown, total, scrolls])
	_expect(total > 0 and (shown == total or scrolls), "sheet %s: rows past its window scroll (%d/%d shown)" % [kind, shown, total])
	if kind == "menu":  # Bag, Craft, Map, Save, Debug: one look, no scroll
		_expect(shown == total, "sheet menu shows all %d rows without scrolling (got %d)" % [total, shown])
	var held: Control = _player.station_craft.held_slot if _player.station_craft else null
	_expect(held == null or not held.is_visible_in_tree() or not held.get_global_rect().intersects(rect), "sheet %s: HANDS is hidden or off the sheet (%s)" % [kind, held.get_global_rect() if held else ""])
	var plates := Game.creature_ui as CreaturePlates
	_expect(plates == null or not (plates.get("_root") as Control).visible, "sheet %s: creature plates hide while it is open" % kind)
	var above := false
	for c in _hud.get_children():
		if c == sheet:
			above = true
		elif above and c is Control and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().intersects(rect):
			_fail("sheet %s: %s %s draws over it" % [kind, c.name, (c as Control).get_global_rect()])

## A bonded raptor out: the whistle hexes join the HUD (at 844x390 they sat on the minimap and ran
## off the top).
func _pet_out(logical: Vector2) -> void:
	_player.bonded.append(PetRecord.from_def(Data.creature(&"velociraptor"), &"A"))
	_player.summon_pet(_player.bonded.size() - 1)
	await get_tree().create_timer(0.6).timeout
	var whistles := 0
	for h in _hud.get("_whistle_hexes"):
		whistles += 1 if (h as Control).is_visible_in_tree() else 0
	print("[uireal] pet out: pets=%d whistles=%d" % [_player.live_pets().size(), whistles])
	_expect(whistles == 3, "pet out: three whistle hexes show (got %d)" % whistles)
	_check_blocks("pet_out", hud_blocks(_hud, _player, logical), logical)
	await _capture("pet_out", [], logical)

## Share of `r` that lies on the convex polygon `hull` (0 when they only touch).
static func cover_share(r: Rect2, hull: PackedVector2Array) -> float:
	var poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var area := 0.0
	for piece in Geometry2D.intersect_polygons(poly, hull):
		var a := 0.0
		for i in piece.size():
			a += piece[i].cross(piece[(i + 1) % piece.size()])
		area += absf(a) * 0.5
	return area / maxf(1.0, r.get_area())

## Atlas blocks: the map square, Close, the action row, zoom, the island cards and the legend.
static func atlas_blocks(map: MapScreen) -> Dictionary:
	var r := map.get_viewport_rect().size
	var out := {"map": map.call("_map_rect", map.call("_layout")), "close": (map.get("_close") as Control).get_global_rect(), "actions": (map.get("_btn_row") as Control).get_global_rect()}
	var zoom_row := map.get_node_or_null("ZoomRow") as Control
	if zoom_row:
		out["zoom"] = zoom_row.get_global_rect()
	# Cards scroll in their column: only the part inside it is on screen.
	var cards := map.get("_cards") as Control
	var column := (map.get("_card_scroll") as Control).get_global_rect()
	for i in cards.get_child_count():
		var card := cards.get_child(i) as Control
		if card and not card.is_queued_for_deletion() and column.intersects(card.get_global_rect()):
			out["card%d" % i] = column.intersection(card.get_global_rect())
	var kinds: Array = map.call("_legend_kinds")
	for i in kinds.size():
		var row := Rect2(MapScreen.legend_slot(i, r) + Vector2(0.0, -15.0), Vector2(MapScreen.legend_col_w(r), 20.0))
		out["legend"] = row if i == 0 else (out["legend"] as Rect2).merge(row)
	return out

## Bag columns (profile, slots, equipment) and its close button.
static func bag_blocks(bag: Node) -> Dictionary:
	var out := {}
	for key in ["_profile_col", "_bag_col", "_equip_col", "_close_btn"]:
		var c := bag.get(key) as Control
		if c and c.is_visible_in_tree():
			out[key.trim_prefix("_")] = c.get_global_rect()
	return out

func _controls_in(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	if node is Control and (node as Control).is_visible_in_tree():
		out.append(node)
	for c in node.get_children():
		out.append_array(_controls_in(c))
	return out

func _visible_vscrolls(node: Node) -> int:
	var n := 0
	var sc := node as ScrollContainer
	if sc and sc.is_visible_in_tree() and sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		n += 1
	for c in node.get_children():
		n += _visible_vscrolls(c)
	return n

func _labels_in(node: Node) -> Array[Label]:
	var out: Array[Label] = []
	if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text != "":
		out.append(node)
	for c in node.get_children():
		out.append_array(_labels_in(c))
	return out

func _capture_plate(logical: Vector2) -> void:
	var wild: Creature = null
	for n in get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c and not c.is_pet and not c.health.dead:
			wild = c
			break
	_expect(wild != null, "a wild creature exists for the plate shot")
	if wild == null:
		return
	wild.process_mode = Node.PROCESS_MODE_DISABLED  # hold it still beside the survivor
	wild.global_position = _player.global_position + Vector3(2.5, 0.0, 1.0)
	for id in [&"knockdown", &"groggy", &"bleed"]:
		wild.statuses.apply(id)
	wild.last_damaged_s = float(Time.get_ticks_msec()) * 0.001 + 30.0
	Game.ensure_creature_plates()
	await get_tree().create_timer(1.0).timeout
	var plates := Game.creature_ui as CreaturePlates
	var entry: Dictionary = plates._entries.get(wild.get_instance_id(), {}) if plates else {}
	var node := entry.get("node", null) as Control
	_expect(node != null and node.visible, "the wild creature shows a plate")
	if node == null:
		return
	# Recently hit but not the target: on a phone the plate is name and bar only (with its status row
	# the 176x72 pill covered the survivor beside a compy at 844x390); the desktop keeps every row.
	var pill := entry["pill"] as Control
	var glyphs := _plate_glyphs(entry)
	print("[uireal] plate %s glyphs=%d pill=%s" % [(entry["line1"] as Label).text, glyphs, pill.size])
	if UiTokens.is_compact(logical):
		_expect(glyphs == 0 and pill.size.y <= 42.0, "phone plate of a creature that is not the target: name and bar only (glyphs %d, pill %s)" % [glyphs, pill.size])
	else:
		_expect(glyphs >= 2, "plate shows its status glyphs")
	_check_plate_pill("plate", node, pill, wild)
	await _capture("plate", [pill], logical)
	# In front of the survivor (toward the camera), where the plate, about 80 px over the creature's
	# feet, would sit on the survivor's name unless it moves.
	var cam := get_viewport().get_camera_3d()
	var toward := cam.global_position - _player.global_position
	toward.y = 0.0
	var name_y: float = (_hud.drawn_blocks.get("nameplate", Rect2()) as Rect2).position.y
	var best_d := 1.0
	for i in 24:
		var d := 0.5 + 0.25 * float(i)
		if absf(cam.unproject_position(_player.global_position + toward.normalized() * d).y - name_y - 80.0) < absf(cam.unproject_position(_player.global_position + toward.normalized() * best_d).y - name_y - 80.0):
			best_d = d
	wild.global_position = _player.global_position + toward.normalized() * best_d
	print("[uireal] plate_front: compy %.2f m toward the camera, feet at y %.0f, name at y %.0f" % [best_d, cam.unproject_position(wild.global_position).y, name_y])
	await get_tree().create_timer(0.5).timeout
	_expect(node.visible, "plate_front: the plate finds a free spot and shows")
	_check_plate_pill("plate_front", node, pill, wild)
	await _capture("plate_front", [pill], logical)
	wild.global_position = _player.global_position + Vector3(2.5, 0.0, 1.0)
	# The hunt, pet still out: End Combat, the skills, Auto/Feed, whistles, the target plate. At 844x390
	# End Combat sat on ROLL and the target bar ran across the vitals and the quest card.
	_player.hunt.start(wild)
	_player.hunt.auto = false  # no swings: the plate shot needs it alive
	_player.hunt.hold = true
	await get_tree().create_timer(0.6).timeout
	var blocks := hud_blocks(_hud, _player, logical)
	_expect(blocks.has("plate") and (_hud.get("_end_btn") as Control).is_visible_in_tree(), "combat: the target plate and End Combat show")
	_check_blocks("combat", blocks, logical)
	glyphs = _plate_glyphs(entry)
	print("[uireal] combat plate %s glyphs=%d" % [(entry["line1"] as Label).text, glyphs])
	# A target plate with no free spot hides (portrait: the combat cluster fills the screen round the
	# survivor); the HUD's target plate then carries the statuses.
	_expect(glyphs >= 2 or (not node.visible and blocks.has("plate")), "the target's plate shows its status glyphs, or hides under the HUD's target plate")
	_check_plate_pill("combat", node, entry["pill"] as Control, wild)
	await _capture("combat", [entry["pill"]], logical)
	# 3x crop so the glyph letters can be checked by eye
	var img := get_tree().root.get_texture().get_image()
	var stretch := get_tree().root.get_final_transform().get_scale().x
	var r := Rect2i(Rect2(node.get_global_rect().position * stretch - Vector2(8, 8), node.get_global_rect().size * stretch + Vector2(16, 16)))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x > 4 and r.size.y > 4:
		var crop := img.get_region(r)
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(_out.path_join("plate_zoom_%dx%d.png" % [get_tree().root.size.x, get_tree().root.size.y]))
	_player.hunt.stop()
	wild.process_mode = Node.PROCESS_MODE_INHERIT

## At the camp's bonfire and workbench, the pet still out: the building labels keep off the quest
## card and the HUD (at 844x390 "Tent" and "Bonfire" sat on the quest text), then with the station
## menu open its hexes keep off them too (COOK covered "Cargo Warp").
func _camp_and_station(logical: Vector2) -> void:
	_hud.set("_last_target", null)  # the quest card comes back: the labels must keep off it
	for sid: StringName in [&"bonfire", &"workbench"]:
		var st := Crafting.nearest_station(_player, sid)
		_expect(st != null, "camp: a %s stands on the home island" % sid)
		if st == null:
			continue
		_player.global_position = st.global_position + Vector3(2.0, 0.0, 2.0)
		await get_tree().create_timer(0.8).timeout
		var blocks := with_world_hexes(hud_blocks(_hud, _player, logical), _hud)
		var pills := count_prefix(blocks, "pill")
		print("[uireal] camp %s: %d labels, quest card %s" % [sid, pills, blocks.get("quest", "hidden")])
		# Portrait: the map column covers half the camp, and a label never steps sideways off it.
		# shortcut: portrait keeps one label; let layout_labels try a sideways step if portrait comes back.
		var want := 1 if UiTokens.is_narrow(logical) else 2
		_expect(pills >= want and blocks.has("quest"), "camp_%s: at least %d camp labels and the quest card are drawn (labels %d)" % [sid, want, pills])
		_check_blocks("camp_%s" % sid, blocks, logical)
		_check_figure("camp_%s" % sid, blocks)
		await _capture("camp_%s" % sid, [], logical)
		_player.open_station_craft(st)
		await get_tree().create_timer(0.6).timeout
		blocks = with_world_hexes(hud_blocks(_hud, _player, logical), _hud)
		print("[uireal] station %s: %d hexes, %d labels" % [sid, count_prefix(blocks, "xhex"), count_prefix(blocks, "pill")])
		_expect(count_prefix(blocks, "xhex") >= 1, "station_%s: the station menu shows hexes" % sid)
		_check_blocks("station_%s" % sid, blocks, logical)
		_check_figure("station_%s" % sid, blocks)
		await _capture("station_%s" % sid, [], logical)
		_player.station_craft.menu.hide_menu()
		await get_tree().create_timer(0.3).timeout

## Three pickups, two notices, then a level-up on top, the pet still out: every toast and notice gets
## a spot of its own off the HUD (at 844x390 they crossed the quest card).
func _busy(logical: Vector2) -> void:
	for id: StringName in [&"wood", &"stone", &"fiber"]:
		_hud.toast(id, 3)
	_hud.notice("Need a stone knife to butcher this")
	_hud.notice("Too heavy to carry more")
	for tag in ["busy", "busy_levelup"]:
		if tag == "busy_levelup":
			_hud.call("_on_level_up", 4)
		await _frames(3)
		var blocks := with_world_hexes(hud_blocks(_hud, _player, logical), _hud)
		var toasts := count_prefix(blocks, "toast")
		var notices := count_prefix(blocks, "notice")
		print("[uireal] %s: toasts=%d notices=%d levelup=%s" % [tag, toasts, notices, blocks.has("levelup")])
		_expect(toasts >= 3 and notices >= 2, "%s: all 3 toasts and 2 notices are drawn (got %d, %d)" % [tag, toasts, notices])
		_check_blocks(tag, blocks, logical)
		_check_figure(tag, blocks)
		await _capture(tag, [], logical)
	_hud.set("_levelup_t", -1.0)

## `blocks` plus every hex outside the HUD (station menu, gather radial) with its caption, as xhex<n>.
static func with_world_hexes(blocks: Dictionary, hud: HuntHud) -> Dictionary:
	for n in hud.get_tree().get_nodes_in_group(&"hex_button"):
		var h := n as HexButton
		if h and h.is_visible_in_tree() and not hud.is_ancestor_of(h):
			var key := "xhex%d" % blocks.size()
			blocks[key] = h.hex_rect()
			if h.caption != "":
				blocks[key + ".caption"] = h.caption_rect()
	return blocks

## Keys starting with `prefix`, captions not counted.
static func count_prefix(blocks: Dictionary, prefix: String) -> int:
	var n := 0
	for k in blocks:
		n += 1 if str(k).begins_with(prefix) and not str(k).contains(".") else 0
	return n

## The opaque pill (layer 58, above the HUD) keeps off the survivor's name and every HUD block and
## hex (beside a compy it hid the name whole), and off the creature it names (pushed down off the
## HUD, it covered the compy and its target ring at 667x375 and 844x390).
func _check_plate_pill(tag: String, node: Control, pill: Control, who: Creature) -> void:
	var pill_rect := pill.get_global_transform() * Rect2(Vector2.ZERO, pill.size)
	var under := 0
	for h in (_hud.taken_rects(PackedStringArray(["pill"])) if node.visible else []):
		under += 1
		_expect(not pill_rect.grow(-0.5).intersects(h), "%s: pill %s stays off the HUD rect %s" % [tag, pill_rect, h])
	var body := CreaturePlates.creature_box(get_viewport().get_camera_3d(), who)
	_expect(body.has_area(), "%s: the %s is on screen" % [tag, who.def.id])
	_expect(not node.visible or not pill_rect.grow(-0.5).intersects(body), "%s: pill %s stays off its creature %s" % [tag, pill_rect, body])
	print("[uireal] %s pill %s shown=%s checked against %d HUD rects (nameplate %s) and its %s %s" % [tag, pill_rect, node.visible, under, _hud.drawn_blocks.get("nameplate"), who.def.id, body])
	_expect(_hud.drawn_blocks.has("nameplate"), "%s: the survivor's name is drawn" % tag)

static func _plate_glyphs(entry: Dictionary) -> int:
	var line3 := entry["line3"] as Control
	var n := 0
	for g in line3.get_children():
		n += 1 if line3.is_visible_in_tree() and (g as Control).visible else 0
	return n

## Checks one open screen and saves the root viewport as <name>_<w>x<h>.png.
func _capture(name: String, roots: Array, logical: Vector2, gated: bool = true) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	if not gated:
		var shot := get_tree().root.get_texture().get_image()
		if shot and shot.get_width() >= 8:
			var at := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
			shot.save_png(at)
			print("[uireal] shot %s (not gated)" % at)
		return
	var view := Rect2(Vector2.ZERO, logical)
	for r in roots:
		var c := r as Control
		if c == null:
			_fail("%s: screen root missing" % name)
			continue
		var rect := c.get_global_rect()
		_expect(rect.size.x >= 8.0 and rect.size.y >= 8.0, "%s: %s has size (%s)" % [name, c.name, rect.size])
		_expect(view.grow(1.0).encloses(rect), "%s: %s inside the view (%s)" % [name, c.name, rect])
	_scan_fonts(get_tree().root, name)
	var img := get_tree().root.get_texture().get_image()
	if img == null or img.get_width() < 8:
		_fail("%s: no pixels (run windowed, not --headless)" % name)
		return
	var path := _out.path_join("%s_%dx%d.png" % [name, get_tree().root.size.x, get_tree().root.size.y])
	img.save_png(path)
	_shots.append(path)
	var stats := _exposure(img)
	print("[uireal] shot %s mean=%.2f dev=%.3f blown=%.3f" % [path, stats.x, stats.y, stats.z])
	_expect(stats.y >= FLAT_MIN, "%s: frame is not blank (luma deviation %.3f)" % [name, stats.y])
	_expect(stats.z <= BLOWN_MAX, "%s: not blown out (%.0f%% near-white)" % [name, stats.z * 100.0])

## A clipped label's text is no wider than the label.
static func text_fits(l: Label) -> bool:
	return l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x <= l.size.x + 0.5

## White symbols (HexButton.white_material) must render white on the GPU: of the bright pixels
## under each visible TextureRect in `node`, under 10 % may be coloured (the item icons are brown,
## green, red). Reads the frame _capture just drew.
func _check_white(screen: String, node: Node) -> void:
	var img := get_tree().root.get_texture().get_image()
	var xf := get_tree().root.get_final_transform()
	var worst := 0.0
	var n := 0
	for c in _controls_in(node):
		var t := c as TextureRect
		if t == null or t.texture == null or t.material != HexButton.white_material() or not on_screen(t):
			continue
		n += 1
		var r := Rect2i(Rect2(xf * t.get_global_rect().position, t.get_global_rect().size * xf.get_scale())).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var bright := 0
		var coloured := 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var p := img.get_pixel(x, y)
				if p.v > 0.6:
					bright += 1
					if p.s > 0.35:
						coloured += 1
		worst = maxf(worst, float(coloured) / maxf(1.0, float(bright)))
	print("[uireal] %s white symbols: %d checked, most coloured %.2f" % [screen, n, worst])
	_expect(n > 0 and worst < 0.1, "%s: white symbols render white (%d checked, worst %.0f%% coloured)" % [screen, n, worst * 100.0])

## Smallest on-screen size of any visible text control, after content scale and plate scaling.
func _scan_fonts(node: Node, screen: String) -> void:
	var stretch := get_tree().root.get_final_transform().get_scale().x
	_scan_fonts_from(node, screen, stretch)

func _scan_fonts_from(node: Node, screen: String, stretch: float) -> void:
	var c := node as Control
	if c and not c.is_visible_in_tree():
		return
	if c and c.modulate.a > 0.05 and (c is Label or c is Button or c is LineEdit) and on_screen(c):
		var text := str(c.get("text"))
		if text.strip_edges() != "":
			var px := float(c.get_theme_font_size("font_size")) * stretch * c.get_global_transform_with_canvas().get_scale().x
			if px < _min_font:
				_min_font = px
				_min_font_where = "%s %s \"%s\" %.1f px" % [screen, c.get_path(), text.left(24).replace("\n", " "), px / stretch]
	for child in node.get_children():
		_scan_fonts_from(child, screen, stretch)

## A text control counts for the font gate only when part of it is drawn: a zero-size label or
## one clipped out by its parents (the old craft hint) is text nobody sees.
static func on_screen(c: Control) -> bool:
	var rect := c.get_global_rect()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return false
	var p := c.get_parent() as Control
	while p:
		if p.clip_contents or p is ScrollContainer:
			rect = rect.intersection(p.get_global_rect())
			if rect.size.x < 1.0 or rect.size.y < 1.0:
				return false
		p = p.get_parent() as Control
	return Rect2(Vector2.ZERO, c.get_viewport_rect().size).intersects(rect)

## (mean luma, luma deviation, share of near-white pixels) on a 64 px grid sample.
func _exposure(img: Image) -> Vector3:
	var n := 0
	var sum := 0.0
	var sum2 := 0.0
	var blown := 0
	var step := maxi(1, int(min(img.get_width(), img.get_height()) / 64))
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var l := img.get_pixel(x, y).get_luminance()
			sum += l
			sum2 += l * l
			if l > 0.97:
				blown += 1
			n += 1
	var mean := sum / maxf(1.0, n)
	return Vector3(mean, sqrt(maxf(0.0, sum2 / maxf(1.0, n) - mean * mean)), float(blown) / maxf(1.0, n))

func _nearest_harvest() -> HarvestNode:
	var best: HarvestNode = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or hn.depleted or not hn.visible or hn.options().is_empty():
			continue
		var d := _player.global_position.distance_to(hn.global_position)
		if d < best_d:
			best_d = d
			best = hn
	return best

func _labels_named(node: Node, wanted: String) -> Array[Label]:
	var out: Array[Label] = []
	if node is Label and node.name == wanted and (node as Label).is_visible_in_tree():
		out.append(node)
	for child in node.get_children():
		out.append_array(_labels_named(child, wanted))
	return out

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)

func _fail(message: String) -> void:
	_fails.append(message)
