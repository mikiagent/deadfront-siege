extends SceneTree
## SP-TARBOSAURUS: the tarbosaurus draws its rigged Tripo model (no box placeholder) with every listed clip, it is
## 6.8 m tall and long and lean, its feet stay on the floor in the standing clips, the Jaw bone exists, each hit comes
## from its part at the hit frame (the jaws out ahead, the tail whip out behind), the brain is the TacticalBrain on its
## own tactics, it stalks in on the low creep, the burst lands and pins the survivor under its foot (pin_foot), the
## head-whip bite lands, the tail whip fires on a survivor behind it and lands, and the spawn row stands.
## Run: Godot --headless --path game --script res://tests/t_sp_tarbosaurus.gd  -> "[t_sp_tarbosaurus] PASS", exit 0.

const ID := &"tarbosaurus"
const GROUND_TOL := 0.08  ## m: the lowest toe stays this close to its rest height in standing clips (6.8 m animal)
## clip -> [hit frac, bone, ahead (+1) or behind (-1)]: anim_events hit fracs and pipeline.hit_parts
const HITS := {&"attack_primary": [0.42, "Jaw", 1], &"attack_heavy": [0.72, "Jaw", 1], &"pounce": [0.7, "Jaw", 1], &"kick": [0.45, "Tail6", -1]}

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
	print("[t_sp_tarbosaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_bite()
	await _test_burst_pin()
	await _test_tail_whip()
	await _test_stalk()
	if failures.is_empty():
		print("[t_sp_tarbosaurus] PASS")
		quit(0)
	else:
		print("[t_sp_tarbosaurus] FAIL %d" % failures.size())
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
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/tarbosaurus/tarbosaurus.glb"), "tarbosaurus data and GLB exist")
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
	_expect(clips.size() >= 18, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/tarbosaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Tail6", "Toe.L", "Toe.R", "Metatarsal.R"]:
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
	_expect(absf(aabb.size.y - def.height_meters) < 0.3, "height %.2f m (data %.2f)" % [aabb.size.y, def.height_meters])
	_expect(long_side > 2.2 * aabb.size.y, "long and lean: %.1f m long, %.1f m tall" % [long_side, aabb.size.y])
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := minf(_bone_pos(sk, "Toe.L", true).y, _bone_pos(sk, "Toe.R", true).y)
	for clip in [&"idle", &"walk", &"stalk", &"strafe_left", &"walk_back", &"attack_primary", &"attack_heavy", &"kick", &"hit_react", &"alert", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		for k in 24:
			ap.seek(a.length * float(k) / 24.0, true)
			worst = maxf(worst, absf(minf(_bone_pos(sk, "Toe.L").y, _bone_pos(sk, "Toe.R").y) - rest))
		_expect(worst <= GROUND_TOL, "%s: a foot stays on the floor (worst %.3f m off rest)" % [clip, worst])
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	for clip in HITS:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		ap.seek(a.length * float(HITS[clip][0]), true)
		var p := _bone_pos(sk, str(HITS[clip][1]))
		# the jaws are out ahead; the whipping tail swings wide across behind (measured flat from the centre, behind the hips)
		var off := p - origin
		var along: float = off.dot(fwd) if HITS[clip][2] > 0 else (Vector2(off.x, off.z).length() if off.dot(fwd) < 0.0 else 0.0)
		_expect(along > 5.0, "%s: %s %.2f m %s the body centre at the hit frame" % [clip, HITS[clip][1], along, "ahead of" if HITS[clip][2] > 0 else "out behind"])
	view.free()

func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect(islands.has("tundra_55"), "tarbosaurus spawn row on tundra_55 (%s)" % [islands])
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(tarbosaurus): spawns no longer fall through")
	_expect(cdef.eligible(ID, [ID, &"megaloceros"]) == ID, "eligible(tarbosaurus) is tarbosaurus itself")
	_expect(load("res://scripts/dev/lab_spawn_panel.gd").listed_species(false).has(ID), "listed in the fight lab picker")

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

func _tarbo(host: Node3D, at: Vector3) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## The slashing bite lands from the jaws on a survivor in front.
func _test_bite() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _tarbo(host, Vector3(0, 0.1, -7.0))
	_expect(c.brain != null and str(c.brain.get_script().resource_path).ends_with("tactical_brain.gd"), "a tarbosaurus runs the TacticalBrain (its own tactics)")
	_expect(c.brain.tac.get("stalk", false) and c.brain.tac.get("point_blank", []).has("kick"), "its tactics: stalk, and the tail whip point blank")
	c.brain.attack_target = player
	c.brain._set_state(&"attack")
	var hp0: float = player.vitals.health
	var parts: Array = []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append(c.part_hit(clip, player)))
	root.get_node("Game").god_mode = false
	c.anim.play_clip(&"attack_primary")
	for _f in 90:
		await physics_frame
	_expect(player.vitals.health < hp0, "the head-whip bite lands in front (hp %.0f -> %.0f, part %s)" % [hp0, player.vitals.health, parts])
	host.free()

## The burst from 11 m: crouch, bound, clamp; a landed burst is an attack_heavy hit, so the survivor is Pinned and the
## tarbosaurus plants its foot on her (pin_foot), then lets her go when Pinned runs out.
func _test_burst_pin() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	var c = _tarbo(host, Vector3(0, 0.1, -11.0))
	var b = c.brain
	b.tac = b.tac.duplicate()
	b.tac["pounce_overshoot_chance"] = 0.0
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: landed[clip] = true)
	var pinned := [false]
	var foot := [false]
	var down := [false]
	root.get_node("Game").god_mode = true  # the burst alone can kill a fresh survivor; the pin needs her alive
	b._start_pounce()
	_expect(b.state == &"pounce", "the burst starts (state %s)" % b.state)
	var released := false
	for _f in 900:
		await physics_frame
		if player.statuses.has(&"pinned"):
			pinned[0] = true
			down[0] = down[0] or player.anim.current_clip in [&"knockdown", &"pinned"]
			foot[0] = foot[0] or (c.pin_victim == player and c.anim.current_clip == &"pin_foot")
		elif pinned[0] and c.pin_victim == null:
			released = true
			break
	_expect(seen.has(&"leap"), "it bounds in")
	_expect(landed.has(&"pounce"), "the burst lands from the jaws")
	_expect(pinned[0], "the survivor is Pinned")
	_expect(down[0], "she goes down into the pinned pose (PINFEEL)")
	_expect(foot[0], "the tarbosaurus pins her under its foot (pin_foot)")
	_expect(released, "it lets go when Pinned runs out")
	root.get_node("Game").god_mode = false
	host.free()

## A survivor behind it, point blank: the tail whip (kick slot) fires and lands from the tail.
func _test_tail_whip() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _tarbo(host, Vector3(0, 0.1, -5.0))
	c.look_at(Vector3(0, 0.1, -20.0), Vector3.UP)  # facing away: she is behind it
	var b = c.brain
	b.attack_target = player
	var d: float = b._flat_dist(player)
	_expect(b._prey_behind(), "the survivor is in its rear arc")
	_expect(b.attack_available(&"kick", d), "the tail whip is available point blank behind (%.1f m, reach %.1f m)" % [d, b.reach_to(player)])
	var hp0: float = player.vitals.health
	var parts: Array = []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append([clip, c.part_hit(clip, player)]))
	_expect(b._strike(d, ["kick"]), "it strikes with the tail whip")
	_expect(c.anim.current_clip == &"kick", "the kick clip (tail whip) plays (%s)" % c.anim.current_clip)
	for _f in 120:
		await physics_frame
	_expect(player.vitals.health < hp0, "the tail whip lands from the tail (hp %.0f -> %.0f, %s)" % [hp0, player.vitals.health, parts])
	host.free()

## Coming in from far off it creeps on the stalk clip, slower than its walk.
func _test_stalk() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _tarbo(host, Vector3(0, 0.1, -24.0))
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
