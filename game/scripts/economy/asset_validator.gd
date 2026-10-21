class_name AssetValidator
extends RefCounted
## Defence in depth behind contract v2 section 0: deposits come from the server character
## store, which minted them, and are kept byte for byte (char.receive takes back only the exact
## body it exported). Every field is still checked against the catalog, and pet stats against
## PetStats.compute, so a bug or a forged body upstream cannot mint value here.

const ITEM_KEYS := ["id", "count", "level", "process_count", "attributes", "flags", "durability", "max_durability"]
## PetRecord.to_dict() keys plus the summoned flag; anything else is refused.
const PET_KEYS := ["uid", "owner", "origin", "tamer", "tamed_at", "wild_level", "name", "parent_uids", "species", "variant", "grade", "hunger", "hunger_max", "hunger_efficiency", "xp_rate", "hp", "hp_now", "attack", "defense", "ranged_defense", "ranged_attack", "accuracy", "speed", "genetics", "tamed_role", "bag", "level", "xp", "respawn_left", "summoned"]
const CAGE := "captured_animal"
const GENE := {"hp": "health", "attack": "melee_attack", "ranged_attack": "ranged_attack", "defense": "melee_defense", "ranged_defense": "ranged_defense", "accuracy": "accuracy", "speed": "speed"}

var cat: EconCatalog
var rules: EconRules

func _init(p_catalog: EconCatalog, p_rules: EconRules) -> void:
	cat = p_catalog
	rules = p_rules

## "" or why the stack is refused. `slot` is a stack dict without its provenance stamp.
func item(slot: Variant) -> String:
	if not slot is Dictionary:
		return "slot_dict must be an object"
	var d: Dictionary = slot
	for k in d:
		if str(k) in ITEM_KEYS:
			continue
		# Per-instance identity besides the provenance stamp (limits.json instance_fields).
		if str(k).begins_with("_") or not (rules.g("instance_fields") as Dictionary).has(str(k)):
			return "unknown item field %s" % str(k)
		var bad := _rule("instance_fields", str(k), d[k])
		if bad != "":
			return bad
	var id_v: Variant = d.get("id")
	if not (id_v is String or id_v is StringName):
		return "item id missing"
	var def_id := str(id_v)
	var def := cat.item(def_id)
	if def == null:
		return "unknown item %s" % def_id
	if def_id in rules.g("denied_defs"):
		return "%s cannot be traded; bond or release it first" % def_id
	var have: Variant = EconArgs.as_int(d.get("count"))
	if have == null or int(have) < 1 or int(have) > def.stack_max:
		return "count must be 1..%d" % def.stack_max
	var level: Variant = EconArgs.as_int(d.get("level", 1))
	if level == null or int(level) < rules.num("level_min") or int(level) > rules.num("level_max"):
		return "level must be %d..%d" % [rules.num("level_min"), rules.num("level_max")]
	var process: Variant = EconArgs.as_int(d.get("process_count", 0))
	if process == null or int(process) < 0 or int(process) > rules.num("process_count_max"):
		return "process_count out of range"
	var flags_in: Variant = d.get("flags", [])
	if not flags_in is Array:
		return "flags must be an array"
	var seen: Array = []
	for f in flags_in:
		var flag := str(f)
		if flag in rules.g("refused_flags"):
			return "%s items cannot be traded" % flag
		if not f is String or flag not in rules.g("allowed_flags") or flag in seen:
			return "flag %s not allowed" % flag
		seen.append(flag)
	var attrs: Variant = d.get("attributes", {})
	if not attrs is Dictionary:
		return "attributes must be an object"
	var why := ""
	if def_id == CAGE:
		why = _cage(attrs)
	else:
		for k in attrs:
			why = _rule("attributes", str(k), attrs[k])
			if why != "":
				break
	if why != "":
		return why
	var dur: Variant = EconArgs.as_int(d.get("durability", 0))
	var dur_max: Variant = EconArgs.as_int(d.get("max_durability", 0))
	if dur == null or dur_max == null:
		return "durability must be integers"
	if def.max_durability > 0:
		# The cap ItemStack itself gives a fresh stack of this level and material tier.
		var cap := ItemStack.make(StringName(def_id), 1, attrs, int(level)).max_durability
		if int(dur_max) < 1 or int(dur_max) > cap:
			return "max_durability must be 1..%d at level %d" % [cap, int(level)]
		if int(dur) < 1:
			return "broken items cannot be traded"
		if int(dur) > int(dur_max):
			return "durability above max"
	elif int(dur) != 0 or int(dur_max) != 0:
		return "%s has no durability" % def_id
	return ""

