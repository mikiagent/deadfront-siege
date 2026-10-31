extends Node3D
## HITBOXES review shots, self-quitting. The hitbox debug draw on (hurtboxes green, the judged sweep red, yellow
## where it touched): for each case a creature (brain off) plays its move at a survivor standing at its contact
## reach, and the tree pauses on the hit frame; then the survivor swings at a stegosaurus's leg. Saves
## DIR/<species>_<move>.png and DIR/survivor_swing.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=hitbox_lab --out=DIR

const CASES := [[&"velociraptor", &"attack_primary"], [&"triceratops", &"attack_heavy"], [&"deinonychus", &"bite_combo"], [&"tyrannosaurus", &"attack_heavy"]]

var _out := ""
var _caption: Label

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("hitbox_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.god_mode = true
	CombatTuning.force_accuracy = 1.0
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=hitbox_lab")
	_run.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[hitbox_lab] saved %s/%s.png" % [_out, name])

func _run() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.current = true
	Hitbox.debug_draw = true
	for row in CASES:
		var c := _spawn(row[0])
		for _f in 10:
			await get_tree().physics_frame
		var reach := c.brain.contact_reach()
		player.global_position = Vector3(0, player.global_position.y, -reach)
		player.face_world(c.global_position)
		var size := c.def.height_meters * c.size_scale()
		# Three-quarter from her side and above, so neither body hides the other.
		cam.look_at_from_position(Vector3(maxf(5.0, size * 1.8), maxf(3.0, size * 1.3), -reach - maxf(3.0, size)), Vector3(0, size * 0.35, -reach * 0.6))
		var hits := [0]
		var on_hit := func(clip: StringName) -> void:
			var hit := Hitbox.strike(c, clip, player, c.anim.hit_index)
			hits[0] += 1
			_caption.text = "%s %s%s: %s" % [c.def.id, clip, "" if clip != &"bite_combo" else " bite %d" % (c.anim.hit_index + 1),
				"hits the survivor's %s" % hit["part"] if not hit.is_empty() else "MISS"]
			get_tree().paused = true
		c.anim.attack_hit.connect(on_hit)
		c.anim.play_clip(row[1])
		while hits[0] == 0:
			await get_tree().physics_frame
		await get_tree().process_frame
		await _snap("%s_%s" % [row[0], row[1]])
		get_tree().paused = false
		c.anim.attack_hit.disconnect(on_hit)
		c.queue_free()
		for _f in 10:
			await get_tree().physics_frame
	# The survivor's swing at a stegosaurus: she walks to the leg she can reach and the swing lands there.
	var s := _spawn(&"stegosaurus")
	for _f in 10:
		await get_tree().physics_frame
	player.global_position = Vector3(7, player.global_position.y, 0)
	cam.look_at_from_position(Vector3(9, 5, 9), Vector3(1.5, 1.2, 0))
	var landed := [false]
	player.hunt.hit_landed.connect(func(_t: Creature) -> void:
		landed[0] = true
		_caption.text = "survivor swing lands on the stegosaurus %s" % s.health.last_hit_part
		get_tree().paused = true)
	player.hunt.start(s)
	var t := 0
	while not landed[0] and t < 600:
		await get_tree().physics_frame
		t += 1
	await get_tree().process_frame
	await _snap("survivor_swing")
	get_tree().paused = false
	Hitbox.debug_draw = false
	Game.god_mode = false
	get_tree().quit(0)

func _spawn(id: StringName) -> Creature:
	var c := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
	add_child(c)
	c.global_position = Vector3.ZERO
	c.spawn(Data.creature(id))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.health.setup(1e9)
	return c
