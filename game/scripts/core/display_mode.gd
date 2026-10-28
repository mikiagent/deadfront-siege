class_name DisplayMode
extends RefCounted
## Fullscreen on desktop and in the browser. On the web the request must come from a user input
## event (a key press or a click), which is where every caller here runs.
## Also owns the logical canvas size: see logical_size().

## The design canvas every desktop screen is laid out for (project.godot viewport size).
const DESIGN := Vector2i(1600, 900)
## Same threshold as UiTokens.is_phone / is_narrow: narrower than this in points is a phone.
const PHONE_MAX_PT := 720.0
## Narrowest usable (inside the safe area) landscape phone canvas. The protected screens' landscape
## (desktop) rows need it: the bag's three columns about 804 px, the HUD's vitals + quest card +
## minimap about 740. A narrower phone (iPhone SE 667x375, 640x360 Androids, a notched iPhone once
## its side insets are off) gets this width at a smaller scale (12 px = 10 pt on an SE) instead of a
## 1:1 canvas, where is_phone would send the HUD and bag into their portrait rows, or a 760 px one,
## where the bag's equipment column and close button ran off the right edge.
## ASSUMPTION: 10 pt smallest text on the narrowest phones beats clipped or overlapping screens;
## lower this once W2-HUD / W2-SCREENS make those rows narrower.
const LANDSCAPE_MIN_W := 804.0
## Smallest share of a landscape phone's width the safe area may leave (logical_size clamps to it).
const MIN_USABLE := 0.75
## Portrait windows narrower than this (iPad mini 768, iPad Air 820) are tablets.
const TABLET_MAX_PT := 1100.0
const TABLET_W := 1000

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
## 390-pt-tall phone drew the HUD at 24 % and left every phone branch dead. Phones get one logical
## px per point, so the 12 px type floor is 12 pt on the glass and UiTokens.is_compact holds
## (narrow when portrait, short when landscape, the shipped orientation); landscape phones narrower
## than LANDSCAPE_MIN_W are scaled up to it. Portrait tablets get a TABLET_W-wide canvas, so desktop
## layouts keep their columns at ~0.8 scale instead of 0.48. Everything else keeps 1600x900.
## `inset_px`: left + right safe-area insets in window px (a notch in landscape).
## `handheld`: false for a desktop browser (no touchscreen), whose short wide window is not a phone.
static func logical_size(window_px: Vector2i, device_scale: float, inset_px: float = 0.0, handheld: bool = true) -> Vector2i:
	var pts := Vector2(window_px) / maxf(1.0, device_scale)
	if pts.x <= 0.0 or pts.y <= 0.0:
		return DESIGN
	if handheld and is_phone_landscape(pts):
		# Clamped: an empty safe area at boot, or the other orientation's, reads as a huge inset and
		# would shrink the whole UI to dust. Real notches take well under a quarter of the width.
		var usable := clampf(pts.x - inset_px / maxf(1.0, device_scale), pts.x * MIN_USABLE, pts.x)
		var k := maxf(1.0, LANDSCAPE_MIN_W / usable)
		return Vector2i(roundi(pts.x * k), roundi(pts.y * k))
	if pts.x < PHONE_MAX_PT:
		return Vector2i(roundi(pts.x), roundi(pts.y))
	if pts.y > pts.x and pts.x < TABLET_MAX_PT:
		return Vector2i(TABLET_W, roundi(pts.y * float(TABLET_W) / pts.x))
	return DESIGN

## Device pixels per point. Desktop windows are sized in pixels (--resolution, the window manager),
## so only the browser and touch devices report a ratio worth dividing by.
static func device_scale() -> float:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return maxf(1.0, DisplayServer.screen_get_scale())
	return 1.0

## Window size in points, the input logical_size() decides on (and the unit the lab's type floor is in).
static func window_points(win: Window) -> Vector2:
	if win == null:
		return Vector2.ZERO
	return Vector2(win.size) / device_scale()

## The canvas fit() gives this window, whether or not install() ran: screens that must look right
## before the boot hook lands lay out for this and scale by (actual canvas / this).
static func fitted_size(win: Window) -> Vector2:
	return Vector2(logical_size(win.size, device_scale(), side_inset_px(), handheld())) if win else Vector2(DESIGN)

