extends Node3D
## THERO-ROAR review shots, self-quitting (cerato_lab.gd for every big theropod). Each species with the survivor beside it
## for scale, one clip posed at a few phases from the cameras asked for:
##   tq     front three-quarter from the left, a little high (the roar's head sweep reads here)
##   side   the left flank
##   behind the fight camera's pitch (IsoCamera 38.7 deg down, near-orthographic), the animal facing away ("head
##          facing north", the owner's view when he found the ceratosaurus head too big)
## At the roar's burst phase (anim_events roar hit_frac) the lab fires TheroRoar's ring and dust and lets them grow.
## Saves DIR/<species>_<clip>_<pct>_<cam>.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=theroroar_lab --out=DIR
##   [--species=ceratosaurus,megarex] [--clip=roar] [--pcts=10,35,60,85] [--cams=tq,behind]
## --stomp: SPACING STOMP live instead: each species fights the survivor tucked under its chest (the real brain, GOD on);
## saves <species>_stomp_hit.png just after the slam (dust ring) and <species>_stomp_bite.png at the follow-up bite's hit.

const SPECIES: Array[String] = ["ceratosaurus", "tyrannosaurus", "megarex", "allosaurus", "majungasaurus", "tarbosaurus", "spinosaurus"]

var _out := ""
var _species: Array[String] = SPECIES.duplicate()
var _clip := &"roar"
var _pcts: Array[int] = [10, 35, 60, 85]
var _cam_names: Array[String] = ["tq"]
var _caption: Label
var _stomp := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--species="):
			_species.assign(a.substr(10).split(","))
		elif a.begins_with("--clip="):
			_clip = StringName(a.substr(7))
		elif a.begins_with("--pcts="):
			_pcts.clear()
			for p in a.substr(7).split(","):
				_pcts.append(int(p))
		elif a == "--stomp":
			_stomp = true
		elif a.begins_with("--cams="):
			_cam_names.assign(a.substr(7).split(","))
	if _out == "":
		push_error("theroroar_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[theroroar] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 160.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).queue_free()  # the IsoCamera takes current back on its first frames
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	if _stomp:
		await _stomp_live(player, cam)
		get_tree().quit(0)
		return
	for id in _species:
		var def: CreatureDef = Data.creature(StringName(id))
		if def == null:
			print("[theroroar] MISSING species %s" % id)
			continue
		var v := CreatureView.new()
		add_child(v)
		v.setup(def, &"")
		v.apply_coloration(CreatureColoration.neutral())
		v.rotation.y = PI / 2.0  # head toward -X, left flank toward +Z
		var h := def.height_meters
		# the survivor stands ahead and to the left of the snout, facing it, for scale
		player.global_position = Vector3(-1.6 * h, 0.1, 0.5 * h)
		player.rotation.y = -PI / 2.0
		for _f in 10:
			await get_tree().process_frame
		var ap: AnimationPlayer = v.rig.anim_player
		if not ap.has_animation(_clip):
			print("[theroroar] MISSING clip %s/%s" % [id, _clip])
			v.queue_free()
			continue
		var burst := int(round(CreatureClips._hit_frac(_clip) * 100.0))
		for pct in _pcts:
			v.rig.skeleton.reset_bone_poses()  # the importer drops constant tracks; a paused seek would keep the last clip's tail
			ap.play(_clip)
			ap.seek(ap.get_animation(_clip).length * pct / 100.0, true)
			ap.pause()
			var fx := _clip == &"roar" and absi(pct - burst) <= 6
			var before := get_children()
			if fx:
				TheroRoar.fx(v, h, null)
				for _f in 14:
					await get_tree().process_frame
			for cam_name in _cam_names:
				_place(cam, cam_name, h)
				_caption.text = "%s  %s %d%%%s   (survivor for scale)" % [id, _clip, pct, "  BURST" if fx else ""]
				for _f in 3:  # the first shot of a run came out before the camera move took (one frame was not enough)
					await get_tree().process_frame
				await _snap("%s_%s_%d_%s" % [id, _clip, pct, cam_name])
			for n in get_children():  # the burst's rings and dust only in the burst shot
				if not before.has(n):
					n.queue_free()
		v.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)

