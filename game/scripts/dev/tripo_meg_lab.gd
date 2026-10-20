extends Node3D
## Throwaway lab for the Tripo megaloceros trial: renders side-view frames of the game's walk/run
## (megaloceros.glb + anim/*.glb through the creature code) and Tripo's preset:quadruped:walk,
## and prints foot-end world positions per sample so gait phase, lift and skating can be measured.
## Run: Godot --path game --resolution 1600x900 -- --lab=tripo_meg_lab --out=DIR

const TRIPO := "res://assets/creatures/megaloceros/tripo/walk.glb"
const FRAMES := 6  # rendered per clip
const SAMPLES := 48  # measured per clip

var _out := "user://tripo_meg"
var _cam: Camera3D
var _tag := Label.new()

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	WorldLighting.install(self, "temperate")
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.36, 0.5, 0.28)
	floor.material_override = fm
	add_child(floor)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 3.6
	add_child(_cam)
	_cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	_tag.position = Vector2(460, 160)
	_tag.add_theme_font_size_override("font_size", 40)
	_tag.add_theme_color_override("font_color", Color.BLACK)
	layer.add_child(_tag)
	_run.call_deferred()

func _run() -> void:
	# Old: the real creature, AnimationTree off so the lab can seek the player directly.
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.spawn(Data.creature(&"megaloceros"))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.label.visible = false
	c.anim.tree.active = false
	print("[tmeg] old anims=%s" % [c.anim.player.get_animation_list()])
	c.anim.set_process(false)
	c.rotation.y = 0.0
	# New: Tripo GLB as delivered, scaled to the game height.
	var t := (load(TRIPO) as PackedScene).instantiate() as Node3D
	add_child(t)
	var tsk := t.find_child("Skeleton3D", true, false) as Skeleton3D
	var tap := t.find_child("AnimationPlayer", true, false) as AnimationPlayer
	print("[tmeg] tripo anims=%s" % [tap.get_animation_list()])
	await _frames(3)
	var aabb := _aabb(t)
	print("[tmeg] tripo raw aabb=%s" % aabb)
	var s := c.def.height_meters / aabb.size.y
	t.scale = Vector3.ONE * s
	t.position = Vector3(30.0, 0.0, 0.0)  # mesh verts already start at y=0
	t.rotation.y = PI  # Tripo faces -Z; match the game deer facing
	var csk := c.view.rig.skeleton
	print("[tmeg] old aabb=%s" % _aabb(c))
	var ttrip := tap.get_animation_list()[0]
	var tripo_len := tap.get_animation(ttrip).length
	tap.get_animation(ttrip).loop_mode = Animation.LOOP_LINEAR
	# Pass list: label, player, clip, skeleton, x offset, playback rate.
	var passes := [
		["old_walk", c.anim.player, &"walk", csk, 0.0, 1.0],
		["old_run", c.anim.player, &"run", csk, 0.0, 1.0],
		["tripo_walk", tap, ttrip, tsk, 30.0, 1.0],
	]
	_cam.current = true
	_cam.look_at_from_position(Vector3(42.0, 1.3, 0.0), Vector3(30.0, 1.1, 0.0))
	c.visible = false
	await _frames(3)
	get_viewport().get_texture().get_image().save_png("%s/tripo_rest.png" % _out)
	print("[tmeg] tripo node xform %s skel %s" % [t.global_transform, tsk.global_transform])
	for p in passes:
		var ap: AnimationPlayer = p[1]
		c.visible = p[3] == csk
		t.visible = not c.visible
		var clip: StringName = p[2]
		var sk: Skeleton3D = p[3]
		var len := ap.get_animation(clip).length
		print("[tmeg] %s clip=%s len=%.3f" % [p[0], clip, len])
		ap.play(clip)
		ap.pause()
		var cx: float = p[4]
		_cam.current = true
		_cam.look_at_from_position(Vector3(cx + 12.0, 1.3, 0.0), Vector3(cx, 1.1, 0.0))
		var feet := _feet(sk)
		for i in SAMPLES:
			ap.seek(len * float(i) / float(SAMPLES), true)
			await _frames(1)
			var row: Array[String] = []
			for f in feet:
				var g := sk.global_transform * sk.get_bone_global_pose(f)
				row.append("%s=(%.3f,%.3f,%.3f)" % [sk.get_bone_name(f), g.origin.x, g.origin.y, g.origin.z])
			print("[tmeg-foot] %s i=%d %s" % [p[0], i, " ".join(row)])
		for i in FRAMES:
			ap.seek(len * float(i) / float(FRAMES), true)
			_tag.text = "%s  t=%.2f/%.2fs" % [p[0], len * float(i) / float(FRAMES), len]
			await _frames(3)
			get_viewport().get_texture().get_image().save_png("%s/%s_%d.png" % [_out, p[0], i])
	_sheet(["old_walk", "tripo_walk", "old_run"])
	print("[tmeg] done")
	get_tree().quit()

## Contact sheet: one row per pass, FRAMES crops each, at half size.
func _sheet(rows: Array) -> void:
	var crop := Rect2i(440, 150, 720, 630)
	var cw := crop.size.x / 2
	var ch := crop.size.y / 2
	var sheet := Image.create(cw * FRAMES, ch * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for i in FRAMES:
			var img := Image.load_from_file("%s/%s_%d.png" % [_out, rows[r], i])
			img.convert(Image.FORMAT_RGBA8)
			var part := img.get_region(crop)
			part.resize(cw, ch)
			sheet.blit_rect(part, Rect2i(0, 0, cw, ch), Vector2i(i * cw, r * ch))
	sheet.save_png("%s/../compare.png" % _out)

## Leg chain ends: old rig *LowLeg*_end bones; Tripo rig deepest bone of each *Limb* chain.
func _feet(sk: Skeleton3D) -> Array[int]:
	var out: Array[int] = []
	for b in sk.get_bone_count():
		var n := sk.get_bone_name(b)
		if n.contains("LowLeg") and n.ends_with("_end"):
			out.append(b)
		elif n.contains("Limb"):
			var leaf := true
			for ch in sk.get_bone_children(b):
				if sk.get_bone_name(ch).contains("Limb"):
					leaf = false
			if leaf:
				out.append(b)
	return out

func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw
