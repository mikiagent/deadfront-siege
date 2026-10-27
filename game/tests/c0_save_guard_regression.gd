extends SceneTree
## Regression for the existing public load path. The only save files touched are
## uniquely named test fixtures under user://; the real save path is restored.

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
	var fixture_base := "user://c0-guard-%d" % Time.get_ticks_usec()
	for row: Dictionary in [
		{"name": "truncated", "bytes": "{\"schema\":3,\"player\":"},
		{"name": "future", "bytes": "{\"schema\":99,\"player\":{}}"},
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
		for child: Node in host.get_children():
			if child.name == &"CharacterCreation":
				failures.append("%s save silently starts a new game" % row.name)
			child.free()
		if FileAccess.get_file_as_string(fixture_path) != row.bytes:
			failures.append("%s save bytes changed during load" % row.name)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
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
