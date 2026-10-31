extends SceneTree
## SP-THERIZINOSAURUS (owner 2026-10-31, sheet: "use this for the therezino"): the therizinosaurus draws its rigged Tripo
## model with every clip and a Jaw and Claw bones, stands 8 m, keeps its feet on their prints in the standing clips, and
## brings the claws to survivor height in front at the sweep's hit. In a fight its TacticalBrain (claw_guardian) picks the
## overhead rake point blank (lands, bleeds), the claw sweep lands and shoves her back (no bleed), the hook dashes in,
## lands and drags her toward it, and a sweep at a survivor behind it misses (the claws are the hit). Territorial: a
## Brave (not Aggressive) one turns on a survivor inside its territory. It spawns where islands.json says and the creature lab lists it.
## Run: Godot --headless --path game --script res://tests/t_sp_therizinosaurus.gd  -> "[t_sp_theri] PASS", exit 0.

const ID := &"therizinosaurus"
const EXTRA_CLIPS: Array[StringName] = [&"walk_back", &"strafe_left", &"strafe_right", &"bite_combo"]
const TOES := ["Toe.L", "Toe.R"]
const GROUND_TOL := 0.12  ## m: the lowest toe stays this close to its rest height in standing clips (an 8 m animal)
const SLIDE_TOL := 0.25  ## m: a toe on the ground may not slide further than this

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
	print("[t_sp_theri] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_fight()
	if failures.is_empty():
		print("[t_sp_theri] PASS")
		quit(0)
	else:
		print("[t_sp_theri] FAIL %d" % failures.size())
		quit(1)

func _boxes(n: Node) -> int:
	var c := 0
	var mi := n as MeshInstance3D
	if mi and (mi.mesh is BoxMesh or mi.mesh is CylinderMesh):
		c += 1
	for ch in n.get_children():
		c += _boxes(ch)
	return c

func _bone(sk: Skeleton3D, view: Node3D, b: String, rest: bool = false) -> Vector3:
	var i := sk.find_bone(b)
	var t := sk.get_bone_global_rest(i) if rest else sk.get_bone_global_pose(i)
	return (sk.global_transform * t).origin - view.global_position

func _test_view() -> void:
	var def = data.creature(ID)
	var view = CV.new()
	root.add_child(view)
	view.setup(def)
	_expect(view.using_glb and view.rig != null, "draws the rigged GLB")
	_expect(_boxes(view) == 0, "no box/cylinder placeholder meshes")
	if view.rig == null:
		view.free()
		return
	var clips: Array = def.pipeline.get("clips", [])
	_expect(clips.size() >= 15, "species lists its clips (%d)" % clips.size())
	for clip in clips + EXTRA_CLIPS:
		_expect(view.rig.has_clip(StringName(clip)), "clip %s loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Hips", "Claw.L", "Claw.R", "ClawTip.L", "ClawTip.R", "Hand.L", "Hand.R", "Thigh.L", "Shin.L", "Metatarsal.L", "Toe.L", "Thigh.R", "Toe.R"]:
		_expect(sk.find_bone(b) >= 0, "bone %s" % b)
	var aabb := AABB()
	var first := true
	for mi in view.rig.mesh_root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta(&"creature_eyeshine"):
			continue
		var box: AABB = m.global_transform * m.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	_expect(absf(aabb.size.y - 8.0) < 0.3, "head top at 8 m (%.2f)" % aabb.size.y)
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone(sk, view, b, true).y)
	var chest: float = _bone(sk, view, "Chest", true).dot(fwd)
	# Standing clips: one toe always on the floor, and a toe on the floor stays on its print (no gliding).
	for clip in [&"idle", &"alert", &"attack_primary", &"attack_heavy", &"bite_combo", &"hit_react", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		var slide := 0.0
		var prints := {}
		for k in 37:
			ap.seek(a.length * float(k) / 36.0, true)
			var lo := INF
			for b in TOES:
				var p := _bone(sk, view, b)
				lo = minf(lo, p.y)
				if p.y - rest < 0.08:
					if not prints.has(b):
						prints[b] = p
					slide = maxf(slide, Vector2(p.x - prints[b].x, p.z - prints[b].z).length())
				else:
					prints.erase(b)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL and slide <= SLIDE_TOL, "%s: feet planted (lowest toe %.3f m off rest, slide %.3f m)" % [clip, worst, slide])
	# The claws are the hit: at the sweep's hit frame the right claw knuckle is ahead of the chest and low.
	sk.reset_bone_poses()
	ap.play(&"attack_primary")
	ap.seek(ap.get_animation(&"attack_primary").length * 0.42, true)
	var cl := _bone(sk, view, "ClawTip.R")
	_expect(cl.dot(fwd) > chest + 1.5 and cl.y < 2.5, "attack_primary: claw tip %.1f m ahead of the chest, %.1f m up at the hit" % [cl.dot(fwd) - chest, cl.y])
	# The rake's telegraph: both claw knuckles high over its head at the windup hold.
	sk.reset_bone_poses()
	ap.play(&"attack_heavy")
	ap.seek(ap.get_animation(&"attack_heavy").length * 0.5, true)
	var hl := _bone(sk, view, "Claw.L").y
	var hr := _bone(sk, view, "Claw.R").y
	_expect(hl > 7.0 and hr > 7.0, "attack_heavy telegraph: both claws raised (%.1f / %.1f m)" % [hl, hr])
	view.free()

