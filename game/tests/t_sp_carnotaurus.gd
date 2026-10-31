extends SceneTree
## SP-CARNOTAURUS: the new species draws its rigged Tripo model (no boxes) with every listed clip, a Jaw bone, about
## 12.8 m long and 5.7 m tall; alphas wear the rust-and-black alpha skin; the hind feet stay on their prints in the
## standing clips; and its signature moves fire and hit in a real fight against a survivor:
##   snap bite (attack_primary): the jaws (Jaw bone at the hit frame) land on her in front, and miss her at its flank;
##   horn ram (attack_heavy): lands and throws her back (tactics.heavy_shove_m);
##   sprint charge with a sharp turn: the straight charge hits and shoves her, at the end of the line it hops round
##     (charge_turn), turning only while airborne, and charges back through.
## It spawns where islands.json says (desert_35 far shore, desert_50 working ring) and the creature lab lists it.
## Run: Godot --headless --path game --script res://tests/t_sp_carnotaurus.gd  -> "[t_sp_carnotaurus] PASS", exit 0.

const ID := &"carnotaurus"
const FEET := ["BackFoot.L", "BackFoot.R"]
const TIME_SCALE := 2.0

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var player

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	root.get_node("Game").time_of_day = 0.4
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_sp_carnotaurus] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_data()
	await _test_fight()
	load("res://scripts/combat/combat_tuning.gd").reset_overrides()
	if failures.is_empty():
		print("[t_sp_carnotaurus] PASS")
		quit(0)
	else:
		print("[t_sp_carnotaurus] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _bone(sk: Skeleton3D, b: String, rest: bool = false) -> Vector3:
	var i := sk.find_bone(b)
	return (sk.global_transform * (sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i))).origin

func _albedo(view) -> Texture2D:
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var sm := m.get_surface_override_material(0) as ShaderMaterial
		if sm:
			return sm.get_shader_parameter("albedo_tex") as Texture2D
	return null