func _place(cam: Camera3D, name: String, h: float) -> void:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	match name:
		"side":
			cam.fov = 38.0
			cam.look_at_from_position(Vector3(-0.3 * h, 0.65 * h, 4.4 * h), Vector3(-0.3 * h, 0.5 * h, 0.0))
		"behind":
			# IsoCamera's pitch, far back with a narrow lens (near-orthographic like the game), from behind the tail
			cam.fov = 12.0
			var pitch := deg_to_rad(38.7)
			var d := 11.0 * h
			var look := Vector3(-0.7 * h, 0.45 * h, 0.15 * h)
			cam.look_at_from_position(look + Vector3(cos(pitch) * d, sin(pitch) * d, 0.0), look)
		_:
			cam.fov = 38.0
			cam.look_at_from_position(Vector3(-3.0 * h, 1.3 * h, 3.0 * h), Vector3(-0.4 * h, 0.7 * h, 0.0))

## SPACING STOMP live: the survivor tucked a third of the way out to the jaws; the brain stomps, she is thrown or knocked
## out to bite reach, and it bites. Shots at the slam (plus a few frames for the dust) and at the bite's hit.
func _stomp_live(player: Player, cam: Camera3D) -> void:
	Game.god_mode = true
	for id in _species:
		var def: CreatureDef = Data.creature(StringName(id))
		if def == null:
			continue
		var c: Creature = load("res://scenes/creatures/creature.tscn").instantiate()
		add_child(c)
		c.global_position = Vector3(0, 0.1, 0)
		c.spawn(def)
		c.look_at(Vector3(-10, 0.1, 0), Vector3.UP)  # head toward -X, left flank toward +Z (the cameras)
		c.set_meta(&"thero_roar_at", Time.get_ticks_msec() * 0.001)  # no roar: the stomp is under review
		player.statuses.clear_all()
		for _f in 3:
			await get_tree().physics_frame
		var st := c.brain.spacing
		if st == null:
			print("[theroroar] %s has no spacing stomp" % id)
			c.queue_free()
			continue
		var h := def.height_meters
		player.global_position = c.global_position + Vector3(-1, 0, 0) * st.bite_reach(player) * 0.35 + Vector3.UP * 0.1
		c.brain.attack_target = player
		c.brain._combat_memory_left = 30.0
		_place(cam, "side", h)
		var mid := -0.5 * st.bite_reach(player)  # between the feet and where she lands
		cam.look_at_from_position(Vector3(mid, 0.45 * h, 2.4 * h), Vector3(mid, 0.3 * h, 0.0))
		var t := 0.0
		var hit_shot := false
		var bit := [false]
		c.anim.attack_hit.connect(func(_clip: StringName) -> void: bit[0] = true)  # a TacticalBrain bite's hit frame
		while t < 6.0:
			await get_tree().physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			if not hit_shot and st.phase == &"after":
				for _f in 6:
					await get_tree().process_frame
				_caption.text = "%s  SPACING STOMP: the slam (dust ring, ground shake %.2f)" % [id, st.last_shake]
				await _snap("%s_stomp_hit" % id)
				hit_shot = true
				bit[0] = false
			# the follow-up's hit frame: the clip's attack_hit, or a TyrantBrain's windup turning into its recovery
			var tyrant_hit: bool = c.brain is TyrantBrain and (c.brain as TyrantBrain).phase == &"recovery"
			if hit_shot and st.followed != &"" and (bit[0] or tyrant_hit):
				_caption.text = "%s  follow-up %s at its hit: pushed %.1f m to the jaws' reach %.1f m" % [id, st.followed, st.last_push, st.last_reach]
				await _snap("%s_stomp_bite" % id)
				break
		c.queue_free()
		player.statuses.clear_all()
		if player.sim:
			player.sim.knock.cancel()
		for _f in 30:
			await get_tree().physics_frame
	Game.god_mode = false
