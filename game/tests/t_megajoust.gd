extends SceneTree
## MEGAJOUST (owner 2026-10-31): "megaloceros strafe looks really awkward. I think a deer would normally charge and do
## a circle and charge again. Like a joust"; doe: "have the doe tackle mainly ... and have it joust like the male ...
## scared and desperate ... more running than charging"; "the jousting brain is good for many of the four legged
## animals". Checks:
##  - both megaloceros sexes run JoustBrain and load charge_crouch (one-shot), charge and run_turn_left/right (loops);
##  - hooves on the wheel: run_turn_left/right carried round the brain's arc (turn_radius_m at the wheel speed) add at
##    most ADD_MED / ADD_WORST of slide per stance to the straight run carried straight (the approved gait's own
##    reading); the straight run carried round the same arc slips more (the measure can tell);
##  - live fights (stag, doe, woolly_rhino, triceratops, zebraceratops) against a standing survivor (GOD on): passes
##    (tell -> straight charge) and wheels alternate, at least 3 passes (charge, circle, charge again, twice), a pass
##    hits and knocks her back, no strafe, walk_back, dodge or hop clip ever plays, the body never moves under a
##    non-locomotion clip, the live wheel's planted hooves stay within the same limits; the doe runs (run off + wheel)
##    more than twice as long as she charges.
## Usage: godot --headless --path game --script res://tests/t_megajoust.gd  -> "[t_megajoust] PASS"

const ID := &"megaloceros"
## A turn may add at most this much slide to the straight run's, per stance (mean / worst).
const ADD_MED := 0.05
const ADD_WORST := 0.10
const LOCO: Array[StringName] = [&"idle", &"walk", &"run", &"charge", &"run_turn_left", &"run_turn_right"]
const BANNED: Array[StringName] = [&"strafe_left", &"strafe_right", &"walk_back", &"dodge_left", &"dodge_right", &"hop_back", &"leap_back"]
const TOES := ["FrontFoot.L", "FrontFoot.R", "BackFoot.L", "BackFoot.R"]

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var base_slide := {}  ## variant -> the straight run's (worst, median) per-stance slide

func _process(_delta: float) -> bool:
	if _started or get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").debug_overlay = false
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_megajoust] %s %s" % ["ok  " if ok else "FAIL", msg])

func _run() -> void:
	seed(20261031)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	load("res://scripts/combat/combat_tuning.gd").force_accuracy = 1.0
	Engine.max_physics_steps_per_frame = 1000
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
	for v in [&"stag", &"doe"]:
		_test_clips(v)
	get_root().get_node("Game").god_mode = true  # hits land (flinch, shove) but take no health: no post-kill retreat
	for v in [&"stag", &"doe"]:
		await _test_fight(ID, v, 50.0)
	# JOUST on other quadrupeds (owner: "the jousting brain is good for many of the four legged animals")
	for sp in [&"woolly_rhino", &"triceratops", &"zebraceratops"]:
		await _test_fight(sp, &"", 60.0)
	get_root().get_node("Game").god_mode = false
	if failures.is_empty():
		print("[t_megajoust] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_megajoust] FAIL " + f)
		quit(1)

func _spawn(v: StringName, at: Vector3, live: bool, sp: StringName = ID) -> Node:
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	# size 1: stride matching (CreatureAnim) does not scale with the genetic body size, so a 0.9x animal slides ~10 %
	# on every gait; that is game-wide and not the joust's (report)
	c.genetics = load("res://scripts/creatures/creature_genetics.gd").new()
	c.spawn(data.creature(sp), v, 0, null, 0, &"aggressive")
	if live:
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	else:
		c.set_physics_process(false)
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

## Hoof tips in world space (the *_end leaf bones, else the foot bones).
func _toes(c) -> Array[Vector3]:
	var skel: Skeleton3D = c.view.rig.skeleton
	var out: Array[Vector3] = []
	for b in TOES:
		var i := skel.find_bone(b + "_end")
		if i < 0:
			i = skel.find_bone(b)
		if i >= 0:
			out.append(skel.global_transform * skel.get_bone_global_pose(i).origin)
	return out

