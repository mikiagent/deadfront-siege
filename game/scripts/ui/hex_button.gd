class_name HexButton
extends Control
## Durango-style hexagonal button: dark hex with a light rim, an icon or glyph in the
## middle, small text above (time) and below (count). Fires `pressed` on tap.
## Also used by the HUD skill cluster (M8c). Minimum 64 px across.

signal pressed

var icon: Texture2D
var glyph: String = ""
var top_text: String = ""
var bottom_text: String = ""
var disabled: bool = false
var accent: Color = Color(0.95, 0.95, 0.95)
var fill: Color = Color(0.07, 0.08, 0.09, 0.93)
var badge: String = ""  # e.g. "⊘" when blocked
var _down: bool = false

func _init(size_px: float = 72.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5

func _hex(r: float, c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * float(i) - 30.0)  # pointy top
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	var f := fill
	var rim := accent
	if disabled:
		f = Color(0.05, 0.05, 0.06, 0.8)
		rim = Color(0.5, 0.5, 0.5, 0.8)
	if _down:
		f = f.lightened(0.15)
	draw_colored_polygon(_hex(r, c), f)
	var outline := _hex(r, c)
	outline.append(outline[0])
	draw_polyline(outline, rim, 2.0, true)
	var font := ThemeDB.fallback_font
	if icon:
		var isz := r * 1.05
		var tint := Color(1, 1, 1, 0.45 if disabled else 1.0)
		draw_texture_rect(icon, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, tint)
	elif glyph != "":
		var gs := int(r * 0.9)
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_CENTER, -1, gs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + gs * 0.35), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color(1, 1, 1, 0.5 if disabled else 1.0))
	if top_text != "":
		var ts := int(r * 0.30)
		var w := font.get_string_size(top_text, HORIZONTAL_ALIGNMENT_CENTER, -1, ts).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y - r * 0.52), top_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.85, 0.85, 0.85))
	if bottom_text != "":
		var bs := int(r * 0.40)
		var w := font.get_string_size(bottom_text, HORIZONTAL_ALIGNMENT_CENTER, -1, bs).x
		draw_string(font, Vector2(c.x - w * 0.5, c.y + r * 0.82), bottom_text, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color.WHITE)
	if badge != "":
		var bc := c + Vector2(r * 0.55, -r * 0.55)
		draw_circle(bc, r * 0.26, Color(0.85, 0.15, 0.12, 0.95))
		var bsz := int(r * 0.34)
		var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, bsz).x
		draw_string(font, Vector2(bc.x - w * 0.5, bc.y + bsz * 0.36), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	var press := false
	var release := false
	if event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
		release = not press
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press = (event as InputEventMouseButton).pressed
		release = not press
	else:
		return
	if press:
		_down = true
		queue_redraw()
		accept_event()
	elif release:
		var was := _down
		_down = false
		queue_redraw()
		accept_event()
		if was and not disabled:
			pressed.emit()

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _hex(minf(size.x, size.y) * 0.5, size * 0.5))
