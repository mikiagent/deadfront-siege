class_name BuildingQuality
extends RefCounted
## Construction quality (owner's spec 10 §§2-3, 6): a finished building's LEVEL comes from the exact
## material instances that went into it, and the PRIMARY material's traits pass to the building,
## where only the traits the blueprint lists in supported_building_effects do anything.
##
## Spec 10 §2 formula (also spec 30 §9): avg = floor(mean of the level-contributing instances),
## level = min(clamp(avg, blueprint_min, blueprint_max), Construction category level).
## # ASSUMPTION: where the spec is silent, a blueprint with no level-contributing instances gets
## level 1, and the traits of the first primary unit are the building's traits (the primary material
## only, never a binding/secondary one).
##
## The per-level effect amounts live in data/structures.json "quality" (reconstruction reference
## values from spec 10 §3: +3 container spaces per Lightweight level, +2 durability per High Density
## level, mirrored for the negative traits; 5 % shorter processing per rare level, +1 job slot).

const DEFS := "res://data/structures.json"

## One entry per level-contributing unit of the exact instances, in slot order.
## `slots` are the blueprint's material_slots rows (structures.json / blueprints.json shape);
## `taken` is the same slot order, each an Array[ItemStack].
static func contributing_levels(slots: Array, taken: Array) -> Array[int]:
	var out: Array[int] = []
	for i in slots.size():
		var row: Dictionary = slots[i] if slots[i] is Dictionary else {}
		if not _contributes_level(row):
			continue
		var col: Array = taken[i] if i < taken.size() and taken[i] is Array else []
		for s: ItemStack in col:
			if s == null:
				continue
			for _n in maxi(1, s.count):
				out.append(maxi(1, s.level))
	return out

## Spec 10 §2: floor(mean), clamped to the blueprint's range and capped by Construction.
static func level(levels: Array, lo: int = 1, hi: int = 60, construction_level: int = 60) -> int:
	if levels.is_empty():
		return 1
	var total := 0
	for l: Variant in levels:
		total += maxi(1, int(l))
	var avg := floori(float(total) / float(levels.size()))
	return mini(clampi(avg, maxi(1, lo), maxi(1, hi)), maxi(1, construction_level))

## The same level for a blueprints.json row (level_min/level_max), through the one engine that
## already computes it (Blueprint.result_level), so a preview can never disagree with the result.
static func level_for_blueprint(bp: Dictionary, levels: Array, construction_level: int) -> int:
	return Blueprints.result_level(bp, levels, construction_level)

## The traits the primary material passes on: [{id, level}], from the first unit of the first
## primary/main slot that carries any trait. Empty when no primary instance has one.
static func primary_traits(slots: Array, taken: Array) -> Array:
	for i in slots.size():
		var row: Dictionary = slots[i] if slots[i] is Dictionary else {}
		if not _is_primary(row):
			continue
		var col: Array = taken[i] if i < taken.size() and taken[i] is Array else []
		for s: ItemStack in col:
			if s == null:
				continue
			var tr := Inventory.traits(s)
			if not tr.is_empty():
				return attribute_rows(tr)
	return []

## [{id, level}] from an attribute dictionary, positive points only (a negative/zero point is a
## missing trait, as Inventory.traits and _points already treat it), in a stable key order.
static func attribute_rows(attrs: Dictionary) -> Array:
	var keys: Array = attrs.keys()
	keys.sort()
	var out: Array = []
	for k: Variant in keys:
		var v: Variant = attrs[k]
		if not (v is int or v is float):
			continue
		var lv := int(v)
		if lv <= 0:
			continue
		out.append({"id": str(k), "level": lv})
	return out

static func _contributes_level(row: Dictionary) -> bool:
	if row.has("level_contributing"):
		return bool(row["level_contributing"])
	if row.has("counts_for_level"):
		return bool(row["counts_for_level"])
	return _is_primary(row)

static func _is_primary(row: Dictionary) -> bool:
	var role := str(row.get("role", "main"))
	return role == "primary" or role == "main"

