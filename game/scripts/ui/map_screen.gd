class_name MapScreen
extends Control
## Full-screen island map (tap the minimap or the map key). Same camera-up orientation as the
## minimap. Shows terrain, camp/harbour/crater, resource dots, creatures and the survivor;
## tap anywhere on land to walk there. Travel buttons along the bottom.

var hud: HuntHud
var player: Player
var _btn_row: HBoxContainer
var _close: Button
var _cards: VBoxContainer
var _zoom_label: Label
var _zoom: float = 1.0
var _selected_region: String = ""
const MARGIN := 24.0

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 45
	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", UiTokens.SPACE)
	add_child(_btn_row)
	_close = _btn("Close", close)
	add_child(_close)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", UiTokens.SPACE)
	add_child(_cards)
	var zoom_row := HBoxContainer.new()
	zoom_row.name = "ZoomRow"
	zoom_row.add_theme_constant_override("separation", UiTokens.SPACE)
	add_child(zoom_row)
	zoom_row.add_child(_zoom_btn("−", func () -> void: _set_zoom(_zoom - 0.25)))
	_zoom_label = Label.new()
	_zoom_label.text = "Zoom 1.0×"
	_zoom_label.custom_minimum_size = Vector2(108, 56)
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zoom_row.add_child(_zoom_label)
	zoom_row.add_child(_zoom_btn("+", func () -> void: _set_zoom(_zoom + 0.25)))

func open() -> void:
	visible = true
	for c in _btn_row.get_children():
		c.queue_free()
	if World.is_unstable():
		_btn_row.add_child(_btn("Return to camp", func () -> void: close(); World.recall_camp()))
		_btn_row.add_child(_btn("Warp home", func () -> void: close(); World.travel(&"home_grassland", &"warp_home")))
	_btn_row.add_child(_btn("Harbour routes", func () -> void:
		close()
		var ui = (load("res://scripts/ui/world_ui.gd") as GDScript).ensure()
		if ui:
			ui.show_harbour()
	))
	_selected_region = str(World.island_id)
	_rebuild_cards()
	queue_redraw()

func _set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.75, 2.0)
	if _zoom_label:
		_zoom_label.text = "Zoom %.1f×" % _zoom
	queue_redraw()

func _rebuild_cards() -> void:
	if _cards == null:
		return
	for c in _cards.get_children():
		c.queue_free()
	var catalogue: Dictionary = Data.world_islands if Data else {}
	var ids: Array = []
	var current := str(World.island_id)
	if current != "" and catalogue.has(current):
		ids.append(current)
	for key in catalogue.keys():
		if str(key).begins_with("_") or str(key) == current:
			continue
		ids.append(str(key))
		if ids.size() >= 4:
			break
	if ids.is_empty():
		ids.append(current if current != "" else "home")
	if _selected_region == "" or not ids.has(_selected_region):
		_selected_region = str(ids[0])
	for id in ids:
		_cards.add_child(_region_card(str(id), catalogue.get(str(id), {}) as Dictionary))

func _region_card(id: String, entry: Dictionary) -> Button:
	var climate := str(entry.get("climate", "unknown")).capitalize()
	var tier := int(entry.get("tier", 1))
	var species := _species_line(entry)
	var materials := _material_line(str(entry.get("climate", "")))
	var here := id == str(World.island_id)
	var travel := "You are here" if here else "Charted"
	var b := Button.new()
	b.text = "%s\nLv %d    %s\n%s\n%s\n%s" % [id.replace("_", " ").capitalize(), tier, climate, materials, species, travel]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(220, 112)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", UiTokens.TEXT)
	b.add_theme_stylebox_override("normal", UiTokens.button_style(_selected_region == id or here))
	b.pressed.connect(_pick_region.bind(id))
	return b

func _pick_region(id: String) -> void:
	_selected_region = id
	_rebuild_cards()

func _species_line(entry: Dictionary) -> String:
	var names: PackedStringArray = []
	var spawns: Variant = entry.get("spawns", {})
	if spawns is Dictionary:
		for ring in (spawns as Dictionary).values():
			if ring is Array:
				for row in ring:
					if row is Dictionary and not names.has(str((row as Dictionary).get("species", ""))):
						names.append(str((row as Dictionary).get("species", "")).capitalize())
					if names.size() >= 3:
						break
	if names.is_empty():
		return "Species —"
	return UiTokens.ellipsis(ThemeDB.fallback_font, " · ".join(names), 200.0, 14)

