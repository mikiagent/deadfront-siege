extends SceneTree
## SP-GALLIMIMUS (owner 2026-10-31: "Gallimimus is fast but the model isn't great, animations aren't great and its
## behavior sucks. Animals that run away from you should get territorial and attack you if you chase them").
## The rebuilt gallimimus draws its rigged Tripo model with every clip, a Jaw and a 3-bone neck, stands 3.8 m, keeps its
## feet on their prints in the standing clips, brings the beak to her chest at the peck's hit and hauls the right foot
## high in the kick's telegraph. It spawns where islands.json says and the creature lab lists it.
## Behaviour: it runs from a threat and leaves a survivor who does not chase it alone; chased, it turns (brain_cornered)
## and fights: point blank the kick is its pick and lands (a stagger shove + Winded, never a knockdown: it is light),
## the peck lands, the peck-peck-kick combo lands from the ring, and under 30 % HP it runs again.
## Run: Godot --headless --path game --script res://tests/t_sp_gallimimus.gd  -> "[t_sp_galli] PASS", exit 0.

const ID := &"gallimimus"
const TOES := ["Toe.L", "Toe.R"]
const GROUND_TOL := 0.08  ## m: the lowest toe stays this close to its rest height in standing clips
const SLIDE_TOL := 0.12  ## m: a toe on the ground may not slide further than this

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
	print("[t_sp_galli] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_spawns()
	await _test_fight()
	await _test_chase()
	if failures.is_empty():
		print("[t_sp_galli] PASS")
		quit(0)
	else:
		print("[t_sp_galli] FAIL %d" % failures.size())
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
	_expect(clips.size() == 20, "species lists its clips (%d)" % clips.size())
	for clip in clips:
		_expect(view.rig.has_clip(StringName(clip)), "clip %s loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Neck1", "Neck2", "Neck3", "Hips", "Hand.L", "Hand.R", "Thigh.L", "Shin.L", "Metatarsal.L", "Toe.L", "Toe.R"]:
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
	_expect(absf(aabb.size.y - 3.8) < 0.2, "head top at 3.8 m (%.2f)" % aabb.size.y)
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone(sk, view, b, true).y)
	# Standing clips: one toe always on the floor, and a toe on the floor stays on its print (the attacks lift or step
	# the right foot on purpose, so there only the left one is held to its print).
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
				if b == "Toe.R" and str(clip).begins_with("attack") or b == "Toe.R" and clip == &"bite_combo":
					continue
				if p.y - rest < 0.06:
					if not prints.has(b):
						prints[b] = p
					slide = maxf(slide, Vector2(p.x - prints[b].x, p.z - prints[b].z).length())
				else:
					prints.erase(b)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL and slide <= SLIDE_TOL, "%s: feet planted (lowest toe %.3f m off rest, slide %.3f m)" % [clip, worst, slide])
	# The peck: at its hit the skull (Head bone; the beak runs 0.55 m on from it, nose-down) has dropped low and ahead.
	sk.reset_bone_poses()
	ap.play(&"attack_primary")
	var head0 := _bone(sk, view, "Head", true)
	ap.seek(ap.get_animation(&"attack_primary").length * 0.42, true)
	var hd := _bone(sk, view, "Head")
	_expect(hd.y < 2.5 and hd.y < head0.y - 1.0 and hd.dot(fwd) > 2.0, "attack_primary: the head drops %.1f m to %.1f m up, %.1f m ahead at the hit" % [head0.y - hd.y, hd.y, hd.dot(fwd)])
	# The kick's telegraph: the right foot hauled up high at the windup hold, then forward at the hit.
	sk.reset_bone_poses()
	ap.play(&"attack_heavy")
	ap.seek(ap.get_animation(&"attack_heavy").length * 0.5, true)
	var up := _bone(sk, view, "Toe.R").y
	ap.seek(ap.get_animation(&"attack_heavy").length * 0.72, true)
	var kick := _bone(sk, view, "Toe.R")
	_expect(up > 1.0 and kick.dot(fwd) > 1.4 and kick.y > 0.3, "attack_heavy: foot raised %.1f m in the telegraph, %.1f m ahead and %.1f m up at the hit" % [up, kick.dot(fwd), kick.y])
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
	_expect(rows.has("desert_35/gathering") and rows.has("desert_50/gathering"), "spawn rows kept: %s" % [rows])
	var CD = load("res://scripts/creatures/creature_def.gd")
	_expect(CD.eligible(ID, ["gallimimus", "stegosaurus"]) == ID, "a spawn row picks the gallimimus (it has a model)")
	_expect(load("res://scripts/dev/lab_spawn_panel.gd").listed_species(false).has(ID), "the creature lab lists it")

