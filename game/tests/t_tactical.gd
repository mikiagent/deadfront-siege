extends SceneTree
## TACTICS (owner 2026-10-28): a wild deinonychus against a stationary survivor circles, feints, lunges,
## pounces with a telegraph, chains the chomp combo and backs off when hurt; bites respect their cooldown
## and specials need energy. Player side: hurt = a stun exactly the hurt clip long, walk/run after it,
## no chain-stun inside the immunity window; tackle and kick land and respect their cooldowns.
## Usage: godot --headless --path game --script res://tests/t_tactical.gd  -> "[t_tactical] PASS"

const SIM_S := 45.0
const TIME_SCALE := 2.0

var failures: Array[String] = []
var _started := false
var host: Node3D
var data: Node
var player
var dino
var _sim_t := 0.0
var _tactics: Array = []  ## [sim_t, kind]
var _bites: Array[float] = []
var _hits: Array = []  ## [sim_t, clip, index, mult]
var _combo_start := -1.0
var _combo_hits: Array = []  ## [t since combo start, index, mult] of the first combo
var _states: Dictionary = {}

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
		print("[t_tactical] FAIL %s" % msg)
	else:
		print("[t_tactical] ok %s" % msg)

func _run() -> void:
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
	if not "--only-ai" in OS.get_cmdline_user_args():
		await _test_player_stun()
		await _test_tackle_kick()
	player.process_mode = Node.PROCESS_MODE_DISABLED  # the stationary target: no auto-attack, no walking
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	dino = _spawn(&"deinonychus", Vector3(0, 0.1, 9), &"loyal")
	await _test_fight()
	_test_energy_gate()
	await _test_retreat()
	_test_natures()
	load("res://scripts/combat/combat_tuning.gd").reset_overrides()
	if failures.is_empty():
		print("[t_tactical] PASS")
		quit(0)
	else:
		print("[t_tactical] FAIL %d" % failures.size())
		quit(1)

func _spawn(id: StringName, at: Vector3, nature: StringName):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id), &"", 0, null, 0, nature)
	return c

func _keep_player_alive() -> void:
	player.vitals.max_health = 1000000.0  # a bite must never kill the stationary target
	player.vitals.health = player.vitals.effective_max_health()
	player.vitals.dead = false
	player.dead = false

