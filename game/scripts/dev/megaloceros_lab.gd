extends Node3D
## SP-MEGALOCEROS review shots, self-quitting (trikeland_lab re-aimed): one body (--variant=stag|doe), the survivor a
## step ahead of its head for scale; every clip at 30 % and 60 % (the attacks also at their hit frame) from the side
## and a high three-quarter from the front left. Saves DIR/<variant>_<clip>_<pct>_<cam>.png.
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=megaloceros_lab --variant=stag --out=DIR

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"charge", &"strafe_left", &"walk_back", &"alert",
	&"attack_primary", &"attack_heavy", &"kick", &"hit_react", &"feed", &"sleep", &"knockdown", &"death"]
## anim_events.json hit_frac: antler hook / forehoof strike, rear-up stomp, rear kick.
const HIT := {&"attack_primary": 42, &"attack_heavy": 72, &"kick": 45}

var _out := ""
var _variant := "stag"
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		if a.begins_with("--variant="):
			_variant = a.substr(10)
	if _out == "":
		push_error("megaloceros_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=megaloceros_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[megaloceros] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"megaloceros")
	var v: CreatureView = CreatureView.new()
	add_child(v)
	v.setup(def, StringName(_variant))
	v.apply_coloration(CreatureColoration.neutral())
	v.rotation.y = PI / 2.0  # head toward -X, left flank toward +Z (the side camera)
	print("[megaloceros] glb=%s rig=%s" % [v.using_glb, v.rig != null])
	# The survivor stands a step ahead of its head, slightly toward the side camera, for scale.
	player.global_position = Vector3(-4.6, 0.1, 1.4)
	player.rotation.y = -PI / 2.0
	var side := Camera3D.new()
	side.fov = 38.0
	add_child(side)
	side.look_at_from_position(Vector3(-0.8, 3.0, 19.0), Vector3(-0.8, 2.6, 0.0))
	var tq := Camera3D.new()
	tq.fov = 38.0
	add_child(tq)
	tq.look_at_from_position(Vector3(-13.0, 9.0, 11.0), Vector3(-1.0, 2.0, 0.0))
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
			print("[megaloceros] MISSING clip %s" % clip)
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
				_caption.text = "megaloceros %s  %s %d%%%s   (survivor 1.78 m)" % [_variant, clip, pct, "  HIT" if HIT.get(clip, -1) == pct else ""]
				await get_tree().process_frame
				await _snap("%s_%s_%d_%s" % [_variant, clip, pct, cam_name])
	get_tree().quit(0)
