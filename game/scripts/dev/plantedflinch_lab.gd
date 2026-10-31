extends Node3D
## PLANTEDFLINCH review shots, self-quitting. Each species stands still on the lab floor with a low side camera on
## its feet; it is hit (crit) the way a fight hits it (Creature._on_damaged: the authored hit_react or the procedural
## flinch), and the frames before the hit and at 0.07 / 0.2 / 0.45 s after it are saved as
## DIR/<species>_<ms>.png (0000 = before). Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=plantedflinch_lab --out=DIR

const SPECIES: Array[StringName] = [&"ankylosaurus", &"stegosaurus", &"raptor", &"utahraptor"]
const AFTER_MS: Array[int] = [70, 200, 450]

var _out := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("plantedflinch_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=plantedflinch_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[plantedflinch] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	(kit["player"] as Node3D).global_position = Vector3(0, 0.1, -30)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	for sp in SPECIES:
		var c: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
		add_child(c)
		c.global_position = Vector3.ZERO
		c.spawn(Data.creature(sp), &"", 0, null, 0, &"aggressive")
		c.rotation.y = PI / 2.0  # side on to the camera
		c.set_physics_process(false)
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		var h := c.def.height_meters
		var l := maxf(c.def.real_length_m, h)
		# Low, nearly level with the floor so a foot below it shows.
		cam.look_at_from_position(Vector3(0, h * 0.12, l * 0.8), Vector3(0, h * 0.3, 0))
		for k in 40:
			await get_tree().process_frame
		await _snap("%s_0000" % sp)
		c.next_hit_kind = &"crit"
		var t0 := Time.get_ticks_msec()
		c._on_damaged(1.0, null)
		for ms in AFTER_MS:
			while Time.get_ticks_msec() - t0 < ms:
				await get_tree().process_frame
			await _snap("%s_%04d" % [sp, ms])
		c.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
