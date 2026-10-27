extends SceneTree
## Recovery operates exclusively on unique temporary fixtures.

func _init() -> void:
	call_deferred("_run")

func _put(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _run() -> void:
	var recovery: GDScript = load("res://scripts/core/save_recovery.gd")
	if not recovery.has_method("restore_backup"):
		print("C0 RESTORE FAIL: restore_backup is missing")
		quit(1)
		return
	var base := "/private/tmp/deadfront-c0-restore-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var backup := '{"schema":3,"player":{"inventory":[]},"home":{}}'
	var broken := '{"schema":3,"player":'
	var future := '{"schema":99,"player":{},"home":{}}'
	var current := '{"schema":3,"player":{"inventory":[1]},"home":{}}'
	var failures: Array[String] = []
	var archives: Array[String] = []
	_put(base + ".bak", backup)
	var result: Dictionary = recovery.restore_backup(base, 3)
	if not result.get("ok", false) or FileAccess.get_file_as_string(base) != backup or FileAccess.get_file_as_string(base + ".bak") != backup:
		failures.append("missing primary was not restored without changing backup")
	_put(base, broken)
	result = recovery.restore_backup(base, 3)
	var archive: String = result.get("archive", "")
	if not archive.is_empty():
		archives.append(archive)
	if not result.get("ok", false) or archive.is_empty() or FileAccess.get_file_as_string(archive) != broken:
		failures.append("damaged original was not preserved")
	if FileAccess.get_file_as_string(base) != backup or FileAccess.get_file_as_string(base + ".bak") != backup:
		failures.append("restored save or backup differs from original backup")
	_put(base, future)
	result = recovery.restore_backup(base, 3)
	if result.get("ok", false) or FileAccess.get_file_as_string(base) != future or FileAccess.get_file_as_string(base + ".bak") != backup:
		failures.append("future save was replaced or backup changed")
	_put(base, current)
	result = recovery.restore_backup(base, 3)
	if result.get("ok", false) or FileAccess.get_file_as_string(base) != current:
		failures.append("valid primary was replaced")
	_put(base, broken)
	_put(base + ".bak", broken)
	result = recovery.restore_backup(base, 3)
	if result.get("ok", false) or FileAccess.get_file_as_string(base) != broken or FileAccess.get_file_as_string(base + ".bak") != broken:
		failures.append("invalid backup changed a save")
	for path: String in archives + [base, base + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	if failures.is_empty():
		print("C0 RESTORE PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("C0 RESTORE FAIL: %s" % failure)
		quit(1)
