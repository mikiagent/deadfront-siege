class_name PetRecord
extends RefCounted
## Bonded animal. Stats are a snapshot of the wild CreatureDef (R2).

var species: StringName = &""
var variant: StringName = &""
var grade: StringName = &"B"
var hunger: float = 0.0
var hunger_max: float = 0.0
var hunger_efficiency: float = 1.0
var xp_rate: float = 1.0
var hp: float = 0.0
var attack: float = 0.0
var defense: float = 0.0
var speed: float = 0.0
var tamed_role: Array[StringName] = []
var bag: Inventory
var summoned: bool = false

static func from_def(def: CreatureDef, p_grade: StringName, variant: StringName = &"") -> PetRecord:
	var r := PetRecord.new()
	r.species = def.id
	r.variant = variant
	r.grade = p_grade
	r.hp = def.hp
	r.attack = def.attack
	r.defense = def.defense
	r.speed = def.speed
	r.tamed_role = def.tamed_role.duplicate()
	r.hunger_max = def.hp * 0.4
	r.hunger = r.hunger_max
	match p_grade:
		&"S":
			r.hunger_efficiency = 1.3
			r.xp_rate = 1.3
		&"A":
			r.hunger_efficiency = 1.1
			r.xp_rate = 1.1
		&"C":
			r.hunger_efficiency = 0.85
			r.xp_rate = 0.85
		_:
			r.hunger_efficiency = 1.0
			r.xp_rate = 1.0
	var slots := def.bag_slots if def.bag_slots > 0 else 10 ## ASSUMPTION: every pet exposes 10 bag slots.
	r.bag = Inventory.new(slots)
	return r

func matches_wild(def: CreatureDef) -> bool:
	return is_equal_approx(hp, def.hp) and is_equal_approx(attack, def.attack) and is_equal_approx(defense, def.defense) and is_equal_approx(speed, def.speed)
