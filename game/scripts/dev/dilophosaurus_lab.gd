extends Node3D
## SP-DILOPHOSAURUS review shots, self-quitting (smilodon_lab adapted). One dilophosaurus with the survivor standing
## ahead of its head for scale; every clip posed at 30 % and 60 % (the attacks and signature moves also at their hit
## frames; the spit shows a stand-in glob just out of the jaws) from two cameras: side (lit flank) and a high
## three-quarter from the front right. --alpha draws the alpha skin. Saves DIR/<clip>_<pct>_<cam>.png. Run windowed off-screen:
## Godot --path game --position 6000,3000 -- --skip-charcreate --lab=dilophosaurus_lab --out=DIR [--alpha] [--clips=a,b]

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"walk_back", &"strafe_left", &"strafe_right",
	&"alert", &"attack_primary", &"attack_heavy", &"spit", &"pounce", &"hit_react", &"feed", &"sleep", &"knockdown", &"death"]
## anim_events.json hit fractions: the snap, the rake, the spit leaving the jaws (and the glob a beat later), the slash.
const HIT := {&"attack_primary": [42], &"attack_heavy": [72], &"spit": [62, 68], &"pounce": [55, 70]}

var _out := ""
var _caption: Label
var _cams: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	if _out == "":
		push_error("dilophosaurus_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=dilophosaurus_lab")
	_sheet.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("[dilophosaurus] saved %s/%s.png" % [_out, name])

func _sheet() -> void:
	var kit := LabKit.build(self, 80.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var def: CreatureDef = Data.creature(&"dilophosaurus")
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
	print("[dilophosaurus] glb=%s rig=%s alpha=%s" % [v.using_glb, v.rig != null, alpha])
	# The survivor stands a step ahead of its head, slightly toward the side camera, for scale.
	player.global_position = Vector3(-5.2, 0.1, 1.2)
	player.rotation.y = -PI / 2.0
	var side := Camera3D.new()
	side.fov = 38.0
	add_child(side)
	side.look_at_from_position(Vector3(-1.2, 2.2, 17.0), Vector3(-1.2, 1.6, 0.0))
	var tq := Camera3D.new()
	tq.fov = 38.0
	add_child(tq)
	tq.look_at_from_position(Vector3(-11.0, 6.5, 10.0), Vector3(-2.0, 1.4, 0.0))
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
	# a stand-in venom glob (VenomSpit's look) for the spit frames after the release
	var glob := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.16
	sph.height = 0.32
	glob.mesh = sph
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.85, 0.18)
	gm.emission_enabled = true
	gm.emission = Color(0.45, 0.75, 0.1)
	gm.emission_energy_multiplier = 1.4
	glob.material_override = gm
	glob.visible = false
	add_child(glob)
	for clip in want:
		if not ap.has_animation(clip):
			print("[dilophosaurus] MISSING clip %s" % clip)
			continue
		var pcts: Array = [30, 60]
		if HIT.has(clip):
			pcts.append_array(HIT[clip])
		for pct in pcts:
			v.rig.skeleton.reset_bone_poses()  # the importer drops constant tracks; a paused seek would keep the last clip's tail
			ap.play(clip)
			ap.seek(ap.get_animation(clip).length * pct / 100.0, true)
			ap.pause()
			glob.visible = clip == &"spit" and pct >= 68
			if glob.visible:
				var sk := v.rig.skeleton
				var jaw: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Jaw")).origin
				glob.global_position = jaw + Vector3(-1.4, -0.2, 0.25)
			for cam_name in _cams:
				(_cams[cam_name] as Camera3D).current = true
				_caption.text = "dilophosaurus%s  %s %d%%%s   (survivor for scale)" % [" ALPHA" if alpha else "", clip, pct, "  HIT" if pct in HIT.get(clip, []) else ""]
				await get_tree().process_frame
				await _snap("%s_%d_%s" % [clip, pct, cam_name])
	get_tree().quit(0)