func _test_spawns() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/islands.json"))
	var rows := []
	for island in (raw as Dictionary):
		if not raw[island] is Dictionary or not (raw[island] as Dictionary).has("spawns"):
			continue
		for ring in (raw[island]["spawns"] as Dictionary):
			for r in raw[island]["spawns"][ring]:
				if r is Dictionary and r.get("species", "") == str(ID):
					rows.append("%s/%s" % [island, ring])
	_expect(rows.has("temperate_45/working") and rows.has("temperate_35/far_shore"), "spawn rows: %s" % [rows])
	var CD = load("res://scripts/creatures/creature_def.gd")
	_expect(CD.eligible(ID, ["therizinosaurus", "stegosaurus"]) == ID, "a spawn row picks the therizinosaurus (it has a model)")
	_expect(load("res://scripts/dev/lab_spawn_panel.gd").listed_species(false).has(ID), "the creature lab lists it")

func _spawn(host: Node3D, player: Node3D, at: Vector3, face: Vector3, nature: StringName = &"aggressive") -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID), &"", 0, null, 0, nature)
	c.look_at(face, Vector3.UP)
	player.vitals.max_health = 1000000.0  # every hit lands on a live survivor (the rake alone kills a fresh one)
	player.vitals.health = player.vitals.effective_max_health()
	player.vitals.dead = false
	player.dead = false
	player.statuses.clear_all()
	if nature == &"aggressive":
		c.brain.attack_target = player
		c.brain._provoked_until = c.brain._now_s() + 60.0
	return c

func _strike(c: Node, player: Node3D, only: Array, frames: int) -> Dictionary:
	var out := {"picked": &"", "hits": [], "kinds": [], "hp0": player.vitals.health}
	c.brain.attack_chosen.connect(func(m: StringName, _d: float) -> void:
		if out["picked"] == &"":
			out["picked"] = m)
	c.anim.attack_hit.connect(func(clip: StringName) -> void: (out["hits"] as Array).append(clip))
	c.brain.tactic.connect(func(k: StringName) -> void: (out["kinds"] as Array).append(k))
	c.brain._strike(c.brain._flat_dist(player), only)
	for _f in frames:
		await physics_frame
	return out

