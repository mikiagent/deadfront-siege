class_name Vitals
extends Node
## Player Health / Energy / Fatigue. Food and rest arrive later; this milestone only accumulates fatigue.

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
## Hunger and thirst, 100 = sated. Eating fills hunger (1.5 × the food's energy), drinking
## fills thirst by 30. ASSUMPTION: hunger empties in 45 real minutes and thirst in 30 (PRD
## §2.3 gives no rates); at zero, health stops regenerating and fatigue climbs 1/min.
var max_hunger: float = 100.0
var hunger: float = 100.0
var max_thirst: float = 100.0
var thirst: float = 100.0
const HUNGER_PER_SEC := 100.0 / (45.0 * 60.0)
const THIRST_PER_SEC := 100.0 / (30.0 * 60.0)

## ASSUMPTION: Health/Energy regen rates are not numbered in PRD §2.3; 0.8 HP/s and 2 Energy/s while not blocked.
## Health regen pauses for REGEN_LOCK_S after any hit, otherwise small bites (compy 8 dmg every
## 1.2 s against 1.5 HP/s) were regenerated away and combat looked like it dealt no damage.
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
	hunger = maxf(0.0, hunger - HUNGER_PER_SEC * delta)
	thirst = maxf(0.0, thirst - THIRST_PER_SEC * delta)
	# Penalties: hungry (<50 %) halves stamina regen and caps stamina at 75 %; thirsty (<50 %)
	# halves health regen; either under 25 % stops health regen; either at 0 drains 0.3 HP/s.
	var hungry := hunger < max_hunger * 0.5
	var thirsty := thirst < max_thirst * 0.5
	var very_low := hunger < max_hunger * 0.25 or thirst < max_thirst * 0.25
	var empty := hunger <= 0.0 or thirst <= 0.0
	_regen_lock = maxf(0.0, _regen_lock - delta)
	if empty:
		health = maxf(1.0, health - 0.3 * delta)
	elif not blocks_regen and not very_low and _regen_lock <= 0.0:
		health = minf(effective_max_health(), health + health_regen * (0.5 if thirsty else 1.0) * delta)
	_stamina_lock = maxf(0.0, _stamina_lock - delta)
	var stam_cap := max_energy * (0.75 if hungry else 1.0)
	if _stamina_lock <= 0.0:
		energy = minf(stam_cap, energy + (STAMINA_REGEN_COMBAT if in_combat else STAMINA_REGEN_CALM) * (0.5 if hungry else 1.0) * delta)
	energy = minf(energy, stam_cap)
	# Fatigue no longer gates anything (the exhausted state was removed 2026-09-20).
	exhausted = false

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

func hungry() -> bool:
	return hunger < max_hunger * 0.5

func thirsty() -> bool:
	return thirst < max_thirst * 0.5

## Respawn: back to a fraction of max health, fatigue eased, regen on again.
func revive(health_frac: float = 0.5) -> void:
	dead = false
	health = maxf(1.0, effective_max_health() * clampf(health_frac, 0.05, 1.0))
	energy = maxf(energy, max_energy * 0.5)
	fatigue = minf(fatigue, max_fatigue * 0.5)
	hunger = maxf(hunger, max_hunger * 0.5)
	thirst = maxf(thirst, max_thirst * 0.5)

func eat(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, max_hunger)

func drink(amount: float = 30.0) -> void:
	thirst = clampf(thirst + amount, 0.0, max_thirst)

func add_fatigue(amount: float, source: StringName = &"") -> void:
	var add := amount * fatigue_gain_mult
	fatigue = clampf(fatigue + add, 0.0, max_fatigue)
	if source != &"" and add > 0.0:
		fatigue_log[str(source)] = float(fatigue_log.get(str(source), 0.0)) + add

func rest(amount: float) -> void:
	fatigue = clampf(fatigue - amount, 0.0, max_fatigue)

func to_dict() -> Dictionary:
	return {
		"health": health,
		"energy": energy,
		"fatigue": fatigue,
		"max_health": max_health,
		"max_energy": max_energy,
		"max_fatigue": max_fatigue,
		"hunger": hunger,
		"thirst": thirst,
	}

func from_dict(d: Dictionary) -> void:
	health = float(d.get("health", health))
	energy = float(d.get("energy", energy))
	fatigue = float(d.get("fatigue", fatigue))
	max_health = float(d.get("max_health", max_health))
	max_energy = float(d.get("max_energy", max_energy))
	max_fatigue = float(d.get("max_fatigue", max_fatigue))
	hunger = float(d.get("hunger", hunger))
	thirst = float(d.get("thirst", thirst))

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
