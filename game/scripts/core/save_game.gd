extends RefCounted
## Snapshot C save. Schema 2. Ids only, never node references.

const PATH := "user://save_1.json"
const SCHEMA := SaveMigrations.CURRENT_SCHEMA

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
			var persist := true
			if b and b.has_method("get"):
				var pv: Variant = b.get("persist_building")
				if pv != null:
					persist = bool(pv)
			if b and b.has_method("to_dict") and persist and not bool(b.get("is_cargo")):
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
			"inventory_extras": player.inventory.extras_to_dict(),
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		},
		"pets": pets,
		"skills": skills,
		"home": {
			"terrain": str(World.home_terrain),
			"buildings": buildings if World.is_home() else World._home_buildings_cache,
			"cargo": World.cargo_home.to_array(),
			"claims": World.home_claims,
			"camp_layout": World.camp_layout,
		},
		"pioneer_xp": World.pioneer_xp,
		"skills_v2": player.skills.to_dict() if player.skills else {},
		"player_name": World.player_name,
		"occupation": World.occupation,
		"pioneer_level": World.pioneer_level,
		"pioneer_crafts": World.pioneer_crafts,
		"pioneer_buildings": World.pioneer_buildings,
		"t_stones": World.t_stones,
		"objective": World.objective,
		"objective_best": World.objective_best,
		"island_id": str(World.island_id),
		"unstable": {
			"remaining": World.remaining_lifetime,
			"harvested": World.harvested,
			"crater_discovered": World.crater_discovered,
		},
		"clock": Game.time_of_day,
		"saved_unix": int(Time.get_unix_time_from_system()),
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
	var raw_data: Dictionary = parsed
	var source_schema := int(raw_data.get("schema", 0))
	var data := SaveMigrations.migrate(raw_data)
	if data.is_empty():
		print("[world] unsupported save schema=%d; starting new world" % source_schema)
		World.start_new(host)
		return
	if source_schema != SCHEMA:
		print("[world] migrated save schema=%d -> %d" % [source_schema, SCHEMA])
	var schema := source_schema
	World.home_terrain = StringName(str(data.get("home", {}).get("terrain", "")))
	World.pioneer_level = int(data.get("pioneer_level", 0))
	World.pioneer_crafts = data.get("pioneer_crafts", {})
	World.pioneer_buildings = data.get("pioneer_buildings", {})
	World.t_stones = int(data.get("t_stones", 20))
	World.objective = int(data.get("objective", 0))  # older saves start the standing orders over
	World.objective_best = int(data.get("objective_best", 0))
	World.remaining_lifetime = float(data.get("unstable", {}).get("remaining", 0.0))
	World.harvested = data.get("unstable", {}).get("harvested", {})
	World.crater_discovered = bool(data.get("unstable", {}).get("crater_discovered", false))
	World.cargo_home.load_array(data.get("home", {}).get("cargo", []))
	World._home_buildings_cache = data.get("home", {}).get("buildings", [])
	World.home_claims = data.get("home", {}).get("claims", [])
	var cl: Variant = data.get("home", {}).get("camp_layout", {})
	World.camp_layout = (cl as Dictionary).duplicate() if cl is Dictionary else {}
	World.pioneer_xp = int(data.get("pioneer_xp", 0))
	World.player_name = str(data.get("player_name", ""))
	World.occupation = str(data.get("occupation", ""))
	Game.time_of_day = float(data.get("clock", 0.35))
	var skills: Dictionary = data.get("skills", {})
	for id in skills:
		Data.set_survival_unlocked(StringName(id), bool(skills[id]))
	var iid := StringName(str(data.get("island_id", "home_grassland")))
	var pos_a: Array = data.get("player", {}).get("position", [0, 1, 12])
	var pos := Vector3(float(pos_a[0]), float(pos_a[1]), float(pos_a[2]))
	World.load_island(host, iid, pos, false)
	if World.is_home():
		_restore_buildings(World._home_buildings_cache, schema)
	var player := World._player()
	if player == null:
		return
	# Re-seat the player on the terrain: saves from older builds (or a regenerated
	# island) can hold a y that is now inside the ground, and a body that starts
	# below the one-sided heightmap falls forever.
	var seat := pos
	if World.runtime and World.runtime.has_method("surface_y"):
		seat.y = World.runtime.surface_y(pos.x, pos.z) + 1.0
	player.global_position = seat
	print("[world] loaded player at %s (saved y=%.2f)" % [seat.snapped(Vector3.ONE * 0.1), pos.y])
	player.vitals.from_dict(data.get("player", {}).get("vitals", {}))
	player.statuses.from_array(data.get("player", {}).get("statuses", []))
	player.inventory.load_array(data.get("player", {}).get("inventory", []))
	var extras: Variant = data.get("player", {}).get("inventory_extras", null)
	if extras is Dictionary:
		player.inventory.extras_from_dict(extras as Dictionary)
	if player.skills:
		player.skills.from_dict(data.get("skills_v2", {}))
	player.bonded.clear()
	for row in data.get("pets", []):
		if row is Dictionary:
			player.bonded.append(PetRecord.from_dict(row))
	var saved_unix := int(data.get("saved_unix", Time.get_unix_time_from_system()))
	var elapsed := maxi(0, int(Time.get_unix_time_from_system()) - saved_unix)
	# Field growth catch-up (same offline window as tent rest).
	if elapsed > 0 and World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("field"):
			if n is FieldPlot:
				(n as FieldPlot).advance_offline(float(elapsed))
		print("[farm] offline catch-up %ds" % elapsed)
	print("[world] loaded island=%s terrain=%s pioneer=%d" % [iid, World.home_terrain, World.pioneer_level])

