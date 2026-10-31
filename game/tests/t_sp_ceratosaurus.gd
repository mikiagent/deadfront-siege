extends SceneTree
## SP-CERATOSAURUS: the ceratosaurus draws its rigged Tripo model (no box placeholder) with every listed clip and a Jaw,
## it is 4 m tall, its feet stay on their prints in the standing clips, each hit comes from its part at the hit frame
## (jaws, nose horn, tail), and in a live fight: the slashing bite lands and makes her bleed, the nose-horn gore lands
## without Bleed, the tail swipe is picked and lands when she is behind it, and from a water's edge it ambushes with the
## lunge (pounce) and lands it; away from water it does not lurk. An alpha wears the camo skin; the spawn tables put it
## on swamp and tropical islands with nothing falling through.
## Run: Godot --headless --path game --script res://tests/t_sp_ceratosaurus.gd  -> "[t_sp_ceratosaurus] PASS", exit 0.

const ID := &"ceratosaurus"
const TOES := ["Toe.L", "Toe.R"]
const GROUND_TOL := 0.08  ## m (4 m animal): the lowest toe stays this close to its rest height in standing clips
## clip -> [hit frac, bone, min metres ahead of the body centre]
const HITS := {&"attack_primary": [0.42, "Jaw", 3.5], &"attack_heavy": [0.72, "Head", 3.0], &"pounce": [0.7, "Jaw", 3.5]}

var failures: Array[String] = []
var _started := false
var data: Node
var CV: GDScript

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	CV = load("res://scripts/creatures/creature_view.gd")
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_sp_ceratosaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_bite_bleeds()
	await _test_gore()
	await _test_tail_swipe()
	await _test_water_lunge()
	await _test_alpha()
	if failures.is_empty():
		print("[t_sp_ceratosaurus] PASS")
		quit(0)
	else:
		print("[t_sp_ceratosaurus] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _bone_pos(sk: Skeleton3D, b: String, rest: bool = false) -> Vector3:
	var i := sk.find_bone(b)
	return sk.global_transform * (sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i)).origin

