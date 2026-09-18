extends Control
## Downloader shell: sign in with an access code, fetch the build manifest, download the
## packs that changed, verify them, apply them in place and start the game.
## Desktop, --smoke and --lab runs skip straight to the game unless --shell is given.

const DEFAULT_HOST := "https://durango-builds.vercel.app"
const CFG_PATH := "user://shell.cfg"

var host: String = DEFAULT_HOST
var code: String = ""
var auto: bool = false
var manifest: Dictionary = {}
var _http: HTTPRequest
var _dl: HTTPRequest
var _queue: Array = []
var _current: Dictionary = {}
var _done_bytes: int = 0
var _total_bytes: int = 0
var _busy: bool = false

var _title: Label
var _installed: Label
var _status: Label
var _code_edit: LineEdit
var _update_btn: Button
var _play_btn: Button
var _bar: ProgressBar

func _ready() -> void:
	add_to_group("shell")
	var args := OS.get_cmdline_user_args()
	var forced := "--shell" in args
	var skip := "--smoke" in args or "--shot=" in "".join(args)
	for a in args:
		if a.begins_with("--lab="):
			skip = true
		elif a.begins_with("--host="):
			host = a.substr(7)
		elif a.begins_with("--code="):
			code = a.substr(7)
		elif a == "--shell-auto":
			auto = true
	if skip or (not forced and not OS.has_feature("mobile")):
		print("[shell] skipped (%s)" % ("smoke/lab" if skip else "desktop"))
		call_deferred("_enter_game")
		return
	_load_cfg()
	_set_touch_layer(false)
	_build_ui()
	_refresh_labels()
	if ShellLoader.safe_mode:
		_status.text = "The last update failed to start. Running the built-in build; update again."
	if auto:
		_on_update()
	elif code != "" and not ShellLoader.safe_mode:
		_status.text = "Signed in. Checking for updates…"
		_on_update()

# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 18)
	centre.add_child(box)
	_title = Label.new()
	_title.text = "Durango-like"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	box.add_child(_title)
	_installed = Label.new()
	_installed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_installed.add_theme_font_size_override("font_size", 20)
	_installed.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	box.add_child(_installed)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Access code"
	_code_edit.text = code
	_code_edit.custom_minimum_size = Vector2(0, 64)
	_code_edit.add_theme_font_size_override("font_size", 24)
	_code_edit.text_submitted.connect(func (_t: String) -> void: _on_update())
	box.add_child(_code_edit)
	_update_btn = Button.new()
	_update_btn.text = "Sign in & update"
	_update_btn.custom_minimum_size = Vector2(0, 72)
	_update_btn.add_theme_font_size_override("font_size", 26)
	_update_btn.pressed.connect(_on_update)
	box.add_child(_update_btn)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 28)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.visible = false
	box.add_child(_bar)
	_status = Label.new()
	_status.text = "Enter your access code to download the latest build."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 20)
	box.add_child(_status)
	_play_btn = Button.new()
	_play_btn.text = "Play installed build"
	_play_btn.custom_minimum_size = Vector2(0, 64)
	_play_btn.add_theme_font_size_override("font_size", 22)
	_play_btn.pressed.connect(func () -> void: call_deferred("_enter_game"))
	box.add_child(_play_btn)
	var foot := Label.new()
	foot.text = "shell v%d  ·  %s" % [ShellLoader.SHELL_VERSION, host.trim_prefix("https://")]
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 14)
	foot.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	box.add_child(foot)

func _refresh_labels() -> void:
	_installed.text = "Installed: %s" % ShellLoader.installed_version()

func _set_status(t: String) -> void:
	print("[shell] %s" % t)
	if _status:
		_status.text = t

# ---------------------------------------------------------------- sign in + manifest

func _on_update() -> void:
	if _busy:
		return
	if _code_edit:
		code = _code_edit.text.strip_edges()
	if code == "":
		_set_status("Enter your access code.")
		return
	_busy = true
	_update_btn.disabled = true
	_set_status("Signing in…")
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_manifest)
	var url := "%s/api/manifest?platform=%s&shell=%d" % [host, OS.get_name().to_lower(), ShellLoader.SHELL_VERSION]
	var err := _http.request(url, PackedStringArray(["X-Access-Code: %s" % code]))
	if err != OK:
		_fail("Could not start the request (%d)." % err)

