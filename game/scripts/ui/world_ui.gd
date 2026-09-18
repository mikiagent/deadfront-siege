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
		if _mode == &"map":
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
	_fill("Choose your home terrain (once)", [
		["Meadow", &"meadow"],
		["Forest", &"forest"],
		["Rocky", &"rocky"],
		["Riverside", &"riverside"],
		["Coastal", &"coastal"],
	], func (id: StringName) -> void:
		World.home_terrain = id
		var host: Node = World.runtime.get_parent() if World.runtime else get_tree().current_scene
		var harbour: Array = World.island_def.get("harbour", [0, 0, 18])
		World.load_island(host, &"home_grassland", Vector3(float(harbour[0]), 1.0, float(harbour[2])), false)
		(load("res://scripts/core/save_game.gd") as GDScript).save_now()
		hide_all()
	)

func show_harbour() -> void:
	var rows: Array = []
	if World.is_home():
		rows.append(["Sail Unstable Temperate (5 T)", &"sail_temp"])
	else:
		rows.append(["Free return home", &"home"])
		rows.append(["Return to camp", &"camp"])
	_fill("Harbour", rows, func (id: StringName) -> void:
		hide_all()
		match id:
			&"sail_temp":
				World.travel(&"temperate_25", &"sail")
			&"home":
				World.travel(&"home_grassland", &"harbour_home")
			&"camp":
				World.recall_camp()
	)

func show_map() -> void:
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
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(24, 24)
	_panel.add_child(box)
	var lab := Label.new()
	lab.text = title
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(700, 80)
	box.add_child(lab)
	for row in rows:
		var b := Button.new()
		b.text = str(row[0])
		b.custom_minimum_size = Vector2(320, 64)
		var id: StringName = row[1]
		b.pressed.connect(func () -> void: cb.call(id))
		box.add_child(b)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 64)
	close.pressed.connect(hide_all)
	box.add_child(close)
