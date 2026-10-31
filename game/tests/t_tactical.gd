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
## Simulated time = physics steps since the census began (not accumulated, not wall clock), so a
## signal fired by a brain inside step k reads k * step whichever side of the test it runs on.
var _f0 := -1
var _step := 1.0 / 60.0
var _sim_t: float:
	get:
		return 0.0 if _f0 < 0 else float(Engine.get_physics_frames() - _f0) * _step
var _tactics: Array = []  ## [sim_t, kind]
var _bites: Array[float] = []
var _hits: Array = []  ## [sim_t, clip, index, mult]
var _combo_start := -1.0
var _combo_hits: Array = []  ## [t since combo start, index, mult] of the first combo
var _states: Dictionary = {}
var _chosen: Array = []  ## [sim_t, move]
var _seq_want: Array = []
var _seq_got: Array[String] = []
var _seq_runs: Array = []  ## [steps wanted, steps started] per finished sequence
var _dodge_from := Vector3.ZERO
var _dodge_t0 := -1.0
var _dodge_best := 0.0  ## most ground a strafe covered within 0.5 s
var _priority_breaks: Array[String] = []
var _cool_frames := 0
var _cool_moving := 0
var _cool_hold := 0
var _fillers: Dictionary = {}
var _charge_clips: Dictionary = {}
var _charge_v := 0.0
var _filler_log: Array = []  ## [sim_t, kind]
var _max_d := 0.0
var _disengage_breaks: Array[String] = []
var _since_disengage := true  ## an attack or a hold happened since the last back-leap
var _hop_start := -1.0
var _hop_d0 := 0.0
var _hop_best := 0.0  ## most distance gained from the prey within 0.5 s of a hop starting
var _hop_rise := 0.0  ## highest body lift seen during a hop
var _hops := 0
var _combo_tell := -1.0  ## t since combo start of the first combo's tell (its last bite's ring)

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
	# Deterministic under load: seeded RNGs, physics never drops steps to catch up with the wall
	# clock, and every test creature animates in the physics step (see _spawn), so brain, clips and
	# the simulated clock below advance in lock-step whatever the machine is doing.
	seed(20261028)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261028
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
	var cam := Camera3D.new()  # PlayerSim.cam_dir turns key input into a direction through the camera
	host.add_child(cam)
	cam.look_at_from_position(Vector3(0, 12, 12), Vector3.ZERO)
	cam.current = true
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	if not "--only-ai" in OS.get_cmdline_user_args():
		await _test_player_stun()
		await _test_tackle_kick()
	player.process_mode = Node.PROCESS_MODE_DISABLED  # the stationary target: no auto-attack, no walking
	player.velocity = Vector3.ZERO
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	dino = _spawn(&"deinonychus", Vector3(0, 0.1, 9), &"loyal")
	await _test_fight()
	_test_pounce_damage()
	_test_energy_gate()
	await _test_retreat()
	await _test_ambush()
	await _test_chase()
	await _test_overshoot()
	await _test_pursuit()
	await _test_enrage()
	_test_natures()
	_test_direction_clips()
	_test_run_and_refill()
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
	seed(20261028)  # the shared brain setup draws from the global RNG
	var iv_rng := RandomNumberGenerator.new()  # IVs (speed!) roll on a fresh randomized RNG unless given one
	iv_rng.seed = 20261028
	c.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv_rng)
	c.spawn(data.creature(id), &"", 0, null, 0, nature)
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	if "rng" in c.brain:
		c.brain.rng.seed = 20261028
		c.brain._circle_sign = 1.0  # CreatureBrain seeds the flank side from the instance id, which differs per run
		c.brain._flank_sign = 1.0
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
		if k in [&"bite", &"combo", &"pounce", &"lunge", &"strafe", &"feint", &"chase", &"dodge", &"charge", &"charge_bite"]:
			_since_disengage = true
		if k == &"hop":
			if not _since_disengage:
				_disengage_breaks.append("%.1fs" % _sim_t)
			_since_disengage = false
			_hops += 1
			_hop_start = _sim_t
			_hop_d0 = Vector2(dino.global_position.x - player.global_position.x, dino.global_position.z - player.global_position.z).length()
		if k == &"combo" and _combo_start < 0.0:
			_combo_start = _sim_t)
	b.tactic_hit.connect(func(clip: StringName, i: int, m: float) -> void:
		_hits.append([_sim_t, clip, i, m])
		if clip == &"bite_combo" and _combo_start >= 0.0 and _combo_hits.size() < 3:
			_combo_hits.append([_sim_t - _combo_start, i, m]))
	dino.anim.attack_windup.connect(func(clip: StringName) -> void:
		if clip == &"bite_combo" and _combo_start >= 0.0 and _combo_tell < 0.0:
			_combo_tell = _sim_t - _combo_start)
	dino.anim.attack_hit.connect(func(clip: StringName) -> void:
		if clip == &"attack_primary":
			_bites.append(_sim_t))
	_keep_player_alive()
	b.attack_chosen.connect(func(move: StringName, _d: float) -> void:
		_chosen.append([_sim_t, move]))
	b.filler.connect(func(k: StringName) -> void: _filler_log.append([_sim_t, k]))
	b.sequence_started.connect(func(_n: String, steps: Array) -> void:
		if not _seq_want.is_empty() and not _seq_got.is_empty():
			_seq_runs.append([_seq_want.duplicate(), _seq_got.duplicate()])
		_seq_want = steps.duplicate()
		_seq_got.clear())
	b.sequence_step.connect(func(step: StringName) -> void:
		_seq_got.append(str(step))
		if step in [&"strafe_left", &"strafe_right"]:
			_dodge_from = dino.global_position
			_dodge_t0 = _sim_t)
	b.on_aggro(player)
	Engine.time_scale = TIME_SCALE
	var prev_ang := NAN
	var circle_ang := 0.0
	var hp0: float = dino.health.max_hp
	var prev_pos: Vector3 = dino.global_position
	_step = 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	_f0 = Engine.get_physics_frames()
	while _sim_t < SIM_S - _step * 0.5:
		prev_pos = dino.global_position
		await physics_frame
		var dt := _step
		_keep_player_alive()
		dino.health.hp = hp0  # no retreat during the manoeuvre census
		if OS.has_environment("TA_TRACE"):
			print("[trace] %.4f %s %.4f %.4f %.4f %.2f %s %.4f %.4f" % [_sim_t, b.state, dino.global_position.x, dino.global_position.y, dino.global_position.z, dino.energy, dino.anim.current_clip, dino.rotation.y, player.global_position.z])
		_states[b.state] = true
		var v: Vector3 = dino.global_position - player.global_position
		var ang := atan2(v.x, v.z)
		if b.state in [&"circle", &"feint", &"hop", &"dodge"] and not is_nan(prev_ang):
			circle_ang += absf(angle_difference(prev_ang, ang))
		prev_ang = ang
		if b.state == &"charge" and Vector2(dino.velocity.x, dino.velocity.z).length() > 0.5:
			_charge_clips[dino.anim.current_clip] = true
			_charge_v = maxf(_charge_v, Vector2(dino.velocity.x, dino.velocity.z).length())
		if _dodge_t0 >= 0.0 and _sim_t - _dodge_t0 <= 0.5 and b.state == &"dodge":
			_dodge_best = maxf(_dodge_best, Vector2(dino.global_position.x - _dodge_from.x, dino.global_position.z - _dodge_from.z).length())
		if _hop_start >= 0.0 and _sim_t - _hop_start <= 0.5:
			_hop_best = maxf(_hop_best, Vector2(v.x, v.z).length() - _hop_d0)
			_hop_rise = maxf(_hop_rise, dino.view.position.y)
		if b.state != &"approach" and b.state != &"alert":
			_max_d = maxf(_max_d, Vector2(v.x, v.z).length())
		if b.state in [&"circle", &"feint", &"hop", &"hold"]:
			var all_cooling := true  # no finisher it may throw now (cooldowns, energy)
			for m in [&"pounce", &"combo", &"charge"]:
				all_cooling = all_cooling and not b._terminal_ready(m, Vector2(v.x, v.z).length())
			if all_cooling:
				_cool_frames += 1
				if b.state == &"hold":
					_cool_hold += 1
				if Vector2(dino.global_position.x - prev_pos.x, dino.global_position.z - prev_pos.z).length() > 0.3 * dt:
					_cool_moving += 1
	Engine.time_scale = 1.0
	# Events of the step the loop ended on may land on either side of it: keep only those before it.
	var cut := SIM_S - _step * 0.5
	_tactics = _tactics.filter(func(row: Array) -> bool: return float(row[0]) < cut)
	_hits = _hits.filter(func(row: Array) -> bool: return float(row[0]) < cut)
	_chosen = _chosen.filter(func(row: Array) -> bool: return float(row[0]) < cut)
	_bites.assign(_bites.filter(func(t: float) -> bool: return t < cut))
	_filler_log = _filler_log.filter(func(row: Array) -> bool: return float(row[0]) < cut)
	_hops = _tactics.filter(func(row: Array) -> bool: return row[1] == &"hop").size()
	for row in _filler_log:
		_fillers[row[1]] = int(_fillers.get(row[1], 0)) + 1
	_f0 = -1
	var kinds := {}
	for row in _tactics:
		kinds[row[1]] = int(kinds.get(row[1], 0)) + 1
	print("[t_tactical] census %s states=%s circle_rad=%.2f bites=%d hits=%d" % [kinds, _states.keys(), circle_ang, _bites.size(), _hits.size()])
	var bite_cd: float = float(b.tac.get("bite_cd", 1.6))
	var min_gap := INF
	for i in range(1, _bites.size()):
		min_gap = minf(min_gap, _bites[i] - _bites[i - 1])
	_expect(_bites.size() >= 1, "bites landed (%d)" % _bites.size())
	# The selection loop: strongest available first, each move outside its own cooldown, moving while all cool.
	# Sequences: every one ran its steps in order (a backstep may be skipped when a back-jump is not allowed).
	var order_breaks: Array[String] = []
	for run in _seq_runs:
		var want: Array = run[0]
		var got: Array = run[1]
		var want_s: Array[String] = []
		for st in want:
			if not (str(st) == "backstep" and not got.has("backstep")):
				want_s.append(str(st))
		if str(want_s) != str(got):
			order_breaks.append("%s ran %s" % [str(want), str(got)])
	_expect(_seq_runs.size() >= 3 and order_breaks.is_empty(), "%d sequences ran their steps in order %s" % [_seq_runs.size(), str(order_breaks)])
	var backstep_rows := 0
	for row in b.tac.get("sequences", []):
		if (row["steps"] as Array).count("backstep") > 1:
			backstep_rows += 1
	_expect(backstep_rows == 0, "no sequence has more than one backstep")
	var sm: float = float(b.tac.get("strafe_m", 3.75))
	_expect(_dodge_best >= sm * 0.9 and _dodge_best <= sm * 1.1, "the powerful strafe moves %.2fm sideways within 0.5s (strafe_m %.2f)" % [_dodge_best, sm])
	var attacks := 0
	var plain_bites := 0
	var finishers := 0
	for row in _tactics:
		if row[1] in [&"pounce", &"combo", &"charge", &"bite"]:
			attacks += 1
		if row[1] == &"bite":
			plain_bites += 1
		if row[1] in [&"pounce", &"combo", &"charge"]:
			finishers += 1
	var max_share: float = float(b.tac.get("max_basic_share", 0.15))
	_expect(float(plain_bites) <= max_share * float(attacks), "basic bites are a small share: %d of %d attacks (<= %.0f%%)" % [plain_bites, attacks, max_share * 100.0])
	_expect(finishers * 2 >= attacks, "most attacks are pounce, charge or combo (%d of %d)" % [finishers, attacks])
	var order: Array[String] = []
	var last_use := {}
	var cd_breaks: Array[String] = []
	for row in _chosen:
		order.append(str(row[1]))
		var cd: float = float(b.tac.get(str(row[1]) + "_cd", 0.0))
		if last_use.has(row[1]) and row[0] - float(last_use[row[1]]) < cd - 0.05:
			cd_breaks.append("%s %.2fs after the last (cd %.1f)" % [row[1], row[0] - float(last_use[row[1]]), cd])
		last_use[row[1]] = row[0]
	print("[t_tactical] attack order %s" % ", ".join(order))
	# Anti-spam: basics <= max_basic_share of all actions, never 3 basics in a row, a beat between two.
	var actions := 0
	var basics := 0
	var streak := 0
	var worst_streak := 0
	var beat := true
	var no_beat := 0
	for row in _tactics:
		var k: StringName = row[1]
		if k in [&"hold", &"hop", &"feint", &"strafe"]:
			actions += 1
			beat = true
		elif k in [&"combo", &"pounce"]:
			actions += 1
			streak = 0
		elif k == &"bite":
			actions += 1
			basics += 1
			streak += 1
			worst_streak = maxi(worst_streak, streak)
			if not beat:
				no_beat += 1
			beat = false
	_expect(worst_streak <= int(b.tac.get("max_basic_streak", 2)), "never more than %d basics in a row (worst %d)" % [int(b.tac.get("max_basic_streak", 2)), worst_streak])
	_expect(no_beat == 0, "a non-attack beat between any two basics (%d without)" % no_beat)
	_expect(cd_breaks.is_empty(), "no attack inside its own cooldown %s" % str(cd_breaks))
	var run_v: float = dino.move_speed_mps() * dino.run_speed_mult()
	_expect(_charge_clips.has(&"charge") and _charge_v >= run_v * 1.4, "the charge plays the charge clip %s at %.1f m/s, visibly faster than its %.1f m/s run" % [_charge_clips.keys(), _charge_v, run_v])
	var hm: float = float(b.tac.get("hop_m", 5.6))
	_expect(_hops >= 2 and _hop_best >= hm * 0.9 and _hop_rise >= 0.3, "backs off by jumping: %d hops, best +%.2fm away within 0.5s (hop_m %.1f), body rose %.2fm" % [_hops, _hop_best, hm, _hop_rise])
	_expect(_disengage_breaks.is_empty(), "a back-jump is always followed by a strafe, attack, pounce or chase before the next %s" % str(_disengage_breaks))
	# Owner (2026-10-28): while the bite cools down, the filler is repositioning (strafe-walk, power strafe, backstep).
	var repos := int(_fillers.get(&"strafe", 0)) + int(_fillers.get(&"dodge", 0)) + int(_fillers.get(&"hop", 0))
	var fill_total := 0
	for k in _fillers:
		fill_total += int(_fillers[k])
	_expect(fill_total >= 3 and float(repos) >= 0.7 * float(fill_total), "repositioning is the main filler: %d of %d %s" % [repos, fill_total, str(_fillers)])
	var max_r: float = float(b.tac.get("max_retreat_m", 11.0))
	_expect(_max_d <= max_r + 0.3, "never farther than max_retreat_m %.1f from the target (max %.2f)" % [max_r, _max_d])
	var moving_frac := float(_cool_moving + _cool_hold) / maxf(1.0, float(_cool_frames))
	_expect(_cool_frames > 30 and moving_frac >= 0.6, "moves or holds deliberately while every attack cools down (%.0f%% of %d frames)" % [moving_frac * 100.0, _cool_frames])
	_expect(min_gap >= bite_cd - 0.05, "never bites twice inside its %.1fs bite cooldown (min gap %.2fs)" % [bite_cd, min_gap])
	_expect(circle_ang > 1.0, "moves around the target (%.2f rad of travel around it while circling, strafing or hopping)" % circle_ang)
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
		# Measured from the first bite: the clip may start a frame or a cross-fade after the combo call.
		var t0: float = _combo_hits[0][0] - float(fracs[0]) * clip_len
		for i in 3:
			var want: float = float(fracs[i]) * clip_len
			_expect(absf(_combo_hits[i][0] - t0 - want) <= 0.07, "combo bite %d at %.2fs into the clip (hit frac %.3f of %.2fs = %.2fs)" % [i + 1, _combo_hits[i][0] - t0, fracs[i], clip_len, want])
	var tell: Array = data.anim_events["clips"]["bite_combo"].get("tell_fracs", [])
	if tell.size() == 2:
		var tell_t: float = float(tell[0]) * clip_len
		var c0: float = _combo_hits[0][0] - float(fracs[0]) * clip_len if _combo_hits.size() > 0 else 0.0
		_expect(absf(_combo_tell - c0 - tell_t) <= 0.07 and _combo_tell - c0 < float(fracs[2]) * clip_len, "combo tell (last bite's ring) at %.2fs into the clip, tell_fracs[0] %.3f = %.2fs" % [_combo_tell - c0, tell[0], tell_t])
	else:
		_expect(false, "anim_events bite_combo has tell_fracs [start, end]")

