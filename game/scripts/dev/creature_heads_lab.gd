extends Node3D
## Head close-ups of every creature, for the "hole in the head" check (CREATUREFIX). Each species is
## spawned once per mode and shot from four sides at the game camera's 35 deg pitch, tiled 2x2:
##   <shot-dir>/<species>_<mode>.png, plus <shot-dir>/contact_<mode>.png with every species.
## Modes bisect the shared draw path without touching it:
##   base     as the game draws it
##   nocull   the colour shader forced to cull_disabled (what it ships with since CREATUREFIX)
##   cullback the colour shader forced to cull_back (what it shipped with before CREATUREFIX)
##   nocolor  the authored GLB mesh and materials back (no colour shader, no rest mesh)
##   norest   colour shader kept, authored mesh back (no rest-mesh rebuild)
##   noeyes   eyeshine dots hidden
##   diff     neutral colours, one frozen pose shot twice: with the pre-fix cull_back shader
##            (<species>_before.png) and as the game draws it now (<species>_after.png); prints
##            the pixels that differ (back faces the skin hid, i.e. holes) and marks them in
##            <species>_diffmask.png
##
##   godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=creature_heads_lab --shot-dir=/tmp/heads [--species=velociraptor,utahraptor] [--modes=base,nocull]

const TILE := Vector2i(400, 225)
const WATCHDOG_S := 110.0

var shot_dir := "/tmp/creature_heads"
var species: Array[StringName] = []
var modes: Array[String] = ["base"]
## --clip=attack_primary@0.3: play this clip and freeze diff shots this many seconds in.
var clip: StringName = &""
var clip_at := 0.3
var _cam: Camera3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			shot_dir = a.substr(11)
		elif a.begins_with("--species="):
			for s in a.substr(10).split(","):
				species.append(StringName(s))
		elif a.begins_with("--clip="):
			var parts := a.substr(7).split("@")
			clip = StringName(parts[0])
			if parts.size() > 1:
				clip_at = float(parts[1])
		elif a.begins_with("--modes="):
			modes.clear()
			for m in a.substr(8).split(","):
				modes.append(m)
	if species.is_empty():
		for f in DirAccess.get_files_at("res://data/creatures"):
			var id := f.get_basename()
			if f.ends_with(".json") and ResourceLoader.exists("res://assets/creatures/%s/%s.glb" % [id, id]):
				species.append(StringName(id))
	Game.debug_overlay = false
	Game.day_length_seconds = 1.0e9
	Game.time_of_day = 0.45
	var kit := LabKit.build(self, 60.0)
	for k in ["player", "nav"]:
		(kit[k] as Node).queue_free()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	TouchControls.visible = false
	DirAccess.make_dir_recursive_absolute(shot_dir)
	get_tree().create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("[heads] FAIL watchdog")
		get_tree().quit(1))
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.current = true
	add_child(_cam)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	for mode in modes:
		var sheet := Image.create(TILE.x * 2 * 4, TILE.y * 2 * int(ceil(species.size() / 4.0)), false, Image.FORMAT_RGB8)
		for i in species.size():
			var img := await _shoot(species[i], mode)
			img.save_png("%s/%s_%s.png" % [shot_dir, species[i], "after" if mode == "diff" else mode])
			if img.get_height() == TILE.y * 2:
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % 4) * TILE.x * 2, (i / 4) * TILE.y * 2))
		sheet.resize(sheet.get_width() / 2, sheet.get_height() / 2, Image.INTERPOLATE_BILINEAR)
		sheet.save_png("%s/contact_%s.png" % [shot_dir, mode])
	print("[heads] done %d species x %s -> %s" % [species.size(), modes, shot_dir])
	get_tree().quit(0)

func _shoot(id: StringName, mode: String) -> Image:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.spawn(Data.creature(id))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	if c.label:
		c.label.visible = false
	if mode != "diff":
		_apply_mode(c, mode)
	await get_tree().create_timer(0.3).timeout
	if mode == "diff":
		if clip != &"":
			c.anim.play_clip(clip)
			await get_tree().create_timer(clip_at).timeout
		c.process_mode = Node.PROCESS_MODE_DISABLED  # one frozen pose for both shots
		await get_tree().create_timer(0.2).timeout
		c.view.apply_coloration(CreatureColoration.neutral())
		_apply_mode(c, "cullback")
		var drawn := await _views(c)
		for sm in c.view._skin_mats:
			sm.shader = CreatureView.COLOR_SHADER
		var both := await _views(c)
		var n := 0
		var mark := both.duplicate() as Image
		for y in drawn.get_height():
			for x in drawn.get_width():
				var a := drawn.get_pixel(x, y)
				var b := both.get_pixel(x, y)
				if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
					n += 1
					mark.set_pixel(x, y, Color.MAGENTA)
		print("[heads] diff %s: %d px differ between cull_back (before) and the shipped shader (after)" % [id, n])
		drawn.save_png("%s/%s_before.png" % [shot_dir, id])
		mark.save_png("%s/%s_diffmask.png" % [shot_dir, id])
		c.queue_free()
		await get_tree().process_frame
		return both
	var out := await _views(c)
	c.queue_free()
	await get_tree().process_frame
	return out

## Four sides at the game camera's 35 deg pitch, tiled 2x2.
func _views(c: Creature) -> Image:
	var head := _head(c)
	var r := maxf(0.35, c.def.height_meters * 0.3)
	_cam.size = r * 2.4
	var out := Image.create(TILE.x * 2, TILE.y * 2, false, Image.FORMAT_RGB8)
	for k in 4:
		var yaw := deg_to_rad(45.0 + 90.0 * k)
		var dir := Vector3(sin(yaw) * cos(deg_to_rad(35.264)), sin(deg_to_rad(35.264)), cos(yaw) * cos(deg_to_rad(35.264)))
		_cam.global_position = head + dir * r * 6.0
		_cam.look_at(head, Vector3.UP)
		for _f in 3:
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(TILE.x, TILE.y, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((k % 2) * TILE.x, (k / 2) * TILE.y))
	return out

## Head bone origin when the rig has one; otherwise the front-top of the body bounds.
func _head(c: Creature) -> Vector3:
	if c.view.rig and c.view.rig.skeleton:
		var sk: Skeleton3D = c.view.rig.skeleton
		for b in sk.get_bone_count():
			if sk.get_bone_name(b).to_lower() == "head":
				return (sk.global_transform * sk.get_bone_global_pose(b)).origin
	return c.global_position + Vector3(0, c.def.height_meters * 0.62, -c.def.real_length_m * 0.28)

func _apply_mode(c: Creature, mode: String) -> void:
	var v := c.view
	match mode:
		"nocull", "cullback":
			var sh := Shader.new()
			var code := CreatureView.COLOR_SHADER.code
			sh.code = code.replace("cull_back,", "cull_disabled,") if mode == "nocull" else code.replace("cull_disabled,", "cull_back,")
			for sm in v._skin_mats:
				sm.shader = sh
		"nocolor", "norest":
			for mi in v._rest_of.keys():
				var rest: ArrayMesh = v._rest_of[mi]
				for orig in CreatureView._rest_meshes.keys():
					if CreatureView._rest_meshes[orig] == rest:
						(mi as MeshInstance3D).mesh = orig
				if mode == "nocolor":
					var originals: Array = v._originals.get(mi, [])
					for i in originals.size():
						(mi as MeshInstance3D).set_surface_override_material(i, originals[i])
		"noeyes":
			var e := v.get_node_or_null("Eyes")
			if e:
				e.queue_free()
