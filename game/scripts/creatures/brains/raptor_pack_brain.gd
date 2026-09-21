class_name RaptorPackBrain
extends CreatureBrain
## pack_raptor / pack_flanker / apex_raptor. Leader plus ±60° flank slots.

var _heavy_cd: float = 0.0
var _flank_sign: float = 1.0

func setup(c: Creature) -> void:
	super.setup(c)
	_flank_sign = -1.0 if int(c.get_instance_id()) % 2 == 0 else 1.0
	if c.def.archetype == &"apex_raptor":
		perception += 4.0

func on_aggro(who: Node) -> void:
	super.on_aggro(who)
	_alert_pack(who)

func _think(delta: float) -> void:
	_heavy_cd = maxf(0.0, _heavy_cd - delta)
	if creature.health.fraction() < 0.30 and creature.def.archetype != &"apex_raptor":
		state = &"flee"
		_flee()
		return
	if not _valid_target():
		_scan()
		if not _valid_target():
			state = &"roam"
			_roam(delta)
			return
	var dist := creature.global_position.distance_to(attack_target.global_position)
	if dist > 2.4:
		state = &"chase"
		var slot := _flank_slot()
		creature.move_to(slot)
		if dist >= 4.0 and dist <= 7.0 and _heavy_cd <= 0.0 and _is_off_axis():
			creature.stop_move()
			creature.face_towards(attack_target.global_position, 0.08)
			creature.anim.play_clip(&"attack_heavy")
			_heavy_cd = 4.5
			state = &"attack"
		return
	state = &"attack"
	creature.face_towards(attack_target.global_position, 0.08)
	if creature.anim._busy:
		creature.stop_move()
	elif _attack_cd > 0.0:
		_strafe_target(delta)
	else:
		creature.stop_move()
		creature.anim.play_clip(&"attack_primary")
		_attack_cd = 1.1
	_attack_cd = maxf(0.0, _attack_cd - delta)

func _flank_slot() -> Vector3:
	var tgt := attack_target.global_position
	var to_me := creature.global_position - tgt
	to_me.y = 0.0
	if to_me.length_squared() < 0.01:
		to_me = Vector3.FORWARD
	var back := to_me.normalized()
	var ang := deg_to_rad(60.0 * _flank_sign)
	var dir := back.rotated(Vector3.UP, ang)
	if _is_leader():
		dir = -back
	return tgt + dir * 3.0

func _is_leader() -> bool:
	var best: Creature = creature
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c.pack_id != creature.pack_id or c.health.dead:
			continue
		if c.get_instance_id() < best.get_instance_id():
			best = c
	return best == creature

func _is_off_axis() -> bool:
	if attack_target == null:
		return false
	var to := creature.global_position - attack_target.global_position
	to.y = 0.0
	var fwd := -attack_target.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.01:
		return true
	return absf(fwd.normalized().dot(to.normalized())) < 0.55

func _alert_pack(who: Node) -> void:
	for n in creature.get_tree().get_nodes_in_group("creatures"):
		var c := n as Creature
		if c == null or c == creature or c.pack_id != creature.pack_id:
			continue
		if c.brain:
			c.brain.attack_target = who as Node3D
			c.brain.state = &"chase"
