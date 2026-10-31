extends SceneTree
## COMPYFEEL (owner 2026-10-31): "compsagnathus needs a strafe left and strafe right animation. its opening attack looks
## like its gliding towards the player when it should lower its center of gravity and charge. It should also have a head
## twitching idle animation, it should look like its itching for a fight"; and "deinonychus actually has the same
## problem where when it charges it glides instead of running" (ankylosaurus attacks glided too).
## Checks:
##  - compy clips load: strafe_left/right, charge and investigate (the combat idle) loop, charge_crouch is a one-shot;
##    the GLB loop lists (RiggedModel.LOOPING and CreatureClips.LOOPING) both list the locomotion loops;
##  - foot slide, stride-matched: each locomotion loop played at a fight speed with the body carried at that speed,
##    the planted toe slips under SLIDE_FRAC of the ground covered per step (compy charge/strafes/run, deinonychus charge/run),
##    and a deliberately mismatched cadence does slide (the measure can fail);
##  - live fights (compy, deinonychus, ankylosaurus): the body never moves while a non-locomotion clip plays (no glide);
##    a compy charge coils in charge_crouch with the body still, then runs on the charge clip at cadence = speed /
##    natural speed; circling plays the strafes; aggro and standing still plays the combat idle.
## Usage: godot --headless --path game --script res://tests/t_compyfeel.gd  -> "[t_compyfeel] PASS"

## A planted toe may slip at most this share of the ground the body covers in one step (median; twice it worst).
## Stride-relative so one rule fits a 1.2 m compy at 11 m/s and a 2.9 m deinonychus (its old run read about 20 %).
const SLIDE_FRAC := 0.1
const LOCO: Array[StringName] = [&"idle", &"investigate", &"walk", &"run", &"charge", &"strafe_left", &"strafe_right", &"walk_back"]
const LEAPS: Array[StringName] = [&"hop_back", &"leap_back", &"pounce", &"dodge_left", &"dodge_right"]

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D
var player: Node

func _process(_delta: float) -> bool:
	if _started or get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	get_root().get_node("Game").debug_overlay = false
	get_root().get_node("Game").time_of_day = 0.40
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_compyfeel] %s %s" % ["ok  " if ok else "FAIL", msg])

func _run() -> void:
	seed(20261031)
	load("res://scripts/combat/combat_tuning.gd").rng.seed = 20261031
	Engine.max_physics_steps_per_frame = 1000
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
	_test_clips()
	_test_slide(&"compsognathus", [&"charge", &"strafe_left", &"strafe_right", &"run"])
	_test_slide(&"deinonychus", [&"charge", &"run"])
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED  # a stationary target
	await _test_fight(&"compsognathus", 25.0)
	await _test_fight(&"deinonychus", 20.0)
	await _test_fight(&"ankylosaurus", 15.0)
	if failures.is_empty():
		print("[t_compyfeel] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_compyfeel] FAIL " + f)
		quit(1)

func _spawn(sp: StringName, at: Vector3, live: bool) -> Node:
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = at
	c.spawn(data.creature(sp), &"", 0, null, 0, &"aggressive")
	if live:
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	else:
		c.set_physics_process(false)
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

func _test_clips() -> void:
	var c = _spawn(&"compsognathus", Vector3(40, 0, 40), false)
	var ap: AnimationPlayer = c.anim.player
	for clip in [&"strafe_left", &"strafe_right", &"charge", &"investigate"]:
		_expect(ap.has_animation(clip) and c.anim.has_state(clip) and ap.get_animation(clip).loop_mode == Animation.LOOP_LINEAR,
			"compy %s loads and loops" % clip)
	_expect(ap.has_animation(&"charge_crouch") and ap.get_animation(&"charge_crouch").loop_mode == Animation.LOOP_NONE,
		"compy charge_crouch loads as a one-shot")
	var rm: Array = load("res://scripts/core/rigged_model.gd").LOOPING
	var cc: Array = load("res://scripts/creatures/creature_clips.gd").LOOPING
	for clip in [&"strafe_left", &"strafe_right", &"walk_back", &"charge", &"investigate"]:
		_expect(clip in rm and clip in cc, "%s is a loop in RiggedModel.LOOPING and CreatureClips.LOOPING" % clip)
	c.free()

