class_name SaveMigrations
extends RefCounted
## The on-disk save format: ordered migrations, plus the file-safety layer under SaveGame (atomic
## writes with a .bak of the previous good save, reads that migrate and sanitize, quarantine of
## unreadable bytes). Knows nothing about what a save holds. Every loader path passes through here.

const CURRENT_SCHEMA := 3

static func migrate(raw: Dictionary) -> Dictionary:
	var data := raw.duplicate(true)
	for key in ["player", "home", "unstable"]:
		if not data.get(key, {}) is Dictionary:
			data.erase(key) # a hand-edited scalar here would crash the typed steps below
	var schema := schema_of(data)
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

## -1 for a marker that is not a number (no migration path, so the save is rejected).
static func schema_of(data: Dictionary) -> int:
	var v: Variant = data.get("schema", 0)
	return int(clampf(float(v), -1.0, 1000000.0)) if v is int or v is float else -1

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

# ---------------------------------------------------------------- file layer

## Write tmp, check it, refresh .bak from the current save, then rename over it: a crash at any
## point leaves a complete save on disk.
static func write_atomic(path: String, text: String) -> bool:
	var target := ProjectSettings.globalize_path(path)
	var tmp := target + ".tmp"
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.get_file_as_bytes(tmp).size() != text.to_utf8_buffer().size():
		DirAccess.remove_absolute(tmp) # short write (disk full): keep the old save untouched
		return false
	if FileAccess.file_exists(target) and DirAccess.copy_absolute(target, target + ".bak") != OK:
		push_warning("[save] could not refresh %s.bak" % path)
	return DirAccess.rename_absolute(tmp, target) == OK

## {path} when missing, {path, error} when unreadable, else {path, data, schema} (migrated, sanitized).
static func read(p: String) -> Dictionary:
	var out := {"path": p}
	if not FileAccess.file_exists(p):
		return out
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(p)) != OK or not json.data is Dictionary:
		out["error"] = "the file is damaged"
		return out
	var schema := SaveMigrations.schema_of(json.data)
	if schema > SaveMigrations.CURRENT_SCHEMA:
		out["error"] = "it was made by a newer version (schema %d)" % schema
		return out
	var data := migrate(json.data)
	if data.is_empty():
		out["error"] = "it has no version number this build understands" if schema < 0 else "it was made by an unsupported version (schema %d)" % schema
		return out
	# A script error aborts clean() but still hands back a Dictionary (half-checked), so success is
	# the sentinel it sets as its last statement; a forged copy of the key is erased first.
	data.erase(SaveSanitizer.CHECKED)
	var cleaned: Dictionary = SaveSanitizer.clean(data)
	if cleaned.get(SaveSanitizer.CHECKED) != true:
		out["error"] = "it could not be checked"
		return out
	cleaned.erase(SaveSanitizer.CHECKED)
	out["data"] = cleaned
	out["schema"] = schema
	return out

## Keep an unreadable file's bytes as <file>.corrupt-<unix> (once per distinct content). Returns that path.
static func quarantine(p: String, move: bool) -> String:
	var src := ProjectSettings.globalize_path(p)
	var dir := src.get_base_dir()
	var sha := FileAccess.get_sha256(src)
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(src.get_file() + ".corrupt-") and FileAccess.get_sha256(dir.path_join(f)) == sha:
			if move:
				DirAccess.remove_absolute(src)
			return dir.path_join(f)
	var unix := int(Time.get_unix_time_from_system())
	var dest := "%s.corrupt-%d" % [src, unix]
	var n := 1
	while FileAccess.file_exists(dest):
		dest = "%s.corrupt-%d-%d" % [src, unix, n]
		n += 1
	var err := DirAccess.rename_absolute(src, dest) if move else DirAccess.copy_absolute(src, dest)
	if err != OK:
		push_error("[save] could not keep %s as %s (error %d)" % [src, dest, err])
	return dest

## Empty an automated run's save folder so every launch of it starts from a fresh world.
static func wipe_dir(dir_path: String) -> void:
	var dir := ProjectSettings.globalize_path(dir_path)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
