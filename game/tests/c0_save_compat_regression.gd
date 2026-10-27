extends SceneTree
## Schema 0-3 survive validation, migration and staged save round-trips.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var recovery: GDScript = load("res://scripts/core/save_recovery.gd")
	var migrations: GDScript = load("res://scripts/core/save_migrations.gd")
	var failures: Array[String] = []
	var fixtures: Array[Dictionary] = []
	for fixture_name: String in ["save_v0.json", "save_v1_c0.json", "save_v2.json", "save_v3_c0.json"]:
		var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/" + fixture_name))
		if fixture is Dictionary:
			fixtures.append(fixture)
		else:
			failures.append("existing fixture %s cannot be read" % fixture_name)
	var base := "/private/tmp/deadfront-c0-compat-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for i: int in fixtures.size():
		var path := "%s-%d.json" % [base, i]
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(fixtures[i]))
		file.close()
		var input: Dictionary = recovery.inspect(path, 3)
		if input.get("status") != "valid":
			failures.append("fixture %d rejected" % i)
			continue
		var migrated: Dictionary = migrations.migrate(input.data)
		if int(migrated.get("schema", -1)) != 3:
			failures.append("fixture %d failed migration" % i)
		elif recovery.write_snapshot(path, migrated, 3) != OK:
			failures.append("fixture %d failed staged save" % i)
		else:
			var loaded: Dictionary = recovery.inspect(path, 3)
			var expected: Dictionary = migrated.duplicate(true)
			# Godot parses JSON numbers as floats, including the schema marker.
			expected["schema"] = float(expected["schema"])
			if JSON.stringify(loaded.get("data")) != JSON.stringify(expected):
				failures.append("fixture %d lost data on reload" % i)
			if FileAccess.get_file_as_string(path + ".bak") != JSON.stringify(fixtures[i]):
				failures.append("fixture %d backup changed" % i)
		for target: String in [path, path + ".bak"]:
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	if failures.is_empty():
		print("C0 SAVE COMPAT PASS: schema 0, 1, 2 and 3")
		quit(0)
	else:
		for failure: String in failures:
			print("C0 SAVE COMPAT FAIL: %s" % failure)
		quit(1)
