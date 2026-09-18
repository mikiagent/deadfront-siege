extends RefCounted
## Snapshot C save. Schema 1. Ids only, never node references.

const PATH := "user://save_1.json"
const SCHEMA := 1

static func exists() -> bool:
	return FileAccess.file_exists(PATH)

static func save_now() -> void:
	var player := _player()
	if player == null:
		return
	World._snapshot_harvest()
	var buildings: Array = []
	if World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("placed_building"):
			var b = n
			if b and b.has_method("to_dict") and not bool(b.get("is_cargo")):
				buildings.append(b.to_dict())
	var pets: Array = []
	for rec in player.bonded:
		pets.append(rec.to_dict())
	var skills: Dictionary = {}
	for id in Data.survival_unlocked:
		skills[str(id)] = bool(Data.survival_unlocked[id])
	var payload := {
		"schema": SCHEMA,
		"player": {
			"vitals": player.vitals.to_dict(),
			"statuses": player.statuses.to_array(),
			"inventory": player.inventory.to_array(),
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		},
		"pets": pets,
		"skills": skills,
		"home": {
			"terrain": str(World.home_terrain),
			"buildings": buildings if World.is_home() else World._home_buildings_cache,
			"cargo": World.cargo_home.to_array(),
		},
		"pioneer_level": World.pioneer_level,
		"pioneer_crafts": World.pioneer_crafts,
		"pioneer_buildings": World.pioneer_buildings,
		"t_stones": World.t_stones,
		"island_id": str(World.island_id),
		"unstable": {
			"remaining": World.remaining_lifetime,
			"harvested": World.harvested,
			"crater_discovered": World.crater_discovered,
		},
		"clock": Game.time_of_day,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"resting_in_tent": World.resting_in_tent,
	}
	if World.is_home():
		World._home_buildings_cache = buildings
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		print("[world] save failed")
		return
	f.store_string(JSON.stringify(payload))
	World.last_save_unix = int(payload["saved_unix"])
	print("[world] saved schema=%d island=%s" % [SCHEMA, World.island_id])

static func load_now(host: Node) -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		World.start_new(host)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		World.start_new(host)
		return
	var data: Dictionary = parsed
	if int(data.get("schema", 0)) != SCHEMA:
		print("[world] save schema mismatch")
	World.home_terrain = StringName(str(data.get("home", {}).get("terrain", "")))
	World.pioneer_level = int(data.get("pioneer_level", 0))
	World.pioneer_crafts = data.get("pioneer_crafts", {})
	World.pioneer_buildings = data.get("pioneer_buildings", {})
	World.t_stones = int(data.get("t_stones", 20))
	World.remaining_lifetime = float(data.get("unstable", {}).get("remaining", 0.0))
	World.harvested = data.get("unstable", {}).get("harvested", {})
	World.crater_discovered = bool(data.get("unstable", {}).get("crater_discovered", false))
	World.resting_in_tent = bool(data.get("resting_in_tent", false))
	World.cargo_home.load_array(data.get("home", {}).get("cargo", []))
	World._home_buildings_cache = data.get("home", {}).get("buildings", [])
	Game.time_of_day = float(data.get("clock", 0.35))
	var skills: Dictionary = data.get("skills", {})
	for id in skills:
		Data.set_survival_unlocked(StringName(id), bool(skills[id]))
	var iid := StringName(str(data.get("island_id", "home_grassland")))
	var pos_a: Array = data.get("player", {}).get("position", [0, 1, 12])
	var pos := Vector3(float(pos_a[0]), float(pos_a[1]), float(pos_a[2]))
	World.load_island(host, iid, pos, false)
	if World.is_home():
		_restore_buildings(World._home_buildings_cache)
	var player := World._player()
	if player == null:
		return
	player.global_position = pos
	player.vitals.from_dict(data.get("player", {}).get("vitals", {}))
	player.statuses.from_array(data.get("player", {}).get("statuses", []))
	player.inventory.load_array(data.get("player", {}).get("inventory", []))
	player.bonded.clear()
	for row in data.get("pets", []):
		if row is Dictionary:
			player.bonded.append(PetRecord.from_dict(row))
	var saved_unix := int(data.get("saved_unix", Time.get_unix_time_from_system()))
	var elapsed := maxi(0, int(Time.get_unix_time_from_system()) - saved_unix)
	if World.resting_in_tent and elapsed > 0:
		player.vitals.rest(World.TENT_REST_PER_MIN * (float(elapsed) / 60.0))
		print("[world] offline rest %ds" % elapsed)
	print("[world] loaded island=%s terrain=%s pioneer=%d" % [iid, World.home_terrain, World.pioneer_level])

static func _restore_buildings(rows: Array) -> void:
	if World.runtime == null:
		return
	for row in rows:
		if not row is Dictionary:
			continue
		var b = (load("res://scripts/world/placed_building.gd") as GDScript).from_dict(row)
		World.runtime.add_child(b)
		b.global_position = Vector3(float(row.get("x", 0.0)), 0.0, float(row.get("z", 0.0)))

static func _player() -> Player:
	return Engine.get_main_loop().root.get_tree().get_first_node_in_group("player") as Player
