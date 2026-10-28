extends SceneTree
## NAVZOOM acceptance (scripts/ui/menu_transition.gd), on the home island with the real HUD: opening the nav
## menu eases the camera out to ZOOM x its distance over DURATION with clouds up; closing restores the exact
## prior zoom, distance and angle (also mid-transition, from a player zoom, and on reopen during the close);
## a full-screen sheet's backdrop gives the lighter version while shown; the follow keeps tracking; 20
## toggles leave no nodes behind.
## Usage: godot --headless --path game --script res://tests/t_navzoom.gd -> "[t_navzoom] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var _cam
var _mt: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_navzoom] %s %s" % ["ok" if ok else "FAIL", what])

func _wait(s: float) -> void:
	await create_timer(s).timeout
	await process_frame

func _open() -> void:
	_hud._close_sheet()
	_hud._toggle_sheet(&"menu")
	await process_frame

func _close() -> void:
	_hud._close_sheet()
	await process_frame

func _trans():
	return _mt.call("of", _cam)

func _run() -> void:
	_mt = load("res://scripts/ui/menu_transition.gd")
	_host = Node3D.new()
	_host.name = "TNavzoomHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("hands_spot"):
			_hud = c
	root.get_node("World").load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(0.2)
	var zoom: float = _mt.get("ZOOM")
	var dur: float = _mt.get("DURATION")
	var base: float = _cam.size
	var dist0: float = _cam.distance
	var rot0: Vector3 = _cam.rotation
	# Open: eases out over the duration, clouds up.
	await _open()
	_expect(_trans() != null and _trans().clouds != null, "opening starts the transition with clouds")
	await _wait(dur * 0.4)
	var mid: float = _cam.distance
	_expect(mid > dist0 * 1.02 and mid < dist0 * zoom * 0.98, "mid-open distance between (%.1f < %.1f < %.1f)" % [dist0, mid, dist0 * zoom])
	await _wait(dur * 0.7)
	_expect(absf(_cam.distance - dist0 * zoom) < 0.01, "open reaches %.2fx distance (%.2f / %.2f)" % [zoom, _cam.distance, dist0 * zoom])
	_expect(_cam.rotation.is_equal_approx(rot0), "the view angle never changes")
	# Close: exact restore, clouds gone.
	await _close()
	await _wait(dur + 0.1)
	_expect(_cam.size == base and _cam.distance == dist0 and _cam.rotation == rot0, "close restores the exact zoom %.3f, distance %.3f (got %.3f, %.3f)" % [base, dist0, _cam.size, _cam.distance])
	_expect(_trans() == null and _cam.get_node_or_null("MenuTransition") == null, "clouds exist only while open")
	# Closed mid-transition.
	await _open()
	await _wait(dur * 0.3)
	await _close()
	await _wait(dur + 0.1)
	_expect(_cam.size == base and _trans() == null, "mid-transition close restores exactly (%.4f)" % _cam.size)
	# Reopened during the close: no compounding.
	await _open()
	await _wait(dur + 0.1)
	await _close()
	await _wait(dur * 0.3)
	await _open()
	await _wait(dur + 0.1)
	_expect(absf(_cam.size - base * zoom) < 0.001, "reopen mid-close goes back to %.2fx, not further (%.3f)" % [zoom, _cam.size])
	await _close()
	await _wait(dur + 0.1)
	_expect(_cam.size == base, "and closes to the prior zoom")
	# The player had zoomed in.
	_cam.size = 9.0
	await _wait(0.1)
	var d9: float = _cam.distance
	await _open()
	await _wait(dur + 0.1)
	_expect(absf(_cam.size - 9.0 * zoom) < 0.001, "zooms out from the player's zoom (%.3f)" % _cam.size)
	# The follow keeps tracking behind the menu (it is not a pause).
	_player.global_position += Vector3(4, 0, 0)
	await _wait(1.0)
	var f: Vector3 = _cam.focus_point()
	_expect(Vector2(f.x - _player.global_position.x, f.z - _player.global_position.z).length() < 0.5, "camera follows the survivor while the menu is up")
	await _close()
	await _wait(dur + 0.1)
	_expect(_cam.size == 9.0 and _cam.distance == d9, "close restores the player's zoom exactly (%.4f)" % _cam.size)
	_cam.size = base
	await _wait(0.1)
	# A sheet's backdrop: lighter, held while shown, released when hidden.
	var sheet := Control.new()
	sheet.visible = false
	sheet.add_child(load("res://scripts/ui/sheet_chrome.gd").call("backdrop"))
	_hud.add_child(sheet)
	await _wait(0.1)
	_expect(_trans() == null, "a hidden sheet holds nothing")
	sheet.visible = true
	await _wait(dur + 0.1)
	var light: float = 1.0 + (zoom - 1.0) * float(_mt.get("SHEET_STRENGTH"))
	_expect(absf(_cam.size - base * light) < 0.001, "a full-screen sheet gives the lighter %.2fx (%.3f)" % [light, _cam.size])
	sheet.visible = false
	await _wait(dur + 0.1)
	_expect(_cam.size == base and _trans() == null, "hiding the sheet restores exactly")
	sheet.queue_free()
	await _wait(0.1)
	# 20 toggles, odd timings: no node growth, exact zoom.
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for i in 20:
		await _open()
		await _wait(0.03 * float(i % 5))
		await _close()
		await _wait(0.02 * float(i % 3))
	await _wait(dur + 0.2)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_expect(nodes1 <= nodes0, "no node growth after 20 toggles (%d -> %d)" % [nodes0, nodes1])
	_expect(_cam.size == base and _trans() == null, "20 toggles end on the exact zoom (%.4f)" % _cam.size)
	if _fails.is_empty():
		print("[t_navzoom] PASS")
		quit(0)
	else:
		print("[t_navzoom] FAIL count=%d" % _fails.size())
		quit(1)
