extends CanvasLayer
## Terrain pick, harbour routes, map, pause/save. Mobile-first 64 px targets.

static var _i

var _panel: Control
var _mode: StringName = &""

static func ensure():
	if _i and is_instance_valid(_i):
		return _i
	_i = (load("res://scripts/ui/world_ui.gd") as GDScript).new()
	_i.name = "WorldUI"
	var host: Node = Engine.get_main_loop().root.get_tree().current_scene
	host.add_child(_i)
	return _i

static func instance_on(host: Node):
	if _i and is_instance_valid(_i):
		return _i
	_i = (load("res://scripts/ui/world_ui.gd") as GDScript).new()
	_i.name = "WorldUI"
	host.add_child(_i)
	return _i

func _ready() -> void:
	layer = 40
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

func _unhandled_input(event: InputEvent) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.placer and player.placer.placing != &"" and event.is_action_pressed("pause"):
		return
	if event.is_action_pressed("map"):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("open_map"):
			hud.open_map()  # toggles
		elif _mode == &"map":
			hide_all()
		else:
			show_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if _mode == &"pause":
			hide_all()
		else:
			show_pause()
		get_viewport().set_input_as_handled()

func hide_all() -> void:
	_mode = &""
	_panel.visible = false
	for c in _panel.get_children():
		c.queue_free()

func show_terrain() -> void:
	for c in _panel.get_children():
		c.queue_free()
	_mode = &"terrain"
	_panel.visible = true
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.035, 0.045, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(scrim)
	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_left = 12.0
	sheet.offset_right = -12.0
	sheet.offset_top = -168.0
	sheet.offset_bottom = -10.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.085, 0.96)
	style.border_color = Color(0.28, 0.52, 0.48, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	sheet.add_theme_stylebox_override("panel", style)
	_panel.add_child(sheet)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	sheet.add_child(content)
	var title := Label.new()
	title.text = "CHOOSE YOUR FIRST ISLAND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 7)
	content.add_child(cards)
	var terrains: Array = [
		["MEADOW", "Open grass", "●", Color(0.20, 0.48, 0.25), &"meadow"],
		["FOREST", "Dense wood", "♣", Color(0.10, 0.34, 0.20), &"forest"],
		["ROCKY", "Stone-rich", "▲", Color(0.34, 0.35, 0.34), &"rocky"],
		["RIVER", "Fresh water", "≈", Color(0.12, 0.36, 0.48), &"riverside"],
		["COAST", "Wide shore", "◒", Color(0.40, 0.39, 0.20), &"coastal"],
	]
	for row in terrains:
		var b := Button.new()
		b.text = "%s  %s\n%s" % [row[2], row[0], row[1]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 86)
		b.add_theme_font_size_override("font_size", 18)
		var normal := StyleBoxFlat.new()
		normal.bg_color = row[3]
		normal.set_corner_radius_all(9)
		normal.border_color = Color(0.75, 0.9, 0.78, 0.45)
		normal.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", normal)
		var id: StringName = row[4]
		b.pressed.connect(func () -> void: _choose_terrain(id))
		cards.add_child(b)

func _choose_terrain(id: StringName) -> void:
	World.home_terrain = id
	var host: Node = World.runtime.get_parent() if World.runtime else get_tree().current_scene
	var harbour: Array = World.island_def.get("harbour", [0, 0, 18])
	World.load_island(host, &"home_grassland", Vector3(float(harbour[0]), 1.0, float(harbour[2])), false)
	(load("res://scripts/core/save_game.gd") as GDScript).save_now()
	hide_all()
	_show_arrival(host)


func _show_arrival(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArrivalWelcome"
	layer.layer = 92
	host.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.045, 0.05, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 14)
	centre.add_child(box)
	var title := Label.new()
	title.text = "YOU MADE IT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	box.add_child(title)
	var body := Label.new()
	body.text = "Your survivor is at the harbour. Tap the world to move and interact."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 20)
	box.add_child(body)
	var go := Button.new()
	go.text = "START EXPLORING"
	go.custom_minimum_size = Vector2(0, 68)
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(layer.queue_free)
	box.add_child(go)

