class_name AssetValidator
extends RefCounted
## The deposit trust boundary (contract 4). A deposit is a client's claim, so every field is
## checked against the catalog and rebuilt into a canonical dict; nothing the client sent is
## stored verbatim. Pet stats are recomputed the way PetRecord.from_def + add_xp build them.

const ITEM_KEYS := ["id", "def_id", "count", "level", "process_count", "attributes", "flags", "durability", "max_durability"]
## Per-level growth PetRecord.add_xp applies; accuracy and speed never grow with level.
const GROWTH := {"hp": 1.08, "attack": 1.05, "ranged_attack": 1.05, "defense": 1.04, "ranged_defense": 1.04, "accuracy": 1.0, "speed": 1.0}
const GENE := {"hp": "health", "attack": "melee_attack", "ranged_attack": "ranged_attack", "defense": "melee_defense", "ranged_defense": "ranged_defense", "accuracy": "accuracy", "speed": "speed"}
const GRADE_RATES := [1.3, 1.1, 1.0, 0.85] ## PetRecord.from_def hunger_efficiency / xp_rate

var cat: EconCatalog
var rules: EconRules

func _init(p_catalog: EconCatalog, p_rules: EconRules) -> void:
	cat = p_catalog
	rules = p_rules

## Returns {"msg": "" or why it was refused, "v": canonical stack of `count` units}.
func item(slot: Variant, count: int) -> Dictionary:
	if not slot is Dictionary:
		return _no("slot_dict must be an object")
	var d: Dictionary = slot
	for k in d:
		if str(k) not in ITEM_KEYS:
			return _no("unknown item field %s" % str(k))
	var id_v: Variant = d.get("id", d.get("def_id"))
	if d.has("id") and d.has("def_id") and str(d.id) != str(d.def_id):
		return _no("id and def_id disagree")
	if not (id_v is String or id_v is StringName):
		return _no("item id missing")
	var def_id := str(id_v)
	var def := cat.item(def_id)
	if def == null:
		return _no("unknown item %s" % def_id)
	if def_id in rules.g("denied_defs"):
		return _no("%s cannot be traded; bond or release it first" % def_id)
	var have: Variant = EconArgs.as_int(d.get("count"))
	if have == null or int(have) < 1 or int(have) > def.stack_max:
		return _no("count must be 1..%d" % def.stack_max)
	if count < 1 or count > int(have):
		return _no("deposit count must be 1..%d" % int(have))
	var level: Variant = EconArgs.as_int(d.get("level", 1))
	if level == null or int(level) < rules.num("level_min") or int(level) > rules.num("level_max"):
		return _no("level must be %d..%d" % [rules.num("level_min"), rules.num("level_max")])
	var process: Variant = EconArgs.as_int(d.get("process_count", 0))
	if process == null or int(process) < 0 or int(process) > rules.num("process_count_max"):
		return _no("process_count out of range")
	var flags_out: Array = []
	var flags_in: Variant = d.get("flags", [])
	if not flags_in is Array:
		return _no("flags must be an array")
	for f in flags_in:
		var flag := str(f)
		if flag in rules.g("refused_flags"):
			return _no("%s items cannot be traded" % flag)
		if flag not in rules.g("allowed_flags") or flag in flags_out:
			return _no("flag %s not allowed" % flag)
		flags_out.append(flag)
	flags_out.sort()
	var attrs_in: Variant = d.get("attributes", {})
	if not attrs_in is Dictionary:
		return _no("attributes must be an object")
	var attrs := {}
	for k in attrs_in:
		var why := _attribute(str(k), attrs_in[k])
		if why != "":
			return _no(why)
		attrs[str(k)] = Ledger.norm(attrs_in[k])
	var dur: Variant = EconArgs.as_int(d.get("durability", 0))
	var dur_max: Variant = EconArgs.as_int(d.get("max_durability", 0))
	if dur == null or dur_max == null:
		return _no("durability must be integers")
	if def.max_durability > 0:
		var cap := def.max_durability_at(int(level))
		if int(dur_max) < 1 or int(dur_max) > cap:
			return _no("max_durability must be 1..%d at level %d" % [cap, int(level)])
		if int(dur) < 1:
			return _no("broken items cannot be traded")
		if int(dur) > int(dur_max):
			return _no("durability above max")
	elif int(dur) != 0 or int(dur_max) != 0:
		return _no("%s has no durability" % def_id)
	return {"msg": "", "v": {
		"id": def_id, "count": count, "level": int(level), "process_count": int(process),
		"attributes": attrs, "flags": flags_out, "durability": int(dur), "max_durability": int(dur_max),
	}}

