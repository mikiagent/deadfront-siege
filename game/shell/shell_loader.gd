extends Node
## First autoload. Applies downloaded build packs (user://builds) before the game's own
## autoloads are instantiated, so every launch runs the newest downloaded build.
## Safe mode: if the previous launch loaded packs but never reached the game, the packs
## are dropped and the built-in build runs (a bad pack can never brick the app).

const SHELL_VERSION := 1
const BUILDS_DIR := "user://builds"
const INSTALLED := "user://builds/installed.json"
const BOOT_MARKER := "user://builds/booting"

## Manifest rules (sec-shell-20): the name and hash become a file name under user://builds.
const PACK_NAME_PATTERN := "^[a-z0-9_-]{1,32}\\z"
const SHA256_PATTERN := "^[0-9a-f]{64}\\z"
const PACK_FILE_PATTERN := "^[a-z0-9_-]{1,32}-[0-9a-f]{8}\\.pck\\z"

static var applied: Dictionary = {}
static var safe_mode: bool = false
static var no_pack: bool = false

var _watch: float = 0.0

func _init() -> void:
	load("res://scripts/core/class_cache_guard.gd").heal()
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

## Empty when a build manifest is safe to act on, else the reason it is refused. Every pack
## needs a name of [a-z0-9_-]{1,32}, a lowercase sha256 and an http(s) url.
static func manifest_error(m: Dictionary) -> String:
	var packs: Variant = m.get("packs")
	if not packs is Array:
		return "packs is not a list"
	if (packs as Array).is_empty():
		return "packs is empty"
	var name_re := RegEx.create_from_string(PACK_NAME_PATTERN)
	var sha_re := RegEx.create_from_string(SHA256_PATTERN)
	var seen: Dictionary = {}
	for p: Variant in packs:
		if not p is Dictionary:
			return "pack entry is not an object"
		var name: Variant = p.get("name")
		if not name is String or name_re.search(name) == null:
			return "bad pack name %s" % str(name).left(40)
		if seen.has(name):
			return "duplicate pack %s" % name
		seen[name] = true
		var sha: Variant = p.get("sha256")
		if not sha is String or sha_re.search(sha) == null:
			return "pack %s has no valid sha256" % name
		var url: Variant = p.get("url")
		if not url is String or not ((url as String).begins_with("https://") or (url as String).begins_with("http://")):
			return "pack %s has no http(s) url" % name
		var size: Variant = p.get("size", 0)
		if not (size is int or size is float) or float(size) < 0.0:
			return "pack %s has a bad size" % name
	return ""

## Loads every pack listed in an installed.json dictionary. Returns false if any is missing.
static func apply_packs(inst: Dictionary) -> bool:
	var all_ok := true
	var file_re := RegEx.create_from_string(PACK_FILE_PATTERN)
	for p in inst.get("packs", []):
		if not p is Dictionary:
			continue
		if file_re.search(str(p.get("file", ""))) == null:
			print("[shell] refusing pack file %s" % str(p.get("file", "")).left(60))
			all_ok = false
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
