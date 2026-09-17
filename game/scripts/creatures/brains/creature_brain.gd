class_name CreatureBrain
extends Node
## Base roam / alert / chase / attack / flee / downed / dead.

var creature: Creature
var state: StringName = &"roam"
var attack_target: Node3D
var perception: float = 12.0
var _roam_cd: float = 0.0
var _attack_cd: float = 0.0

func setup(c: Creature) -> void:
	creature = c
	# ASSUMPTION: perception radius = 8 + tier * 0.15 m.
	perception = 8.0 + float(c.def.tier) * 0.15

func _physics_process(delta: float) -> void:
	if creature == null or creature.health.dead:
		state = &"dead"
		return
	if creature.statuses.has(&"knockdown") or not creature.statuses.can_act():
		state = &"downed"
		creature.stop_move()
		return
	_think(delta)
	creature.brain_state = state

func on_aggro(who: Node) -> void:
	if who is Node3D:
		attack_target = who as Node3D
		state = &"chase"

func _think(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	match state:
		&"roam":
			_roam(delta)
			_scan()
		&"alert":
			_scan()
			if attack_target:
				state = &"chase"
		&"chase":
			if not _valid_target():
				state = &"roam"
				return
			creature.move_to(attack_target.global_position)
			if creature.global_position.distance_to(attack_target.global_position) < 1.6:
				state = &"attack"
		&"attack":
			_do_attack()
		&"flee":
			_flee()

func _roam(delta: float) -> void:
	_roam_cd -= delta
	if _roam_cd <= 0.0 or creature.agent.is_navigation_finished():
		var p := creature.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		creature.move_to(p)
		_roam_cd = randf_range(2.5, 5.0)

func _scan() -> void:
	var player := creature.get_tree().get_first_node_in_group("player") as Node3D
	if player and creature.global_position.distance_to(player.global_position) <= perception:
		attack_target = player
		state = &"alert"
		creature.anim.play_clip(&"alert")

func _valid_target() -> bool:
	return attack_target != null and is_instance_valid(attack_target)

func _do_attack() -> void:
	if not _valid_target():
		state = &"roam"
		return
	var dist := creature.global_position.distance_to(attack_target.global_position)
	if dist > 2.2:
		state = &"chase"
		return
	creature.stop_move()
	creature.face_towards(attack_target.global_position, 0.05)
	if _attack_cd <= 0.0:
		creature.anim.play_clip(&"attack_primary")
		_attack_cd = 1.2

func _flee() -> void:
	var player := creature.get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var away := creature.global_position + (creature.global_position - player.global_position).normalized() * 8.0
		creature.move_to(away)
