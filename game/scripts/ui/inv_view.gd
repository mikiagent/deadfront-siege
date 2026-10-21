class_name InvView
extends RefCounted
## Sorting and filtering for the bag family (spec 13 s9, s12): returns the bag slots to show, in
## order. Presentation only: it never moves, merges or edits an instance.

const DATA := "res://data/inv_ui.json"

static var _data: Dictionary = {}

## data/inv_ui.json, parsed once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
		_data = parsed if parsed is Dictionary else {"sort_keys": ["acquired"], "filters": [{"id": "all", "label": "All", "categories": []}]}
	return _data

static func sort_keys() -> Array:
	return data().get("sort_keys", ["acquired"])

static func sort_label(key: StringName) -> String:
	return str((data().get("sort_labels", {}) as Dictionary).get(str(key), str(key).capitalize()))

static func filters() -> Array:
	return data().get("filters", [])

static func filter_label(id: StringName) -> String:
	for f: Dictionary in filters():
		if str(f.get("id", "")) == str(id):
			return str(f.get("label", id))
	return str(id).capitalize()

## Lead slot indices (span rows excluded) that pass `filter`, ordered by `key`. Ties keep bag order,
## so a sort is stable and repeatable.
static func order(inv: Inventory, key: StringName, filter: StringName) -> Array[int]:
	var out: Array[int] = []
	if inv == null:
		return out
	var rule := _filter(filter)
	for i in inv.slot_count:
		var s := inv.slots[i]
		if s != null and s.def_id != Inventory.LOCK and _passes(s, rule):
			out.append(i)
	if key == &"acquired" or key == &"":
		return out
	var rank := {}
	for i in out:
		rank[i] = _key(inv.slots[i], key)
	out.sort_custom(func(a: int, b: int) -> bool:
		var ka: Array = rank[a]
		var kb: Array = rank[b]
		return ka < kb if ka != kb else a < b)
	return out

static func _filter(id: StringName) -> Dictionary:
	for f: Dictionary in filters():
		if str(f.get("id", "")) == str(id):
			return f
	return {}

static func _passes(s: ItemStack, rule: Dictionary) -> bool:
	if rule.is_empty() or str(rule.get("id", "all")) == "all":
		return true
	match str(rule.get("rule", "")):
		"rare":
			return InvAttributes.has_rare(s)
		"locked":
			return s.is_locked()
	if (rule.get("ids", []) as Array).has(str(s.def_id)):
		return true
	var d := s.def()
	if d == null:
		return false
	for c in rule.get("categories", []):
		if d.has_category(StringName(str(c))):
			return true
	return false

## Ascending sort key per instance; "highest first" keys are negated.
static func _key(s: ItemStack, key: StringName) -> Array:
	var d := s.def()
	var name := d.display_name if d and d.display_name != "" else str(s.def_id)
	match key:
		&"name":
			return [name, -s.level]
		&"type":
			return [str(d.categories[0]) if d and not d.categories.is_empty() else "~", name, -s.level]
		&"level":
			return [-s.level, name]
		&"rarity":
			return [-ItemArt.rarity_order().find(str(ItemArt.rarity(s.def_id))), name, -s.level]
		&"attributes":
			var sec := InvAttributes.sections(s)
			var pos := 0
			for r: Dictionary in sec.positive:
				pos += int(r.level)
			return [-(sec.rare as Array).size(), -pos, name]
		&"durability":
			var frac := float(s.durability) / float(s.max_durability) if s.max_durability > 0 else 2.0
			return [frac, name]
	return [0]