func _test_fight() -> void:
	var b = dino.brain
	_expect(b.get_script().get_global_name() == &"TacticalBrain", "deinonychus gets the TacticalBrain (pack_flanker tactics)")
	_expect(dino.anim.has_state(&"bite_combo"), "deinonychus loads the bite_combo clip")
	b.tactic.connect(func(k: StringName) -> void:
		_tactics.append([_sim_t, k])
		if k == &"combo" and _combo_start < 0.0:
			_combo_start = _sim_t)
	b.tactic_hit.connect(func(clip: StringName, i: int, m: float) -> void:
		_hits.append([_sim_t, clip, i, m])
		if clip == &"bite_combo" and _combo_start >= 0.0 and _combo_hits.size() < 3:
			_combo_hits.append([_sim_t - _combo_start, i, m]))
	dino.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"attack_primary":
			_bites.append(_sim_t))
	_keep_player_alive()
	b.on_aggro(player)
	Engine.time_scale = TIME_SCALE
	var prev_ang := NAN
	var circle_ang := 0.0
	var hp0: float = dino.health.max_hp
	while _sim_t < SIM_S:
		await physics_frame
		var dt := get_root().get_physics_process_delta_time()  # already scaled by Engine.time_scale
		_sim_t += dt
		_keep_player_alive()
		dino.health.hp = hp0  # no retreat during the manoeuvre census
		_states[b.state] = true
		var v: Vector3 = dino.global_position - player.global_position
		var ang := atan2(v.x, v.z)
		if b.state == &"circle" and not is_nan(prev_ang):
			circle_ang += absf(angle_difference(prev_ang, ang))
		prev_ang = ang
	Engine.time_scale = 1.0
	var kinds := {}
	for row in _tactics:
		kinds[row[1]] = int(kinds.get(row[1], 0)) + 1
	print("[t_tactical] census %s states=%s circle_rad=%.2f bites=%d hits=%d" % [kinds, _states.keys(), circle_ang, _bites.size(), _hits.size()])
	var bite_cd: float = float(b.tac.get("bite_cd", 1.6))
	var min_gap := INF
	for i in range(1, _bites.size()):
		min_gap = minf(min_gap, _bites[i] - _bites[i - 1])
	_expect(_bites.size() >= 2, "bites landed (%d)" % _bites.size())
	_expect(min_gap >= bite_cd - 0.05, "never bites twice inside its %.1fs bite cooldown (min gap %.2fs)" % [bite_cd, min_gap])
	_expect(circle_ang > PI, "circles the target (%.2f rad of travel around it while circling)" % circle_ang)
	_expect(int(kinds.get(&"lunge", 0)) >= 1, "lunges (%d)" % int(kinds.get(&"lunge", 0)))
	_expect(int(kinds.get(&"pounce", 0)) >= 1, "pounces (%d)" % int(kinds.get(&"pounce", 0)))
	_expect(int(kinds.get(&"combo", 0)) >= 1, "chomp combo (%d)" % int(kinds.get(&"combo", 0)))
	# Telegraph precedes the leap's hit by at least the telegraph time.
	var tele: float = float(b.tac.get("pounce_telegraph_s", 0.8))
	var pounce_t := -1.0
	var gap_ok := false
	for row in _tactics:
		if row[1] == &"pounce" and pounce_t < 0.0:
			pounce_t = row[0]
		elif row[1] == &"leap" and pounce_t >= 0.0:
			gap_ok = row[0] - pounce_t >= tele - 0.04
			print("[t_tactical] pounce windup->leap %.2fs (telegraph %.2fs)" % [row[0] - pounce_t, tele])
			break
	_expect(gap_ok, "pounce telegraph precedes the leap by >= %.2fs" % tele)
	# Combo: three bites at the hit fracs, rising damage.
	var fracs: Array = data.anim_events["clips"]["bite_combo"]["hit_fracs"]
	var clip_len: float = dino.anim.player.get_animation(&"bite_combo").length / maxf(0.01, dino.anim.cadence(&"bite_combo"))
	_expect(_combo_hits.size() == 3, "combo lands 3 damage events (%d)" % _combo_hits.size())
	if _combo_hits.size() == 3:
		var rising: bool = _combo_hits[0][2] < _combo_hits[1][2] and _combo_hits[1][2] < _combo_hits[2][2]
		_expect(rising, "combo damage rises %s" % str(_combo_hits))
		for i in 3:
			var want: float = float(fracs[i]) * clip_len
			_expect(absf(_combo_hits[i][0] - want) <= 0.12, "combo bite %d at %.2fs (hit frac %.3f of %.2fs = %.2fs)" % [i + 1, _combo_hits[i][0], fracs[i], clip_len, want])

func _test_energy_gate() -> void:
	var b = dino.brain
	dino.energy = 0.0
	dino.winded = true
	var specials := 0
	for i in 60:
		b._set_state(&"circle")
		b._cd.clear()
		b._choose(6.0)
		if b.state == &"pounce" or (b.state == &"lunge" and b._lunge_into == &"bite_combo"):
			specials += 1
	_expect(specials == 0, "refuses pounce and combo with no energy (%d starts)" % specials)
	dino.energy = dino.energy_max
	dino.winded = false
	b._set_state(&"circle")

func _test_retreat() -> void:
	var b = dino.brain
	b._retreat_cd = 0.0
	dino.health.hp = dino.health.max_hp * (b.retreat_frac() * 0.5)
	var saw := false
	for i in 30:
		await physics_frame
		_keep_player_alive()
		if b.state == &"retreat":
			saw = true
			break
	_expect(saw, "retreats below %.0f%% HP" % (b.retreat_frac() * 100.0))
	var wide_ok: bool = b.ring_m() > float(b.tac.get("ring_m", 5.5))
	_expect(wide_ok, "circles wider after a retreat (ring %.1fm)" % b.ring_m())

