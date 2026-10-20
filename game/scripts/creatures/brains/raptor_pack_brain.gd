class_name RaptorPackBrain
extends CreatureBrain
## Pack predators. The strongest living member is alpha; followers path with it and fan out
## only once the alpha commits to prey. Timers, the pack leash, sleep and the walk home run
## first in CreatureBrain._pre_think, so this think never has to repeat them.

func setup(c: Creature) -> void:
	super.setup(c)
	if c.def.archetype == &"apex_raptor":
		perception += 4.0

func on_aggro(who: Node) -> void:
	super.on_aggro(who)
	if who is Node3D:
		_propagate_alert(who as Node3D)

func _think(delta: float) -> void:
	if creature.health.fraction() < 0.30 and creature.def.archetype != &"apex_raptor" and _valid_target():
		_set_state(&"flee")
		flight.flee()
		return

	if not _valid_target():
		if _combat_memory_left > 0.0 and flight.can_reacquire():
			attack_target = _nearest_live_prey(aggro_radius())
		if not _valid_target():
			_set_state(&"roam")
			_roam(delta)
			_scan()
			return

	_combat_memory_left = 4.0
	# Followers inherit the alpha's prey. This is also the post-kill path: the alpha chooses the
	# next live pet/survivor and every packmate stays in the hunt.
	var leader := _pack_leader()
	if leader and leader != creature and leader.brain and leader.brain._valid_target():
		attack_target = leader.brain.attack_target

	var dist := creature.global_position.distance_to(attack_target.global_position)
	var excess := _size_excess(attack_target)
	var reach := maxf(1.2, float(profile.get("attack_range", 2.0)) + 0.2) + excess
	# Leave a bite only a little past reach, so a target stepping back does not flip the state.
	if dist > reach + (0.4 if state == &"attack" else 0.0):
		# The gap-closing pounce is the kit's lunge (ai.json), which moves; this used to pounce in place.
		_set_state(&"approach")
		creature.move_to(_flank_slot())
		creature.face_towards(attack_target.global_position, delta)
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
		_play_attack(&"attack_primary")
		_attack_cd = 1.1
		if _is_pack_member():
			_pack_cooldown_until[creature.pack_id] = _now_s() + 0.25
