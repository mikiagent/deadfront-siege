extends Node3D
## STEGOSPIN review shots, self-quitting. A live stegosaurus or ankylosaurus (ClubTailBrain) and the survivor in GOD mode.
## Per move: the survivor stands where the move reaches, the brain plays it, and the lab saves frames through it (a turn
## move at 0 / 60 / 120 / 180 deg of its turn) plus the frame the hit lands (paused on club_hit). "joust" (ankylosaurus):
## she stands 18 m ahead and the brain jousts on its own; a frame every 0.8 s from high above.
## Saves DIR/<species>_<variant>_<move>_<tag>.png. Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=stegospin_lab --out=DIR [--species=ankylosaurus]
##   [--variant=ochre] [--moves=spin_right,stomp]

const STEGO: Array[StringName] = [&"spin_right", &"pivot_left", &"stomp", &"rear_slam", &"hind_stomp_right", &"shove_left", &"tackle"]
const ANKY: Array[StringName] = [&"spin_left", &"joust"]
## Where she stands per move, body frame (+x its right, -z ahead), for the moves that have no aim spot of their own.
const AT := {&"spin_right": Vector3(-4.0, 0, 6.0), &"spin_left": Vector3(0.6, 0, -4.4), &"pivot_left": Vector3(-6.0, 0, 9.0),
	&"tackle": Vector3(0, 0, -7.5)}

var _out := ""
var _species := &"stegosaurus"
var _variant := &""
var _only: Array = []
var _caption: Label
var _hit := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--species="):
			_species = StringName(a.substr(10))
		elif a.begins_with("--variant="):
			_variant = StringName(a.substr(10))
		elif a.begins_with("--moves="):
			_only = Array(a.substr(8).split(","))
	if _out == "":
		push_error("stegospin_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	Game.god_mode = true
	CombatTuning.force_accuracy = 1.0
	TouchControls.visible = false
	TouchControls.enabled = false
	_run.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s_%s_%s.png" % [_out, _species, _variant if _variant != &"" else &"base", name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[stegospin] saved %s" % path)

func _run() -> void:
	var kit := LabKit.build(self, 120.0)
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
	cam.fov = 50.0
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cam)
	cam.current = true
	var k := 1.0 if _species == &"stegosaurus" else 0.75
	for id in (STEGO if _species == &"stegosaurus" else ANKY):
		if not _only.is_empty() and not str(id) in _only:
			continue
		player.global_position = Vector3(40, 0, 40)  # clear of the spawn point
		for _f in 3:
			await get_tree().physics_frame
		var c := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
		add_child(c)
		c.global_position = Vector3.ZERO
		c.spawn(Data.creature(_species), _variant)
		c.look_at(Vector3(0, 0, -10), Vector3.UP)
		c.brain._roam_pause = 999.0
		for _f in 10:
			await get_tree().physics_frame
		var b := c.brain as ClubTailBrain
		b.attack_target = player
		b._provoked_until = b._now_s() + 60.0
		if id == &"joust":
			await _joust(c, b, player, cam)
		else:
			await _move(c, b, player, cam, id, k)
		c.queue_free()
		player.statuses.clear_all()
		for _f in 20:
			await get_tree().physics_frame
	Game.god_mode = false
	get_tree().quit(0)

func _move(c: Creature, b: ClubTailBrain, player: Player, cam: Camera3D, id: StringName, k: float) -> void:
	var mv: Dictionary = b.moves[id]
	var at: Vector3 = AT[id] if AT.has(id) else c.global_transform.affine_inverse() * b.strike_spot(id)
	var spot := c.global_transform * at
	player.global_position = Vector3(spot.x, 0.0, spot.z)
	player.look_at(Vector3(0, 0, 0), Vector3.UP)
	# high and oblique from her side, the whole animal in frame
	var side := signf(at.x) if absf(at.x) > 0.3 else 1.0
	cam.look_at_from_position(Vector3(side * 16.0, 14.0, 10.0) * k, Vector3(0, 1.5, 1.0) * k)
	_hit = false
	var on_hit := func(_m: StringName, t: Node3D, _kind: StringName) -> void:
		if t == player and not _hit:
			_hit = true
			get_tree().paused = true
			_caption.text = "%s %s  HIT at %.2f s%s" % [_species, mv.get("label", id), b.move_t, " (knockdown)" if mv.get("knockdown", false) else ""]
	b.club_hit.connect(on_hit)
	b._start(id)
	var marks := [60.0, 120.0, 180.0] if mv.has("turn_deg") else []
	var windup := float((mv.get("strike", [0.5]) as Array)[0]) * b.move_len * 0.7
	var shot_w := false
	while b.move_id != &"":
		await get_tree().physics_frame
		if not _hit and player.statuses.has(&"knockdown") == false and not mv.has("turn_deg"):
			player.global_position = Vector3(spot.x, 0.0, spot.z)  # she holds her spot until it lands
		if not shot_w and b.move_t >= windup:
			shot_w = true
			_caption.text = "%s %s  wind-up %.1f s%s" % [_species, mv.get("label", id), b.move_t, "" if b.pivots.has(id) else " (ring + name)"]
			get_tree().paused = true
			await get_tree().process_frame
			await _snap("%s_windup" % id)
			get_tree().paused = false
		if not marks.is_empty() and absf(b.turn_applied) >= float(marks[0]):
			_caption.text = "%s %s  turned %.0f deg about its %s front foot" % [_species, mv.get("label", id), absf(b.turn_applied), "right" if float(mv["turn_deg"]) < 0.0 else "left"]
			get_tree().paused = true
			await get_tree().process_frame
			await _snap("%s_turn%03d" % [id, int(marks[0])])
			marks.pop_front()
			get_tree().paused = false
		if _hit and get_tree().paused:
			await get_tree().process_frame
			await _snap("%s_hit" % id)
			get_tree().paused = false  # _hit stays set: one hit shot per move
	b.club_hit.disconnect(on_hit)

func _joust(c: Creature, b: ClubTailBrain, player: Player, cam: Camera3D) -> void:
	player.global_position = Vector3(0, 0, -18.0)
	b._set_state(&"approach")
	cam.look_at_from_position(Vector3(22.0, 30.0, -6.0), Vector3(0, 0, -10.0))
	var t := 0.0
	var n := 0
	var next := 0.0
	while t < 14.0 and n < 14:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		player.hunt.stop()
		if t >= next and b.joust_phase != &"":
			next = t + 0.8
			_caption.text = "ankylosaurus JOUST  %s  %.1f s  (%s)" % [b.joust_phase, t, c.anim.current_clip]
			await _snap("joust_%02d" % n)
			n += 1
		if n > 0 and b.joust_phase == &"":
			break