func _test_view() -> void:
	var def = data.creature(ID)
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/ceratosaurus/ceratosaurus.glb"), "ceratosaurus data and GLB exist")
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null, "draws the rigged GLB")
	_expect(_boxes(view) == 0, "no box/cylinder placeholder meshes")
	if view.rig == null:
		view.free()
		return
	var clips: Array = def.pipeline.get("clips", [])
	_expect(clips.size() >= 16, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/ceratosaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Tail6", "Metatarsal.L", "Toe.R"]:
		_expect(sk.find_bone(b) >= 0, "bone %s in the rig" % b)
	var aabb := AABB()
	var first := true
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	var long_side := maxf(aabb.size.x, aabb.size.z)
	_expect(absf(aabb.size.y - def.height_meters) < 0.2, "height %.2f m (data %.2f)" % [aabb.size.y, def.height_meters])
	_expect(long_side > 8.5 and long_side < 11.0, "%.1f m nose to tail (a ~6 m animal at the house 1.6x)" % long_side)
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	for clip in [&"idle", &"walk", &"strafe_left", &"walk_back", &"alert", &"attack_primary", &"attack_heavy", &"kick", &"hit_react", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 24:
			ap.seek(a.length * float(k) / 24.0, true)
			var lo := INF
			for b in TOES:
				lo = minf(lo, _bone_pos(sk, b).y)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL, "%s: a foot stays on the floor (worst %.3f m off rest)" % [clip, worst])
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	for clip in HITS:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		ap.seek(a.length * float(HITS[clip][0]), true)
		var ahead: float = (_bone_pos(sk, str(HITS[clip][1])) - origin).dot(fwd)
		_expect(ahead > float(HITS[clip][2]), "%s: %s %.2f m ahead of the body centre at the hit frame" % [clip, HITS[clip][1], ahead])
	# The tail swipe: at its hit frame the tail sweeps across behind it (fast sideways, still out behind).
	sk.reset_bone_poses()
	ap.play(&"kick")
	var kl := ap.get_animation(&"kick").length
	var side_x: Vector3 = (view as Node3D).global_transform.basis.x
	ap.seek(kl * 0.40, true)
	var s0: float = (_bone_pos(sk, "Tail5") - origin).dot(side_x)
	ap.seek(kl * 0.45, true)
	var p1 := _bone_pos(sk, "Tail5") - origin
	var sweep: float = absf(p1.dot(side_x) - s0) / (kl * 0.05)
	_expect(sweep > 4.0 and -p1.dot(fwd) > 2.0, "kick: the tail sweeps across behind it at the hit (%.1f m/s sideways, %.2f m behind)" % [sweep, -p1.dot(fwd)])
	view.free()

## The species' rows in islands.json: swamp and tropical islands, and the model means nothing falls through.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect("swamp_55" in islands and "tropical_40" in islands, "ceratosaurus spawn rows on swamp_55 and tropical_40 (%s)" % [islands])
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(ceratosaurus): spawns do not fall through")
	_expect(cdef.eligible(ID, [ID, &"deinonychus"]) == ID, "eligible(ceratosaurus) is ceratosaurus itself")
	_expect(str(data.creature(ID).climate) == "swamp", "climate swamp")
	var lab: GDScript = load("res://scripts/dev/lab_spawn_panel.gd")
	_expect(ID in lab.all_species(), "the creature lab's SPAWN list has it")

func _find_rows(n: Variant, out: Array, island: String) -> void:
	if n is Dictionary:
		var d := n as Dictionary
		var here := str(d.get("id", island))
		if str(d.get("species", "")) == str(ID):
			out.append(island)
		for k in d:
			_find_rows(d[k], out, here)
	elif n is Array:
		for x in n:
			_find_rows(x, out, island)

func _arena() -> Array:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	return [host, player]

func _cerato(host: Node3D, at: Vector3, alpha: bool = false) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	c.alpha_spawn = alpha
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## In front at bite range: the slashing bite lands from the jaws and she bleeds.
func _test_bite_bleeds() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cerato(host, Vector3(0, 0.1, -4.6))
	_expect(c.brain != null and str(c.brain.get_script().resource_path).ends_with("tactical_brain.gd"), "a ceratosaurus runs the TacticalBrain (its own tactics block)")
	root.get_node("Game").god_mode = true
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void: landed[clip] = m)
	var picked := []
	b.attack_chosen.connect(func(m: StringName, _d: float) -> void: picked.append(m))
	b._beat_since_basic = true
	_expect(b._strike(b._flat_dist(player), ["bite"]), "the slashing bite is available in front")
	var parts := []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append([clip, c.part_hit(clip, player)]))
	for _f in 90:
		await physics_frame
	_expect(picked.has(&"bite"), "bite picked (%s)" % [picked])
	_expect(parts.size() > 0 and parts[0][1], "the jaws reach her at the hit (%s)" % [parts])
	_expect(player.statuses.has(&"bleed"), "the slashing bite makes her bleed")
	_expect(landed.has(&"attack_primary"), "the bite lands (god mode keeps her HP; the hit and its status still land)")
	root.get_node("Game").god_mode = false
	host.free()

