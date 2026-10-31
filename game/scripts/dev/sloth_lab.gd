extends Node3D
## SP-MEGATHERIUM review shots (sloth_lab adapted), self-quitting. One giant ground sloth with the survivor standing
## where its claws strike, for scale; every clip posed at 30 % and 60 % (the signature moves also at their hit frames)
## from two cameras: side (lit flank) and a high three-quarter from the front left. Saves DIR/<clip>_<pct>_<cam>.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=sloth_lab --out=DIR

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"charge", &"walk_back", &"strafe_left", &"strafe_right",
	&"alert", &"attack_primary", &"attack_heavy", &"grab", &"pounce", &"pin_stab", &"toss", &"hit_react", &"feed", &"sleep",
	&"knockdown", &"death"]
## anim_events.json hit fractions: hook, overhead swipe, hug, crush, the advance's topple.
const HIT := {&"attack_primary": 42, &"attack_heavy": 72, &"pounce": 70, &"pin_stab": 38, &"toss": 30}
var _alpha := false

var _out := ""
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		_alpha = _alpha or a == "--alpha"
	if _out == "":
		push_error("sloth_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=sloth_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[sloth] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"megatherium")
	var v: CreatureView = CreatureView.new()
	add_child(v)
	v.setup(def, &"alpha" if _alpha else &"")
	v.apply_coloration(CreatureColoration.neutral())
	v.rotation.y = PI / 2.0  # head toward -X, left flank toward +Z (the side camera)
	print("[sloth] glb=%s rig=%s" % [v.using_glb, v.rig != null])
	# The survivor stands a step ahead of its head, slightly toward the side camera, for scale.
	player.global_position = Vector3(-4.4, 0.1, 1.2)
	player.rotation.y = -PI / 2.0
	var side := Camera3D.new()
	side.fov = 38.0
	add_child(side)
	side.look_at_from_position(Vector3(-1.5, 3.0, 16.0), Vector3(-1.5, 2.6, 0.0))
	var tq := Camera3D.new()
	tq.fov = 38.0
	add_child(tq)
	tq.look_at_from_position(Vector3(-12.0, 6.5, 9.0), Vector3(-1.5, 2.2, 0.0))
	_cams = {"side": side, "tq": tq}
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
	for clip in CLIPS:
		if not ap.has_animation(clip):
			print("[sloth] MISSING clip %s" % clip)
			continue
		var pcts: Array = [30, 60]
		if HIT.has(clip):
			pcts.append(HIT[clip])
		for pct in pcts:
			v.rig.skeleton.reset_bone_poses()  # the importer drops constant tracks; a paused seek would keep the last clip's tail
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * pct / 100.0, true)
			ap.pause()
			for cam_name in _cams:
				(_cams[cam_name] as Camera3D).current = true
				_caption.text = "giant ground sloth%s  %s %d%%%s   (survivor for scale)" % [" (alpha)" if _alpha else "", clip, pct, "  HIT" if HIT.get(clip, -1) == pct else ""]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)
