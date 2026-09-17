extends Node
## Autoload Data. Loads item, status, creature and skill catalogs at boot.

var items: Dictionary = {} ## StringName -> ItemDef
var statuses: Dictionary = {} ## StringName -> StatusDef
var creatures: Dictionary = {} ## StringName -> CreatureDef
var anim_events: Dictionary = {}
var survival_nodes: Dictionary = {}
var survival_unlocked: Dictionary = {} ## node id -> bool. ASSUMPTION: no SP economy yet.

func _ready() -> void:
	_load_items("res://data/items.json")
	_load_statuses("res://data/statuses.json")
	_load_creatures("res://data/creatures")
	_load_anim_events("res://data/creatures/anim_events.json")
	_load_survival("res://data/skills/survival.json")
	print("[data] items=%d statuses=%d creatures=%d" % [items.size(), statuses.size(), creatures.size()])

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
	var cap := 3
	for id in survival_nodes:
		var n: Dictionary = survival_nodes[id]
		if str(n.get("kind", "")) == "animal_management" and is_survival_unlocked(id):
			cap += int(n.get("bonded_cap_bonus", 1))
	return cap

func has_capture_technique(tier: int) -> bool:
	for id in survival_nodes:
		var n: Dictionary = survival_nodes[id]
		if str(n.get("kind", "")) == "capture_technique" and int(n.get("unlocks_capture_tier", 0)) == tier:
			return is_survival_unlocked(id)
	return false

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
		if not da.current_is_dir() and fname.ends_with(".json") and fname != "anim_events.json":
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
