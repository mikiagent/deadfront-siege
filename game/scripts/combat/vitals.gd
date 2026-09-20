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

## ASSUMPTION: Health/Energy regen rates are not numbered in PRD §2.3; 1.5 HP/s and 2 Energy/s while not blocked.
@export var health_regen: float = 1.5
@export var energy_regen: float = 2.0

func _process(delta: float) -> void:
	if dead:
		return
	hunger = maxf(0.0, hunger - HUNGER_PER_SEC * delta)
	thirst = maxf(0.0, thirst - THIRST_PER_SEC * delta)
	var starving := hunger <= 0.0 or thirst <= 0.0
	if starving:
		add_fatigue(delta / 60.0, &"hunger")
	if not blocks_regen and not starving:
		health = minf(effective_max_health(), health + health_regen * delta)
	energy = minf(max_energy, energy + energy_regen * delta)
	var was := exhausted
	exhausted = fatigue >= max_fatigue
	if exhausted != was:
		exhausted_changed.emit(exhausted)

func effective_max_health() -> float:
	return max_health

func take_damage(amount: float) -> void:
	if dead:
		return
	var was := health
	health = maxf(0.0, health - amount)
	add_fatigue(amount * 0.15, &"combat")
	if amount > 0.0:
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
	return true