## The pounce's resolved hit against the combo's first bite, both on the same survivor (no fight race).
func _test_pounce_damage() -> void:
	var b = dino.brain
	dino.global_position = player.global_position + Vector3(0, -0.8, -1.5)
	b.attack_target = player
	b._pounce_dir = Vector3(0, 0, 1)  # landed facing her
	_keep_player_alive()
	var hp0: float = player.vitals.health
	b._pounce_land()
	var pounce_dmg: float = hp0 - player.vitals.health
	_keep_player_alive()
	hp0 = player.vitals.health
	load("res://scripts/combat/creature_attack.gd").apply_for(dino, &"bite_combo", player, b.hit_damage_mult(&"bite_combo", 0))
	var bite_dmg: float = hp0 - player.vitals.health
	_keep_player_alive()
	_expect(b._pounce_landed and pounce_dmg > bite_dmg and bite_dmg > 0.0, "the pounce hits harder than the combo's first bite (%.1f vs %.1f damage)" % [pounce_dmg, bite_dmg])

func _test_energy_gate() -> void:
	var b = dino.brain
	dino.energy = 0.0
	dino.winded = true
	var specials := 0
	for i in 60:
		b._set_state(&"circle")
		b._cd.clear()
		b._strike(6.0, ["combo", "pounce"])
		b._start_sequence(6.0)
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
	var saw := [false]
	b.tactic.connect(func(k: StringName) -> void:
		if k == &"retreat":
			saw[0] = true)
	for i in 30:
		await physics_frame
		_keep_player_alive()
		if saw[0]:
			break
	_expect(saw[0], "retreats below %.0f%% HP" % (b.retreat_frac() * 100.0))
	var wide_ok: bool = b.ring_m() > float(b.tac.get("ring_m", 5.5))
	_expect(wide_ok, "circles wider after a retreat (ring %.1fm)" % b.ring_m())

