extends SceneTree
## RAPTORFEEL (owner 2026-10-30: "they gave this raptor like a head tilt and curious/inquisitive movement (similar
## to compy but more aggressive)"). The velociraptor has investigate.glb (4 s crouched head-cocking loop) and
## sniff.glb (1.5 s inspect one-shot), authored by tools/gait/make_investigate_idle.py.
## Checks: both clips load (investigate loops, sniff does not); a raptor that spots the survivor sniffs, then stands
## in the investigate idle while aware but not attacking, then commits; a hit during that hold makes it charge at
## once; through both clips the hind feet stay on the idle's ground and do not slide.
## Usage: godot --headless --path game --script res://tests/t_raptorfeel.gd  -> "[t_raptorfeel] PASS"

const FOOT_TOL := 0.03  # metres at game scale
const FEET: Array[String] = ["BackFoot.L", "BackFoot.R"]

var failures: Array[String] = []
var _started := false
var data: Node
var game: Node

func _process(_delta: float) -> bool:
	if _started or get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	game = get_root().get_node("Game")
	game.debug_overlay = false
	game.time_of_day = 0.40  # daytime: no night sleep
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_raptorfeel] %s %s" % ["ok  " if ok else "FAIL", msg])

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _run() -> void:
	_test_clips_and_feet()
	await _test_aware_state()
	await _test_hit_breaks_hold()
	if failures.is_empty():
		print("[t_raptorfeel] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_raptorfeel] FAIL " + f)
		quit(1)

func _raptor(at: Vector3, live: bool) -> Node:
	var c: Node = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	get_root().add_child(c)
	c.global_position = at
	c.spawn(data.creature(&"velociraptor"))
	if not live:
		c.set_physics_process(false)
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
		c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

## Hind feet in world metres relative to the creature (it never moves or turns here): [left, right].
func _feet(c) -> Array[Vector3]:
	var skel: Skeleton3D = c.view.rig.skeleton
	var out: Array[Vector3] = []
	for b in FEET:
		out.append(skel.global_transform * skel.get_bone_global_pose(skel.find_bone(b)).origin - c.global_position)
	return out

func _test_clips_and_feet() -> void:
	var c = _raptor(Vector3(40, 0, 40), false)
	var ap: AnimationPlayer = c.anim.player
	for clip in [&"investigate", &"sniff"]:
		_expect(ap.has_animation(clip) and c.anim.has_state(clip), "velociraptor has the %s clip and tree state" % clip)
	if not ap.has_animation(&"investigate") or not ap.has_animation(&"sniff"):
		c.free()
		return
	_expect(ap.get_animation(&"investigate").loop_mode == Animation.LOOP_LINEAR and ap.get_animation(&"sniff").loop_mode == Animation.LOOP_NONE,
		"investigate loops, sniff is a one-shot (loop modes %d / %d)" % [ap.get_animation(&"investigate").loop_mode, ap.get_animation(&"sniff").loop_mode])
	c.anim.play_idle()
	c.anim.tree.advance(0.0)
	var ground := _feet(c)
	for clip in [&"investigate", &"sniff"]:
		if clip == &"investigate":
			c.anim.play_idle(true)
		else:
			c.anim.play_clip(clip)
		c.anim.tree.advance(0.5)  # past the cross-fade
		var length: float = ap.get_animation(clip).length
		var worst_y := 0.0
		var worst_xz := 0.0
		var skel: Skeleton3D = c.view.rig.skeleton
		var head0: Vector3 = skel.get_bone_global_pose(skel.find_bone("Head")).basis.y
		var head_turn := 0.0  # proves the pose is live while the feet read 0
		var n := 24
		for k in n:
			c.anim.tree.advance(length / n * (0.9 if clip == &"sniff" else 1.0))
			var f := _feet(c)
			head_turn = maxf(head_turn, rad_to_deg(head0.angle_to(skel.get_bone_global_pose(skel.find_bone("Head")).basis.y)))
			for i in 2:
				worst_y = maxf(worst_y, absf(f[i].y - ground[i].y))
				worst_xz = maxf(worst_xz, Vector2(f[i].x - ground[i].x, f[i].z - ground[i].z).length())
		_expect(worst_y <= FOOT_TOL and worst_xz <= FOOT_TOL, "%s: hind feet stay planted on the idle's ground (worst %.1f cm up/down, %.1f cm slide)"
			% [clip, worst_y * 100.0, worst_xz * 100.0])
		_expect(head_turn > 15.0, "%s: the head really moves (%.0f deg)" % [clip, head_turn])
		c.anim.play_idle()
		c.anim.tree.advance(0.5)
	c.free()

## A daytime survivor inside perception, out of reach: spot -> sniff -> investigate (aware, not attacking) -> commit.
func _test_aware_state() -> void:
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(p)
	p.global_position = Vector3(0, 0, 6.0)
	var c = _raptor(Vector3.ZERO, true)
	await _frames(12)
	_expect(c.brain.state == &"alert" and c.brain.attack_target == p, "raptor spots the survivor and is aware (state %s)" % c.brain.state)
	_expect(c.anim.current_clip == &"sniff", "it sniffs first (clip %s)" % c.anim.current_clip)
	await _frames(int(1.9 * Engine.physics_ticks_per_second))
	_expect(c.brain.state == &"alert" and c.brain.aware_idle(), "still sizing it up, not attacking (state %s)" % c.brain.state)
	_expect(c.anim.current_clip == &"investigate", "aware but not attacking plays the investigate idle (clip %s)" % c.anim.current_clip)
	var flat := Vector2(c.velocity.x, c.velocity.z).length()
	_expect(flat < 0.05, "it holds still while investigating (%.2f m/s)" % flat)
	await _frames(int(1.6 * Engine.physics_ticks_per_second))
	# COELOMOVES: the velociraptor runs the deinonychus TacticalBrain, so it may commit with any of its moves.
	_expect(c.brain.state != &"alert" and c.brain.state in [&"approach", &"attack", &"circle", &"feint", &"lunge", &"pounce", &"combo", &"charge", &"hold", &"hop", &"dodge"], "after the hold it commits (state %s)" % c.brain.state)
	_expect(c.anim.current_clip != &"investigate", "and leaves the investigate idle (clip %s)" % c.anim.current_clip)
	c.free()
	p.free()

func _test_hit_breaks_hold() -> void:
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(p)
	p.global_position = Vector3(0, 0, 6.0)
	var c = _raptor(Vector3.ZERO, true)
	await _frames(12)
	var was: StringName = c.brain.state
	c.brain.on_aggro(p)
	await _frames(12)
	_expect(was == &"alert" and c.brain.state != &"alert", "a hit while investigating makes it charge at once (%s -> %s)" % [was, c.brain.state])
	c.free()
	p.free()
