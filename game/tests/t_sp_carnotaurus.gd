extends SceneTree
## SP-CARNOTAURUS: the new species draws its rigged Tripo model (no boxes) with every listed clip, a Jaw bone, about
## 12.8 m long and 5.7 m tall; alphas wear the rust-and-black alpha skin; the hind feet stay on their prints in the
## standing clips; and its signature moves fire and hit in a real fight against a survivor:
##   snap bite (attack_primary): the jaws (Jaw bone at the hit frame) land on her in front, and miss her at its flank;
##   horn ram (attack_heavy): lands and throws her back (tactics.heavy_shove_m);
##   sprint charge (CARNOFEEL): the charge's contact knocks her down (knockdown or throw tier), even when the damage
##     roll misses, and the carnotaurus runs on past her through her body (no snag); at the end of the line it wheels
##     round on its turning radius (yaw rate <= speed / charge_arc_r_m and <= turn_rate 1.4, travelling where it faces:
##     no skid) and charges back through once;
##   chomp combo (CARNOFEEL): point blank, a slowed coil with a ring (the tell), then three chomps that land via the
##     hitboxes; after its charges land it dashes in for it (tactics.charge_follow).
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
	for clip in [&"idle", &"attack_primary", &"bite_combo", &"alert", &"hit_react", &"feed"]:
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
	c.set_meta(&"thero_roar_at", Time.get_ticks_msec() * 0.001)  # THERO-ROAR: no spot roar; the moves under test come at once
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

## Her standing on her feet at the origin, no knock, no statuses (the ram or the charge threw her).
func _stand_up() -> void:
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.sim.knock.cancel()
	player.statuses.clear_all()
	player.anim.release_knockdown()
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO

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

	# 3. CARNOFEEL chomp combo: point blank, the tell (slowed coil + ring), then three chomps on her via the hitboxes.
	_stand_up()
	c = _spawn(Vector3(0, 0.1, -4.5), Vector3(0, 0, 0))
	await _sim(0.05)
	log = []
	c.brain.tactic.connect(func(kind: StringName) -> void: log.append(kind))
	var chomps := [0]
	c.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"bite_combo":
			chomps[0] += 1)
	hurt[0] = 0
	d = c.brain._flat_dist(player)
	_expect((tac.get("point_blank", []) as Array).has("combo") and c.brain.attack_available(&"combo", d), "the chomp combo is a point-blank move and available in front (%.1f m)" % d)
	c.brain._strike(d, ["combo"])
	await _sim(0.1)
	var TG: GDScript = load("res://scripts/combat/telegraph.gd")
	_expect(log.has(&"combo_tell") and TG.live_for(c) >= 1 and chomps[0] == 0, "the combo opens with its tell: a ring at the snout, no chomp yet (%s)" % [log])
	await _sim(3.6)
	_expect(log.has(&"combo") and chomps[0] == 3 and hurt[0] == 3, "chomp combo: 3 chomps land on her (hit frames %d, damage events %d)" % [chomps[0], hurt[0]])
	await _free(c)

	# 4. CARNOFEEL charge contact: knocks her down and runs on through her, then arcs round. Twice: a landed hit, and a
	#    damage roll that misses (a passive dodge / GOD mode used to leave her standing in its path: the snag).
	for acc in [1.0, 0.0]:
		_stand_up()
		load("res://scripts/combat/combat_tuning.gd").force_accuracy = acc
		c = _spawn(Vector3(0, 0.1, -12.0), Vector3(0, 0, 0))
		c.brain.tac = c.brain.tac.duplicate()
		c.brain.tac["charge_through_m"] = 6.0  # the test floor is 160 m, but keep the line short
		log = []
		c.brain.tactic.connect(func(kind: StringName) -> void: log.append(kind))
		c.brain._start_charge()
		var knocked := false
		var passed := false
		var through := false
		var min_v := INF
		var past := -INF
		var arc := {"max_rate": 0.0, "max_slip": 0.0, "min_r": INF, "frames": 0}
		var prev_yaw: float = c.rotation.y
		var step := TIME_SCALE / float(Engine.physics_ticks_per_second)  # one physics frame of game time
		for i in 400:
			await _sim(step)
			if player.sim.knock.active() and player.sim.knock.tier in [1, 2]:  # PlayerKnock.Tier.KNOCKDOWN / THROW
				knocked = true
			if c.brain.state == &"charge" and not c.brain._charge_return:
				through = through or c.brain.passes_through(player)
				if c.brain._charge_hit:
					min_v = minf(min_v, Vector2(c.velocity.x, c.velocity.z).length())
				past = maxf(past, c.global_position.z)  # the line runs toward +z, she stood at z = 0
			if c.brain.state == &"charge_arc":
				var v := Vector2(c.velocity.x, c.velocity.z)
				var rate := absf(angle_difference(prev_yaw, c.rotation.y)) / step
				if v.length() > 0.5:
					arc["frames"] += 1
					arc["max_rate"] = maxf(arc["max_rate"], rate)
					# the frame's move ran on the heading it had then: before or after this frame's yaw step
					var slip := minf(absf(Vector2(-sin(c.rotation.y), -cos(c.rotation.y)).angle_to(v)), absf(Vector2(-sin(prev_yaw), -cos(prev_yaw)).angle_to(v)))
					arc["max_slip"] = maxf(arc["max_slip"], slip)
					if rate > 0.01:
						arc["min_r"] = minf(arc["min_r"], v.length() / rate)
			prev_yaw = c.rotation.y
			if log.has(&"charge_return"):
				break
		passed = past >= 6.0 - 1.5  # the line ends within 1 m of charge_through_m
		var what := "hit" if acc > 0.0 else "damage roll missed"
		_expect(log.has(&"charge_hit") and knocked, "charge contact (%s) knocks her down (%s)" % [what, log])
		_expect(through and min_v >= 0.6 * c.move_speed_mps() and passed,
			"charge (%s) runs on through her body: lowest speed after contact %.1f m/s, reached %.1f m past her" % [what, min_v, past])
		var r_min: float = c.brain.arc_radius()
		_expect(log.has(&"charge_arc") and int(arc["frames"]) > 10 and float(arc["max_rate"]) <= c.turn_rate() + 0.02 and c.turn_rate() <= 1.4 + 0.001
				and float(arc["min_r"]) >= r_min - 0.1 and float(arc["max_slip"]) < deg_to_rad(2.0),
			"after the charge (%s) it arcs round: yaw %.2f rad/s (turn_rate %.2f), radius >= %.1f m (limit %.1f), slip %.1f deg" % [what, arc["max_rate"], c.turn_rate(), arc["min_r"], r_min, rad_to_deg(arc["max_slip"])])
		_expect(log.has(&"charge_return"), "wheeled round, it charges back through her (%s)" % [log])
		if acc > 0.0:  # between charges: after the landed return pass and its arc it dashes in for the chomps
			for i in 200:
				await _sim(0.05)
				if log.has(&"combo"):
					break
			_expect(log.has(&"combo") and log.find(&"combo") > log.rfind(&"charge_arc"), "after its charges land it closes in for the chomp combo (%s)" % [log])
		await _free(c)
		_expect(not player.get_collision_exceptions().any(func(b) -> bool: return is_instance_valid(b) and b.is_in_group(&"creatures")), "the pass-through exception is gone once the animal is")
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	player.process_mode = Node.PROCESS_MODE_DISABLED
	host.free()