func _attribute(key: String, v: Variant) -> String:
	var spec: Variant = (rules.g("attributes") as Dictionary).get(key)
	if key.begins_with("_") or not spec is Dictionary:
		return "attribute %s not allowed" % key
	match str(spec.get("type", "")):
		"color":
			var t := str(v)
			if not (v is String) or not (t.length() == 7 or t.length() == 9) or not t.begins_with("#") or not t.substr(1).is_valid_hex_number():
				return "attribute %s must be #rrggbb" % key
		"enum":
			if not (v is String) or str(v) not in spec.get("values", []):
				return "attribute %s value not allowed" % key
		"bool":
			if not v is bool:
				return "attribute %s must be true/false" % key
		"int":
			var n: Variant = EconArgs.as_int(v)
			if n == null or int(n) < int(spec.get("min", 0)) or int(n) > int(spec.get("max", 0)):
				return "attribute %s out of range" % key
		_:
			return "attribute %s has no rule" % key
	return ""

## Returns {"msg", "v": canonical PetDict}. Derived labels (grade, roles, hunger_max) are
## rebuilt from the catalog; stats must match the recomputation within the tolerance.
func pet(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return _no("pet_dict must be an object")
	var d: Dictionary = raw
	var species := str(d.get("species", ""))
	var def := cat.creature(species)
	if def == null:
		return _no("unknown species %s" % species)
	var variant := str(d.get("variant", ""))
	# Variants are cosmetic and island spawn tables may name ones the def omits: shape check only.
	if variant != "" and not EconArgs.is_id(variant):
		return _no("bad variant")
	if bool(d.get("summoned", false)):
		return _no("dismiss the pet before depositing it")
	var level: Variant = EconArgs.as_int(d.get("level", 1))
	if level == null or int(level) < 1 or int(level) > rules.num("level_max"):
		return _no("pet level must be 1..%d" % rules.num("level_max"))
	var lv := int(level)
	var bag: Variant = d.get("bag", [])
	if not bag is Array:
		return _no("bag must be an array")
	for slot in bag:
		if slot != null:
			return _no("empty the pet bag before depositing it")
	var genes := _genetics(d.get("genetics"), lv)
	if genes.has("msg"):
		return genes
	var tol := float(rules.g("pet_stat_tolerance"))
	var out := {"species": species, "variant": variant, "level": lv}
	for stat in GROWTH:
		var have: Variant = d.get(stat)
		if not (have is float or have is int) or not is_finite(float(have)):
			return _no("%s missing" % stat)
		var want := _expected(def, stat, int(genes.ivs[GENE[stat]]), lv)
		if absf(float(have) - want) > tol * absf(want) + 0.000001:
			return _no("%s %.3f does not match species, level and genetics (%.3f)" % [stat, float(have), want])
		out[stat] = q(want)
	var rate: Variant = d.get("hunger_efficiency", 1.0)
	var grade_rate := _grade_rate(rate)
	if grade_rate < 0.0 or _grade_rate(d.get("xp_rate")) != grade_rate:
		return _no("hunger_efficiency / xp_rate do not match a grade")
	out.hunger_efficiency = grade_rate
	out.xp_rate = grade_rate
	out.hunger_max = q(def.hp * 0.4)
	var hunger: Variant = d.get("hunger", 0.0)
	if not (hunger is float or hunger is int) or float(hunger) < 0.0 or float(hunger) > out.hunger_max * (1.0 + tol):
		return _no("hunger out of range")
	out.hunger = minf(q(float(hunger)), out.hunger_max)
	var xp: Variant = d.get("xp", 0.0)
	var xp_cap := PetRecord.xp_to_next(lv) if lv < rules.num("level_max") else 1.0e9
	if not (xp is float or xp is int) or float(xp) < 0.0 or float(xp) >= xp_cap:
		return _no("xp out of range")
	out.xp = q(float(xp))
	if out.xp >= xp_cap:
		return _no("xp out of range")
	var respawn: Variant = d.get("respawn_left", 0.0)
	if not (respawn is float or respawn is int) or float(respawn) < 0.0 or float(respawn) > PetRecord.RESPAWN_TIME:
		return _no("respawn_left out of range")
	out.respawn_left = q(float(respawn))
	var g := CreatureGenetics.new()
	g.ivs = _keyed(genes.ivs)
	out.grade = str(g.overall_tier())
	out.genetics = {"ivs": genes.ivs, "evs": genes.evs, "level_gains": genes.level_gains}
	var roles: Array = []
	for r in def.tamed_role:
		roles.append(str(r))
	out.tamed_role = roles
	out.bag = []
	return {"msg": "", "v": Ledger.norm(out)}

## IVs 0..31 for every stat, EVs 0..100 with total <= 300, level gains no more than the
## three per level PetRecord.add_xp grants.
func _genetics(raw: Variant, level: int) -> Dictionary:
	if not raw is Dictionary:
		return _no("genetics missing")
	var out := {"ivs": {}, "evs": {}, "level_gains": {}}
	var ev_total := 0
	var gain_total := 0
	for part in out:
		var src: Variant = (raw as Dictionary).get(part, {})
		if not src is Dictionary:
			return _no("genetics.%s must be an object" % part)
		for k in src:
			if StringName(str(k)) not in CreatureGenetics.STATS:
				return _no("unknown stat %s" % str(k))
		for stat in CreatureGenetics.STATS:
			var key := str(stat)
			if part == "ivs" and not (src as Dictionary).has(key):
				return _no("iv %s missing" % key)
			var n: Variant = EconArgs.as_int((src as Dictionary).get(key, 0))
			var hi := CreatureGenetics.IV_MAX if part == "ivs" else (CreatureGenetics.EV_MAX_PER_STAT if part == "evs" else 3 * (level - 1))
			if n == null or int(n) < 0 or int(n) > hi:
				return _no("%s %s out of range" % [part, key])
			out[part][key] = int(n)
			if part == "evs":
				ev_total += int(n)
			elif part == "level_gains":
				gain_total += int(n)
	if ev_total > CreatureGenetics.EV_TOTAL_MAX:
		return _no("EV total above %d" % CreatureGenetics.EV_TOTAL_MAX)
	if gain_total > 3 * (level - 1):
		return _no("more level gains than levels")
	return out

## PetRecord.from_def snapshots base x IV multiplier at capture (level 1, no gains or EVs);
## add_xp then multiplies by the growth rate per level.
static func _expected(def: CreatureDef, stat: String, iv: int, level: int) -> float:
	var base := 100.0
	match stat:
		"hp": base = def.hp
		"attack", "ranged_attack": base = def.attack
		"defense", "ranged_defense": base = def.defense
		"speed": base = def.speed
	var mult := 0.85 + 0.30 * float(iv) / float(CreatureGenetics.IV_MAX)
	return base * mult * pow(float(GROWTH[stat]), float(level - 1))

## Stored pet floats sit on a 0.001 grid. Godot's JSON reader is not exact for 17-digit
## doubles (about 1 in 8 comes back an ulp off), but grid values survive the trip, so the
## journal and snapshot reload to byte-identical state. economy_tests checks the round trip.
static func q(x: float) -> float:
	return roundf(x * 1000.0) / 1000.0

## The grade rate `v` names (within float noise), or -1.
static func _grade_rate(v: Variant) -> float:
	if not (v is float or v is int):
		return -1.0
	for r in GRADE_RATES:
		if absf(float(v) - r) < 0.000001:
			return r
	return -1.0

static func _keyed(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[StringName(k)] = src[k]
	return out

static func _no(msg: String) -> Dictionary:
	return {"msg": msg}