func _test_natures() -> void:
	var calm = _spawn(&"deinonychus", Vector3(20, 0.1, 20), &"loyal")
	var mad = _spawn(&"deinonychus", Vector3(-20, 0.1, 20), &"aggressive")
	var shy = _spawn(&"deinonychus", Vector3(20, 0.1, -20), &"timid")
	var brave = _spawn(&"deinonychus", Vector3(-20, 0.1, -20), &"brave")
	calm.brain._start_cd(&"pounce")
	mad.brain._start_cd(&"pounce")
	_expect(mad.brain.cooldown_left(&"pounce") < calm.brain.cooldown_left(&"pounce"), "Aggressive: shorter cooldowns")
	calm.brain.attack_target = player
	shy.brain.attack_target = player
	_expect(shy.brain.ring_m() > calm.brain.ring_m(), "Timid: wider circle")
	_expect(shy.brain.retreat_frac() > calm.brain.retreat_frac() and brave.brain.retreat_frac() < calm.brain.retreat_frac(), "Timid retreats earlier, Brave later")
	for c in [calm, mad, shy, brave]:
		c.queue_free()

## Hurt = a hard stun exactly the hurt clip long; then movement plays walk/run; a second bite inside the
## immunity window damages but does not re-stun.
func _test_player_stun() -> void:
	var sim = player.sim
	var clip_len: float = sim.hurt_stun_seconds()
	_expect(clip_len > 0.1, "hurt clip has a length (%.2fs)" % clip_len)
	player.receive_creature_hit(null, &"attack_primary")
	_expect(is_equal_approx(sim._stagger_left, clip_len), "hurt stun == hurt clip length (%.2f vs %.2f)" % [sim._stagger_left, clip_len])
	_expect(player.anim.current_clip == &"hit_react", "hurt plays the hurt clip")
	var hp_before: float = player.vitals.health
	player.vitals.take_damage(5.0)
	sim._stagger_left = 0.05
	player.receive_creature_hit(null, &"attack_primary")
	_expect(sim._stagger_left <= 0.05 + 0.001, "a second bite inside the immunity window does not re-stun")
	_expect(player.vitals.health < hp_before, "the second bite still damages")
	var t0 := Time.get_ticks_msec()
	while sim._stagger_left > 0.0 and Time.get_ticks_msec() - t0 < 3000:
		await physics_frame
	Input.action_press("move_up")
	for i in 12:
		await physics_frame
	Input.action_release("move_up")
	_expect(player.anim.current_clip in [&"walk", &"run"], "moving after the stun plays walk/run (got %s)" % player.anim.current_clip)
	for i in 30:
		await physics_frame
	player.vitals.health = player.vitals.effective_max_health()

func _test_tackle_kick() -> void:
	var raptor = _spawn(&"velociraptor", player.global_position + Vector3(0, 0, -1.6), &"loyal")
	raptor.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	var hunt = player.hunt
	hunt.start(raptor)
	var hp0: float = raptor.health.hp
	hunt.tackle()
	_expect(raptor.health.hp < hp0, "tackle lands (hp %.0f -> %.0f)" % [hp0, raptor.health.hp])
	_expect(hunt.cooldown_left(&"tackle") > 0.0, "tackle starts its cooldown")
	_expect(raptor.stagger_left > 0.0, "tackle staggers the target")
	var hp1: float = raptor.health.hp
	hunt.tackle()
	_expect(is_equal_approx(raptor.health.hp, hp1), "tackle refused on cooldown")
	for i in 60:  # past the tactic lock
		await physics_frame
	player.vitals.energy = player.vitals.effective_max_energy()
	raptor.global_position = player.global_position + Vector3(0, 0, -1.6)
	raptor.stagger_left = 0.0
	hp1 = raptor.health.hp
	hunt.kick()
	_expect(raptor.health.hp < hp1, "kick lands (hp %.0f -> %.0f)" % [hp1, raptor.health.hp])
	_expect(hunt.cooldown_left(&"kick") > 0.0, "kick starts its cooldown")
	_expect(raptor.stagger_left > 0.0, "kick staggers the target")
	var hp2: float = raptor.health.hp
	hunt.kick()
	_expect(is_equal_approx(raptor.health.hp, hp2), "kick refused on cooldown")
	hunt.stop()
	raptor.queue_free()
	await physics_frame
