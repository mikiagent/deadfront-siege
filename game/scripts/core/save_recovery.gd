extends RefCounted
## File-level validation for the existing schema. Does not migrate or mutate saves.

static func inspect(save_path: String, current_schema: int) -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {"status": "missing"}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {"status": "unreadable"}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {"status": "invalid"}
	var data: Dictionary = json.data
	if data.is_empty():
		return {"status": "invalid"}
	var version: Variant = data.get("schema", 0)
	if not (version is int or version is float):
		return {"status": "invalid"}
	if float(version) != float(int(version)) or int(version) < 0:
		return {"status": "invalid"}
	if int(version) > current_schema:
		return {"status": "future", "schema": int(version)}
	# Current snapshots are written with both root records. Older schemas may
	# legitimately omit either because the existing migrators supply defaults.
	if int(version) == current_schema and (not data.has("player") or not data.has("home")):
		return {"status": "invalid"}
	for key: String in ["player", "home", "unstable"]:
		if data.has(key) and not data[key] is Dictionary:
			return {"status": "invalid"}
	for key: String in ["pets", "ground_snares"]:
		if data.has(key) and not data[key] is Array:
			return {"status": "invalid"}
	for key: String in ["skills", "skills_v2", "pioneer_crafts", "pioneer_buildings", "visited_islands"]:
		if data.has(key) and not data[key] is Dictionary:
			return {"status": "invalid"}
	var player: Dictionary = data.get("player", {})
	for key: String in ["inventory", "statuses"]:
		if player.has(key) and not player[key] is Array:
			return {"status": "invalid"}
	for key: String in ["vitals", "inventory_extras"]:
		if player.has(key) and not player[key] is Dictionary:
			return {"status": "invalid"}
	if player.has("position"):
		var position: Variant = player["position"]
		if not position is Array or position.size() < 3:
			return {"status": "invalid"}
		for coordinate: Variant in position.slice(0, 3):
			if not (coordinate is int or coordinate is float):
				return {"status": "invalid"}
	var home: Dictionary = data.get("home", {})
	for key: String in ["buildings", "cargo", "claims"]:
		if home.has(key) and not home[key] is Array:
			return {"status": "invalid"}
	if home.has("camp_layout") and not home.camp_layout is Dictionary:
		return {"status": "invalid"}
	var unstable: Dictionary = data.get("unstable", {})
	if unstable.has("harvested") and not unstable.harvested is Dictionary:
		return {"status": "invalid"}
	return {"status": "valid", "data": data}

## Write a complete snapshot to a sibling file, preserve the last valid
## primary, then promote the staged file. If a filesystem cannot replace the
## destination by rename, fail without deleting the original or its backup.
static func write_snapshot(save_path: String, data: Dictionary, current_schema: int, keep_backup: bool = true) -> int:
	var existing := inspect(save_path, current_schema)
	if existing.status != "valid" and existing.status != "missing":
		return ERR_FILE_CORRUPT
	if existing.status == "missing" and keep_backup and FileAccess.file_exists(save_path + ".bak"):
		return ERR_FILE_CORRUPT
	if int(data.get("schema", -1)) != current_schema:
		return ERR_INVALID_DATA
	var text := JSON.stringify(data)
	var staged := _unused_path(save_path + ".pending-")
	var error := _write_checked(staged, text.to_utf8_buffer(), current_schema)
	if error != OK:
		return error
	if existing.status == "valid" and keep_backup:
		var previous := FileAccess.get_file_as_bytes(save_path)
		if FileAccess.get_open_error() != OK:
			return ERR_CANT_OPEN
		var backup_stage := _unused_path(save_path + ".backup-pending-")
		error = _write_checked(backup_stage, previous, current_schema)
		if error != OK:
			return error
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_stage), ProjectSettings.globalize_path(save_path + ".bak"))
		if error != OK:
			return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(staged), ProjectSettings.globalize_path(save_path))

static func _unused_path(prefix: String) -> String:
	var candidate := prefix + str(Time.get_ticks_usec())
	while FileAccess.file_exists(candidate):
		candidate += "-1"
	return candidate

static func _write_checked(target: String, bytes: PackedByteArray, current_schema: int) -> int:
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	var written := FileAccess.get_file_as_bytes(target)
	if FileAccess.get_open_error() != OK or written != bytes:
		return ERR_FILE_CANT_WRITE
	if inspect(target, current_schema).status != "valid":
		return ERR_INVALID_DATA
	return OK
