extends RefCounted
## INVIS (owner: "player model has disappeared"): a source run reads class_name scripts from
## .godot/global_script_class_cache.cfg, which only an import or the editor rewrites. Canon was
## launched after a merge added FireWeather and LightningBolt without one: data.gd and
## status_effects.gd failed to compile, the survivor rig never loaded, and only her lamp showed.
## ShellLoader calls heal() first thing on editor builds (exports carry their own cache): a stale
## cache is re-imported and the game relaunches; headless runs only report it (no detached restart).
## No class_name here on purpose: this script must load while the cache is wrong.

const DIRS := ["res://scripts", "res://shell"]

## class_name declarations under DIRS that the loaded class cache does not know.
static func missing_classes(dirs: Array = DIRS, known: Dictionary = {}) -> PackedStringArray:
	if known.is_empty():
		for row in ProjectSettings.get_global_class_list():
			known[str(row["class"])] = true
	var out := PackedStringArray()
	for d in dirs:
		_scan(str(d), known, out)
	return out

static func _scan(dir: String, known: Dictionary, out: PackedStringArray) -> void:
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var fa := FileAccess.open(dir.path_join(f), FileAccess.READ)
		for i in 3:  # every class_name in the project sits on line 1 or 2
			if fa == null or fa.eof_reached():
				break
			var line := fa.get_line()
			if line.begins_with("class_name "):
				var cls := line.substr(11).get_slice(" ", 0).strip_edges()
				if not known.has(cls):
					out.append(cls)
				break
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), known, out)

static func heal() -> void:
	if not OS.has_feature("editor"):
		return
	var missing := missing_classes()
	if missing.is_empty():
		return
	var root := ProjectSettings.globalize_path("res://")
	push_error("[classcache] the .godot class cache is stale (missing %s): every script that uses them fails to compile. Run: %s --headless --path %s --import" % [", ".join(missing), OS.get_executable_path(), root])
	if DisplayServer.get_name() == "headless":
		return
	print("[classcache] re-importing, then relaunching")
	OS.execute(OS.get_executable_path(), ["--headless", "--path", root, "--import"])
	# A relaunch can start in another working directory (macOS opens the bundle anew), so --path is absolute.
	var args := PackedStringArray(["--path", root])
	var given := OS.get_cmdline_args()
	var i := 0
	while i < given.size():
		if given[i] == "--path":
			i += 2
			continue
		args.append(given[i])
		i += 1
	var user := OS.get_cmdline_user_args()
	if not user.is_empty():
		args.append("--")
		args.append_array(user)
	print("[classcache] relaunch pid=%d" % OS.create_instance(args))
	(Engine.get_main_loop() as SceneTree).quit()
