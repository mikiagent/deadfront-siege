extends Node3D
## SADDLES screenshots: an unsaddled and a saddled deinonychus side by side (the saddle tinted by its
## reddish hide), then the tame's Gear sheet, one PNG each into --shot-dir, suffixed with the canvas.
## Windowed: Godot --path game --resolution 1600x900 -- --lab=saddles_lab --shot-dir=DIR

var _out := ""
var _player: Player
var _hud: HuntHud

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("saddles")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 60.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	_run.call_deferred()

func _shot(tag: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	var v := get_tree().root.get_visible_rect().size
	var path := _out.path_join("%s_%dx%d.png" % [tag, int(v.x), int(v.y)])
	img.save_png(path)
	print("[saddles] shot %s" % path)

func _pet(at: Vector3, saddled: bool) -> Creature:
	var rec := PetRecord.from_def(Data.creature(&"deinonychus"), &"A")
	rec.name = "Saddled" if saddled else "No saddle"
	if saddled:
		rec.gear.put(&"saddle", ItemStack.make(&"saddle_medium", 1, {"tint": "#9a4a2a"}, 8))
	_player.bonded.append(rec)
	var c := _player.pets.summon(_player.bonded.size() - 1)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.global_position = at
	c.rotation.y = PI * 0.5
	return c

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	_pet(Vector3(-4.6, 0.1, 3.0), false)
	_pet(Vector3(3.2, 0.1, 3.0), true)
	_player.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40.0
	cam.global_position = Vector3(0.0, 4.4, 15.5)
	cam.look_at(Vector3(0.0, 1.0, 3.0))
	cam.current = true
	_hud.visible = false
	await get_tree().create_timer(1.5).timeout
	await _shot("saddle_compare")
	_hud.visible = true
	_player.visible = true
	var rec := _player.bonded[1]
	_player.inventory.add(ItemStack.make(&"saddle_medium", 1, {"tint": "#d8c49a"}, 4))
	_player.inventory.add(ItemStack.make(&"saddle_small", 1, {"tint": "#6b5a3e"}, 3))
	_player.inventory.add(ItemStack.make(&"saddle_large", 1, {"tint": "#4a3a28"}, 12))
	_hud.open_pet_gear(rec)
	await get_tree().create_timer(1.0).timeout
	await _shot("gear")
	print("[saddles] DONE")
	get_tree().quit(0)
