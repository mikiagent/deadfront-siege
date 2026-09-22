class_name RaptorPackBrain
extends CreatureBrain
## Pack predators. The strongest living member is alpha; followers path with it and fan out
## only once the alpha commits to prey.

var _heavy_cd: float = 0.0

func setup(c: Creature) -> void:
	super.setup(c)
	if c.def.archetype == &"apex_raptor":
		perception += 4.0

func on_aggro(who: Node) -> void:
	super.on_aggro(who)
	if who is Node3D:
		_propagate_alert(who as Node3D)

func _think(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_heavy_cd = maxf(0.0, _heavy_cd - delta)
	_combat_memory_left = maxf(0.0, _combat_memory_left - delta)
	# Raptor override bypasses CreatureBrain._think, so enforce the same hard radius boundary
	# before refreshing combat memory or inheriting the alpha's target.
	if _valid_target() and creature.global_position.distance_to(attack_target.global_position) > aggro_radius():
		attack_target = null
		_combat_memory_left = 0.0
		_set_state(&"disengage")
		creature.move_to(creature.spawn_home)
		print("[ai] %s disengage (left aggro radius)" % creature.def.id)
		return

	if creature.health.fraction() < 0.30 and creature.def.archetype != &"apex_raptor":
		_set_state(&"flee")
		_flee(delta)
		return

	if not _valid_target():
		if _combat_memory_left > 0.0:
			attack_target = _nearest_live_prey(aggro_radius())
		if not _valid_target():
			_scan()
		if not _valid_target():
			_set_state(&"roam")
			_roam(delta)
			return

	_combat_memory_left = 4.0
	# Followers inherit the alpha's prey. This is also the post-kill path: the alpha chooses the
	# next live pet/survivor and every packmate stays in the hunt.
	var leader := _pack_leader()
	if leader and leader != creature and leader.brain and leader.brain._valid_target():
		attack_target = leader.brain.attack_target

	var dist := creature.global_position.distance_to(attack_target.global_position)
	var reach := maxf(1.2, float(profile.get("attack_range", 2.0)) + 0.2)
	if dist > reach:
		_set_state(&"approach")
		creature.move_to(_flank_slot())
		creature.face_towards(attack_target.global_position, delta)
		if dist >= 4.0 and dist <= 7.0 and _heavy_cd <= 0.0 and _is_off_axis():
			creature.stop_move()
			creature.anim.play_clip(&"attack_heavy")
			_heavy_cd = 4.5
			_attack_cd = 1.8
			_set_state(&"attack")
		return
	_set_state(&"attack")
	creature.face_towards(attack_target.global_position, delta)
	if creature.anim._busy:
		creature.stop_move()
	elif _attack_cd > 0.0:
		# Main removed inter-bite strafing (fight-or-move: no walking during swings); hold ground.
		creature.stop_move()
	elif _pack_ready():
		creature.stop_move()
		creature.anim.play_clip(&"attack_primary")
		_attack_cd = 1.1
		_pack_cooldown_until[creature.pack_id] = _now_s() + 0.25

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
