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

static func butcher_cfg() -> Dictionary:
	return loot().get("butcher", {})

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
