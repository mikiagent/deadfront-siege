extends SceneTree
## Creature turning (owner: "they glitch around"). Run: godot --headless --path game --script res://tests/t_turnrate.gd
## Prints "[t_turnrate] PASS" or FAIL lines and quits 0/1.
##  1. face_towards never turns more than turn_rate * physics step in one frame, even when several
##     callers face in the same frame, and still reaches the goal.
##  2. Locomotion along a jittery path (goal swinging left/right every frame) does not flip yaw back
##     and forth: the creature faces a low-passed velocity.
##  3. The T. rex bite aims at a target behind it and still lands, with no snap turn.

const CREATURE_SCENE := "res://scenes/creatures/creature.tscn"
const SPECIES: Array[StringName] = [&"compsognathus", &"velociraptor", &"utahraptor", &"triceratops", &"tyrannosaurus"]

var failures: Array[String] = []
var data: Node
var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	data = root.get_node("Data")
	root.get_node("Game").debug_overlay = false
	_run()
	return false

func _run() -> void:
	for id in SPECIES:
		await _test_cap(id)
	await _test_jitter(&"velociraptor")
	await _test_jitter(&"tyrannosaurus")
	await _test_tyrant_bite_behind()
	if failures.is_empty():
		print("[t_turnrate] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_turnrate] FAIL " + f)
		quit(1)

func _expect(ok: bool, what: String) -> void:
	print("[t_turnrate] %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _spawn(id: StringName, at: Vector3, physics: bool):
	var c = load(CREATURE_SCENE).instantiate()
	root.add_child(c)
	c.global_position = at
	c.spawn(data.creature(id))
	c.set_physics_process(physics)
	if c.brain:
		c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	return c

func _test_cap(id: StringName) -> void:
	var c = _spawn(id, Vector3(0, 0, 0), false)
	var rate: float = c.turn_rate()
	_expect(rate > 0.0 and absf(rate - float(data.creature(id).turn_rate)) < 0.0001, "%s turn_rate %.2f rad/s comes from its def" % [id, rate])
	c.rotation.y = 0.0
	# Goal straight behind: the old lerp_angle(.., delta * 10) moved ~0.5 rad in the first frame
	# and the tyrant's face_towards(p, 1.0) snapped the full PI.
	var goal: Vector3 = c.global_position + Vector3(0.05, 0, 10.0)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var worst := 0.0
	var frames := 0
	var reached := false
	while frames < 600:
		await physics_frame
		var before: float = c.rotation.y
		c.face_towards(goal, dt)
		c.face_towards(goal, 1.0)  # a second caller the same frame (brain + locomotion) shares the budget
		worst = maxf(worst, absf(angle_difference(before, c.rotation.y)))
		frames += 1
		var to: Vector3 = (goal - c.global_position)
		if absf(angle_difference(c.rotation.y, atan2(-to.x, -to.z))) < 0.01:
			reached = true
			break
	_expect(worst <= rate * dt + 1e-4, "%s max yaw step %.4f rad/frame <= turn_rate*dt %.4f" % [id, worst, rate * dt])
	var want_frames := int(ceil(PI / (rate * dt)))
	_expect(reached and frames <= want_frames + 3, "%s turns 180 deg in %d frames (want about %d)" % [id, frames, want_frames])
	c.free()

## The goal swings 1.5 m left/right of the heading every frame (the nav jitter a crowd produces).
func _test_jitter(id: StringName) -> void:
	var c = _spawn(id, Vector3(200, 0, 0), true)
	c.rotation.y = 0.0  # facing -Z
	var start: Vector3 = c.global_position
	var flips := 0
	var last_sign := 0
	var moved := 0.0
	for i in 120:
		var side := 1.5 if i % 2 == 0 else -1.5
		c._path_active = true
		c._path_goal = c.global_position + Vector3(side, 0, -5.0)
		c.agent.target_position = c._path_goal
		var before: float = c.rotation.y
		await physics_frame
		var d := angle_difference(before, c.rotation.y)
		if absf(d) > 0.002:
			var s := 1 if d > 0.0 else -1
			if last_sign != 0 and s != last_sign:
				flips += 1
			last_sign = s
	moved = Vector2(c.global_position.x - start.x, c.global_position.z - start.z).length()
	c._path_active = false
	_expect(moved > 2.0, "%s moved %.1f m along the jittery path (the check needs it to walk)" % [id, moved])
	_expect(flips <= 2, "%s yaw direction flips %d times in 120 jittery frames (want <= 2)" % [id, flips])
	_expect(absf(angle_difference(c.rotation.y, 0.0)) < 0.25, "%s still heads along the path: yaw %.3f rad" % [id, c.rotation.y])
	c.free()

## Target behind the rex in reach: the windup aims at it, the body turns at the capped rate, and the
## impact lands.
func _test_tyrant_bite_behind() -> void:
	var rex = _spawn(&"tyrannosaurus", Vector3(-200, 0, 0), false)
	var prey = _spawn(&"zebraceratops", Vector3(-200, 0, 0), false)
	rex.rotation.y = 0.0
	var brain = rex.brain
	await physics_frame
	prey.global_position = rex.global_position + Vector3(0.3, 0, brain.contact_reach() * 0.5)  # +Z is behind
	brain.attack_target = prey
	brain.attack_number = 0
	var hp0: float = prey.health.hp
	var before: float = rex.rotation.y
	brain._do_attack()
	var step := absf(angle_difference(before, rex.rotation.y))
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	_expect(brain.phase == &"windup", "tyrannosaurus starts a windup on a target behind it (phase %s)" % brain.phase)
	_expect(step <= rex.turn_rate() * dt + 1e-4, "tyrannosaurus windup start turns %.4f rad, not a snap (cap %.4f)" % [step, rex.turn_rate() * dt])
	var to: Vector3 = prey.global_position - rex.global_position
	to.y = 0.0
	_expect(to.normalized().dot(brain.locked_forward) > 0.99, "windup aims at the target (dot %.3f)" % to.normalized().dot(brain.locked_forward))
	brain._impact()
	_expect(prey.health.hp < hp0, "the bite behind lands: prey hp %.0f -> %.0f" % [hp0, prey.health.hp])
	rex.free()
	prey.free()
