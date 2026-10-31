class_name MegaRexBrain
extends TyrantBrain
## MEGAREX (owner 2026-10-31, on the v2 open-mouth rex: "call that monstrosity MegaRex ... make it a boss fight"):
## the tyrant's timed, fixed-facing moves in three phases by health.
##   1 (> 66 %): bite, bite, stomp (the stomp pins with the foot, PINFEEL); a target behind her draws a turn, no whip.
##   2 (<= 66 %): adds the bite and shake (every third bite on something she can lift) and the tail whip, and every
##      telegraph is shorter.
##   3 (<= 33 %): enraged: she roars on entering it and again every ROAR_COOLDOWN in melee (survivors and small creatures
##      around her stagger), and attacks faster with even shorter telegraphs and recoveries.
## ASSUMPTION: the phase cut-offs, windup and recovery scales, roar radius/size/cooldown below are first guesses.

const PHASE2 := 0.66
const PHASE3 := 0.33
const WINDUP_SCALE := [1.0, 0.8, 0.65]
const RECOVERY_SCALE := [1.0, 0.9, 0.7]
## Bite and shake: clamp, thrash, fling. Only on what fits in her jaws.
const GRAB_HEIGHT := 3.0
const SHAKE_MULT := 1.5
## The phase-3 roar: Groggy and a flinch on survivors and on creatures no taller than ROAR_SMALL within ROAR_RADIUS.
const ROAR_RADIUS := 22.0
const ROAR_SMALL := 3.0
const ROAR_COOLDOWN := 14.0

static var _bosses: Array[MegaRexBrain] = []
var boss_phase := 1
var roar_ready_at := 0.0

func _enter_tree() -> void:
	if not _bosses.has(self):
		_bosses.append(self)

func _exit_tree() -> void:
	_bosses.erase(self)
	super._exit_tree()

## The boss fighting `who` right now (its target is `who`), for the HUD's boss bar; null when none.
static func engaged_boss(who: Node3D) -> Creature:
	for b in _bosses:
		if is_instance_valid(b) and b.creature and not b.creature.health.dead and b.attack_target == who:
			return b.creature
	return null

func hp_frac() -> float:
	return clampf(creature.health.hp / maxf(1.0, creature.health.max_hp), 0.0, 1.0)

func _update_phase() -> void:
	var f := hp_frac()
	var p := 3 if f <= PHASE3 else (2 if f <= PHASE2 else 1)
	if p == boss_phase:
		return
	boss_phase = p
	creature.status_float.emit(StringName("phase %d" % p))
	if p == 3:
		creature.statuses.apply(&"enraged", creature, 1)
		roar_ready_at = 0.0  # enraged: the roar opens phase 3

func _think(delta: float) -> void:
	_update_phase()
	if boss_phase == 3 and not creature.statuses.has(&"enraged"):
		creature.statuses.apply(&"enraged", creature, 1)  # stays enraged for the rest of the fight
	super._think(delta)

func _special_attack(offset: Vector3) -> bool:
	if boss_phase < 3 or Time.get_ticks_msec() * 0.001 < roar_ready_at or not creature.anim.has_state(&"alert"):
		return false
	roar_ready_at = Time.get_ticks_msec() * 0.001 + ROAR_COOLDOWN
	locked_forward = offset.normalized() if offset.length_squared() > 0.0001 else -creature.global_basis.z
	windup_clip = &"alert"
	phase = &"windup"
	phase_left = _windup_s(windup_clip)
	creature.anim.play_timed_attack(windup_clip, phase_left)
	telegraph = Telegraph.show_tyrant(creature, ROAR_RADIUS, phase_left, windup_clip)
	return true

func _tail_ok() -> bool:
	return boss_phase >= 2

func _pick_attack() -> StringName:
	if attack_number % 3 == 0:
		return &"attack_heavy"
	if boss_phase >= 2 and attack_number % 3 == 2 and can_grab(attack_target) and creature.anim.has_state(&"bite_shake"):
		return &"bite_shake"
	return &"attack_primary"

func _windup_s(clip: StringName) -> float:
	var base: float = {&"bite_shake": 0.75, &"alert": 1.0}.get(clip, super._windup_s(clip))
	return base * float(WINDUP_SCALE[boss_phase - 1])

func _recovery_s(clip: StringName) -> float:
	var base: float = {&"bite_shake": 1.75, &"alert": 1.4}.get(clip, super._recovery_s(clip))
	return base * float(RECOVERY_SCALE[boss_phase - 1])

## Small enough to be lifted in her jaws and shaken.
static func can_grab(who: Node) -> bool:
	if who is Player:
		return true
	return who is Creature and (who as Creature).def != null and (who as Creature).def.height_meters <= GRAB_HEIGHT

func _impact_special() -> bool:
	if windup_clip == &"alert":
		roar()
		return true
	if windup_clip != &"bite_shake":
		return false
	if not is_instance_valid(locked_target):
		return true
	if locked_target is Player and (locked_target as Player).dead:
		return true
	if Hitbox.applies(creature, locked_target):
		# HITBOXES: the jaws (hitboxes.json megarex bite_shake) must close on her hurtboxes.
		var hit := Hitbox.strike(creature, windup_clip, locked_target)
		if hit.is_empty():
			return true
		Hitbox.mark(locked_target, hit)
	else:
		var offset := locked_target.global_position - creature.global_position
		offset.y = 0.0
		if offset.length() > reach_to(locked_target) + 0.3 or offset.normalized().dot(locked_forward) < 0.15:
			return true
	if not CreatureAttack.apply_for(creature, windup_clip, locked_target, SHAKE_MULT):
		return true
	if not CreatureAttack._target_dead(locked_target):
		CreatureAttack._apply_token(&"knockdown", windup_clip, locked_target, creature)  # flung down; Pinned stays the stomp's (PINFEEL)
	if locked_target is Player:
		(locked_target as Player).receive_creature_hit(creature, windup_clip)
	return true

## The roar's bellow: every survivor and small creature within ROAR_RADIUS staggers (Groggy + a flinch); big animals
## stand their ground. Returns how many it staggered.
func roar() -> int:
	var n := 0
	var me := creature.global_position
	for pl in PlayerRegistry.all():
		if pl == null or pl.dead or pl.global_position.distance_to(me) > ROAR_RADIUS:
			continue
		pl.statuses.apply(&"groggy", creature, 1)
		n += 1
	for c in creature.get_tree().get_nodes_in_group("creatures"):
		var cr := c as Creature
		if cr == null or cr == creature or cr.def == null or cr.health.dead:
			continue
		if cr.def.height_meters > ROAR_SMALL or cr.global_position.distance_to(me) > ROAR_RADIUS:
			continue
		cr.statuses.apply(&"groggy", creature, 1)
		cr.stop_move()
		cr.anim.play_clip(&"hit_react")
		cr.view.flinch(1.5)
		n += 1
	creature.status_float.emit(&"roar")
	return n

func opening_label() -> String:
	return "MEGAREX  PHASE %d%s   %s" % [boss_phase, "  ENRAGED" if boss_phase == 3 else "", super.opening_label()]
