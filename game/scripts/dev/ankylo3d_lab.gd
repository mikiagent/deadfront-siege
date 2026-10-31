extends Node3D
## ANKYLO3D review shots, self-quitting. One ankylosaurus with the survivor standing at its left shoulder for scale;
## every clip posed at 30 % and 60 % (the attacks also at their hit frame) from two cameras: side (lit flank) and a
## high three-quarter from the right rear, which shows the tail-club swing. Saves DIR/<clip>_<pct>_<cam>.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=ankylo3d_lab --out=DIR

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"walk_back", &"strafe_left", &"strafe_right", &"attack_primary",
	&"attack_heavy", &"hit_react", &"alert", &"feed", &"sleep", &"knockdown", &"death"]
## anim_events.json hit fractions: the frame the club lands.
const HIT := {&"attack_primary": 42, &"attack_heavy": 72}

var _out := ""
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("ankylo3d_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=ankylo3d_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[ankylo3d] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"ankylosaurus")
	var v: CreatureView = CreatureView.new()
	add_child(v)
	v.setup(def)
	v.apply_coloration(CreatureColoration.neutral())
	v.rotation.y = PI / 2.0  # head toward -X, left flank toward +Z (the side camera)
	print("[ankylo3d] glb=%s rig=%s" % [v.using_glb, v.rig != null])
	# The survivor stands a step ahead of its head, slightly toward the side camera, for scale.
	player.global_position = Vector3(-5.6, 0.1, 0.9)
	player.rotation.y = -PI / 2.0
	var side := Camera3D.new()
	side.fov = 38.0
	add_child(side)
	side.look_at_from_position(Vector3(-1.2, 2.0, 13.0), Vector3(-1.2, 1.0, 0.0))
	var tq := Camera3D.new()
	tq.fov = 38.0
	add_child(tq)
	tq.look_at_from_position(Vector3(7.0, 8.0, -9.0), Vector3(-1.0, 0.4, -0.6))
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
			print("[ankylo3d] MISSING clip %s" % clip)
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
				_caption.text = "ankylosaurus  %s %d%%%s   (survivor for scale)" % [clip, pct, "  HIT" if HIT.get(clip, -1) == pct else ""]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)
