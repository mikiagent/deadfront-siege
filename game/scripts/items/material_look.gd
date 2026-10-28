class_name MaterialLook
extends RefCounted
## Spec 35 package 1 (material appearance): what a piece of wood LOOKS like, kept apart from what
## it is worth. A `look` is {species, color, family, grain}, rolled once when a tree is harvested
## from the tree kind's wood species (data/materials/wood_species.json) with a small per-log jitter.
##
## Appearance is a separate data dimension: nothing here reads or writes level, rarity, traits or
## value, and nothing that computes those may read `look` (spec 35 §3). Crafted tinting, building
## inheritance and the inspect UI are later packages and are not built here.

const SPECIES_PATH := "res://data/materials/wood_species.json"
## The exact keys a look carries. Anything else is a malformed look.
const KEYS: Array[String] = ["species", "color", "family", "grain"]
## Allowance for hex rounding when a validated colour is checked against its species range.
const HUE_TOLERANCE_DEG := 1.5
const VALUE_TOLERANCE := 0.01

static var _table: Dictionary = {}

## The species file, parsed once. Empty when it cannot be read: every lookup then answers "".
static func table() -> Dictionary:
	if _table.is_empty():
		var f := FileAccess.open(SPECIES_PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_table = parsed if parsed is Dictionary else {}
	return _table

## One species row, or {} for an unknown id.
static func species(id: String) -> Dictionary:
	var rows: Variant = table().get("species", {})
	if rows is Dictionary:
		var row: Variant = (rows as Dictionary).get(id)
		if row is Dictionary:
			return row
	return {}

static func species_ids() -> PackedStringArray:
	var out := PackedStringArray()
	var rows: Variant = table().get("species", {})
	if rows is Dictionary:
		for id: Variant in (rows as Dictionary).keys():
			out.append(str(id))
	out.sort()
	return out

static func default_species() -> String:
	var id := str(table().get("default_species", ""))
	return id if not species(id).is_empty() else ""

## Every tree kind the manifest and the species file claim, as the file maps it.
static func tree_kinds() -> Dictionary:
	var map: Variant = table().get("tree_kinds", {})
	return map if map is Dictionary else {}

## The species a tree kind yields in a climate: "" when the kind is not a mapped tree.
## ASSUMPTION (spec 35 package 1): one species per kind today; climate_overrides is honoured so a
## later package can split a kind by climate without code changes.
static func species_for(family: String, climate: String = "") -> String:
	var t := table()
	var over: Variant = t.get("climate_overrides", {})
	if over is Dictionary:
		var per_kind: Variant = (over as Dictionary).get(family, {})
		if per_kind is Dictionary:
			var pick := str((per_kind as Dictionary).get(climate, ""))
			if not species(pick).is_empty():
				return pick
	var mapped := str(tree_kinds().get(family, ""))
	return mapped if not species(mapped).is_empty() else ""

## True for an item the tree harvest path can drop as wood (the def's "wood" category: logs,
## branch, planks). Stone, fibre, bark and fruit are not wood and never carry a look.
static func is_wood_item(def_id: StringName) -> bool:
	var def: ItemDef = Data.item(def_id) if Data != null else null
	return def != null and def.has_category(&"wood")

## The look of one log from `family` in `climate`, its colour jittered by `seed_value`.
## {} when the tree kind has no species (nothing to stamp).
static func look_for(family: String, climate: String, seed_value: int) -> Dictionary:
	return look_for_species(species_for(family, climate), seed_value)

## The look of one log of `id`, its colour jittered by `seed_value`: deterministic per seed.
static func look_for_species(id: String, seed_value: int) -> Dictionary:
	var row := species(id)
	if row.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var variation: Variant = row.get("variation", {})
	var color := _jitter(str(row.get("color", "#000000")), variation if variation is Dictionary else {}, rng)
	return {
		"species": id,
		"color": color,
		"family": str(row.get("family", "")),
		"grain": str(row.get("grain", "")),
	}

## Stamps `s` with the look of the tree kind it came from. Returns true when it stamped.
## A stack from a non-wood yield (fibre, fruit, bark, stone) or an unmapped kind keeps no look.
static func stamp(s: ItemStack, family: String, climate: String, seed_value: int) -> bool:
	if s == null or not is_wood_item(s.def_id):
		return false
	var look := look_for(family, climate, seed_value)
	if look.is_empty():
		return false
	s.look = look
	return true

## "" when `look` is absent or well formed, else why it was refused. This is the one gate saves,
## the server and the economy check a look against (spec 35 §1: a species' colour identity is
## fixed; a log may only sit inside its species' jitter range).
static func validate(look: Variant) -> String:
	if look == null:
		return ""
	if not look is Dictionary:
		return "look must be an object"
	var d: Dictionary = look
	if d.is_empty():
		return "look must not be empty"
	for k: Variant in d:
		if str(k) not in KEYS:
			return "look field %s not allowed" % str(k)
	for k in KEYS:
		if not d.has(k):
			return "look is missing %s" % k
	var id := str(d.get("species", ""))
	var row := species(id)
	if row.is_empty():
		return "unknown wood species %s" % id
	if str(d.get("family", "")) != str(row.get("family", "")):
		return "look family %s does not belong to %s" % [str(d.get("family", "")), id]
	if str(d.get("grain", "")) != str(row.get("grain", "")):
		return "look grain %s does not belong to %s" % [str(d.get("grain", "")), id]
	var hex := str(d.get("color", ""))
	if hex.length() != 7 or not hex.begins_with("#") or not _hex(hex.substr(1)):
		return "look color must be #rrggbb"
	return _range_why(id, row, Color(hex))

## A look as it may be stored: a valid one kept as is, anything else dropped ({}). Used by save
## loads so a hand-edited row can never inject an appearance outside the species palette.
static func sanitize(look: Variant) -> Dictionary:
	if validate(look) != "":
		return {}
	return (look as Dictionary).duplicate(true)

## "The look of a wood item that carries none": the default species, unjittered base colour.
## Used only where a caller must show a swatch; never written into a save (old rows stay as saved).
static func default_look() -> Dictionary:
	return look_for_species(default_species(), 0)

# --- internals ---------------------------------------------------------------------------

## Base colour, hue shifted inside the species range and value nudged: two logs of one species
## read as the same wood, never as two woods.
static func _jitter(base_hex: String, variation: Dictionary, rng: RandomNumberGenerator) -> String:
	var base := Color(base_hex)
	var hue_pair: Array = _pair(variation.get("hue_deg"), 0.0)
	var val_pair: Array = _pair(variation.get("value"), 0.0)
	var dh := rng.randf_range(float(hue_pair[0]), float(hue_pair[1])) / 360.0
	var dv := rng.randf_range(float(val_pair[0]), float(val_pair[1]))
	var c := Color.from_hsv(fposmod(base.h + dh, 1.0), base.s, clampf(base.v + dv, 0.02, 1.0))
	return "#" + c.to_html(false)

## `[min, max]` from a JSON pair, falling back to the same value twice.
static func _pair(raw: Variant, fallback: float) -> Array:
	if raw is Array and (raw as Array).size() >= 2:
		return [float((raw as Array)[0]), float((raw as Array)[1])]
	return [fallback, fallback]

## "" when `c` sits inside the species' jitter range (plus rounding tolerance), else why not.
static func _range_why(id: String, row: Dictionary, c: Color) -> String:
	var base := Color(str(row.get("color", "#000000")))
	var variation: Variant = row.get("variation", {})
	var v: Dictionary = variation if variation is Dictionary else {}
	var hue_pair: Array = _pair(v.get("hue_deg"), 0.0)
	var val_pair: Array = _pair(v.get("value"), 0.0)
	var reach := maxf(absf(float(hue_pair[0])), absf(float(hue_pair[1]))) + HUE_TOLERANCE_DEG
	if _hue_delta_deg(base.h, c.h) > reach:
		return "look color %s is outside %s's hue range" % [c.to_html(false), id]
	var lo := minf(float(val_pair[0]), float(val_pair[1])) - VALUE_TOLERANCE
	var hi := maxf(float(val_pair[0]), float(val_pair[1])) + VALUE_TOLERANCE
	var dv := c.v - base.v
	if dv < lo or dv > hi:
		return "look color %s is outside %s's value range" % [c.to_html(false), id]
	return ""

## Signed hue distance in degrees, the short way around the wheel.
static func _hue_delta_deg(a: float, b: float) -> float:
	var d := fposmod(b - a + 0.5, 1.0) - 0.5
	return d * 360.0

static func _hex(s: String) -> bool:
	for ch in s:
		if ch not in "0123456789abcdefABCDEF":
			return false
	return true
