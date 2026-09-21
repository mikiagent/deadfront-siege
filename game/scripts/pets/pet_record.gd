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
## Pet level: kills by the pet pay most, kills by the survivor with the pet fighting nearby pay
## less. Each level: +8 % HP, +5 % attack, +4 % defense. ASSUMPTION: level n needs 30 + 15 n XP.
var level: int = 1
var xp: float = 0.0
## Runtime health is distinct from the level-scaled maximum (`hp`). It is written on every
## health change so save/load cannot silently heal a pet to full.
var current_hp: float = 0.0
## Unix second when this pet may return after being knocked out. Zero means ready.
var respawn_ready_unix: int = 0
const RESPAWN_COOLDOWN_SECONDS := 180

func respawn_seconds_left(now_unix: int = int(Time.get_unix_time_from_system())) -> int:
	return maxi(0, respawn_ready_unix - now_unix)

func can_respawn(now_unix: int = int(Time.get_unix_time_from_system())) -> bool:
	return respawn_seconds_left(now_unix) <= 0

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
		gained += 1
	return gained

static func from_def(def: CreatureDef, p_grade: StringName, variant: StringName = &"") -> PetRecord:
	var r := PetRecord.new()
	r.species = def.id
	r.variant = variant
	r.grade = p_grade
	r.hp = def.hp
	r.current_hp = def.hp
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
		"level": level,
		"xp": xp,
		"current_hp": current_hp,
		"respawn_ready_unix": respawn_ready_unix,
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
	r.level = maxi(1, int(d.get("level", 1)))
	r.xp = float(d.get("xp", 0.0))
	r.current_hp = clampf(float(d.get("current_hp", r.hp)), 0.0, r.hp)
	r.respawn_ready_unix = maxi(0, int(d.get("respawn_ready_unix", 0)))
	return r
