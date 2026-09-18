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
var blocks_regen: bool = false
var fatigue_gain_mult: float = 1.0
var fatigue_log: Dictionary = {}

## ASSUMPTION: Health/Energy regen rates are not numbered in PRD §2.3; 1.5 HP/s and 2 Energy/s while not blocked.
@export var health_regen: float = 1.5
@export var energy_regen: float = 2.0

func _process(delta: float) -> void:
	if not blocks_regen:
		health = minf(effective_max_health(), health + health_regen * delta)
	energy = minf(max_energy, energy + energy_regen * delta)
	var was := exhausted
	exhausted = fatigue >= max_fatigue
	if exhausted != was:
		exhausted_changed.emit(exhausted)

func effective_max_health() -> float:
	return max_health

func take_damage(amount: float) -> void:
	var was := health
	health = maxf(0.0, health - amount)
	add_fatigue(amount * 0.15, &"combat")
	if amount > 0.0:
		damaged.emit()
	if was > 0.0 and health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	health = minf(effective_max_health(), health + amount)

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
	}

func from_dict(d: Dictionary) -> void:
	health = float(d.get("health", health))
	energy = float(d.get("energy", energy))
	fatigue = float(d.get("fatigue", fatigue))
	max_health = float(d.get("max_health", max_health))
	max_energy = float(d.get("max_energy", max_energy))
	max_fatigue = float(d.get("max_fatigue", max_fatigue))

func spend_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true