## AMBUSH: unaggroed while the survivor stands outside the ambush radius facing it; inside it the
## first attack is the leap (pounce) out of cover. Back-offs are leaps (checked in _test_fight).
func _test_ambush() -> void:
	dino.queue_free()
	await physics_frame
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	var lurker = _spawn(&"deinonychus", Vector3(0, 0.1, -9), &"loyal")
	var b = lurker.brain
	var radius: float = float(b.tac.get("ambush_radius_m", 6.0))
	player.visual.rotation.y = 0.0  # facing -Z, towards the lurker: her back is not turned
	_keep_player_alive()
	var first := [&""]
	var ambushed := [false]
	b.tactic.connect(func(k: StringName) -> void:
		if k == &"ambush":
			ambushed[0] = true)
	b.attack_chosen.connect(func(move: StringName, _d: float) -> void:
		if first[0] == &"":
			first[0] = move)
	for i in 90:
		await physics_frame
		_keep_player_alive()
	_expect(b.attack_target == null and not ambushed[0], "unaggroed at %.1fm, outside the %.1fm ambush radius, facing it (state %s)" % [Vector2(lurker.global_position.x, lurker.global_position.z).length(), radius, lurker.brain_state])
	lurker.global_position = Vector3(0, 0.1, -(radius - 1.0))
	for i in 200:
		await physics_frame
		_keep_player_alive()
		if first[0] != &"":
			break
	if first[0] == &"":
		var dd: float = b._flat_dist(player)
		print("[t_tactical] ambush why: swing=%s wide=%.1f sprint=%s pounce=%s combo=%s bite=%s stagger=%.2f reach=%.2f ring=%.2f dflat=%.2f" % [b._can_swing(), b._wide_left, lurker.can_sprint(), b.attack_available(&"pounce", dd), b.attack_available(&"combo", dd), b.attack_available(&"bite", dd), lurker.stagger_left, b.reach_to(player), b.ring_m(), dd])
		print("[t_tactical] ambush debug tgt=%s valid=%s amb=%s state=%s open=%.2f e=%.0f busy=%s cd=%s pack=%s d=%.2f" % [b.attack_target, b._valid_target(), ambushed[0], b.state, b._open_left, lurker.energy, lurker.anim._busy, b._cd, b._pack_ready(), Vector2(lurker.global_position.x, lurker.global_position.z).length()])
	_expect(ambushed[0], "ambushes inside the %.1fm radius" % radius)
	_expect(first[0] == &"pounce", "first attack after the ambush is the leap from cover (got %s)" % first[0])
	lurker.queue_free()