func _material_line(climate: String) -> String:
	var block: Variant = Data.world_climates.get(climate, {}) if Data else {}
	var names: PackedStringArray = []
	if block is Dictionary:
		for row in (block as Dictionary).get("materials", []):
			if row is Dictionary:
				names.append(str((row as Dictionary).get("id", "")).replace("_", " "))
			if names.size() >= 3:
				break
	if names.is_empty():
		return "Resources —"
	return UiTokens.ellipsis(ThemeDB.fallback_font, " · ".join(names), 200.0, 14)

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

func _zoom_btn(text: String, cb: Callable) -> Button:
	var b := _btn(text, cb)
	b.custom_minimum_size = Vector2(64, 56)
	return b

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 56)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", UiTokens.ACTION)
	b.add_theme_stylebox_override("normal", UiTokens.button_style(false))
	b.pressed.connect(cb)
	return b

func _process(_delta: float) -> void:
	if not visible:
		return
	var r := get_viewport_rect().size
	var phone := UiTokens.is_phone(r)
	var close_w := minf(160.0, maxf(96.0, r.x * 0.36))
	_close.custom_minimum_size = Vector2(close_w, 56)
	_close.size = Vector2(close_w, 56)
	_close.position = Vector2(r.x - close_w - MARGIN, MARGIN)
	var actions := _btn_row.get_child_count()
	var action_w := 200.0 if not phone else maxf(96.0, (r.x - MARGIN * 2.0 - UiTokens.SPACE * float(maxi(actions - 1, 0))) / float(maxi(actions, 1)))
	for child in _btn_row.get_children():
		var action := child as Control
		if action:
			action.custom_minimum_size = Vector2(action_w, 56)
	_btn_row.position = Vector2(MARGIN, r.y - 64.0 - MARGIN)
	if _cards:
		_cards.position = Vector2(MARGIN, 132.0 if phone else 96.0)
		_cards.size = Vector2(240.0 if not phone else r.x - MARGIN * 2.0, 220.0 if phone else r.y - 220.0)
	var zoom_row := get_node_or_null("ZoomRow") as Control
	if zoom_row:
		var zoom_w := 64.0 + 108.0 + 64.0 + UiTokens.SPACE * 2.0
		zoom_row.position = Vector2(r.x - zoom_w - MARGIN, r.y - 64.0 - MARGIN) if not phone else Vector2(MARGIN, r.y - 64.0 - MARGIN - 64.0 - UiTokens.SPACE)
	if _zoom_label:
		_zoom_label.add_theme_font_size_override("font_size", UiTokens.body(r))
		_zoom_label.add_theme_color_override("font_color", UiTokens.TEXT)
	queue_redraw()

func _layout() -> Dictionary:
	var r := get_viewport_rect().size
	var fit := minf(r.x, r.y) - MARGIN * 2.0 - 90.0
	var rt := World.runtime
	var size_m: float = float(rt.get("_size")) if rt and rt.get("_size") != null else 200.0
	var cam := get_viewport().get_camera_3d()
	var centre := Vector2(r.x * 0.58, r.y * 0.48) if not UiTokens.is_phone(r) else Vector2(r.x * 0.5, r.y * 0.62)
	return {"centre": centre, "scale": fit / maxf(1.0, size_m) * _zoom, "fit": fit,
		"yaw": cam.global_rotation.y if cam else 0.0, "size_m": size_m}

