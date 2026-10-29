extends Node3D
## FOODTORPOR shots: a weakened raptor with its violet torpor bar on the creature plate and the hunt
## target plate, and the bag panel's Food Bag tab. Windowed with --shot-dir=DIR it saves the PNGs,
## prints "[foodtorpor] shot <path>" per PNG, then quits.

var _player: Player
var _cam: Camera3D
var _out := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
		if a.begins_with("--canvas="):  # the phone canvas, as tools/ui_screens.sh draws it (2x window)
			var wh := a.substr(9).split("x")
			DisplayMode.canvas_override = Vector2i(int(wh[0]), int(wh[1]))
			DisplayMode.fit(get_tree().root)
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self)
	_player = kit["player"]
	_cam = kit.get("cam", null) as Camera3D
	LabKit.give(_player, &"club", 1)
	for id in [&"mango", &"berry", &"raw_meat", &"grilled_meat", &"berry", &"spoiled_meat", &"rot", &"narcoberry", &"sedative", &"tranquilizer_dart", &"slingshot"]:
		LabKit.give(_player, id, 1)
	_run.call_deferred()

func _size_tag() -> String:
	var v := get_viewport().get_visible_rect().size
	return "%dx%d" % [int(v.x), int(v.y)]

func _shot(step: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or _out == "":
		return
	var path := _out.path_join("foodtorpor_%s_%s.png" % [step, _size_tag()])
	img.save_png(path)
	print("[foodtorpor] shot %s" % path)

func _run() -> void:
	await get_tree().create_timer(0.6).timeout
	# A fresh HOME boots character creation over the lab; the shots are about the field.
	for n in get_tree().root.find_children("*", "CharacterCreation", true, false):
		n.queue_free()
	for n in get_tree().get_nodes_in_group(&"character_creation"):
		n.queue_free()
	World.finish_creation()
	await get_tree().process_frame
	var raptor: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	raptor.position = _player.global_position + Vector3(1.4, 0, -1.6)
	add_child(raptor)
	raptor.spawn(Data.creature(&"velociraptor"))
	raptor.brain.process_mode = Node.PROCESS_MODE_DISABLED
	raptor.health.hp = raptor.health.max_hp * 0.26
	raptor.torpor = raptor.torpor_max() * 0.42
	raptor._torpor_quiet_s = -9999.0  # hold the bar still for the shot
	_player.hunt.auto = false
	_player.hunt.start(raptor)
	if _cam:
		_cam.global_position = _player.global_position + Vector3(0.5, 7.5, 6.0)
		_cam.look_at(raptor.global_position + Vector3(0, 0.6, 0), Vector3.UP)
	Game.reveal_creature_plate(raptor, 30.0)
	await get_tree().create_timer(1.2).timeout
	await _shot("plate_torpor")
	# The Food Bag tab: mango, then berry, then grilled meat put in, in that order.
	_player.hunt.stop()
	var inv := _player.inventory
	for id in [&"mango", &"berry", &"grilled_meat"]:
		inv.food_bag_add(inv.find_first(id))
	var ui := get_tree().get_first_node_in_group("inventory_ui") as InventoryUI
	if ui == null:
		ui = find_children("*", "InventoryUI", true, false)[0] as InventoryUI
	ui.bind(inv, _player)
	ui.visible = true
	if ui.has_method("show_food_bag"):
		ui.call("show_food_bag")
	await get_tree().create_timer(0.8).timeout
	await _shot("food_bag")
	get_tree().quit(0)