func _arena() -> Array:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.vitals.max_health = 1000000.0
	return [host, player]

func _fresh(player: Node) -> void:
	player.vitals.health = 1000000.0  # every hit lands on a live survivor (a peck alone kills a fresh one: attack 120)
	player.vitals.dead = false
	player.dead = false
	player.statuses.clear_all()
	player.sim._shove = Vector3.ZERO

func _spawn(host: Node3D, player: Node3D, at: Vector3, face: Vector3, fight: bool = true) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID), &"", 0, null, 0, &"brave")
	c.look_at(face, Vector3.UP)
	_fresh(player)
	if fight:
		c.brain.attack_target = player
		c.brain._provoked_until = c.brain._now_s() + 60.0
	return c

func _strike(c: Node, player: Node3D, only: Array, frames: int) -> Dictionary:
	var out := {"picked": &"", "hits": [], "kinds": [], "hp0": player.vitals.health, "knocked": false}
	c.brain.attack_chosen.connect(func(m: StringName, _d: float) -> void:
		if out["picked"] == &"":
			out["picked"] = m)
	c.anim.attack_hit.connect(func(clip: StringName) -> void: (out["hits"] as Array).append(clip))
	c.brain.tactic.connect(func(k: StringName) -> void: (out["kinds"] as Array).append(k))
	c.brain._strike(c.brain._flat_dist(player), only)
	for _f in frames:
		await physics_frame
		out["knocked"] = out["knocked"] or player.sim.knock.active()
	return out

func _test_fight() -> void:
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	# 1. Point blank in front: the spring-and-rake kick is the pick; it lands, staggers her back and winds her, no knockdown.
	var c = _spawn(host, player, Vector3(0, 0.1, -2.5), Vector3(0, 0.1, 0))
	_expect(c.view.using_glb and _boxes(c.view) == 0 and c.brain.get_script().get_global_name() == &"TacticalBrain", "a spawned gallimimus draws the GLB and runs the TacticalBrain")
	_expect(c.brain.tac.get("point_blank", []) == ["heavy", "combo", "bite"] and not c.brain.tac.has("territorial") and c.brain.cornered.cfg.get("radius_m", 0.0) == 18.0,
		"tactics: point blank %s, no flee-once territorial block, its own cornered thresholds" % [c.brain.tac.get("point_blank", [])])
	await physics_frame
	var r: Dictionary = await _strike(c, player, c.brain.tac.get("point_blank", []), 90)
	_expect(r["picked"] == &"heavy" and &"attack_heavy" in r["hits"], "point blank: the kick is picked (%s) and hits %s" % [r["picked"], r["hits"]])
	_expect(player.vitals.health < r["hp0"] and &"heavy_shove" in r["kinds"], "the kick lands and shoves her (hp %.0f -> %.0f, %s)" % [r["hp0"], player.vitals.health, r["kinds"]])
	_expect(player.statuses.has(&"winded") and not r["knocked"], "the kick winds her and never knocks her down (light animal)")
	c.queue_free()
	await physics_frame
	# 2. The peck: lands, no wind, no knockdown.
	c = _spawn(host, player, Vector3(0, 0.1, -3.0), Vector3(0, 0.1, 0))
	await physics_frame
	c.brain._beat_since_basic = true
	r = await _strike(c, player, ["bite"], 40)
	_expect(&"attack_primary" in r["hits"] and player.vitals.health < r["hp0"], "the peck lands (hits %s, hp %.0f -> %.0f)" % [r["hits"], r["hp0"], player.vitals.health])
	_expect(not player.statuses.has(&"winded") and not r["knocked"], "the peck does not wind or knock her down")
	c.queue_free()
	await physics_frame
	# 3. Peck-peck-kick from a few metres: it closes in and the combo lands.
	c = _spawn(host, player, Vector3(0, 0.1, -6.0), Vector3(0, 0.1, 0))
	await physics_frame
	r = {"hits": [], "hp0": player.vitals.health}
	c.anim.attack_hit.connect(func(clip: StringName) -> void: (r["hits"] as Array).append(clip))
	_expect(c.brain._strike(c.brain._flat_dist(player), ["combo"]), "the combo is available from 6 m")
	for _f in 240:
		await physics_frame
	_expect((r["hits"] as Array).count(&"bite_combo") >= 2 and player.vitals.health < r["hp0"], "peck-peck-kick lands (hits %s, hp %.0f -> %.0f)" % [r["hits"], r["hp0"], player.vitals.health])
	c.queue_free()
	await physics_frame
	# 4. Behind it: the peck never reaches her.
	c = _spawn(host, player, Vector3(0, 0.1, -3.0), Vector3(0, 0.1, -12.0))
	await physics_frame
	c.brain._beat_since_basic = true
	var hp0: float = player.vitals.health
	var hits := []
	c.anim.attack_hit.connect(func(clip: StringName) -> void: hits.append(clip))
	c.brain._bite()
	for _f in 40:
		await physics_frame
	_expect(&"attack_primary" in hits and player.vitals.health == hp0, "a peck with her behind it misses (hits %s, hp %.0f -> %.0f)" % [hits, hp0, player.vitals.health])
	c.queue_free()
	host.free()
	await physics_frame

