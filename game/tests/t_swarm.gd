extends SceneTree
## SWARM (compsognathus) tactics, seeded and frame-locked like t_tactical: a pack of four surrounds a
## stationary survivor, darts in for bites and scurries back out, the basic bite stays rare, a hurt
## one flees, a packmate's death scatters the rest, and a pack is bolder than a lone compy.
## Usage: godot --headless --path game --script res://tests/t_swarm.gd  -> "[t_swarm] PASS"

const TIME_SCALE := 2.0

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
		print("[t_swarm] FAIL %s" % msg)
	else:
		print("[t_swarm] ok %s" % msg)

func _run() -> void:
	seed(20261028)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261028
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	Engine.max_physics_steps_per_frame = 1000
	Engine.physics_jitter_fix = 0.0
	host = Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED  # a stationary target
	player.velocity = Vector3.ZERO
	var tac: Dictionary = load("res://scripts/creatures/brains/tactical_brain.gd").tactics_for(&"swarm")
	_expect(not tac.is_empty(), "the swarm archetype has a tactics profile")
	var pack := _pack(4, 77)
	_expect(pack[0].brain.get_script().get_global_name() == &"TacticalBrain", "compsognathus gets the TacticalBrain")
	var group: Dictionary = await _fight(pack, 30.0, true)
	print("[t_swarm] pack census %s" % group)
	_expect(float(group.surround_gap) < 200.0, "the pack surrounds her (largest gap between neighbours %.0f deg on average)" % group.surround_gap)
	_expect(int(group.darts) >= 8 and int(group.outs) * 2 >= int(group.darts), "darts in and scurries back out (%d darts, %d back-outs)" % [group.darts, group.outs])
	_expect(float(group.bite_share) <= float(tac.get("max_basic_share", 0.15)), "the plain bite stays rare (%.2f of attacks)" % group.bite_share)
	# Hurt: one flees.
	var hurt = pack[1]
	hurt.health.hp = hurt.health.max_hp * 0.2
	var fled := false
	for i in 30:
		await physics_frame
		_keep_alive()
		fled = fled or hurt.brain.state == &"flee"
	_expect(fled, "a hurt compy flees")
	# A packmate dies: the others scatter.
	var scattered := [0]
	for c in [pack[0], pack[2]]:
		c.brain.tactic.connect(func(k: StringName) -> void:
			if k == &"flee":
				scattered[0] += 1)
	pack[3].health.take_damage(99999.0, player)
	for i in 20:
		await physics_frame
		_keep_alive()
	_expect(scattered[0] >= 2, "a packmate's death scatters the rest (%d fled)" % scattered[0])
	for c in pack:
		if is_instance_valid(c):
			c.queue_free()
	await physics_frame
	await physics_frame
	# Alone vs in numbers: per animal, a pack of four darts more often than a lone compy.
	var lone := _pack(1, 91)
	var alone: Dictionary = await _fight(lone, 30.0, false)
	lone[0].queue_free()
	await physics_frame
	var four := _pack(4, 92)
	var bold: Dictionary = await _fight(four, 30.0, false)
	for c in four:
		c.queue_free()
	print("[t_swarm] alone %s / four %s" % [alone, bold])
	_expect(float(bold.darts_per_min_each) > float(alone.darts_per_min_each), "bolder in numbers: %.1f darts/min each in a pack of four vs %.1f alone" % [bold.darts_per_min_each, alone.darts_per_min_each])
	load("res://scripts/combat/combat_tuning.gd").reset_overrides()
	if failures.is_empty():
		print("[t_swarm] PASS")
		quit(0)
	else:
		print("[t_swarm] FAIL %d" % failures.size())
		quit(1)

func _keep_alive() -> void:
	player.vitals.max_health = 1000000.0
	player.vitals.health = player.vitals.effective_max_health()
	player.vitals.dead = false
	player.dead = false

## n compys as one pack, seeded (IVs, brain dice, flank side) so the census replays exactly.
func _pack(n: int, pack_id: int) -> Array:
	var out: Array = []
	for i in n:
		var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
		host.add_child(c)
		var ang := TAU * float(i) / float(n)
		c.global_position = Vector3(cos(ang) * 1.0, 0.1, -4.0 + sin(ang) * 1.0)  # inside a compy's short leash (perception 3.5 x 1.2)
		seed(20261028 + i)
		var iv := RandomNumberGenerator.new()
		iv.seed = 20261028 + i
		c.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv)
		c.spawn(data.creature(&"compsognathus"), &"", pack_id if n > 1 else 0, null, 0, &"loyal")
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		c.brain.rng.seed = 20261028 + i
		c.brain._circle_sign = 1.0
		c.brain._flank_sign = 1.0
		out.append(c)
	load("res://scripts/creatures/brains/pack_index.gd").invalidate()
	return out

## secs of simulated time (physics steps) on the survivor; per-member counts of darts (charges) and
## back-outs (hops), the plain-bite share, and the average largest angular gap between neighbours.
func _fight(cs: Array, secs: float, measure_ring: bool) -> Dictionary:
	var log: Array = []
	for c in cs:
		c.brain.tactic.connect(func(k: StringName) -> void: log.append(k))
		c.brain.on_aggro(player)
	Engine.time_scale = TIME_SCALE
	var step := 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	var n := int(round(secs / step))
	var f0 := Engine.get_physics_frames()
	var gap_sum := 0.0
	var gap_n := 0
	while Engine.get_physics_frames() - f0 < n:
		await physics_frame
		_keep_alive()
		for c in cs:
			c.health.hp = c.health.max_hp
		if OS.has_environment("TS_TRACE"):
			var row := ""
			for c in cs:
				row += " %s %.3f,%.3f e%.1f" % [c.brain.state, c.global_position.x, c.global_position.z, c.energy]
			print("[trace] %d%s" % [Engine.get_physics_frames() - f0, row])
		if measure_ring and Engine.get_physics_frames() - f0 > n / 3:
			var angs: Array[float] = []
			for c in cs:
				var v: Vector3 = c.global_position - player.global_position
				angs.append(atan2(v.z, v.x))
			angs.sort()
			var worst := TAU - (angs[-1] - angs[0])
			for i in range(1, angs.size()):
				worst = maxf(worst, angs[i] - angs[i - 1])
			gap_sum += rad_to_deg(worst)
			gap_n += 1
	Engine.time_scale = 1.0
	var darts := 0
	var outs := 0
	var bites := 0
	var attacks := 0
	for k in log:
		if k == &"charge":
			darts += 1
		if k == &"hop":
			outs += 1
		if k == &"bite":
			bites += 1
		if k in [&"charge", &"bite"]:
			attacks += 1
	return {"darts": darts, "outs": outs, "bite_share": float(bites) / maxf(1.0, float(attacks)),
		"surround_gap": gap_sum / maxf(1.0, float(gap_n)), "darts_per_min_each": float(darts) * 60.0 / secs / float(cs.size())}
