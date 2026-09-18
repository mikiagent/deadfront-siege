extends Node
## First autoload. Applies downloaded build packs (user://builds) before the game's own
## autoloads are instantiated, so every launch runs the newest downloaded build.
## Safe mode: if the previous launch loaded packs but never reached the game, the packs
## are dropped and the built-in build runs (a bad pack can never brick the app).

const SHELL_VERSION := 1
const BUILDS_DIR := "user://builds"
const INSTALLED := "user://builds/installed.json"
const BOOT_MARKER := "user://builds/booting"

static var applied: Dictionary = {}
static var safe_mode: bool = false
static var no_pack: bool = false

var _watch: float = 0.0

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(BUILDS_DIR)
	if "--no-pack" in OS.get_cmdline_user_args():
		no_pack = true
		print("[shell] --no-pack: built-in build")
		return
	if FileAccess.file_exists(BOOT_MARKER):
		safe_mode = true
		DirAccess.remove_absolute(BOOT_MARKER)
		DirAccess.remove_absolute(INSTALLED)
		print("[shell] safe mode: the last downloaded build never booted; using the built-in build")
		return
	var inst := read_installed()
	if inst.is_empty():
		return
	var marker := FileAccess.open(BOOT_MARKER, FileAccess.WRITE)
	if marker:
		marker.store_string(str(inst.get("version", "")))
	var ok := apply_packs(inst)
	if ok:
		applied = inst
	else:
		DirAccess.remove_absolute(BOOT_MARKER)

## Loads every pack listed in an installed.json dictionary. Returns false if any is missing.
static func apply_packs(inst: Dictionary) -> bool:
	var all_ok := true
	for p in inst.get("packs", []):
		if not p is Dictionary:
			continue
		var path := "%s/%s" % [BUILDS_DIR, str(p.get("file", ""))]
		if not FileAccess.file_exists(path):
			print("[shell] pack missing %s" % path)
			all_ok = false
			continue
		var ok := ProjectSettings.load_resource_pack(path, true)
		print("[shell] pack %s %s (%s)" % [p.get("name", "?"), "loaded" if ok else "FAILED", str(inst.get("version", ""))])
		all_ok = all_ok and ok
	return all_ok

func _process(delta: float) -> void:
	# Clear the boot marker once the game is actually running (player exists) or after 90 s.
	if not FileAccess.file_exists(BOOT_MARKER):
		set_process(false)
		return
	_watch += delta
	var player := get_tree().get_first_node_in_group("player")
	if player != null or _watch > 90.0:
		DirAccess.remove_absolute(BOOT_MARKER)
		set_process(false)

static func read_installed() -> Dictionary:
	if not FileAccess.file_exists(INSTALLED):
		return {}
	var f := FileAccess.open(INSTALLED, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

static func write_installed(d: Dictionary) -> void:
	var f := FileAccess.open(INSTALLED, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "  "))

static func built_in_version() -> String:
	if FileAccess.file_exists("res://shell/build_version.txt"):
		return FileAccess.get_file_as_string("res://shell/build_version.txt").strip_edges()
	return "dev"

static func installed_version() -> String:
	if not applied.is_empty():
		return str(applied.get("version", "?"))
	return "built-in %s" % built_in_version()