## Run the chase: frames of physics with the survivor following it at `chase_mps` (0: she stands still).
func _run_for(c: Node, player: Node3D, seconds: float, chase_mps: float, seen: Dictionary) -> Dictionary:
	var out := {"states": {}, "turned": -1.0, "attacked": false}
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var t := 0.0
	while t < seconds:
		await physics_frame
		t += dt
		out["states"][c.brain.state] = true
		if seen.has(&"cornered") and out["turned"] < 0.0:
			out["turned"] = t
		if c.brain.state in [&"attack", &"combo", &"lunge", &"charge"]:
			out["attacked"] = true
		if OS.has_environment("GALLI_TRACE") and int(t * 60) % 15 == 0:
			print("[trace] %.2f %s d=%.1f pressure=%.2f chased=%.1f speed=%.1f" % [t, c.brain.state, c.brain._flat_dist(player), c.brain.cornered.pressure, c.brain.cornered.chased_m, Vector2(c.velocity.x, c.velocity.z).length()])
		if chase_mps > 0.0:
			var to: Vector3 = c.global_position - player.global_position
			to.y = 0.0
			if to.length() > 2.5:
				player.global_position += to.normalized() * chase_mps * dt
	return out

func _test_chase() -> void:
	root.get_node("Game").god_mode = true  # she lives through the whole fight (a dead target ends it)
	var a: Array = await _arena()
	var host: Node3D = a[0]
	var player = a[1]
	# 1. Left alone: it runs from her and never turns on a survivor who stands still.
	var c = _spawn(host, player, Vector3(0, 0.1, -12.0), Vector3(0, 0.1, -40.0), false)
	var seen := {}
	c.brain.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	await physics_frame
	c.brain._spot(player)
	var r: Dictionary = await _run_for(c, player, 8.0, 0.0, seen)
	_expect(r["states"].has(&"flee") and r["turned"] < 0.0 and not r["attacked"], "unchased: it runs and never turns on her (states %s)" % [r["states"].keys()])
	c.queue_free()
	await physics_frame
	# 2. Chased at a survivor's sprint: it turns with its threat display and attacks.
	c = _spawn(host, player, Vector3(0, 0.1, -12.0), Vector3(0, 0.1, -40.0), false)
	player.global_position = Vector3(0, 0.9, 0)
	seen = {}
	c.brain.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	await physics_frame
	c.brain._spot(player)
	r = await _run_for(c, player, 12.0, 7.0, seen)
	_expect(r["turned"] > 0.0 and c.brain.cornered.fighting(), "chased: it turns on her after %.1f s (states %s)" % [r["turned"], r["states"].keys()])
	_expect(r["states"].has(&"alert"), "the turn opens with the threat display")
	r = await _run_for(c, player, 8.0, 0.0, seen)
	_expect(r["attacked"], "then it fights (states %s)" % [r["states"].keys()])
	# 3. Badly hurt it runs again: chased into a fight once more, then hurt to 20 % while it fights.
	c.queue_free()
	await physics_frame
	c = _spawn(host, player, Vector3(0, 0.1, -12.0), Vector3(0, 0.1, -40.0), false)
	player.global_position = Vector3(0, 0.9, 0)
	seen = {}
	c.brain.tactic.connect(func(k: StringName) -> void: seen[k] = true)
	await physics_frame
	c.brain._spot(player)
	r = await _run_for(c, player, 12.0, 7.0, seen)
	var was_fighting: bool = c.brain.cornered.fighting()
	c.health.hp = c.health.max_hp * 0.2
	r = await _run_for(c, player, 2.0, 0.0, seen)
	_expect(was_fighting and r["states"].has(&"flee") and not c.brain.cornered.fighting(), "under 30 %% HP it runs again (fighting before: %s, states %s)" % [was_fighting, r["states"].keys()])
	root.get_node("Game").god_mode = false
	host.free()
	await physics_frame