## The gore: the attack_heavy clip at point blank in front, landing from the head, with no Bleed (status_clips).
func _test_gore() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cerato(host, Vector3(0, 0.1, -4.6))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void: landed[clip] = m)
	var hp0: float = player.vitals.health
	_expect(b._strike(b._flat_dist(player), ["kick", "heavy", "bite"]), "point blank in front picks a move")
	_expect(c.anim.current_clip == &"attack_heavy", "in front, the point-blank order skips the tail swipe and gores (%s)" % c.anim.current_clip)
	for _f in 120:
		await physics_frame
	_expect(landed.has(&"attack_heavy"), "the nose-horn gore lands (x%.1f)" % float(landed.get(&"attack_heavy", 0.0)))
	_expect(player.vitals.health < hp0, "the gore hurts (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	_expect(not player.statuses.has(&"bleed"), "the gore does not apply Bleed (bite only)")
	host.free()

## Behind it at point blank: the tail swipe is picked and the tail hits her.
func _test_tail_swipe() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cerato(host, Vector3(0, 0.1, 20.0))
	c.look_at(Vector3(0, 0.1, 40.0), Vector3.UP)  # facing away from her
	await physics_frame
	var back: Vector3 = c.global_transform.basis.z.normalized()
	var right: Vector3 = c.global_transform.basis.x.normalized()
	var b = c.brain
	var spot: Vector3 = c.global_position + back * 3.8 + right * -0.6
	player.global_position = Vector3(spot.x, 0.9, spot.z)
	await physics_frame
	b.attack_target = player
	b._combat_memory_left = 30.0
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void: landed[clip] = m)
	var parts := []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append([clip, c.part_hit(clip, player)]))
	var hp0: float = player.vitals.health
	_expect(b._strike(b._flat_dist(player), ["kick", "heavy", "bite"]), "point blank behind it picks a move")
	_expect(c.anim.current_clip == &"kick", "behind it, it swings the tail (%s)" % c.anim.current_clip)
	for _f in 90:
		await physics_frame
	_expect(landed.has(&"kick"), "the tail swipe lands (parts %s)" % [parts])
	_expect(player.vitals.health < hp0, "the tail hurts (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	host.free()

## Lurking on a bank: she walks within ambush range and it opens with the lunge out of the water's edge, which lands.
## Without water (the lab, no island) it does not ambush.
func _test_water_lunge() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cerato(host, Vector3(0, 0.1, -9.0))
	var b = c.brain
	_expect(not b._ambushes(), "no island water: it does not lurk (hunts in the open)")
	b._water_checked = true
	b.water_cover = c.global_position
	_expect(b._ambushes() and b._find_cover() == c.global_position, "with a water's edge it lurks there")
	b.tac = b.tac.duplicate()
	b.tac["pounce_overshoot_chance"] = 0.0
	b._set_state(&"roam")
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void: landed[clip] = m)
	root.get_node("Game").god_mode = true
	for _f in 360:
		if b.state == &"roam":
			b._scan()
		await physics_frame
		if landed.has(&"pounce"):
			break
	_expect(seen.has(&"ambush"), "it springs the ambush on her (%s)" % [seen.keys()])
	_expect(seen.has(&"pounce") and seen.has(&"leap"), "it opens with the lunge: windup, then the surge")
	_expect(landed.has(&"pounce"), "the lunge lands from the jaws (x%.1f)" % float(landed.get(&"pounce", 0.0)))
	root.get_node("Game").god_mode = false
	host.free()

## An alpha wears the camo skin; a regular animal keeps the GLB's.
func _test_alpha() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var reg = _cerato(host, Vector3(14, 0.1, 0))
	var alp = _cerato(host, Vector3(-14, 0.1, 0), true)
	_expect(alp.is_alpha() and alp.variant == &"alpha", "an alpha spawns with the alpha variant (%s)" % alp.variant)
	_expect(reg.variant != &"alpha", "a regular ceratosaurus is not given the alpha skin (%s)" % reg.variant)
	var tex := _albedo(alp.view)
	_expect(tex != null and tex.resource_path.ends_with("ceratosaurus_alpha_albedo.jpg"), "the alpha draws ceratosaurus_alpha_albedo.jpg (%s)" % (tex.resource_path if tex else "none"))
	var rtex := _albedo(reg.view)
	_expect(rtex != null and not rtex.resource_path.ends_with("ceratosaurus_alpha_albedo.jpg"), "the regular draws its own albedo")
	host.free()

func _albedo(v: Node) -> Texture2D:
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var mat := m.get_active_material(0)
		if mat is ShaderMaterial:
			return (mat as ShaderMaterial).get_shader_parameter("albedo_tex") as Texture2D
		if mat is StandardMaterial3D:
			return (mat as StandardMaterial3D).albedo_texture
	return null
