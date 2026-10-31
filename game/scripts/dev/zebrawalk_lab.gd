extends Node3D
## ZEBRAWALK review shots, self-quitting (ankylo3d_lab adapted). One zebraceratops through the game's own CreatureView,
## the survivor beside it for scale; every locomotion clip posed at 0/25/50/75 % from a side camera (lit flank) and a
## front three-quarter (shows the strafes' sidesteps). Saves DIR/<clip>_<pct>_<cam>.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=zebrawalk_lab --out=DIR

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"walk_back", &"strafe_left", &"strafe_right"]
const PCTS: Array[int] = [0, 25, 50, 75]

var _out := ""
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("zebrawalk_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=zebrawalk_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[zebrawalk] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"zebraceratops")
	var v: CreatureView = CreatureView.new()
	add_child(v)
	v.setup(def)
	v.rotation.y = PI / 2.0  # head toward -X, left flank toward +Z (the side camera)
	print("[zebrawalk] glb=%s rig=%s" % [v.using_glb, v.rig != null])
	player.global_position = Vector3(-3.6, 0.1, -1.6)
	player.rotation.y = -PI / 2.0
	var side := Camera3D.new()
	side.fov = 38.0
	add_child(side)
	side.look_at_from_position(Vector3(-0.4, 1.4, 8.0), Vector3(-0.4, 0.8, 0.0))
	var front := Camera3D.new()
	front.fov = 38.0
	add_child(front)
	front.look_at_from_position(Vector3(-6.5, 2.2, 4.0), Vector3(0.0, 0.6, 0.0))
	_cams = {"side": side, "front": front}
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
			print("[zebrawalk] MISSING clip %s" % clip)
			continue
		for pct in PCTS:
			v.rig.skeleton.reset_bone_poses()  # the importer drops constant tracks; a paused seek would keep the last clip's tail
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * pct / 100.0, true)
			ap.pause()
			for cam_name in _cams:
				(_cams[cam_name] as Camera3D).current = true
				_caption.text = "zebraceratops  %s %d%%   (survivor for scale)" % [clip, pct]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)
