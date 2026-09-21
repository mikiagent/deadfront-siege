class_name MapScreen
extends Control
## Full-screen island map (tap the minimap or the map key). Same camera-up orientation as the
## minimap. Shows terrain, camp/harbour/crater, resource dots, creatures and the survivor;
## tap anywhere on land to walk there. Travel buttons along the bottom.

var hud: HuntHud
var player: Player
var _btn_row: HBoxContainer
var _close: Button
const MARGIN := 24.0

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 45
	_btn_row = HBoxContainer.new()
	_btn_row.add_theme_constant_override("separation", 10)
	add_child(_btn_row)
	_close = _btn("Close", close)
	add_child(_close)

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
	queue_redraw()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func is_open() -> bool:
	return visible

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 56)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	return b

func _process(_delta: float) -> void:
	if not visible:
		return
	var r := get_viewport_rect().size
	_close.position = Vector2(r.x - 200.0 - MARGIN, MARGIN)
	_btn_row.position = Vector2(MARGIN, r.y - 56.0 - MARGIN)
	queue_redraw()

func _layout() -> Dictionary:
	var r := get_viewport_rect().size
	var fit := minf(r.x, r.y) - MARGIN * 2.0 - 90.0
	var rt := World.runtime
	var size_m: float = float(rt.get("_size")) if rt and rt.get("_size") != null else 200.0
	var cam := get_viewport().get_camera_3d()
	return {"centre": Vector2(r.x * 0.5, r.y * 0.5 + 10.0), "scale": fit / maxf(1.0, size_m), "fit": fit,
		"yaw": cam.global_rotation.y if cam else 0.0, "size_m": size_m}

func _draw() -> void:
	if player == null or hud == null:
		return
	var r := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, r), Color(0.04, 0.05, 0.07, 0.94))
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
	var title := "%s   %s" % [str(World.island_id).replace("_", " ").capitalize(), "Home" if World.is_home() else "Survivable for %d min" % int(ceil(World.remaining_lifetime / 60.0))]
	draw_string(font, Vector2(MARGIN, MARGIN + 24), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var tile := BuildGrid.tile_of(pp)
	draw_string(font, Vector2(MARGIN, MARGIN + 50), "You: X %d  Y %d   ·   Pioneer %d   ·   T-stones %d   ·   tap the map to walk there" % [tile.x, tile.y, World.pioneer_level, World.t_stones], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.85, 0.8))
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