## Toe tips (the *_end bones of the hind feet) in world space.
func _toes(c) -> Array[Vector3]:
	var skel: Skeleton3D = c.view.rig.skeleton
	var out: Array[Vector3] = []
	for b in ["BackFoot.L_end", "BackFoot.R_end"]:
		var i := skel.find_bone(b)
		if i >= 0:
			out.append(skel.global_transform * skel.get_bone_global_pose(i).origin)
	return out

## Carry the body at mps along the clip's travel direction, step the tree at 120 Hz, and return the worst and median
## world slide of a planted toe per stance (frames within 1.5 % of height of that toe's lowest point).
func _slide(c, clip: StringName, mps: float, cadence_mult: float = 1.0) -> Vector2:
	var basis: Basis = c.global_basis
	var dir: Vector3 = -basis.z
	if clip == &"strafe_left":
		dir = -basis.x
	elif clip == &"strafe_right":
		dir = basis.x
	if clip in [&"walk", &"run"]:
		c.anim.set_move_speed(mps)
	else:
		c.anim.set_gait_clip(clip, mps, dir * mps, basis)
	if cadence_mult != 1.0:
		c.anim._scale[clip] = float(c.anim._scale[clip]) * cadence_mult
		c.anim._apply(clip)
	var dt := 1.0 / 120.0
	for k in 60:  # past the blend
		c.global_position += dir * mps * dt
		c.anim.tree.advance(dt)
	var h: float = c.def.height_meters
	var frames: Array = []
	for k in 480:
		c.global_position += dir * mps * dt
		c.anim.tree.advance(dt)
		frames.append(_toes(c))
	var slides: Array[float] = []
	for j in (frames[0] as Array).size():
		var lo := 1e9
		for f in frames:
			lo = minf(lo, (f[j] as Vector3).y)
		var start := Vector3.INF
		var prev := Vector3.INF
		for f in frames:
			var p: Vector3 = f[j]
			if p.y <= lo + 0.015 * h:
				if start == Vector3.INF:
					start = p
				prev = p
			elif start != Vector3.INF:
				slides.append(Vector2(prev.x - start.x, prev.z - start.z).length())
				start = Vector3.INF
	if slides.is_empty():
		return Vector2(INF, INF)
	slides.sort()
	return Vector2(slides[-1], slides[slides.size() / 2])

## Ground the body covers in one step (half a cycle) at the clip's current cadence.
func _step_m(c, clip: StringName, mps: float) -> float:
	return mps * c.anim.player.get_animation(clip).length / maxf(0.01, c.anim.cadence(clip)) * 0.5

func _test_slide(sp: StringName, clips: Array) -> void:
	var c = _spawn(sp, Vector3(-40, 0, 40), false)
	var rsm: float = c.run_speed_mult()
	var tac: Dictionary = load("res://scripts/creatures/brains/tactical_brain.gd").tactics_for(c.def.archetype)
	for clip in clips:
		if not c.anim.has_state(clip):
			_expect(false, "%s has a %s clip" % [sp, clip])
			continue
		# the speeds the fight uses: the charge at charge_speed_mult x the sprinting run, the strafes at the circling pace
		var mps: float = c.move_speed_mps() * rsm
		if clip == &"charge":
			mps *= float(tac.get("charge_speed_mult", 1.5))
		elif clip != &"run":
			mps *= float(c.brain.profile.get("chase_speed_mult", 0.7))
		var s: Vector2 = _slide(c, clip, mps)
		var step := _step_m(c, clip, mps)
		_expect(s.y <= SLIDE_FRAC * step and s.x <= 2.0 * SLIDE_FRAC * step,
			"%s %s at %.1f m/s (cadence %.2f, %.2f m per step): planted toe slides %.1f cm median, %.1f cm worst (limits %.1f / %.1f)"
			% [sp, clip, mps, c.anim.cadence(clip), step, s.y * 100.0, s.x * 100.0, SLIDE_FRAC * step * 100.0, 2.0 * SLIDE_FRAC * step * 100.0])
	# the measure can fail: the first clip at half its matched cadence slides
	var mps0: float = c.move_speed_mps() * rsm
	var bad: Vector2 = _slide(c, clips[0], mps0, 0.5)
	var step0 := _step_m(c, clips[0], mps0)
	_expect(bad.y > SLIDE_FRAC * step0, "%s %s at half cadence does slide (%.1f cm median per %.2f m step): the measure catches a glide"
		% [sp, clips[0], bad.y * 100.0, step0])
	c.free()

