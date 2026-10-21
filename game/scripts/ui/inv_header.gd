class_name InvHeader
extends Control
## The black top bar shared by the bag family (spec 13 s4, s16): "<" back, a large white title, an
## optional centre item (the bag's capacity), the T-stone count, and X. Its lower edge is torn like
## the reference's weathered paper, from a fixed hash so it never flickers.

signal back_pressed
signal close_pressed

var title := ""
## The T-stone chip (the Bag reference has it; Character and Equipment do not).
var show_stones := true
var _back: Button
var _close: Button
var _title: Label
var _middle: Control
var _m := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_back = _icon_button(&"", "Back")
	_back.draw.connect(_draw_chevron) # Durango's thin "<", not the HUD's arrow
	_back.pressed.connect(func() -> void: back_pressed.emit())
	_close = _icon_button(&"close", "Close")
	_close.pressed.connect(func() -> void: close_pressed.emit())
	_title = Label.new()
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", InvTheme.TEXT)
	add_child(_title)
	resized.connect(_layout)

## Places `node` right after the title (the capacity indicator).
func set_middle(node: Control) -> void:
	if _middle and _middle != node:
		_middle.queue_free()
	_middle = node
	if node.get_parent() != self:
		add_child(node)
	if not node.minimum_size_changed.is_connected(_layout):
		node.minimum_size_changed.connect(_layout) # "99 / 100" -> "100 / 100" grows the count
	_layout()

func set_title(text: String) -> void:
	title = text
	_title.text = text
	_layout()

func apply_metrics(m: Dictionary) -> void:
	_m = m
	_title.add_theme_font_size_override("font_size", int(m.title_font))
	_layout()

func _icon_button(id: StringName, tip: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.icon = UiIcons.icon(id)
	b.expand_icon = true
	b.tooltip_text = tip
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b

func _layout() -> void:
	if _m.is_empty():
		return
	var h := size.y
	var pad: float = _m.margin
	var btn := maxf(44.0, h - 8.0)
	_back.size = Vector2(btn, btn)
	_back.position = Vector2(pad - 4.0, (h - btn) * 0.5)
	_back.add_theme_constant_override("icon_max_width", int(h * 0.42))
	_close.size = Vector2(btn, btn)
	_close.position = Vector2(size.x - pad - btn + 4.0, (h - btn) * 0.5)
	_close.add_theme_constant_override("icon_max_width", int(h * 0.42))
	var x := _back.position.x + btn
	var tw := InvTheme.font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_m.title_font)).x + 4.0
	_title.position = Vector2(x, 0)
	_title.size = Vector2(tw, h)
	x += tw + float(_m.gap)
	if _middle:
		_middle.position = Vector2(x, (h - _middle.custom_minimum_size.y) * 0.5)
		_middle.size = Vector2(_middle.custom_minimum_size.x, _middle.custom_minimum_size.y)
	queue_redraw()

func _draw() -> void:
	var h := size.y
	var depth := 3.0 if h < 60.0 else 5.0
	# Black bar with a ragged lower edge, then a thin lighter tear line under it.
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0)])
	var x := size.x
	var k := 0
	while x > 0.0:
		pts.append(Vector2(x, h + _jit(k) * depth))
		x -= 11.0
		k += 1
	pts.append(Vector2(0, h + _jit(k) * depth))
	draw_colored_polygon(pts, InvTheme.HEADER)
	var edge := PackedVector2Array()
	for i in range(2, pts.size()):
		edge.append(pts[i] + Vector2(0, 1.5))
	draw_polyline(edge, Color(0.42, 0.36, 0.28, 0.55), 1.5)
	var dot := maxf(2.0, h * 0.04)
	for fx in [0.24, 0.76]:
		draw_circle(Vector2(size.x * fx, h + dot * 0.2), dot, Color(0.02, 0.02, 0.02))
	if not show_stones:
		return
	# T-stones (display only; the shop that sells them is elsewhere).
	var f := InvTheme.font()
	var px := int(_m.get("cap_font", 34) * 0.7)
	var txt := "%d" % World.t_stones
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var chip_h := h * 0.56
	var chip_w := tw + chip_h * 1.6 + 24.0
	var right := _close.position.x - float(_m.get("gap", 16))
	var chip := Rect2(Vector2(right - chip_w, (h - chip_h) * 0.5), Vector2(chip_w, chip_h))
	draw_style_box(InvTheme.button_box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.0), 6), chip)
	var ic := UiIcons.icon(&"t_stones")
	if ic:
		draw_texture_rect(ic, Rect2(chip.position + Vector2(chip_h * 0.25, chip_h * 0.15), Vector2(chip_h * 0.7, chip_h * 0.7)), false, InvTheme.SELECT)
	draw_string(f, Vector2(chip.end.x - 12.0 - tw, chip.position.y + (chip_h + f.get_ascent(px) - f.get_descent(px)) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, InvTheme.TEXT)
	draw_line(Vector2(right + float(_m.get("gap", 16)) * 0.5, h * 0.3), Vector2(right + float(_m.get("gap", 16)) * 0.5, h * 0.7), Color(1, 1, 1, 0.25), 1.0)

func _draw_chevron() -> void:
	var c := _back.size * 0.5
	var h := size.y * 0.2
	_back.draw_polyline(PackedVector2Array([c + Vector2(h * 0.35, -h), c + Vector2(-h * 0.45, 0), c + Vector2(h * 0.35, h)]), InvTheme.TEXT, maxf(2.5, h * 0.17), true)

## Deterministic jitter in [-1, 1] for the torn edge.
static func _jit(k: int) -> float:
	var v := sin(float(k) * 12.9898) * 43758.5453
	return (v - floorf(v)) * 2.0 - 1.0
