extends SceneTree
## Regression for the existing public load path. The only save files touched are
## uniquely named temporary fixtures; the real save path is restored.

var _ran: bool = false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	if root.get_node_or_null("World") == null:
		return false
	_ran = true
	var save: GDScript = load("res://scripts/core/save_game.gd")
	var previous_path: String = save.path
	var host := Node.new()
	root.add_child(host)
	var failures: Array[String] = []
	var fixture_base := "/private/tmp/deadfront-c0-guard-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for row: Dictionary in [
		{"name": "truncated", "bytes": "{\"schema\":3,\"player\":"},
		{"name": "future", "bytes": "{\"schema\":99,\"player\":{}}"},
		{"name": "invalid position", "bytes": "{\"schema\":3,\"player\":{\"position\":[0]},\"home\":{}}"},
		{"name": "incomplete snapshot", "bytes": "{\"schema\":3}"},
		{"name": "invalid harvest state", "bytes": "{\"schema\":3,\"player\":{},\"home\":{},\"unstable\":{\"harvested\":[]}}"},
	]:
		var fixture_path: String = "%s-%s.json" % [fixture_base, row.name]
		var file := FileAccess.open(fixture_path, FileAccess.WRITE)
		if file == null:
			failures.append("cannot create isolated fixture")
			continue
		file.store_string(row.bytes)
		file.close()
		save.path = fixture_path
		save.load_now(host)
		save.save_now()
		if host.get_node_or_null("SaveRecoveryError") == null:
			failures.append("%s save did not show the recovery error" % row.name)
		for child: Node in host.get_children():
			if child.name == &"CharacterCreation":
				failures.append("%s save silently starts a new game" % row.name)
			child.free()
		if FileAccess.get_file_as_string(fixture_path) != row.bytes:
			failures.append("%s save bytes changed during load" % row.name)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	var missing_primary := fixture_base + "-missing.json"
	var backup_bytes := '{"schema":3,"player":{},"home":{}}'
	var backup := FileAccess.open(missing_primary + ".bak", FileAccess.WRITE)
	backup.store_string(backup_bytes)
	backup.close()
	save.path = missing_primary
	if not save.exists():
		failures.append("backup-only save was not detected")
	save.load_now(host)
	save.save_now()
	if host.get_node_or_null("SaveRecoveryError") == null or FileAccess.file_exists(missing_primary):
		failures.append("backup-only save did not enter the protected state")
	if FileAccess.get_file_as_string(missing_primary + ".bak") != backup_bytes:
		failures.append("backup-only save changed its backup")
	DirAccess.remove_absolute(missing_primary + ".bak")
	save.path = previous_path
	host.free()
	if failures.is_empty():
		print("C0 SAVE GUARD PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("C0 SAVE GUARD FAIL: %s" % failure)
		quit(1)
	return true
