class_name BagDef
extends RefCounted
## Bag definitions (owner spec 31, docs/design/durango-prompts/31_bag_levels_quality_and_capacity.md).
## data/bags.json holds the storage side of each bag type; data/items.json holds the item itself
## (categories accessory + bag, "bag_def": "<id here>"). A bag's level and its capacity bonus are
## different statistics: capacity comes from the type's level curve, never from the level number.
## HISTORICAL (spec 31 §1, §5, §15): base personal capacity 100; Pocket is +6 spaces per level.
## ASSUMPTION (spec 31 §15 allows it): every curve, storage_bonus and recipe is a new design value.

const PATH := "res://data/bags.json"
static var _rules: Dictionary = {}

## The whole file: {"pocket_slots_per_level", "max_pocket_level", "storage_attributes", "bags"}.
static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if not parsed is Dictionary:
			push_error("[bags] %s is unreadable: no bag type stores anything" % PATH)
			parsed = {"bags": {}, "storage_attributes": {}}
		_rules = parsed
	if not _rules.has("bags") or not _rules["bags"] is Dictionary:
		_rules["bags"] = {}
	return _rules

static func all() -> Dictionary:
	return rules().get("bags", {}) as Dictionary

## The definition of a bag type id, or {} when the id is not a bag type.
static func def_for(id: StringName) -> Dictionary:
	var b: Variant = all().get(str(id), {})
	return b as Dictionary if b is Dictionary else {}

## The bag type an item definition belongs to (its "bag_def" row), or "" for ordinary gear.
static func id_of(def: ItemDef) -> StringName:
	if def == null:
		return &""
	var id := StringName(str(def.bag_def))
	return id if not def_for(id).is_empty() else &""

static func is_bag(id: StringName) -> bool:
	return not def_for(id).is_empty()

static func pocket_slots_per_level() -> int:
	return maxi(0, int(rules().get("pocket_slots_per_level", 6)))

static func max_pocket_level() -> int:
	return maxi(0, int(rules().get("max_pocket_level", 60)))

## Every storage attribute key known to the system -> {"slots_per_point": n}.
static func storage_attributes() -> Dictionary:
	var v: Variant = rules().get("storage_attributes", {})
	return v as Dictionary if v is Dictionary else {}

## Spaces one point of `key` is worth (0 when the key is not a storage attribute).
static func slots_per_point(key: String) -> int:
	var row: Variant = storage_attributes().get(key, null)
	if row is Dictionary:
		return maxi(0, int((row as Dictionary).get("slots_per_point", 0)))
	return 0

## The capacity table of a bag type: [[level, base], ...], sorted by level.
static func curve(id: StringName) -> Array:
	var d := def_for(id)
	var rows: Array = []
	for row: Variant in (d.get("capacity_curve", []) as Array):
		if row is Array and (row as Array).size() >= 2:
			rows.append([maxi(1, int(row[0])), maxi(0, int(row[1]))])
	rows.sort_custom(func (a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return rows

## The type's own base capacity at `level`: linear between table rows, clamped at both ends.
static func base_capacity(id: StringName, level: int) -> int:
	var rows := curve(id)
	if rows.is_empty():
		return 0
	var lv := maxi(1, level)
	if lv <= int(rows[0][0]):
		return int(rows[0][1])
	if lv >= int(rows[rows.size() - 1][0]):
		return int(rows[rows.size() - 1][1])
	for i in range(1, rows.size()):
		var hi: Array = rows[i]
		if lv > int(hi[0]):
			continue
		var lo: Array = rows[i - 1]
		var span := maxi(1, int(hi[0]) - int(lo[0]))
		var t := float(lv - int(lo[0])) / float(span)
		return int(floor(float(lo[1]) + (float(hi[1]) - float(lo[1])) * t))
	return int(rows[rows.size() - 1][1])

## A flat bonus the bag type adds on top of its curve (0 for most).
static func storage_bonus(id: StringName) -> int:
	return maxi(0, int(def_for(id).get("storage_bonus", 0)))

## The storage attributes this bag type may inherit from its primary material.
static func inheritable(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in (def_for(id).get("inheritable", []) as Array):
		out.append(StringName(str(k)))
	return out

static func can_inherit(id: StringName, key: StringName) -> bool:
	return key in inheritable(id)

## The equip slot name the bag type declares ("accessory1" here: bags wear in a ring slot).
static func slot(id: StringName) -> StringName:
	return StringName(str(def_for(id).get("slot", "")))

static func min_craft_level(id: StringName) -> int:
	return maxi(0, int(def_for(id).get("min_craft_level", 0)))

static func recipe_id(id: StringName) -> StringName:
	return StringName(str(def_for(id).get("recipe", "")))

## Every bag type id, in data order.
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in all():
		out.append(StringName(str(k)))
	return out
