class_name Knockback
extends Node
## Shoves a body along the ground for a moment (charge horns, tail sweeps). Lives next to the
## body, not under it, so it still runs when the body's own processing is off; collides with
## walls on the way. # ASSUMPTION: a shove is distance over time, not a physics impulse, until
## PlayerSim (W2-PLAYER) has a real knockback input.

var body: CharacterBody3D
var _step := Vector3.ZERO
var _left := 0.0

static func push(target: Node, dir: Vector3, metres: float, seconds: float = 0.25) -> Knockback:
	var b := target as CharacterBody3D
	if b == null or not b.is_inside_tree() or metres <= 0.0:
		return null
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return null
	var k := Knockback.new()
	k.body = b
	k._left = maxf(0.05, seconds)
	k._step = flat.normalized() * (metres / k._left)
	b.get_parent().add_child(k)
	return k

func _physics_process(delta: float) -> void:
	if not is_instance_valid(body) or _left <= 0.0:
		queue_free()
		return
	var dt := minf(delta, _left)
	_left -= dt
	body.move_and_collide(_step * dt)