## Per-stance world slide of each hoof over a run of frames: frames within 1.5 % of height of that hoof's lowest point
## are planted. Returns [worst, mean] in metres.
static func _stance_slides(frames: Array, h: float) -> Vector2:
	var slides: Array[float] = []
	if frames.is_empty():
		return Vector2(INF, INF)
	for j in (frames[0] as Array).size():
		var lo := 1e9
		var hi := -1e9
		for f in frames:
			lo = minf(lo, (f[j] as Vector3).y)
			hi = maxf(hi, (f[j] as Vector3).y)
		var start := Vector3.INF
		var prev := Vector3.INF
		for f in frames:
			var p: Vector3 = f[j]
			if p.y <= lo + minf(0.025, 0.12 * (hi - lo)):  # planted: within 2.5 cm of its lowest (a looser band caught the fast touchdown)
				if start == Vector3.INF:
					start = p
				prev = p
			elif start != Vector3.INF:
				slides.append(Vector2(prev.x - start.x, prev.z - start.z).length())
				start = Vector3.INF
	if slides.is_empty():
		return Vector2(INF, INF)
	slides.sort()
	var total := 0.0
	for x in slides:
		total += x
	return Vector2(slides[-1], total / slides.size())  # worst, mean (a median flipped between fore and hind hooves)

## Carry the body round an arc of radius r at mps (sgn +1 = to its left), playing clip stride-matched; 8 s at 60 Hz
## (the physics rate the live fight samples at).
func _arc_slide(c, clip: StringName, mps: float, r: float, sgn: float) -> Vector2:
	c.rotation = Vector3.ZERO
	var p0: Vector3 = c.global_position
	var centre := p0 + Vector3(-1, 0, 0) * r * sgn  # its left is -X while it faces -Z
	if clip == &"run":
		c.anim.set_move_speed(mps)
	else:
		c.anim.set_gait_clip(clip, mps, Vector3(0, 0, -mps), c.global_basis)
	var dt := 1.0 / 60.0
	var th := 0.0
	var frames: Array = []
	for k in 540:
		th += sgn * mps / r * dt
		c.global_position = centre + (p0 - centre).rotated(Vector3.UP, th)
		c.rotation.y = th
		c.anim.tree.advance(dt)
		if k >= 30:  # past the blend
			frames.append(_toes(c))
	c.global_position = p0
	return _stance_slides(frames, c.def.height_meters * c.size_scale())

func _step_m(c, clip: StringName, mps: float) -> float:
	return mps * c.anim.player.get_animation(clip).length / maxf(0.01, c.anim.cadence(clip)) * 0.5

