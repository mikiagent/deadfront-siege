extends SceneTree
## SP-SMILODON: the smilodon draws its rigged Tripo model (no box placeholder) with every listed clip, it is about 2 m
## tall, its feet stay on the floor in the standing clips, the jaw and sabre (Head) bones exist, each hit comes from its
## part (the swiping paw, the sabres) at the hit frame, the brain stalks in, pounces, pins and stabs a survivor, the
## swipe misses a survivor the paw cannot reach (centre reach would have hit), an alpha wears the brown skin, and the
## spawn tables put it on tundra islands with nothing falling through.
## Run: Godot --headless --path game --script res://tests/t_sp_smilodon.gd  -> "[t_sp_smilodon] PASS", exit 0.

const ID := &"smilodon"
const FEET := ["BackFoot.L", "BackFoot.R", "FrontFoot.L", "FrontFoot.R"]
## The cat stands on its toes: the Foot bones run hock/wrist -> toe tips, so ground contact is the Foot_end (toe tip).
const TOES := ["BackFoot.L_end", "BackFoot.R_end", "FrontFoot.L_end", "FrontFoot.R_end"]
const GROUND_TOL := 0.06  ## m: the lowest toe tip stays this close to its rest height in standing clips
## clip -> [hit frac, bone]: anim_events hit fracs and pipeline.hit_bones
const HITS := {&"attack_primary": [0.42, "FrontFoot.R"], &"attack_heavy": [0.72, "Head"], &"pounce": [0.7, "Head"], &"pin_stab": [0.38, "Head"]}

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
	print("[t_sp_smilodon] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_swipe_part()
	await _test_pounce_pin()
	await _test_stalk()
	await _test_alpha()
	if failures.is_empty():
		print("[t_sp_smilodon] PASS")
		quit(0)
	else:
		print("[t_sp_smilodon] FAIL %d" % failures.size())
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
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/smilodon/smilodon.glb"), "smilodon data and GLB exist")
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
	_expect(clips.size() >= 17, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/smilodon/anim/%s.glb" % clip)
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
	_expect(long_side > 1.5 * aabb.size.y and long_side < 2.5 * aabb.size.y, "a cat's proportions: %.1f m long, %.1f m tall" % [long_side, aabb.size.y])
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	for clip in [&"idle", &"walk", &"run", &"stalk", &"strafe_left", &"walk_back", &"attack_primary", &"attack_heavy", &"pin_stab", &"hit_react", &"alert", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var offs: Array[float] = []
		for k in 24:
			ap.seek(a.length * float(k) / 24.0, true)
			var lo := INF
			for b in TOES:
				lo = minf(lo, _bone_pos(sk, b).y)
			offs.append(absf(lo - rest))
		offs.sort()
		# The gallop has a flight phase (every foot up for ~8 % of the stride): a fifth of its samples may be airborne.
		var worst: float = offs[int(offs.size() * 0.8) - 1] if clip == &"run" else offs[-1]
		_expect(worst <= GROUND_TOL, "%s: a toe stays on the floor (worst %.3f m off rest)" % [clip, worst])
	# Each hit's part, at its hit frame, is out in front of the body (the paw raked forward, the sabres driven down).
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	sk.reset_bone_poses()
	var head_rest := _bone_pos(sk, "Head", true)
	for clip in HITS:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		ap.seek(a.length * float(HITS[clip][0]), true)
		var p := _bone_pos(sk, str(HITS[clip][1]))
		var ahead: float = (p - origin).dot(fwd)
		_expect(ahead > 1.2, "%s: %s %.2f m ahead of the body centre at the hit frame" % [clip, HITS[clip][1], ahead])
		if HITS[clip][1] == "Head":
			_expect(p.y < head_rest.y - 0.2, "%s: the sabres are driven down (head %.2f m, rest %.2f m)" % [clip, p.y, head_rest.y])
	view.free()

## The species' rows in islands.json: tundra islands, and the model means nothing falls through to another species.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect(islands.size() >= 3, "smilodon spawn rows in islands.json (%d)" % islands.size())
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(smilodon): spawns no longer fall through")
	_expect(cdef.eligible(ID, [ID, &"megaloceros"]) == ID, "eligible(smilodon) is smilodon itself")
	_expect(str(data.creature(ID).climate) == "tundra", "climate tundra")

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
	box.size = Vector3(120, 1, 120)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	return [host, player]

func _cat(host: Node3D, at: Vector3, alpha: bool = false) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	c.alpha_spawn = alpha
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## The swipe lands from the paw: in front of the paw it hits; beside the hindquarters (inside the old centre reach,
## out of the paw's) it misses.
func _test_swipe_part() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cat(host, Vector3(0, 0.1, -2.6))
	_expect(c.brain != null and str(c.brain.get_script().resource_path).ends_with("tactical_brain.gd"), "a smilodon runs the TacticalBrain (saber_cat tactics)")
	c.brain.attack_target = player
	c.brain._set_state(&"attack")  # mid-swing: the brain waits for the clip instead of alerting and charging
	var hp0: float = player.vitals.health
	var parts: Array = []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append([c.hit_part_point(clip), c.part_reaches(clip, player)]))
	c.anim.play_clip(&"attack_primary")
	for _f in 90:
		await physics_frame
	_expect(player.vitals.health < hp0, "the forepaw swipe lands in front (hp %.0f -> %.0f, paw %s)" % [hp0, player.vitals.health, parts])
	# Beside the rump: 2.3 m from the centre (centre reach would hit), 3 m from the swiping paw.
	var back: Vector3 = c.global_transform.basis.z.normalized()
	var right: Vector3 = c.global_transform.basis.x.normalized()
	player.global_position = c.global_position + back * 1.4 + right * 1.8 + Vector3(0, 0.8, 0)
	var flat: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(flat < c.brain.reach_to(player), "the rump spot is inside the centre reach (%.2f < %.2f m)" % [flat, c.brain.reach_to(player)])
	var hp1: float = player.vitals.health
	for _f in 10:
		await physics_frame
	c.brain._set_state(&"attack")
	c.anim.play_clip(&"attack_primary")
	for _f in 90:
		await physics_frame
	_expect(is_equal_approx(player.vitals.health, hp1), "the swipe misses a survivor beside the rump: the paw does not reach (hp %.0f -> %.0f)" % [hp1, player.vitals.health])
	host.free()

## Pounce from 7 m: it leaps, lands, pins (Pinned + knocked down, held in front), stabs twice, then lets go.
func _test_pounce_pin() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _cat(host, Vector3(0, 0.1, -7.0))
	var b = c.brain
	b.tac = b.tac.duplicate()
	b.tac["pounce_overshoot_chance"] = 0.0  # the 15 % sail-past miss is its own (random) branch
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var stabs := [0]
	var pinned_seen := [false]
	var held_d := [99.0]
	c.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"pin_stab":
			stabs[0] += 1)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: landed[clip] = int(landed.get(clip, 0)) + 1)
	root.get_node("Game").god_mode = true  # a 100 HP survivor dies to the pounce alone; the pin needs her alive
	b._start_pounce()
	_expect(b.state == &"pounce", "the pounce starts (state %s)" % b.state)
	for _f in 420:
		await physics_frame
		if player.statuses.has(&"pinned"):
			pinned_seen[0] = true
			held_d[0] = minf(held_d[0], Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length())
		if seen.has(&"pin") and b.state != &"pin" and stabs[0] >= 2:
			break
	_expect(seen.has(&"leap"), "it leaps")
	_expect(seen.has(&"pin"), "a landed pounce pins the survivor")
	_expect(pinned_seen[0], "the survivor is Pinned")
	_expect(held_d[0] < 3.0, "she is held under the forepaws (%.2f m from its centre)" % held_d[0])
	_expect(stabs[0] == 2, "pin_stab drives the sabres in twice (%d)" % stabs[0])
	_expect(int(landed.get(&"pounce", 0)) == 1 and int(landed.get(&"pin_stab", 0)) == 2, "the pounce and both stabs land from the Head bone (%s)" % landed)
	_expect(not player.statuses.has(&"pinned") and b.state != &"pin", "it lets go when the stabs are done (state %s)" % b.state)
	root.get_node("Game").god_mode = false
	host.free()

