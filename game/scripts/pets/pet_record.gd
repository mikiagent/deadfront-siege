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
var ranged_defense: float = 0.0
var ranged_attack: float = 0.0
var accuracy: float = 100.0
var speed: float = 0.0
var genetics: CreatureGenetics
var tamed_role: Array[StringName] = []
var bag: Inventory
var summoned: bool = false
## A dead pet comes back after this long; the PETS sheet shows the countdown ring.
const RESPAWN_TIME := 60.0
var respawn_left: float = 0.0

func respawning() -> bool:
	return respawn_left > 0.0

func tick_respawn(delta: float) -> void:
	if respawn_left > 0.0:
		respawn_left = maxf(0.0, respawn_left - delta)

func start_respawn() -> void:
	respawn_left = RESPAWN_TIME
	summoned = false
## Pet level: kills by the pet pay most, kills by the survivor with the pet fighting nearby pay
## less. Each level: +8 % HP, +5 % attack, +4 % defense. ASSUMPTION: level n needs 30 + 15 n XP.
var level: int = 1
var xp: float = 0.0

static func xp_to_next(lv: int) -> float:
	return 30.0 + 15.0 * float(lv)

## Returns the number of levels gained.
func add_xp(amount: float) -> int:
	if amount <= 0.0:
		return 0
	xp += amount * xp_rate
	var gained := 0
	while xp >= xp_to_next(level) and level < 60:
		xp -= xp_to_next(level)
		level += 1
		hp *= 1.08
		attack *= 1.05
		defense *= 1.04
		ranged_defense *= 1.04
		ranged_attack *= 1.05
		if genetics:
			genetics.add_level()
		gained += 1
	return gained

static func from_def(def: CreatureDef, p_grade: StringName, variant: StringName = &"", p_genetics: CreatureGenetics = null) -> PetRecord:
	var r := PetRecord.new()
	r.species = def.id
	r.variant = variant
	r.genetics = p_genetics if p_genetics != null else CreatureGenetics.roll()
	r.grade = r.genetics.overall_tier()
	r.hp = def.hp * r.genetics.multiplier(&"health")
	r.attack = def.attack * r.genetics.multiplier(&"melee_attack")
	r.ranged_attack = def.attack * r.genetics.multiplier(&"ranged_attack")
	r.defense = def.defense * r.genetics.multiplier(&"melee_defense")
	r.ranged_defense = def.defense * r.genetics.multiplier(&"ranged_defense")
	r.accuracy = 100.0 * r.genetics.multiplier(&"accuracy")
	r.speed = def.speed * r.genetics.multiplier(&"speed")
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

func stat_value(stat: StringName) -> float:
	match stat:
		&"health": return hp
		&"melee_defense": return defense
		&"ranged_defense": return ranged_defense
		&"melee_attack": return attack
		&"ranged_attack": return ranged_attack
		&"accuracy": return accuracy
		&"speed": return speed
	return 0.0

func accuracy_chance() -> float:
	return clampf(0.90 + (accuracy - 100.0) * 0.004, 0.72, 0.99)

func crit_chance() -> float:
	return clampf(0.05 + (accuracy - 85.0) * 0.003, 0.02, 0.16)

func dodge_chance(def: CreatureDef) -> float:
	return clampf(0.04 + (speed / maxf(1.0, def.speed) - 0.85) * 0.20, 0.04, 0.10)

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
		"ranged_defense": ranged_defense,
		"ranged_attack": ranged_attack,
		"accuracy": accuracy,
		"speed": speed,
		"genetics": genetics.to_dict() if genetics else {},
		"tamed_role": roles,
		"bag": bag.to_array() if bag else [],
		"level": level,
		"xp": xp,
		"respawn_left": respawn_left,
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
	r.ranged_defense = float(d.get("ranged_defense", r.defense))
	r.ranged_attack = float(d.get("ranged_attack", r.attack))
	r.accuracy = float(d.get("accuracy", 100.0))
	r.speed = float(d.get("speed", 0.0))
	r.genetics = CreatureGenetics.from_dict(d.get("genetics", {})) if d.get("genetics", {}) is Dictionary else CreatureGenetics.neutral()
	r.tamed_role.clear()
	for v in d.get("tamed_role", []):
		r.tamed_role.append(StringName(str(v)))
	r.bag = Inventory.new(10)
	r.bag.load_array(d.get("bag", []))
	r.level = maxi(1, int(d.get("level", 1)))
	r.xp = float(d.get("xp", 0.0))
	r.respawn_left = maxf(0.0, float(d.get("respawn_left", 0.0)))
	return r
