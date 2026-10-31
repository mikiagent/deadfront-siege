extends Node3D
## MEGAJOUST review shots, self-quitting.
##   --before=res://..glb  an imported copy of the old stag GLB: antlers_before_<cam>.png, then the
##                     current stag: antlers_after_<cam>.png (front, side, three-quarter, close on the head)
##   joust fights      each species in --species=a,b (default megaloceros stag, megaloceros doe, woolly_rhino) fights a
##                     standing survivor (GOD on) for --passes passes; a trail is dropped every 0.12 s, coloured by beat
##                     (yellow tell, red pass, cyan run off, blue wheel); joust_<name>_top.png from above, plus a chase
##                     shot in the tell and mid-wheel (joust_<name>_tell.png, joust_<name>_wheel.png)
## Run windowed off-screen: Godot --path game --position 6000,3000 -- --skip-charcreate --lab=megajoust_lab --out=DIR [--before=..]

const BEAT_COLOURS := {&"tell": Color(1.0, 0.85, 0.1), &"charge": Color(0.9, 0.15, 0.1), &"run_off": Color(0.1, 0.85, 0.9), &"wheel": Color(0.15, 0.35, 1.0), &"other": Color(0.6, 0.6, 0.6)}

var _out := ""
var _before := ""
var _passes := 3
var _species: Array = ["megaloceros:stag", "megaloceros:doe", "woolly_rhino:"]
var _caption: Label
var _player: Player

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--before="):
			_before = a.substr(9)
		elif a.begins_with("--passes="):
			_passes = int(a.substr(9))
		elif a.begins_with("--species="):
			_species = a.substr(10).split(",")
	if _out == "":
		push_error("megajoust_lab: --out=DIR is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	print("[boot] lab=megajoust_lab")
	_run.call_deferred()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("[megajoust] saved %s/%s.png" % [_out, name])

func _run() -> void:
	var kit := LabKit.build(self, 160.0)
	_player = kit["player"] as Player
	(kit["ui"] as CanvasLayer).visible = false
	(kit["cam"] as Camera3D).current = false
	var layer := CanvasLayer.new()
	add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24, 16)
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_caption)
	await _antlers()
	Game.god_mode = true
	for row in _species:
		var parts := str(row).split(":")
		if parts[0] == "":
			continue
		await _joust(StringName(parts[0]), StringName(parts[1]) if parts.size() > 1 else &"")
	Game.god_mode = false
	get_tree().quit(0)

## The stag at rest, before (the old GLB) and after (the current one), from the sheet's angles.
func _antlers() -> void:
	_player.global_position = Vector3(-60, 0.1, -60)
	var cams := {
		"front": [Vector3(0, 4.2, -15.0), Vector3(0, 4.0, 0)],
		"side": [Vector3(15.0, 3.6, 0.6), Vector3(0, 3.3, 0.6)],
		"tq": [Vector3(-9.0, 7.5, -10.0), Vector3(0, 4.2, -0.5)],
		"head": [Vector3(-4.5, 6.2, -6.5), Vector3(0, 4.8, -1.2)],
	}
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	for which in ["before", "after"]:
		var node: Node3D
		if which == "before":
			if _before == "":
				continue
			# an imported copy (res://, the game's own importer): GLTFDocument at runtime misplaced the skinned mesh
			var ps := load(_before) as PackedScene
			if ps == null:
				push_error("megajoust_lab: cannot load %s" % _before)
				continue
			node = ps.instantiate() as Node3D
			add_child(node)
			node.rotation.y = PI  # the GLB faces +Z; the game turns it to face -Z, as CreatureView does
		else:
			var v := CreatureView.new()
			add_child(v)
			v.setup(Data.creature(&"megaloceros"), &"stag")
			v.apply_coloration(CreatureColoration.neutral())
			node = v
		for _f in 6:
			await get_tree().process_frame
		for cam_name in cams:
			cam.look_at_from_position(cams[cam_name][0], cams[cam_name][1])
			_caption.text = "megaloceros stag antlers %s  (%s)" % [which.to_upper(), cam_name]
			await get_tree().process_frame
			await _snap("antlers_%s_%s" % [which, cam_name])
		node.queue_free()
		await get_tree().process_frame
	cam.queue_free()

func _beat(c: Creature) -> StringName:
	var b := c.brain as JoustBrain
	if b == null:
		return &"other"
	if b.state == &"charge":
		return &"tell" if c.anim.current_clip == &"charge_crouch" or c.anim.current_clip == &"alert" else &"charge"
	if b.state == &"circle":
		return b.phase if b.phase in [&"run_off", &"wheel"] else &"other"
	return &"other"

func _dot(at: Vector3, col: Color, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3(at.x, 0.4, at.z)
	parent.add_child(mi)

func _joust(sp: StringName, variant: StringName) -> void:
	var label := "%s %s" % [sp, variant] if variant != &"" else str(sp)
	_player.global_position = Vector3(0, 0.2, 0)
	_player.velocity = Vector3.ZERO
	var c: Creature = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	add_child(c)
	c.global_position = Vector3(0, 0.2, -18.0)
	c.genetics = CreatureGenetics.new()  # size 1, as t_megajoust
	c.spawn(Data.creature(sp), variant, 0, null, 0, &"aggressive")
	c.look_at(Vector3(0, 0.2, 0), Vector3.UP)
	await get_tree().physics_frame
	var b := c.brain as JoustBrain
	b.attack_target = _player
	b._provoked_until = b._now_s() + 999.0
	b.on_aggro(_player)
	var trail := Node3D.new()
	add_child(trail)
	var chase := Camera3D.new()
	chase.fov = 50.0
	add_child(chase)
	var top := Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = 70.0
	add_child(top)
	top.look_at_from_position(Vector3(0, 60, 0.01), Vector3.ZERO)
	top.current = true
	var shot_tell := false
	var tell_t := 0.0
	var shot_wheel := false
	var t := 0.0
	var next_dot := 0.0
	while t < 60.0 and b.passes < _passes and is_instance_valid(c):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		_player.vitals.health = _player.vitals.effective_max_health()
		var beat := _beat(c)
		if t >= next_dot:
			next_dot = t + 0.12
			_dot(c.global_position, BEAT_COLOURS[beat], trail)
		tell_t = tell_t + get_physics_process_delta_time() if c.anim.current_clip == &"charge_crouch" else 0.0
		var want_tell := beat == &"tell" and not shot_tell and tell_t > 0.45  # antlers down, mid-scrape
		var want_wheel := beat == &"wheel" and not shot_wheel and b._circle_t > 1.2
		if want_tell or want_wheel:
			var fwd := -c.global_basis.z
			var side := Vector3(-fwd.z, 0, fwd.x)
			chase.look_at_from_position(c.global_position + side * 12.0 - fwd * 4.0 + Vector3(0, 5.5, 0), c.global_position + Vector3(0, 2.5, 0))
			chase.current = true
			_caption.text = "%s  %s" % [label, "the tell (charge_crouch)" if want_tell else "the wheel (%s)" % c.anim.current_clip]
			await _snap("joust_%s_%s" % [label.replace(" ", "_"), "tell" if want_tell else "wheel"])
			top.current = true
			if want_tell:
				shot_tell = true
			else:
				shot_wheel = true
	_caption.text = "%s  joust from above: %d passes in %.0f s  (yellow tell, red pass, cyan run off, blue wheel; survivor at the centre)" % [label, b.passes, t]
	await get_tree().process_frame
	await _snap("joust_%s_top" % label.replace(" ", "_"))
	c.queue_free()
	trail.queue_free()
	chase.queue_free()
	top.queue_free()
	await get_tree().process_frame
