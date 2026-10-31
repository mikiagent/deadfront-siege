extends Node3D
## DILOFRILL review shots, self-quitting. A live dilophosaurus (Creature + TacticalBrain) next to the survivor for
## scale: calm (brain held in roam: frill folded), then in a fight with her (GOD on): one shot while it circles or
## holds on a plain gait clip (the frill held open by DisplayFlare), one in a strike (snapped fully open).
## Saves DIR/calm.png, DIR/combat_hold.png, DIR/combat_strike.png. Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=dilofrill_lab --out=DIR

const GAITS: Array[StringName] = [&"walk", &"strafe_left", &"strafe_right", &"walk_back", &"idle", &"run"]
const TIMEOUT_S := 45.0

var _out := ""
var _cam: Camera3D
var _caption: Label

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("dilofrill_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=dilofrill_lab")
	_run.call_deferred()

func _snap(name: String, c: Creature, player: Node3D, text: String) -> void:
	# Side-on to the line between them, so both stand in profile.
	var mid := (c.global_position + player.global_position) * 0.5
	var along := (c.global_position - player.global_position)
	along.y = 0.0
	var side := along.normalized().cross(Vector3.UP)
	_cam.look_at_from_position(mid + side * (along.length() * 0.9 + 9.0) + Vector3(0, 2.4, 0), mid + Vector3(0, 1.4, 0))
	_caption.text = "%s   flare %.2f   state %s / %s   (survivor for scale)" % [text, c.view.flare.weight, c.brain.state, c.anim.current_clip]
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[dilofrill] saved %s/%s.png (%s) dilo %s her %s" % [_out, name, _caption.text, c.global_position, player.global_position])

func _run() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	_cam = Camera3D.new()
	_cam.fov = 40.0
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
	player.process_mode = Node.PROCESS_MODE_DISABLED  # she stands still
	player.global_position = Vector3(0, 0.1, 0)
	var c: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	add_child(c)
	c.global_position = Vector3(0, 0.1, -9.0)
	c.spawn(Data.creature(&"dilophosaurus"))
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)  # facing her: profile to the camera
	var b := c.brain as TacticalBrain
	b.process_mode = Node.PROCESS_MODE_DISABLED  # calm: held in roam, it never notices her
	b._set_state(&"roam")
	for _f in 180:  # the survivor's model streams in over the first frames
		await get_tree().process_frame
	await _snap("calm", c, player, "dilophosaurus CALM")
	b.process_mode = Node.PROCESS_MODE_INHERIT
	b.attack_target = player
	b._combat_memory_left = 60.0
	b._set_state(&"approach")
	var got_hold := false
	var got_strike := false
	var t := 0.0
	while t < TIMEOUT_S and not (got_hold and got_strike):
		await get_tree().process_frame
		t += get_process_delta_time()
		var w: float = c.view.flare.weight
		if not got_hold and t > 2.0 and c.anim.current_clip in GAITS and b.state in [&"circle", &"hold", &"approach"] and w >= 0.79:
			got_hold = true
			await _snap("combat_hold", c, player, "dilophosaurus IN COMBAT")
		elif not got_strike and c.anim.current_clip in [&"spit", &"attack_primary"] and w >= 0.99:
			got_strike = true
			await _snap("combat_strike", c, player, "dilophosaurus STRIKE")
	print("[dilofrill] done hold=%s strike=%s" % [got_hold, got_strike])
	get_tree().quit(0)
