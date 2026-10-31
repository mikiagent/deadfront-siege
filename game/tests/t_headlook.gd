extends SceneTree
## HEADLOOK acceptance (scripts/creatures/head_look.gd). For every rigged species:
##  - in idle, aware of a survivor standing 30 deg to its left, the head (neck chain + head) turns toward her: the
##    head bone's added yaw is on her side, within the species clamp, and close to min(30 deg, clamp);
##  - she steps to the right: the head follows to the right;
##  - during an attack clip the look's weight is 0 and the head bone is exactly where the clip put it (hit sweeps
##    read these bones);
##  - she walks behind it: the look fades out;
##  - nothing pops: the head's added yaw never changes more than MAX_STEP_DEG in one 60 fps frame.
## Also times the modifier on CAP animals at once (the perf budget's creature cap).
## Trees and skeletons advance manually at 60 fps, so every number is exact.
## Run: Godot --headless --path game --script res://tests/t_headlook.gd -> "[t_headlook] PASS", 0/1.

const DT := 1.0 / 60.0
const MAX_STEP_DEG := 6.0  # X: the most the head's look may change in one 60 fps frame
const AIM_TOL_DEG := 6.0
const CAP := 24  # data/perf_budget.json creatures.max
const COST_US_MAX := 60.0  # per animal per frame

## Records the head bone's global pose before HeadLook runs (it sits right before it in the modifier list).
class Probe extends SkeletonModifier3D:
	var bone := -1
	var pre := Transform3D.IDENTITY
	func _process_modification_with_delta(_dt: float) -> void:
		pre = get_skeleton().get_bone_global_pose(bone)

var failures: Array[String] = []
var _started := false
var data: Node

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	var hl_script: GDScript = load("res://scripts/creatures/head_look.gd")
	var off: Array = hl_script.default_off_clips()
	_expect(&"attack_primary" in off and &"roar" in off and &"death" in off and &"hit_react" in off, "default off clips cover attacks, roar, death, hit_react")
	_expect(not (&"idle" in off or &"walk" in off or &"alert" in off), "idle, walk and alert keep the look")
	var ids: Array[StringName] = []
	for f in DirAccess.get_files_at("res://data/creatures"):
		var id := StringName(f.get_basename())
		if f.ends_with(".json") and data.creature(id) != null and not f in ["ai.json", "anim_events.json", "hitboxes.json", "natures.json", "ragdoll.json"]:
			ids.append(id)
	var tested := 0
	for id in ids:
		if _test_species(id):
			tested += 1
	_expect(tested >= 20, "%d rigged species tested" % tested)
	_test_cost()
	if failures.is_empty():
		print("[t_headlook] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_headlook] FAIL " + f)
		quit(1)
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_headlook] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _spawn(id: StringName, at: Vector3):
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	root.add_child(c)
	c.spawn(data.creature(id))
	c.global_position = at
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	if c.anim.tree:
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

## The clip, then the modifiers in their skeleton order (the skeleton's own pass is set to manual and never runs here).
func _step(c, sk: Skeleton3D) -> void:
	c.anim.tree.advance(DT)
	for m in sk.get_children():
		if m is SkeletonModifier3D and (m as SkeletonModifier3D).active and m.has_method(&"_process_modification_with_delta"):
			m._process_modification_with_delta(DT)

## The head's added yaw this frame in degrees (+ = left), from the probe's pre-look pose to the post-look pose.
func _added_yaw(c, sk: Skeleton3D, probe: Probe) -> float:
	var post := sk.get_bone_global_pose(probe.bone).basis.orthonormalized()
	var d := post * probe.pre.basis.orthonormalized().inverse()  # skeleton space
	var vb: Basis = c.view.global_basis.orthonormalized()
	var skb := sk.global_basis.orthonormalized()
	var fwd_sk := (skb.inverse() * (vb * Vector3.FORWARD)).normalized()
	var turned := vb.inverse() * (skb * (d * fwd_sk))
	return rad_to_deg(atan2(-turned.x, -turned.z))

