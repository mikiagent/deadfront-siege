class_name GearRepair
extends RefCounted
## P3 GEARREPAIR (docs/design/tools-durability-crafting.md 3.5): repair a worn or broken tool, weapon or
## armor piece at its tier's station (recipes.json "repairs": workbench for stone to obsidian, anvil for
## copper to steel). Cost: ceil(missing / (restore_fraction x max)) units of the tier material (a broken
## item 2, a half-worn one 1). Each repair refills the item and cuts its max to round(max x max_factor);
## the count lives in attributes["repairs"] (saves keep it with the item, old items read 0), and the
## repair past max_repairs is refused ("worn out").

static var _rows: Array = []
static var _rules: Dictionary = {}

static func _load() -> void:
	if not _rows.is_empty():
		return
	var f := FileAccess.open("res://data/recipes.json", FileAccess.READ)
	var root: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if root is Dictionary:
		_rows = (root as Dictionary).get("repairs", [])
		_rules = (root as Dictionary).get("repair_rules", {})

static func max_repairs() -> int:
	_load()
	return int(_rules.get("max_repairs", 4))  # ASSUMPTION: 4 repairs, 41 % of the first max

static func max_factor() -> float:
	_load()
	return float(_rules.get("max_factor", 0.8))  # ASSUMPTION: the research's one measured value

## The repairs row for this item's material tier ({} when none).
static func row_for(s: ItemStack) -> Dictionary:
	_load()
	var tier := str(s.material_tier())
	for r: Variant in _rows:
		if r is Dictionary and str((r as Dictionary).get("tier", "")) == tier:
			return r
	return {}

static func count(s: ItemStack) -> int:
	return int(s.attributes.get("repairs", 0))

static func station_of(s: ItemStack) -> StringName:
	return StringName(str(row_for(s).get("station", "")))

## The tier material slot: {"category", "count"} per restore step.
static func _slot(s: ItemStack) -> Dictionary:
	var slots: Array = row_for(s).get("slots", [])
	return slots[0] if not slots.is_empty() and slots[0] is Dictionary else {}

static func cost(s: ItemStack) -> int:
	var frac := float(row_for(s).get("restore_fraction", 0.5))
	var missing := s.max_durability - s.durability
	if missing <= 0 or s.max_durability <= 0:
		return 0
	return int(ceil(float(missing) / (frac * float(s.max_durability)) - 0.0001)) * int(_slot(s).get("count", 1))

static func material_label(s: ItemStack) -> String:
	var cat := str(_slot(s).get("category", ""))
	return "%s material" % (cat.trim_prefix("tier_").capitalize() if cat != "" else "tier")

## Why this item can't be repaired here ("" when it can). `station` is the station the survivor is at.
static func block_reason(s: ItemStack, inv: Inventory, station: StringName) -> String:
	if s == null or s.max_durability <= 0 or row_for(s).is_empty():
		return "can't be repaired"
	if s.durability >= s.max_durability:
		return "already at full durability"
	if count(s) >= max_repairs():
		return "worn out: repaired %d times" % count(s)
	var want := station_of(s)
	if station != want:
		return "repair at the %s" % str(want).replace("_", " ")
	var cat := StringName(str(_slot(s).get("category", "")))
	var have := 0
	for i in inv.find_by_category(cat):
		have += inv.slots[i].count
	if have < cost(s):
		return "needs %d %s" % [cost(s), material_label(s)]
	return ""

## Repair `s` from `inv`'s tier material at `station`. Returns "" on success, else the refusal.
static func repair(s: ItemStack, inv: Inventory, station: StringName) -> String:
	var why := block_reason(s, inv, station)
	if why != "":
		return why
	if not inv.consume_by_category(StringName(str(_slot(s).get("category", ""))), cost(s)):
		return "needs %d %s" % [cost(s), material_label(s)]
	s.max_durability = maxi(1, int(round(float(s.max_durability) * max_factor())))
	s.durability = s.max_durability
	s.attributes["repairs"] = count(s) + 1
	inv.changed.emit()
	print("[item] repaired %s -> max %d (repair %d of %d)" % [s.def_id, s.max_durability, count(s), max_repairs()])
	return ""

## The worn or broken gear a survivor carries or wears that could be repaired (any station).
static func damaged_in(inv: Inventory) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	var pool: Array = inv.slots.duplicate()
	for slot: StringName in [&"weapon", &"head", &"body", &"arms", &"legs"]:
		pool.append(inv.equipped_in(slot))
	for v: Variant in pool:
		var s := v as ItemStack
		if s and s not in out and s.max_durability > 0 and s.durability < s.max_durability and not row_for(s).is_empty():
			out.append(s)
	return out

## Tooltip: "Repair at Workbench: 2 Stone material · max 50 -> 40 (repair 1 of 4)".
static func text(s: ItemStack) -> String:
	return " · ".join(lines(s))

## The same as card rows (one fact per line): where and for what, then the max it leaves.
static func lines(s: ItemStack) -> PackedStringArray:
	if s == null or s.max_durability <= 0 or row_for(s).is_empty():
		return PackedStringArray(["Repair: Not Possible"])
	var n := count(s)
	if n >= max_repairs():
		return PackedStringArray(["Repair: worn out (repaired %d of %d)" % [n, max_repairs()]])
	var st := str(station_of(s)).replace("_", " ").capitalize()
	var nxt := maxi(1, int(round(float(s.max_durability) * max_factor())))
	var where := "Repair at %s when worn" % st if s.durability >= s.max_durability else "Repair at %s: %d %s" % [st, cost(s), material_label(s)]
	return PackedStringArray([where, "max %d -> %d (repair %d of %d)" % [s.max_durability, nxt, n + 1, max_repairs()]])
