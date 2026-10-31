extends Node3D
## HEADLOOK review shots, self-quitting. Four species each stand in their aware idle (brain held in alert on the
## survivor) while she stands left, centre and right of them; the camera looks over the animal's shoulder so the
## neck and head turn reads. Saves DIR/<species>_<left|centre|right>.png. Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=headlook_lab --out=DIR

const SPECIES: Array[StringName] = [&"velociraptor", &"tyrannosaurus", &"triceratops", &"gallimimus"]
const SIDES := {"left": 40.0, "centre": 0.0, "right": -40.0}

var _out := ""
var _cam: Camera3D
var _caption: Label

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("headlook_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=headlook_lab")
	_run.call_deferred()

func _run() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	Game.god_mode = true
	player.process_mode = Node.PROCESS_MODE_DISABLED  # she stands where she is put
	for id in SPECIES:
		var c: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
		add_child(c)
		c.spawn(Data.creature(id))
		c.global_position = Vector3(0, 0.1, 0)
		c.rotation = Vector3.ZERO  # faces -Z
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		c.brain.attack_target = player
		c.brain.state = &"alert"
		var h := c.def.height_meters
		var dist := maxf(7.0, c.def.real_length_m * 1.1)
		for side in SIDES:
			var dir := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(SIDES[side]))
			player.global_position = Vector3(0, 0.1, -c.def.real_length_m * 0.3) + dir * dist
			c.global_position = Vector3(0, 0.1, 0)
			c.rotation = Vector3.ZERO
			for _f in 120:
				await get_tree().process_frame
			# Over the shoulder, high: the head and the survivor in one frame.
			_cam.look_at_from_position(Vector3(h * 0.9, h * 1.9, c.def.real_length_m * 0.55), Vector3(0, h * 0.5, -dist * 0.55), Vector3.UP)
			var a: Vector2 = c.view.head_look.applied() if c.view.head_look else Vector2.ZERO
			_caption.text = "%s   survivor %s   look yaw %+.0f deg  pitch %+.0f deg  weight %.2f   clip %s" % [id, side, rad_to_deg(a.x), rad_to_deg(a.y), c.view.head_look.weight if c.view.head_look else 0.0, c.anim.current_clip]
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, id, side])
			print("[headlook] saved %s/%s_%s.png (%s)" % [_out, id, side, _caption.text])
		c.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)
