extends SceneTree
## MEGARUN (owner 2026-10-31, god-mode fight lab): "the run animation is cursed too, especially obvious on the alpha
## variant". Megaloceros stag, doe and alpha (the stag at its alpha size) run in a straight line at their own run
## speed (move_speed_mps x run_speed_mult), stride-matched by CreatureAnim; also the stag at the normal size range's
## ends. Every planted hoof (frames within 2.5 cm of that hoof's lowest point) may slide at most MAX_SLIP per stance,
## worst stance of 8 s. Also: CreatureAnim's stride match scales with size_scale() (a 1.3x body takes 1.3x strides),
## and a strafe clip never plays for megaloceros outside the joust (it falls back to the forward walk).
## Usage: godot --headless --path game --script res://tests/t_megarun.gd  -> "[t_megarun] PASS"

const ID := &"megaloceros"
const MAX_SLIP := 0.05
const TOES := ["FrontFoot.L", "FrontFoot.R", "BackFoot.L", "BackFoot.R"]

var failures: Array[String] = []
var _started := false
var data: Node
var host: Node3D

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
	print("[t_megarun] %s %s" % ["ok  " if ok else "FAIL", msg])

func _run() -> void:
	host = Node3D.new()
	get_root().add_child(host)
	for row in [[&"stag", 1.0, false], [&"doe", 1.0, false], [&"stag", 0.0, true], [&"doe", 0.0, true],
			[&"stag", 0.85, false], [&"stag", 1.15, false], [&"doe", 0.85, false]]:
		_test_run(row[0], row[1], row[2])
	for row in [[&"stag", 1.0, false], [&"doe", 1.0, false], [&"stag", 0.0, true]]:
		_test_run(row[0], row[1], row[2], &"walk")
	_test_no_strafe()
	for v in [&"stag", &"doe"]:
		_test_legs(v)
	if failures.is_empty():
		print("[t_megarun] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_megarun] FAIL " + f)
		quit(1)

func _spawn(v: StringName, size: float, alpha: bool) -> Node:
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	host.add_child(c)
	c.global_position = Vector3(0, 0, 0)
	var g = load("res://scripts/creatures/creature_genetics.gd").new()
	if alpha:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		g.make_alpha(rng)
	else:
		g.size = size
	c.genetics = g
	c.spawn(data.creature(ID), v, 0, null, 0, &"aggressive")
	c.set_physics_process(false)
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

func _toes(c) -> Array[Vector3]:
	var skel: Skeleton3D = c.view.rig.skeleton
	var out: Array[Vector3] = []
	for b in TOES:
		var i := skel.find_bone(b + "_end")
		if i < 0:
			i = skel.find_bone(b)
		out.append(skel.global_transform * skel.get_bone_global_pose(i).origin)
	return out

## Per hoof: the worst world slide over any stance (a stance is the frames within 2.5 cm of the hoof's lowest point),
## then per hoof the share of frames it was planted (out[4..7]), so a stance the band misses cannot pass by default.
static func _worst_per_hoof(frames: Array) -> Array[float]:
	var out: Array[float] = []
	var share: Array[float] = []
	for j in (frames[0] as Array).size():
		var lo := 1e9
		for f in frames:
			lo = minf(lo, (f[j] as Vector3).y)
		var worst := 0.0
		var start := Vector3.INF
		var prev := Vector3.INF
		var n := 0
		var planted := 0
		for f in frames:
			var p: Vector3 = f[j]
			if p.y <= lo + 0.025:
				planted += 1
				if start == Vector3.INF:
					start = p
				prev = p
				# max distance from touchdown within the stance (a there-and-back slide still counts)
				worst = maxf(worst, Vector2(p.x - start.x, p.z - start.z).length())
			elif start != Vector3.INF:
				start = Vector3.INF
				n += 1
		out.append(worst if n > 0 else INF)
		share.append(float(planted) / frames.size())
	out.append_array(share)
	return out

func _test_run(v: StringName, size: float, alpha: bool, gait: StringName = &"run") -> void:
	var c = _spawn(v, size, alpha)
	var mps: float = c.move_speed_mps() * c.run_speed_mult() if gait == &"run" else 2.0 * c.size_scale()
	var label := "%s%s size %.2f" % [v, " ALPHA" if alpha else "", c.size_scale()]
	c.rotation = Vector3.ZERO
	c.anim.set_move_speed(mps)
	_expect(c.anim.current_clip == gait, "%s at %.1f m/s plays the %s (%s)" % [label, mps, gait, c.anim.current_clip])
	var dt := 1.0 / 60.0
	var frames: Array = []
	var p0: Vector3 = c.global_position
	for k in 540:
		c.global_position = p0 + Vector3(0, 0, -mps * dt * k)  # it faces -Z
		c.anim.tree.advance(dt)
		if k >= 60:  # past the blend from idle
			frames.append(_toes(c))
	var w := _worst_per_hoof(frames)
	var worst := 0.0
	var least := 1.0
	for j in 4:
		worst = maxf(worst, w[j])
		least = minf(least, w[4 + j])
	_expect(worst <= MAX_SLIP, "%s %s at %.1f m/s (cadence %.2f): worst slip per stance FL %.1f FR %.1f HL %.1f HR %.1f cm (max %.0f)"
		% [label, gait, mps, c.anim.cadence(gait), w[0] * 100.0, w[1] * 100.0, w[2] * 100.0, w[3] * 100.0, MAX_SLIP * 100.0])
	# the gallop plants each hoof for 34 % of the cycle, the last fifth of it rolling up off the heel (the walk 66 %): the
	# band must see at least 20 % (a hoof that bobbed in stance would fall out of it and slip unmeasured)
	_expect(least >= 0.20, "%s: every hoof planted at least 20 %% of the %s (least %.0f %%)" % [label, gait, least * 100.0])
	c.queue_free()