## Can this be a phone held sideways? A desktop browser window 1200x480 is short and wide too, and
## got the phone layouts; on the web it takes a touchscreen. Native windows keep the shape rule, so
## --resolution 844x390 still stands in for a phone in the labs.
# ASSUMPTION: a web page without a touchscreen is a desktop; a touch laptop gets phone layouts when short.
static func handheld() -> bool:
	return OS.has_feature("mobile") or not OS.has_feature("web") or DisplayServer.is_touchscreen_available()

## Left + right safe-area insets of the window, in window px; 0 off mobile (desktop and browser
## windows report the screen's work area, not a notch).
static func side_inset_px() -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return 0.0  # not reported yet (boot): no notch beats a full-width one
	var w := float(DisplayServer.window_get_size().x)
	return maxf(0.0, float(safe.position.x)) + maxf(0.0, w - float(safe.end.x))

## A phone held sideways: short (under UiTokens.SHORT_MAX pt) and wide (>= 1.75:1), the shipped handheld orientation
## (project.godot sensor landscape). logical_size() gives it a 1:1 canvas.
static func is_phone_landscape(pts: Vector2) -> bool:
	return pts.y > 0.0 and pts.y < UiTokens.SHORT_MAX and pts.x / pts.y >= 1.75

## A window narrower than a phone, in points: the canvas fit must make UiTokens.is_compact true
## there and text must stay at least UiTokens.TYPE_MIN logical px.
static func is_phone_window(pts: Vector2) -> bool:
	return pts.x > 0.0 and pts.x < PHONE_MAX_PT

## Dev only (ui_screens_lab): a fixed logical canvas, so a 2x window renders the phone layout sharp.
static var canvas_override := Vector2i.ZERO

static func fit(win: Window) -> void:
	if win == null:
		return
	var want := canvas_override if canvas_override != Vector2i.ZERO else logical_size(win.size, device_scale(), side_inset_px(), handheld())
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

## The token Theme lives here, beside the canvas fit: both are what boot installs on the root.
static var _theme_installed := false

## One Theme from these tokens: ink panels, teal selection and a teal focus ring (keyboard and
## controller users can see where they are), 16 px body type.
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	var normal := UiTokens.button_style(false)
	var hover := UiTokens.button_style(false)
	hover.bg_color = hover.bg_color.lightened(0.08)
	hover.border_color = UiTokens.META
	var pressed := UiTokens.button_style(true)
	var disabled := UiTokens.button_style(false)
	disabled.bg_color = Color(0.07, 0.075, 0.085, 0.9)
	disabled.border_color = Color(UiTokens.DIVIDER, 0.3)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UiTokens.TEAL
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(UiTokens.RADIUS)
	focus.set_expand_margin_all(2.0)
	for kind in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, hover)
		t.set_stylebox("pressed", kind, pressed)
		t.set_stylebox("hover_pressed", kind, pressed)
		t.set_stylebox("disabled", kind, disabled)
		t.set_stylebox("focus", kind, focus)
		t.set_color("font_color", kind, UiTokens.TEXT)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, Color.WHITE)
		t.set_color("font_focus_color", kind, Color.WHITE)
		t.set_color("font_disabled_color", kind, Color(UiTokens.META, 0.55))
		t.set_font_size("font_size", kind, 16)
	t.set_color("font_color", "Label", UiTokens.TEXT)
	t.set_font_size("font_size", "Label", 16)
	t.set_stylebox("panel", "PanelContainer", UiTokens.panel_style())
	t.set_stylebox("panel", "Panel", UiTokens.panel_style())
	var field := UiTokens.slot_style(false)
	field.content_margin_left = UiTokens.SPACE
	field.content_margin_right = UiTokens.SPACE
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_color("font_color", "LineEdit", UiTokens.TEXT)
	t.set_font_size("font_size", "LineEdit", 16)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)  # visible on ink panels even when the bar is empty
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTokens.TEAL
	fill.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", track)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font_size("font_size", "ProgressBar", UiTokens.TYPE_MIN)
	return t

## Merge the token theme into the engine default theme, so every Control picks it up, including
## those under CanvasLayers (a theme on the root Window does not reach them). Idempotent.
static func install_theme() -> void:
	if _theme_installed:
		return
	var base := ThemeDB.get_default_theme()
	if base == null:
		return
	base.merge_with(build_theme())
	_theme_installed = true
	print("[ui] theme installed")
