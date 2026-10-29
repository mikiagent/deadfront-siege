extends SceneTree
## ZEBRACERATOPS (pack_mule tactics), seeded and frame-locked like t_swarm, against a stationary survivor:
## a Brave herd lowers its head (display) and then horn-charges, a default zebra flees on sight and only
## fights after three hits, a Timid one never fights back, a hit herdmate rallies the herd (defend), a
## sidestepped charge misses and staggers, the hind kick fires only with the prey behind it, and a
## grazer stands down once the prey is past guard_m.
## Usage: godot --headless --path game --script res://tests/t_zebra.gd  -> "[t_zebra] PASS"

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
	get_root().get_node("Game").time_of_day = 0.4  # daytime: grazers asleep at night would not react
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_zebra] FAIL %s" % msg)
	else:
		print("[t_zebra] ok %s" % msg)

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
	box.size = Vector3(120, 1, 120)
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
	var tac: Dictionary = load("res://scripts/creatures/brains/tactical_brain.gd").tactics_for(&"pack_mule")
	_expect(not tac.is_empty(), "pack_mule has a tactics profile")

	# 1. Brave herd: head-lowering display, then the horn charge.
	var brave := _herd(3, 41, &"brave", Vector3(0, 0.1, -6))
	_expect(brave[0].brain.get_script().get_global_name() == &"TacticalBrain", "zebraceratops gets the TacticalBrain")
	var log := _listen(brave)
	for c in brave:
		c.brain.on_aggro(player)  # spotted (no damage)
	await _sim(3.0)
	_expect(log.count(&"display") >= 1 and not log.has(&"charge"), "Brave: it holds its ground with a head-lowering display while she keeps her distance (%s)" % [_head(log)])
	player.global_position = Vector3(0, 0.9, -3.0)  # she walks in: inside display_charge_m
	var hits := [0]
	for c in brave:
		c.brain.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void:
			if clip == &"charge":
				hits[0] += 1)
	await _sim(20.0)
	var first_charge := log.find(&"charge")
	_expect(first_charge > 0 and log.slice(0, first_charge).has(&"display"), "Brave: she walks in and the display leads into the charge")
	_expect(log.count(&"charge") >= 3, "Brave herd charges (%d charges in 21 s)" % log.count(&"charge"))
	_expect(hits[0] >= 1, "a charge lands a horn hit (%d)" % hits[0])
	_expect(not log.has(&"flee"), "Brave herd does not run from the survivor")
	_free(brave)

	# 2. A default (Loyal) zebra flees on sight and fights back only after three hits.
	var calm = _herd(1, 0, &"loyal", Vector3(0, 0.1, -6))[0]
	var clog := _listen([calm])
	calm.brain.on_aggro(player)
	await _sim(1.5)
	_expect(calm.brain.state == &"flee" and not clog.has(&"charge"), "default: flees on sight (state %s)" % calm.brain.state)
	for i in 3:
		calm.health.take_damage(5.0, player)
	await _sim(8.0)
	_expect(clog.has(&"charge"), "default: three hits provoke it into charging (%s)" % [_head(clog)])
	_free([calm])

	# 3. Timid: three hits still only make it run.
	var timid = _herd(1, 0, &"timid", Vector3(0, 0.1, -6))[0]
	var tlog := _listen([timid])
	timid.brain.on_aggro(player)
	for i in 3:
		timid.health.take_damage(5.0, player)
	var fled := false
	for i in 8:
		await _sim(0.5)
		fled = fled or timid.brain.state == &"flee"
	_expect(fled and not tlog.has(&"charge") and not timid.brain._provoked(), "Timid: hit three times it still only flees (state %s, %s)" % [timid.brain.state, _head(tlog)])
	_free([timid])

	# 4. Herd defence: one is hit, the herd turns on the attacker; the hurt one runs.
	var herd := _herd(3, 42, &"loyal", Vector3(0, 0.1, -9))
	var hlog := _listen(herd)
	var hurt = herd[0]
	hurt.health.take_damage(5.0, player)
	await _sim(1.0)
	var defenders := 0
	for c in herd:
		if c != hurt and c.brain.attack_target == player and c.brain._provoked():
			defenders += 1
	_expect(hlog.count(&"defend") >= 2 and defenders == 2, "a hit herdmate rallies the other two (%d defend, %d provoked)" % [hlog.count(&"defend"), defenders])
	_expect(hurt.brain.state == &"flee", "the hurt one runs (state %s)" % hurt.brain.state)
	await _sim(8.0)
	_expect(hlog.has(&"charge"), "the defenders charge (%s)" % [_head(hlog)])
	_free(herd)

	# 5. A sidestepped charge misses and leaves it staggered.
	var miss = _herd(1, 0, &"brave", Vector3(0, 0.1, -12))[0]
	var mlog := _listen([miss])
	miss.brain.attack_target = player
	miss.brain._provoked_until = miss.brain._now_s() + 30.0
	miss.brain._start_charge()
	await _sim(0.3)
	player.global_position = Vector3(6, 0.9, 0)  # the sidestep
	var staggered := false
	for i in 30:
		await _sim(0.1)
		staggered = staggered or miss.stagger_left > 0.5
		if mlog.has(&"charge_miss"):
			break
	_expect(mlog.has(&"charge_miss") and not mlog.has(&"charge_hit") and staggered, "a sidestepped charge misses and staggers it (%s)" % [_head(mlog)])
	player.global_position = Vector3(0, 0.9, 0)
	_free([miss])
	await physics_frame

	# 6. Hind kick: only with the prey behind it, at point blank.
	var k = _herd(1, 0, &"brave", Vector3(0, 0.1, 1.8))[0]
	k.brain.attack_target = player
	k.brain._provoked_until = k.brain._now_s() + 30.0
	k.look_at(Vector3(0, 0.1, 10), Vector3.UP)  # facing away: the survivor is behind it
	var d: float = k.brain._flat_dist(player)
	var behind_ok: bool = k.brain.attack_available(&"kick", d)
	k.look_at(Vector3(0, 0.1, -10), Vector3.UP)
	var front_ok: bool = k.brain.attack_available(&"kick", d)
	_expect(behind_ok and not front_ok, "kick only with the prey behind (behind %s, in front %s)" % [behind_ok, front_ok])
	k.look_at(Vector3(0, 0.1, 10), Vector3.UP)
	var kicked := [0]
	k.brain.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void:
		if clip == &"kick":
			kicked[0] += 1
			print("[t_zebra] kick x%.2f" % m))
	var hp0: float = player.vitals.health
	_expect(k.brain._strike(d, ["kick"]), "the kick starts")
	await _sim(1.5)
	_expect(kicked[0] == 1 and player.vitals.health < hp0, "the kick lands once on the survivor (%d, hp %.0f -> %.0f)" % [kicked[0], hp0, player.vitals.health])
	_free([k])

	# 7. Guard: past guard_m from home a defender stands down.
	var g = _herd(1, 0, &"loyal", Vector3(0, 0.1, -6))[0]
	var glog := _listen([g])
	for i in 3:
		g.health.take_damage(5.0, player)
	await _sim(0.5)
	var engaged: bool = g.brain._provoked()
	# She backs off past guard_m from its home; it followed her (still inside its leash).
	g.global_position = g.spawn_home + Vector3(float(tac.get("guard_m", 16.0)) - 6.0, 0, 0)
	player.global_position = g.spawn_home + Vector3(float(tac.get("guard_m", 16.0)) + 1.0, 0.8, 0)
	await _sim(1.0)
	_expect(engaged and not g.brain._provoked() and glog.has(&"stand_down"), "past guard_m it stands down (engaged %s, provoked now %s, %s)" % [engaged, g.brain._provoked(), _head(glog)])
	player.global_position = Vector3(0, 0.9, 0)
	_free([g])

	load("res://scripts/combat/combat_tuning.gd").reset_overrides()
	if failures.is_empty():
		print("[t_zebra] PASS")
		quit(0)
	else:
		print("[t_zebra] FAIL %d" % failures.size())
		quit(1)

