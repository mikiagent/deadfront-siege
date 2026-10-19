extends SceneTree
## W1-CANIM acceptance: the creature AnimationTree obeys time scale, stride-matched speed, loop
## trims and optional clips. Run: Godot --headless --path game --script res://tests/t_canim.gd
## Prints "[t_canim] PASS" and exits 0, or FAIL lines and exits 1. Trees advance manually, so
## every number is in exact tree time, independent of how fast the headless loop spins.

const DT := 1.0 / 60.0
const FEET := ["BackFoot.L", "Toe.L", "Metatarsal.L"]
const STRIDE_SPECIES: Array[StringName] = [&"velociraptor", &"megaloceros", &"protoceratops", &"tyrannosaurus"]
## ASSUMPTION: a species walks at 40 % of its listed speed; defs and the PRD give one top speed.
const WALK_FRAC := 0.4
const TYRANT_HEAVY_WINDUP := 1.2  # tyrant_brain.gd _do_attack: phase_left for attack_heavy

var failures: Array[String] = []
var _started := false
var data: Node
var clips: GDScript

## Creature classes reference the Data autoload, which exists only after the first frame.
func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	clips = load("res://scripts/creatures/creature_clips.gd")
	_test_time_scale()
	_test_tyrant_hit_timing()
	_test_stride_match()
	_test_walk_loops_not_frozen()
	_test_optional_clips()
	if failures.is_empty():
		print("[t_canim] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_canim] FAIL " + f)
		quit(1)
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_canim] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _spawn(id: StringName):
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	root.add_child(c)
	c.spawn(data.creature(id))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

func _advance(c, seconds: float, step: float = DT) -> void:
	var t := 0.0
	while t < seconds - 0.00001:
		c.anim.tree.advance(step)
		t += step

## Tree-time advance per second of wall time while `node` plays.
func _ratio(c, node: StringName, frames: int) -> float:
	var pb: AnimationNodeStateMachinePlayback = c.anim._playback
	_advance(c, 8 * DT)  # let the travel and its 0.08 s crossfade finish
	if pb.get_current_node() != node:
		return -1.0
	var length := pb.get_current_length()
	var p0 := pb.get_current_play_position()
	_advance(c, frames * DT)
	return fposmod(pb.get_current_play_position() - p0, length) / (frames * DT)

func _test_time_scale() -> void:
	var c = _spawn(&"velociraptor")
	var anim = c.anim
	anim.play_timed_attack(&"attack_primary", 2.0)
	var scale: float = anim._effective(&"attack_primary")
	var r := _ratio(c, &"attack_primary", 30)
	_expect(r >= 0.16 and r <= 0.21, "velociraptor attack_primary timed to 2.0 s: time scale %.3f, tree advance / wall = %.3f (want 0.16-0.21, was 1.000)" % [scale, r])
	anim.end_timed_attack()
	anim.play_locomotion(1.0)
	r = _ratio(c, &"run", 12)
	_expect(r >= 1.5 and r <= 1.7, "velociraptor run at anim_events speed 1.6: tree advance / wall = %.3f (want 1.5-1.7)" % r)
	anim.play_idle()
	anim.set_time_scale(0.5)
	r = _ratio(c, &"idle", 30)
	_expect(absf(r - 0.5) <= 0.02, "set_time_scale(0.5) on idle: tree advance / wall = %.3f" % r)
	anim.set_time_scale(1.0)
	c.free()

func _test_tyrant_hit_timing() -> void:
	var c = _spawn(&"tyrannosaurus")
	var anim = c.anim
	var pb: AnimationNodeStateMachinePlayback = anim._playback
	var length: float = anim.player.get_animation(&"attack_heavy").length
	var hit_pos: float = length * clips._hit_frac(&"attack_heavy")
	anim.play_timed_attack(&"attack_heavy", TYRANT_HEAVY_WINDUP)
	var step := 1.0 / 240.0
	var t := 0.0
	var hit_t := -1.0
	while t < 4.0 and hit_t < 0.0:
		anim.tree.advance(step)
		t += step
		if pb.get_current_node() == &"attack_heavy" and pb.get_current_play_position() >= hit_pos:
			hit_t = t
	_expect(hit_t >= 0.0 and absf(hit_t - TYRANT_HEAVY_WINDUP) <= 0.05, "tyrannosaurus attack_heavy (len %.3f s, hit_frac pos %.3f s): animation hit at %.3f s, brain damage at %.3f s, gap %.3f s (want <= 0.05, was 0.65)" % [length, hit_pos, hit_t, TYRANT_HEAVY_WINDUP, absf(hit_t - TYRANT_HEAVY_WINDUP)])
	c.free()