func _fresh_hunter(at: Vector3):
	var c = _spawn(&"deinonychus", at, &"loyal")
	c.brain.tac = c.brain.tac.duplicate()
	c.brain.tac.erase("ambush")  # these checks start mid-fight
	return c

## Walking away at walk pace while it is on her: it runs after her or pounces; the gap does not keep growing.
func _test_chase() -> void:
	player.global_position = Vector3(0, 0.9, 0)
	var c = _fresh_hunter(Vector3(0, 0.1, -6))
	var b = c.brain
	_keep_player_alive()
	b.on_aggro(player)
	for i in 30:
		await physics_frame
	var kinds := {}
	b.tactic.connect(func(k: StringName) -> void: kinds[k] = true)
	var away := Vector3(0, 0, 1)
	var d0: float = Vector2(c.global_position.x - player.global_position.x, c.global_position.z - player.global_position.z).length()
	var ran := false
	var late_min := INF
	var t := 0.0
	while t < 7.0:
		await physics_frame
		var dt := get_root().get_physics_process_delta_time()
		t += dt
		player.velocity = away * 5.5
		player.global_position += away * 5.5 * dt
		_keep_player_alive()
		if b.state == &"approach" and b.speed_override >= c.move_speed_mps() - 0.01:
			ran = true
		if OS.has_environment("TA_TRACE") and Engine.get_physics_frames() % 10 == 0:
			print("[chase] t=%.2f d=%.1f %s/%s so=%.1f v=%.1f e=%.0f" % [t, Vector2(c.global_position.x - player.global_position.x, c.global_position.z - player.global_position.z).length(), b.state, b._pounce_phase, b.speed_override, Vector2(c.velocity.x, c.velocity.z).length(), c.energy])
		if t >= 5.0:
			late_min = minf(late_min, Vector2(c.global_position.x - player.global_position.x, c.global_position.z - player.global_position.z).length())
	var d1: float = Vector2(c.global_position.x - player.global_position.x, c.global_position.z - player.global_position.z).length()
	player.velocity = Vector3.ZERO
	_expect(ran or kinds.has(&"pounce"), "chases at a run or pounces when she walks away (ran=%s pounce=%s)" % [ran, kinds.has(&"pounce")])
	# A pounce mid-leap opens the gap for a moment; over the last 2 s it must have closed back in.
	_expect(late_min <= d0 + 1.0, "the gap does not keep growing (%.1fm at the start, closest %.1fm in the last 2s of 7s)" % [d0, late_min])
	c.queue_free()
	await physics_frame

