extends SceneTree
## CORNERED (owner 2026-10-31: "Animals that run away from you should get territorial and attack you if you
## chase them"). BrainCornered on every brain that flees. Checks: a fleeing zebraceratops (TacticalBrain) and a
## fleeing stegosaurus (plain CreatureBrain) chased by the survivor turn and hit her within the threshold; a
## zebraceratops that is not chased never turns; badly hurt it runs again; a tactics "cornered" block overrides.
## Usage: godot --headless --path game --script res://tests/t_cornered.gd  -> "[t_cornered] PASS"

const TIME_SCALE := 2.0
const CHASE_MPS := 7.0  # a sprinting survivor (the skittish flee floor is 6.5 m/s)

var failures: Array[String] = []
var _started := false
var host: Node3D
var data: Node
var player

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").debug_overlay = false
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_cornered] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	seed(20261031)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	Engine.max_physics_steps_per_frame = 1000
	Engine.physics_jitter_fix = 0.0
	host = Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var nav := NavigationRegion3D.new()
	var nmesh := NavigationMesh.new()
	nmesh.agent_radius = 0.5
	nmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nmesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nmesh.geometry_source_group_name = &"cornered_nav"
	host.add_to_group(&"cornered_nav")
	nav.navigation_mesh = nmesh
	host.add_child(nav)
	nav.bake_navigation_mesh(false)
	await physics_frame
	await physics_frame
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED  # the test moves her
	_test_override()
	await _test_chased(&"zebraceratops", false)
	await _test_chased(&"stegosaurus", true)
	await _test_not_chased()
	await _test_weak()
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("[t_cornered] PASS")
		quit(0)
	else:
		print("[t_cornered] FAIL %d" % failures.size())
		quit(1)

func _spawn(id: StringName, at: Vector3):
	for n in host.get_children():
		if n.has_method("spawn") and n != player:
			n.queue_free()
	await physics_frame
	player.global_position = Vector3(0, 0.9, 0)
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	seed(20261031)
	var iv_rng := RandomNumberGenerator.new()
	iv_rng.seed = 20261031
	c.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv_rng)
	c.spawn(data.creature(id), &"", 0, null, 0, &"docile")
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	await physics_frame
	return c

func _keep_player_alive() -> void:
	player.vitals.max_health = 1000000.0
	player.vitals.health = player.vitals.effective_max_health()
	player.vitals.dead = false
	player.dead = false

## Runs `seconds` of sim time; with chase the survivor runs at the animal at CHASE_MPS (stopping 1.5 m short of
## its body). Returns {turned: sim s of the first turn or -1, hits: hits she took after it, states: seen}.
func _run_for(c, seconds: float, chase: bool, keep_hp: bool = true) -> Dictionary:
	var b = c.brain
	var out := {"turned": -1.0, "hits": 0, "states": {}}
	var on_hurt := func() -> void:
		if float(out.turned) >= 0.0:
			out.hits = int(out.hits) + 1
	player.vitals.damaged.connect(on_hurt)
	Engine.time_scale = TIME_SCALE
	var step := 1.0 / float(Engine.physics_ticks_per_second) * TIME_SCALE
	var t := 0.0
	var hp0: float = c.health.hp
	while t < seconds:
		await physics_frame
		t += step
		_keep_player_alive()
		if keep_hp:
			c.health.hp = hp0
		out.states[b.state] = true
		if float(out.turned) < 0.0 and b.cornered.fighting():
			out.turned = t
		if chase:
			var to: Vector3 = c.global_position - player.global_position
			to.y = 0.0
			var gap: float = to.length() - c.body_radius() - 1.5
			if gap > 0.0:
				player.global_position += to.normalized() * minf(gap, CHASE_MPS * step)
		if OS.has_environment("CORNER_TRACE"):
			print("[trace] %.2f %s d=%.1f p=%.2f m=%.1f fight=%s" % [t, b.state, b._flat_dist(player), b.cornered.pressure, b.cornered.chased_m, b.cornered.fighting()])
	Engine.time_scale = 1.0
	player.vitals.damaged.disconnect(on_hurt)
	return out

func _test_chased(id: StringName, force_flee: bool) -> void:
	var c = await _spawn(id, Vector3(0, 0.1, 7))
	var b = c.brain
	_expect(not b.cornered.cfg.is_empty(), "%s has the cornered thresholds (%s)" % [id, b.get_class()])
	if force_flee:
		# A defensive grazer flees when a hit takes past its threshold; start it running.
		b.attack_target = player
		b._set_state(&"flee")
	else:
		b._spot(player)
	var r := await _run_for(c, 18.0, true)
	var limit: float = float(b.cornered.cfg.get("pressure_s", 3.0)) + 2.5  # + the startle and the turn
	print("[t_cornered] %s chased: turned at %.2f s, %d hits on her, states %s" % [id, r.turned, r.hits, r.states.keys()])
	_expect(r.states.has(&"flee"), "%s runs first" % id)
	_expect(float(r.turned) >= 0.0 and float(r.turned) <= limit, "%s turns on its chaser within %.1f s (%.2f)" % [id, limit, r.turned])
	_expect(int(r.hits) > 0, "%s hits the survivor after turning (%d)" % [id, r.hits])

func _test_not_chased() -> void:
	var c = await _spawn(&"zebraceratops", Vector3(0, 0.1, 7))
	c.brain._spot(player)
	var r := await _run_for(c, 15.0, false)
	print("[t_cornered] zebraceratops not chased: states %s" % [r.states.keys()])
	_expect(r.states.has(&"flee"), "an unchased zebraceratops flees")
	_expect(float(r.turned) < 0.0 and not r.states.has(&"attack") and not r.states.has(&"approach"), "an unchased zebraceratops never turns on her")

func _test_weak() -> void:
	var c = await _spawn(&"zebraceratops", Vector3(0, 0.1, 7))
	var b = c.brain
	b._spot(player)
	var r := await _run_for(c, 8.0, true)
	_expect(b.cornered.fighting(), "zebraceratops is fighting before the weak check (turned %.2f)" % r.turned)
	c.health.hp = c.health.max_hp * 0.2
	var r2 := await _run_for(c, 1.0, false, true)
	_expect(not b.cornered.fighting() and r2.states.has(&"flee"), "badly hurt (20 %% HP) it runs again (states %s)" % [r2.states.keys()])

func _test_override() -> void:
	var def = data.creature(&"gallimimus")
	var keep: Dictionary = def.tactics.duplicate(true)
	def.tactics["cornered"] = {"pressure_s": 1.25}
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.spawn(def, &"", 0, null, 0, &"docile")
	var cfg: Dictionary = c.brain.cornered.cfg
	_expect(float(cfg.get("pressure_s", 0)) == 1.25 and float(cfg.get("radius_m", 0)) == 10.0,
		"a tactics cornered block overrides one threshold and keeps the defaults (%s)" % [cfg])
	def.tactics = keep
	c.queue_free()
