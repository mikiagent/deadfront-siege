extends SceneTree
## SWARM (compsognathus) tactics, seeded and frame-locked like t_tactical: a pack of four surrounds a
## stationary survivor, pounces from range and darts in for bites, jumps back out (leap_back, owner
## 2026-10-28: "should jump back similar to the deinonychus"), mixes strafe jumps into the circling, the
## basic bite stays rare, a pounce whiffs on a survivor who sidesteps after take-off, a hurt one flees, a
## packmate's death scatters the rest, and a pack is bolder than a lone compy.
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
	if OS.has_environment("TS_PART"):  # debugging one scenario: TS_PART=landing | whiff
		if OS.get_environment("TS_PART") == "landing":
			await _landing()
		else:
			await _whiff(tac)
		quit(0 if failures.is_empty() else 1)
		return
	await _whiff(tac)  # first, on clear ground (no corpses on its line)
	var pack := _pack(4, 77)
	_expect(pack[0].brain.get_script().get_global_name() == &"TacticalBrain", "compsognathus gets the TacticalBrain")
	var group: Dictionary = await _fight(pack, 30.0, true)
	print("[t_swarm] pack census %s" % group)
	_expect(float(group.surround_gap) < 180.0, "the pack surrounds her (largest gap between neighbours %.0f deg on average while it circles)" % group.surround_gap)
	_expect(int(group.darts) >= 8 and int(group.outs) * 2 >= int(group.darts), "goes in and jumps back out (%d darts/pounces, %d back-outs)" % [group.darts, group.outs])
	_expect(int(group.bite_backoffs) >= 2 and int(group.bite_leaps) == int(group.bite_backoffs), "after a bite it jumps back: leap_back plays on %d of %d back-offs" % [group.bite_leaps, group.bite_backoffs])
	# A frame or two at a hop's very end can show the next gait while the state flips: count those out.
	_expect(int(group.scurry_frames) * 50 <= int(group.leap_frames) and int(group.leap_frames) > 0, "back-offs are leaps, never a scurry (%d leap frames, %d walk/run frames in a back-off)" % [group.leap_frames, group.scurry_frames])
	_expect(int(group.pounces) >= 3 and float(group.pounce_min_d) >= float(tac.get("pounce_min_m", 2.0)) - 0.05, "pounces from range (%d pounces, nearest take-off %.1f m)" % [group.pounces, group.pounce_min_d])
	_expect(int(group.dodges) >= 3 and int(group.dodge_clip_frames) > 0, "strafe jumps while circling (%d dodges, dodge clip on %d frames)" % [group.dodges, group.dodge_clip_frames])
	_expect(float(group.bite_share) <= float(tac.get("max_basic_share", 0.15)), "the plain bite stays rare (%.2f of attacks)" % group.bite_share)
	# Owner 2026-10-28: "strafe left and strafe right animations are needed on compsagnathus". Circling the ring
	# sideways plays the strafe on the side it moves to, not a forward walk gliding sideways.
	_expect(int(group.circle_side_frames) > 60 and float(group.circle_strafe_share) >= 0.8, "circling sideways plays strafe_left/right (%.2f of %d frames)" % [group.circle_strafe_share, group.circle_side_frames])
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
	await _landing()
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

## Owner 2026-10-28: "compsagnathus attacks aren't landing very often, it should land some attacks". With
## real accuracy rolls (no forced hits), a fair share of bites and pounces connect on a standing survivor and
## on one walking a circle.
func _landing() -> void:
	var CT = load("res://scripts/combat/combat_tuning.gd")
	CT.force_accuracy = -1.0
	for walk in [0.0, 2.0]:
		player.global_position = Vector3(3.0, 0.9, 0.0)
		player.velocity = Vector3.ZERO
		var duo := _pack(2, 93 + int(walk))
		var r: Dictionary = await _fight(duo, 30.0, false, walk)
		for c in duo:
			c.queue_free()
		await physics_frame
		print("[t_swarm] landing walk %.1f m/s: %d of %d attempts landed" % [walk, r.landed, r.attempts])
		_expect(int(r.attempts) >= 6 and float(r.land_share) >= 0.45 and float(r.land_share) <= 0.85, "it lands a fair share on a survivor %s (%.2f of %d attempts)" % ["walking %.0f m/s" % walk if walk > 0.0 else "standing", r.land_share, r.attempts])
	CT.force_accuracy = 1.0
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0.9, 0)

