extends Node
## Autoload Data. Loads item, status, creature and skill catalogs at boot.

var items: Dictionary = {} ## StringName -> ItemDef
var statuses: Dictionary = {} ## StringName -> StatusDef
var creatures: Dictionary = {} ## StringName -> CreatureDef
var anim_events: Dictionary = {}
var survival_nodes: Dictionary = {}
var survival_unlocked: Dictionary = {} ## node id -> bool. ASSUMPTION: no SP economy yet.
var recipes: Dictionary = {} ## StringName -> Dictionary
var recipe_list: Array = []
var butcher_tables: Dictionary = {} ## species String -> Dictionary
var nature_families: Dictionary = {}
var world_rules: Dictionary = {}
var world_climates: Dictionary = {}
var world_islands: Dictionary = {}
var props_manifest: Dictionary = {}
var creature_ai: Dictionary = {}

func _ready() -> void:
	_load_items("res://data/items.json")
	_load_statuses("res://data/statuses.json")
	_load_creatures("res://data/creatures")
	_load_anim_events("res://data/creatures/anim_events.json")
	_load_survival("res://data/skills/survival.json")
	_load_recipes("res://data/recipes.json")
	_load_butchering("res://data/butchering.json")
	_load_nature("res://data/nature_manifest.json")
	_load_world()
	_load_creature_ai("res://data/creatures/ai.json")
	print("[data] items=%d statuses=%d creatures=%d recipes=%d" % [
		items.size(), statuses.size(), creatures.size(), recipes.size()])

func item(id: StringName) -> ItemDef:
	return items.get(id) as ItemDef

func status(id: StringName) -> StatusDef:
	return statuses.get(id) as StatusDef

func creature(id: StringName) -> CreatureDef:
	return creatures.get(id) as CreatureDef

func is_survival_unlocked(node_id: StringName) -> bool:
	return bool(survival_unlocked.get(node_id, false))

func set_survival_unlocked(node_id: StringName, on: bool) -> void:
	survival_unlocked[node_id] = on

func bonded_cap() -> int:
	# Roster storage is unlimited; Player.MAX_PETS_OUT governs the three active companions.
	return 2147483647

func has_capture_technique(tier: int) -> bool:
	for id in survival_nodes:
		var n: Dictionary = survival_nodes[id]
		if str(n.get("kind", "")) == "capture_technique" and int(n.get("unlocks_capture_tier", 0)) == tier:
			return is_survival_unlocked(id)
	return false

func butchering_level() -> int:
	var lvl := 0
	for id in survival_nodes:
		var n: Dictionary = survival_nodes[id]
		if str(n.get("kind", "")) == "butchering" and is_survival_unlocked(id):
			lvl = maxi(lvl, int(n.get("tier", 1)))
	return lvl

func butcher_drops(species: StringName) -> Array:
	var table: Dictionary = butcher_tables.get(str(species), {})
	var out: Array = []
	for row in table.get("base", []):
		out.append(row)
	for row in table.get("rare", []):
		out.append(row)
	return out

func _load_items(path: String) -> void:
	var root := _parse_json(path)
	var arr: Array = root.get("items", [])
	for row in arr:
		if not row is Dictionary:
			_fail(path, "item row is not an object")
			return
		var def := ItemDef.from_dict(row)
		if def.id == &"":
			_fail(path, "item missing id")
			return
		items[def.id] = def

func _load_statuses(path: String) -> void:
	var root := _parse_json(path)
	var arr: Array = root.get("statuses", [])
	for row in arr:
		if not row is Dictionary:
			_fail(path, "status row is not an object")
			return
		var def := StatusDef.from_dict(row)
		if def.id == &"":
			_fail(path, "status missing id")
			return
		statuses[def.id] = def

func _load_creatures(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		_fail(dir, "cannot open creatures directory")
		return
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if not da.current_is_dir() and fname.ends_with(".json") and fname != "anim_events.json" and fname != "ai.json":
			var path := "%s/%s" % [dir, fname]
			var root := _parse_json(path)
			if not root.has("species"):
				_fail(path, "creature json missing species")
				fname = da.get_next()
				continue
			var id := StringName(fname.get_basename())
			creatures[id] = CreatureDef.from_dict(root, id)
		fname = da.get_next()
	da.list_dir_end()

func _load_anim_events(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	anim_events = _parse_json(path)

func _load_survival(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var root := _parse_json(path)
	for row in root.get("nodes", []):
		if row is Dictionary:
			var id := StringName(str(row.get("id", "")))
			survival_nodes[id] = row
			survival_unlocked[id] = false

func _load_recipes(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var root := _parse_json(path)
	recipe_list.clear()
	recipes.clear()
	for row in root.get("recipes", []):
		if not row is Dictionary:
			continue
		var id := StringName(str(row.get("id", "")))
		if id == &"":
			continue
		recipes[id] = row
		recipe_list.append(row)

func _load_butchering(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var root := _parse_json(path)
	var tables: Variant = root.get("species", {})
	if tables is Dictionary:
		butcher_tables = tables as Dictionary

func _load_nature(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var root := _parse_json(path)
	var fam: Variant = root.get("families", {})
	if fam is Dictionary:
		nature_families = fam as Dictionary

func _load_world() -> void:
	world_rules = _parse_json("res://data/world/rules.json")
	world_climates = _parse_json("res://data/world/climates.json")
	world_islands = _parse_json("res://data/world/islands.json")
	props_manifest = _parse_json("res://data/props_manifest.json")

func _load_creature_ai(path: String) -> void:
	if not FileAccess.file_exists(path):
		creature_ai = {}
		return
	creature_ai = _parse_json(path)

func _parse_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_fail(path, "cannot read")
		return {}
	var txt := f.get_as_text()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail(path, "root is not an object")
		return {}
	return parsed

func _fail(path: String, why: String) -> void:
	push_error("[data] malformed %s: %s" % [path, why])
	print("[data] FAIL %s: %s" % [path, why])