func show_harbour() -> void:
	var rows: Array = []
	var player := get_tree().get_first_node_in_group("player") as Player
	var level := player.skills.level_of("survival") if player and player.skills else 0
	if not World.is_home():
		rows.append(["Free return home", &"home"])
		rows.append(["Return to camp", &"camp"])
	for key in World.harbour_routes():
		if key == str(World.island_id):
			continue
		var id := StringName(key)
		var dest := World.def_of(id)
		var required := World.route_level(id)
		var cost := int(dest.get("sail_cost", 5))
		var label := "Sail %s (%d T)" % [dest.get("display_name", key), cost]
		if level < required:
			label += " - Survival %d required" % required
		elif World.t_stones < cost:
			label += " - need T-stones"
		rows.append([label, id, level < required or World.t_stones < cost])
	_fill("Harbour - Survival %d" % level, rows, func (id: StringName) -> void:
		hide_all()
		match id:
			&"home": World.travel(&"home_grassland", &"harbour_home")
			&"camp": World.recall_camp()
			_: World.travel(id, &"sail")
	)

func show_map() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("open_map"):
		hud.open_map()  # the drawn island map; this text panel is the lab fallback
		_mode = &"map"
		return
	var life := "permanent" if World.is_home() else "%.0fs left" % World.remaining_lifetime
	var crater := "yes" if World.crater_discovered else "no"
	var player := get_tree().get_first_node_in_group("player") as Player
	var fat := 0.0
	if player:
		fat = player.vitals.fatigue
	var body := "Island %s\n%s\nPioneer %d   T-stones %d\nFatigue %.0f  (walk / gather / climate)\nCrater discovered: %s" % [
		World.island_id, life, World.pioneer_level, World.t_stones, fat, crater]
	var rows: Array = [["Warp home", &"warp"], ["Harbour routes", &"harbour"]]
	if World.is_unstable():
		rows.append(["Return to camp", &"camp"])
	_fill(body, rows, func (id: StringName) -> void:
		match id:
			&"warp":
				hide_all()
				World.travel(&"home_grassland", &"warp_home")
			&"harbour":
				show_harbour()
			&"camp":
				hide_all()
				World.recall_camp()
	)
	_mode = &"map"

func show_pause() -> void:
	_fill("Paused", [["Save", &"save"], ["Resume", &"resume"]], func (id: StringName) -> void:
		if id == &"save":
			(load("res://scripts/core/save_game.gd") as GDScript).save_now()
		hide_all()
	)

func _fill(title: String, rows: Array, cb: Callable) -> void:
	for c in _panel.get_children():
		c.queue_free()
	_mode = &"panel"
	_panel.visible = true
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.03, 0.04, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(func (event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			hide_all()
		elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			hide_all()
	)
	_panel.add_child(scrim)
	var sheet := PanelContainer.new()
	sheet.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sheet.offset_left = 12.0
	sheet.offset_right = -12.0
	sheet.offset_top = -minf(650.0, get_viewport().get_visible_rect().size.y * 0.75) if rows.size() > 4 else (-148.0 if rows.size() <= 2 else -220.0)
	sheet.offset_bottom = -10.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.08, 0.96)
	style.border_color = Color(0.26, 0.49, 0.46, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	sheet.add_theme_stylebox_override("panel", style)
	_panel.add_child(sheet)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	sheet.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	box.add_child(heading)
	var lab := Label.new()
	lab.text = title
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("font_size", 22)
	heading.add_child(lab)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(54, 54)
	close.add_theme_font_size_override("font_size", 26)
	close.pressed.connect(hide_all)
	heading.add_child(close)
	var actions: BoxContainer
	if rows.size() > 4:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		box.add_child(scroll)
		actions = VBoxContainer.new()
		actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(actions)
	else:
		actions = HBoxContainer.new()
		box.add_child(actions)
	actions.add_theme_constant_override("separation", 8)
	for i in rows.size():
		var row: Array = rows[i]
		var b := Button.new()
		b.text = str(row[0]).to_upper()
		b.set_meta("route_id", str(row[1]))
		b.disabled = bool(row[2]) if row.size() > 2 else false
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 20)
		if i == 0:
			var primary := StyleBoxFlat.new()
			primary.bg_color = Color(0.16, 0.50, 0.37)
			primary.set_corner_radius_all(10)
			b.add_theme_stylebox_override("normal", primary)
		var id: StringName = row[1]
		b.pressed.connect(func () -> void: cb.call(id))
		actions.add_child(b)