func _test_species(id: StringName) -> bool:
	var c = _spawn(id, Vector3.ZERO)
	var hl = c.view.head_look
	if c.view.rig == null or hl == null:
		print("[t_headlook] skip %s (no rig or no head bone)" % id)
		c.free()
		return false
	var sk: Skeleton3D = c.view.rig.skeleton
	var probe := Probe.new()
	probe.bone = hl._head
	sk.add_child(probe)
	sk.move_child(probe, hl.get_index())
	sk.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	var her := Node3D.new()
	root.add_child(her)
	c.brain.attack_target = her
	c.brain.state = &"alert"
	c.anim.play_idle(true)
	_step(c, sk)
	var head_w: Vector3 = sk.global_transform * sk.get_bone_global_pose(hl._head).origin
	var fwd: Vector3 = -c.global_basis.z
	fwd.y = 0.0
	var dist := maxf(8.0, c.def.real_length_m * 1.5)
	var clamp_deg := rad_to_deg(hl.yaw_max)
	var place := func(deg: float) -> void:
		var p: Vector3 = head_w + fwd.normalized().rotated(Vector3.UP, deg_to_rad(deg)) * dist
		her.global_position = Vector3(p.x, 0.0, p.z)
	var st := {"worst": 0.0, "prev": 0.0}  # lambdas capture locals by value
	var run := func(frames: int) -> float:
		for i in frames:
			_step(c, sk)
			var y := _added_yaw(c, sk, probe)
			st.worst = maxf(st.worst, absf(y - st.prev))
			st.prev = y
		return st.prev
	place.call(30.0)
	var left: float = run.call(90)
	var want := minf(30.0, clamp_deg)
	_expect(left > 0.0 and left <= clamp_deg + 0.5 and absf(left - want) <= AIM_TOL_DEG,
		"%s idle: head turns %.1f deg left toward her at 30 deg (clamp %.0f)" % [id, left, clamp_deg])
	place.call(-30.0)
	var right: float = run.call(90)
	_expect(right < 0.0 and absf(right + want) <= AIM_TOL_DEG, "%s idle: head follows her to the right (%.1f deg)" % [id, right])
	place.call(30.0)
	run.call(60)
	var clip: StringName = &"attack_primary" if c.anim.has_state(&"attack_primary") else &"hit_react"
	c.anim.play_clip(clip, true)
	var prev: float = run.call(int(ceil(hl.FADE_OFF_S / DT)) + 2)
	var during: float = hl.weight
	var still := absf(prev) < 0.01
	_expect(during == 0.0 and still and c.anim.current_clip == clip,
		"%s during %s: look weight %.3f, head on its clip pose (%.3f deg)" % [id, clip, during, prev])
	c.anim.play_idle(true)
	c.brain.state = &"alert"
	run.call(60)
	place.call(170.0)
	prev = run.call(60)
	_expect(hl.weight == 0.0 and absf(prev) < 0.01, "%s: the look fades out with her behind it (weight %.2f)" % [id, hl.weight])
	_expect(st.worst <= MAX_STEP_DEG, "%s: no pop, worst per-frame change %.2f deg (max %.1f)" % [id, st.worst, MAX_STEP_DEG])
	c.free()
	her.free()
	return true

## CAP animals looking at once: the modifier's own cost per animal per frame.
func _test_cost() -> void:
	var her := Node3D.new()
	root.add_child(her)
	her.global_position = Vector3(0, 0, -30)
	var herd: Array = []
	for i in CAP:
		var c = _spawn(&"velociraptor" if i % 2 == 0 else &"tyrannosaurus", Vector3((i % 6) * 6.0 - 15.0, 0, (i / 6) * 6.0))
		c.brain.attack_target = her
		c.brain.state = &"alert"
		c.anim.play_idle(true)
		var sk: Skeleton3D = c.view.rig.skeleton
		_step(c, sk)
		herd.append(c)
	var frames := 120
	var t0 := Time.get_ticks_usec()
	for f in frames:
		for c in herd:
			c.view.head_look._process_modification_with_delta(DT)
	var us := float(Time.get_ticks_usec() - t0) / float(frames * CAP)
	print("[t_headlook] cost: %.1f us per animal per frame, %.2f ms for %d animals" % [us, us * CAP / 1000.0, CAP])
	_expect(us <= COST_US_MAX, "head look costs %.1f us per animal per frame (max %.0f)" % [us, COST_US_MAX])
	for c in herd:
		c.free()
	her.free()
