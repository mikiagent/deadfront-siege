class_name PetRecord
extends RefCounted
## Bonded animal. hp/attack/... are a cache of PetStats.compute(def, genetics, level); every
## change to level or genetics goes through recompute(), and loading recomputes too.

## Identity and provenance (contracts v2 section 0.5). The server replaces uid and owner with its
## own when it mints a pet; offline the uid is local and owner stays "".
var uid: String = ""
var owner: String = ""
## tame (field) | capture (pen) | breed (wave 2) | settlers | objective | market.
var origin: StringName = &"tame"
var tamer: String = ""
var tamed_at: int = 0
var wild_level: int = 1
## Identity fields from the ORIGINS contract; anything else loads as "tame".
const ORIGINS: Array[StringName] = [&"tame", &"capture", &"breed", &"settlers", &"objective", &"market"]
## Server uids are "p<seq>"; offline mints "p_<hex>" (new_uid). Both load.
const UID_RE := RegEx.create_from_string("^p_?[0-9a-f]+$")
const NAME_MAX := 24
var name: String = ""
## Lineage for breeding (wave 2): the two parents' uids, empty for wild-caught animals.
var parent_uids: Array[String] = []
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
## GAUNTLET/HANDOFF rule: 3-minute death cooldown.
const RESPAWN_TIME := 180.0
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
## less. Each level adds three random growth points; PetStats turns level and points into stats.
## ASSUMPTION: level n needs 30 + 15 n XP.
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
	while xp >= xp_to_next(level) and level < PetStats.MAX_LEVEL:
		xp -= xp_to_next(level)
		level += 1
		if genetics:
			genetics.add_level()
		gained += 1
	if gained > 0:
		recompute()
	return gained

## Focus EVs into one stat (the late-game training layer). Returns the EVs actually added.
func train(stat: StringName, amount: int = 1) -> int:
	if genetics == null:
		return 0
	var added := genetics.train(stat, amount)
	if added > 0:
		recompute()
	return added

## Refresh the cached stats and the grade-driven rates from species + genetics + level.
func recompute(def: CreatureDef = null) -> void:
	var d := def if def != null else Data.creature(species)
	if genetics == null:
		genetics = CreatureGenetics.neutral()
	genetics.clamp_level_gains(level)
	grade = genetics.overall_tier()
	xp_rate = PetStats.grade_rate(grade)
	hunger_efficiency = xp_rate
	if d == null:
		# Unknown species (removed from data): no base stats to compute from, and a stored row is
		# untrusted (probe loaded species "dodo" with hp 1e9), so neutralise instead of keeping them.
		hp = 0.0
		attack = 0.0
		ranged_attack = 0.0
		defense = 0.0
		ranged_defense = 0.0
		accuracy = 100.0
		speed = 0.0
		return
	var st := PetStats.compute(d, genetics, level)
	hp = st[&"health"]
	attack = st[&"melee_attack"]
	ranged_attack = st[&"ranged_attack"]
	defense = st[&"melee_defense"]
	ranged_defense = st[&"ranged_defense"]
	accuracy = st[&"accuracy"]
	speed = st[&"speed"]

## Local uid; the server issues its own "p<seq>" when it owns the pet.
static func new_uid() -> String:
	return "p_" + Crypto.new().generate_random_bytes(8).hex_encode()

## Bag size is the species' (10 when the species declares none), never smaller than what a save
## already holds, so a load can only grow a bag.
static func bag_slots_for(def: CreatureDef, saved: int = 0) -> int:
	var slots := def.bag_slots if def != null and def.bag_slots > 0 else 10 ## ASSUMPTION: every pet exposes 10 bag slots.
	return maxi(slots, saved)

## _legacy_grade is ignored: the grade always derives from genetics (callers still pass one).
static func from_def(def: CreatureDef, _legacy_grade: StringName = &"", variant: StringName = &"", p_genetics: CreatureGenetics = null, p_level: int = 1) -> PetRecord:
	var r := PetRecord.new()
	r.uid = new_uid()
	r.tamed_at = int(Time.get_unix_time_from_system())
	r.species = def.id
	r.variant = variant
	r.genetics = p_genetics if p_genetics != null else CreatureGenetics.roll()
	r.level = clampi(p_level, 1, PetStats.MAX_LEVEL)
	r.wild_level = r.level
	r.tamed_role = def.tamed_role.duplicate()
	r.hunger_max = def.hp * 0.4
	r.hunger = r.hunger_max
	r.recompute(def)
	r.bag = Inventory.new(bag_slots_for(def))
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

func to_dict() -> Dictionary:
	var roles: Array = []
	for r in tamed_role:
		roles.append(str(r))
	var parents: Array = []
	for p in parent_uids:
		parents.append(p)
	return {
		"uid": uid,
		"owner": owner,
		"origin": str(origin),
		"tamer": tamer,
		"tamed_at": tamed_at,
		"wild_level": wild_level,
		"name": name,
		"parent_uids": parents,
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

## Stored stats, grade and rates are not trusted: they are recomputed (legacy saves carry the
## old compounding numbers). Missing identity fields get defaults so old saves keep loading.
## Identity fields are untrusted too (the market will key pets by uid): an unknown origin or a
## malformed uid is replaced here, and the W2-INT AssetValidator still has to reject duplicate
## uids within one owner's roster (from_dict cannot see the roster).
static func from_dict(d: Dictionary) -> PetRecord:
	var r := PetRecord.new()
	var raw_uid: Variant = d.get("uid", "")
	r.uid = raw_uid if raw_uid is String and UID_RE.search(raw_uid) != null else new_uid()
	r.owner = str(d.get("owner", ""))
	var o := StringName(str(d.get("origin", "tame"))) ## ASSUMPTION: pre-uid saves were tames.
	r.origin = o if o in ORIGINS else &"tame"
	r.tamer = str(d.get("tamer", ""))
	r.tamed_at = clampi(int(d.get("tamed_at", 0)), 0, int(Time.get_unix_time_from_system()) + 86400)
	r.name = str(d.get("name", "")).strip_edges().substr(0, NAME_MAX)
	var parents: Variant = d.get("parent_uids", [])
	if parents is Array:
		for p in parents:
			r.parent_uids.append(str(p))
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
	r.level = clampi(int(d.get("level", 1)), 1, PetStats.MAX_LEVEL)
	# A pet was caught at or below the level it has now; a wild_level above level is forged.
	r.wild_level = clampi(int(d.get("wild_level", 1)), 1, r.level)
	r.xp = float(d.get("xp", 0.0))
	r.respawn_left = clampf(float(d.get("respawn_left", 0.0)), 0.0, RESPAWN_TIME)
	var def := Data.creature(r.species)
	r.recompute(def)
	var raw_bag: Variant = d.get("bag", [])
	var bag_rows: Array = raw_bag if raw_bag is Array else []
	# Saved rows only keep a legacy 10-slot bag; a padded save cannot grow the bag past that.
	r.bag = Inventory.new(bag_slots_for(def, mini(bag_rows.size(), 10)))
	r.bag.load_array(bag_rows)
	return r
