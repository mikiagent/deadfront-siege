extends Node3D
## Real-scene UI gate (W1-UI). Boots the home island with the real HUD, fits the logical canvas and
## installs the theme the way boot does (DisplayMode.install, UiTheme.install), then opens
## the HUD, craft, skills, atlas, a gather radial and character creation in the ROOT viewport (not a
## sized SubViewport, which hid the phone problem) and saves a PNG of each. Every screen must have
## size, sit inside the view, draw no text under 12 px on screen and be neither blank nor blown out.
## Windowed: --resolution 390x844 -- --lab=ui_real_capture_lab [--shot-dir=DIR] [--no-fit]
## --no-fit skips DisplayMode.install: the gate's self-test, which must then FAIL on a phone window.
## Prints "[uireal] phone=<bool> min_font_px=<n> ..." then "[uireal] PASS" (exit 0) or FAIL lines (exit 1).

const SETTLE_S := 3.0
const BLOWN_MAX := 0.2   ## share of near-white pixels allowed in a frame
const FLAT_MIN := 0.02   ## luma deviation under this is a blank frame
## Zero-size roots in files W1-UI may not edit. Reported as KNOWN, not failed, until the owner
## lands the hook; delete the entry then so the gate checks it again.
const KNOWN_ZERO_SIZE := {
	"HuntHud": "hunt_hud.gd:68 set_anchors_preset in _ready keeps an empty rect; use set_anchors_and_offsets_preset (W2-HUD)",
}

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
	UiTheme.install()
	DirAccess.make_dir_recursive_absolute(_out)
	var kit := LabKit.build(self, 4.0)
	Game.debug_overlay = false
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
	var phone := UiTokens.is_phone(logical)
	print("[uireal] window=%dx%d logical=%dx%d content_scale=%s" % [root.size.x, root.size.y, logical.x, logical.y, root.content_scale_size])
	if _hud == null:
		_fail("no HuntHud in the lab UI layer")
		_finish(phone, logical)
		return
	await _capture("hud", [_hud], logical)
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
	if phone:
		_expect(_visible_vscrolls(craft) == 1, "phone craft shows one vertical scroll pane, not %d" % _visible_vscrolls(craft))
	await _capture("craft", [craft], logical)
	if phone and not metas.is_empty():
		# open the detail sheet: Craft / Craft x5 must sit in the pinned footer, inside the view
		(metas[0].get_parent().get_parent().get_parent() as Button).pressed.emit()
		await _frames(3)
		var one := craft.find_child("CraftOne", true, false) as Control
		var view := Rect2(Vector2.ZERO, logical)
		var ok := one != null and one.is_visible_in_tree() and view.encloses(one.get_global_rect()) and one.size.y >= UiTokens.TARGET_PRIMARY
		print("[uireal] craft sheet: CraftOne %s in footer=%s vscrolls=%d" % [one.get_global_rect() if one else "missing", one != null and one.get_parent().name == "CraftFooter", _visible_vscrolls(craft)])
		_expect(ok, "phone craft detail: Craft button visible, inside the view, >= %d px tall" % UiTokens.TARGET_PRIMARY)
		_expect(one != null and one.get_parent().name == "CraftFooter", "phone Craft button is pinned in the footer, not inside a scroll")
		await _capture("craft_detail", [craft], logical)
	craft.hide_ui()
	# skills: the real HUD path
	_hud.call("_toggle_skills")
	await _frames(3)
	var sheet := _hud.get_node_or_null("SkillsSheet") as SkillsSheet
	_expect(sheet != null and sheet.visible, "skills sheet opens from the HUD")
	if sheet:
		var panel := sheet.get_child(1) as Control
		var scroll := panel.get_child(0) as ScrollContainer
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
	# character creation
	var cc := CharacterCreation.new()
	root.add_child(cc)
	await _frames(3)
	await _capture("charcreate", [cc.get_child(0) as Control], logical)
	cc.queue_free()
	_finish(phone, logical)

func _finish(phone: bool, logical: Vector2) -> void:
	# On-screen size in points (window px / device scale), the unit the 12 px floor is meant in.
	var min_px := int(floor(_min_font / DisplayMode.device_scale())) if _min_font < INF else 0
	var pts := DisplayMode.window_points(get_tree().root)
	print("[uireal] phone=%s min_font_px=%d logical_width=%d window_pt=%dx%d (smallest: %s)" % [phone, min_px, int(logical.x), int(pts.x), int(pts.y), _min_font_where])
	_fails.append_array(gate_failures(pts, phone, min_px, int(logical.x)))
	if _fails.is_empty():
		print("[uireal] PASS screens=hud,craft,%sskills,atlas,radial,plate,charcreate shots=%s" % ["craft_detail," if phone else "", _out])
		get_tree().quit(0)
	else:
		for f in _fails:
			print("[uireal] FAIL %s" % f)
		get_tree().quit(1)

## The gate's verdict on the canvas fit. A phone-width window must get the phone canvas and a
## 12 px floor whatever the screens did; before this a missing fit (phone=false, 3 px text) passed
## because neither branch ran under 1600 px.
static func gate_failures(pts: Vector2, phone: bool, min_px: int, logical_w: int) -> Array[String]:
	var out: Array[String] = []
	if DisplayMode.is_phone_window(pts):
		if pts.y > pts.x and not phone:
			out.append("a portrait %dx%d pt window must get the phone canvas (is_phone is false, logical width %d)" % [int(pts.x), int(pts.y), logical_w])
		if min_px < UiTokens.TYPE_MIN:
			out.append("phone-width window: text at least %d px on screen (got %d)" % [UiTokens.TYPE_MIN, min_px])
	elif pts.x >= float(DisplayMode.DESIGN.x) and logical_w != DisplayMode.DESIGN.x:
		out.append("desktop keeps a %d px logical width (got %d)" % [DisplayMode.DESIGN.x, logical_w])
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
		var kind := str(c.get_script().get_global_name()) if c.get_script() else c.get_class()
		if rect.size.x < 8.0 and KNOWN_ZERO_SIZE.has(kind):
			print("[uireal] KNOWN %s: %s root has zero size: %s" % [name, kind, KNOWN_ZERO_SIZE[kind]])
			continue
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
	if c and c.modulate.a > 0.05 and (c is Label or c is Button or c is LineEdit):
		var text := str(c.get("text"))
		if text.strip_edges() != "":
			var px := float(c.get_theme_font_size("font_size")) * stretch * c.get_global_transform_with_canvas().get_scale().x
			if px < _min_font:
				_min_font = px
				_min_font_where = "%s %s \"%s\" %.1f px" % [screen, c.get_path(), text.left(24).replace("\n", " "), px]
	for child in node.get_children():
		_scan_fonts_from(child, screen, stretch)

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
