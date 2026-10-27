extends RefCounted
## Snapshot C save. Schema 2. Ids only, never node references.

## The bot plays on its own throwaway save, deleted at launch, so every bot run is a true first hour
## and none of them can write into the real save.
static var path: String = _pick_path()
static var _save_blocked: bool = false
const Recovery := preload("res://scripts/core/save_recovery.gd")

static func _pick_path() -> String:
	if "--bot" in OS.get_cmdline_user_args():
		var bot_path := "user://bot_save.json"
		if FileAccess.file_exists(bot_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(bot_path))
		return bot_path
	return "user://save_1.json"
const SCHEMA := SaveMigrations.CURRENT_SCHEMA

static func exists() -> bool:
	return FileAccess.file_exists(path) or (not _is_bot() and FileAccess.file_exists(path + ".bak"))

static func _is_bot() -> bool:
	return "--bot" in OS.get_cmdline_user_args()

static func save_now() -> void:
	if _save_blocked:
		print("[world] save blocked: existing save needs recovery")
		return
	var check: Dictionary = Recovery.inspect(path, SCHEMA)
	if check.status != "valid" and check.status != "missing":
		_save_blocked = true
		print("[world] save blocked: existing save needs recovery")
		_show_save_error(World.get_tree().current_scene, str(check.status))
		return
	if check.status == "missing" and not _is_bot() and FileAccess.file_exists(path + ".bak"):
		_save_blocked = true
		print("[world] save blocked: primary is missing but a backup exists")
		_show_save_error(World.get_tree().current_scene, "primary missing; backup available")
		return
	var player := _player()
	if player == null:
		return
	World._snapshot_harvest()
	var buildings: Array = []
	if World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("placed_building"):
			# The old island may still be queue_free pending during a travel callback.
			if n.is_queued_for_deletion() or not World.runtime.is_ancestor_of(n): continue
			var b = n
			var persist := true
			if b and b.has_method("get"):
				var pv: Variant = b.get("persist_building")
				if pv != null:
					persist = bool(pv)
			if b and b.has_method("to_dict") and persist and b.get("is_cargo") != true:
				buildings.append(b.to_dict())
	var snares: Array = []
	if World.runtime:
		for n in World.runtime.get_tree().get_nodes_in_group("ground_snare"):
			if n.get_parent() == World.runtime and not n.is_queued_for_deletion(): snares.append(n.to_dict())
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
		"ground_snares": snares,
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
		"visited_islands": World.visited_islands,
		"raid_victory": World.raid_victory,
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
	var error: int = Recovery.write_snapshot(path, payload, SCHEMA, not _is_bot())
	if error != OK:
		print("[world] save failed (%d); previous save and backup retained" % error)
		_save_blocked = true
		_show_save_error(World.get_tree().current_scene, "save write failed; check storage")
		return
	if World.is_home():
		World._home_buildings_cache = buildings
	World.last_save_unix = int(payload["saved_unix"])
	print("[world] saved schema=%d island=%s" % [SCHEMA, World.island_id])

