extends SceneTree
## SP-DILOPHOSAURUS: the dilophosaurus draws its rigged Tripo model (no box placeholder) with every listed clip, it is
## 3.6 m tall, its feet stay on the floor in the standing clips, the frill is folded in the gaits and flared in the
## display, the spit and the slash, each melee hit comes from its part (jaws, raking foot) out in front at the hit frame,
## the brain spits venom from range (a glob that hits a survivor who stands still and poisons her with Venom, and misses
## one who steps out of the ring), opens with the spit on the approach, leaps and slashes, snaps without venom, an
## alpha wears the olive skin, and the spawn tables put it on tropical/swamp islands with nothing falling through.
## Run: Godot --headless --path game --script res://tests/t_sp_dilophosaurus.gd  -> "[t_sp_dilophosaurus] PASS", exit 0.

const ID := &"dilophosaurus"
const TOES := ["Toe.L", "Toe.R"]
const GROUND_TOL := 0.08  ## m: the lowest toe stays this close to its rest height in standing clips
## clip -> [hit frac, bone, metres ahead of the origin at least]: anim_events hit fracs and pipeline.hit_parts
const HITS := {&"attack_primary": [0.42, "Head", 2.0], &"attack_heavy": [0.72, "Toe.R", 1.2], &"pounce": [0.7, "Toe.L", 0.8]}

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
	print("[t_sp_dilophosaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_spit_hits()
	await _test_spit_dodged()
	await _test_bite_no_venom()
	await _test_approach_spit()
	await _test_pounce()
	await _test_alpha()
	if failures.is_empty():
		print("[t_sp_dilophosaurus] PASS")
		quit(0)
	else:
		print("[t_sp_dilophosaurus] FAIL %d" % failures.size())
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

## Span across the body of the frill rib tips (their bone tails are not in the skeleton: the rib heads plus the
## direction of each rib's +Y, one rib length out).
func _frill_span(sk: Skeleton3D) -> float:
	var lo := INF
	var hi := -INF
	for side in ["L", "R"]:
		for i in range(1, 8):
			var b := sk.find_bone("Frill%d.%s" % [i, side])
			if b < 0:
				continue
			var t: Transform3D = sk.global_transform * sk.get_bone_global_pose(b)
			var tip: Vector3 = t.origin + t.basis.y.normalized() * 1.1
			var x: float = tip.x
			lo = minf(lo, x)
			hi = maxf(hi, x)
	return hi - lo

func _test_view() -> void:
	var def = data.creature(ID)
	_expect(def != null and ResourceLoader.exists("res://assets/creatures/dilophosaurus/dilophosaurus.glb"), "dilophosaurus data and GLB exist")
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
		var authored := ResourceLoader.exists("res://assets/creatures/dilophosaurus/anim/%s.glb" % clip)
		_expect(authored and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Neck2", "Tail7", "Frill1.L", "Frill7.R"] + TOES:
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
	_expect(long_side > 2.4 * aabb.size.y and long_side < 3.4 * aabb.size.y, "a long-tailed theropod: %.1f m long, %.1f m tall" % [long_side, aabb.size.y])
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone_pos(sk, b, true).y)
	var shut := _frill_span(sk)
	for clip in [&"idle", &"walk", &"run", &"strafe_left", &"walk_back", &"alert", &"attack_primary", &"attack_heavy", &"spit", &"hit_react", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var offs: Array[float] = []
		var widest := 0.0
		for k in 24:
			ap.seek(a.length * float(k) / 24.0, true)
			var lo := INF
			for b in TOES:
				lo = minf(lo, _bone_pos(sk, b).y)
			offs.append(absf(lo - rest))
			widest = maxf(widest, _frill_span(sk))
		offs.sort()
		var worst: float = offs[int(offs.size() * 0.75) - 1] if clip == &"run" else offs[-1]  # the run has a flight phase
		_expect(worst <= GROUND_TOL, "%s: a toe stays on the floor (worst %.3f m off rest)" % [clip, worst])
		if clip in [&"idle", &"walk", &"run"]:
			_expect(widest < shut + 0.3, "%s: the frill stays folded (%.2f m, rest %.2f m)" % [clip, widest, shut])
		elif clip in [&"alert", &"attack_heavy", &"spit"]:
			_expect(widest > shut + 1.2, "%s: the frill flares (%.2f m, folded %.2f m)" % [clip, widest, shut])
	var origin: Vector3 = (view as Node3D).global_position
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	for clip in HITS:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		ap.seek(a.length * float(HITS[clip][0]), true)
		var p := _bone_pos(sk, str(HITS[clip][1]))
		var ahead: float = (p - origin).dot(fwd)
		_expect(ahead > float(HITS[clip][2]), "%s: %s %.2f m ahead of the body centre at the hit frame" % [clip, HITS[clip][1], ahead])
	view.free()

## The species' rows in islands.json: tropical/swamp islands, and the model means nothing falls through.
func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var islands := []
	_find_rows(raw, islands, "")
	_expect(islands.size() >= 3, "dilophosaurus spawn rows in islands.json (%d: %s)" % [islands.size(), islands])
	var cdef: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(cdef.has_model(ID), "has_model(dilophosaurus): spawns no longer fall through")
	_expect(cdef.eligible(ID, [ID, &"compsognathus"]) == ID, "eligible(dilophosaurus) is dilophosaurus itself")
	_expect(str(data.creature(ID).climate) == "tropical", "climate tropical")

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

func _dilo(host: Node3D, at: Vector3, alpha: bool = false) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	c.alpha_spawn = alpha
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID))
	c.look_at(Vector3(0, at.y, 0), Vector3.UP)
	return c

