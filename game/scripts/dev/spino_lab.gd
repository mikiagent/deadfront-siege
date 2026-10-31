extends Node3D
## SP-SPINOSAURUS review shots, self-quitting (cerato_lab.gd for the spinosaurus). Two modes:
##   default: one spinosaurus with the survivor standing at the jaws' reach for scale; every clip posed at 30 % and 60 %
##            (the fight moves also at their hit frame) from two cameras: side (left flank) and a high three-quarter
##            from the front left. Saves DIR/<clip>_<pct>_<cam>.png.
##   --live:  a real spinosaurus (TacticalBrain) does the snap-and-shake on the survivor (god mode): shots at the
##            windup, the clamp, mid-thrash, the fling and her landing (DIR/live_<n>_<what>.png), then the claw rake on
##            her close under its chest (DIR/live_rake_<what>.png) and the sail-flare display from her point of view.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=spino_lab --out=DIR [--live]

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"stalk", &"walk_back", &"strafe_left", &"strafe_right", &"alert",
	&"attack_primary", &"attack_heavy", &"bite_shake", &"kick", &"pounce", &"hit_react", &"feed", &"sleep", &"knockdown", &"death"]
## anim_events.json hit fractions: croc snap, claw rake, snap-and-shake clamp (and mid-thrash), tail swipe, water lunge.
const HIT := {&"attack_primary": 42, &"attack_heavy": 72, &"bite_shake": 30, &"kick": 45, &"pounce": 70}
const EXTRA := {&"bite_shake": [55, 78], &"alert": [80]}

var _out := ""
var _live := false
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--live":
			_live = true
	if _out == "":
		push_error("spino_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=spino_lab")
	if _live:
		_fight.call_deferred()
	else:
		_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[spino] saved %s/%s.png" % [_out, name])

func _label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)

func _cam(from: Vector3, at: Vector3) -> Camera3D:
	var c := Camera3D.new()
	c.fov = 40.0
	add_child(c)
	c.look_at_from_position(from, at)
	return c

func _sheet() -> void:
	var kit := LabKit.build(self, 120.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"spinosaurus")
	var v: CreatureView = CreatureView.new()
	add_child(v)
	v.setup(def)
	v.apply_coloration(CreatureColoration.neutral())
	v.rotation.y = PI / 2.0  # head toward -X, left flank toward +Z (the side camera)
	print("[spino] glb=%s rig=%s" % [v.using_glb, v.rig != null])
	# The survivor stands at the jaws' reach at the snap (about 9.5 m ahead of the centre), toward the side camera.
	player.global_position = Vector3(-9.6, 0.1, 1.5)
	player.rotation.y = -PI / 2.0
	_cams = {"side": _cam(Vector3(-2.0, 4.5, 34.0), Vector3(-2.0, 4.0, 0.0)), "tq": _cam(Vector3(-28.0, 14.0, 20.0), Vector3(-3.0, 3.0, 0.0))}
	_label()
	for _f in 10:
		await get_tree().process_frame
	var ap: AnimationPlayer = v.rig.anim_player
	for clip in CLIPS:
		if not ap.has_animation(clip):
			print("[spino] MISSING clip %s" % clip)
			continue
		var pcts: Array = [30, 60]
		if HIT.has(clip):
			pcts.append(HIT[clip])
		pcts.append_array(EXTRA.get(clip, []))
		for pct in pcts:
			v.rig.skeleton.reset_bone_poses()  # the importer drops constant tracks; a paused seek would keep the last clip's tail
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * pct / 100.0, true)
			ap.pause()
			for cam_name in _cams:
				(_cams[cam_name] as Camera3D).current = true
				_caption.text = "spinosaurus  %s %d%%%s   (survivor for scale)" % [clip, pct, "  HIT" if HIT.get(clip, -1) == pct else ""]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)

func _wait_until(cond: Callable, max_frames: int) -> void:
	for _f in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame

