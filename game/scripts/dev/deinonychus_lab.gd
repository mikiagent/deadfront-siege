extends Node3D
## SP-DEINONYCHUS review shots (raptor_lab adapted, self-quitting). One deinonychus with the survivor standing a step ahead of its
## head for scale; every clip posed at 30 % and 60 % (the attacks and signature moves also at their hit frames) from two
## cameras: side (lit flank) and a high three-quarter from the front right. --variant=<morph> draws a colour morph
## (pipeline.model_variants). Saves DIR/<clip>_<pct>_<cam>.png. Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=deinonychus_lab --out=DIR [--clips=a,b] [--close]

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"charge", &"walk_back", &"strafe_left", &"strafe_right",
	&"attack_primary", &"bite_combo", &"attack_heavy", &"pounce", &"hop_back", &"leap_back", &"dodge_left",
	&"dodge_right", &"hit_react", &"alert", &"feed", &"sleep", &"knockdown", &"death"]
## anim_events.json hit fractions: the bite, the three chomps, the sickle slash, the pounce.
const HIT := {&"attack_primary": [42], &"attack_heavy": [72], &"pounce": [70], &"bite_combo": [9, 34, 82]}
## The slash's held windup (anim_events windup_hold 0.6): the telegraph.
## DEINOARMS: each attack's wind-up (the wings spread before the hit): bite 0.32, the three chomps, the pounce's take-off.
const EXTRA := {&"attack_heavy": [60], &"attack_primary": [32], &"bite_combo": [5, 28, 72], &"pounce": [25]}

var _out := ""
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("deinonychus_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=deinonychus_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[deinonychus] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"deinonychus")
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
	print("[deinonychus] glb=%s rig=%s variant=%s" % [v.using_glb, v.rig != null, morph])
	# The survivor stands a step ahead of its head, slightly toward the side camera, for scale.
	player.global_position = Vector3(-4.6, 0.1, 1.2)
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
			print("[deinonychus] MISSING clip %s" % clip)
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
				_caption.text = "deinonychus%s  %s %d%%%s   (survivor for scale)" % [(" " + str(morph)) if morph != &"" else "", clip, pct, "  HIT" if pct in HIT.get(clip, []) else ("  WIND-UP" if pct in EXTRA.get(clip, []) else "")]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)
