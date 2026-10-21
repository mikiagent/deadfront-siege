extends SceneTree
## SAILUI acceptance (spec 15 "The Sail menu"; docs/orchestration/mmo/islandmap-check.md package 1).
## The harbour opens the Sail chart, not the old list of text rows:
## - 15 nodes, Home first, in level order with x strictly growing by level; a sea at least twice the
##   view wide with no vertical scrolling; 64 px tap targets that never overlap, inside the safe area
##   (sail_lab.audit); Home + 5 in view at 1600x900 and 844x390, the Lv. 60 island after scrolling right.
## - A 400 px touch drag (with the phone's emulated mouse copy) and a 400 px mouse drag each scroll
##   400 +/- 10 px and do not open a card; the wheel scrolls; a tap opens the card; Escape closes the
##   card, then the chart.
## - Survival 0 locks all 14 islands (card says "Needs Survival N"); after a real voyage to
##   savannah_15 its node shows a check and the never-visited ones "?".
## - Sail on the card travels through World.travel(id, &"sail"): 5 T-stones charged, the island loads;
##   off home the header's Return to camp and Free return home work, and the return is free.
## Run: Godot --headless --path game --script res://tests/t_sailui.gd   -> "[t_sailui] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const VIEWS := [Vector2i(1600, 900), Vector2i(844, 390)]

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _world: Node
var _ui: CanvasLayer
var _player: Node
var _lab: GDScript
var _tally := Tally.new()

## Engine and script errors raised while the checks run fail the test (warnings do not).
class Tally extends Logger:
	var lines: PackedStringArray = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			lines.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_sailui] FAIL %s" % what)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	OS.add_logger(_tally)
	_lab = load("res://scripts/dev/sail_lab.gd")
	_world = root.get_node("World")
	(load("res://scripts/core/display_mode.gd") as GDScript).install(root)
	_host = Node3D.new()
	_host.name = "TSailHost"
	root.add_child(_host)
	var kit: Dictionary = (load("res://scripts/dev/lab_kit.gd") as GDScript).build(_host, 20.0)
	_player = kit["player"]
	_ui = (load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(_host)
	_world.home_terrain = &"meadow"
	_world.harvested.clear()
	_world.visited_islands.clear()
	_world.t_stones = 20
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 0), false)
	_player.global_position = _world.runtime.arrival_point() + Vector3.UP
	_player.skills.trees["survival"]["level"] = 0
	await _frames(2)
	for v in VIEWS:
		await _check_layout(v)
	await _check_locks()
	for v in VIEWS:
		await _check_scroll(v)
	await _check_travel()
	for line in _tally.lines:
		_expect(false, "engine error: %s" % line)
	if _fails.is_empty():
		print("[t_sailui] PASS")
		quit(0)
	else:
		print("[t_sailui] FAIL count=%d" % _fails.size())
		quit(1)

## Opens the harbour menu the way the dock does; null (and a FAIL) when it is not the Sail chart.
func _open() -> Control:
	_ui.show_harbour()
	await _frames(2)
	for n in _ui.find_children("*", "SailScreen", true, false):
		if not n.is_queued_for_deletion():
			return n as Control
	_expect(false, "the harbour opened no Sail chart (the old route list?)")
	return null

func _node(sail: Control, id: String) -> Control:
	return (sail.get("nodes") as Dictionary).get(id) as Control

func _check_layout(view: Vector2i) -> void:
	root.size = view
	await _frames(2)
	var sail: Control = await _open()
	if sail == null:
		return
	var tag := "%dx%d" % [view.x, view.y]
	_expect(sail.size.is_equal_approx(Vector2(view)), "%s chart fills the %s canvas (%s)" % [tag, view, sail.size])
	var r: Dictionary = _lab.audit(sail)
	_expect((r.problems as PackedStringArray).is_empty(), "%s layout: %s" % [tag, "; ".join(r.problems)])
	_expect(int(r.nodes) == 15, "%s one node per island: %d" % [tag, r.nodes])
	var order: PackedStringArray = r.order
	_expect(order.size() > 0 and order[0] == "home_grassland", "%s Home is the far-left node" % tag)
	var last := 0
	for id in order:
		var tier := int(_world.def_of(StringName(id)).get("tier", 0))
		_expect(tier >= last, "%s %s (Lv %d) sits right of a higher level (Lv %d)" % [tag, id, tier, last])
		last = tier
	var want := 6 if view.x >= 1600 else 4
	var shown: PackedStringArray = r.visible
	_expect(shown.size() >= want and shown.has("home_grassland"), "%s %d nodes in view without scrolling (want >= %d with Home): %s" % [tag, shown.size(), want, shown])
	_expect(float(r.ratio) >= 2.0, "%s sea is %.2fx the view" % [tag, r.ratio])
	sail.call("scroll_to", INF)
	await _frames(1)
	var right: Dictionary = _lab.audit(sail)
	_expect((right.visible as PackedStringArray).has("volcanic_60"), "%s scrolled right shows the Lv. 60 island" % tag)
	print("[t_sailui] %s content_w=%.0f (%.2fx) visible=%d %s order=%s" % [tag, r.content_w, r.ratio, shown.size(), shown, order])
	_ui.hide_all()
	await _frames(1)

