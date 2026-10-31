extends SceneTree
## STYRAFIX: a 60 s scripted GOD-mode fight against one Aggressive styracosaurus (the fight lab's NEXT),
## the survivor hunting it (F) and sidestepping now and then. Every physics frame logs the brain state,
## the clip asked for and the clip the tree plays. Checks: no state flicker, charge and impale both
## fire, the impale lifts her from the horns, the feet do not slide or glide during the charge.
## Usage: godot --headless --path game --script res://tests/t_styrafix.gd [-- --log=PATH] -> "[t_styrafix] PASS"

const TIME_SCALE := 2.0
const FIGHT_S := 60.0
const MAX_STATE_CHANGES_PER_S := 3  ## in any 1 s window
const MAX_PINGPONG := 0  ## A -> B -> A inside 0.25 s
const ROUND_S := 15.0
const HUNT_S := 4.0
const GLIDE_MIN_FRAMES := 4  ## 0.13 s of the body moving on a non-locomotion clip

var failures: Array[String] = []
var _started := false
var host: Node3D
var data: Node
var player
var styra
var rows: Array = []
var events: Array = []  ## [t, kind]
var t := 0.0
var horn_err: Array[float] = []
var lift: Array[float] = []
var charges := 0

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").time_of_day = 0.4
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
		print("[t_styrafix] FAIL %s" % msg)
	else:
		print("[t_styrafix] ok %s" % msg)

func _run() -> void:
	seed(20261031)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	Engine.max_physics_steps_per_frame = 1000
	Engine.physics_jitter_fix = 0.0
	get_root().get_node("Game").god_mode = true
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
	# A flat navmesh over the floor: her walk-off and its approach path like in the lab's world.
	var nav := NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.vertices = PackedVector3Array([Vector3(-150, 0, -150), Vector3(150, 0, -150), Vector3(150, 0, 150), Vector3(-150, 0, 150)])
	nm.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	nav.navigation_mesh = nm
	host.add_child(nav)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.hunt.auto_ability = false  # her tactics would cast rolls of their own; the script decides
	styra = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(styra)
	styra.global_position = Vector3(0, 0.1, -14)
	var iv := RandomNumberGenerator.new()
	iv.seed = 20261031
	styra.genetics = load("res://scripts/creatures/creature_genetics.gd").roll(iv)
	styra.spawn(data.creature(&"styracosaurus"), &"", 0, null, 0, &"aggressive")
	styra.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	styra.brain.rng.seed = 20261031
	styra.brain.tactic.connect(func(kind: StringName) -> void: events.append([t, kind]))
	styra.brain.tactic.connect(_on_tactic)
	styra.brain.on_aggro(player)
	await _fight()
	_report()
	get_root().get_node("Game").god_mode = false
	load("res://scripts/combat/combat_tuning.gd").reset_overrides()
	if failures.is_empty():
		print("[t_styrafix] PASS")
		quit(0)
	else:
		print("[t_styrafix] FAIL %d" % failures.size())
		quit(1)

## The impale's contact: how far her centre was from the horn tip at the hit frame, and how high she goes.
func _on_tactic(kind: StringName) -> void:
	if kind == &"charge":
		charges += 1
	if kind != &"impale":
		return
	horn_err.append(styra.brain.impale_gap)
	var y0: float = player.global_position.y
	var top := [y0]
	for i in 45:
		await physics_frame
		top[0] = maxf(top[0], player.global_position.y)
	lift.append(top[0] - y0)

## The script, in ROUND_S rounds: she hunts it (F) for HUNT_S, then walks off ~16 m and stands, so it has room to
## paw and charge. Every other charge she rolls sideways once its horns are 9 m off (the dodge the charge
## is built to be punished by); the others she takes (the impale).
func _fight() -> void:
	Engine.time_scale = TIME_SCALE
	var step := TIME_SCALE / float(Engine.physics_ticks_per_second)
	var n := int(round(FIGHT_S / step))
	var f0 := Engine.get_physics_frames()
	var round_i := -1
	var rolled := -1
	while Engine.get_physics_frames() - f0 < n:
		await physics_frame
		t = float(Engine.get_physics_frames() - f0) * step
		_keep_alive()
		var r := int(t / ROUND_S)
		var in_round := fmod(t, ROUND_S)
		if r != round_i:
			round_i = r
			player.hunt.start(styra)
		elif in_round >= HUNT_S:
			# Off the hunt (a hit would make her retaliate) and ~16 m out, standing: room for paw and charge.
			if player.hunt.target != null:
				player.hunt.stop()
			var away: Vector3 = player.global_position - styra.global_position
			away.y = 0.0
			if not player.nav_active and away.length() < 13.0 and in_round < HUNT_S + 3.0:
				player.sim.nav_to(styra.global_position + away.normalized() * 16.0)
		var b = styra.brain
		if b._charge_phase == &"run" and charges % 2 == 0 and rolled != charges \
				and b._flat_between(b.horn_tip(), player.global_position) < 9.0:
			rolled = charges
			player.hunt.stop()
			player.sim.try_roll(b._charge_dir.cross(Vector3.UP).normalized())
		var v: Vector3 = styra.velocity
		rows.append({
			"t": t, "state": styra.brain.state, "clip": styra.anim.current_clip, "node": styra.anim.current_state(),
			"busy": styra.anim._busy, "spd": Vector2(v.x, v.z).length(), "pos": styra.global_position,
			"yaw": styra.rotation.y, "cad": styra.anim.cadence(styra.anim.current_clip), "py": player.global_position.y,
			"stag": styra.stagger_left, "dist": b._flat_dist(player) if b.attack_target else -1.0,
			"tip": b._flat_between(b.horn_tip(), player.global_position), "ph": b._charge_phase,
		})
	Engine.time_scale = 1.0