static func _restore_buildings(rows: Array, schema: int) -> void:
	if World.runtime == null:
		return
	var grid: BuildGrid = null
	var gv: Variant = World.runtime.get("build_grid")
	if gv is BuildGrid:
		grid = gv as BuildGrid
	if grid:
		grid.clear_occupancy()
	for row in rows:
		if not row is Dictionary:
			continue
		var normalized := _normalize_build_row(row as Dictionary, schema)
		var b := _spawn_building(normalized)
		if b == null:
			continue
		World.runtime.add_child(b)
		_place_building(b, normalized, grid)

static func _normalize_build_row(row: Dictionary, schema: int) -> Dictionary:
	var out := row.duplicate(true)
	if schema >= 2 and out.has("cell"):
		return out
	var x := float(out.get("x", 0.0))
	var z := float(out.get("z", 0.0))
	var tile := BuildGrid.tile_of(Vector3(x, 0.0, z))
	out["cell"] = [tile.x, tile.y]
	out["rot"] = int(out.get("rot", 0))
	return out

static func _spawn_building(row: Dictionary) -> Node3D:
	var kind := StringName(str(row.get("kind", "basket")))
	match kind:
		&"workbench", &"drying_rack", &"mortar", &"stone_grill", &"steamer", &"well":
			return CraftStation.from_dict(row)
		&"bonfire":
			return Bonfire.from_dict(row)
		&"makeshift_taming_pen":
			return TamingPen.from_dict(row)
		&"field_small", &"field_large":
			return FieldPlot.from_dict(row)
		&"tent", &"basket", &"fence", &"gate", &"sign":
			return (load("res://scripts/world/placed_building.gd") as GDScript).from_dict(row)
		_:
			return (load("res://scripts/world/placed_building.gd") as GDScript).from_dict(row)

static func _place_building(node: Node3D, row: Dictionary, grid: BuildGrid) -> void:
	var kind := StringName(str(row.get("kind", "basket")))
	var cell := Vector2i.ZERO
	var cell_v: Variant = row.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	var rot := int(row.get("rot", 0))
	if grid:
		node.global_transform = grid.placement_transform(kind, cell, rot)
		if node.has_method("set_grid_pose"):
			node.set_grid_pose(cell, rot)
		grid.occupy(node, grid.cells_for(kind, cell, rot))
		return
	node.global_position = Vector3(float(row.get("x", 0.0)), 0.0, float(row.get("z", 0.0)))

static func _player() -> Player:
	return Engine.get_main_loop().root.get_tree().get_first_node_in_group("player") as Player
