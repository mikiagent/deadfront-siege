class_name DisplayMode
extends RefCounted
## Fullscreen on desktop and in the browser. On the web the request must come from a user input
## event (a key press or a click), which is where every caller here runs.

static func is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

static func set_fullscreen(on: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)

static func toggle() -> void:
	var target := not is_fullscreen()
	print("[display] fullscreen request -> %s" % ("on" if target else "off"))
	set_fullscreen(target)

static func label() -> String:
	return "Exit full screen" if is_fullscreen() else "Full screen"
