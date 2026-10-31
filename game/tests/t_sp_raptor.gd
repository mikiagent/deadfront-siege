extends SceneTree
## SP-RAPTOR: the Raptor (owner: "black and gold is the original raptor") draws its rigged Tripo model (no box
## placeholder) with every listed clip, it is 3.5 m tall and about 7.5 m long, its feet stay on the floor in the
## standing clips, each hit comes from its part at the hit frame (the jaws, the sickle foot), the brain flares its crest
## and pounces, pins a survivor under the foot and bites twice, the sickle slash misses a survivor the foot cannot reach
## (centre reach would have hit), the colour morphs draw their own albedo (the mouth keeps its gum red), and the spawn
## tables put it on temperate/tropical islands with nothing falling through.
## Run: Godot --headless --path game --script res://tests/t_sp_raptor.gd  -> "[t_sp_raptor] PASS", exit 0.

const ID := &"raptor"
const FEET := ["BackFoot.L", "BackFoot.R", "BackFoot.L_end", "BackFoot.R_end"]
const GROUND_TOL := 0.08  ## m: the lowest foot point stays this close to its rest height in standing clips
## clip -> [hit fracs, bone]: anim_events hit fracs and pipeline.hit_parts
const HITS := {&"attack_primary": [[0.42], "Head"], &"attack_heavy": [[0.72], "BackFoot.R"], &"pounce": [[0.7], "Head"], &"pin_stab": [[0.38, 0.74], "Head"]}
const MORPHS := ["black_crimson", "green", "rust", "slate"]

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
	print("[t_sp_raptor] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_slash_part()
	await _test_pounce_pin()
	await _test_flare_pounce()
	await _test_morphs()
	if failures.is_empty():
		print("[t_sp_raptor] PASS")
		quit(0)
	else:
		print("[t_sp_raptor] FAIL %d" % failures.size())
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
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/raptor/raptor.glb"), "raptor data and GLB exist")
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
	_expect(clips.size() >= 22, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/raptor/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Tail5"] + FEET:
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
	_expect(absf(aabb.size.y - def.height_meters) < 0.15, "height %.2f m (data %.2f)" % [aabb.size.y, def.height_meters])
	_expect(long_side > 6.5 and long_side < 8.5, "%.1f m long: between deinonychus (4.8 m) and utahraptor (11.2 m)" % long_side)
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in FEET:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	# Standing clips: some foot point stays on the floor every sampled frame (the slash and the pin stand on one leg).
	# (walk/walk_back lift the heel and toe bones mid-stride; their skin contact is gated by tools/gait/check_raptor.py)
	for clip in [&"idle", &"strafe_left", &"strafe_right", &"attack_heavy", &"pin_stab", &"hit_react", &"alert", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 24:
			ap.seek(a.length * float(k) / 24.0, true)
			var lo := INF
			for b in FEET:
				lo = minf(lo, _bone_pos(sk, b).y)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL, "%s: a foot stays on the floor (worst %.3f m off rest)" % [clip, worst])
	# Each hit's part, at its hit frame, is out in front of the body (the jaws, the sickle foot driven forward).
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	sk.reset_bone_poses()
	var head_rest := _bone_pos(sk, "Head", true)
	var foot_rest := _bone_pos(sk, "BackFoot.R", true)
	for clip in HITS:
		for frac in HITS[clip][0]:
			sk.reset_bone_poses()
			ap.play(clip)
			var a := ap.get_animation(clip)
			ap.seek(a.length * float(frac), true)
			var p := _bone_pos(sk, str(HITS[clip][1]))
			var ahead: float = (p - origin).dot(fwd)
			_expect(ahead > 1.5, "%s@%.2f: %s %.2f m ahead of the body centre" % [clip, frac, HITS[clip][1], ahead])
			if clip == &"pin_stab":
				_expect(p.y < head_rest.y - 0.5, "pin_stab@%.2f: the jaws come down on the pinned prey (head %.2f m, rest %.2f m)" % [frac, p.y, head_rest.y])
			if clip == &"attack_heavy":
				_expect((p - foot_rest).dot(fwd) > 1.0, "the slash drives the sickle foot %.2f m forward of its print" % (p - foot_rest).dot(fwd))
	view.free()

## The species' rows in islands.json: temperate/tropical islands, and the model means nothing falls through.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect(islands.has("temperate_35") and islands.has("tropical_40"), "raptor spawn rows on temperate_35 and tropical_40 (%s)" % [islands])
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(raptor): its rows spawn raptors")
	_expect(cdef.eligible(ID, [ID, &"deinonychus"]) == ID, "eligible(raptor) is the raptor itself")
	var def = data.creature(ID)
	_expect(def.tameable and def.tamed_role.has(&"mount") and ResourceLoader.exists("res://assets/creatures/raptor/mount/saddle.glb"), "tameable, rideable, with a saddle")

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
	box.size = Vector3(140, 1, 140)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	return [host, player]

func _raptor(host: Node3D, at: Vector3, variant: StringName = &"") -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID), variant)
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## The sickle slash lands from the foot: in front it hits; beside the hindquarters (inside the centre reach, out of
## the foot's) it misses.
func _test_slash_part() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _raptor(host, Vector3(0, 0.1, -3.0))
	_expect(c.brain != null and str(c.brain.get_script().resource_path).ends_with("tactical_brain.gd"), "a raptor runs the TacticalBrain (the deinonychus profile)")
	_expect(c.brain.tac.get("point_blank", []).has("heavy") and c.brain.tac.get("pin", false), "its tactics add the slash and the pin")
	c.brain.attack_target = player
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # no turning toward her during the held windup: the foot strikes where it faces
	var parts: Array = []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append(c.part_hit(clip, player)))
	# Beside the rump first (a landed slash kills a fresh survivor): inside the centre reach, out of the foot's.
	var back: Vector3 = c.global_transform.basis.z.normalized()
	var right: Vector3 = c.global_transform.basis.x.normalized()
	var front: Vector3 = player.global_position
	player.global_position = c.global_position + back * 2.4 + right * 2.0 + Vector3(0, 0.8, 0)
	var flat: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(flat < c.brain.reach_to(player), "the rump spot is inside the centre reach (%.2f < %.2f m)" % [flat, c.brain.reach_to(player)])
	var hp0: float = player.vitals.health
	c.brain._set_state(&"attack")
	c.anim.play_clip(&"attack_heavy")
	for _f in 240:  # the clip holds its windup (anim_events windup_hold) before the slash
		await physics_frame
	_expect(parts == [false] and is_equal_approx(player.vitals.health, hp0), "the slash misses a survivor beside the rump: the foot does not reach (hp %.0f -> %.0f, foot %s)" % [hp0, player.vitals.health, parts])
	player.global_position = front
	parts.clear()
	c.brain._set_state(&"attack")
	c.anim.play_clip(&"attack_heavy")
	for _f in 240:
		await physics_frame
	_expect(parts == [true] and player.vitals.health < hp0, "the sickle slash lands in front (hp %.0f -> %.0f, foot %s)" % [hp0, player.vitals.health, parts])
	host.free()