## Outside the joust nothing may play a megaloceros strafe (the owner: "strafe left animation is cursed"): a sideways
## velocity plays the forward walk instead.
func _test_no_strafe() -> void:
	for v in [&"stag", &"doe"]:
		var c = _spawn(v, 1.0, false)
		for sgn in [1.0, -1.0]:
			c.anim.set_move_velocity(Vector3(sgn * 2.0, 0, 0), Basis.IDENTITY)
			_expect(c.anim.current_clip == &"walk", "%s sideways at 2 m/s plays %s (the walk, no strafe)" % [v, c.anim.current_clip])
		c.queue_free()

## LEGS (owner 2026-10-31 on the canon lab: "the motion is right but the legs are getting mangled"): every locomotion
## clip, sampled at 60 Hz, per leg bone:
##  - twist about the bone's own axis relative to its parent (the candy wrapper), at most MAX_TWIST from rest, and at
##    most MAX_TWIST_STEP between samples (a roll flip);
##  - the stifle bends forward and the hock back (hind), the elbow back (front), the carpus folds forward; a joint
##    straighter than STRAIGHT_DEG is not judged.
## Bones are built with local X = the body's left on every leg bone (build_rig.py), so Y is the bone axis.
const LOCO_CLIPS: Array[StringName] = [&"walk", &"run", &"charge", &"walk_back", &"run_turn_left", &"run_turn_right"]
const LEG_BONES := ["Scapula", "Upper", "Lower", "Cannon", "Foot"]
const MAX_TWIST := 30.0
const MAX_TWIST_STEP := 30.0
const STRAIGHT_DEG := 8.0

static func _leg_bone(front: bool, part: String, side: String) -> String:
	if part == "Foot":
		return ("FrontFoot." if front else "BackFoot.") + side
	return ("Front" if front else "Hind") + part + "." + side

## Twist (deg) of a rotation about axis.
static func _twist_deg(q: Quaternion, axis: Vector3) -> float:
	var p := Vector3(q.x, q.y, q.z).dot(axis)
	var t := 2.0 * atan2(p, q.w)
	return rad_to_deg(wrapf(t, -PI, PI))

func _test_legs(v: StringName) -> void:
	var c = _spawn(v, 1.0, false)
	var sk: Skeleton3D = c.view.rig.skeleton
	var ap: AnimationPlayer = c.view.rig.anim_player
	var inv: Basis = c.global_basis.inverse()
	for clip in LOCO_CLIPS:
		if not ap.has_animation(clip):
			continue
		var a := ap.get_animation(clip)
		sk.reset_bone_poses()
		ap.play(clip)
		var worst_twist := 0.0
		var worst_step := 0.0
		var where := ""
		var bends := 0
		var bend_where := ""
		var prev := {}
		var n := int(ceil(a.length * 60.0))
		for i in n + 1:
			ap.seek(a.length * float(i) / float(n), true)
			for front in [true, false]:
				for side in ["L", "R"]:
					var pts: Array[Vector3] = []
					for part in LEG_BONES:
						var name := _leg_bone(front, part, side)
						var b := sk.find_bone(name)
						if b < 0:
							continue
						var local := sk.get_bone_rest(b).basis.get_rotation_quaternion().inverse() * sk.get_bone_pose_rotation(b)
						var tw := _twist_deg(local, Vector3.UP)
						if absf(tw) > worst_twist:
							worst_twist = absf(tw)
							where = "%s %.0f%%" % [name, 100.0 * i / n]
						if prev.has(name):
							var step := absf(wrapf(tw - float(prev[name]), -180.0, 180.0))
							if step > worst_step:
								worst_step = step
						prev[name] = tw
						if part != "Scapula" and part != "Foot":
							pts.append(inv * (sk.global_transform * sk.get_bone_global_pose(b).origin))
					pts.append(inv * (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(_leg_bone(front, "Foot", side))).origin))
					# pts: upper top, knee/elbow, hock/carpus, fetlock. Forward is -Z, left +X: bend sign about +X.
					for j in 2:
						var d1: Vector3 = pts[j + 1] - pts[j]
						var d2: Vector3 = pts[j + 2] - pts[j + 1]
						var ang := rad_to_deg(Vector2(d1.z, d1.y).angle_to(Vector2(d2.z, d2.y)))
						if absf(ang) < STRAIGHT_DEG:
							continue
						# hind: stifle apex forward, hock apex back; front: elbow apex back, carpus apex forward
						var want := (1.0 if j == 0 else -1.0) * (-1.0 if front else 1.0)
						if signf(ang) != want:
							bends += 1
							if bend_where == "":
								bend_where = "%s %s %s %.0f deg at %.0f%%" % ["front" if front else "hind", side, ["upper joint", "lower joint"][j], ang, 100.0 * i / n]
		_expect(worst_twist <= MAX_TWIST and worst_step <= MAX_TWIST_STEP,
			"%s %s: leg bones twist at most %.0f deg about their axis (worst %.1f at %s), %.1f deg between 60 Hz samples" % [v, clip, MAX_TWIST, worst_twist, where, worst_step])
		_expect(bends == 0, "%s %s: knees, hocks, elbows and carpi bend the right way (%d wrong samples%s)" % [v, clip, bends, ", first " + bend_where if bends else ""])
	c.queue_free()