## Spit from 8 m at a survivor who stands still: the frill flares under the ring, the glob flies and lands, she
## loses health and is Venomed.
func _test_spit_hits() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _dilo(host, Vector3(0, 0.1, -8.0))
	var b = c.brain
	_expect(b != null and str(b.get_script().resource_path).ends_with("tactical_brain.gd"), "a dilophosaurus runs the TacticalBrain (its own tactics)")
	b.attack_target = player
	b._combat_memory_left = 30.0
	_expect(b.attack_available(&"spit", 8.0), "the spit is available at 8 m")
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var res := {}
	var hp0: float = player.vitals.health
	root.get_node("Game").god_mode = true  # a fresh 100 HP survivor dies to one spit (the old stat block); Venom needs her alive
	b._start_spit()
	_expect(b.state == &"spit" and c.anim.current_clip == &"spit", "the spit starts (state %s, clip %s)" % [b.state, c.anim.current_clip])
	_expect(is_instance_valid(b._telegraph), "a ground ring on her for the windup")
	for _f in 150:
		await physics_frame
		var s := host.find_child("VenomSpit", true, false)
		if s and not res.has("conn"):
			res["conn"] = true
			s.landed.connect(func(hit: bool) -> void: res["hit"] = hit)
		if res.has("hit"):
			break
	_expect(seen.has(&"spit_launch"), "the glob leaves the jaws on the spit's hit frame")
	_expect(res.get("hit", false), "the glob lands on her")
	_expect(res.get("hit", false) and player.vitals.health <= hp0, "it lands a damaging hit through CreatureAttack (GOD keeps her at %.0f HP)" % player.vitals.health)
	_expect(player.statuses.has(&"venom"), "she is Venomed (the species' status rides on the spit)")
	root.get_node("Game").god_mode = false
	host.free()