func _on_manifest(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("No connection to the build server (%d)." % result)
		return
	if response_code == 401 or response_code == 403:
		_fail("Access code rejected.")
		return
	if response_code != 200:
		_fail("Build server answered %d." % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("Bad manifest.")
		return
	manifest = parsed
	_save_cfg()
	if int(manifest.get("min_shell", 1)) > ShellLoader.SHELL_VERSION:
		_fail("This build needs a newer app. Update from TestFlight.")
		return
	var ver := str(manifest.get("version", "?"))
	var installed := ShellLoader.read_installed()
	var have: Dictionary = {}
	for p in installed.get("packs", []):
		if p is Dictionary:
			have[str(p.get("name", ""))] = p
	_queue.clear()
	_total_bytes = 0
	for p in manifest.get("packs", []):
		if not p is Dictionary:
			continue
		var prev: Dictionary = have.get(str(p.get("name", "")), {})
		var file := "%s-%s.pck" % [p.get("name", "pack"), str(p.get("sha256", "")).substr(0, 8)]
		var path := "%s/%s" % [ShellLoader.BUILDS_DIR, file]
		if str(prev.get("sha256", "")) == str(p.get("sha256", "")) and FileAccess.file_exists(path):
			continue
		_queue.append(p)
		_total_bytes += int(p.get("size", 0))
	if _queue.is_empty():
		if str(installed.get("version", "")) == ver and not ShellLoader.applied.is_empty():
			_set_status("Up to date (%s)." % ver)
			_finish_no_change()
			return
		# Same files, new version label (or built-in build already matches): record and apply.
		_apply(ver)
		return
	_set_status("Downloading %s (%s)…" % [ver, String.humanize_size(_total_bytes)])
	_bar.visible = true
	_bar.value = 0.0
	_done_bytes = 0
	_next_download()

# ---------------------------------------------------------------- downloads

func _next_download() -> void:
	if _queue.is_empty():
		_apply(str(manifest.get("version", "?")))
		return
	_current = _queue.pop_front()
	var file := "%s-%s.pck" % [_current.get("name", "pack"), str(_current.get("sha256", "")).substr(0, 8)]
	var part := "%s/%s.part" % [ShellLoader.BUILDS_DIR, file]
	if FileAccess.file_exists(part):
		DirAccess.remove_absolute(part)
	_dl = HTTPRequest.new()
	_dl.use_threads = true
	_dl.download_file = ProjectSettings.globalize_path(part)
	_dl.timeout = 0.0
	add_child(_dl)
	_dl.request_completed.connect(_on_pack_done.bind(part, file))
	var err := _dl.request(str(_current.get("url", "")))
	if err != OK:
		_fail("Could not start download (%d)." % err)

func _process(_delta: float) -> void:
	if _dl == null or not is_instance_valid(_dl) or _bar == null:
		return
	var got := _dl.get_downloaded_bytes()
	var total := _total_bytes if _total_bytes > 0 else maxi(1, _dl.get_body_size())
	_bar.value = clampf(float(_done_bytes + got) / float(total), 0.0, 1.0)
	_status.text = "Downloading %s… %s / %s" % [
		_current.get("name", "pack"), String.humanize_size(_done_bytes + got), String.humanize_size(total)]

func _on_pack_done(result: int, response_code: int, _h: PackedStringArray, _b: PackedByteArray, part: String, file: String) -> void:
	_dl.queue_free()
	_dl = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_fail("Download of %s failed (%d/%d)." % [_current.get("name", "pack"), result, response_code])
		return
	var want := str(_current.get("sha256", ""))
	var got := FileAccess.get_sha256(part)
	if want != "" and got != want:
		DirAccess.remove_absolute(part)
		_fail("Checksum mismatch for %s; try again." % _current.get("name", "pack"))
		return
	var final := "%s/%s" % [ShellLoader.BUILDS_DIR, file]
	if FileAccess.file_exists(final):
		DirAccess.remove_absolute(final)
	DirAccess.rename_absolute(part, final)
	_done_bytes += int(_current.get("size", 0))
	print("[shell] downloaded %s sha=%s" % [file, got.substr(0, 8)])
	_next_download()

# ---------------------------------------------------------------- apply

func _apply(version: String) -> void:
	var inst := {"version": version, "packs": []}
	var keep: Dictionary = {}
	for p in manifest.get("packs", []):
		if not p is Dictionary:
			continue
		var file := "%s-%s.pck" % [p.get("name", "pack"), str(p.get("sha256", "")).substr(0, 8)]
		inst["packs"].append({"name": p.get("name", "pack"), "file": file, "sha256": p.get("sha256", "")})
		keep[file] = true
	_prune(keep)
	ShellLoader.write_installed(inst)
	if not ShellLoader.applied.is_empty() and str(ShellLoader.applied.get("version", "")) == version:
		_finish_no_change()
		return
	_set_status("Applying %s…" % version)
	if not ShellLoader.apply_packs(inst):
		_fail("A pack could not be loaded. Restart the app.")
		return
	_reload_cached_resources()
	# Autoload singletons keep their identity (other scripts hold the original objects);
	# their scripts were refreshed in place above, so reset each one and run _ready again.
	_reinit_autoloads(["InputSetup", "Data", "Game"])
	ShellLoader.applied = inst
	_refresh_labels()
	_set_status("Build %s ready." % version)
	_enter_game()
	_reinit_autoloads(["TouchControls", "World"])

func _finish_no_change() -> void:
	_busy = false
	_update_btn.disabled = false
	_bar.visible = false
	call_deferred("_enter_game")

func _prune(keep: Dictionary) -> void:
	var da := DirAccess.open(ShellLoader.BUILDS_DIR)
	if da == null:
		return
	for f in da.get_files():
		if f.ends_with(".pck") and not keep.has(f):
			da.remove(f)

## Scripts and scenes the shell already loaded (autoloads and their dependencies) are
## cached as the built-in versions. CACHE_MODE_IGNORE makes GDScript re-read a script
## from disk (now the pack) and reload it in place, so existing instances run the new
## code; scenes are replaced in the cache.
func _reload_cached_resources() -> void:
	var n := 0
	for root in ["res://scripts", "res://scenes"]:
		for path in _walk(root):
			if not ResourceLoader.has_cached(path):
				continue
			var mode := ResourceLoader.CACHE_MODE_IGNORE if path.ends_with(".gd") else ResourceLoader.CACHE_MODE_REPLACE
			ResourceLoader.load(path, "", mode)
			n += 1
	print("[shell] refreshed %d cached resources" % n)

func _walk(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var f := da.get_next()
	while f != "":
		if da.current_is_dir():
			if not f.begins_with("."):
				out.append_array(_walk("%s/%s" % [dir, f]))
		elif f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			out.append("%s/%s" % [dir, f])
		f = da.get_next()
	da.list_dir_end()
	return out

## Reset an autoload node in place: drop what its old _ready built, re-attach its (now
## reloaded) script so member defaults run again, then call _ready.
func _reinit_autoloads(names: Array) -> void:
	# May run after the shell left the tree, so go through the main loop, not get_tree().
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	for name: String in names:
		var node := root.get_node_or_null(name)
		if node == null:
			continue
		var script: Script = node.get_script()
		if script == null:
			continue
		for c in root.size_changed.get_connections():
			var cb: Callable = c["callable"]
			if cb.get_object() == node:
				root.size_changed.disconnect(cb)
		for c in node.get_children():
			node.remove_child(c)
			c.free()
		var fresh: Script = ResourceLoader.load(script.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		node.set_script(null)
		node.set_script(fresh if fresh else script)
		if node.has_method("_ready"):
			node._ready()
		print("[shell] autoload %s re-initialised" % name)

## Immediate scene swap (not deferred) so World's deferred boot sees the game scene.
## The game's touch layer (an autoload) must not float over the shell screen.
func _set_touch_layer(shown: bool) -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var tc := root.get_node_or_null("TouchControls")
	if tc is CanvasLayer:
		(tc as CanvasLayer).visible = shown

func _enter_game() -> void:
	_set_touch_layer(true)
	var packed := ResourceLoader.load("res://scenes/main.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if packed == null:
		_fail("Game scene missing.")
		return
	var inst := packed.instantiate()
	var tree := get_tree()
	var root := tree.root
	root.remove_child(self)
	root.add_child(inst)
	tree.current_scene = inst
	# World skipped its boot while the shell was the current scene.
	if root.has_node("World") and root.get_node("World").has_method("_boot"):
		root.get_node("World").call_deferred("_boot")
	queue_free()

func _fail(msg: String) -> void:
	_busy = false
	if _update_btn:
		_update_btn.disabled = false
	if _bar:
		_bar.visible = false
	_set_status(msg)
	if auto:
		get_tree().quit(2)

# ---------------------------------------------------------------- config

func _load_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		if code == "":
			code = str(cfg.get_value("shell", "code", ""))
		if "--host=" not in "".join(OS.get_cmdline_user_args()):
			host = str(cfg.get_value("shell", "host", host))

func _save_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG_PATH)
	cfg.set_value("shell", "code", code)
	cfg.set_value("shell", "host", host)
	cfg.save(CFG_PATH)
