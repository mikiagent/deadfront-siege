extends SceneTree
## SP-ALLOSAURUS: the allosaurus draws its rigged Tripo model (no box placeholder) with every listed clip, it is 6.5 m
## tall and 14 m long, its feet stay on the floor in the standing clips, each hit's part is out in front at its hit frame,
## the TacticalBrain picks the shoulder ram for prey under its chin and the grab or hatchet in front, the hatchet bite
## lands and bleeds (the snap bite does not), the grab pins the survivor and both bites land before it lets go, the ram
## throws her back, a pair surrounds her from opposite sides, and the spawn rows (pairs) are on its islands.
## Run: Godot --headless --path game --script res://tests/t_sp_allosaurus.gd  -> "[t_sp_allosaurus] PASS", exit 0.

const ID := &"allosaurus"
const TOES := ["Toe.L", "Toe.R"]  ## Toe head = the heel/ball on the floor (rig_biped: the whole sole is Toe)
const GROUND_TOL := 0.12  ## m on a 6.5 m animal: the lowest Toe head stays this close to its rest height
## clip -> [hit frac, bone, min metres ahead of the centre]: anim_events hit fracs and pipeline.hit_parts
const HITS := {&"attack_primary": [0.42, "Jaw", 6.0], &"attack_heavy": [0.72, "Head", 5.0], &"grab_bite": [0.3, "Hand.R", 4.5], &"kick": [0.45, "Chest", 2.5]}

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
	print("[t_sp_allosaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_choice()
	await _test_hatchet()
	await _test_grab()
	await _test_ram()
	await _test_pair()
	if failures.is_empty():
		print("[t_sp_allosaurus] PASS")
		quit(0)
	else:
		print("[t_sp_allosaurus] FAIL %d" % failures.size())
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
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/allosaurus/allosaurus.glb"), "allosaurus data and GLB exist")
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
		var authored := ResourceLoader.exists("res://assets/creatures/allosaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Chest", "Hand.L", "Hand.R", "Tail6"] + TOES:
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
	_expect(long_side > 13.0 and long_side < 15.5, "14 m long (9 m real x 1.6): %.1f m" % long_side)
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	for clip in [&"idle", &"walk", &"run", &"strafe_left", &"walk_back", &"attack_primary", &"attack_heavy", &"grab_bite", &"kick", &"hit_react", &"alert", &"feed"]:
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
		var worst: float = offs[int(offs.size() * 0.8) - 1] if clip == &"run" else offs[-1]  # the run has a flight phase
		_expect(worst <= GROUND_TOL, "%s: a foot stays on the floor (worst %.3f m off rest)" % [clip, worst])
	# Each hit's part, at its hit frame, is out in front of the body.
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
		_expect(ahead > float(HITS[clip][2]), "%s: %s %.2f m ahead of the body centre at the hit frame" % [clip, HITS[clip][1], ahead])
		if clip == &"attack_heavy":
			_expect(p.y < head_rest.y - 2.5, "hatchet: the skull is chopped down (head %.2f m, rest %.2f m)" % [p.y, head_rest.y])
	view.free()

## islands.json rows: pairs, on its own islands; the model means nothing falls through to another species.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var rows := []
	_find_rows(raw, rows)
	_expect(rows.size() >= 2, "allosaurus spawn rows in islands.json (%d)" % rows.size())
	for r in rows:
		_expect(int((r as Dictionary).get("count", 0)) == 2, "a row spawns a pair (count %s)" % (r as Dictionary).get("count"))
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(allosaurus): spawns no longer fall through")
	_expect(cdef.eligible(ID, [ID, &"gallimimus"]) == ID, "eligible(allosaurus) is allosaurus itself")

func _find_rows(n: Variant, out: Array) -> void:
	if n is Dictionary:
		if str((n as Dictionary).get("species", "")) == str(ID):
			out.append(n)
		for k in n:
			_find_rows(n[k], out)
	elif n is Array:
		for x in n:
			_find_rows(x, out)

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

func _allo(host: Node3D, at: Vector3, pack: int = 0) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID), &"", pack)
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## Point-blank choice: prey pressed under its chin gets the shoulder ram (not the jaws); in front at jaw range the grab.
func _test_choice() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _allo(host, Vector3(0, 0.1, -3.0))
	var b = c.brain
	_expect(str(b.get_script().resource_path).ends_with("tactical_brain.gd"), "an allosaurus runs the TacticalBrain")
	b.attack_target = player
	_expect(b.attack_available(&"kick", 3.0) and not b.attack_available(&"grab", 3.0), "under its chin (3 m): shoulder ram, no grab")
	c.global_position = Vector3(0, 0.1, -6.2)
	_expect(b.attack_available(&"grab", 6.2) and not b.attack_available(&"kick", 6.2), "in front at jaw range (6.2 m): grab, no ram")
	_expect(b.attack_available(&"heavy", 6.2), "the hatchet bite is available in front at jaw range")
	_expect(not b.attack_available(&"pounce", 6.2), "no pounce: a 14 m animal does not leap")
	host.free()

