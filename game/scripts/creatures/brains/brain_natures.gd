class_name CreatureNatures
extends RefCounted
## Creature natures (owner 2026-10-28): a temperament that changes AI behaviour and shows as a
## prefix on the animal's name ("Timid Velociraptor"). Natures LAYER ON TOP of the ai.json
## archetypes and temperaments: they only supply multipliers the brains already read, so a nature
## row starts from `default` (every knob neutral) and an animal with no nature behaves as before.
##
## The table lives in data/creatures/natures.json and is read here directly (no autoload), cached
## once per run. A nature is rolled ONCE per animal, from a seed (species + spawn point + pack), and
## kept when the animal is tamed (PetRecord.nature). An old pet record without one derives the same
## nature from its uid every load.

const PATH := "res://data/creatures/natures.json"
## The table ships six natures; this is the fallback list when the file is missing or broken.
const FALLBACK: Array[StringName] = [&"timid", &"brave", &"aggressive", &"loyal", &"stubborn", &"docile"]

static var _table: Dictionary = {}
static var _knobs: Dictionary = {} ## nature id -> default merged with its row (read-only to callers)

static func table() -> Dictionary:
	if _table.is_empty():
		var parsed: Variant = null
		if FileAccess.file_exists(PATH):
			var f := FileAccess.open(PATH, FileAccess.READ)
			if f != null:
				parsed = JSON.parse_string(f.get_as_text())
		_table = parsed if parsed is Dictionary else {}
	return _table

static func nature_rows() -> Dictionary:
	var rows: Variant = table().get("natures", {})
	return rows if rows is Dictionary else {}

## Every nature id in the table, in file order (falls back to FALLBACK).
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in nature_rows().keys():
		out.append(StringName(str(id)))
	return out if not out.is_empty() else FALLBACK.duplicate()

static func has(nature: StringName) -> bool:
	return nature_rows().has(str(nature))

static func is_valid(nature: StringName) -> bool:
	return has(nature)

## The knobs a brain reads for this nature: `default` (all neutral) merged with the nature's row.
## Returns a shared read-only dictionary, so brains must not write into it.
static func knobs(nature: StringName) -> Dictionary:
	var key := str(nature)
	if _knobs.has(key):
		return _knobs[key]
	var out: Dictionary = (table().get("default", {}) as Dictionary).duplicate()
	var row: Variant = nature_rows().get(key, {})
	if row is Dictionary:
		out.merge(row as Dictionary, true)
	out.erase("never")
	out.erase("only")
	out.erase("_about")
	_knobs[key] = out
	return out

## "Timid" for the id "timid". Empty id = "" (no nature, no prefix).
static func label(nature: StringName) -> String:
	if nature == &"":
		return ""
	var row: Variant = nature_rows().get(str(nature), {})
	var want := str((row as Dictionary).get("label", "")) if row is Dictionary else ""
	return want if want != "" else str(nature).capitalize()

## Natures this archetype may roll: a row with "only" is limited to those archetypes, a row with
## "never" excludes them. ASSUMPTION (natures.json): a T. rex is never Timid, and grazers roll
## Aggressive only rarely (weight x rarity_weight_mult, see rarity_weight_for).
static func allowed_for(archetype: StringName) -> Array[StringName]:
	var arch := str(archetype)
	var out: Array[StringName] = []
	for id in ids():
		var row: Variant = nature_rows().get(str(id), {})
		if not row is Dictionary:
			out.append(id)
			continue
		var only: Variant = (row as Dictionary).get("only", [])
		var never: Variant = (row as Dictionary).get("never", [])
		if only is Array and not (only as Array).is_empty() and not (arch in _strs(only as Array)):
			continue
		if never is Array and arch in _strs(never as Array):
			continue
		out.append(id)
	return out