## A pounce at prey that stops at take-off (aimed by its old velocity) sails past and recovers longer.
func _test_overshoot() -> void:
	player.global_position = Vector3(0, 0.9, 0)
	var c = _fresh_hunter(Vector3(0, 0.1, -7))
	var b = c.brain
	b.attack_target = player
	b._set_state(&"circle")
	await physics_frame
	b._start_pounce()
	var start: Vector3 = c.global_position
	var missed := [false]
	b.tactic.connect(func(k: StringName) -> void:
		if k == &"pounce_miss":
			missed[0] = true)
	var t := 0.0
	while t < 3.0 and not missed[0]:
		# She looks like she is walking away (velocity) but stands still: the lead overshoots her.
		player.velocity = Vector3(0, 0, 4.0) if b._pounce_phase == &"windup" else Vector3.ZERO
		await physics_frame
		t += get_root().get_physics_process_delta_time()
		_keep_player_alive()
	var past: bool = c.global_position.distance_to(start) > player.global_position.distance_to(start)
	_expect(missed[0] and b._pounce_phase == &"recover", "an overshot pounce misses and recovers (missed=%s phase=%s)" % [missed[0], b._pounce_phase])
	_expect(past, "it lands past her (%.1fm from its start, she is %.1fm)" % [c.global_position.distance_to(start), player.global_position.distance_to(start)])
	player.velocity = Vector3.ZERO
	c.queue_free()
	await physics_frame

