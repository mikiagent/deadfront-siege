extends Node3D
## NATURECHIP lab: a Timid wild deinonychus on the home island at the game camera. Shoots its world
## plate (selected: name, nature tag, HP bar), then the fight with the HUD's target plate.
## Run: Godot --path game --resolution 1600x900 -- --lab=naturechip_lab --shot-dir=DIR

var _out := ""
var _player: Player
var _hud: HuntHud

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("naturechip")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	_run.call_deferred()

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _out.path_join("%s_%dx%d.png" % [label, img.get_width(), img.get_height()])
	img.save_png(path)
	print("[naturechip] shot %s" % path)

func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	var sp := Spawner.new()
	sp.species = &"deinonychus"
	sp.count = 1
	sp.radius = 0.5
	sp.as_pack = false
	sp.position = _player.global_position + Vector3(-3.0, 0, -2.5)
	World.runtime.add_child(sp)
	var made := sp.spawn_now()
	if made.is_empty():
		print("[naturechip] FAIL no deinonychus")
		get_tree().quit(1)
		return
	var c: Creature = made[0]
	c.nature = &"timid"
	c.global_position = sp.position
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # stands for the shots
	await get_tree().create_timer(1.0).timeout
	_player.controls.selection.select(c)
	await get_tree().create_timer(0.5).timeout
	await _shot("world_plate")
	_player.actions.attack(c)
	await get_tree().create_timer(0.8).timeout
	_player.hunt.stop()  # hold the plate still: no swing knocking the HP down mid-shot
	_hud.set("_last_target", c)
	await get_tree().create_timer(0.4).timeout
	await _shot("combat")
	print("[naturechip] PASS")
	get_tree().quit(0)