static func load_now(host: Node) -> void:
	var check: Dictionary = Recovery.inspect(path, SCHEMA)
	if check.status == "missing":
		if not _is_bot() and FileAccess.file_exists(path + ".bak"):
			_save_blocked = true
			_show_save_error(host, "primary missing; backup available")
			return
		World.start_new(host)
		return
	if check.status != "valid":
		_save_blocked = true
		_show_save_error(host, str(check.status))
		return
	var raw_data: Dictionary = check.data
	var source_schema := int(raw_data.get("schema", 0))
	var data := SaveMigrations.migrate(raw_data)
	if data.is_empty():
		_save_blocked = true
		_show_save_error(host, "migration failed")
		return
	# A valid outer JSON object can still contain malformed nested data or fail
	# while the world is being restored. Never autosave a partially loaded world.
	_save_blocked = true
	if source_schema != SCHEMA:
		print("[world] migrated save schema=%d -> %d" % [source_schema, SCHEMA])
	var schema := source_schema
	World.home_terrain = StringName(str(data.get("home", {}).get("terrain", "")))
	World.pioneer_level = int(data.get("pioneer_level", 0))
	World.pioneer_crafts = data.get("pioneer_crafts", {})
	World.pioneer_buildings = data.get("pioneer_buildings", {})
	World.t_stones = int(data.get("t_stones", 20))
	World.visited_islands = data.get("visited_islands", {}).duplicate()
	World.raid_victory = bool(data.get("raid_victory", false))
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
	for row in data.get("ground_snares", []):
		if row is Dictionary and World.runtime:
			var remaining: Dictionary = row.duplicate(true)
			remaining["life_left"] = float(row.get("life_left", 0.0)) - maxi(0, int(Time.get_unix_time_from_system()) - int(data.get("saved_unix", Time.get_unix_time_from_system())))
			GroundSnare.restore(remaining, World.runtime)
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
	player.inventory.load_array(data.get("player", {}).get("inventory", []))
	var extras: Variant = data.get("player", {}).get("inventory_extras", null)
	if extras is Dictionary:
		player.inventory.extras_from_dict(extras as Dictionary)
	# Derive equipment capacity before restoring statuses, whose sync clamps health.
	player.refresh_equipment_vitals()
	player.vitals.from_dict(data.get("player", {}).get("vitals", {}))
	player.statuses.from_array(data.get("player", {}).get("statuses", []))
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
	_save_blocked = false
	print("[world] loaded island=%s terrain=%s pioneer=%d" % [iid, World.home_terrain, World.pioneer_level])

static func _show_save_error(host: Node, reason: String) -> void:
	print("[world] save unavailable (%s); original file preserved, saving disabled" % reason)
	if host == null:
		return
	if host.get_node_or_null("SaveRecoveryError") != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "SaveRecoveryError"
	layer.layer = 120
	var panel := ColorRect.new()
	panel.color = Color(0.04, 0.05, 0.06, 0.96)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var message := Label.new()
	var description := reason
	match reason:
		"invalid": description = "the save is damaged or incomplete"
		"future": description = "the save belongs to a newer game version"
		"unreadable": description = "the save could not be read"
	var backup_note := "No backup was found."
	if FileAccess.file_exists(path + ".bak"):
		backup_note = "A backup is available at:\n%s" % ProjectSettings.globalize_path(path + ".bak")
	message.text = "Save protection stopped saving: %s.\n\nThe existing save has not been replaced. This session is not being saved.\n%s\n\nBack up your files before making changes, or use a compatible game version." % [description, backup_note]
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(message)
	layer.add_child(panel)
	host.add_child(layer)
	panel.resized.connect(func () -> void: _layout_save_message(message))
	_layout_save_message(message)

static func _layout_save_message(message: Label) -> void:
	if not is_instance_valid(message) or message.get_viewport() == null:
		return
	var viewport := message.get_viewport()
	var logical := viewport.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	var scale := maxf(1.0, logical.x / window.x) if window.x > 0.0 else 1.0
	var safe := UiTokens.safe_insets(viewport)
	var padding := 18.0 * scale
	message.offset_left = safe.w + padding
	message.offset_top = safe.z + padding
	message.offset_right = -safe.x - padding
	message.offset_bottom = -safe.y - padding
	message.add_theme_font_size_override("font_size", int(ceil(22.0 * scale)))

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
		&"catapult":
			return FieldCatapult.from_dict(row) if float(row.get("hp",200)) > 0 else null
		&"workbench", &"drying_rack", &"smoker", &"crock_pot", &"mortar", &"stone_grill", &"steamer", &"well":
			return CraftStation.from_dict(row)
		&"bonfire", &"stone_fire_pit", &"campfire":
			return Bonfire.from_dict(row)
		&"makeshift_taming_pen":
			return TamingPen.from_dict(row)
		&"field_small", &"field_large":
			return FieldPlot.from_dict(row)
		&"straw_roll", &"tent", &"canvas_tent", &"log_shelter", &"cabin_bed", &"basket", &"fence", &"gate", &"sign":
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