func _test_fight(sp: StringName, secs: float) -> void:
	var c = _spawn(sp, Vector3(0, 0.1, -6.0), true)
	await physics_frame
	if c.brain.get("rng") is RandomNumberGenerator:
		c.brain.rng.seed = 20261031  # the brain's own dice, so the fight replays the same
	c.brain.on_aggro(player)
	var glide := 0
	var glide_clips: Dictionary = {}
	var crouch_frames := 0
	var crouch_moving := 0
	var charge_frames := 0
	var cadence_off := 0
	var strafe_circle := 0
	var hop_circle := 0
	var aware_still := 0
	var aware_combat_idle := 0
	var prev: Vector3 = c.global_position
	var last_clip: StringName = &""
	var hz := float(Engine.physics_ticks_per_second)
	var nat: float = load("res://scripts/creatures/creature_clips.gd").natural_speed(c.def, &"charge")
	for k in int(secs * hz):
		await physics_frame
		player.vitals.health = player.vitals.effective_max_health()
		if not is_instance_valid(c) or c.health.dead:
			break
		var pos: Vector3 = c.global_position
		var mps := Vector2(pos.x - prev.x, pos.z - prev.z).length() * hz
		prev = pos
		var clip: StringName = c.anim.current_clip
		var prev_clip := last_clip
		last_clip = clip
		# The frame a strike starts still carries the run's last step (the brain switches the clip after the body
		# moved), so a glide is a non-locomotion clip on two frames in a row with the body moving.
		if mps > 0.3 and not clip in LOCO and not clip in LEAPS and clip == prev_clip:
			glide += 1
			glide_clips[clip] = true
		if clip == &"charge_crouch":
			crouch_frames += 1
			crouch_moving += 1 if mps > 0.3 and clip == prev_clip else 0
		if clip == &"charge" and c.brain.state == &"charge" and mps > 0.5 and c.anim.current_state() == &"charge":
			charge_frames += 1
			var want: float = Vector2(c.velocity.x, c.velocity.z).length() / nat
			if absf(c.anim.cadence(&"charge") - want) > want * 0.05:
				cadence_off += 1
		if c.brain.state == &"circle" and clip in [&"strafe_left", &"strafe_right"]:
			strafe_circle += 1
		if clip in [&"dodge_left", &"dodge_right", &"hop_back", &"leap_back"]:
			hop_circle += 1
		if c.brain.aware_idle() and mps < 0.05 and not c.anim.is_busy() and c.anim.current_state() in [&"idle", &"investigate"]:
			aware_still += 1
			aware_combat_idle += 1 if clip == &"investigate" else 0
	_expect(glide == 0, "%s: no frame moves the body under a non-locomotion clip (%d frames, %s)" % [sp, glide, glide_clips.keys()])
	if sp == &"compsognathus":
		_expect(crouch_frames > 0 and crouch_moving == 0, "compy charges coil in charge_crouch first, body still (%d frames, %d moving)" % [crouch_frames, crouch_moving])
		_expect(charge_frames > 10 and cadence_off == 0, "compy charge runs on the charge clip at cadence = speed / natural speed (%d frames, %d off)" % [charge_frames, cadence_off])
		# HOPSTRAFE (owner 2026-10-31): a small animal hops around more than it strafes, but still strafes.
		_expect(strafe_circle > 10 and hop_circle > strafe_circle, "compy repositions in bounds (dodge/hop_back/leap_back, %d frames) more than it strafe-walks on the ring (strafe_left/right, %d frames)" % [hop_circle, strafe_circle])
		_expect(aware_still > 20 and aware_combat_idle == aware_still, "compy aggro and standing still plays the combat idle (%d of %d frames)" % [aware_combat_idle, aware_still])
	c.queue_free()
	await physics_frame
