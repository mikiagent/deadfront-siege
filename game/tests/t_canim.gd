extends SceneTree
## W1-CANIM acceptance: the creature AnimationTree obeys time scale, stride-matched speed, loop
## trims and optional clips. Run: Godot --headless --path game --script res://tests/t_canim.gd
## Prints "[t_canim] PASS" and exits 0, or FAIL lines and exits 1. Trees advance manually, so
## every number is in exact tree time, independent of how fast the headless loop spins.

const DT := 1.0 / 60.0
const FEET := ["BackFoot", "Toe", "Metatarsal"]  # + ".L" / ".R", as tools/bake_clip_speeds.py
const STRIDE_SPECIES: Array[StringName] = [&"velociraptor", &"megaloceros", &"protoceratops", &"tyrannosaurus"]
## ASSUMPTION: a species walks at 40 % of its listed speed; defs and the PRD give one top speed.
const WALK_FRAC := 0.4

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
	_test_oneshot_tree_time()
	_test_bad_input_and_stale_bake()
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
	var pb: AnimationNodeStateMachinePlayback = c.anim.tree.get("parameters/playback")
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
	var scale: float = anim.cadence(&"attack_primary")
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

## The windup comes from the real TyrantBrain: it is aimed at a target in reach on its third attack
## (the heavy), so a brain retune moves the expectation with it.
func _test_tyrant_hit_timing() -> void:
	var c = _spawn(&"tyrannosaurus")
	var anim = c.anim
	var brain = c.brain
	var target := Node3D.new()
	root.add_child(target)
	target.global_position = c.global_position - c.global_basis.z * (brain.contact_reach() * 0.5)
	brain.attack_target = target
	brain.attack_number = 2
	brain._do_attack()
	var windup: float = brain.phase_left
	var pb: AnimationNodeStateMachinePlayback = anim.tree.get("parameters/playback")
	var length: float = anim.player.get_animation(&"attack_heavy").length
	var hit_pos: float = length * clips._hit_frac(&"attack_heavy")
	var step := 1.0 / 240.0
	var t := 0.0
	var hit_t := -1.0
	while t < 4.0 and hit_t < 0.0:
		anim.tree.advance(step)
		t += step
		if pb.get_current_node() == &"attack_heavy" and pb.get_current_play_position() >= hit_pos:
			hit_t = t
	_expect(brain.windup_clip == &"attack_heavy" and windup > 0.0 and hit_t >= 0.0 and absf(hit_t - windup) <= 0.05, "tyrannosaurus %s (len %.3f s, hit_frac pos %.3f s): animation hit at %.3f s, TyrantBrain damage at %.3f s, gap %.3f s (want <= 0.05, was 0.65)" % [brain.windup_clip, length, hit_pos, hit_t, windup, absf(hit_t - windup)])
	target.free()
	c.free()

## attack_hit / attack_done follow tree time: at a slowed time scale, and when the scale changes mid-swing.
func _test_oneshot_tree_time() -> void:
	var c = _spawn(&"velociraptor")
	var anim = c.anim
	var length: float = anim.player.get_animation(&"attack_primary").length
	var frac: float = clips._hit_frac(&"attack_primary")
	var cad: float = clips.clip_speed(&"attack_primary", c.def)
	var ev := {}
	anim.attack_hit.connect(func (_clip: StringName) -> void: ev["hit"] = ev.get("t", 0.0))
	anim.attack_done.connect(func () -> void: ev["done"] = ev.get("t", 0.0))
	var step := 1.0 / 240.0
	# [label, time scale before 0.1 s, after]; expected times are tree-time integrals of that schedule.
	for run in [["time scale 0.5", 0.5, 0.5], ["hit-stop 0.1 for 0.1 s then 1.0", 0.1, 1.0]]:
		ev.clear()
		anim.set_time_scale(run[1])
		anim.play_clip(&"attack_primary")
		var t := 0.0
		while t < 6.0 and not ev.has("done"):
			if t >= 0.1:
				anim.set_time_scale(run[2])
			anim.tree.advance(step)
			t += step
			ev["t"] = t
		var head: float = 0.1 * run[1] * cad
		var want_hit: float = 0.1 + (length * frac - head) / (run[2] * cad) if length * frac > head else length * frac / (run[1] * cad)
		var want_done: float = 0.1 + (length - head) / (run[2] * cad)
		var hit: float = ev.get("hit", -1.0)
		var done: float = ev.get("done", -1.0)
		_expect(absf(hit - want_hit) <= 0.05 and absf(done - want_done) <= 0.05 and not anim._busy, "velociraptor attack_primary, %s: attack_hit at %.3f s (want %.3f), attack_done at %.3f s (want %.3f), busy after %s (was hit 3.399 s, done 8.477 s for hit-stop)" % [run[0], hit, want_hit, done, want_done, anim._busy])
	anim.set_time_scale(1.0)
	c.free()

