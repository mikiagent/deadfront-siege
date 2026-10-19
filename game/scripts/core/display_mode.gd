class_name DisplayMode
extends RefCounted
## Fullscreen on desktop and in the browser. On the web the request must come from a user input
## event (a key press or a click), which is where every caller here runs.
## Also owns the logical canvas size: see logical_size().

## The design canvas every desktop screen is laid out for (project.godot viewport size).
const DESIGN := Vector2i(1600, 900)
## Same threshold as UiTokens.is_phone: narrower than this in points is a phone.
const PHONE_MAX_PT := 720.0

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

## Logical canvas for a window. The project stretches a 1600x900 canvas (aspect expand), which on a
## 390-pt phone drew the HUD at 24 % and left every is_phone branch dead. A portrait phone now gets
## one logical px per point, so text keeps its designed size; everything else keeps 1600x900.
## shortcut: landscape phones and portrait tablets still get the design canvas; give them their own
## rule when a device test shows text below the 12 px floor there.
static func logical_size(window_px: Vector2i, device_scale: float) -> Vector2i:
	var pts := Vector2(window_px) / maxf(1.0, device_scale)
	if pts.x > 0.0 and pts.x < PHONE_MAX_PT and pts.y > pts.x:
		return Vector2i(roundi(pts.x), roundi(pts.y))
	return DESIGN

## Device pixels per point. Desktop windows are sized in pixels (--resolution, the window manager),
## so only the browser and touch devices report a ratio worth dividing by.
static func device_scale() -> float:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return maxf(1.0, DisplayServer.screen_get_scale())
	return 1.0

## Window size in points, the input logical_size() decides on. Screens that pick a layout by the
## physical shape (a landscape phone keeps the 1600x900 canvas) use this, not the logical canvas.
static func window_points(win: Window) -> Vector2:
	if win == null:
		return Vector2.ZERO
	return Vector2(win.size) / device_scale()

## A phone held sideways: short (<= 500 pt) and wide (>= 1.75:1). It keeps the design canvas, so
## text drawn at desktop sizes lands under 12 pt; screens scale their type up for it.
static func is_phone_landscape(pts: Vector2) -> bool:
	return pts.y > 0.0 and pts.y <= 500.0 and pts.x / pts.y >= 1.75

## A window narrower than a phone, in points: the canvas fit must make UiTokens.is_phone true
## there and text must stay at least UiTokens.TYPE_MIN.
static func is_phone_window(pts: Vector2) -> bool:
	return pts.x > 0.0 and pts.x < PHONE_MAX_PT

static func fit(win: Window) -> void:
	if win == null:
		return
	var want := logical_size(win.size, device_scale())
	if win.content_scale_size != want:
		win.content_scale_size = want
		print("[display] window %s -> logical %s" % [win.size, want])

## Fit now and on every resize or rotation. Call once with the root window at boot.
static func install(win: Window) -> void:
	if win == null:
		return
	fit(win)
	if not win.has_meta(&"display_mode_fit"):
		win.set_meta(&"display_mode_fit", true)
		win.size_changed.connect(func () -> void: fit(win))
