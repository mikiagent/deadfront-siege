class_name HexButton
extends Control
## Durango-style hexagonal button: dark hex with a light rim, an icon or glyph in the
## middle, small text above (time) and below (count). Fires `pressed` on tap.
## Also used by the HUD skill cluster (M8c). Minimum 64 px across.

signal pressed
signal long_pressed

var icon: Texture2D
var glyph: String = ""
var top_text: String = ""
var bottom_text: String = ""
var disabled: bool = false
var accent: Color = Color(0.95, 0.95, 0.95)
var fill: Color = Color(0.07, 0.08, 0.09, 0.93)
var badge: String = ""  # e.g. "⊘" when blocked
var badge_color: Color = Color(0.85, 0.15, 0.12, 0.95)
var label_text: String = ""   # optional label drawn to the right (station radial)
var hint_text: String = ""    # small red line under the label (blocked reason)
var cooldown: float = 0.0     # 0..1 remaining sweep
var selected: bool = false
var enabled_look: bool = true
var _down: bool = false
var _hold: float = 0.0

## Compatibility with the station radial (M8e): icon or glyph, label, seconds on top, count below.
func setup(p_icon: Texture2D, p_glyph: String, p_label: String, p_seconds: String = "", p_count: String = "") -> void:
	icon = p_icon
	glyph = p_glyph if p_icon == null else ""
	label_text = p_label
	top_text = p_seconds
	bottom_text = p_count
	queue_redraw()

func set_blocked(hint: String) -> void:
	disabled = true
	badge = "⊘"
	badge_color = Color(0.85, 0.15, 0.12, 0.95)
	hint_text = hint if hint == "" or hint.begins_with("needs") else "needs %s" % hint
	queue_redraw()

func set_ok_badge(hint: String, color: Color = Color(0.95, 0.8, 0.2, 0.95)) -> void:
	badge = "✓"
	badge_color = color
	hint_text = hint
	queue_redraw()

func _process(delta: float) -> void:
	if _down:
		_hold += delta
		if _hold > 0.55:
			_hold = -999.0
			long_pressed.emit()
	if cooldown > 0.0:
		queue_redraw()

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
	if disabled or not enabled_look:
		f = Color(0.05, 0.05, 0.06, 0.8)
		rim = Color(0.5, 0.5, 0.5, 0.8)
	if selected:
		rim = Color(1.0, 0.85, 0.3)
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
		var gs := int(r * 0.9) if glyph.length() <= 2 else (int(r * 0.40) if glyph.length() <= 4 else int(r * 0.30))
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
		draw_circle(bc, r * 0.26, badge_color)
		var bsz := int(r * 0.34)
		var w := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_CENTER, -1, bsz).x
		draw_string(font, Vector2(bc.x - w * 0.5, bc.y + bsz * 0.36), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, bsz, Color.WHITE)

	if cooldown > 0.0:
		var pts := PackedVector2Array([c])
		var steps := 24
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * cooldown * float(i) / float(steps)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
	if label_text != "":
		var ls := int(r * 0.42)
		var lw := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
		draw_rect(Rect2(Vector2(size.x + 4.0, c.y - ls * 0.9), Vector2(lw + 12.0, ls * 1.6)), Color(0.05, 0.06, 0.07, 0.85))
		draw_string(font, Vector2(size.x + 10.0, c.y + ls * 0.35), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ls, Color(0.95, 0.95, 0.95))
		if hint_text != "":
			draw_string(font, Vector2(size.x + 10.0, c.y + ls * 1.5), hint_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.32), Color(1.0, 0.45, 0.4))

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
		_hold = 0.0
		queue_redraw()
		accept_event()
	elif release:
		var was := _down and _hold >= 0.0
		_down = false
		queue_redraw()
		accept_event()
		if was and not disabled:
			pressed.emit()

func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _hex(minf(size.x, size.y) * 0.5, size * 0.5))
