extends SceneTree
## LOADING (owner 2026-10-30: "we don't have loading ... add loading screens in between"): the overlay
## shows on an island load and on travel, its bar follows the build's stages to 1.0 and it hides after;
## its tips come from data/ui/loading_tips.json; no input reaches the world while it is up.
## Run: Godot --headless --path game --script res://tests/t_loading.gd -> "[t_loading] PASS".

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var W: Node
var LS: GDScript

## Records what reaches the world's input stages (after the overlay's _input and the GUI).
class Probe extends Node:
	var got := 0
	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS  # a block must come from the overlay, not the pause
	func _unhandled_input(_e: InputEvent) -> void:
		got += 1
	func _shortcut_input(_e: InputEvent) -> void:
		got += 1

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_loading] FAIL %s" % what)
	else:
		print("[t_loading] ok %s" % what)

func _run() -> void:
	var watchdog := create_timer(600.0)
	watchdog.timeout.connect(func () -> void:
		print("[t_loading] FAIL watchdog")
		quit(2))
	W = root.get_node("World")
	LS = load("res://scripts/ui/loading_screen.gd")
	for n in get_nodes_in_group(&"character_creation"):
		n.free()
	for n in root.get_children():
		if n.name == "CharacterCreation":
			n.free()
	_host = Node3D.new()
	_host.name = "TLoadingHost"
	root.add_child(_host)
	load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	await process_frame
	W.finish_creation()
	_test_tips()
	await _test_input_block()
	await _test_island_load()
	await _test_travel()
	if _fails.is_empty():
		print("[t_loading] PASS")
		quit(0)
	else:
		print("[t_loading] FAILED %d: %s" % [_fails.size(), "; ".join(_fails)])
		quit(1)

func _test_tips() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/loading_tips.json"))
	var want: Array[String] = []
	for row in (parsed as Dictionary).get("tips", []):
		want.append(str(row["text"]))
	var tips: Array[String] = LS.call("tips")
	_expect(want.size() >= 5 and tips == want, "tips are the data file's rows (%d)" % tips.size())
	var ls = LS.call("open", "Tip check")
	_expect(want.has(ls.tip_text()), "the overlay shows a data tip: \"%s\"" % ls.tip_text())
	ls.finish()

func _test_input_block() -> void:
	var probe := Probe.new()
	root.add_child(probe)
	var ls = LS.call("open", "Input check")
	_expect(paused, "the tree is paused while the overlay is up")
	_expect(ls.layer >= 128, "the overlay sits above every other layer (%d)" % ls.layer)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	root.push_input(key)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = Vector2(400, 300)
	root.push_input(tap)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(400, 300)
	root.push_input(touch)
	_expect(probe.got == 0, "no key, click or touch reaches the world while loading (got %d)" % probe.got)
	ls.finish()
	_expect(not paused, "the tree runs again once the overlay is gone")
	key.pressed = false
	root.push_input(key)
	_expect(probe.got > 0, "control: the same probe hears input once the overlay is gone (got %d)" % probe.got)
	probe.queue_free()
	await process_frame

func _test_island_load() -> void:
	var seen: Array[float] = []
	var mid := [0.0, false]
	await LS.call("run", "Entering the Test Isle", func () -> void:
		W.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
		mid[0] = float(LS.get("current").progress)
		mid[1] = bool(LS.call("active")))
	_expect(mid[1], "the overlay is up while the island builds")
	_expect(float(mid[0]) >= 0.9, "the build's stages moved the bar to %.2f before the run finished" % float(mid[0]))
	_expect(float(LS.get("last_progress")) == 1.0, "the bar reaches 1.0 (%.2f)" % float(LS.get("last_progress")))
	_expect(not bool(LS.call("active")), "the overlay hides after the load")
	_expect(root.get_node_or_null("LoadingScreen") == null, "no overlay node is left in the tree")
	_expect(W.runtime != null and str(W.island_id) == "home_grassland", "the island loaded under the overlay")
	await process_frame

func _test_travel() -> void:
	var before := (LS.get("shown") as Array).size()
	var dest := str(W.def_of(&"savannah_15").get("display_name", ""))
	await W.travel(&"savannah_15", &"test")
	var shown: Array = LS.get("shown")
	_expect(shown.size() > before and str(shown.back()) == "Sailing to %s" % dest, "travel shows \"Sailing to %s\" (got %s)" % [dest, shown.slice(before)])
	_expect(str(W.island_id) == "savannah_15", "travel arrived (%s)" % W.island_id)
	_expect(float(LS.get("last_progress")) == 1.0 and not bool(LS.call("active")), "the travel overlay reached 1.0 and hid")
	_expect(not paused, "the world runs after travel")