func _keep_alive() -> void:
	player.vitals.max_health = 1000000.0
	if player.vitals.health < 1000.0:
		player.vitals.health = player.vitals.effective_max_health()
	player.vitals.dead = false
	player.dead = false
	if styra.health.hp < styra.health.max_hp * 0.5:
		styra.health.hp = styra.health.max_hp  # a 60 s fight, not a kill: no retreat below 25 %

func _report() -> void:
	var log_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--log="):
			log_path = a.substr(6)
	var f: FileAccess = FileAccess.open(log_path, FileAccess.WRITE) if log_path != "" else null
	var changes: Array = []  ## [t, from, to]
	var clip_changes: Array = []
	var glide := 0  ## frames inside glide runs of GLIDE_MIN_FRAMES or more (a 1-2 frame travel/crossfade lag is not visible)
	var run_len := 0
	var charge_frames := 0
	var slip_frames := 0
	var strides: Array[float] = []
	for i in rows.size():
		var r: Dictionary = rows[i]
		if i > 0:
			var p: Dictionary = rows[i - 1]
			if r.state != p.state:
				changes.append([r.t, p.state, r.state])
			if r.clip != p.clip:
				clip_changes.append([r.t, p.clip, r.clip])
		var moving: bool = r.spd > 1.0
		var loco: bool = str(r.node) in ["walk", "run", "charge", "strafe_left", "strafe_right", "walk_back"]
		if moving and not loco:
			run_len += 1
			if run_len == GLIDE_MIN_FRAMES:
				glide += GLIDE_MIN_FRAMES
			elif run_len > GLIDE_MIN_FRAMES:
				glide += 1
		else:
			run_len = 0
		if r.state == &"charge":
			charge_frames += 1
			if moving and str(r.node) != "charge":
				slip_frames += 1
			elif moving and r.cad > 0.0:
				strides.append(r.spd / r.cad)  # the ground speed one cadence unit buys: constant = feet planted
		if f:
			f.store_line("%.3f %-9s %-14s %-14s busy=%s spd=%.2f cad=%.2f yaw=%.2f py=%.2f stag=%.2f d=%.1f tip=%.1f ph=%s" % [r.t, r.state, r.clip, r.node, r.busy, r.spd, r.cad, r.yaw, r.py, r.stag, r.dist, r.tip, r.ph])
	if f:
		for e in events:
			f.store_line("EVENT %.3f %s" % [e[0], e[1]])
		f.close()
	var worst := 0
	var j := 0
	for i in changes.size():
		while float(changes[i][0]) - float(changes[j][0]) > 1.0:
			j += 1
		worst = maxi(worst, i - j + 1)
	var pingpong := 0
	for i in range(2, changes.size()):
		if changes[i][2] == changes[i - 1][1] and float(changes[i][0]) - float(changes[i - 1][0]) < 0.25:
			pingpong += 1
	var kinds := {}
	for e in events:
		kinds[e[1]] = int(kinds.get(e[1], 0)) + 1
	print("[t_styrafix] states %d changes, worst %d in 1 s, ping-pong %d; clips %d changes; glide %d frames; charge %d frames, %d off the charge clip" % [changes.size(), worst, pingpong, clip_changes.size(), glide, charge_frames, slip_frames])
	print("[t_styrafix] tactics %s" % [kinds])
	print("[t_styrafix] impale horn error %s lift %s" % [horn_err, lift])
	_expect(worst <= MAX_STATE_CHANGES_PER_S, "no state flicker: at most %d brain state changes in any 1 s (worst %d)" % [MAX_STATE_CHANGES_PER_S, worst])
	_expect(pingpong <= MAX_PINGPONG, "no A->B->A state ping-pong inside 0.25 s (%d)" % pingpong)
	_expect(int(kinds.get(&"charge", 0)) >= 2, "the charge fires (%d)" % int(kinds.get(&"charge", 0)))
	_expect(int(kinds.get(&"impale", 0)) >= 1, "the impale fires (%d)" % int(kinds.get(&"impale", 0)))
	_expect(not horn_err.is_empty() and horn_err.max() <= 1.5, "the impale hits from the horns (tip to her chest %s m)" % [horn_err])
	_expect(not lift.is_empty() and lift.min() >= 0.5, "the impale lifts her (%s m)" % [lift])
	_expect(charge_frames > 0 and slip_frames == 0, "during the charge the body only moves on the charge clip (%d of %d frames off it)" % [slip_frames, charge_frames])
	_expect(not strides.is_empty() and strides.max() <= strides.min() * 1.05, "the charge clip is stride-matched on every moving frame (ground speed per cadence %.2f-%.2f m/s)" % [strides.min() if strides else 0.0, strides.max() if strides else 0.0])
	_expect(glide == 0, "the body never glides on a non-locomotion clip for %d+ frames (%d frames)" % [GLIDE_MIN_FRAMES, glide])