## Direction-aware locomotion: the clip follows velocity against facing (the body faces -Z).
func _test_direction_clips() -> void:
	var CA = load("res://scripts/creatures/creature_anim.gd")
	var b := Basis.IDENTITY
	_expect(CA.pick_direction(Vector3(0, 0, -3), b) == &"", "forward velocity -> forward gait")
	_expect(CA.pick_direction(Vector3(0, 0, 3), b) == &"walk_back", "velocity against facing -> walk_back")
	_expect(CA.pick_direction(Vector3(3, 0, 0), b) == &"strafe_right", "velocity to the right -> strafe_right")
	_expect(CA.pick_direction(Vector3(-3, 0, 0), b) == &"strafe_left", "velocity to the left -> strafe_left")
	_expect(CA.pick_direction(Vector3(0.5, 0, -1), b) == &"", "diagonal forward -> forward gait")
	_expect(CA.pick_direction(Vector3(1, 0, -1.2), b, CA.FACING_SIDE_DOT) == &"strafe_right" and CA.pick_direction(Vector3(-1, 0, -1.2), b, CA.FACING_SIDE_DOT) == &"strafe_left", "facing the prey, a 50 deg diagonal is a sidestep by its lateral sign")
	var turned := Basis(Vector3.UP, PI)  # facing +Z now
	_expect(CA.pick_direction(Vector3(0, 0, -3), turned) == &"walk_back", "walk_back follows the body's own facing")
	var c = _spawn(&"zebraceratops", Vector3(30, 0.1, 30), &"loyal")
	c.set_physics_process(false)
	c.anim.set_move_velocity(Vector3(0, 0, 2), c.global_basis.orthonormalized())
	var want := &"walk_back" if c.anim.has_state(&"walk_back") else &"walk"
	_expect(c.anim.current_clip == want, "zebraceratops backing up plays %s (got %s)" % [want, c.anim.current_clip])
	c.queue_free()

## Pressed by an advancing survivor it strafes / strafe-walks instead of committing, and commits once
## her swing is recovering (the opening).
func _test_pursuit() -> void:
	player.global_position = Vector3(0, 0.9, 0)
	player.hunt._swing_cd = 0.0
	player.hunt._swing_pending = false
	var c = _fresh_hunter(Vector3(0, 0.1, -7))
	var b = c.brain
	b.attack_target = player
	b._enter_circle(0.0)
	var first := [-1.0]
	var t := [0.0]
	b.attack_chosen.connect(func(_m: StringName, _d: float) -> void:
		if first[0] < 0.0:
			first[0] = t[0])
	var moving_s := 0.0
	var open_at := 2.0
	var prev: Vector3 = c.global_position
	while t[0] < open_at + 1.0 and first[0] < 0.0:
		var to_c: Vector3 = c.global_position - player.global_position
		to_c.y = 0.0
		player.velocity = to_c.normalized() * 2.0  # pressing in on it (her position stays: a stationary press)
		if t[0] >= open_at:
			player.hunt._swing_cd = 0.8  # she just swung: the recovery is the opening
		prev = c.global_position
		await physics_frame
		t[0] += get_root().get_physics_process_delta_time()
		_keep_player_alive()
		if b.state in [&"circle", &"dodge", &"hop"] and Vector2(c.global_position.x - prev.x, c.global_position.z - prev.z).length() > 0.0:
			moving_s += get_root().get_physics_process_delta_time()
	player.velocity = Vector3.ZERO
	player.hunt._swing_cd = 0.0
	_expect(first[0] >= open_at - 0.05, "pressed, it waits for an opening before committing (first commit at %.2fs, opening at %.1fs)" % [first[0], open_at])
	_expect(first[0] >= 0.0 and first[0] <= open_at + 0.6, "it commits once her swing is recovering (at %.2fs)" % first[0])
	_expect(moving_s >= 1.2, "it strafes / strafe-walks while it waits (%.2fs of movement)" % moving_s)
	c.queue_free()
	await physics_frame