## Weight of a nature for this archetype: its weight from natures.json, times rarity_weight_mult
## when the archetype sits in the row's "rare_for".
static func weight_for(nature: StringName, archetype: StringName) -> float:
	var weights: Dictionary = table().get("weights", {})
	var w := maxf(0.0, float(weights.get(str(nature), 1.0)))
	var row: Variant = nature_rows().get(str(nature), {})
	if row is Dictionary:
		var rare: Variant = (row as Dictionary).get("rare_for", [])
		if rare is Array and str(archetype) in _strs(rare as Array):
			w *= float((table().get("_masking", {}) as Dictionary).get("rarity_weight_mult", 0.1))
	return w

static func _strs(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for r in rows:
		out.append(str(r))
	return out

## Weighted roll over the natures this archetype may have. Deterministic for a seed key.
static func roll(seed_key: String, archetype: StringName = &"") -> StringName:
	var ok := allowed_for(archetype)
	if ok.is_empty():
		return &""
	var total := 0.0
	for id in ok:
		total += weight_for(id, archetype)
	if total <= 0.0:
		return ok[0]
	var rng := _rng(seed_key)
	var pick := rng.randf() * total
	for id in ok:
		pick -= weight_for(id, archetype)
		if pick <= 0.0:
			return id
	return ok[ok.size() - 1]

## The seed of a wild animal's nature: species, rounded spawn point and the pack it spawned with.
## Same shape as Creature.spawn_colour_key, so a reload at the same spot rolls the same nature.
static func spawn_key(species: StringName, at: Vector3, pack: int) -> String:
	return "nature:%s@%d,%d,%d#%d" % [species, roundi(at.x), roundi(at.y), roundi(at.z), pack]

## Nature for a pet saved without one: derived from its uid (stable), so every load agrees. The
## caller passes the species' archetype when it knows it (PetRecord.from_dict asks Data); this file
## never names an autoload, so it compiles before they exist (the server handlers load it at boot).
static func from_uid(uid: String, species: StringName = &"", archetype: StringName = &"") -> StringName:
	return roll("uid:" + uid + "@" + str(species), archetype)

## Seeded RNG shared with the colour roll's rule: PCG's first draws are weak right after seeding,
## so warm it up before anything reads it.
static func _rng(key: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _fnv1a(key)
	for _i in 4:
		rng.randf()
	return rng

## 64-bit FNV-1a (same rule as CreatureColoration.fnv1a: String.hash() is not stable across runs).
static func _fnv1a(text: String) -> int:
	var h: int = -3750763034362895579
	for i in text.length():
		h = (h ^ int(text.unicode_at(i))) * 1099511628211
	return h

## The word a variant id adds to the name: "velociraptor_crested" -> "Crested" (species prefix
## dropped), "" for none.
static func variant_word(variant: StringName, species: StringName) -> String:
	var v := str(variant)
	if v == "":
		return ""
	var sp := str(species)
	if sp != "" and v.begins_with(sp + "_"):
		v = v.substr(sp.length() + 1)
	return v.replace("_", " ").capitalize()

## "Brave Alpha Velociraptor": nature, then variant (an Alpha pack leader included), then species.
static func display_name(nature: StringName, variant_label: String, species_text: String) -> String:
	var parts: PackedStringArray = []
	var nat := label(nature)
	if nat != "":
		parts.append(nat)
	if variant_label != "":
		parts.append(variant_label)
	if species_text != "":
		parts.append(species_text)
	return " ".join(parts)

## The full displayed name of a living animal (plate and screens): its nature, "Alpha" when it
## leads its pack, its colour variant when it has one, then the species.
static func display_title(c: Node) -> String:
	if c == null:
		return ""
	var def: CreatureDef = c.get("def")
	var species_text := str(def.species if def != null else "").capitalize()
	var words: Array[String] = []
	if _is_pack_alpha(c):
		words.append("Alpha")
	var vw := variant_word(StringName(str(c.get("variant"))), def.id if def != null else &"")
	if vw != "":
		words.append(vw)
	return display_name(c.call("nature_id"), " ".join(words), species_text)

static func _is_pack_alpha(c: Node) -> bool:
	if not c.has_method("nature_id"):
		return false
	var brain: Variant = c.get("brain")
	if brain == null or not (brain is Object) or not (brain as Object).has_method("_is_pack_leader"):
		return false
	return bool((brain as Object).call("_is_pack_leader"))
