extends Node3D
## SP-SMILODON review shots, self-quitting. One smilodon with the survivor standing a step ahead of its head for scale;
## every clip posed at 30 % and 60 % (the attacks and signature moves also at their hit frames) from two cameras: side
## (lit flank) and a high three-quarter from the front right. --alpha draws the alpha skin. Saves
## DIR/<clip>_<pct>_<cam>.png. Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=smilodon_lab --out=DIR [--alpha] [--clips=a,b]
##   [--pcts=0,12,25,...] [--cams=side]  (SMILORUN: a gait-cycle contact strip instead of the 30/60 % pair, one camera)
## --fight (SMILOFEEL): the live brain instead of posed clips, GOD survivor: the long leap mid-air, the pin and the maul
##   (fight_leap_air, fight_pin, fight_maul), then a scripted survivor sprinting away with the cat's strikes held off, seen
##   from high above with a dot every 0.1 s (cat orange, survivor blue): bounds spread the dots, pauses bunch them
##   (fight_chase_high).

const CLIPS: Array[StringName] = [&"idle", &"walk", &"lope", &"run", &"sprint", &"leap", &"stalk", &"walk_back", &"strafe_left", &"strafe_right",
	&"attack_primary", &"attack_heavy", &"pounce", &"pin_stab", &"hit_react", &"alert", &"feed", &"sleep", &"knockdown", &"death"]
## anim_events.json hit fractions: the paw rakes, the sabres stab.
const HIT := {&"attack_primary": [42], &"attack_heavy": [72], &"pounce": [70], &"pin_stab": [38, 74]}

var _out := ""
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("smilodon_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=smilodon_lab")
	if "--fight" in OS.get_cmdline_user_args():
		_fight.call_deferred()
	else:
		_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[smilodon] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"smilodon")
	var v: CreatureView = CreatureView.new()
	add_child(v)
	var alpha := "--alpha" in OS.get_cmdline_user_args()
	var want: Array[StringName] = CLIPS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clips="):
			want = []
			for c in a.substr(8).split(","):
				want.append(StringName(c))
	v.setup(def, &"alpha" if alpha else &"")
	v.apply_coloration(CreatureColoration.neutral())
	v.rotation.y = PI / 2.0  # head toward -X, left flank toward +Z (the side camera)
	print("[smilodon] glb=%s rig=%s alpha=%s" % [v.using_glb, v.rig != null, alpha])
	# The survivor stands a step ahead of its head, slightly toward the side camera, for scale.
	player.global_position = Vector3(-3.0, 0.1, 0.9)
	player.rotation.y = -PI / 2.0
	var side := Camera3D.new()
	side.fov = 38.0
	add_child(side)
	side.look_at_from_position(Vector3(-0.8, 1.6, 8.5), Vector3(-0.8, 1.0, 0.0))
	var tq := Camera3D.new()
	tq.fov = 38.0
	add_child(tq)
	tq.look_at_from_position(Vector3(-6.5, 4.5, 6.5), Vector3(-0.6, 0.8, 0.0))
	_cams = {"side": side, "tq": tq}
	var only_pcts: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pcts="):
			for p in a.substr(7).split(","):
				only_pcts.append(int(p))
		if a.begins_with("--cams="):
			var keep := {}
			for cn in a.substr(7).split(","):
				if _cams.has(cn):
					keep[cn] = _cams[cn]
			_cams = keep
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	for _f in 10:
		await get_tree().process_frame
	var ap: AnimationPlayer = v.rig.anim_player
	for clip in want:
		if not ap.has_animation(clip):
			print("[smilodon] MISSING clip %s" % clip)
			continue
		var pcts: Array = [30, 60]
		if HIT.has(clip):
			pcts.append_array(HIT[clip])
		if not only_pcts.is_empty():
			pcts = only_pcts
		for pct in pcts:
			v.rig.skeleton.reset_bone_poses()  # the importer drops constant tracks; a paused seek would keep the last clip's tail
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * pct / 100.0, true)
			ap.pause()
			for cam_name in _cams:
				(_cams[cam_name] as Camera3D).current = true
				_caption.text = "smilodon%s  %s %d%%%s   (survivor for scale)" % [" ALPHA" if alpha else "", clip, pct, "  HIT" if pct in HIT.get(clip, []) else ""]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)

func _caption_layer() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)

