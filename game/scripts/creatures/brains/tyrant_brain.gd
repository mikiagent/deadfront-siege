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
## ASSUMPTION: the "tail" phase of the tyrant's verb (stomp, roar, tail; the roar is the alert clip on spotting):
## a target this far behind her facing (dot with forward below this) draws the tail whip instead of a turn
## into a bite, so "get behind" during recovery is a read, not a free hit.
const TAIL_DOT := -0.35
## SP-TYRANNOSAURUS signature moves (owner: "be creative with what moves they do when they fight").
## Bite and shake: every third bite on something she can lift in her jaws (a survivor, or a creature no taller
## than GRAB_HEIGHT) clamps on, thrashes it and flings it: more damage, and the catch is pinned while it is shaken.
## ASSUMPTION: 1.5x the bite's damage, rotation bite, bite-and-shake, stomp.
const GRAB_HEIGHT := 3.0
const SHAKE_MULT := 1.5
## Battle roar: mid-fight she stops and bellows (the alert clip). Small things around her stagger: survivors and
## creatures no taller than ROAR_SMALL inside ROAR_RADIUS go groggy and flinch. ASSUMPTION: 18 m, 3 m, every 16 s
## at most, first one 6 s into the fight.
const ROAR_RADIUS := 18.0
const ROAR_SMALL := 3.0
const ROAR_COOLDOWN := 16.0
var roar_ready_at := -1.0

## Windup, impact and recovery are timed moves: resolve them every physics frame, not at 10 Hz.
func _full_rate() -> bool:
	return phase != &"idle"

## The shared leash can drop the target mid-swing; end the timed move with it.
func _pre_think(dt: float) -> bool:
	var handled := super._pre_think(dt)
	if phase != &"idle" and not _valid_target():
		_end_phase()
	return handled

func _think(delta: float) -> void:
	stagger_immunity = maxf(0,stagger_immunity-delta)
	if phase != &"idle":
		creature.stop_move()
		if phase == &"windup":
			creature.face_towards(creature.global_position + locked_forward, delta)
		phase_left = maxf(0,phase_left-delta)
		if not _valid_target():
			_end_phase()
			_disengage()
			return
		if phase_left > 0: return
		if phase == &"windup":
			_impact()
			phase = &"recovery"
			phase_left = {&"attack_heavy": 2.0, &"bite_shake": 1.75, &"alert": 1.4}.get(windup_clip, 1.0)
			# The clip keeps playing through its follow-through (snap, slam, whip); _end_phase returns to idle.
			_clear_telegraph()
		else:
			if phase == &"stagger": stagger_immunity = 20.0
			_end_phase()
		return
	super._think(delta)

func _do_attack() -> void:
	if not _valid_target() or creature.anim._busy: return
	var offset := attack_target.global_position-creature.global_position
	if Vector2(offset.x,offset.z).length() > reach_to(attack_target)+0.1:
		_set_state(&"approach")
		return
	creature.stop_move()
	# Fixed-facing: the strike is aimed where the target stood at windup start; the body turns into
	# that aim at the species turn rate during the windup instead of snapping to it.
	offset.y = 0.0
	var facing := -creature.global_basis.z
	facing.y = 0.0
	var behind := offset.length_squared() > 0.0001 and offset.normalized().dot(facing.normalized()) < TAIL_DOT
	locked_target = attack_target
	var now := Time.get_ticks_msec() * 0.001
	if roar_ready_at < 0.0:
		roar_ready_at = now + 6.0
	elif now >= roar_ready_at and creature.anim.has_state(&"alert"):
		roar_ready_at = now + ROAR_COOLDOWN
		locked_forward = (offset.normalized() if offset.length_squared() > 0.0001 else -creature.global_basis.z)
		windup_clip = &"alert"
		phase = &"windup"
		phase_left = 1.0
		creature.anim.play_timed_attack(windup_clip, phase_left)
		telegraph = Telegraph.show_tyrant(creature, ROAR_RADIUS, phase_left, windup_clip)
		return
	if behind and creature.anim.has_state(&"tail_swipe"):
		locked_forward = facing.normalized()  # the whip swings from where she stands; no turn
		windup_clip = &"tail_swipe"
		phase = &"windup"
		phase_left = 0.9
		creature.anim.play_timed_attack(windup_clip, phase_left)
		telegraph = Telegraph.show_tyrant(creature, contact_reach() + 0.3, phase_left, windup_clip)
		return
	locked_forward = offset.normalized() if offset.length_squared() > 0.0001 else -creature.global_basis.z
	creature.face_towards(creature.global_position + locked_forward, get_physics_process_delta_time())
	attack_number += 1
	windup_clip = &"attack_heavy" if attack_number % 3 == 0 else &"attack_primary"
	if attack_number % 3 == 2 and can_grab(attack_target) and creature.anim.has_state(&"bite_shake"):
		windup_clip = &"bite_shake"
	phase = &"windup"
	phase_left = {&"attack_heavy": 1.2, &"bite_shake": 0.75}.get(windup_clip, 0.7)
	creature.anim.play_timed_attack(windup_clip,phase_left)
	telegraph = Telegraph.show_tyrant(creature,contact_reach()+0.3,phase_left,windup_clip)