## What the inherited traits DO to a building (spec 10 §3 table, amounts from structures.json
## "quality"). `supported` is the blueprint's supported_building_effects: a trait whose effect the
## blueprint does not support is carried and shown but never applied (a wall gains no storage
## spaces from Lightweight). A station also gets the rare station effects (shorter jobs, a job slot).
## Returns {durability: int, storage_space: int, duration_mult: float, slots: int, carried: Array}.
static func effects(supported: Array, attrs: Array, station: bool = false) -> Dictionary:
	var out := {"durability": 0, "storage_space": 0, "duration_mult": 1.0, "slots": 0, "carried": [], "applied": []}
	var table: Dictionary = _quality().get("attributes", {}) as Dictionary
	var rare: Dictionary = _quality().get("station_rare", {}) as Dictionary
	var can: Array[String] = []
	for s: Variant in supported:
		can.append(str(s))
	for row: Variant in attrs:
		if not row is Dictionary:
			continue
		var id := str((row as Dictionary).get("id", ""))
		var lv := int((row as Dictionary).get("level", 0))
		if lv <= 0:
			continue
		# A rare trait's station bonus is separate from the ordinary property table (spec 10 §3).
		if station and rare.has(id):
			var r: Dictionary = rare[id]
			match str(r.get("effect", "")):
				"duration":
					out["duration_mult"] = maxf(0.1, float(out["duration_mult"]) + float(r.get("per_level", 0.0)) * lv)
					out["applied"].append(id)
					continue
				"slots":
					out["slots"] = int(out["slots"]) + int(r.get("per_level", 0)) * lv
					out["applied"].append(id)
					continue
		var effect := str((table.get(id, {}) as Dictionary).get("effect", ""))
		if effect == "" or not (effect in can):
			out["carried"].append({"id": id, "level": lv, "effect": effect if effect != "" else "carried"})
			continue
		match effect:
			"durability", "storage_space":
				out[effect] = int(out[effect]) + lv * int((table[id] as Dictionary).get("per_level", 0))
				out["applied"].append(id)
			_:
				out["carried"].append({"id": id, "level": lv, "effect": effect})
	return out

## The effect rows a finished building shows in its card: what each inherited trait did, in plain
## words. A trait the blueprint does not support says so and is never given a number.
static func effect_lines(attrs: Array, eff: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var table: Dictionary = _quality().get("attributes", {}) as Dictionary
	var rare: Dictionary = _quality().get("station_rare", {}) as Dictionary
	var applied: Array = eff.get("applied", [])
	for row: Variant in attrs:
		if not row is Dictionary:
			continue
		var id := str((row as Dictionary).get("id", ""))
		var lv := int((row as Dictionary).get("level", 0))
		if lv <= 0:
			continue
		if not (id in applied):
			out.append("%s Lv %d (no effect here)" % [_label(id), lv])
			continue
		var effect := str((table.get(id, {}) as Dictionary).get("effect", ""))
		match effect:
			"durability":
				out.append("%s Lv %d: %+d durability" % [_label(id), lv, int(eff.get("durability", 0))])
			"storage_space":
				out.append("%s Lv %d: %+d spaces" % [_label(id), lv, int(eff.get("storage_space", 0))])
			"comfort":
				out.append("%s Lv %d: comfort" % [_label(id), lv])
			"antibiotic":
				out.append("%s Lv %d: antibiotic" % [_label(id), lv])
			"building_attack":
				out.append("%s Lv %d: building attack" % [_label(id), lv])
			_:
				var d := float(eff.get("duration_mult", 1.0))
				if rare.has(id) and not is_equal_approx(d, 1.0):
					out.append("%s Lv %d: %d%% faster jobs" % [_label(id), lv, int(round((1.0 - d) * 100.0))])
				elif rare.has(id) and int(eff.get("slots", 0)) != 0:
					out.append("%s Lv %d: %+d job slot" % [_label(id), lv, int(eff.get("slots", 0))])
				else:
					out.append("%s Lv %d" % [_label(id), lv])
	return out

## "Lv 12 · High Density 3, Firm 3": the one line the structure card and the station share.
static func summary(level: int, attrs: Array) -> String:
	var text := "Lv %d" % maxi(1, level)
	var names := PackedStringArray()
	for row: Variant in attrs:
		if row is Dictionary:
			names.append("%s %d" % [_label(str((row as Dictionary).get("id", ""))), int((row as Dictionary).get("level", 0))])
	if not names.is_empty():
		text += " · " + ", ".join(names)
	return text

## The trait's player-facing name from inv_ui.json attribute_classes, else its title.
static func _label(id: String) -> String:
	var rows: Variant = _inv_ui().get("attribute_classes", {})
	if rows is Dictionary and (rows as Dictionary).has(id):
		return str(((rows as Dictionary)[id] as Dictionary).get("label", id.capitalize()))
	return id.replace("_", " ").capitalize()

static var _defs: Dictionary = {}
static var _ui: Dictionary = {}

static func _quality() -> Dictionary:
	if _defs.is_empty():
		_defs = _json(DEFS)
	return _defs.get("quality", {}) as Dictionary

static func _inv_ui() -> Dictionary:
	if _ui.is_empty():
		_ui = _json("res://data/inv_ui.json")
	return _ui

static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}

## A blueprint's supported_building_effects as strings (missing = none, so nothing applies).
static func supported(bp: Dictionary) -> Array:
	var v: Variant = bp.get("supported_building_effects", [])
	return v as Array if v is Array else []

## [{id, level}] rows only, ids and levels clamped: a save file may carry anything.
static func clean_attrs(v: Variant) -> Array:
	var out: Array = []
	if not v is Array:
		return out
	for row: Variant in v:
		if not row is Dictionary:
			continue
		var id := str((row as Dictionary).get("id", "")).strip_edges().left(40)
		var lv: Variant = (row as Dictionary).get("level", 0)
		if id == "" or not (lv is int or lv is float):
			continue
		out.append({"id": id, "level": clampi(int(lv), 0, 60)})
	return out
