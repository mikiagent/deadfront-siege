class_name TyrantBrain
extends CreatureBrain
## T-rex only: fixed-facing timed attacks and counter-earned punish openings.
var phase: StringName = &"idle"
var phase_left := 0.0
var windup_clip: StringName = &"attack_primary"
var locked_target: Node3D
var locked_forward := Vector3.FORWARD
var counter_hits := 0
var stagger_immunity := 0.0
var attack_number := 0
var telegraph: Telegraph

func _think(delta: float) -> void:
	stagger_immunity = maxf(0,stagger_immunity-delta)
	if phase != &"idle":
		creature.stop_move()
		phase_left = maxf(0,phase_left-delta)
		if not _valid_target():
			_end_phase()
			_disengage()
			return
		if phase_left > 0: return
		if phase == &"windup":
			_impact()
			phase = &"recovery"
			phase_left = 2.0 if windup_clip == &"attack_heavy" else 1.0
			creature.anim.end_timed_attack()
			_clear_telegraph()
		else:
			if phase == &"stagger": stagger_immunity = 20.0
			_end_phase()
		return
	super._think(delta)

func _do_attack() -> void:
	if not _valid_target() or creature.anim._busy: return
	var offset := attack_target.global_position-creature.global_position
	if Vector2(offset.x,offset.z).length() > contact_reach()+0.1:
		_set_state(&"approach")
		return
	creature.stop_move()
	creature.face_towards(attack_target.global_position,1.0)
	locked_forward = -creature.global_basis.z
	locked_target = attack_target
	attack_number += 1
	windup_clip = &"attack_heavy" if attack_number % 3 == 0 else &"attack_primary"
	phase = &"windup"
	phase_left = 1.2 if windup_clip == &"attack_heavy" else 0.7
	creature.anim.play_timed_attack(windup_clip,phase_left)
	telegraph = Telegraph.show_tyrant(creature,contact_reach()+0.3,phase_left,windup_clip)

func _impact() -> void:
	if not is_instance_valid(locked_target): return
	if locked_target is Player and ((locked_target as Player).dead or (locked_target as Player).rolling): return
	if locked_target is FieldCatapult and (locked_target as FieldCatapult).hp <= 0: return
	var offset := locked_target.global_position-creature.global_position
	offset.y = 0
	if offset.length() > contact_reach()+0.3: return
	var dot := offset.normalized().dot(locked_forward)
	if dot < (-0.4 if windup_clip == &"attack_heavy" else 0.15): return
	CreatureAttack.apply_for(creature,windup_clip,locked_target)
	if locked_target is Player: (locked_target as Player).receive_creature_hit(creature,windup_clip)

func blunt_counter() -> void:
	# Windup is damageable but not a stagger shortcut. Only recovery is punishable.
	if phase != &"recovery" or stagger_immunity > 0 or creature.health.dead: return
	counter_hits += 1
	var need := 3 if creature.statuses.has(&"poisoned_target") else 6
	if counter_hits < need: return
	counter_hits = 0
	phase = &"stagger"
	phase_left = 3.0
	creature.stop_move()
	creature.anim.end_timed_attack()
	creature.status_float.emit(&"stagger")

func opening_label() -> String:
	if phase == &"windup": return "%s %.1fs" % ["STOMP" if windup_clip == &"attack_heavy" else "BITE",phase_left]
	if phase == &"stagger": return "STAGGER %.1fs" % phase_left
	if phase == &"recovery": return "PUNISH %.1fs  BLUNT %d/%d%s" % [phase_left,counter_hits,3 if creature.statuses.has(&"poisoned_target") else 6,"  IMMUNE" if stagger_immunity > 0 else ""]
	return "BLUNT %d/%d%s" % [counter_hits,3 if creature.statuses.has(&"poisoned_target") else 6,"  IMMUNE %.0fs" % stagger_immunity if stagger_immunity > 0 else ""]

func _clear_telegraph() -> void:
	if is_instance_valid(telegraph): telegraph.queue_free()
	telegraph = null

func _end_phase() -> void:
	phase = &"idle"
	phase_left = 0
	if not _valid_target(): counter_hits = 0
	creature.anim.end_timed_attack()
	_clear_telegraph()

func on_player_killed(at: Vector3) -> void:
	_end_phase()
	counter_hits = 0
	super.on_player_killed(at)

func _exit_tree() -> void:
	_clear_telegraph()