## Small enough to be lifted in her jaws and shaken.
static func can_grab(who: Node) -> bool:
	if who is Player: return true
	return who is Creature and (who as Creature).def != null and (who as Creature).def.height_meters <= GRAB_HEIGHT

func _impact() -> void:
	if windup_clip == &"alert":
		roar()
		return
	if not is_instance_valid(locked_target): return
	# A roll does not make her immune for its whole length: CreatureAttack judges the hit against
	# the opening window (RollRules) exactly as it does a bite, and pays the Defense XP for it.
	if locked_target is Player and (locked_target as Player).dead: return
	if locked_target is FieldCatapult and (locked_target as FieldCatapult).hp <= 0: return
	var offset := locked_target.global_position-creature.global_position
	offset.y = 0
	if offset.length() > reach_to(locked_target)+0.3: return
	var dot := offset.normalized().dot(locked_forward)
	if windup_clip == &"tail_swipe":
		if dot > 0.2: return  # the tail sweeps behind and beside her, never in front
	elif dot < (-0.4 if windup_clip == &"attack_heavy" else 0.15): return
	if windup_clip == &"bite_shake":
		if not CreatureAttack.apply_for(creature, windup_clip, locked_target, SHAKE_MULT): return
		if not CreatureAttack._target_dead(locked_target):
			CreatureAttack._apply_token(&"pinned", &"attack_primary", locked_target, creature)  # held in the jaws (the raid kit still prevents it)
		if locked_target is Player: (locked_target as Player).receive_creature_hit(creature, windup_clip)
		elif locked_target is Creature: (locked_target as Creature).anim.play_clip(&"knockdown")
		return
	CreatureAttack.apply_for(creature,windup_clip,locked_target)
	if locked_target is Player: (locked_target as Player).receive_creature_hit(creature,windup_clip)

## The battle roar's bellow: every survivor and small creature within ROAR_RADIUS staggers (groggy + a flinch);
## big animals stand their ground. Returns how many it staggered.
func roar() -> int:
	var n := 0
	var me := creature.global_position
	for p in PlayerRegistry.all():
		var pl := p as Player
		if pl == null or pl.dead or pl.global_position.distance_to(me) > ROAR_RADIUS: continue
		pl.statuses.apply(&"groggy", creature, 1)
		n += 1
	for c in creature.get_tree().get_nodes_in_group("creatures"):
		var cr := c as Creature
		if cr == null or cr == creature or cr.def == null or cr.health.dead: continue
		if cr.def.height_meters > ROAR_SMALL or cr.global_position.distance_to(me) > ROAR_RADIUS: continue
		cr.statuses.apply(&"groggy", creature, 1)
		cr.stop_move()
		cr.anim.play_clip(&"hit_react")
		cr.view.flinch(1.5)
		n += 1
	creature.status_float.emit(&"roar")
	return n

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
	if phase == &"windup": return "%s %.1fs" % [{&"attack_heavy": "STOMP", &"tail_swipe": "TAIL", &"bite_shake": "BITE & SHAKE", &"alert": "ROAR"}.get(windup_clip, "BITE"),phase_left]
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
