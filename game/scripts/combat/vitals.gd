class_name Vitals
extends Node
## Player Health / Energy / Exhaustion. Food eases exhaustion; sleep clears it.

signal exhausted_changed(on: bool)
signal damaged
signal died

var max_health: float = 100.0
var health: float = 100.0
var max_energy: float = 100.0
var energy: float = 100.0
var max_fatigue: float = 100.0
var fatigue: float = 0.0
var exhausted: bool = false
## Set on death: no regen, no further damage until revive().
var dead: bool = false
var blocks_regen: bool = false
var fatigue_gain_mult: float = 1.0
var fatigue_log: Dictionary = {}
## ASSUMPTION: Exhaustion rises by 100 over 45 minutes even at rest, plus exertion.
## It is a soft governor: at 50+ stamina regenerates more slowly; at 75+ its
## maximum is reduced. Neither state starves the survivor or disables gathering.
const EXHAUSTION_PER_SEC := 100.0 / (45.0 * 60.0)

## ASSUMPTION: Health regen is 0.8 HP/s while not blocked.
## Health regen pauses for REGEN_LOCK_S after any hit, otherwise small bites (compy 8 dmg every
## 1.2 s against passive healing) were regenerated away and combat looked like it dealt no damage.
@export var health_regen: float = 0.8
## Stamina (the blue bar): running, sprinting, attacks, tackles and rolls spend it. It refills
## fast out of combat and slowly in combat, after a short pause following any spend.
const STAMINA_REGEN_CALM := 16.0   # out of combat: full bar in ~7 s
const STAMINA_REGEN_COMBAT := 2.5  # in combat: a slow trickle
const STAMINA_LOCK_S := 0.8
var in_combat: bool = false
var _stamina_lock: float = 0.0
const REGEN_LOCK_S := 6.0
var _regen_lock: float = 0.0
@export var energy_regen: float = 2.0

func _process(delta: float) -> void:
	if dead:
		return
	add_fatigue(EXHAUSTION_PER_SEC * delta, &"time")
	_regen_lock = maxf(0.0, _regen_lock - delta)
	if not blocks_regen and _regen_lock <= 0.0:
		health = minf(effective_max_health(), health + health_regen * delta)
	_stamina_lock = maxf(0.0, _stamina_lock - delta)
	var strain := fatigue / maxf(1.0, max_fatigue)
	var stam_cap := max_energy * (0.75 if strain >= 0.75 else 1.0)
	if _stamina_lock <= 0.0:
		energy = minf(stam_cap, energy + (STAMINA_REGEN_COMBAT if in_combat else STAMINA_REGEN_CALM) * (0.65 if strain >= 0.5 else 1.0) * delta)
	energy = minf(energy, stam_cap)
	_sync_exhausted()

func _sync_exhausted() -> void:
	var on := fatigue >= max_fatigue * 0.95
	if on != exhausted:
		exhausted = on
		exhausted_changed.emit(on)

func effective_max_health() -> float:
	return max_health

func take_damage(amount: float) -> void:
	if dead:
		return
	var was := health
	health = maxf(0.0, health - amount)
	add_fatigue(amount * 0.15, &"combat")
	if amount > 0.0:
		_regen_lock = REGEN_LOCK_S
		damaged.emit()
	if was > 0.0 and health <= 0.0:
		dead = true
		died.emit()

func heal(amount: float) -> void:
	if dead:
		return
	health = minf(effective_max_health(), health + amount)

## Respawn: back to a fraction of max health, fatigue eased, regen on again.
func revive(health_frac: float = 0.5) -> void:
	dead = false
	health = maxf(1.0, effective_max_health() * clampf(health_frac, 0.05, 1.0))
	energy = maxf(energy, max_energy * 0.5)
	fatigue = minf(fatigue, max_fatigue * 0.5)
	_sync_exhausted()

## Food keeps its Energy restore and timed recipe buffs; a meal also grants a
## small exhaustion break. Sleep remains the only full reset.
func eat(amount: float) -> void:
	rest(amount * 0.25)

func add_fatigue(amount: float, source: StringName = &"") -> void:
	var add := amount * fatigue_gain_mult
	fatigue = clampf(fatigue + add, 0.0, max_fatigue)
	_sync_exhausted()
	if source != &"" and add > 0.0:
		fatigue_log[str(source)] = float(fatigue_log.get(str(source), 0.0)) + add

func rest(amount: float) -> void:
	fatigue = clampf(fatigue - amount, 0.0, max_fatigue)
	_sync_exhausted()

func to_dict() -> Dictionary:
	return {
		"health": health,
		"energy": energy,
		"fatigue": fatigue,
		"max_health": max_health,
		"max_energy": max_energy,
		"max_fatigue": max_fatigue,
	}

func from_dict(d: Dictionary) -> void:
	health = float(d.get("health", health))
	energy = float(d.get("energy", energy))
	fatigue = float(d.get("fatigue", fatigue))
	max_health = float(d.get("max_health", max_health))
	max_energy = float(d.get("max_energy", max_energy))
	max_fatigue = float(d.get("max_fatigue", max_fatigue))
	fatigue = clampf(fatigue, 0.0, max_fatigue)
	_sync_exhausted()

func spend_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	_stamina_lock = STAMINA_LOCK_S
	return true

## Continuous drain (running): returns false when empty so the caller drops to a walk.
func drain_energy(per_second: float, delta: float) -> bool:
	if energy <= 0.0:
		return false
	energy = maxf(0.0, energy - per_second * delta)
	_stamina_lock = STAMINA_LOCK_S
	return energy > 0.0