func _bleeds(p) -> bool:
	return p.statuses.has(&"deep_bleed") or p.statuses.has(&"bleed")

## The hatchet bite lands from the skull at its chop and applies Bleed; the snap bite lands without it.
func _test_hatchet() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	root.get_node("Game").god_mode = true
	var c = _allo(host, Vector3(0, 0.1, -6.4))
	c.brain.attack_target = player
	c.brain._set_state(&"attack")
	var hits := []
	c.brain.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: hits.append(clip))
	c.anim.play_clip(&"attack_primary")
	for _f in 70:
		await physics_frame
	_expect(&"attack_primary" in hits, "the snap bite lands in front (%s)" % [hits])
	_expect(not _bleeds(player), "the snap bite applies no bleed")
	c.global_position = Vector3(0, 0.1, -6.4)
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	c.brain._set_state(&"attack")
	c.brain._heavy()
	for _f in 120:
		await physics_frame
	_expect(&"attack_heavy" in hits, "the hatchet bite lands (%s)" % [hits])
	_expect(_bleeds(player), "the hatchet bite applies Bleed")
	root.get_node("Game").god_mode = false
	host.free()

## The grab: the hands clamp (Pinned, held in front), both bites land, then it lets go.
func _test_grab() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	root.get_node("Game").god_mode = true
	var c = _allo(host, Vector3(0, 0.1, -6.2))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := []
	b.tactic_hit.connect(func(clip: StringName, i: int, _m: float) -> void: landed.append("%s%d" % [clip, i]))
	var pinned_seen := [false]
	var held := [99.0]
	b._grab()
	for _f in 240:
		await physics_frame
		if player.statuses.has(&"pinned"):
			pinned_seen[0] = true
			held[0] = minf(held[0], Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length())
		if seen.has(&"grabbed") and b.state != &"pin":
			break
	_expect(seen.has(&"grab") and seen.has(&"grabbed"), "the grab clamps her (%s)" % [seen.keys()])
	_expect(pinned_seen[0], "the survivor is Pinned by the hands")
	_expect(held[0] < 7.5, "she is held in front of the chest (%.2f m from its centre)" % held[0])
	_expect(landed == ["grab_bite0", "grab_bite1", "grab_bite2"], "the clamp and both bites land (%s)" % [landed])
	_expect(not player.statuses.has(&"pinned") and b.state != &"pin", "it lets go after the bites (state %s)" % b.state)
	root.get_node("Game").god_mode = false
	host.free()

## The shoulder ram lands from the chest and throws her back.
func _test_ram() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	root.get_node("Game").god_mode = true
	var c = _allo(host, Vector3(0, 0.1, -3.2))
	var b = c.brain
	b.attack_target = player
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var d0: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(b._strike(d0, ["kick"]), "the ram is picked at %.1f m" % d0)
	for _f in 90:
		await physics_frame
	var d1: float = Vector2(player.global_position.x - c.global_position.x, player.global_position.z - c.global_position.z).length()
	_expect(seen.has(&"kick_shove"), "the shoulder ram lands and shoves (%s)" % [seen.keys()])
	_expect(d1 > d0 + 2.5, "she is thrown back (%.1f -> %.1f m)" % [d0, d1])
	root.get_node("Game").god_mode = false
	host.free()

## A pair (one pack) holds ring slots on opposite sides of the prey (tactics.surround), and both go for her.
## (The slot math, not a walk round the ring: with no navmesh in a test a goal past ~12 m is not steered to.)
func _test_pair() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var one = _allo(host, Vector3(-3, 0.1, -14), 777)
	var two = _allo(host, Vector3(3, 0.1, -14), 777)
	for c in [one, two]:
		c.brain.attack_target = player
		c.brain._combat_memory_left = 60.0
	await physics_frame
	_expect(one.brain._pack_members().size() == 2 and bool(one.brain.tac.get("surround", false)), "the two are one surrounding pack")
	var u: Vector3 = one.brain._surround_slot() - player.global_position
	var v: Vector3 = two.brain._surround_slot() - player.global_position
	u.y = 0.0
	v.y = 0.0
	_expect(absf(rad_to_deg(u.angle_to(v)) - 180.0) < 5.0, "their ring slots are on opposite sides of her (%.0f deg apart, %.1f m out)" % [rad_to_deg(u.angle_to(v)), u.length()])
	host.free()
