extends Node3D
## SP-RAPTOR review shots, self-quitting (smilodon_lab adapted). One raptor with the survivor standing a step ahead of its
## head for scale; every clip posed at 30 % and 60 % (the attacks and signature moves also at their hit frames) from two
## cameras: side (lit flank) and a high three-quarter from the front right. --variant=<morph> draws a colour morph
## (pipeline.model_variants). Saves DIR/<clip>_<pct>_<cam>.png. Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=raptor_lab --out=DIR [--variant=green] [--clips=a,b]
## RAPTORFLANK: --flank runs the live flank instead (the brain on its flank sequence only, the survivor standing still)
## and saves DIR/flank_<n>_<cam>.png every few frames from an overview and a chase camera, captioned with the phase.

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"charge", &"walk_back", &"strafe_left", &"strafe_right",
	&"attack_primary", &"bite_combo", &"attack_heavy", &"pounce", &"pin_stab", &"hop_back", &"leap_back", &"dodge_left",
	&"dodge_right", &"hit_react", &"alert", &"feed", &"sleep", &"knockdown", &"death", &"charge_turn", &"flank_rake"]
## anim_events.json hit fractions: the bites, the sickle slash, the pounce, the two pin bites.
const HIT := {&"attack_primary": [42], &"attack_heavy": [72], &"pounce": [70], &"pin_stab": [38, 74], &"bite_combo": [34, 82], &"flank_rake": [56]}
## The slash's held windup (anim_events windup_hold 0.6): the telegraph.
const EXTRA := {&"attack_heavy": [60]}

var _out := ""
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("raptor_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=raptor_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[raptor] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	if "--flank" in OS.get_cmdline_user_args():
		await _flank_shots(player)
		return
	var def: CreatureDef = Data.creature(&"raptor")
	var v: CreatureView = CreatureView.new()
	add_child(v)
	var morph := &""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--variant="):
			morph = StringName(a.substr(10))
	var want: Array[StringName] = CLIPS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--clips="):
			want = []
			for c in a.substr(8).split(","):
				want.append(StringName(c))
	v.setup(def, morph)
	v.apply_coloration(CreatureColoration.neutral())
	v.rotation.y = PI / 2.0  # head toward -X, left flank toward +Z (the side camera)
	print("[raptor] glb=%s rig=%s variant=%s" % [v.using_glb, v.rig != null, morph])
	# The survivor stands a step ahead of its head, slightly toward the side camera, for scale.
	player.global_position = Vector3(-5.6, 0.1, 1.2)
	player.rotation.y = -PI / 2.0
	var side := Camera3D.new()
	side.fov = 38.0
	add_child(side)
	side.look_at_from_position(Vector3(-1.4, 2.2, 15.5), Vector3(-1.4, 1.6, 0.0))
	var tq := Camera3D.new()
	tq.fov = 38.0
	add_child(tq)
	tq.look_at_from_position(Vector3(-12.5, 7.5, 11.5), Vector3(-1.4, 1.3, 0.0))
	_cams = {"side": side, "tq": tq}
	if "--close" in OS.get_cmdline_user_args():  # RAPTORFLANK: the arms and claws up close (chest from the side and the front)
		side.look_at_from_position(Vector3(-2.6, 2.4, 6.5), Vector3(-2.6, 1.8, 0.0))
		tq.look_at_from_position(Vector3(-8.5, 3.0, 4.5), Vector3(-2.6, 1.7, 0.0))
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
			print("[raptor] MISSING clip %s" % clip)
			continue
		var pcts: Array = [30, 60]
		if HIT.has(clip):
			pcts.append_array(HIT[clip])
		pcts.append_array(EXTRA.get(clip, []))
		for pct in pcts:
			v.rig.skeleton.reset_bone_poses()  # the importer drops constant tracks; a paused seek would keep the last clip's tail
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * pct / 100.0, true)
			ap.pause()
			for cam_name in _cams:
				(_cams[cam_name] as Camera3D).current = true
				_caption.text = "raptor%s  %s %d%%%s   (survivor for scale)" % [(" " + str(morph)) if morph != &"" else "", clip, pct, "  HIT" if pct in HIT.get(clip, []) else ("  WINDUP" if pct in EXTRA.get(clip, []) else "")]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)

## The live flank: run past, skid-turn, strafe round to her back, leap-rake. Two cameras: a high overview of the whole
## manoeuvre and a chase camera on the raptor.
func _flank_shots(player: Player) -> void:
	var morph := &""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--variant="):
			morph = StringName(a.substr(10))
	Game.god_mode = true
	player.global_position = Vector3(0, 0.1, 0)
	player.visual.rotation.y = 0.0  # she faces -Z, toward where the raptor starts
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	add_child(c)
	c.global_position = Vector3(0, 0.1, -10.0)
	c.spawn(Data.creature(&"raptor"), morph)
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	var b := c.brain as TacticalBrain
	b.tac = b.tac.duplicate()
	b.tac["sequences"] = (b.tac["sequences"] as Array).filter(func(r: Dictionary) -> bool: return r.get("name") == "flank")
	b.rng.seed = 7
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._enter_circle(0.0)
	var over := Camera3D.new()
	over.fov = 50.0
	add_child(over)
	over.look_at_from_position(Vector3(-14.0, 16.0, 12.0), Vector3(0, 0, -1.0))
	var chase := Camera3D.new()
	chase.fov = 45.0
	add_child(chase)
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 30)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	var n := 0
	var done_t := -1
	for f in 60 * 30:
		await get_tree().physics_frame
		if b.state != &"flank" and n == 0:
			continue
		if done_t < 0 and b.state != &"flank":
			done_t = f
		if done_t >= 0 and f - done_t > 30:
			break
		if f % 8 != 0:
			continue
		var phase: String = str(b._flank_phase) if b.state == &"flank" else str(b.state)
		var to := c.global_position - player.global_position
		chase.look_at_from_position(c.global_position + Vector3(-9.0, 6.0, 9.0), c.global_position.lerp(player.global_position, 0.35) + Vector3(0, 1.2, 0))
		for cam_name in ["over", "chase"]:
			var cam: Camera3D = over if cam_name == "over" else chase
			cam.current = true
			_caption.text = "raptor%s  FLANK %s  %.0f deg off her facing  clip %s" % [(" " + str(morph)) if morph != &"" else "", phase, b.behind_deg(), c.anim.current_clip]
			await get_tree().process_frame
			await _snap("flank_%03d_%s" % [n, cam_name])
		n += 1
	print("[raptor] flank shots %d" % n)
	Game.god_mode = false
	get_tree().quit(0)
