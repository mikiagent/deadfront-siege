extends SceneTree
## STYRACOSAURUS (horned_charger tactics), seeded and frame-locked like t_zebra, against a stationary
## survivor: a Brave styracosaurus holds its ground with a head-lowering display and then horn-charges
## on a locked line, a landed charge (a ram) shoves her back along the line, a sidestepped charge misses
## and staggers it, the point-blank finisher is the sweeping horn swipe (attack_heavy, heavier than the
## bite), and it does not flee above 25% HP. Triceratops shares the archetype (no model; stand-in).
## Usage: godot --headless --path game --script res://tests/t_styraco.gd -> "[t_styraco] PASS"

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
	get_root().get_node("Game").debug_overlay = true  # ai chatter in the log (leash, disengage)
	get_root().get_node("Game").time_of_day = 0.4  # daytime: grazers asleep at night would not react
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_styraco] FAIL %s" % msg)
	else:
		print("[t_styraco] ok %s" % msg)

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
	var tac: Dictionary = load("res://scripts/creatures/brains/tactical_brain.gd").tactics_for(&"horned_charger")
	_expect(not tac.is_empty(), "horned_charger has a tactics profile")

	# 1. Brave: head-lowering display while she keeps her distance, then the horn charge.
	var brave := _herd(1, 0, &"brave", Vector3(0, 0.1, -8))
	_expect(brave[0].brain.get_script().get_global_name() == &"TacticalBrain", "styracosaurus gets the TacticalBrain (horned_charger tactics)")
	var log := _listen(brave)
	for c in brave:
		c.brain.on_aggro(player)  # spotted (no damage)
	await _sim(3.5)
	_expect(log.count(&"display") >= 1 and not log.has(&"charge"), "Brave: it holds its ground with a head-lowering display while she keeps her distance (%s)" % [_head(log)])
	player.global_position = Vector3(0, 0.9, -3.5)  # she walks in: inside display_charge_m
	var hits := [0]
	for c in brave:
		c.brain.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void:
			if clip == &"charge":
				hits[0] += 1)
	await _sim(20.0)
	var first_charge := log.find(&"charge")
	_expect(first_charge > 0 and log.slice(0, first_charge).has(&"display"), "Brave: she walks in and the display leads into the charge")
	_expect(hits[0] >= 1, "a charge lands a horn hit (%d)" % hits[0])
	_expect(not log.has(&"flee"), "Brave styracosaurus does not run from the survivor")
	_free(brave)
	# A clean slate for the direct-charge sections: clear the knockdown and the auto-retaliation
	# the first fight left on her, so a charge starts from a known pose.
	player.statuses.clear_all()
	player.anim.release_knockdown()
	if player.hunt:
		player.hunt.stop()
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	await physics_frame

	# 2. The charge is a ram (owner 2026-10-29, pack_mule rule): a landed one shoves her back along its line.
	#    The survivor must be live for the sim to slide her (a disabled body cannot be pushed).
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	var ram = _herd(1, 0, &"brave", Vector3(0, 0.1, -9))[0]
	var rlog := _listen([ram])
	var at_hit := [Vector3.INF]
	var line := [Vector3.ZERO]  # captured at impact: _charge_dir is only set inside _start_charge
	ram.brain.tactic.connect(func(kind: StringName) -> void:
		if kind == &"charge_hit":
			at_hit[0] = player.global_position
			line[0] = ram.brain._charge_dir)
	ram.brain.attack_target = player
	ram.brain._provoked_until = ram.brain._now_s() + 30.0
	# The impact is one accuracy roll (force_accuracy = 1.0 makes every roll land, but the draw
	# order differs per run): retry from a fresh seed until a charge lands, then measure the shove.
	var attempts := 0
	while at_hit[0] == Vector3.INF and attempts < 4:
		attempts += 1
		if ram.brain.attack_target == null:  # a leash break between tries nulls it: re-aggro
			ram.brain.attack_target = player
			ram.brain.flight.reacquire_at = 0.0
			ram.brain._provoked_until = ram.brain._now_s() + 30.0
		print("[t_styraco] try %d: ram=(%.1f,%.1f) player=(%.1f,%.1f) dist=%.1f aggR=%.1f tgt=%s" % [attempts, ram.global_position.x, ram.global_position.z, player.global_position.x, player.global_position.z, ram.brain._flat_dist(player), ram.brain.aggro_radius(), ram.brain.attack_target != null])
		ram.brain._start_charge()
		for i in 40:
			await _sim(0.1)
			if at_hit[0] != Vector3.INF:
				break
			player.global_position = Vector3(0, 0.9, 0)  # pinned: she must be a stationary target
			player.velocity = Vector3.ZERO
	_expect(rlog.has(&"charge_hit"), "the ram lands on a stationary survivor (%d tries, %s)" % [attempts, _head(rlog)])
	var pushed_s := float(tac.get("charge_shove_stagger_s", 0.6))
	await _sim(pushed_s + 0.2)
	var moved: float = (player.global_position - at_hit[0]).dot(line[0]) if at_hit[0] != Vector3.INF else 0.0
	_expect(moved >= 0.6 * float(tac.get("charge_shove_m", 2.5)), "a landed ram shoves her back along its line (%.2f m, want ~%.1f; %s)" % [moved, float(tac.get("charge_shove_m", 2.5)), _head(rlog)])
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.velocity = Vector3.ZERO
	_free([ram])
	await physics_frame

	# 3. A sidestepped charge misses and leaves it staggered.
	var miss = _herd(1, 0, &"brave", Vector3(0, 0.1, -12))[0]
	var mlog := _listen([miss])
	miss.brain.attack_target = player
	miss.brain._provoked_until = miss.brain._now_s() + 30.0
	miss.brain._start_charge()
	await _sim(0.1)
	player.global_position = Vector3(7, 0.9, 0)  # the sidestep
	var staggered := false
	for i in 40:
		await _sim(0.1)
		staggered = staggered or miss.stagger_left > 0.5
		if mlog.has(&"charge_miss"):
			break
	# The miss must come before any hit: a re-engage that later catches her at the new spot is not
	# the sidestep dodge working, it is the charge being repeated. (The miss already staggered it.)
	var hit_i := mlog.find(&"charge_hit")
	var miss_i := mlog.find(&"charge_miss")
	var miss_first := miss_i >= 0 and (hit_i < 0 or miss_i < hit_i)
	_expect(miss_first and staggered, "a sidestepped charge misses and staggers it (miss %s, %s)" % [miss_first, _head(mlog)])
	miss.brain.attack_target = null
	player.global_position = Vector3(0, 0.9, 0)
	_free([miss])
	await physics_frame

	# 4. Point blank, prey in front: the sweeping horn swipe (attack_heavy), heavier than the bite.
	player.statuses.clear_all()
	player.anim.release_knockdown()
	if player.hunt:
		player.hunt.stop()
	var swipe = _herd(1, 0, &"brave", Vector3(0, 0.1, -1.8))[0]  # well inside reach_to (2.4 m)
	swipe.brain.attack_target = player
	swipe.brain._provoked_until = swipe.brain._now_s() + 30.0
	swipe.look_at(Vector3(0, 0.1, -10), Vector3.UP)  # the survivor in front of it
	var heavy_hits := [0.0]
	swipe.brain.tactic_hit.connect(func(clip: StringName, _i: int, m: float) -> void:
		if clip == &"attack_heavy":
			heavy_hits[0] = m)
	# _keep_alive refills her every frame inside _sim, so hp equality proves nothing: count the
	# landed hits through the vitals' damaged signal instead (one signal per landed hit).
	var dmg_taken := [0]
	player.vitals.damaged.connect(func() -> void: dmg_taken[0] += 1)
	_expect(swipe.brain._strike(swipe.brain._flat_dist(player), ["heavy"]), "the horn swipe starts at point blank")
	await _sim(2.5)
	_expect(heavy_hits[0] >= float(tac.get("charge_mult", 1.8)), "the swipe resolves as the heavy (x%.2f, heavy_mult %.1f)" % [heavy_hits[0], float(tac.get("heavy_mult", 2.2))])
	_expect(dmg_taken[0] >= 1, "the swipe lands on the survivor (%d hits)" % dmg_taken[0])
	_free([swipe])

	# 5. No flee above 25% HP: hurt to 60% it keeps fighting; only below retreat_frac does it run.
	var hurt = _herd(1, 0, &"brave", Vector3(0, 0.1, -6))[0]
	var hlog := _listen([hurt])
	for i in 4:
		hurt.health.take_damage(hurt.health.max_hp * 0.1, player)  # 60% left
	await _sim(0.5)
	var engaged: bool = hurt.brain._provoked()
	var frac: float = hurt.brain.retreat_frac()
	await _sim(4.0)
	_expect(engaged and frac <= 0.251 and hurt.brain.state != &"flee" and not hlog.has(&"flee"), "at 60%% HP it does not flee (provoked %s, retreat_frac %.2f, state %s, %s)" % [engaged, frac, hurt.brain.state, _head(hlog)])
	hurt.health.hp = hurt.health.max_hp * (frac * 0.5)  # badly hurt: below the threshold
	var fled := false
	for i in 12:
		await _sim(0.5)
		fled = fled or hurt.brain.state == &"flee"
	_expect(fled, "below retreat_frac (%.2f) it flees (state %s)" % [frac, hurt.brain.state])
	_free([hurt])

	# 6. Triceratops shares the archetype and gets the same brain (no model: the box stand-in).
	var tri = _herd(1, 0, &"brave", Vector3(0, 0.1, -8), &"triceratops")[0]
	var tlog := _listen([tri])
	_expect(tri.brain.get_script().get_global_name() == &"TacticalBrain", "triceratops gets the same horned_charger brain")
	tri.brain.on_aggro(player)
	await _sim(2.5)
	_expect(tlog.count(&"display") >= 1, "triceratops (stand-in) displays like the styracosaurus (%s)" % [_head(tlog)])
	_free([tri])

	load("res://scripts/combat/combat_tuning.gd").reset_overrides()
	if failures.is_empty():
		print("[t_styraco] PASS")
		quit(0)
	else:
		print("[t_styraco] FAIL %d" % failures.size())
		quit(1)

func _keep_alive() -> void:
	player.vitals.max_health = 1000000.0
	if player.vitals.health < 1000.0:
		player.vitals.health = player.vitals.effective_max_health()
	player.vitals.dead = false
	player.dead = false

## n creatures as one herd (pack_id 0 = alone), one nature, seeded; id defaults to the styracosaurus.
func _herd(n: int, pack_id: int, nature: StringName, at: Vector3, id: StringName = &"styracosaurus") -> Array:
	var out: Array = []
	for i in n:
		var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
		host.add_child(c)
		c.global_position = at + Vector3(2.5 * float(i) - 2.5 * float(n - 1) * 0.5, 0.0, 0.0)
		seed(20261028 + i)
		var iv := RandomNumberGenerator.new()
		iv.seed = 20261028 + i
		c.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv)
		c.spawn(data.creature(id), &"", pack_id if n > 1 else 0, null, 0, nature)
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