func _test_clips(v: StringName) -> void:
	var c = _spawn(v, Vector3(60, 0, 60), false)
	_expect(c.brain.get_script().get_global_name() == &"JoustBrain", "%s runs JoustBrain" % v)
	var ap: AnimationPlayer = c.anim.player
	for clip in [&"charge", &"run_turn_left", &"run_turn_right"]:
		_expect(ap.has_animation(clip) and c.anim.has_state(clip) and ap.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "%s %s loads and loops" % [v, clip])
	_expect(ap.has_animation(&"charge_crouch") and ap.get_animation(&"charge_crouch").loop_mode == Animation.LOOP_NONE, "%s charge_crouch (the tell) is a one-shot" % v)
	var mps: float = c.move_speed_mps()
	var r: float = c.brain._j("turn_radius_m", 9.0) * c.size_scale()
	# the approved straight run, carried straight: what the measure reads with no turn at all (a gallop's hind toe
	# rolls through its heel-off, so this is not zero); a turn clip on its arc may not add to it
	var base := _arc_slide(c, &"run", mps, 1e6, 1.0)
	base_slide[v] = base
	print("[t_megajoust] %s straight run, straight line: %.1f cm mean, %.1f cm worst per stance" % [v, base.y * 100.0, base.x * 100.0])
	for pair in [[&"run_turn_left", 1.0], [&"run_turn_right", -1.0]]:
		var s := _arc_slide(c, pair[0], mps, r, pair[1])
		_expect(s.y <= base.y + ADD_MED and s.x <= base.x + ADD_WORST,
			"%s %s round its %.1f m arc at %.1f m/s: planted hooves slide %.1f cm mean, %.1f cm worst (straight run %.1f / %.1f, + at most %.0f / %.0f)"
			% [v, pair[0], r, mps, s.y * 100.0, s.x * 100.0, base.y * 100.0, base.x * 100.0, ADD_MED * 100.0, ADD_WORST * 100.0])
	var turn := _arc_slide(c, &"run_turn_left", mps, r, 1.0)
	var plain := _arc_slide(c, &"run", mps, r, 1.0)
	_expect(plain.x > turn.x + 0.05, "%s: the straight run carried round the same arc slips more (%.1f cm worst vs the turn clip's %.1f cm): the measure can tell" % [v, plain.x * 100.0, turn.x * 100.0])
	c.free()

