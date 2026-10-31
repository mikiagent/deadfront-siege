extends SceneTree
## SP-MAJUNGASAURUS: the majungasaurus draws its rigged Tripo model (no box placeholder) with every listed clip, it is
## about 5 m tall and twice as long, its toes stay on the floor in the standing clips, each move's part is where the
## hit lands (the jaws ahead and down at survivor height, the skull ahead in the headbutt, the tail behind and low in
## the swipe, the jaws low in front in the grab), a landed crushing bite GRABS (Pinned, held at the jaws, shaken twice,
## then released), the bite misses a survivor behind it while the tail swipe hits her there, the opportunist brain
## commits only now and then on healthy prey and every time on prey under 50 %, and the spawn tables put it on savannah.
## Run: Godot --headless --path game --script res://tests/t_sp_majungasaurus.gd  -> "[t_sp_majungasaurus] PASS", exit 0.

const ID := &"majungasaurus"
const TOES := ["Toe.L", "Toe.R"]
const GROUND_TOL := 0.12  ## m on a 5 m animal: the lowest toe stays this close to its rest height in standing clips
## clip -> [hit frac, bone]: anim_events hit fracs and pipeline.hit_parts
const HITS := {&"attack_primary": [0.42, "Jaw"], &"attack_heavy": [0.72, "Head"], &"kick": [0.45, "Tail4"], &"pin_stab": [0.38, "Jaw"]}

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
	print("[t_sp_majungasaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_bite_grab()
	await _test_behind()
	await _test_headbutt()
	await _test_opportunist()
	if failures.is_empty():
		print("[t_sp_majungasaurus] PASS")
		quit(0)
	else:
		print("[t_sp_majungasaurus] FAIL %d" % failures.size())
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
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/majungasaurus/majungasaurus.glb"), "majungasaurus data and GLB exist")
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
	_expect(clips.size() == 17, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		var authored := ResourceLoader.exists("res://assets/creatures/majungasaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Tail4", "Arm.L", "Thigh.L", "Metatarsal.R"] + TOES:
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
	_expect(long_side > 9.0 and long_side < 12.0, "about 10.4 m long (%.1f m): 6.5 m real x the house 1.6" % long_side)
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	for clip in [&"idle", &"walk", &"run", &"charge", &"strafe_left", &"walk_back", &"attack_primary", &"attack_heavy", &"kick", &"pin_stab", &"hit_react", &"alert", &"feed"]:
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
		var worst: float = offs[int(offs.size() * 0.8) - 1] if clip in [&"run", &"charge"] else offs[-1]
		_expect(worst <= GROUND_TOL, "%s: a toe stays on the floor (worst %.3f m off rest)" % [clip, worst])
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	for clip in HITS:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		ap.seek(a.length * float(HITS[clip][0]), true)
		var p := _bone_pos(sk, str(HITS[clip][1]))
		var ahead: float = (p - origin).dot(fwd)
		var side: float = (p - origin).dot((view as Node3D).global_transform.basis.x.normalized())
		print("[t_sp_majungasaurus] %s %s at the hit: %.2f m ahead, %.2f m right, %.2f m up" % [clip, HITS[clip][1], ahead, side, p.y - origin.y])
		if clip == &"kick":
			_expect(ahead < -1.5 and absf(side) < 1.0 and p.y - origin.y < 2.6, "kick: the tail sweeps behind it, low (%.2f m ahead, %.2f m up)" % [ahead, p.y - origin.y])
		elif clip == &"pin_stab":
			_expect(ahead > 2.5 and p.y - origin.y < 1.7, "pin_stab: the jaws are clamped low in front (%.2f m ahead, %.2f m up)" % [ahead, p.y - origin.y])
		else:
			# the headbutt's Head bone is the skull joint: the knob it drives is the skull top, ~1 m lower once tucked
			_expect(ahead > 2.5 and p.y - origin.y < (3.4 if clip == &"attack_heavy" else 2.8), "%s: %s ahead and down at a survivor's height (%.2f m ahead, %.2f m up)" % [clip, HITS[clip][1], ahead, p.y - origin.y])
	view.free()

## The species' rows in islands.json: savannah islands, and the model means nothing falls through to another species.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect(islands.size() >= 2, "majungasaurus spawn rows in islands.json (%d)" % islands.size())
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(majungasaurus): spawns no longer fall through")
	_expect(cdef.eligible(ID, [ID, &"styracosaurus"]) == ID, "eligible(majungasaurus) is majungasaurus itself")
	_expect(str(data.creature(ID).climate) == "savannah", "climate savannah")

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

func _majunga(host: Node3D, at: Vector3) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## A crushing bite that lands holds on: she is Pinned and held at its jaws while pin_stab shakes her twice (both hits
## land from the jaws), then it lets go.
func _test_bite_grab() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED  # her auto-tackle (a canon gap: it fires while Pinned) staggers it out of the grab
	var c = _majunga(host, Vector3(0, 0.1, -4.0))
	var b = c.brain
	_expect(b != null and str(b.get_script().resource_path).ends_with("tactical_brain.gd"), "a majungasaurus runs the TacticalBrain (opportunist tactics)")
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: landed[clip] = int(landed.get(clip, 0)) + 1)
	var pinned_seen := [false]
	var jaw_gap := [99.0]
	root.get_node("Game").god_mode = true  # the grab needs her alive through both shakes
	var hp0: float = player.vitals.health
	b._bite()
	var sk: Skeleton3D = c.view.rig.skeleton
	for _f in 360:
		await physics_frame
		if player.statuses.has(&"pinned"):
			pinned_seen[0] = true
			var j := _bone_pos(sk, "Jaw")
			jaw_gap[0] = minf(jaw_gap[0], Vector2(player.global_position.x - j.x, player.global_position.z - j.z).length())
		if seen.has(&"pin") and b.state != &"pin" and int(landed.get(&"pin_stab", 0)) >= 2:
			break
	_expect(player.vitals.health < hp0 or int(landed.get(&"attack_primary", 0)) >= 1, "the crushing bite lands (%s)" % landed)
	_expect(seen.has(&"pin") and pinned_seen[0], "the landed bite grabs: she is Pinned")
	_expect(jaw_gap[0] < 2.0, "she is held at its jaws (%.2f m from the Jaw bone, flat)" % jaw_gap[0])
	_expect(int(landed.get(&"pin_stab", 0)) == 2, "pin_stab shakes her twice, both landing from the jaws (%s)" % landed)
	_expect(not player.statuses.has(&"pinned") and b.state != &"pin", "it lets go when the shakes are done (state %s)" % b.state)
	_expect(b.cooldown_left(&"pin") > 0.0, "the grab goes on its cooldown (%.1f s)" % b.cooldown_left(&"pin"))
	root.get_node("Game").god_mode = false
	host.free()

## Behind it, by the hindquarters: the bite misses (the jaws cannot reach) and the low tail swipe hits.
func _test_behind() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _majunga(host, Vector3(0, 0.1, -4.0))
	var b = c.brain
	b.attack_target = player
	b.process_mode = Node.PROCESS_MODE_DISABLED  # posed by hand: the brain would turn to face her
	await physics_frame
	var back: Vector3 = c.global_transform.basis.z.normalized()
	var right: Vector3 = c.global_transform.basis.x.normalized()
	player.global_position = c.global_position + back * 3.0 + right * 0.8 + Vector3(0, 0.8, 0)
	_expect(b._prey_behind(), "she is in its rear arc")
	var hp0: float = player.vitals.health
	b._set_state(&"attack")
	c.anim.play_clip(&"attack_primary")
	for _f in 80:
		await physics_frame
	_expect(is_equal_approx(player.vitals.health, hp0), "the bite misses a survivor behind it (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	var flat: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(b.attack_available(&"kick", flat), "the tail swipe is available with her behind it (%.2f m)" % flat)
	b._kick()
	for _f in 90:
		await physics_frame
	_expect(player.vitals.health < hp0, "the low tail swipe hits her behind it (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	host.free()

## Point blank in front: the skull-knob headbutt lands from the Head bone.
func _test_headbutt() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _majunga(host, Vector3(0, 0.1, -4.2))
	var b = c.brain
	b.attack_target = player
	var parts := []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append(c.part_hit(clip, player)))
	var hp0: float = player.vitals.health
	_expect(b.attack_available(&"heavy", 4.2), "the headbutt is available point blank in front")
	b._heavy()
	for _f in 110:
		await physics_frame
	_expect(player.vitals.health < hp0 and parts == [true], "the headbutt lands from the skull (hp %.0f -> %.0f, part %s)" % [hp0, player.vitals.health, parts])
	host.free()

## The opportunist: on a healthy survivor a ready rush goes only now and then (healthy_commit_chance); under 50 %
## health every ready pick commits, with the weak_prey cooldowns.
func _test_opportunist() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _majunga(host, Vector3(0, 0.1, -12.0))
	var b = c.brain
	b.attack_target = player
	b.rng.seed = 7
	var healthy := 0
	for i in 200:
		b._cd.clear()
		b._seq = []
		if b._start_sequence(12.0):
			healthy += 1
		b._set_state(&"circle")
	_expect(healthy > 25 and healthy < 80, "healthy prey: it commits on %d of 200 ready picks (about a quarter)" % healthy)
	player.vitals.health = player.vitals.effective_max_health() * 0.4
	_expect("weak_prey" in b._active_mods(), "under 50 %% health the weak_prey block is on")
	var weak := 0
	for i in 50:
		b._cd.clear()
		b._seq = []
		if b._start_sequence(12.0):
			weak += 1
		b._set_state(&"circle")
	_expect(weak == 50, "weak prey: it commits on every ready pick (%d of 50)" % weak)
	b._start_cd(&"charge")
	_expect(b.cooldown_left(&"charge") < 9.0 * 0.6, "weak prey: the rush comes back sooner (charge cooldown %.1f s)" % b.cooldown_left(&"charge"))
	host.free()