## Pounce from 9 m: it leaps, lands, pins her under the foot (Pinned, laid down, held in front), bites twice, lets go.
func _test_pounce_pin() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _raptor(host, Vector3(0, 0.1, -9.0))
	var b = c.brain
	b.tac = b.tac.duplicate()
	b.tac["pounce_overshoot_chance"] = 0.0  # the sail-past miss is its own (random) branch
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var bites := [0]
	var pinned_seen := [false]
	var held_d := [99.0]
	var down := [false]
	c.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"pin_stab":
			bites[0] += 1
			held_d[0] = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length())
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: landed[clip] = int(landed.get(clip, 0)) + 1)
	root.get_node("Game").god_mode = true  # the pounce alone can kill a fresh survivor; the pin needs her alive
	b._start_pounce()
	_expect(b.state == &"pounce", "the pounce starts (state %s)" % b.state)
	for _f in 480:
		await physics_frame
		if player.statuses.has(&"pinned"):
			pinned_seen[0] = true
			down[0] = down[0] or player.anim.current_clip in [&"knockdown", &"pinned"]
		if seen.has(&"pin") and b.state != &"pin" and bites[0] >= 2:
			break
	_expect(seen.has(&"leap"), "it leaps")
	_expect(seen.has(&"pin"), "a landed pounce pins the survivor")
	_expect(pinned_seen[0], "the survivor is Pinned")
	_expect(down[0], "she goes down into the pinned pose (PINFEEL)")
	_expect(held_d[0] > 2.0 and held_d[0] < 4.5, "she is held under the foot and the jaws at the bites (%.2f m from its centre)" % held_d[0])
	_expect(bites[0] == 2, "pin_stab bites twice (%d)" % bites[0])
	_expect(int(landed.get(&"pounce", 0)) == 1 and int(landed.get(&"pin_stab", 0)) == 2, "the pounce and both pin bites land from the jaws (%s)" % landed)
	_expect(not player.statuses.has(&"pinned") and b.state != &"pin", "it lets go when the bites are done (state %s)" % b.state)
	root.get_node("Game").god_mode = false
	host.free()