## Stride method of the dino-art audit (scratchpad/audit/dino-art/tools/stride.gd), applied to the
## tree's live output: median foot z-velocity while the foot is within tol of its lowest point.
func _planted_speed(c, seconds: float, samples: int) -> float:
	var skel: Skeleton3D = c.view.rig.skeleton
	var foot := -1
	for f in FEET:
		if foot == -1:
			foot = skel.find_bone(f)
	var ys := PackedFloat32Array()
	var zs := PackedFloat32Array()
	var step := seconds / float(samples)
	for i in samples + 1:
		if i > 0:
			c.anim.tree.advance(step)
		var p: Vector3 = c.view.to_local(skel.global_transform * skel.get_bone_global_pose(foot).origin)
		ys.append(p.y)
		zs.append(p.z)
	var ymin := ys[0]
	for y in ys:
		ymin = minf(ymin, y)
	var tol := maxf(0.02, float(c.def.height_meters) * 0.015)
	var vels: Array[float] = []
	for i in samples:
		if ys[i] <= ymin + tol and ys[i + 1] <= ymin + tol:
			vels.append((zs[i + 1] - zs[i]) / step)
	vels.sort()
	return absf(vels[vels.size() / 2]) if vels.size() > 0 else 0.0

func _test_stride_match() -> void:
	for id in STRIDE_SPECIES:
		var c = _spawn(id)
		var top: float = c.def.move_speed_mps
		for v in [top * WALK_FRAC, top]:
			c.anim.set_move_speed(v)
			_advance(c, 0.5)  # gait crossfade is 0.2 s
			var gait: StringName = c.anim.current_clip
			var cadence: float = c.anim._effective(gait)
			var cycle: float = c.anim.player.get_animation(gait).length / maxf(0.01, cadence)
			var foot_speed := _planted_speed(c, cycle * 2.0, 480)
			var ratio: float = foot_speed / v
			_expect(ratio >= 0.75 and ratio <= 1.30, "%s set_move_speed(%.2f) -> %s x%.2f: planted foot %.2f m/s, ratio %.2f (want 0.75-1.30)" % [id, v, gait, cadence, foot_speed, ratio])
		c.free()

## Longest span (fraction of the loop, wrapping) in which no bone channel moves more than 1e-4.
func _frozen_fraction(anim: Animation) -> float:
	var n := 120
	var prev: Array = []
	var moving: Array[bool] = []
	for i in n + 1:
		var at := anim.length * float(i) / float(n)
		var cur: Array = []
		for t in anim.get_track_count():
			match anim.track_get_type(t):
				Animation.TYPE_POSITION_3D:
					cur.append(anim.position_track_interpolate(t, at))
				Animation.TYPE_ROTATION_3D:
					var q: Quaternion = anim.rotation_track_interpolate(t, at)
					cur.append(Vector4(q.x, q.y, q.z, q.w))
				Animation.TYPE_SCALE_3D:
					cur.append(anim.scale_track_interpolate(t, at))
		if i > 0:
			var moved := false
			for k in cur.size():
				var d = cur[k] - prev[k]  # Vector3 or Vector4
				if d.length() > 0.0001:
					moved = true
					break
			moving.append(moved)
		prev = cur
	var best := 0
	var run := 0
	for i in n * 2:
		run = 0 if moving[i % n] else run + 1
		best = maxi(best, mini(run, n))
	return float(best) / float(n)

func _test_walk_loops_not_frozen() -> void:
	var worst := 0.0
	var checked := 0
	for id in data.creatures.keys():
		var def = data.creature(id)
		if def.rig != "biped" or not ResourceLoader.exists("res://assets/creatures/%s/anim/walk.glb" % id):
			continue
		var c = _spawn(id)
		var walk: Animation = c.anim.player.get_animation(&"walk")
		var frac := _frozen_fraction(walk)
		worst = maxf(worst, frac)
		checked += 1
		print("[t_canim] %s walk loop %.3f s, longest frozen span %.0f %%" % [id, walk.length, frac * 100.0])
		c.free()
	_expect(checked >= 6 and worst <= 0.25, "%d biped walk loops: longest frozen span %.0f %% (want <= 25 %%, was 51 %%)" % [checked, worst * 100.0])

func _test_optional_clips() -> void:
	var rex = _spawn(&"tyrannosaurus")
	var pb: AnimationNodeStateMachinePlayback = rex.anim._playback
	for clip in [&"sleep", &"feed", &"tail_swipe"]:
		rex.anim.play_clip(clip, true)
		_advance(rex, 0.25)
		_expect(pb.get_current_node() == clip and rex.anim.current_clip == clip, "tyrannosaurus play_clip(%s): state machine on %s" % [clip, pb.get_current_node()])
		rex.anim.play_clip(&"idle")
		_advance(rex, 0.25)
	rex.free()
	var raptor = _spawn(&"velociraptor")
	pb = raptor.anim._playback
	raptor.anim.play_clip(&"sleep", true)
	_advance(raptor, 0.25)
	_expect(pb.get_current_node() == &"idle" and raptor.anim.current_clip == &"idle" and not raptor.anim._param.has(&"sleep"), "velociraptor play_clip(sleep) has no sleep node and stays on %s" % pb.get_current_node())
	raptor.free()