func _keep_alive() -> void:
	player.vitals.max_health = 1000000.0
	if player.vitals.health < 1000.0:
		player.vitals.health = player.vitals.effective_max_health()
	player.vitals.dead = false
	player.dead = false

## n zebraceratops as one herd (pack_id 0 = alone), one nature, seeded.
func _herd(n: int, pack_id: int, nature: StringName, at: Vector3) -> Array:
	var out: Array = []
	for i in n:
		var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
		host.add_child(c)
		c.global_position = at + Vector3(2.5 * float(i) - 2.5 * float(n - 1) * 0.5, 0.0, 0.0)
		seed(20261028 + i)
		var iv := RandomNumberGenerator.new()
		iv.seed = 20261028 + i
		c.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv)
		c.spawn(data.creature(&"zebraceratops"), &"", pack_id if n > 1 else 0, null, 0, nature)
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		c.brain.rng.seed = 20261028 + i
		c.brain._circle_sign = 1.0
		c.brain._flank_sign = 1.0
		out.append(c)
	load("res://scripts/creatures/brains/pack_index.gd").invalidate()
	return out

func _listen(cs: Array) -> Array:
	var log: Array = []
	for c in cs:
		c.brain.tactic.connect(func(kind: StringName) -> void: log.append(kind))
	return log

func _head(log: Array) -> Array:
	return log.slice(0, 14)

## secs of simulated time (physics steps at TIME_SCALE); the survivor cannot die.
func _sim(secs: float) -> void:
	Engine.time_scale = TIME_SCALE
	var step := 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	var n := int(round(secs / step))
	var f0 := Engine.get_physics_frames()
	while Engine.get_physics_frames() - f0 < n:
		await physics_frame
		_keep_alive()
	Engine.time_scale = 1.0

func _free(cs: Array) -> void:
	for c in cs:
		if is_instance_valid(c):
			c.queue_free()
	await physics_frame
