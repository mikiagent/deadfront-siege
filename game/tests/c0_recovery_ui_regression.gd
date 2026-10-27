extends SceneTree

var ran: bool = false

func _process(_delta: float) -> bool:
	if ran or root.get_node_or_null("World") == null:
		return false
	ran = true
	var save: GDScript = load("res://scripts/core/save_game.gd")
	var old_path: String = save.path
	var fixture_path := "/private/tmp/deadfront-ui-check-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var good := '{"schema":3,"player":{},"home":{}}'
	var cases: Array[Dictionary] = [
		{"name": "invalid", "primary": "broken", "backup": good, "button": true},
		{"name": "missing", "primary": "", "backup": good, "button": true},
		{"name": "future", "primary": '{"schema":99}', "backup": good, "button": false},
		{"name": "valid", "primary": good, "backup": good, "button": false},
		{"name": "bad backup", "primary": "broken", "backup": "broken", "button": false},
	]
	var failures: Array[String] = []
	for row: Dictionary in cases:
		if FileAccess.file_exists(fixture_path):
			DirAccess.remove_absolute(fixture_path)
		if FileAccess.file_exists(fixture_path + ".bak"):
			DirAccess.remove_absolute(fixture_path + ".bak")
		if row.primary != "":
			var file := FileAccess.open(fixture_path, FileAccess.WRITE)
			file.store_string(row.primary)
			file.close()
		var backup := FileAccess.open(fixture_path + ".bak", FileAccess.WRITE)
		backup.store_string(row.backup)
		backup.close()
		save.path = fixture_path
		var host := Node.new()
		root.add_child(host)
		save._show_save_error(host, row.name)
		var overlay: Node = host.get_node_or_null("SaveRecoveryError")
		var button: Button = overlay.find_child("RestoreBackupButton", true, false) as Button if overlay else null
		if (button != null) != row.button:
			failures.append("%s button availability" % row.name)
		if button != null and row.name == "invalid":
			if button.offset_bottom - button.offset_top < 64.0:
				failures.append("button below minimum target size")
			var broken_backup := FileAccess.open(fixture_path + ".bak", FileAccess.WRITE)
			broken_backup.store_string("broken backup")
			broken_backup.close()
			button.pressed.emit()
			if button.disabled or overlay.is_queued_for_deletion() or FileAccess.get_file_as_string(fixture_path) != "broken":
				failures.append("failed restore did not keep protected UI and original")
		host.free()
	save.path = old_path
	if FileAccess.file_exists(fixture_path):
		DirAccess.remove_absolute(fixture_path)
	if FileAccess.file_exists(fixture_path + ".bak"):
		DirAccess.remove_absolute(fixture_path + ".bak")
	if failures.is_empty():
		print("C0 RECOVERY UI PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("C0 RECOVERY UI FAIL: %s" % failure)
		quit(1)
	return true
