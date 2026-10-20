extends Node3D
## Real-scene UI gate (W1-UI). Boots the home island with the real HUD, fits the logical canvas and
## installs the theme the way boot does (DisplayMode.install, DisplayMode.install_theme), then opens
## the HUD, craft, skills, atlas, a gather radial, the bag and character creation in the ROOT
## viewport (not a sized SubViewport, which hid the phone problem) and saves a PNG of each. Every
## screen must have size, sit inside the view, draw no text under 12 logical px and be neither blank
## nor blown out; the HUD, atlas, bag and character creation also check that their blocks and
## controls stay inside the view and do not overlap each other.
## Windowed: --resolution 844x390 -- --lab=ui_real_capture_lab [--shot-dir=DIR] [--no-fit]
## (844x390 is the phone check: the owner plays phones landscape; 667x375, 390x844 and 1600x900 also
## run.) --no-fit skips DisplayMode.install: the gate's self-test, which must then FAIL on a phone
## window. Prints "[uireal] phone=<bool> min_font_px=<n> ..." then "[uireal] PASS" (exit 0) or FAIL
## lines (exit 1).

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
	var fit := true
	_out = OS.get_user_data_dir().path_join("ui-real")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		elif a == "--no-fit":
			fit = false
	if fit:
		DisplayMode.install(get_tree().root)
	DisplayMode.install_theme()
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
		for zone in UiTokens.hud_reserved(logical).slice(0, 1):
			_expect(not panel.get_global_rect().intersects(zone), "skills panel %s clears the vitals block %s" % [panel.get_global_rect(), zone])
		await _capture("skills", [sheet], logical)
		sheet.close()
	# atlas
	_hud.open_map()
	await _frames(3)
	var map := _hud.get_node_or_null("MapLayer/MapScreen") as MapScreen
	_expect(map != null and map.visible, "atlas opens from the HUD")
	if map:
		await _frames(2)
		_check_blocks("atlas", map.layout_rects(), logical)
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
		await _capture("radial", hexes, logical)
		radial.close()
	# creature plate with three status glyphs (letters must sit inside their rings)
	await _capture_plate(logical)
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
	await _capture("bag", [], logical)
	_player.ui.visible = false
	# character creation: every card and control inside the view, none overlapping
	var cc := CharacterCreation.new()
	root.add_child(cc)
	await _frames(3)
	var cc_rects := {}
	for c in _controls_in(cc):
		if c is Button or c is LineEdit:
			cc_rects[str(c.name)] = c.get_global_rect()
	_expect(cc_rects.has("EnterRift") and cc_rects.has("NameField"), "character creation has the name field and ENTER THE RIFT")
	_check_blocks("charcreate", cc_rects, logical)
	await _capture("charcreate", [cc.get_child(0) as Control], logical)
	cc.queue_free()
	_finish(phone, logical)

func _finish(phone: bool, logical: Vector2) -> void:
	var narrow := UiTokens.is_narrow(logical)
	# On-screen size in points (window px / device scale), the unit the 12 px floor is meant in.
	var min_px := int(floor(_min_font / DisplayMode.device_scale())) if _min_font < INF else 0
	var pts := DisplayMode.window_points(get_tree().root)
	var min_pt := _min_font / DisplayMode.device_scale() if _min_font < INF else 0.0
	print("[uireal] phone=%s min_font_px=%d logical_width=%d window_pt=%dx%d min_pt=%.2f floor_pt=%.2f (smallest: %s)" % [phone, min_px, int(logical.x), int(pts.x), int(pts.y), min_pt, type_floor_pt(pts), _min_font_where])
	_fails.append_array(gate_failures(pts, phone, min_pt, int(logical.x)))
	if _fails.is_empty():
		print("[uireal] PASS screens=hud,craft,%sskills,atlas,radial,plate,bag,charcreate shots=%s" % ["craft_detail," if narrow else "", _out])
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

## HUD blocks: its visible controls (hexes with their caption, the minimap), the held-tool slot, and
## the two blocks it draws (vitals, quest card), mirrored from hunt_hud.gd _draw (:916-930) and
## _draw_quest (:1071-1074) with the HUD's own is_phone branch.
static func hud_blocks(hud: HuntHud, player: Player, r: Vector2) -> Dictionary:
	var out := {}
	var minimap: Control = null
	for c in hud.get_children():
		var ctl := c as Control
		if ctl == null or not ctl.is_visible_in_tree() or ctl.top_level or ctl.size.x < 8.0 or ctl.size.y < 8.0:
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
		if ctl.name == "Minimap":
			minimap = ctl
	var held: Control = player.station_craft.held_slot if player and player.station_craft else null
	if held and held.is_visible_in_tree():
		out["HeldItemSlot"] = Rect2(held.get_global_rect().position, held.size + Vector2(0, 18))
	if minimap == null:
		return out
	var inset := UiTokens.safe_insets(hud.get_viewport())
	var phone := UiTokens.is_phone(r)
	var x := 16.0 + inset.w
	var y := 12.0 + inset.z
	var mp := minimap.position
	var panel_w := 300.0 if not phone else maxf(148.0, mp.x - x - 8.0)
	var big := 16.0 if not phone else 12.0
	var small := 10.0 if not phone else 8.0
	out["vitals"] = Rect2(x - 8.0, y - 6.0, panel_w, big * 2.0 + small + 12.0 + 36.0)
	var w := HuntHud.MAP_PX if phone else 240.0
	var origin := Vector2(mp.x, mp.y + HuntHud.MAP_PX + 52.0) if phone else Vector2(mp.x - w - 12.0, mp.y)
	origin.x = maxf(origin.x, 8.0)
	out["quest"] = Rect2(origin, Vector2(w, 72.0))
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
	_expect(node != null and node.visible, "the wild creature shows a full plate")
	if node == null:
		return
	var glyphs := 0
	for g in (entry["line3"] as Control).get_children():
		if (g as Control).visible:
			glyphs += 1
	print("[uireal] plate %s glyphs=%d" % [(entry["line1"] as Label).text, glyphs])
	_expect(glyphs >= 2, "plate shows its status glyphs")
	await _capture("plate", [node], logical)
	# 3x crop so the glyph letters can be checked by eye
	var img := get_tree().root.get_texture().get_image()
	var stretch := get_tree().root.get_final_transform().get_scale().x
	var r := Rect2i(Rect2(node.get_global_rect().position * stretch - Vector2(8, 8), node.get_global_rect().size * stretch + Vector2(16, 16)))
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x > 4 and r.size.y > 4:
		var crop := img.get_region(r)
		crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
		crop.save_png(_out.path_join("plate_zoom_%dx%d.png" % [get_tree().root.size.x, get_tree().root.size.y]))
	wild.process_mode = Node.PROCESS_MODE_INHERIT

## Checks one open screen and saves the root viewport as <name>_<w>x<h>.png.
func _capture(name: String, roots: Array, logical: Vector2) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
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
				_min_font_where = "%s %s \"%s\" %.1f px" % [screen, c.get_path(), text.left(24).replace("\n", " "), px]
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
