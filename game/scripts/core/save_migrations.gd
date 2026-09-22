class_name SaveMigrations
extends RefCounted
## Pure, ordered save migrations. Every loader path passes through this class.

const CURRENT_SCHEMA := 3

static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	var schema := int(data.get("schema", 0))
	if schema > CURRENT_SCHEMA:
		push_error("Save schema %d is newer than this build (%d)" % [schema, CURRENT_SCHEMA])
		return {}
	while schema < CURRENT_SCHEMA:
		match schema:
			0:
				data = _v0_to_v1(data)
			1:
				data = _v1_to_v2(data)
			2:
				data = _v2_to_v3(data)
			_:
				push_error("No save migration from schema %d" % schema)
				return {}
		schema = int(data.get("schema", -1))
	return data

static func _v0_to_v1(data: Dictionary) -> Dictionary:
	# The first shipped saves had no schema marker. Their world-position buildings
	# are intentionally left alone; SaveGame normalizes them after migration.
	data["schema"] = 1
	data.get_or_add("player", {})
	data.get_or_add("home", {})
	data.get_or_add("unstable", {})
	return data

static func _v1_to_v2(data: Dictionary) -> Dictionary:
	# Schema 2 introduced grid-cell building poses. Old x/z rows remain valid and
	# are converted by SaveGame._normalize_build_row using source_schema.
	data["schema"] = 2
	return data

static func _v2_to_v3(data: Dictionary) -> Dictionary:
	var player: Dictionary = data.get("player", {})
	player.get_or_add("inventory_extras", {})
	data["player"] = player
	var home: Dictionary = data.get("home", {})
	home.get_or_add("camp_layout", {})
	data["home"] = home
	data["schema"] = 3
	return data