func _test_view() -> void:
	var def = data.creature(ID)
	var CV: GDScript = load("res://scripts/creatures/creature_view.gd")
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null and _boxes(view) == 0, "draws the rigged GLB, no box placeholder")
	if view.rig == null:
		view.free()
		return
	for clip in def.pipeline.get("clips", []):
		_expect(ResourceLoader.exists("res://assets/creatures/carnotaurus/anim/%s.glb" % clip) and view.rig.has_clip(StringName(clip)), "clip %s authored and loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	_expect(sk.find_bone("Jaw") >= 0 and sk.find_bone("Head") >= 0, "Jaw and Head bones in the rig")
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
	_expect(absf(aabb.size.y - def.height_meters) < 0.2 and absf(long_side - 12.8) < 0.8, "size: %.1f m long, %.2f m tall (8 m real x 1.6)" % [long_side, aabb.size.y])
	# Alpha skin: an alpha wears the rust-and-black map, a normal one the regular map.
	var regular := _albedo(view)
	view.free()
	view = CV.new()
	root.add_child(view)
	view.setup(def, &"alpha")  # an alpha spawn's variant (Creature.spawn picks it for alphas)
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	sk = view.rig.skeleton  # the first view (and its skeleton) is freed
	var alpha := _albedo(view)
	_expect(CV.model_variants(def).has("alpha") and not CV.pick_variant(def, "x") in [&"alpha"], "the alpha skin is pipeline.model_variants.alpha, never rolled for a normal spawn")
	_expect(regular != null and alpha != null and alpha != regular and alpha.resource_path.ends_with("carnotaurus_alpha_albedo.jpg"), "the alpha's albedo is the alpha map (%s)" % (alpha.resource_path if alpha else "none"))
	# Feet on their prints in the standing clips: lowest hind foot bone at its rest height, no slide across the floor.
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := {}
	for b in FEET:
		rest[b] = _bone(sk, b, true)
	for clip in [&"idle", &"attack_primary", &"alert", &"hit_react", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst_y := 0.0
		var worst_slide := 0.0
		for k in 13:
			ap.seek(a.length * float(k) / 12.0, true)
			var lo := INF
			for b in FEET:
				var p := _bone(sk, b)
				lo = minf(lo, p.y - (rest[b] as Vector3).y)
				worst_slide = maxf(worst_slide, Vector2(p.x - rest[b].x, p.z - rest[b].z).length())
			worst_y = maxf(worst_y, absf(lo))
		_expect(worst_y <= 0.15 and worst_slide <= 0.2, "%s: hind feet stay on their prints (lowest %.3f m off rest, slide %.3f m)" % [clip, worst_y, worst_slide])
	view.free()

func _test_data() -> void:
	var def = data.creature(ID)
	_expect(def != null and def.archetype == &"horned_hunter" and load("res://scripts/creatures/brains/tactical_brain.gd").has_tactics(def), "carnotaurus is a horned_hunter with a tactics profile")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var rows := []
	for island in ["desert_35", "desert_50"]:
		for ring in (raw[island]["spawns"] as Dictionary):
			for r in raw[island]["spawns"][ring]:
				if str(r.get("species", "")) == "carnotaurus":
					rows.append("%s/%s" % [island, ring])
	_expect(rows.has("desert_35/far_shore") and rows.has("desert_50/working"), "spawn rows: %s" % [rows])
	var CD: GDScript = load("res://scripts/creatures/creature_def.gd")
	_expect(CD.eligible(ID, ["carnotaurus", "utahraptor"]) == ID, "a spawn row picks the carnotaurus (it has a model)")
	_expect(load("res://scripts/dev/lab_spawn_panel.gd").listed_species(false).has(ID), "the creature lab lists it")

func _spawn(at: Vector3, face: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	var iv := RandomNumberGenerator.new()
	iv.seed = 20261030
	c.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv)
	c.spawn(data.creature(ID), &"", 0, null, 0, &"aggressive")
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	c.brain.rng.seed = 20261030
	c.look_at(Vector3(face.x, at.y, face.z), Vector3.UP)
	c.brain.attack_target = player
	return c

func _sim(secs: float) -> void:
	Engine.time_scale = TIME_SCALE
	var step := 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	var n := int(round(secs / step))
	var f0 := Engine.get_physics_frames()
	while Engine.get_physics_frames() - f0 < n:
		await physics_frame
		player.vitals.max_health = 1000000.0
		if player.vitals.health < 1000.0:
			player.vitals.health = player.vitals.effective_max_health()
		player.vitals.dead = false
		player.dead = false
	Engine.time_scale = 1.0

func _free(c) -> void:
	if is_instance_valid(c):
		c.queue_free()
	await physics_frame

func _test_fight() -> void:
	seed(20261030)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261030
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	Engine.max_physics_steps_per_frame = 1000
	Engine.physics_jitter_fix = 0.0
	host = Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var tac: Dictionary = load("res://scripts/creatures/brains/tactical_brain.gd").tactics_for(&"horned_hunter")

	# 1. Snap bite: in front, the jaws land; at its flank (inside the centre reach) the jaws are not on her.
	var c = _spawn(Vector3(0, 0.1, -4.8), Vector3(0, 0, 0))  # inside its reach (attack_range 4.6 + 0.3)
	_expect(c.view.using_glb and _boxes(c.view) == 0 and c.brain.get_script().get_global_name() == &"TacticalBrain", "a spawned carnotaurus draws the GLB and runs the TacticalBrain")
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED  # the clip alone: the brain would pick its own moves
	await _sim(0.1)
	var hurt := [0]  # the survivor's damage events (her health pool is reset by _sim, so count hits instead)
	player.vitals.damaged.connect(func() -> void: hurt[0] += 1)
	var hits := [0]
	c.anim.attack_hit.connect(func(clip: StringName) -> void: hits[0] += 1)
	c.anim.play_clip(&"attack_primary")
	await _sim(1.2)
	_expect(hits[0] == 1 and hurt[0] == 1, "snap bite: the jaws land on her in front (hit frames %d, damage events %d)" % [hits[0], hurt[0]])
	c.global_position = Vector3(-3.0, 0.1, 0.0)
	c.look_at(Vector3(-3.0, 0.1, -10.0), Vector3.UP)  # she is at its flank, 3 m from its centre
	await _sim(0.2)
	hurt[0] = 0
	c.anim.play_clip(&"attack_primary")
	await _sim(1.2)
	_expect(hurt[0] == 0 and not c.part_hit(&"attack_primary", player), "snap bite: at its flank (3 m from its centre) the jaws miss (damage events %d)" % hurt[0])
	await _free(c)

	# 2. Horn ram: lands and throws her back.
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = Vector3(0, 0.9, 0)
	c = _spawn(Vector3(0, 0.1, -4.5), Vector3(0, 0, 0))
	await _sim(0.05)
	var log: Array = []
	c.brain.tactic.connect(func(kind: StringName) -> void: log.append(kind))
	var rammed := [Vector3.INF]
	c.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"attack_heavy":
			rammed[0] = player.global_position)
	hurt[0] = 0
	var d: float = c.brain._flat_dist(player)
	_expect(c.brain.attack_available(&"heavy", d), "the horn ram is available point blank in front (%.1f m)" % d)
	c.brain._strike(d, ["heavy"])
	await _sim(2.4)
	var pushed: float = (player.global_position - rammed[0]).length() if rammed[0] != Vector3.INF else 0.0
	_expect(log.has(&"heavy") and log.has(&"heavy_shove") and hurt[0] >= 1 and pushed >= 0.6 * float(tac.get("heavy_shove_m", 4.0)),
		"horn ram: lands and throws her back %.2f m (%s)" % [pushed, log])
	await _free(c)

	# 3. Sprint charge with a sharp turn: hit and shove, hop round in the air only, charge back through.
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	# 6.8 m out: with no navmesh in the test a goal past 12 m is not steered to (the charge runs on 5 m past her)
	c = _spawn(Vector3(0, 0.1, -6.8), Vector3(0, 0, 0))
	# The run-through and shove scaled into the test's 12 m: she must end up behind it, as in the game (9 m past, 3.5 m shove)
	c.brain.tac = c.brain.tac.duplicate()
	c.brain.tac["charge_through_m"] = 4.5
	c.brain.tac["charge_shove_m"] = 1.5
	log = []
	c.brain.tactic.connect(func(kind: StringName) -> void: log.append(kind))
	var yaw0: float = c.rotation.y
	var turn := {"yaw_ground_max": 0.0, "yaw_total": 0.0, "from": 0.0}
	c.brain._start_charge()
	var in_turn := false
	for i in 120:
		await _sim(0.05)
		if c.brain.state == &"charge_turn":
			if not in_turn:
				in_turn = true
				turn["from"] = c.brain._turn_from
			var u: float = c.brain._j_t / maxf(0.01, c.brain._j_len)
			var turned := absf(angle_difference(float(turn["from"]), c.rotation.y))
			if u < c.brain._j_air.x - 0.02:
				turn["yaw_ground_max"] = maxf(turn["yaw_ground_max"], turned)
			turn["yaw_total"] = maxf(turn["yaw_total"], turned)
		if log.has(&"charge_return") and not c.brain.state in [&"charge", &"charge_turn"]:
			break
	_expect(log.has(&"charge") and log.has(&"charge_hit"), "the straight charge hits her (%s)" % [log])
	_expect(log.has(&"charge_turn") and log.has(&"charge_return") and log.count(&"charge") >= 2, "at the end of the line it turns sharply and charges back (%s)" % [log])
	_expect(float(turn["yaw_total"]) > deg_to_rad(120.0) and float(turn["yaw_ground_max"]) < deg_to_rad(3.0),
		"the turn swings %.0f deg, only in the air (%.1f deg before take-off)" % [rad_to_deg(turn["yaw_total"]), rad_to_deg(turn["yaw_ground_max"])])
	await _free(c)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	host.free()
