extends Node3D
## MEGANTLERS review shots, self-quitting: two megaloceros stags side by side with the survivor between them, the old
## Blender-built antlers (left in each shot) and the new Tripo rack (right). Poses: rest (idle), charge, death (last
## frame; the old stag plays its old death clip). Cameras: front, side, three-quarter. Saves DIR/<pose>_<cam>.png.
##   --before=res://..glb      an imported copy of the old stag GLB (its Antlers mesh is swapped onto the left stag)
##   --before-death=res://..glb  the old death clip (played on the left stag for the death shots)
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=megantlers_lab --out=DIR
##   --before=res://assets/creatures/megaloceros/work/old/stag_old.glb --before-death=res://assets/creatures/megaloceros/work/old/death_old.glb

const GAP := 5.6  ## each stag's distance from the survivor, across the camera (the racks span 7.6 m)
const POSES := [[&"rest", &"idle", 0.0, ["front", "side", "tq"]], [&"charge", &"charge", 0.3, ["side", "tq", "front"]],
	[&"death", &"death", 1.0, ["front", "tq", "side"]]]
## camera direction from the scene centre (horizontal), height, distance, look height
const CAMS := {"front": [Vector3(0, 0, -1), 4.0, 22.0, 2.6], "side": [Vector3(1, 0, 0), 3.4, 24.0, 2.6],
	"tq": [Vector3(-0.6, 0, -0.8), 9.0, 22.0, 2.2]}

var _out := ""
var _before := ""
var _before_death := ""
var _caption: Label

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--before="):
			_before = a.substr(9)
		elif a.begins_with("--before-death="):
			_before_death = a.substr(15)
	if _out == "" or _before == "":
		push_error("megantlers_lab: --out=DIR and --before=res://..glb are required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=megantlers_lab")
	_run.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[megantlers] saved %s/%s.png" % [_out, name])

func _stag(old: bool) -> CreatureView:
	var v := CreatureView.new()
	add_child(v)
	v.setup(Data.creature(&"megaloceros"), &"stag")
	if old:
		var ps := load(_before) as PackedScene
		var src := ps.instantiate()
		var from := src.find_children("Antlers*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var to := v.rig.mesh_root.find_children("Antlers*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		to.mesh = from.mesh  # same skeleton (build_rig.py), so the old skin binds as it did
		to.skin = from.skin
		v._rest_of.erase(to)  # setup() already cached the new rack's rest mesh for this instance
		v._originals.erase(to)
		src.free()
		if _before_death != "":
			var ap := v.rig.anim_player
			var a := RiggedModel.animation_from_glb(_before_death, ap, v.rig.mesh_root, &"death", "megantlers")
			if a:
				v.rig.library.add_animation(&"death_old", a)
	v.apply_coloration(CreatureColoration.neutral())
	return v

func _pose(v: CreatureView, clip: StringName, frac: float) -> void:
	var ap := v.rig.anim_player
	v.rig.skeleton.reset_bone_poses()
	ap.play(clip)
	ap.seek(ap.get_animation(clip).length * frac, true)
	ap.pause()

func _run() -> void:
	var kit := LabKit.build(self, 160.0)
	var player := kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	var old := _stag(true)
	var new := _stag(false)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	for _f in 8:
		await get_tree().process_frame
	for p in POSES:
		var old_clip: StringName = &"death_old" if p[1] == &"death" and old.rig.library.has_animation(&"death_old") else p[1]
		_pose(old, old_clip, p[2])
		_pose(new, p[1], p[2])
		for cam_name in p[3]:
			var c: Array = CAMS[cam_name]
			var dir: Vector3 = c[0]
			var right := Vector3.UP.cross(-dir).normalized() * -1.0  # screen right, looking along -dir
			# both stags face -Z; the old one on screen left, the new one on screen right, the survivor between
			old.global_position = -right * GAP
			new.global_position = right * GAP
			player.global_position = Vector3(0, 0.1, 0) + dir * 2.5
			player.rotation.y = atan2(dir.x, dir.z)
			cam.look_at_from_position(dir * c[2] + Vector3(0, c[1], 0), Vector3(0, c[3], 0))
			_caption.text = "megaloceros stag %s (%s)   left: OLD Blender antlers   right: NEW Tripo antlers   survivor 1.78 m" % [p[0], cam_name]
			for _f in 3:
				await get_tree().process_frame
			await _snap("%s_%s" % [p[0], cam_name])
	get_tree().quit(0)