func _draw() -> void:
	if player == null or hud == null:
		return
	var r := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, r), Color(0.03, 0.035, 0.04, 1.0))
	draw_rect(Rect2(Vector2(12, 12), r - Vector2(24, 24)), Color(0.05, 0.055, 0.06, 0.4), false, 2.0)
	var L := _layout()
	var centre: Vector2 = L["centre"]
	var s: float = L["scale"]
	var yaw: float = L["yaw"]
	var size_m: float = L["size_m"]
	var to_map := func (w: Vector3) -> Vector2:
		return Vector2(w.x * s, w.z * s)
	draw_set_transform(centre, yaw, Vector2.ONE)
	var tex := hud.map_texture()
	if tex:
		var px := size_m * s
		draw_texture_rect(tex, Rect2(Vector2(-px * 0.5, -px * 0.5), Vector2(px, px)), false)
	var rt := World.runtime
	# resource dots: trees dark green, rocks grey, bushes/plants light green
	for n in get_tree().get_nodes_in_group("harvest"):
		var hn := n as HarvestNode
		if hn == null or not hn.visible or hn.depleted:
			continue
		var role := str(Data.nature_families.get(hn.family, {}).get("role", ""))
		var col := Color(0.55, 0.85, 0.45, 0.9)
		if role.begins_with("tree"):
			col = Color(0.15, 0.45, 0.2, 0.95)
		elif role == "rock":
			col = Color(0.62, 0.62, 0.66, 0.95)
		draw_circle(to_map.call(hn.global_position), 1.6, col)
	if rt:
		var camp: Vector3 = rt.get("_camp_pos")
		var harb: Vector3 = rt.get("_harbour_pos")
		draw_circle(to_map.call(camp), 6.0, Color(1.0, 0.85, 0.3))
		draw_circle(to_map.call(harb), 6.0, Color(0.7, 0.85, 1.0))
		if World.crater_discovered:
			draw_circle(to_map.call(rt.get("_crater_pos")), 6.0, Color(0.9, 0.4, 0.2))
	for n in get_tree().get_nodes_in_group("creatures"):
		var cr := n as Creature
		if cr == null or cr.health.dead:
			continue
		draw_circle(to_map.call(cr.global_position), 3.2, Color(0.4, 0.9, 0.4) if cr.is_pet else Color(0.95, 0.35, 0.3))
	var pp := player.global_position
	var pyaw := player.visual.rotation.y if player.visual else 0.0
	var fwd := Vector2(-sin(pyaw), -cos(pyaw))
	var side := Vector2(-fwd.y, fwd.x)
	var pm: Vector2 = to_map.call(pp)
	draw_colored_polygon(PackedVector2Array([pm + fwd * 11.0, pm - fwd * 7.0 + side * 7.0, pm - fwd * 7.0 - side * 7.0]), Color(1, 1, 1))
	if player.nav_active:
		var goal: Vector2 = to_map.call(player._path_goal)
		draw_circle(goal, 5.0, Color(1.0, 1.0, 1.0, 0.0))
		draw_arc(goal, 6.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# header + legend (screen space)
	var title := "WORLD ATLAS"
	var head := UiTokens.heading(r)
	var phone := UiTokens.is_phone(r)
	var close_w := minf(160.0, maxf(96.0, r.x * 0.36))
	var text_w := r.x - MARGIN * 2.0 - close_w - 12.0
	draw_string(font, Vector2(MARGIN, MARGIN + head), title, HORIZONTAL_ALIGNMENT_LEFT, text_w, head, Color.WHITE)
	var sub := "%s   %s" % [str(World.island_id).replace("_", " ").capitalize(), "Home" if World.is_home() else "Survivable %d min" % int(ceil(World.remaining_lifetime / 60.0))]
	var sub_pos := Vector2(MARGIN, MARGIN + head + 22) if phone else Vector2(MARGIN + 220, MARGIN + head)
	var sub_w := text_w if phone else minf(r.x * 0.4, text_w - 220.0)
	draw_string(font, sub_pos, UiTokens.ellipsis(font, sub, sub_w, UiTokens.body(r)), HORIZONTAL_ALIGNMENT_LEFT, sub_w, UiTokens.body(r), UiTokens.TEAL)
	var tile := BuildGrid.tile_of(pp)
	var meta := "You  X %d  Y %d    Pioneer %d    T-stones %d" % [tile.x, tile.y, World.pioneer_level, World.t_stones]
	var meta_y := MARGIN + head + (44.0 if phone else 22.0)
	draw_string(font, Vector2(MARGIN, meta_y), UiTokens.ellipsis(font, meta, text_w, UiTokens.meta(r)), HORIZONTAL_ALIGNMENT_LEFT, text_w, UiTokens.meta(r), UiTokens.META)
	if not phone:
		var lx := r.x - MARGIN - 200.0
		var ly := MARGIN + 100.0
		for row in [[Color(1.0, 0.85, 0.3), "Camp"], [Color(0.7, 0.85, 1.0), "Harbour"], [Color(0.95, 0.35, 0.3), "Wild animal"], [Color(0.4, 0.9, 0.4), "Pet"], [Color(0.15, 0.45, 0.2), "Trees"], [Color(0.62, 0.62, 0.66), "Rocks"], [Color(0.55, 0.85, 0.45), "Plants"]]:
			draw_circle(Vector2(lx + 8, ly - 5), 5.0, row[0])
			draw_string(font, Vector2(lx + 22, ly), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
			ly += 22.0

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var release := false
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
		release = true
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
		release = true
	if not release:
		return
	accept_event()
	var L := _layout()
	var local := (pos - (L["centre"] as Vector2)).rotated(-float(L["yaw"]))
	var s: float = L["scale"]
	var world := Vector3(local.x / s, 0.0, local.y / s)
	var rt := World.runtime
	if rt == null or not rt.has_method("spawn_ok") or not rt.spawn_ok(world, false):
		return  # water or off the island
	world.y = rt.surface_y(world.x, world.z) if rt.has_method("surface_y") else 0.0
	if player.has_method("nav_to"):
		player.nav_to(player._closest_nav_point(world))
		player.notice("Walking to X %d  Y %d" % [BuildGrid.tile_of(world).x, BuildGrid.tile_of(world).y])
	close()
