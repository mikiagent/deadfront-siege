extends SceneTree
## REXFEEL (owner 2026-10-30, "better and more exaggerated animations"): the T. rex's re-authored clips load, the
## tyrant's attack and roar code plays them, and the feet stay on the ground through every one.
## Run: Godot --headless --path game --script res://tests/t_rexclips.gd   Prints "[t_rexclips] PASS" or FAIL lines.

const CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"walk_back", &"strafe_left", &"strafe_right",
	&"alert", &"attack_primary", &"attack_heavy", &"tail_swipe"]
## In-place one-shots and idle keep one foot planted on its print in every frame; gaits only must not sink.
const PLANTED: Array[StringName] = [&"idle", &"alert", &"attack_primary", &"attack_heavy", &"tail_swipe"]
const TOL := 0.05  # m on an 8 m animal (the Blender gate, tools/gait/check_rex_clips.py, holds 3 cm on the skin)

var failures: Array[String] = []
var _started := false
var data: Node

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	_test_clips_and_feet()
	_test_brain_plays_clips()
	if failures.is_empty():
		print("[t_rexclips] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_rexclips] FAIL " + f)
		quit(1)
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_rexclips] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _spawn():
	var c = load("res://scenes/creatures/creature.tscn").instantiate()
	root.add_child(c)
	c.spawn(data.creature(&"tyrannosaurus"))
	c.set_physics_process(false)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.anim.tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return c

func _test_clips_and_feet() -> void:
	var c = _spawn()
	var skel: Skeleton3D = c.view.rig.skeleton
	var toes: Array[int] = [skel.find_bone("Toe.L"), skel.find_bone("Toe.R")]
	var y := func (b: int) -> float: return c.view.to_local(skel.global_transform * skel.get_bone_global_pose(b).origin).y
	c.anim.tree.active = false
	var player: AnimationPlayer = c.anim.player
	skel.reset_bone_poses()
	var rest: Array[float] = [y.call(toes[0]), y.call(toes[1])]
	for clip in CLIPS:
		var ok: bool = player.has_animation(clip) and c.anim.has_state(clip)
		_expect(ok, "%s loads (AnimationPlayer + tree state)" % clip)
		if not ok:
			continue
		var anim := player.get_animation(clip)
		player.play(clip)
		var worst_sink := 0.0
		var lifted_frames := 0
		var n := int(ceil(anim.length * 30.0))
		for i in n + 1:
			player.seek(anim.length * i / n, true)
			var d0: float = y.call(toes[0]) - rest[0]
			var d1: float = y.call(toes[1]) - rest[1]
			worst_sink = minf(worst_sink, minf(d0, d1))
			if minf(absf(d0), absf(d1)) > TOL:
				lifted_frames += 1
		player.stop()
		_expect(worst_sink > -TOL, "%s: balls of the feet never below the ground (worst %.3f m)" % [clip, worst_sink])
		if clip in PLANTED:
			_expect(lifted_frames == 0, "%s: one foot on its print every frame (%d frames with both off)" % [clip, lifted_frames])
	c.free()

## TyrantBrain picks the clips: a target in front draws the bite, every third attack the stomp, a target behind
## her the tail whip; spotting prey plays the roar (alert). The swing keeps playing through the follow-through.
func _test_brain_plays_clips() -> void:
	var c = _spawn()
	var brain = c.brain
	var pb: AnimationNodeStateMachinePlayback = c.anim.tree.get("parameters/playback")
	var target := Node3D.new()
	root.add_child(target)
	var reach: float = brain.contact_reach() * 0.5
	for case in [[0, 1.0, &"attack_primary"], [2, 1.0, &"attack_heavy"], [0, -1.0, &"tail_swipe"]]:
		brain._end_phase()
		c.anim.play_idle()
		c.anim.tree.advance(0.5)
		target.global_position = c.global_position - c.global_basis.z * reach * float(case[1])
		brain.attack_target = target
		brain.attack_number = int(case[0])
		brain._do_attack()
		c.anim.tree.advance(0.1)
		_expect(brain.windup_clip == case[2] and brain.phase == &"windup" and pb.get_current_node() == case[2],
			"target %s, attack %d: brain winds up %s, tree plays %s" % ["ahead" if case[1] > 0 else "behind", int(case[0]) + 1, brain.windup_clip, pb.get_current_node()])
	# the follow-through: recovery no longer cuts to idle at the hit
	brain.phase = &"windup"
	brain.phase_left = 0.0
	brain.locked_target = null  # _impact is a no-op without a live target; only the phase change is under test
	brain._think(1.0 / 60.0)
	c.anim.tree.advance(0.05)
	_expect(brain.phase == &"recovery" and pb.get_current_node() == &"tail_swipe", "after the hit the whip plays on into recovery (tree at %s)" % pb.get_current_node())
	brain._end_phase()
	c.anim.tree.advance(0.3)
	brain._spot(target)
	c.anim.tree.advance(0.1)
	_expect(pb.get_current_node() == &"roar", "spotting prey roars (THERO-ROAR's rearing roar): tree plays %s" % pb.get_current_node())
	target.free()
	c.free()
