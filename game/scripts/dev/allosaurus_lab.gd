extends Node3D
## SP-ALLOSAURUS review shots, self-quitting (smilodon_lab adapted). One allosaurus with the survivor standing where its
## jaws land, for scale; every clip posed at 30 % and 60 % (the attacks and signature moves also at their hit frames)
## from two cameras: side (lit flank) and a high three-quarter from the front right. Saves DIR/<clip>_<pct>_<cam>.png.
## Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=allosaurus_lab --out=DIR [--clips=a,b]

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"walk_back", &"strafe_left", &"strafe_right",
	&"attack_primary", &"attack_heavy", &"grab_bite", &"kick", &"hit_react", &"alert", &"feed", &"sleep", &"knockdown", &"death",
	&"claw_rake", &"slash_bite", &"check_left", &"check_right"]
## anim_events.json hit fractions: the snap bite, the hatchet chop (and its held gape at 50), the grab's clamp and two
## bites, the shoulder ram.
const HIT := {&"attack_primary": [42], &"attack_heavy": [50, 72], &"grab_bite": [30, 55, 80], &"kick": [45],
	&"claw_rake": [27, 50], &"slash_bite": [23, 42], &"check_left": [25, 45], &"check_right": [25, 45]}  # ALLOFEEL: the held tell, then the hit

var _out := ""
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("allosaurus_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=allosaurus_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[allosaurus] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"allosaurus")
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
	print("[allosaurus] glb=%s rig=%s alpha=%s" % [v.using_glb, v.rig != null, alpha])
	# The survivor stands where the jaws land (about 6.5 m ahead of its centre), toward the side camera, for scale.
	player.global_position = Vector3(-6.6, 0.1, 1.2)
	player.rotation.y = PI / 2.0
	var side := Camera3D.new()
	side.fov = 38.0
	add_child(side)
	side.look_at_from_position(Vector3(-2.5, 3.5, 24.0), Vector3(-2.5, 3.0, 0.0))
	var tq := Camera3D.new()
	tq.fov = 38.0
	add_child(tq)
	tq.look_at_from_position(Vector3(-17.0, 10.0, 15.0), Vector3(-3.0, 2.5, 0.0))
	_cams = {"side": side, "tq": tq}
	if "--close" in OS.get_cmdline_user_args():  # ALLOFEEL: the chest and arms up close, from the front left
		var close := Camera3D.new()
		close.fov = 40.0
		add_child(close)
		close.look_at_from_position(Vector3(-15.5, 6.0, 12.0), Vector3(-4.6, 3.6, 0.0))
		_cams["close"] = close
	if "--hits-only" in OS.get_cmdline_user_args():
		var keep: Array[StringName] = []
		for c in want:
			if HIT.has(c):
				keep.append(c)
		want = keep
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
			print("[allosaurus] MISSING clip %s" % clip)
			continue
		var pcts: Array = [] if "--hits-only" in OS.get_cmdline_user_args() else [30, 60]
		if HIT.has(clip):
			pcts.append_array(HIT[clip])
		for pct in pcts:
			v.rig.skeleton.reset_bone_poses()  # the importer drops constant tracks; a paused seek would keep the last clip's tail
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * pct / 100.0, true)
			ap.pause()
			for cam_name in _cams:
				(_cams[cam_name] as Camera3D).current = true
				_caption.text = "allosaurus%s  %s %d%%%s   (survivor for scale)" % [" ALPHA" if alpha else "", clip, pct, "  HIT" if pct in HIT.get(clip, []) else ""]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)
