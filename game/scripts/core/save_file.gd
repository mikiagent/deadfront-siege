class_name SaveFile
extends RefCounted
## File-safety layer under SaveGame: atomic writes with a .bak of the previous good save, reads that
## migrate and sanitize, and quarantine of unreadable bytes. Knows nothing about what a save holds.

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
	var data := SaveMigrations.migrate(json.data)
	if data.is_empty():
		out["error"] = "unsupported schema %d" % schema
		return out
	var cleaned: Variant = SaveSanitizer.clean(data) # null when a script error aborted the check
	if not cleaned is Dictionary:
		out["error"] = "it could not be checked"
		return out
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