func _check_locks() -> void:
	root.size = VIEWS[0]
	_player.skills.trees["survival"]["level"] = 0
	await _frames(2)
	var sail: Control = await _open()
	if sail == null:
		return
	var locks := 0
	for id in _world.harbour_routes():
		var n := _node(sail, id)
		if n == null:
			_expect(false, "no node for %s" % id)
			continue
		locks += 1 if bool(n.get("locked")) else 0
		_expect(int(n.get("need")) == int(_world.route_level(StringName(id))), "%s shows its real Survival gate" % id)
		_expect(str(n.call("badge")) == "?", "%s never visited shows '?' (got %s)" % [id, n.call("badge")])
	_expect(locks == 14, "Survival 0 locks all 14 islands (%d)" % locks)
	_expect(not bool(_node(sail, "home_grassland").get("locked")) and str(_node(sail, "home_grassland").call("badge")) == "check", "Home is open and checked")
	var go: Button = sail.call("route_button", &"temperate_20")
	_expect(go != null and go.disabled and go.text == "Needs Survival 15", "a locked card reads its requirement (%s)" % (go.text if go else "none"))
	_ui.hide_all()
	await _frames(1)

## Real input: a phone's touch sequence (Input sends the emulated mouse copy first, device -1), then
## a desktop mouse drag, then the wheel; a drag that starts on a node is not a tap.
func _check_scroll(view: Vector2i) -> void:
	root.size = view
	await _frames(2)
	var sail: Control = await _open()
	if sail == null:
		return
	var tag := "%dx%d" % [view.x, view.y]
	var node := _node(sail, "savannah_15")
	var start := node.get_global_rect().get_center()
	var before: float = sail.get("scroll_x")
	await _touch_drag(start, -400.0)
	var moved: float = float(sail.get("scroll_x")) - before
	_expect(absf(moved - 400.0) <= 10.0, "%s 400 px touch drag scrolls %.1f px" % [tag, moved])
	_expect(sail.get("card_id") == &"", "%s a drag from a node opens no card" % tag)
	before = sail.get("scroll_x")
	await _mouse_drag(_node(sail, "temperate_20").get_global_rect().get_center(), 400.0)
	moved = before - float(sail.get("scroll_x"))
	_expect(absf(moved - 400.0) <= 10.0, "%s 400 px mouse drag scrolls %.1f px" % [tag, moved])
	_expect(sail.get("card_id") == &"", "%s a mouse drag opens no card" % tag)
	before = sail.get("scroll_x")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.factor = 1.0
	wheel.position = (sail.call("view_rect") as Rect2).get_center()
	wheel.global_position = wheel.position
	root.push_input(wheel)
	await _frames(1)
	_expect(float(sail.get("scroll_x")) > before, "%s mouse wheel scrolls right" % tag)
	sail.call("scroll_to", 0.0)
	await _frames(1)
	await _touch_drag(_node(sail, "savannah_15").get_global_rect().get_center(), 0.0)
	_expect(sail.get("card_id") == &"savannah_15", "%s a touch tap opens the node's card (%s)" % [tag, sail.get("card_id")])
	print("[t_sailui] %s drags ok, scroll range 0..%.0f" % [tag, float(sail.get("content_w")) - (sail.call("view_rect") as Rect2).size.x])
	root.push_input(_cancel())
	await _frames(1)
	_expect(is_instance_valid(sail) and not sail.is_queued_for_deletion() and sail.get("card_id") == &"", "%s Escape closes the card first" % tag)
	root.push_input(_cancel())
	await _frames(1)
	_expect(not is_instance_valid(sail) or sail.is_queued_for_deletion(), "%s a second Escape closes the chart" % tag)
	_ui.hide_all()
	await _frames(1)

func _cancel() -> InputEventAction:
	var a := InputEventAction.new()
	a.action = &"ui_cancel"
	a.pressed = true
	return a