## The crest-flare sequence: it stops and displays (the alert clip: arms wide, screech), then pounces.
func _test_flare_pounce() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _raptor(host, Vector3(0, 0.1, -9.0))
	var b = c.brain
	b.tac = b.tac.duplicate()
	var flare: Array = (b.tac.get("sequences", []) as Array).filter(func(r: Dictionary) -> bool: return r.get("name") == "flare_pounce")
	_expect(flare.size() == 1, "the flare_pounce sequence is in its tactics")
	b.tac["sequences"] = flare
	b.attack_target = player
	b._combat_memory_left = 30.0
	var order: Array = []
	var alert_seen := [false]
	b.tactic.connect(func(k: StringName) -> void: order.append(k))
	root.get_node("Game").god_mode = true
	_expect(b._start_sequence(b._flat_dist(player)), "the flare_pounce sequence starts at 9 m")
	for _f in 240:
		await physics_frame
		alert_seen[0] = alert_seen[0] or c.anim.current_clip == &"alert"
		if order.has(&"leap"):
			break
	_expect(order.size() > 0 and order[0] == &"display", "it opens with the crest-flare display (%s)" % [order])
	_expect(alert_seen[0], "the display plays the alert clip")
	_expect(order.has(&"leap"), "the display leads into the pounce (%s)" % [order])
	root.get_node("Game").god_mode = false
	host.free()

## Each colour morph draws its own albedo; the GLB's black/gold is a morph too; wild spawns spread over them.
func _test_morphs() -> void:
	var def = data.creature(ID)
	var rows: Dictionary = CV.model_variants(def)
	_expect(rows.has("black_gold") and MORPHS.all(func(m: String) -> bool: return rows.has(m)), "five morphs: black_gold + %s" % [MORPHS])
	var picked := {}
	for i in 60:
		picked[CV.pick_variant(def, "raptor@%d" % i)] = true
	_expect(picked.size() == 5, "wild spawns spread over every morph (%s)" % [picked.keys()])
	var panel: GDScript = load("res://scripts/dev/lab_spawn_panel.gd")
	_expect(panel.variants_of(ID).size() == 5, "the lab's Body button steps through the morphs (%s)" % [panel.variants_of(ID)])
	var a := await _arena()
	var host: Node3D = a[0]
	var x := -12.0
	for m in MORPHS:
		var c = _raptor(host, Vector3(x, 0.1, 6.0), StringName(m))
		x += 6.0
		var tex := _albedo(c.view)
		_expect(c.variant == StringName(m) and tex != null and tex.resource_path.ends_with("raptor_%s_albedo.jpg" % m), "%s draws raptor_%s_albedo.jpg (%s)" % [m, m, tex.resource_path if tex else "none"])
		_expect(_untextured_surfaces(c.view) > 0, "%s: the mouth bag keeps its own colour (no hide texture)" % m)
	var base = _raptor(host, Vector3(x, 0.1, 6.0), &"black_gold")
	var btex := _albedo(base.view)
	_expect(btex != null and not btex.resource_path.contains("_albedo.jpg"), "black_gold draws the GLB's own albedo")
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

func _untextured_surfaces(v: Node) -> int:
	var n := 0
	for mi in v.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter("albedo_tex") == null:
				n += 1
			elif mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture == null:
				n += 1
	return n