func _spawn_cat(at: Vector3, face: Vector3) -> Creature:
	var c := (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate() as Creature
	add_child(c)
	c.global_position = at
	c.spawn(Data.creature(&"smilodon"))
	c.look_at(Vector3(face.x, at.y, face.z), Vector3.UP)
	return c

func _shot(cam: Camera3D, name: String, text: String) -> void:
	cam.current = true
	cam.reset_physics_interpolation()  # physics interpolation would otherwise sweep it in from its last spot
	_caption.text = text
	await get_tree().process_frame
	await _snap(name)

func _dot(at: Vector3, col: Color, r: float) -> void:
	var m := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = r
	sph.height = r * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sph.material = mat
	m.mesh = sph
	add_child(m)
	m.global_position = Vector3(at.x, 0.15, at.z)
	m.reset_physics_interpolation()

## SMILOFEEL review shots from the live brain (see the header).
func _fight() -> void:
	var kit := LabKit.build(self, 160.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	Game.god_mode = true
	_caption_layer()
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	for _f in 10:
		await get_tree().physics_frame
	# 1-3: the long leap from 11.5 m onto a standing survivor, the pin and the maul (her loop runs: PINFEEL lays her down).
	player.global_position = Vector3(0, 0.1, 0)
	var c := _spawn_cat(Vector3(0, 0.1, -11.5), Vector3.ZERO)
	var b := c.brain as TacticalBrain
	for _f in 5:
		await get_tree().physics_frame
	b.attack_target = player
	b._combat_memory_left = 30.0
	var phase := [0]
	var worry := [false]
	b.tactic_hit.connect(func(clip: StringName, i: int, _m: float) -> void:
		if clip == &"maul_bite" and i == 1:
			worry[0] = true)
	b._strike(Vector2(c.global_position.x, c.global_position.z).length(), ["long_leap"])
	var top := 0.0
	var pinned_t := -1.0
	var t := 0.0
	for _f in 480:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var lift := c.view.position.y
		if phase[0] == 0 and b._pounce_phase == &"leap":
			if lift >= top:
				top = lift
			elif top > 0.8:
				var mid_air := c.view.global_position + Vector3(0, 1.4, 0)
				cam.look_at_from_position(mid_air + Vector3(12.0, 0.3, -2.0), mid_air)
				await _shot(cam, "fight_leap_air", "SMILOFEEL  long leap: mid-air, %.1f m off the ground, forepaws thrown forward" % lift)
				phase[0] = 1
		if phase[0] <= 1 and player.statuses.has(&"pinned"):
			pinned_t = t if pinned_t < 0.0 else pinned_t
			if t - pinned_t > 0.7:
				var mid_pin := (c.global_position + player.global_position) * 0.5 + Vector3(0, 0.8, 0)
				cam.look_at_from_position(mid_pin + Vector3(4.0, 1.4, 6.0), mid_pin)
				await _shot(cam, "fight_pin", "SMILOFEEL  the leap landed on her: pinned under the forepaws (PinHold)")
				phase[0] = 2
		if phase[0] == 2 and worry[0]:
			var mid_maul := (c.global_position + player.global_position) * 0.5 + Vector3(0, 0.8, 0)
			cam.look_at_from_position(mid_maul + Vector3(-5.5, 1.8, 4.5), mid_maul)
			await _shot(cam, "fight_maul", "SMILOFEEL  the maul: sabres in, head-shake worry, a forepaw raking")
			phase[0] = 3
		if phase[0] == 3:
			break
	c.queue_free()
	await get_tree().physics_frame
	# 4: the burst chase, from high above.
	player.process_mode = Node.PROCESS_MODE_DISABLED  # a scripted sprinter
	player.statuses.clear_all()
	var start := Vector3(0, 0.1, -40.0)
	var cat := _spawn_cat(start, Vector3(0, 0.1, 100.0))
	var cb := cat.brain as TacticalBrain
	cb.tac = cb.tac.duplicate(true)
	(cb.tac["bound"] as Dictionary)["strike"] = false  # the chase itself is the picture, not the catch
	for k in [&"pounce", &"long_leap", &"maul", &"bite", &"heavy"]:
		cb._cd[k] = 999.0
	cb.tac["pounce_cd"] = 999.0
	cb.tac["long_leap_cd"] = 999.0
	player.global_position = start + Vector3(0, 0.0, 8.0)
	var sprint := player.sprint_speed
	var acc := 0.0
	var last := cat.global_position
	for f in 360:
		player.velocity = Vector3(0, 0, sprint)
		player.global_position += player.velocity / float(Engine.physics_ticks_per_second)
		await get_tree().physics_frame
		acc += get_physics_process_delta_time()
		if acc >= 0.1:
			acc = 0.0
			var v := Vector2(cat.global_position.x - last.x, cat.global_position.z - last.z).length() / 0.1
			last = cat.global_position
			if v < 3.0:
				_dot(cat.global_position, Color(0.55, 0.0, 0.0), 0.8)  # planted: the pause
			else:
				_dot(cat.global_position, Color(1.0, 0.5, 0.05) if v > 8.0 else Color(1.0, 0.9, 0.2), 0.4)
			_dot(player.global_position + Vector3(1.4, 0, 0), Color(0.2, 0.55, 1.0), 0.3)  # beside her line, not on the cat's
	var mid := (start + player.global_position) * 0.5
	cam.fov = 40.0
	cam.look_at_from_position(mid + Vector3(-14.0, 66.0, 0.0), mid, Vector3.UP)
	await _shot(cam, "fight_chase_high", "SMILOFEEL burst chase, 6 s from above, a dot every 0.1 s.  Survivor: blue, sprinting %.1f m/s.\nCat: orange = bounding (>8 m/s), yellow = moving, big dark red = planted pause (<3 m/s)" % sprint)
	get_tree().quit(0)
