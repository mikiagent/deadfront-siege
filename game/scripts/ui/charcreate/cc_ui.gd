class_name CcUi
extends RefCounted
## Character creation chrome in Durango's look (spec 19): the black torn header band, dotted row
## separators, yellow corner brackets on a selected row, the gold hex swatch and the yellow button.
## The bag and market (specs 13/14) draw the same band in their own branches; this one is local
## until they merge (note for the integrator).

const BG := Color(0.13, 0.13, 0.13)
const LIST_BG := Color(0.085, 0.085, 0.085)
const ROW_SELECTED := Color(0.235, 0.225, 0.19)
const BAND := Color(0.015, 0.015, 0.015)
const DOTS := Color(1, 1, 1, 0.16)
const GOLD := Color(0.96, 0.76, 0.25)
const YELLOW := Color(0.98, 0.80, 0.20)
const INK := Color(0.07, 0.07, 0.07)
const TEXT := Color(0.94, 0.94, 0.92)
const MUTED := Color(0.62, 0.62, 0.6)
const ERROR := Color(1.0, 0.48, 0.40)

static func label(text: String, size_px: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func yellow_button(text: String, size_px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size_px)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_disabled_color", Color(0.25, 0.25, 0.25))
	for pair in [["normal", YELLOW], ["hover", YELLOW.lightened(0.12)], ["pressed", YELLOW.darkened(0.15)], ["focus", YELLOW.lightened(0.12)], ["disabled", Color(0.42, 0.38, 0.26)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = pair[1]
		sb.set_corner_radius_all(4)
		if pair[0] == "focus":
			sb.draw_center = false
			sb.border_color = Color.WHITE
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override(pair[0], sb)
	return b

## A full-width row (occupation list, tabs): text left on a clear box the owner restyles for selection.
## Not `flat`: a flat Button skips its styleboxes, and the selected row's lighter fill is one.
static func row_button(text: String, size_px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, clear)
	b.add_theme_font_size_override("font_size", size_px)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, TEXT)
	return b

## Durango's dotted separator under a row.
static func dotted(ci: CanvasItem, from: Vector2, to: Vector2) -> void:
	ci.draw_dashed_line(from, to, DOTS, 1.0, 3.0)

## Yellow corner brackets around a selected row or portrait.
static func brackets(ci: CanvasItem, r: Rect2, arm: float, width: float = 3.0) -> void:
	for c in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = c[0]
		var d: Vector2 = c[1]
		ci.draw_polyline(PackedVector2Array([p + Vector2(0, d.y * arm), p, p + Vector2(d.x * arm, 0)]), YELLOW, width)

static func hex_points(r: float, c: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * float(i) - 30.0)  # pointy top, like HexButton
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

## The black header band with a torn lower edge (fixed hash, never flickers), a title and an
## optional back chevron (a 44 px+ button).
class Band extends Control:
	signal back_pressed
	var title := ""
	var font_px := 28
	var back: Button

	func _init(p_title: String, with_back: bool) -> void:
		title = p_title
		mouse_filter = Control.MOUSE_FILTER_STOP
		if with_back:
			back = Button.new()
			back.name = "Back"
			back.flat = true
			back.focus_mode = Control.FOCUS_ALL
			back.tooltip_text = "Back"
			back.draw.connect(func () -> void:
				var s := back.size
				var h := s.y * 0.22
				back.draw_polyline(PackedVector2Array([Vector2(s.x * 0.58, s.y * 0.5 - h), Vector2(s.x * 0.40, s.y * 0.5), Vector2(s.x * 0.58, s.y * 0.5 + h)]), CcUi.TEXT, 3.0, true))
			back.pressed.connect(func () -> void: back_pressed.emit())
			add_child(back)

	## `inset_x`: the safe-area inset on the left (a notch in landscape).
	func place(r: Rect2, p_font: int, inset_x: float) -> void:
		position = r.position
		size = r.size
		font_px = p_font
		if back:
			var b := maxf(44.0, r.size.y - 4.0)
			back.position = Vector2(inset_x + 4.0, (r.size.y - b) * 0.5)
			back.size = Vector2(b, b)
		set_meta(&"inset", inset_x)
		queue_redraw()

	func title_x() -> float:
		return back.position.x + back.size.x + 4.0 if back else float(get_meta(&"inset", 0.0)) + 20.0

	func _draw() -> void:
		var h := size.y
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0)])
		var x := size.x
		var k := 0
		while x > 0.0:
			pts.append(Vector2(x, h + (fmod(sin(float(k) * 12.9898) * 43758.5453, 1.0) - 0.5) * 8.0))
			x -= 13.0
			k += 1
		pts.append(Vector2(0, h))
		draw_colored_polygon(pts, CcUi.BAND)
		var font := get_theme_default_font()
		draw_string(font, Vector2(title_x(), h * 0.5 + font_px * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, CcUi.TEXT)

## A hex swatch or tab: a filled hex (colour or dark), an optional glyph/texture, gold outline and a
## check when selected, an optional caption under it. At least 44 px across.
class Hex extends Control:
	signal pressed
	var fill := Color(0.16, 0.16, 0.16)
	var glyph := ""
	var glyph_color := CcUi.TEXT
	## Glyph size over the hex radius (the symbol font draws the gender signs small).
	var glyph_scale := 0.95
	var texture: Texture2D
	var caption := ""
	var caption_px := 13
	var selected := false
	var check := false
	var _down := false

	func _init(p_size: float) -> void:
		custom_minimum_size = Vector2(p_size, p_size)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL

	func hex_radius() -> float:
		return minf(size.x, size.y - (caption_px + 6.0 if caption != "" else 0.0)) * 0.5 - 2.0

	func _draw() -> void:
		var r := hex_radius()
		var c := Vector2(size.x * 0.5, r + 2.0)
		draw_colored_polygon(CcUi.hex_points(r, c), fill)
		if texture:
			var t := r * 1.05
			draw_texture_rect(texture, Rect2(c - Vector2(t, t) * 0.5, Vector2(t, t)), false)
		if glyph != "":
			var font := get_theme_default_font()
			var gs := maxi(12, int(r * glyph_scale))
			var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
			draw_string(font, Vector2(c.x - w * 0.5, c.y + gs * 0.36), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, glyph_color)
		var rim := CcUi.hex_points(r, c)
		rim.append(rim[0])
		draw_polyline(rim, CcUi.GOLD if selected else Color(1, 1, 1, 0.22), 3.0 if selected else 1.5, true)
		if has_focus():
			var ring := CcUi.hex_points(r + 3.0, c)
			ring.append(ring[0])
			draw_polyline(ring, Color.WHITE, 1.5, true)
		if check:
			var b := c + Vector2(r * 0.5, r * 0.45)
			draw_circle(b, r * 0.3, CcUi.GOLD)
			draw_polyline(PackedVector2Array([b + Vector2(-r * 0.14, 0), b + Vector2(-r * 0.03, r * 0.11), b + Vector2(r * 0.15, -r * 0.1)]), CcUi.INK, 2.0, true)
		if caption != "":
			var font := get_theme_default_font()
			var w := minf(font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_px).x, size.x + 24.0)
			draw_string(font, Vector2(size.x * 0.5 - w * 0.5, size.y - 3.0), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x + 24.0, caption_px, CcUi.GOLD if selected else CcUi.MUTED)

	## A touch can arrive as both a touch and an emulated mouse event: one press, one release, one emit.
	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept"):
			accept_event()
			pressed.emit()
			return
		var tap := event is InputEventScreenTouch or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		if not tap:
			return
		accept_event()
		if event.is_pressed():
			_down = true
		elif _down:
			_down = false
			pressed.emit()
