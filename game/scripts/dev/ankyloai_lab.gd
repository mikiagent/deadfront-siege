extends Node3D
## ANKYLOAI review shots, self-quitting. A live ankylosaurus (ClubTailBrain) and the survivor in GOD mode: for each move
## (TAIL WHIP, TAIL SMASH, CLUB SWEEP) the survivor stands on the move's aim spot, the brain swings, and the tree pauses
## on the frame the club lands (club_hit), so the shot shows the club on her. One wind-up shot per move shows the ring
## and the name. Two cameras: high from the swing side, and low side-on to her. Saves DIR/<move>_<windup|hit>_<cam>.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=ankyloai_lab --out=DIR

const MOVES: Array[StringName] = [&"whip", &"smash", &"sweep"]

var _out := ""
var _caption: Label
var _hit := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("ankyloai_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.god_mode = true
	CombatTuning.force_accuracy = 1.0
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=ankyloai_lab")
	_run.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[ankyloai] saved %s/%s.png" % [_out, name])

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
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	var high := Camera3D.new()
	high.fov = 45.0
	high.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(high)
	var low := Camera3D.new()
	low.fov = 45.0
	add_child(low)
	for id in MOVES:
		player.global_position = Vector3(12, player.global_position.y, 12)  # clear of the spawn point (it would stand on her)
		var c := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
		add_child(c)
		c.global_position = Vector3.ZERO
		c.spawn(Data.creature(&"ankylosaurus"))
		c.look_at(Vector3(0, 0, -10), Vector3.UP)
		for _f in 10:
			await get_tree().physics_frame
		var b := c.brain as ClubTailBrain
		var mv: Dictionary = b.moves[id]
		var spot := b.strike_spot(id)
		player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
		player.look_at(Vector3(0, player.global_position.y, 0), Vector3.UP)
		b.attack_target = player
		b._provoked_until = b._now_s() + 60.0
		# high camera on the swing side, looking across the animal at her; low camera side-on to her and the club
		var side := signf(spot.x) if absf(spot.x) > 0.3 else 1.0
		high.look_at_from_position(Vector3(side * 9.0, 9.0, 2.0), (spot + Vector3(0, 0, -1.0)) * 0.6 + Vector3(0, 0.6, 0))
		var across := (spot - Vector3(0, 0, -1.0)).normalized().cross(Vector3.UP)  # side-on to the line from its body to her
		low.look_at_from_position(spot + across * 6.0 + Vector3(0, 1.4, 0), spot.lerp(Vector3(0, 0, -1.0), 0.3) + Vector3(0, 0.9, 0))
		_hit = false
		var on_hit := func(_m: StringName, t: Node3D, kind: StringName) -> void:
			if t == player and not _hit:
				_hit = true
				get_tree().paused = true
				_caption.text = "%s  HIT (%s) at %.2f s: club %.2f m from the survivor (hit radius %.1f m)" % [mv["label"], kind, b.move_t,
					Vector2(b.club_position().x - player.global_position.x, b.club_position().z - player.global_position.z).length(), mv["hit_radius_m"]]
		b.club_hit.connect(on_hit)
		b._start(id)
		var windup := float(mv["strike"][0]) * b.move_len
		var shot_windup := false
		while b.move_id != &"" and not _hit:
			await get_tree().physics_frame
			if not _hit:
				player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
			if not shot_windup and b.move_t >= windup * 0.6:
				shot_windup = true
				get_tree().paused = true
				_caption.text = "%s  wind-up %.1f / %.1f s (ring + name: roll or get to its head)" % [mv["label"], b.move_t, windup]
				high.current = true
				await get_tree().process_frame
				await _snap("%s_windup_high" % id)
				get_tree().paused = false
		if _hit:
			for cam in [high, low]:
				(cam as Camera3D).current = true
				await get_tree().process_frame
				await _snap("%s_hit_%s" % [id, "high" if cam == high else "low"])
			get_tree().paused = false
		else:
			print("[ankyloai] %s: NO HIT" % id)
		b.club_hit.disconnect(on_hit)
		c.queue_free()
		player.statuses.clear_all()
		for _f in 30:
			await get_tree().physics_frame
	Game.god_mode = false
	get_tree().quit(0)