func _test_bad_input_and_stale_bake() -> void:
	var c = _spawn(&"velociraptor")
	var anim = c.anim
	anim.set_move_speed(NAN)
	anim.set_move_speed(INF)
	anim.set_time_scale(INF)
	anim.set_time_scale(NAN)
	var cad: float = anim.cadence(anim.current_clip)
	_expect(is_finite(cad), "set_move_speed(NAN/INF) and set_time_scale(INF/NAN) are ignored: %s cadence %s" % [anim.current_clip, cad])
	var walk_len: float = anim.player.get_animation(&"walk").length
	var fresh: float = clips.natural_speed(c.def, &"walk", walk_len)
	var stale: float = clips.natural_speed(c.def, &"walk", walk_len * 1.05)
	_expect(fresh > 0.0 and stale == 0.0, "velociraptor walk bake: %.3f m/s on the %.3f s clip, %.3f on a 5 %% longer clip (stale bake ignored)" % [fresh, walk_len, stale])
	c.free()

## Stride method of the dino-art audit (scratchpad/audit/dino-art/tools/stride.gd), applied to the
## tree's live output: median foot z-velocity while the foot is within tol of its lowest point.
## Returns [left, right] planted-foot speeds sampled in one pass over the live tree.
func _planted_speeds(c, seconds: float, samples: int) -> Array[float]:
	var skel: Skeleton3D = c.view.rig.skeleton
	var feet: Array[int] = []
	for side in [".L", ".R"]:
		var bone := -1
		for f in FEET:
			if bone == -1:
				bone = skel.find_bone(f + side)
		feet.append(bone)
	var ys := [PackedFloat32Array(), PackedFloat32Array()]
	var zs := [PackedFloat32Array(), PackedFloat32Array()]
	var step := seconds / float(samples)
	for i in samples + 1:
		if i > 0:
			c.anim.tree.advance(step)
		for k in 2:
			var p: Vector3 = c.view.to_local(skel.global_transform * skel.get_bone_global_pose(feet[k]).origin)
			ys[k].append(p.y)
			zs[k].append(p.z)
	var tol := maxf(0.02, float(c.def.height_meters) * 0.015)
	var out: Array[float] = []
	for k in 2:
		var ymin: float = ys[k][0]
		for y in ys[k]:
			ymin = minf(ymin, y)
		var vels: Array[float] = []
		for i in samples:
			if ys[k][i] <= ymin + tol and ys[k][i + 1] <= ymin + tol:
				vels.append((zs[k][i + 1] - zs[k][i]) / step)
		vels.sort()
		out.append(absf(vels[vels.size() / 2]) if vels.size() > 0 else 0.0)
	return out

## Both feet must keep pace: the bake averages them, so an asymmetric donor clip shows up here.
func _test_stride_match() -> void:
	for id in STRIDE_SPECIES:
		var c = _spawn(id)
		var top: float = c.def.move_speed_mps
		for v in [top * WALK_FRAC, top]:
			c.anim.set_move_speed(v)
			_advance(c, 0.5)  # gait crossfade is 0.2 s
			var gait: StringName = c.anim.current_clip
			var cadence: float = c.anim.cadence(gait)
			var cycle: float = c.anim.player.get_animation(gait).length / maxf(0.01, cadence)
			var feet := _planted_speeds(c, cycle * 2.0, 480)
			var rl: float = feet[0] / v
			var rr: float = feet[1] / v
			var ok := rl >= 0.75 and rl <= 1.30 and rr >= 0.75 and rr <= 1.30
			_expect(ok, "%s set_move_speed(%.2f) -> %s x%.2f: planted feet L %.2f R %.2f m/s, ratio L %.2f R %.2f (want 0.75-1.30)" % [id, v, gait, cadence, feet[0], feet[1], rl, rr])
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
	var pb: AnimationNodeStateMachinePlayback = rex.anim.tree.get("parameters/playback")
	for clip in [&"sleep", &"feed", &"tail_swipe"]:
		rex.anim.play_clip(clip, true)
		_advance(rex, 0.25)
		_expect(pb.get_current_node() == clip and rex.anim.current_clip == clip, "tyrannosaurus play_clip(%s): state machine on %s" % [clip, pb.get_current_node()])
		rex.anim.play_clip(&"idle")
		_advance(rex, 0.25)
	rex.free()
	var raptor = _spawn(&"velociraptor")
	pb = raptor.anim.tree.get("parameters/playback")
	raptor.anim.play_clip(&"sleep", true)
	_advance(raptor, 0.25)
	_expect(pb.get_current_node() == &"idle" and raptor.anim.current_clip == &"idle" and not raptor.anim.has_state(&"sleep"), "velociraptor play_clip(sleep) has no sleep node and stays on %s" % pb.get_current_node())
	raptor.free()