## A captured (untamed) animal's cage: CaptureSystem writes exactly species, variant,
## grade_seed and the wild genetics. The buyer still has to tame it in a pen.
func _cage(attrs: Dictionary) -> String:
	for k in attrs:
		if str(k) not in ["species", "variant", "grade_seed", "genetics"]:
			return "attribute %s not allowed on a cage" % str(k)
	var species_v: Variant = attrs.get("species")
	var def := cat.creature(str(species_v)) if species_v is String else null
	if def == null:
		return "unknown species %s" % str(species_v)
	var variant_v: Variant = attrs.get("variant", "")
	if not variant_v is String or (variant_v != "" and StringName(variant_v) not in def.variants):
		return "%s has no variant %s" % [str(species_v), str(variant_v)]
	if EconArgs.as_int(attrs.get("grade_seed", 0)) == null:
		return "grade_seed must be an integer"
	var genes := _genetics(attrs.get("genetics"), 1)
	return str(genes.get("msg", ""))

## "" or why `v` breaks the limits.json rule `table`.`key` (attributes, instance_fields).
func _rule(table: String, key: String, v: Variant) -> String:
	var spec: Variant = (rules.g(table) as Dictionary).get(key)
	if key.begins_with("_") or not spec is Dictionary:
		return "attribute %s not allowed" % key
	match str(spec.get("type", "")):
		"text":
			if not v is String or (v as String).length() > int(spec.get("max", 0)):
				return "%s must be text of at most %d characters" % [key, int(spec.get("max", 0))]
		"color":
			var t := str(v)
			if not (v is String) or not (t.length() == 7 or t.length() == 9) or not t.begins_with("#") or not _hex_digits(t.substr(1)):
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
		"steps":
			# A processing history: known step ids, at most `max`. Repeats stay legal (spec 08's steam-steam is open).
			var known: Array = spec.get("values", [])
			if not v is Array or (v as Array).size() > int(spec.get("max", 0)) or not (v as Array).all(func (s: Variant) -> bool: return s is String and s in known):
				return "attribute %s value not allowed" % key
		_:
			return "attribute %s has no rule" % key
	return ""