func _test_fight() -> void:
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
	player.process_mode = Node.PROCESS_MODE_DISABLED
	# 1. Point blank in front: the overhead rake is the brain's pick; it lands and bleeds.
	var c = _spawn(host, player, Vector3(0, 0.1, -5.2), Vector3(0, 0.1, 0))
	_expect(c.view.using_glb and _boxes(c.view) == 0 and c.brain.get_script().get_global_name() == &"TacticalBrain", "a spawned therizinosaurus draws the GLB and runs the TacticalBrain")
	_expect(c.brain.tac.get("point_blank", []) == ["heavy", "combo", "bite"] and c.brain.tac.get("hook_pull_m", 0.0) > 0.0, "claw_guardian tactics (point blank %s)" % [c.brain.tac.get("point_blank", [])])
	await physics_frame
	var r: Dictionary = await _strike(c, player, c.brain.tac.get("point_blank", []), 130)
	_expect(r["picked"] == &"heavy" and &"attack_heavy" in r["hits"], "point blank: overhead rake picked (%s) and hits %s" % [r["picked"], r["hits"]])
	_expect(player.vitals.health < r["hp0"], "the rake lands (hp %.0f -> %.0f)" % [r["hp0"], player.vitals.health])
	_expect(player.statuses.has(&"bleed"), "the rake bleeds")
	c.queue_free()
	await physics_frame
	# 2. The claw sweep: lands, shoves her away from it, does not bleed.
	c = _spawn(host, player, Vector3(0, 0.1, -5.2), Vector3(0, 0.1, 0))
	await physics_frame
	c.brain._beat_since_basic = true
	r = await _strike(c, player, ["bite"], 40)
	var shove: Vector3 = player.sim._shove
	_expect(&"attack_primary" in r["hits"] and player.vitals.health < r["hp0"], "the claw sweep lands (hits %s, hp %.0f -> %.0f)" % [r["hits"], r["hp0"], player.vitals.health])
	_expect(&"sweep_shove" in r["kinds"] and shove.z > 0.5, "the sweep shoves her back, away from it (%s)" % shove)
	_expect(not player.statuses.has(&"bleed"), "the sweep does not bleed (pipeline.status_clips)")
	c.queue_free()
	await physics_frame
	# 3. The hook from the ring: it dashes in, the hook lands on hit 0 and drags her toward it.
	player.sim._shove = Vector3.ZERO
	c = _spawn(host, player, Vector3(0, 0.1, -9.5), Vector3(0, 0.1, 0))
	await physics_frame
	var pulls := []
	r = {"picked": &"", "hits": [], "kinds": [], "hp0": player.vitals.health}
	c.brain.tactic.connect(func(k: StringName) -> void:
		(r["kinds"] as Array).append(k)
		if k == &"hook_pull":
			pulls.append(player.sim._shove))
	c.anim.attack_hit.connect(func(clip: StringName) -> void: (r["hits"] as Array).append(clip))
	_expect(c.brain._strike(c.brain._flat_dist(player), ["combo"]), "the hook combo is available from 9.5 m (it dashes in)")
	for _f in 220:
		await physics_frame
	_expect((r["hits"] as Array).count(&"bite_combo") >= 1 and player.vitals.health < r["hp0"], "the hook lands (hits %s, hp %.0f -> %.0f)" % [r["hits"], r["hp0"], player.vitals.health])
	_expect(not pulls.is_empty() and (pulls[0] as Vector3).z < -0.5, "the hook drags her toward it (%s, %s)" % [pulls, r["kinds"]])
	c.queue_free()
	await physics_frame
	# 4. Behind it: the sweep's claws never reach her (the part check), so it misses.
	c = _spawn(host, player, Vector3(0, 0.1, -4.5), Vector3(0, 0.1, -12.0))
	await physics_frame
	c.brain._beat_since_basic = true
	var hp0: float = player.vitals.health
	var hits := []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: hits.append(clip))
	c.brain._bite()
	for _f in 40:
		await physics_frame
	_expect(&"attack_primary" in hits and player.vitals.health == hp0, "a sweep with her behind it misses (hits %s, hp %.0f -> %.0f)" % [hits, hp0, player.vitals.health])
	c.queue_free()
	await physics_frame
	# 5. Territorial: a Brave (not Aggressive) one ignores her at 40 m and turns on her inside its territory.
	c = _spawn(host, player, Vector3(0, 0.1, -40.0), Vector3(0, 0.1, -80.0), &"brave")
	for _f in 30:
		await physics_frame
	var far_target: bool = c.brain.attack_target == player
	c.global_position = Vector3(0, 0.1, -12.0)
	for _f in 60:
		await physics_frame
	_expect(not far_target and c.brain.attack_target == player, "territorial: ignores her at 40 m, turns on her inside its territory (state %s)" % c.brain.state)
	host.free()