func _touch_drag(from: Vector2, dx: float) -> void:
	var steps := 20 if dx != 0.0 else 0
	var p := from
	_push_mouse(p, true, -1)
	_push_touch(p, true)
	await _frames(1)
	for i in steps:
		var rel := Vector2(dx / float(steps), 0.0)
		p += rel
		var mm := InputEventMouseMotion.new()
		mm.device = InputEvent.DEVICE_ID_EMULATION
		mm.position = p
		mm.global_position = p
		mm.relative = rel
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(mm)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = p
		drag.relative = rel
		root.push_input(drag)
		await _frames(1)
	_push_mouse(p, false, -1)
	_push_touch(p, false)
	await _frames(1)

func _mouse_drag(from: Vector2, dx: float) -> void:
	var p := from
	_push_mouse(p, true, 0)
	await _frames(1)
	for i in 20:
		var rel := Vector2(dx / 20.0, 0.0)
		p += rel
		var mm := InputEventMouseMotion.new()
		mm.position = p
		mm.global_position = p
		mm.relative = rel
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(mm)
		await _frames(1)
	_push_mouse(p, false, 0)
	await _frames(1)

func _push_mouse(p: Vector2, down: bool, device: int) -> void:
	var mb := InputEventMouseButton.new()
	mb.device = device
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = down
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	mb.position = p
	mb.global_position = p
	root.push_input(mb)

func _push_touch(p: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = down
	t.position = p
	root.push_input(t)

func _click(c: Control) -> void:
	var p := c.get_global_rect().get_center()
	_push_mouse(p, true, 0)
	await _frames(1)
	_push_mouse(p, false, 0)
	await _frames(1)

func _until_island(id: StringName) -> bool:
	for i in 240:
		if _world.island_id == id and _world.runtime != null:
			await _frames(30)  # the fade back in
			return true
		await process_frame
	return false

func _check_travel() -> void:
	root.size = VIEWS[0]
	_player.skills.trees["survival"]["level"] = 10
	_world.t_stones = 20
	await _frames(2)
	var sail: Control = await _open()
	if sail == null:
		return
	await _click(_node(sail, "temperate_20"))
	var blocked: Button = sail.get("card_action")
	_expect(sail.get("card_id") == &"temperate_20" and blocked != null and blocked.disabled, "tapping a locked island opens its card with Sail disabled")
	if blocked:
		await _click(blocked)
	_expect(_world.island_id == &"home_grassland" and _world.t_stones == 20, "a disabled Sail goes nowhere and charges nothing")
	await _click(_node(sail, "savannah_15"))
	var go: Button = sail.get("card_action")
	_expect(go != null and not go.disabled and go.text.begins_with("Sail"), "savannah_15's card offers Sail (%s)" % (go.text if go else "none"))
	if go == null:
		return
	await _click(go)
	_expect(await _until_island(&"savannah_15"), "Sail landed on savannah_15 (on %s)" % _world.island_id)
	_expect(_world.t_stones == 15, "Sail charged the route's 5 T-stones like World.travel(id, &\"sail\") (%d left)" % _world.t_stones)
	_expect(_world.visited_islands.has("savannah_15"), "the voyage is logged")
	sail = await _open()
	if sail == null:
		return
	_expect(str(_node(sail, "savannah_15").call("badge")) == "check" and bool(_node(sail, "savannah_15").get("here")), "after the voyage savannah_15 shows a check and the pin")
	var unknown := 0
	for id in _world.harbour_routes():
		if id != "savannah_15" and str(_node(sail, id).call("badge")) == "?":
			unknown += 1
	_expect(unknown == 13, "the 13 never-visited islands show '?' (%d)" % unknown)
	var camp: Button = sail.get("camp_button")
	var home: Button = sail.get("home_button")
	_expect(camp != null and home != null, "off home the header has Return to camp and Free return home")
	if camp == null or home == null:
		return
	_player.global_position = _world.runtime.arrival_point() + Vector3.UP
	await _click(camp)
	var c: Array = _world.island_def.get("camp", [0, 0, 8])
	var at := Vector2(_player.global_position.x, _player.global_position.z)
	_expect(at.distance_to(Vector2(float(c[0]), float(c[2]))) < 1.0, "Return to camp moved the survivor to camp (%s)" % at)
	_expect(_ui.find_children("*", "SailScreen", true, false).all(func (n: Node) -> bool: return n.is_queued_for_deletion()), "choosing closes the chart")
	sail = await _open()
	if sail == null:
		return
	await _click(sail.get("home_button"))
	_expect(await _until_island(&"home_grassland"), "Free return home landed home (on %s)" % _world.island_id)
	_expect(_world.t_stones == 15, "the return home was free (%d)" % _world.t_stones)
	print("[t_sailui] travel ok: home -> savannah_15 (20 -> 15 T) -> camp -> home (free)")