## "" or why the pet is refused. Stats must match PetStats.compute for its species, level and
## genetics; grade and the grade rates must be the ones its genetics give.
func pet(raw: Variant) -> String:
	if not raw is Dictionary:
		return "pet_dict must be an object"
	var d: Dictionary = raw
	for k in d:
		if str(k) not in PET_KEYS:
			return "unknown pet field %s" % str(k)
	var species_v: Variant = d.get("species")
	var def := cat.creature(str(species_v)) if species_v is String else null
	if def == null:
		return "unknown species %s" % str(species_v)
	var species := str(species_v)
	var variant_v: Variant = d.get("variant", "")
	# Spawners only ever use "" or a variant the creature def lists.
	if not variant_v is String or (variant_v != "" and StringName(variant_v) not in def.variants):
		return "%s has no variant %s" % [species, str(variant_v)]
	var summoned: Variant = d.get("summoned", false)
	if not summoned is bool:
		summoned = EconArgs.as_int(summoned)
		if summoned == null or int(summoned) not in [0, 1]:
			return "summoned must be true or false"
		summoned = int(summoned) == 1
	if summoned:
		return "dismiss the pet before depositing it"
	for k in ["owner", "tamer", "name", "grade"]:
		if d.has(k) and not d[k] is String:
			return "%s must be a string" % k
	if str(d.get("name", "")).length() > PetRecord.NAME_MAX:
		return "name longer than %d" % PetRecord.NAME_MAX
	var parents: Variant = d.get("parent_uids", [])
	if not parents is Array or (parents as Array).size() > 2 or (parents as Array).any(func (p: Variant) -> bool: return not p is String):
		return "parent_uids must be up to two uids"
	if d.has("tamed_role") and (not d.tamed_role is Array or (d.tamed_role as Array).any(func (r: Variant) -> bool: return not r is String)):
		return "tamed_role must be a list of names"
	var level: Variant = EconArgs.as_int(d.get("level", 1))
	if level == null or int(level) < 1 or int(level) > rules.num("level_max"):
		return "pet level must be 1..%d" % rules.num("level_max")
	var lv := int(level)
	for k in ["tamed_at", "wild_level"]:
		var n: Variant = EconArgs.as_int(d.get(k, 1))
		if n == null or int(n) < 0 or (k == "wild_level" and int(n) > rules.num("level_max")):
			return "%s out of range" % k
	var bag: Variant = d.get("bag", [])
	if not bag is Array:
		return "bag must be an array"
	for slot in bag:
		if slot != null:
			return "empty the pet bag before depositing it"
	var genes := _genetics(d.get("genetics"), lv)
	if genes.has("msg"):
		return genes.msg
	var g := CreatureGenetics.from_dict(genes)
	var tol := float(rules.g("pet_stat_tolerance"))
	var want := PetStats.compute(def, g, lv)
	for stat: String in GENE:
		var have: Variant = d.get(stat)
		var w: float = want[StringName(GENE[stat])]
		if not (have is float or have is int) or not is_finite(float(have)) or absf(float(have) - w) > tol * absf(w) + 0.000001:
			return "%s %s does not match species, level and genetics (%.3f)" % [stat, str(have), w]
	var grade := g.overall_tier()
	if str(d.get("grade", grade)) != str(grade):
		return "grade must be %s" % grade
	var rate := PetStats.grade_rate(grade)
	for k in ["hunger_efficiency", "xp_rate"]:
		var v: Variant = d.get(k, rate)
		if not (v is float or v is int) or absf(float(v) - rate) > 0.000001:
			return "%s must be %.2f for grade %s" % [k, rate, grade]
	var hunger_max := def.hp * 0.4
	for k in ["hunger", "hunger_max"]:
		var v: Variant = d.get(k, 0.0)
		if not (v is float or v is int) or float(v) < 0.0 or float(v) > hunger_max * (1.0 + tol):
			return "%s out of range" % k
	var hp_now: Variant = d.get("hp_now", -1.0)
	if not (hp_now is float or hp_now is int) or float(hp_now) < -1.0 or float(hp_now) > float(d.hp) * (1.0 + tol):
		return "hp_now out of range"
	var xp: Variant = d.get("xp", 0.0)
	var xp_cap := PetRecord.xp_to_next(lv) if lv < rules.num("level_max") else 1.0e9
	if not (xp is float or xp is int) or float(xp) < 0.0 or float(xp) >= xp_cap:
		return "xp out of range"
	var respawn: Variant = d.get("respawn_left", 0.0)
	if not (respawn is float or respawn is int) or float(respawn) < 0.0 or float(respawn) > PetRecord.RESPAWN_TIME:
		return "respawn_left out of range"
	return ""

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

static func _no(msg: String) -> Dictionary:
	return {"msg": msg}

## Exactly [0-9a-fA-F]+ (String.is_valid_hex_number also takes a sign and a 0x prefix).
static func _hex_digits(t: String) -> bool:
	for ch in t:
		if ch not in "0123456789abcdefABCDEF":
			return false
	return true
