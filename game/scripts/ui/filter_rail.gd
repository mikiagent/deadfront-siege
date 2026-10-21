class_name FilterRail
extends Control
## The storage view's left column of category filters (2026-10-20 storage-transfer reference): one
## square per data/inv_ui.json filter with its white icon, the active one gold. It scrolls when the
## screen is short (a phone). Presentation only: the screen applies the filter to its grids.

signal chosen(id: StringName)

var filter_id: StringName = &"all"
var _scroll: ScrollContainer
var _box: VBoxContainer
var _buttons := {} ## filter id -> Button
var _side := 56.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER # drag scrolls; a bar would not fit
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_scroll.add_child(_box)
	for f: Dictionary in InvView.filters():
		var id := StringName(str(f.get("id", "")))
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = str(f.get("label", id))
		var icon := str(f.get("icon", ""))
		if icon != "" and icon != "grid":
			b.icon = UiIcons.icon(StringName(icon))
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.draw.connect(func() -> void:
			if icon == "grid":
				InvGlyphs.grid(b, Rect2(Vector2.ZERO, b.size), InvTheme.SELECT if filter_id == id else InvGlyphs.WHITE))
		b.pressed.connect(func() -> void: choose(id))
		_box.add_child(b)
		_buttons[id] = b
	_paint()

## Square side of each filter button (44 px or more).
func set_side(side: float) -> void:
	_side = maxf(44.0, side)
	for b: Button in _buttons.values():
		b.custom_minimum_size = Vector2(_side, _side)
		b.add_theme_constant_override("icon_max_width", int(_side * 0.5))

func choose(id: StringName) -> void:
	filter_id = id if _buttons.has(id) else &"all"
	_paint()
	chosen.emit(filter_id)

func button(id: StringName) -> Button:
	return _buttons.get(id)

## The active square dark with a gold icon and edge (the reference's All); the rest dark grey, white icons.
func _paint() -> void:
	for id: StringName in _buttons:
		var b: Button = _buttons[id]
		var on := id == filter_id
		var sb := InvTheme.button_box(Color(0.02, 0.022, 0.02, 0.95) if on else Color(0.16, 0.165, 0.155, 0.85), InvTheme.SELECT if on else Color(0, 0, 0, 0), 4)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, sb)
		b.add_theme_color_override("icon_normal_color", InvTheme.SELECT if on else InvGlyphs.WHITE)
		b.add_theme_color_override("icon_hover_color", InvTheme.SELECT if on else Color.WHITE)
		b.add_theme_color_override("icon_pressed_color", InvTheme.SELECT)
		b.queue_redraw()