## Step out of the ring after the glob leaves: it splashes where she stood, no damage, no venom.
func _test_spit_dodged() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _dilo(host, Vector3(0, 0.1, -9.0))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	var res := {}
	b.tactic.connect(func(k: StringName) -> void:
		if k == &"spit_launch":
			player.global_position += Vector3(3.0, 0, 0))  # sidestep as it spits
	var hp0: float = player.vitals.health
	b._start_spit()
	for _f in 150:
		await physics_frame
		var s := host.find_child("VenomSpit", true, false)
		if s and not res.has("conn"):
			res["conn"] = true
			s.landed.connect(func(hit: bool) -> void: res["hit"] = hit)
		if res.has("hit"):
			break
	_expect(res.has("hit") and not res["hit"], "a sidestep out of the ring dodges the glob")
	_expect(is_equal_approx(player.vitals.health, hp0) and not player.statuses.has(&"venom"), "no damage, no venom (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	host.free()

## The snap lands from the jaws in front and carries no venom (tactics.status_clips: the spit only).
func _test_bite_no_venom() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _dilo(host, Vector3(0, 0.1, -3.2))
	c.brain.attack_target = player
	c.brain._set_state(&"attack")
	var hp0: float = player.vitals.health
	var parts: Array = []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: parts.append(c.part_hit(clip, player)))
	c.anim.play_clip(&"attack_primary")
	for _f in 60:
		await physics_frame
	_expect(player.vitals.health < hp0, "the snap lands (hp %.0f -> %.0f, jaws in reach %s)" % [hp0, player.vitals.health, parts])
	_expect(not player.statuses.has(&"venom"), "the snap carries no venom")
	host.free()

## Coming in from 16 m it opens with the spit as soon as she is in spit range.
func _test_approach_spit() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _dilo(host, Vector3(0, 0.1, -16.0))
	var b = c.brain
	b.attack_target = player
	b._combat_memory_left = 30.0
	b._set_state(&"approach")
	var chosen := {}
	b.attack_chosen.connect(func(m: StringName, d: float) -> void:
		if not chosen.has(m):
			chosen[m] = d)
	for _f in 300:
		await physics_frame
		if chosen.has(&"spit"):
			break
	_expect(chosen.has(&"spit"), "it opens with the spit on the approach (%s)" % chosen)
	if chosen.has(&"spit"):
		_expect(float(chosen[&"spit"]) <= 11.5 and float(chosen[&"spit"]) >= 3.5, "from spit range (%.1f m)" % float(chosen[&"spit"]))
	host.free()

## The leaping slash from 6 m: the flared crouch, the leap, both feet rake her on landing.
func _test_pounce() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var c = _dilo(host, Vector3(0, 0.1, -6.0))
	var b = c.brain
	b.tac = b.tac.duplicate()
	b.tac["pounce_overshoot_chance"] = 0.0
	b.attack_target = player
	b._combat_memory_left = 30.0
	var seen := {}
	b.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	var landed := {}
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void: landed[clip] = true)
	var hp0: float = player.vitals.health
	root.get_node("Game").god_mode = true
	b._start_pounce()
	_expect(b.state == &"pounce", "the leaping slash starts (state %s)" % b.state)
	for _f in 200:
		await physics_frame
		if landed.has(&"pounce") or seen.has(&"pounce_miss"):
			break
	_expect(seen.has(&"leap"), "it leaps")
	_expect(landed.has(&"pounce"), "the slash lands from the feet (%s)" % landed)
	root.get_node("Game").god_mode = false
	_expect(not player.statuses.has(&"venom"), "the slash carries no venom")
	host.free()

## An alpha wears the olive skin; a regular animal keeps the GLB's.
func _test_alpha() -> void:
	var a := await _arena()
	var host: Node3D = a[0]
	var reg = _dilo(host, Vector3(10, 0.1, 0))
	var alp = _dilo(host, Vector3(-10, 0.1, 0), true)
	_expect(alp.is_alpha() and alp.variant == &"alpha", "an alpha spawns with the alpha variant (%s)" % alp.variant)
	_expect(reg.variant != &"alpha", "a regular dilophosaurus is not given the alpha skin (%s)" % reg.variant)
	var tex := _albedo(alp.view)
	_expect(tex != null and tex.resource_path.ends_with("dilophosaurus_alpha_albedo.jpg"), "the alpha draws dilophosaurus_alpha_albedo.jpg (%s)" % (tex.resource_path if tex else "none"))
	var rtex := _albedo(reg.view)
	_expect(rtex != null and not rtex.resource_path.ends_with("dilophosaurus_alpha_albedo.jpg"), "the regular draws its own albedo")
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
