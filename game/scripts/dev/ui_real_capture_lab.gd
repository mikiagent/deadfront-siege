extends Node3D
## Real-scene UI gate (W1-UI). Boots the home island with the real HUD, fits the logical canvas and
## installs the theme the way boot does (DisplayMode.install, UiTokens.install_theme), then opens
## the HUD, craft, skills, atlas, a gather radial and character creation in the ROOT viewport (not a
## sized SubViewport, which hid the phone problem) and saves a PNG of each. Every screen must have
## size, sit inside the view, draw no text under 12 px on screen and be neither blank nor blown out.
## Windowed: --resolution 390x844 -- --lab=ui_real_capture_lab [--shot-dir=DIR]
## Prints "[uireal] phone=<bool> min_font_px=<n> ..." then "[uireal] PASS" (exit 0) or FAIL lines (exit 1).

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
	DisplayMode.install(get_tree().root)
	UiTokens.install_theme()
	_out = OS.get_user_data_dir().path_join("ui-real")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
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
	await _capture("craft", [craft], logical)
	craft.hide_ui()
	# skills: the real HUD path
	_hud.call("_toggle_skills")
	await _frames(3)
	var sheet := _hud.get_node_or_null("SkillsSheet") as SkillsSheet
	_expect(sheet != null and sheet.visible, "skills sheet opens from the HUD")
	if sheet:
		var panel := sheet.get_child(1) as Control
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
	# character creation
	var cc := CharacterCreation.new()
	root.add_child(cc)
	await _frames(3)
	await _capture("charcreate", [cc.get_child(0) as Control], logical)
	cc.queue_free()
	_finish(phone, logical)

func _finish(phone: bool, logical: Vector2) -> void:
	var min_px := int(floor(_min_font)) if _min_font < INF else 0
	print("[uireal] phone=%s min_font_px=%d logical_width=%d (smallest: %s)" % [phone, min_px, int(logical.x), _min_font_where])
	if phone:
		_expect(min_px >= UiTokens.TYPE_MIN, "phone text at least %d px on screen (got %d at %s)" % [UiTokens.TYPE_MIN, min_px, _min_font_where])
	elif get_tree().root.size.x >= 1600:
		_expect(int(logical.x) == DisplayMode.DESIGN.x, "desktop keeps a %d px logical width" % DisplayMode.DESIGN.x)
	if _fails.is_empty():
		print("[uireal] PASS screens=hud,craft,skills,atlas,radial,charcreate shots=%s" % _out)
		get_tree().quit(0)
	else:
		for f in _fails:
			print("[uireal] FAIL %s" % f)
		get_tree().quit(1)

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