func _fight() -> void:
	var kit := LabKit.build(self, 160.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	Game.god_mode = true
	_label()
	player.global_position = Vector3(0, 0.2, 0)
	var c: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	add_child(c)
	c.global_position = Vector3(-9.0, 0.1, 0.0)
	c.spawn(Data.creature(&"spinosaurus"))
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	player.look_at(Vector3(-9.0, player.global_position.y, 0.0), Vector3.UP)
	var b := c.brain as TacticalBrain
	b.attack_target = player
	b._combat_memory_left = 60.0
	var side := _cam(Vector3(-3.0, 5.0, 30.0), Vector3(-3.0, 4.0, 0.0))
	side.current = true
	for _f in 20:
		await get_tree().physics_frame
	# 1. snap-and-shake
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	b._strike(b._flat_dist(player), ["grab"])
	_caption.text = "SNAP-AND-SHAKE: windup (jaws gaping, claws up, ring on her)"
	await _wait_until(func() -> bool: return b._grab_t > b._grab_len * 0.2, 120)
	await _snap("live_1_windup")
	await _wait_until(func() -> bool: return seen.has(&"grab_hit") or seen.has(&"grab_miss"), 120)
	_caption.text = "SNAP-AND-SHAKE: clamp (%s)" % ("caught" if seen.has(&"grab_hit") else "MISSED")
	await get_tree().process_frame
	await _snap("live_2_clamp")
	await _wait_until(func() -> bool: return b._grab_t > b._grab_len * 0.55, 120)
	_caption.text = "SNAP-AND-SHAKE: thrash, she is held in the jaws (%.1f m up)" % player.global_position.y
	await _snap("live_3_thrash")
	await _wait_until(func() -> bool: return seen.has(&"grab_fling"), 120)
	for _f in 6:
		await get_tree().physics_frame
	_caption.text = "SNAP-AND-SHAKE: fling to its left"
	await _snap("live_4_fling")
	for _f in 60:
		await get_tree().physics_frame
	_caption.text = "SNAP-AND-SHAKE: she lands %.1f m away" % Vector2(player.global_position.x, player.global_position.z).length()
	await _snap("live_5_landed")
	# 2. claw rake, close under its chest
	await _wait_until(func() -> bool: return b.state != &"grab", 120)
	b._set_state(&"circle")
	c.global_position = Vector3(-6.5, 0.1, 0.0) + Vector3(player.global_position.x, 0, player.global_position.z)
	c.look_at(Vector3(player.global_position.x, 0.1, player.global_position.z), Vector3.UP)
	side.look_at_from_position(player.global_position + Vector3(-3.0, 5.0, 26.0), player.global_position + Vector3(-3.0, 4.0, 0.0))
	for _f in 30:
		await get_tree().physics_frame
	b._cd.clear()
	b._strike(b._flat_dist(player), ["heavy"])
	_caption.text = "CLAW RAKE: rear-up, claws cocked (held telegraph)"
	await _wait_until(func() -> bool: return c.anim._os_t > 1.6 * 0.5, 120)
	await _snap("live_rake_windup")
	await _wait_until(func() -> bool: return c.anim._os_t > 1.6 * 0.73 or c.anim.current_clip != &"attack_heavy", 120)
	_caption.text = "CLAW RAKE: the claws rake down (Bleed %s)" % player.statuses.has(&"bleed")
	await _snap("live_rake_hit")
	# 3. sail-flare display from her side of it
	await _wait_until(func() -> bool: return not c.anim.is_busy(), 240)
	b._set_state(&"circle")
	var to_her := (player.global_position - c.global_position)
	to_her.y = 0.0
	var pov := _cam(player.global_position + to_her.normalized() * 22.0 + Vector3(0, 6.0, 0), c.global_position + Vector3(0, 4.5, 0))
	pov.current = true
	b._cd.clear()
	b.tac = b.tac.duplicate(true)
	b.tac["sequences"] = (b.tac["sequences"] as Array).filter(func(r: Dictionary) -> bool: return str(r["name"]) == "sail_flare_charge")
	b._start_sequence(b._flat_dist(player))  # the display step plays alert for display_s, then the charge
	_caption.text = "SAIL-FLARE DISPLAY (alert): turns broadside, sail shown, claws spread, roar"
	for k in 3:
		for _f in 22:
			await get_tree().physics_frame
		await _snap("live_display_%d" % k)
	get_tree().quit(0)
