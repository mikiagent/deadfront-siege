extends SceneTree
## Exercises file writes only against unique temporary save fixtures.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var recovery: GDScript = load("res://scripts/core/save_recovery.gd")
	if not recovery.has_method("write_snapshot"):
		print("C0 SAVE WRITE FAIL: staged snapshot writer is missing")
		quit(1)
		return
	var base := "/private/tmp/deadfront-c0-write-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var old_text := '{"schema":3,"player":{"inventory":[{"id":"wood","count":5}]},"home":{}}'
	var newer := {"schema": 3, "player": {"inventory": [{"id": "wood", "count": 4}]}, "home": {}}
	var file := FileAccess.open(base, FileAccess.WRITE)
	if file == null:
		print("C0 SAVE WRITE FAIL: cannot create temporary fixture")
		quit(1)
		return
	file.store_string(old_text)
	file.close()
	var failures: Array[String] = []
	var result: int = recovery.write_snapshot(base, newer, 3)
	if result != OK:
		failures.append("valid snapshot was not written")
	if FileAccess.get_file_as_string(base + ".bak") != old_text:
		failures.append("previous save was not retained byte-for-byte")
	var state: Dictionary = recovery.inspect(base, 3)
	if state.get("status") != "valid" or state.get("data", {}).get("player", {}).get("inventory", [])[0].get("count") != 4:
		failures.append("new primary did not round-trip")
	var previous_primary := FileAccess.get_file_as_string(base)
	var next := {"schema": 3, "player": {"inventory": [{"id": "wood", "count": 3}]}, "home": {}}
	if recovery.write_snapshot(base, next, 3) != OK:
		failures.append("second valid snapshot was not written")
	if FileAccess.get_file_as_string(base + ".bak") != previous_primary:
		failures.append("backup was not advanced to the last valid save")
	var interrupted := base + ".pending-interrupted"
	file = FileAccess.open(interrupted, FileAccess.WRITE)
	file.store_string("{\"schema\":3,\"player\":")
	file.close()
	if recovery.inspect(base, 3).get("status") != "valid" or FileAccess.get_file_as_string(base + ".bak") != previous_primary:
		failures.append("interrupted stage damaged a known-good snapshot")
	if recovery.write_snapshot(base + "/missing/save.json", newer, 3) == OK:
		failures.append("failed stage incorrectly reported success")
	var future_text := '{"schema":99,"player":{},"home":{}}'
	file = FileAccess.open(base, FileAccess.WRITE)
	file.store_string(future_text)
	file.close()
	if recovery.write_snapshot(base, newer, 3) == OK:
		failures.append("future schema was overwritten")
	if FileAccess.get_file_as_string(base) != future_text or FileAccess.get_file_as_string(base + ".bak") != previous_primary:
		failures.append("blocked write changed protected bytes")
	var bot_fixture := base + "-bot"
	if recovery.write_snapshot(bot_fixture, newer, 3, false) != OK or recovery.write_snapshot(bot_fixture, next, 3, false) != OK:
		failures.append("throwaway bot-style save could not be written twice")
	if FileAccess.file_exists(bot_fixture + ".bak"):
		failures.append("throwaway bot-style save created a persistent backup")
	var blocked_dir := base + "-io-failure"
	var blocked_path := blocked_dir + "/save.json"
	if DirAccess.make_dir_absolute(blocked_dir) != OK:
		failures.append("cannot create isolated I/O failure fixture")
	else:
		file = FileAccess.open(blocked_path, FileAccess.WRITE)
		file.store_string(old_text)
		file.close()
		DirAccess.make_dir_absolute(blocked_path + ".bak")
		if recovery.write_snapshot(blocked_path, newer, 3) == OK:
			failures.append("failed backup promotion incorrectly reported success")
		if FileAccess.get_file_as_string(blocked_path) != old_text:
			failures.append("failed backup promotion changed the primary")
		# Only remove files this test created in its unique fixture directory.
		var directory := DirAccess.open(blocked_dir)
		if directory:
			for name: String in directory.get_files():
				if name == "save.json" or name.begins_with("save.json.pending-") or name.begins_with("save.json.backup-pending-"):
					DirAccess.remove_absolute(blocked_dir.path_join(name))
		DirAccess.remove_absolute(blocked_path + ".bak")
		DirAccess.remove_absolute(blocked_dir)
	for fixture: String in [base, base + ".bak", interrupted, bot_fixture]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture))
	if failures.is_empty():
		print("C0 SAVE WRITE PASS")
		quit(0)
	else:
		for failure: String in failures:
			print("C0 SAVE WRITE FAIL: %s" % failure)
		quit(1)