## Owner 2026-10-28: faster running that costs more, refills faster when fresh and slower when exhausted.
func _test_run_and_refill() -> void:
	var CT = load("res://scripts/combat/combat_tuning.gd")
	var mult: float = CT.num("movement", "run_speed_mult", 1.0)
	_expect(mult > 1.0 and is_equal_approx(player.sprint_speed, 8.5 * mult) and is_equal_approx(player.run_speed, 7.0 * mult), "survivor run %.2f / sprint %.2f = scene 7.0 / 8.5 x %.2f" % [player.run_speed, player.sprint_speed, mult])
	var rules: Dictionary = data.creature_ai["energy"]
	var c = _spawn(&"deinonychus", Vector3(25, 0.1, -25), &"loyal")
	_expect(c.run_speed_mult() > 1.0 and is_equal_approx(c.energy_drain_per_s, float(rules["run_drain_per_s"])), "creatures run x%.2f and drain %.1f/s" % [c.run_speed_mult(), c.energy_drain_per_s])
	c.energy = 10.0
	c.winded = false
	c.tick_energy(1.0, false)
	var fresh: float = c.energy - 10.0
	c.energy = 10.0
	c.winded = true
	c.tick_energy(1.0, false)
	var tired: float = c.energy - 10.0
	_expect(fresh > tired and tired > 0.0, "a fresh creature refills faster than a winded one (%.1f vs %.1f per s)" % [fresh, tired])
	c.queue_free()
	var v = player.vitals
	var keep: float = v.fatigue
	var rates: Array[float] = []
	for frac in [0.0, 0.3, 0.6, 0.9]:
		v.fatigue = frac * v.effective_max_fatigue()
		rates.append(v.stamina_regen_mult())
	v.fatigue = keep
	_expect(rates[0] > rates[1] and rates[1] > rates[2] and rates[2] > rates[3] and rates[0] > 1.0, "stamina refill falls with exhaustion tier %s (fresh faster than before)" % str(rates))

## ENRAGE: no red body tint, blood particles while it lasts (freed after), more movement attacks and
## combos per minute than calm with the bite share still capped, natures scale it, Timid runs away.
func _test_enrage() -> void:
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	var c = _fresh_hunter(Vector3(0, 0.1, -7))
	c.brain.on_aggro(player)
	c.statuses.apply(&"enraged", player)
	for i in 5:
		await physics_frame
	var fx: Array = c.status_emitters.get(&"enraged", [])
	var live: bool = fx.size() == 2
	for e in fx:
		live = live and is_instance_valid(e) and e is CPUParticles3D and (e as Node).get_parent() == c
	_expect(c._fx_tint_last == Color.WHITE, "enraged: no red body tint (tint %s)" % str(c._fx_tint_last))
	_expect(live, "enraged: blood particles on the body and mouth (%d emitters)" % fx.size())
	c.statuses.clear_id(&"enraged")
	for i in 3:
		await physics_frame
	var gone: bool = not c.status_emitters.has(&"enraged")
	for e in fx:
		gone = gone and not is_instance_valid(e)
	_expect(gone, "the blood particles are freed when the rage ends")
	c.queue_free()
	await physics_frame
	var calm: Dictionary = await _census(&"loyal", false, 30.0)
	var mad: Dictionary = await _census(&"loyal", true, 30.0)
	var aggr: Dictionary = await _census(&"aggressive", true, 30.0)
	var docile: Dictionary = await _census(&"docile", true, 30.0)
	print("[t_tactical] enrage census calm=%s enraged=%s aggressive=%s docile=%s" % [calm, mad, aggr, docile])
	_expect(float(mad.moves) > float(calm.moves), "enraged makes more movement attacks and combos per minute (%.1f vs %.1f calm)" % [mad.moves, calm.moves])
	_expect(float(aggr.moves) > float(docile.moves), "an enraged Aggressive makes more than an enraged Docile (%.1f vs %.1f)" % [aggr.moves, docile.moves])
	var share: float = float(_t_tac().get("max_basic_share", 0.15))
	_expect(float(mad.bite_share) <= share and float(aggr.bite_share) <= share, "the bite share stays capped while enraged (%.2f, %.2f <= %.2f)" % [mad.bite_share, aggr.bite_share, share])
	# Timid: panics and runs from the threat instead.
	var shy = _fresh_hunter(Vector3(0, 0.1, -6))
	shy.nature = &"timid"
	shy.brain.on_aggro(player)
	for i in 10:
		await physics_frame
	var d0: float = Vector2(shy.global_position.x, shy.global_position.z).length()
	shy.statuses.apply(&"enraged", player)
	var fled := false
	for i in 120:
		await physics_frame
		fled = fled or shy.brain.state == &"flee"
	var d1: float = Vector2(shy.global_position.x, shy.global_position.z).length()
	_expect(fled and d1 > d0 + 2.0, "an enraged Timid runs away (flee=%s, %.1fm -> %.1fm)" % [fled, d0, d1])
	shy.queue_free()
	await physics_frame