## Coming in from far off it creeps on the stalk clip, slower than its walk.
func _test_stalk() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _cat(host, Vector3(0, 0.1, -18.0))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._set_state(&"approach")
	var stalked := [0]
	var speeds: Array[float] = []
	for _f in 120:
		await physics_frame
		if c.anim.current_clip == &"stalk":
			stalked[0] += 1
			speeds.append(Vector2(c.velocity.x, c.velocity.z).length())
	_expect(stalked[0] > 30, "it approaches on the stalk clip (%d frames)" % stalked[0])
	var mean := 0.0
	for s in speeds:
		mean += s / maxf(1.0, speeds.size())
	_expect(mean > 0.2 and mean < c.walk_mps(c.move_speed_mps()), "stalk speed %.2f m/s, under its walk %.2f m/s" % [mean, c.walk_mps(c.move_speed_mps())])
	host.free()

## An alpha wears the brown-maned skin; a regular animal keeps the GLB's.
func _test_alpha() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var reg = _cat(host, Vector3(10, 0.1, 0))
	var alp = _cat(host, Vector3(-10, 0.1, 0), true)
	_expect(alp.is_alpha() and alp.variant == &"alpha", "an alpha spawns with the alpha variant (%s)" % alp.variant)
	_expect(reg.variant != &"alpha", "a regular smilodon is not given the alpha skin (%s)" % reg.variant)
	var tex := _albedo(alp.view)
	_expect(tex != null and tex.resource_path.ends_with("smilodon_alpha_albedo.jpg"), "the alpha draws smilodon_alpha_albedo.jpg (%s)" % (tex.resource_path if tex else "none"))
	var rtex := _albedo(reg.view)
	_expect(rtex != null and not rtex.resource_path.ends_with("smilodon_alpha_albedo.jpg"), "the regular draws its own albedo")
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
