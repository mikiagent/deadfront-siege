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

func to_dict() -> Dictionary:
	var roles: Array = []
	for r in tamed_role:
		roles.append(str(r))
	return {
		"species": str(species),
		"variant": str(variant),
		"grade": str(grade),
		"hunger": hunger,
		"hunger_max": hunger_max,
		"hunger_efficiency": hunger_efficiency,
		"xp_rate": xp_rate,
		"hp": hp,
		"attack": attack,
		"defense": defense,
		"speed": speed,
		"tamed_role": roles,
		"bag": bag.to_array() if bag else [],
	}

static func from_dict(d: Dictionary) -> PetRecord:
	var r := PetRecord.new()
	r.species = StringName(str(d.get("species", "")))
	r.variant = StringName(str(d.get("variant", "")))
	r.grade = StringName(str(d.get("grade", "B")))
	r.hunger = float(d.get("hunger", 0.0))
	r.hunger_max = float(d.get("hunger_max", 0.0))
	r.hunger_efficiency = float(d.get("hunger_efficiency", 1.0))
	r.xp_rate = float(d.get("xp_rate", 1.0))
	r.hp = float(d.get("hp", 0.0))
	r.attack = float(d.get("attack", 0.0))
	r.defense = float(d.get("defense", 0.0))
	r.speed = float(d.get("speed", 0.0))
	r.tamed_role.clear()
	for v in d.get("tamed_role", []):
		r.tamed_role.append(StringName(str(v)))
	r.bag = Inventory.new(10)
	r.bag.load_array(d.get("bag", []))
	return r
