class_name HexButton
extends Control
## Flat hexagon button used by station/gather radials and combat hexes (M8c contract).

signal pressed
signal long_pressed

const DEFAULT_SIZE := 64.0

var label_text: String = ""
var seconds_text: String = ""
var count_text: String = ""
var badge_text: String = ""
var badge_color: Color = Color(0.9, 0.2, 0.2, 0.95)
var icon: Texture2D
var glyph: String = ""
var enabled_look: bool = true
var cooldown: float = 0.0 ## 0..1 sweep remaining
var selected: bool = false

var _pressing: bool = false
var _long_armed: bool = false
var _long_left: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(DEFAULT_SIZE, DEFAULT_SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func setup(p_icon: Texture2D, p_glyph: String, p_label: String, p_seconds: String = "", p_count: String = "") -> void:
	icon = p_icon
	glyph = p_glyph
	label_text = p_label
	seconds_text = p_seconds
	count_text = p_count
	queue_redraw()

func set_blocked(hint: String) -> void:
	enabled_look = false
	badge_text = hint if hint != "" else "✕"
	badge_color = Color(0.9, 0.15, 0.15, 0.95)
	queue_redraw()

func set_ok_badge(hint: String, color: Color = Color(0.95, 0.8, 0.2, 0.95)) -> void:
	badge_text = hint
	badge_color = color
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressing = true
			_long_armed = true
			_long_left = 0.45
			queue_redraw()
		else:
			if _pressing and enabled_look:
				pressed.emit()
			_pressing = false
			_long_armed = false
			queue_redraw()
		accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pressing = true
			_long_armed = true
			_long_left = 0.45
			queue_redraw()
		else:
			if _pressing and enabled_look:
				pressed.emit()
			_pressing = false
			_long_armed = false
			queue_redraw()
		accept_event()

func _process(delta: float) -> void:
	if _long_armed and _pressing:
		_long_left -= delta
		if _long_left <= 0.0:
			_long_armed = false
			_pressing = false
			long_pressed.emit()
			queue_redraw()

func _draw() -> void:
	var r := mini(size.x, size.y) * 0.48
	var c := size * 0.5
	var fill := Color(0.12, 0.14, 0.16, 0.92)
	if selected:
		fill = Color(0.22, 0.28, 0.2, 0.95)
	if _pressing:
		fill = fill.lightened(0.12)
	if not enabled_look:
		fill = Color(0.18, 0.12, 0.12, 0.9)
	var pts := PackedVector2Array()
	for i in 6:
		var a := -PI * 0.5 + float(i) * TAU / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, fill)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.85, 0.88, 0.9, 0.55), 1.5, true)
	if cooldown > 0.001:
		draw_arc(c, r * 0.92, -PI * 0.5, -PI * 0.5 + TAU * clampf(cooldown, 0.0, 1.0), 32, Color(0.05, 0.05, 0.05, 0.55), 4.0, true)
	var font := ThemeDB.fallback_font
	if icon:
		var isz := Vector2(28, 28)
		draw_texture_rect(icon, Rect2(c - isz * 0.5 - Vector2(0, 4), isz), false)
	elif glyph != "" and font:
		draw_string(font, c + Vector2(0, 4), glyph, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(0.95, 0.95, 0.9))
	if font:
		if seconds_text != "":
			draw_string(font, c + Vector2(0, -r + 14), seconds_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(0.95, 0.95, 0.85))
		if count_text != "":
			draw_string(font, c + Vector2(0, r - 6), count_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(1, 1, 1, 0.95))
		if label_text != "":
			draw_string(font, c + Vector2(r + 6, 4), label_text, HORIZONTAL_ALIGNMENT_LEFT, 160.0, 12, Color(0.92, 0.94, 0.9))
		if badge_text != "":
			var br := Vector2(c.x + r * 0.55, c.y - r * 0.55)
			draw_circle(br, 10.0, badge_color)
			draw_string(font, br + Vector2(0, 4), badge_text.substr(0, 6), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 9, Color(1, 1, 1, 0.98))