func _t_tac() -> Dictionary:
	return load("res://scripts/creatures/brains/tactical_brain.gd").tactics_for(&"pack_flanker")

## Per minute over `secs` simulated seconds against the stationary survivor: movement attacks and
## combos (pounce, charge, leap-in, combo, power strafe, back-jump, sequences) and the plain-bite share.
func _census(nature: StringName, rage: bool, secs: float) -> Dictionary:
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	var c = _fresh_hunter(Vector3(0, 0.1, -8))
	c.nature = nature
	var b = c.brain
	var log: Array = []
	b.tactic.connect(func(k: StringName) -> void: log.append(k))
	b.sequence_started.connect(func(_n: String, _s: Array) -> void: log.append(&"sequence"))
	b.on_aggro(player)
	Engine.time_scale = TIME_SCALE
	var step := 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	var n := int(round(secs / step))
	var f0 := Engine.get_physics_frames()
	while Engine.get_physics_frames() - f0 < n:
		await physics_frame
		_keep_player_alive()
		c.health.hp = c.health.max_hp
		if rage and not c.statuses.has(&"enraged"):
			c.statuses.apply(&"enraged", player)
	Engine.time_scale = 1.0
	var moves := 0
	var attacks := 0
	var bites := 0
	for k in log:
		if k in [&"pounce", &"charge", &"lunge", &"combo", &"dodge", &"hop", &"sequence"]:
			moves += 1
		if k in [&"pounce", &"charge", &"combo", &"bite"]:
			attacks += 1
		if k == &"bite":
			bites += 1
	c.queue_free()
	await physics_frame
	return {"moves": float(moves) * 60.0 / secs, "bite_share": float(bites) / maxf(1.0, float(attacks))}

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
	var rates := {}
	for c in [mad, shy]:
		var charges := 0
		c.brain.attack_target = player
		for i in 400:
			c.brain._cd.clear()
			var row: Dictionary = c.brain.pick_sequence(6.5)
			if not row.is_empty() and str((row["steps"] as Array)[-1]) == "charge":
				charges += 1
		rates[c.nature] = charges
	_expect(int(rates.get(&"aggressive", 0)) > int(rates.get(&"timid", 0)) * 2, "natures weight the sequence pick: charge finishers aggressive %d vs timid %d of 400" % [int(rates.get(&"aggressive", 0)), int(rates.get(&"timid", 0))])
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
	# The manual presses are under test: AUTOABILITY (on by default) would cast the kick itself during
	# the wait below and leave the manual kick on cooldown.
	player.hunt.auto_ability = false
	var raptor = _spawn(&"velociraptor", player.global_position + Vector3(0, 0, -1.6), &"loyal")
	raptor.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	var hunt = player.hunt
	hunt.start(raptor)
	var hp0: float = raptor.health.hp
	hunt.use_tackle()
	_expect(raptor.health.hp < hp0, "tackle lands (hp %.0f -> %.0f)" % [hp0, raptor.health.hp])
	_expect(hunt.cooldown_left(&"tackle") > 0.0, "tackle starts its cooldown")
	_expect(raptor.stagger_left > 0.0, "tackle staggers the target")
	var hp1: float = raptor.health.hp
	hunt.use_tackle()
	_expect(is_equal_approx(raptor.health.hp, hp1), "tackle refused on cooldown")
	for i in 60:  # past the tactic lock
		await physics_frame
	player.vitals.energy = player.vitals.effective_max_energy()
	raptor.global_position = player.global_position + Vector3(0, 0, -1.6)
	raptor.stagger_left = 0.0
	hp1 = raptor.health.hp
	hunt.use_kick()
	_expect(raptor.health.hp < hp1, "kick lands (hp %.0f -> %.0f)" % [hp1, raptor.health.hp])
	_expect(hunt.cooldown_left(&"kick") > 0.0, "kick starts its cooldown")
	_expect(raptor.stagger_left > 0.0, "kick staggers the target")
	var hp2: float = raptor.health.hp
	hunt.use_kick()
	_expect(is_equal_approx(raptor.health.hp, hp2), "kick refused on cooldown")
	for i in 60:
		await physics_frame
	hunt._swing_cd = 0.0
	hunt.begin_swing()
	var floor_s: float = load("res://scripts/combat/combat_tuning.gd").num("player_melee", "basic_cooldown_s", 0.8)
	_expect(hunt._swing_cd >= floor_s - 0.001, "player basic attack has its own cooldown (%.2fs >= %.2fs)" % [hunt._swing_cd, floor_s])
	hunt.stop()
	hunt.auto_ability = true
	raptor.queue_free()
	await physics_frame