func _test_fight(sp: StringName, v: StringName, secs: float) -> void:
	var name := "%s %s" % [sp, v] if v != &"" else str(sp)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	host.add_child(player)
	await physics_frame
	player.global_position = Vector3(0, 0.9, 0)
	player.velocity = Vector3.ZERO
	player.process_mode = Node.PROCESS_MODE_DISABLED  # a standing target; the shove she gets is read off PlayerSim
	var c = _spawn(v, Vector3(0, 0.1, -16.0), true, sp)
	_expect(c.brain.get_script().get_global_name() == &"JoustBrain", "%s runs JoustBrain" % name)
	c.look_at(Vector3(0, 0.1, 0), Vector3.UP)
	await physics_frame
	var b = c.brain
	b.attack_target = player
	b._provoked_until = b._now_s() + 999.0
	b.on_aggro(player)
	var log: Array[String] = []
	b.tactic.connect(func(k: StringName) -> void:
		if str(k).begins_with("joust_") or k in [&"charge_hit", &"charge_miss", &"heavy", &"kick", &"bite"]:
			log.append(str(k)))
	var hits := [0]
	b.tactic_hit.connect(func(clip: StringName, _i: int, _m: float) -> void:
		if clip == &"charge":
			hits[0] += 1)
	var banned := {}
	var glide := 0
	var glide_clips := {}
	var run_s := 0.0
	var charge_s := 0.0
	var wheel_turn_frames := 0
	var wheel_t := 0.0
	var crouch_moving := 0
	var shove_m := 0.0
	var knocked := false
	var wheel_runs: Array = []  ## hoof frames per uninterrupted run_turn stretch
	var cur: Array = []
	var prev: Vector3 = c.global_position
	var last_clip: StringName = &""
	var hz := float(Engine.physics_ticks_per_second)
	var dt := 1.0 / hz
	for k in int(secs * hz):
		await physics_frame
		player.vitals.health = player.vitals.effective_max_health()
		if not is_instance_valid(c) or c.health.dead:
			break
		var pos: Vector3 = c.global_position
		var mps := Vector2(pos.x - prev.x, pos.z - prev.z).length() * hz
		prev = pos
		# the knock-back PlayerSim.shove asked for (d = |_shove| x _shove_s / 2), or a knockdown/throw where that is built
		var ps = player.sim
		shove_m = maxf(shove_m, (ps._shove as Vector3).length() * float(ps._shove_s) * 0.5)
		if ps.get("knock") != null and ps.knock.has_method("active") and ps.knock.active():
			knocked = true
		var clip: StringName = c.anim.current_clip
		if clip in BANNED or c.anim.current_state() in BANNED:
			banned[clip] = int(banned.get(clip, 0)) + 1
		if mps > 0.3 and not clip in LOCO and clip == last_clip:
			glide += 1
			glide_clips[clip] = true
		if clip == &"charge_crouch" and mps > 0.3 and clip == last_clip:
			crouch_moving += 1
		last_clip = clip
		if b.state == &"circle":
			run_s += dt
		elif b.state == &"charge":
			charge_s += dt
		if b.state == &"circle" and b.phase == &"wheel" and clip in LOCO and mps > 1.0:
			wheel_turn_frames += 1
			wheel_t += dt
			if wheel_t > 0.5:  # past the blend out of the charge
				cur.append(_toes(c))
		else:
			wheel_t = 0.0
			if not cur.is_empty():
				wheel_runs.append(cur)
				cur = []
	if not cur.is_empty():
		wheel_runs.append(cur)
	var seq := ",".join(log)
	print("[t_megajoust] %s log: %s" % [name, seq])
	var passes: int = b.passes
	# charge, circle, charge again: every pass after the first is preceded by a wheel
	var alternating := true
	var last := ""
	for e in log:
		if e == "joust_pass" and last == "joust_pass":
			alternating = false
		if e in ["joust_pass", "joust_wheel"]:
			last = e
	_expect(passes >= 3 and log.count("joust_wheel") >= 2 and alternating,
		"%s jousts: %d passes, %d wheels, passes and wheels alternate (%s)" % [name, passes, log.count("joust_wheel"), "yes" if alternating else "no"])
	_expect(hits[0] >= 1 and (shove_m > 1.0 or knocked), "%s: a pass hits (%d) and knocks the survivor back (shove %.1f m%s)" % [name, hits[0], shove_m, ", knocked down" if knocked else ""])
	_expect(banned.is_empty(), "%s: no strafe / walk_back / dodge / hop clip plays (%s)" % [name, banned])
	_expect(glide == 0 and crouch_moving == 0, "%s: no frame moves the body under a non-locomotion clip (%d, %s; tell moving %d)" % [name, glide, glide_clips.keys(), crouch_moving])
	_expect(wheel_turn_frames > 60, "%s wheels at a gallop or walk (%d frames%s)" % [name, wheel_turn_frames, ", on run_turn_left/right" if c.anim.has_state(&"run_turn_left") else ", no turn clips: the run"])
	var worst := 0.0
	var meds: Array[float] = []
	var h: float = c.def.height_meters * c.size_scale()
	for run in wheel_runs:
		if (run as Array).size() < 40:
			continue
		var s := _stance_slides(run, h)
		if s.x < INF:
			worst = maxf(worst, s.x)
			meds.append(s.y)
	var med := INF
	if not meds.is_empty():
		med = 0.0
		for m in meds:
			med += m / meds.size()  # mean over the wheels
	if not c.anim.has_state(&"run_turn_left") or not base_slide.has(v):
		print("[t_megajoust] %s live wheel on the plain run: planted hooves slide %.1f cm mean, %.1f cm worst (no turn clips; not gated)" % [name, med * 100.0, worst * 100.0])
	else:
		var base: Vector2 = base_slide[v]
		_expect(med <= base.y + ADD_MED and worst <= base.x + ADD_WORST,
			"%s live wheel: planted hooves slide %.1f cm mean, %.1f cm worst per stance (straight run %.1f / %.1f, + at most %.0f / %.0f)" % [name, med * 100.0, worst * 100.0, base.y * 100.0, base.x * 100.0, ADD_MED * 100.0, ADD_WORST * 100.0])
	if sp == ID and v == &"doe":
		_expect(log.count("joust_run_off") >= 2 and run_s > 2.0 * charge_s,
			"doe is desperate: runs off after her passes (%d) and runs %.1f s against %.1f s charging" % [log.count("joust_run_off"), run_s, charge_s])
	c.queue_free()
	player.queue_free()
	await physics_frame
