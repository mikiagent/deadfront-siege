class_name LootTables
extends RefCounted
## Read-only access to game/data/loot_tables.json and gather_rules.json (W2-GATHER data).
## Loaded once on first use; no autoload.

const LOOT_PATH := "res://data/loot_tables.json"
const RULES_PATH := "res://data/gather_rules.json"

static var _loot: Dictionary = {}
static var _rules: Dictionary = {}

static func loot() -> Dictionary:
	if _loot.is_empty():
		_loot = _read(LOOT_PATH)
	return _loot

static func rules() -> Dictionary:
	if _rules.is_empty():
		_rules = _read(RULES_PATH)
	return _rules

static func gather_cfg() -> Dictionary:
	return loot().get("gather_rare", {})

static func trait_cfg() -> Dictionary:
	return loot().get("rare_trait", {})

## RAREATTR: the rare attributes one material can roll (spec 04:33, rare_trait.by_material), or the
## shared six when the item has no list of its own (a new harvest id before its data row lands).
static func material_traits(item_id: StringName) -> Array:
	var cfg := trait_cfg()
	var rows: Variant = cfg.get("by_material", {})
	var own: Variant = (rows as Dictionary).get(str(item_id), []) if rows is Dictionary else []
	if own is Array and not (own as Array).is_empty():
		return own as Array
	var all: Variant = cfg.get("traits", [])
	return all as Array if all is Array else []

## Every material that has its own list (the test walks these).
static func trait_materials() -> Dictionary:
	var rows: Variant = trait_cfg().get("by_material", {})
	return rows as Dictionary if rows is Dictionary else {}

## HARVESTROLL: one gathered lot's level band and signed-trait odds (loot_tables.json "lot").
static func lot_cfg() -> Dictionary:
	return loot().get("lot", {})

static func butcher_cfg() -> Dictionary:
	return loot().get("butcher", {})

## ALPHATAG: the alpha-only loot rows for a species (loot_tables.json "alpha"), its own list when it has
## one, else the shared default pool. An unknown species still gets the default pool.
static func alpha_pool(species: StringName) -> Array:
	var cfg: Variant = loot().get("alpha", {})
	if not cfg is Dictionary:
		return []
	var by: Variant = (cfg as Dictionary).get("by_species", {})
	var own: Variant = (by as Dictionary).get(str(species), null) if by is Dictionary else null
	if own is Array and not (own as Array).is_empty():
		return own as Array
	var pool: Variant = (cfg as Dictionary).get("pool", [])
	return pool as Array if pool is Array else []

## ALPHATAG: every alpha-only item id, across the default pool and every species override (the tests
## and the data walk use it to prove a normal carcass never yields one).
static func alpha_pool_ids() -> Array[StringName]:
	var cfg: Variant = loot().get("alpha", {})
	var out: Array[StringName] = []
	if not cfg is Dictionary:
		return out
	var rows: Array = []
	rows.append_array((cfg as Dictionary).get("pool", []))
	var by: Variant = (cfg as Dictionary).get("by_species", {})
	if by is Dictionary:
		for k: Variant in by:
			if (by as Dictionary)[k] is Array:
				rows.append_array((by as Dictionary)[k])
	for row: Variant in rows:
		if row is Dictionary and str((row as Dictionary).get("id", "")) != "":
			var id := StringName(str((row as Dictionary)["id"]))
			if id not in out:
				out.append(id)
	return out

## Rare rows for a node: its role's rows plus any family-specific rows.
static func gather_rare_rows(family: String, role: String) -> Array:
	var cfg := gather_cfg()
	var out: Array = []
	out.append_array(cfg.get("by_role", {}).get(role, []))
	out.append_array(cfg.get("by_family", {}).get(family, []))
	return out

## Tool class that speeds up work on a node role even when the node needs none.
static func affinity_tool(role: String) -> StringName:
	return StringName(str(rules().get("tool_affinity", {}).get(role, "")))

static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[gather] missing %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("[gather] bad json %s" % path)
	return {}
