extends SceneTree
## PACHY (owner 2026-10-31: "the Pachy's model is completely ruined. the legs are mangled. And the color is off"):
## the rebuilt pachycephalosaurus draws its rigged Tripo v2 model with every clip, stands 1.8 m, keeps its feet on
## their prints in the standing clips, leads with the dome at the butt's hit frame, and in a fight its brain picks
## the stomp in front, the hip check behind and the head-down charge, each landing on the survivor; the coloration
## roll stays a small natural range.
## Run: Godot --headless --path game --script res://tests/t_sp_pachycephalosaurus.gd  -> "[t_sp_pachy] PASS", exit 0.

const ID := &"pachycephalosaurus"
const EXTRA_CLIPS: Array[StringName] = [&"walk_back", &"strafe_left", &"strafe_right"]
const TOES := ["Toe.L", "Toe.R"]
const GROUND_TOL := 0.05  ## m: the lowest toe stays this close to its rest height in standing clips
const SLIDE_TOL := 0.08  ## m: a toe on the ground may not slide further than this

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
	print("[t_sp_pachy] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _run() -> void:
	_test_view()
	_test_colour()
	await _test_fight()
	if failures.is_empty():
		print("[t_sp_pachy] PASS")
		quit(0)
	else:
		print("[t_sp_pachy] FAIL %d" % failures.size())
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
	view.apply_coloration(load("res://scripts/creatures/creature_coloration.gd").neutral())
	_expect(view.using_glb and view.rig != null, "draws the rigged GLB")
	_expect(_boxes(view) == 0, "no box/cylinder placeholder meshes")
	if view.rig == null:
		view.free()
		return
	var clips: Array = def.pipeline.get("clips", [])
	_expect(clips.size() >= 13, "species lists its clips (%d)" % clips.size())
	for clip in clips + EXTRA_CLIPS:
		_expect(view.rig.has_clip(StringName(clip)), "clip %s loaded" % clip)
	var sk: Skeleton3D = view.rig.skeleton
	for b in ["Jaw", "Head", "Hips", "Thigh.L", "Shin.L", "Metatarsal.L", "Toe.L", "Thigh.R", "Shin.R", "Metatarsal.R", "Toe.R"]:
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
	_expect(absf(aabb.size.y - 1.8) < 0.1, "dome top at 1.8 m (%.2f)" % aabb.size.y)
	var fwd: Vector3 = -(view as Node3D).global_transform.basis.z.normalized()
	var ap: AnimationPlayer = view.rig.anim_player
	sk.reset_bone_poses()
	var rest := INF
	for b in TOES:
		rest = minf(rest, _bone(sk, view, b, true).y)
	var head_rest: float = _bone(sk, view, "Head", true).dot(fwd)
	# Standing clips: one toe always on the floor, and a toe on the floor stays on its print (no gliding).
	for clip in [&"idle", &"alert", &"attack_primary", &"attack_heavy", &"kick", &"hit_react", &"feed"]:
		sk.reset_bone_poses()
		ap.play(clip)
		var a := ap.get_animation(clip)
		var worst := 0.0
		var slide := 0.0
		var prints := {}
		for k in 25:
			ap.seek(a.length * float(k) / 24.0, true)
			var lo := INF
			for b in TOES:
				var p := _bone(sk, view, b)
				lo = minf(lo, p.y)
				if p.y - rest < 0.03:
					if not prints.has(b):
						prints[b] = p
					slide = maxf(slide, Vector2(p.x - prints[b].x, p.z - prints[b].z).length())
				else:
					prints.erase(b)
			worst = maxf(worst, absf(lo - rest))
		_expect(worst <= GROUND_TOL and slide <= SLIDE_TOL, "%s: feet planted (lowest toe %.3f m off rest, slide %.3f m)" % [clip, worst, slide])
	# The dome is the hit: at the butt's hit frame the head has driven well forward of rest.
	sk.reset_bone_poses()
	ap.play(&"attack_primary")
	ap.seek(ap.get_animation(&"attack_primary").length * 0.42, true)
	var head_hit: float = _bone(sk, view, "Head").dot(fwd)
	_expect(head_hit - head_rest > 0.25, "attack_primary: dome driven %.2f m forward at the hit" % (head_hit - head_rest))
	view.free()

## The colour roll stays natural: hue within +-10 deg (it was +-355, clamped to +-40, before PACHY).
func _test_colour() -> void:
	var CC = load("res://scripts/creatures/creature_coloration.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst := 0.0
	var block: Dictionary = data.creature(ID).coloration
	for i in 200:
		var c = CC.roll(block, rng)
		if not c.rare:
			worst = maxf(worst, absf(c.hue_deg))
	_expect(worst <= 10.0, "hue roll within +-10 deg (worst %.1f)" % worst)

func _spawn(host: Node3D, player: Node3D, at: Vector3) -> Node:
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(ID), &"", 0, null, 0, &"aggressive")  # a timid one never fights back
	player.vitals.health = player.vitals.max_health
	c.brain.attack_target = player
	c.brain._provoked_until = c.brain._now_s() + 60.0
	return c

## In a fight: point blank in front -> stomp; prey behind -> hip check; at range -> the head-down charge with its shove.
func _test_fight() -> void:
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	var host := Node3D.new()
	root.add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_expect((data.creature(ID).tactics as Dictionary).get("point_blank", []) == ["kick", "heavy", "bite"], "species tactics merged: hip check, stomp, dome butt at point blank")
	# 1. In front, point blank: the brain's own point-blank pick is the stomp, and it lands.
	var c = _spawn(host, player, Vector3(0, 0.1, -1.9))
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	_expect(c.view.using_glb and _boxes(c.view) == 0, "a spawned pachycephalosaurus draws the GLB, no boxes")
	_expect(c.brain.tac.get("charge_shove_m", 0.0) == 3.5, "brain reads the species tactics (shove %.1f m)" % c.brain.tac.get("charge_shove_m", 0.0))
	await physics_frame
	var picked := [&""]
	var hits := []
	c.brain.attack_chosen.connect(func(m: StringName, _d: float) -> void: picked[0] = m)
	c.anim.attack_hit.connect(func(clip: StringName) -> void: hits.append(clip))
	var hp0: float = player.vitals.health
	c.brain._strike(c.brain._flat_dist(player), c.brain.tac.get("point_blank", []))
	for _f in 90:
		await physics_frame
	_expect(picked[0] == &"heavy" and &"attack_heavy" in hits, "in front: stomp picked (%s) and hits %s" % [picked[0], hits])
	_expect(player.vitals.health < hp0, "the stomp lands (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	c.queue_free()
	await physics_frame
	# 2. Behind it: the hip check.
	c = _spawn(host, player, Vector3(0, 0.1, -1.6))
	c.look_at(Vector3(0, 0.1, -6), Vector3.UP)  # facing away from her
	await physics_frame
	picked = [&""]
	hits = []
	c.brain.attack_chosen.connect(func(m: StringName, _d: float) -> void: picked[0] = m)
	c.anim.attack_hit.connect(func(clip: StringName) -> void: hits.append(clip))
	hp0 = player.vitals.health
	c.brain._strike(c.brain._flat_dist(player), c.brain.tac.get("point_blank", []))
	for _f in 60:
		await physics_frame
	_expect(picked[0] == &"kick" and &"kick" in hits, "behind: hip check picked (%s) and hits %s" % [picked[0], hits])
	_expect(player.vitals.health < hp0, "the hip check lands (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	c.queue_free()
	await physics_frame
	# 3. At range: the head-down charge rams her (charge clip, impact, shove).
	c = _spawn(host, player, Vector3(0, 0.1, -9.0))
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	await physics_frame
	var kinds := []
	c.brain.tactic.connect(func(k: StringName) -> void: kinds.append(k))
	hp0 = player.vitals.health
	c.brain._start_charge()
	for _f in 150:
		await physics_frame
		if &"charge_hit" in kinds:
			break
	_expect(&"charge_hit" in kinds, "the charge connects (%s)" % [kinds])
	_expect(c.brain.gait_clip == &"charge" and c.anim.has_state(&"charge"), "it runs the head-down charge clip")
	_expect(player.vitals.health < hp0, "the dome ram lands (hp %.0f -> %.0f)" % [hp0, player.vitals.health])
	host.free()