## A pounce locks its landing point at take-off: a survivor who sidesteps 2.5 m once it is in the air is
## missed, and the compy lands where she stood (past her line) and recovers for pounce_miss_recover_s.
func _whiff(tac: Dictionary) -> void:
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	var c = _pack(1, 0)[0]
	c.global_position = Vector3(0, 0.1, -4.5)
	await physics_frame
	var events: Array = []
	var hits := [0]
	var takeoff := [Vector3.ZERO]
	c.brain.tactic.connect(func(k: StringName) -> void:
		events.append(k)
		if k == &"leap":
			takeoff[0] = c.global_position)
	c.brain.tactic_hit.connect(func(_k: StringName, _i: int, _m: float) -> void: hits[0] += 1)
	c.brain.attack_target = player
	c.brain._cd.clear()
	c.energy = c.energy_max
	c.brain._start_pounce()
	var stepped := false
	var travel := -1.0
	var recover_s := 0.0
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	for i in 240:
		await physics_frame
		_keep_alive()
		if not stepped and &"leap" in events:
			stepped = true
			player.global_position += Vector3(2.5, 0, 0)  # sidestep across its line
		if c.brain._pounce_phase == &"recover":
			if travel < 0.0:
				travel = Vector2(c.global_position.x - takeoff[0].x, c.global_position.z - takeoff[0].z).length()
			recover_s += step
		if stepped and c.brain.state != &"pounce":
			break
	_expect(stepped and &"pounce_miss" in events and hits[0] == 0, "a pounce whiffs when the survivor sidesteps after take-off (events %s)" % [events])
	print("[t_swarm] whiff take-off %s landed %s she stood %s" % [takeoff[0], c.global_position, player.global_position - Vector3(2.5, 0, 0)])
	_expect(travel >= 3.0, "the whiffed pounce still flies to its locked landing point (%.1f m from take-off)" % travel)
	_expect(recover_s >= float(tac.get("pounce_miss_recover_s", 1.0)) * 0.8, "a whiff leaves a punish window (%.2f s recovering)" % recover_s)
	c.queue_free()
	await physics_frame

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
func _fight(cs: Array, secs: float, measure_ring: bool, walk_mps: float = 0.0) -> Dictionary:
	var log: Array = []
	var attempts := [0]  ## bite contact frames plus pounce take-offs
	for c in cs:
		c.anim.attack_hit.connect(func(clip: StringName) -> void:
			if clip == &"attack_primary":
				attempts[0] += 1)
	var landed := 0
	var walk_ang := 0.0
	var pounce_d: Array[float] = []
	var last: Dictionary = {}  ## creature -> its previous tactic
	var after_bite: Dictionary = {}  ## creature -> its current back-off follows a bite
	var bo := [0]  ## back-offs straight after a bite
	for c in cs:
		c.brain.tactic.connect(func(k: StringName) -> void:
			log.append(k)
			if k == &"pounce":
				pounce_d.append(c.brain._flat_dist(player))
			if k == &"hop":
				after_bite[c] = last.get(c, &"") in [&"bite", &"charge_bite"]
				bo[0] += 1 if after_bite[c] else 0
			last[c] = k)
		c.brain.on_aggro(player)
	var bite_leaps := 0
	var leap_frames := 0
	var scurry_frames := 0
	var dodge_frames := 0
	var hop_seen: Dictionary = {}
	Engine.time_scale = TIME_SCALE
	var step := 1.0 / float(Engine.physics_ticks_per_second) * Engine.time_scale
	var n := int(round(secs / step))
	var f0 := Engine.get_physics_frames()
	var gap_sum := 0.0
	var gap_n := 0
	var circ_moving := 0  ## physics frames a member circled while moving sideways to its facing
	var circ_strafe := 0  ## ...of which it played strafe_left/right on the side it moved to
	while Engine.get_physics_frames() - f0 < n:
		await physics_frame
		if player.vitals.health < player.vitals.effective_max_health() - 0.01:
			landed += 1
		_keep_alive()
		if walk_mps > 0.0:  # she walks a 3 m circle around the start, so they have to hit a moving target
			walk_ang += walk_mps / 3.0 * step
			player.global_position = Vector3(cos(walk_ang) * 3.0, 0.9, sin(walk_ang) * 3.0)
			player.velocity = Vector3(-sin(walk_ang), 0.0, cos(walk_ang)) * walk_mps
		for c in cs:
			c.health.hp = c.health.max_hp
		if OS.has_environment("TS_TRACE"):
			var row := ""
			for c in cs:
				row += " %s %.3f,%.3f e%.1f" % [c.brain.state, c.global_position.x, c.global_position.z, c.energy]
			print("[trace] %d%s" % [Engine.get_physics_frames() - f0, row])
		for c in cs:
			if c.brain.state == &"hop":
				if c.current_clip in [&"leap_back", &"hop_back"]:
					leap_frames += 1
					if after_bite.get(c, false) and c.current_clip == &"leap_back" and not hop_seen.has(c):
						hop_seen[c] = true
						bite_leaps += 1
				elif c.current_clip in [&"walk_back", &"run", &"walk", &"strafe_left", &"strafe_right"]:
					scurry_frames += 1
			else:
				hop_seen.erase(c)
			if c.brain.state == &"dodge" and c.current_clip in [&"dodge_left", &"dodge_right"]:
				dodge_frames += 1
		var ringed := 0
		for c in cs:
			ringed += 1 if c.brain.state == &"circle" else 0
			var v := Vector3(c.velocity.x, 0.0, c.velocity.z)
			# a jump's last frames can still be on its one-shot as the state flips back to circling: not a glide
			if c.brain.state == &"circle" and v.length() > 0.2 and not c.current_clip in [&"dodge_left", &"dodge_right", &"hop_back", &"leap_back", &"pounce"]:
				var side: float = v.normalized().dot(c.global_basis.x)
				if absf(side) > 0.5:
					circ_moving += 1
					circ_strafe += 1 if c.current_clip == (&"strafe_right" if side > 0.0 else &"strafe_left") else 0
		# Measured while the pack is on its ring (3+ circling), not mid-dart.
		if measure_ring and Engine.get_physics_frames() - f0 > n / 3 and ringed >= 3:
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
	var pounces := 0
	var dodges := 0
	for k in log:
		if k == &"leap":
			attempts[0] += 1
		if k == &"pounce":
			pounces += 1
		if k == &"dodge":
			dodges += 1
		if k in [&"charge", &"pounce"]:
			darts += 1
		if k == &"hop":
			outs += 1
		if k == &"bite":
			bites += 1
		if k in [&"charge", &"bite", &"pounce"]:
			attacks += 1
	return {"darts": darts, "outs": outs, "bite_share": float(bites) / maxf(1.0, float(attacks)),
		"surround_gap": gap_sum / maxf(1.0, float(gap_n)), "circle_side_frames": circ_moving,
		"circle_strafe_share": float(circ_strafe) / maxf(1.0, float(circ_moving)), "darts_per_min_each": float(darts) * 60.0 / secs / float(cs.size()),
		"pounces": pounces, "pounce_min_d": pounce_d.min() if not pounce_d.is_empty() else 0.0, "dodges": dodges,
		"dodge_clip_frames": dodge_frames, "bite_backoffs": bo[0], "bite_leaps": bite_leaps, "leap_frames": leap_frames,
		"scurry_frames": scurry_frames, "attempts": attempts[0], "landed": landed,
		"land_share": float(landed) / maxf(1.0, float(attempts[0]))}
