class_name TyrantBrain
extends CreatureBrain
## T-rex only: fixed-facing timed attacks and counter-earned punish openings.
## Bites, with every third attack a raid phase in turn: stomp, roar, tail (PRD verb).
# ASSUMPTION: the PRD names the three phases but not their order, cadence, timing or reach.
const PHASES: Array[StringName] = [&"attack_heavy", &"alert", &"tail_swipe"]
const LABELS := {&"attack_primary": "BITE", &"attack_heavy": "STOMP", &"alert": "ROAR", &"tail_swipe": "TAIL"}
const WINDUP := {&"attack_primary": 0.7, &"attack_heavy": 1.2, &"alert": 1.0, &"tail_swipe": 1.0}
const RECOVERY := {&"attack_primary": 1.0, &"attack_heavy": 2.0, &"alert": 1.0, &"tail_swipe": 1.5}
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
			phase_left = RECOVERY[windup_clip]
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
	attack_number += 1
	windup_clip = PHASES[(int(attack_number / 3.0) - 1) % PHASES.size()] if attack_number % 3 == 0 else &"attack_primary"
	# The tail swings round: turn the hips to the target so it sweeps behind.
	var face := creature.global_position - offset if windup_clip == &"tail_swipe" else attack_target.global_position
	creature.face_towards(face,1.0)
	locked_forward = -creature.global_basis.z
	locked_target = attack_target
	phase = &"windup"
	phase_left = WINDUP[windup_clip]
	creature.anim.play_timed_attack(windup_clip,phase_left)
	telegraph = Telegraph.show_tyrant(creature,_phase_reach(windup_clip),phase_left,windup_clip)

func _phase_reach(clip: StringName) -> float:
	# ASSUMPTION: the roar deafens out to 2.5x bite reach (escapable by backing off in the
	# windup); the tail reaches 2x bite reach, about the measured tail tip at full sweep.
	if clip == &"alert": return contact_reach()*2.5
	if clip == &"tail_swipe": return contact_reach()*2.0
	return contact_reach()+0.3

func _roar() -> void:
	if &"deafened" not in creature.def.status_applied: return
	var player := creature.get_tree().get_first_node_in_group("player") as Player
	if player == null or player.dead: return
	var offset := player.global_position-creature.global_position
	offset.y = 0
	# ASSUMPTION: a roar is sound, so rolling does not avoid it; only distance does.
	if offset.length() > _phase_reach(&"alert"): return
	CreatureAttack._apply_token(&"deafened",&"alert",player,creature)
	print("[tyrant] roar deafened player")

func _impact() -> void:
	if windup_clip == &"alert":
		_roar()
		return
	if not is_instance_valid(locked_target): return
	if locked_target is Player and ((locked_target as Player).dead or (locked_target as Player).rolling): return
	if locked_target is FieldCatapult and (locked_target as FieldCatapult).hp <= 0: return
	var offset := locked_target.global_position-creature.global_position
	offset.y = 0
	if offset.length() > _phase_reach(windup_clip): return
	var dot := offset.normalized().dot(locked_forward)
	if windup_clip == &"tail_swipe":
		# Behind or beside the hips; standing at the head is the dodge.
		if dot > 0.3: return
		# ASSUMPTION: tail hits like a bite and applies Fracture (PRD status table: "T. rex tail").
		if &"fracture" in creature.def.status_applied: CreatureAttack._apply_token(&"fracture",windup_clip,locked_target,creature)
		CreatureAttack._deal_damage(creature,locked_target,windup_clip)
		if locked_target is Player: (locked_target as Player).receive_creature_hit(creature,windup_clip)
		return
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
	if phase == &"windup": return "%s %.1fs" % [LABELS[windup_clip],phase_left]
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
