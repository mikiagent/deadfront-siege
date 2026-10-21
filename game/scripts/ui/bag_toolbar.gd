class_name BagToolbar
extends Control
## Durango's bottom bag toolbar (spec 13 s9): a wide dark Auto Sort button with its dropdown caret
## on the left; square Select, Filter and Lock buttons on the right (a Drop square only when a
## package that owns dropping sets InvActions.drop_handler). Each one does something real.

signal sort_pressed(key: StringName)
signal filter_chosen(id: StringName)
signal select_toggled(on: bool)
signal lock_pressed
signal drop_pressed

var sort_key: StringName = &"type"
var filter_id: StringName = &"all"
var select_on := false
var _sort: Button
var _caret: Button
var _select: Button
var _filter: Button
var _lock: Button
var _drop: Button
var _menu: Control
var _m := {}
var _lock_open := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sort = _button("Auto Sort", "Sort the bag view (the items themselves do not move)")
	_sort.pressed.connect(func() -> void: sort_pressed.emit(sort_key))
	_caret = _button("", "Choose how Auto Sort orders the bag")
	_caret.draw.connect(func() -> void: InvGlyphs.caret(_caret, Rect2(Vector2.ZERO, _caret.size)))
	_caret.pressed.connect(_open_sort_menu)
	_select = _button("", "Select several items")
	_select.toggle_mode = true
	_select.draw.connect(func() -> void: InvGlyphs.select(_select, Rect2(Vector2.ZERO, _select.size), select_on))
	_select.toggled.connect(func(on: bool) -> void:
		select_on = on
		_select.queue_redraw()
		select_toggled.emit(on))
	_filter = _button("", "Filter")
	_filter.draw.connect(func() -> void: InvGlyphs.funnel(_filter, Rect2(Vector2.ZERO, _filter.size), filter_id != &"all"))
	_filter.pressed.connect(_open_filter_menu)
	_lock = _button("", "Lock or unlock the selection")
	_lock.expand_icon = true
	_lock.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock.pressed.connect(func() -> void: lock_pressed.emit())
	_drop = _button("", "Drop")
	_drop.pressed.connect(func() -> void: drop_pressed.emit())
	set_lock_state(false, false)
	resized.connect(_layout)

func _button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", InvTheme.button_box(InvTheme.BUTTON_DARK, InvTheme.BUTTON_EDGE))
	b.add_theme_color_override("font_color", InvTheme.TEXT_2)
	add_child(b)
	return b

func apply_metrics(m: Dictionary) -> void:
	_m = m
	_sort.add_theme_font_size_override("font_size", int(m.button_font))
	_lock.add_theme_constant_override("icon_max_width", int(m.square * 0.46))
	_layout()

## The lock square shows what pressing it does: lock, or unlock when the selection is all locked.
func set_lock_state(all_locked: bool, enabled: bool) -> void:
	_lock_open = all_locked
	_lock.icon = UiIcons.icon(&"unlock" if all_locked else &"lock")
	_lock.disabled = not enabled
	_lock.tooltip_text = ("Unlock" if all_locked else "Lock") + (" the selection" if enabled else ": select an item first")

func _layout() -> void:
	if _m.is_empty():
		return
	var sq: float = _m.square
	var pad := (size.y - sq) * 0.5
	var sort_w := roundf(size.x * 0.24)
	_sort.position = Vector2(pad, pad)
	_sort.size = Vector2(sort_w, sq)
	_caret.position = Vector2(pad + sort_w - 1.0, pad)
	_caret.size = Vector2(maxf(44.0, sq * 0.9), sq)
	var squares: Array[Button] = [_select, _filter, _lock]
	_drop.visible = InvActions.drop_handler.is_valid()
	if _drop.visible:
		squares.append(_drop)
	var x := size.x - pad
	for i in range(squares.size() - 1, -1, -1):
		x -= sq
		squares[i].position = Vector2(x, pad)
		squares[i].size = Vector2(sq, sq)
		x -= float(UiTokens.SPACE) * (1.0 if _m.compact else 2.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.03, 0.82))
	draw_rect(Rect2(Vector2.ZERO, size), InvTheme.BORDER, false, 2.0)

# ---------------------------------------------------------------- dropdowns

func _open_sort_menu() -> void:
	var rows: Array = []
	for k in InvView.sort_keys():
		rows.append([StringName(str(k)), InvView.sort_label(StringName(str(k))), StringName(str(k)) == sort_key])
	_open_menu(_caret, rows, func(key: StringName) -> void:
		sort_key = key
		sort_pressed.emit(key))

func _open_filter_menu() -> void:
	var rows: Array = []
	for f: Dictionary in InvView.filters():
		rows.append([StringName(str(f.id)), str(f.get("label", f.id)), StringName(str(f.id)) == filter_id])
	_open_menu(_filter, rows, func(id: StringName) -> void:
		filter_id = id
		_filter.queue_redraw()
		filter_chosen.emit(id))

## A list above `anchor` on a full-screen catcher (a tap outside closes it). rows: [id, label, on].
func _open_menu(anchor: Control, rows: Array, pick: Callable) -> void:
	close_menu()
	var host := get_parent() as Control
	if host == null:
		return
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			close_menu())
	host.add_child(_menu)
	var row_h: float = maxf(44.0, float(_m.square) * 0.8)
	var font_px: int = int(_m.button_font) - (2 if _m.compact else 4)
	var w := 0.0
	for r in rows:
		w = maxf(w, InvTheme.font().get_string_size(str(r[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x)
	w = maxf(w + 48.0, anchor.size.x * 2.0)
	var list_h := minf(row_h * rows.size() + 8.0, host.size.y - 16.0)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", InvTheme.button_box(Color(0.05, 0.055, 0.05, 0.97), InvTheme.BUTTON_EDGE))
	var at := anchor.get_global_rect()
	var origin := host.get_global_rect().position
	var px := clampf(at.position.x - origin.x, 8.0, host.size.x - w - 8.0)
	panel.position = Vector2(px, maxf(8.0, at.position.y - origin.y - list_h - 6.0))
	panel.size = Vector2(w, list_h)
	_menu.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	scroll.add_child(box)
	for r in rows:
		var b := Button.new()
		b.text = str(r[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, row_h)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", font_px)
		var on: bool = r[2]
		b.add_theme_stylebox_override("normal", InvTheme.button_box(Color(InvTheme.SELECT, 0.18) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0)))
		b.add_theme_color_override("font_color", InvTheme.SELECT if on else InvTheme.TEXT)
		var id: StringName = r[0]
		b.pressed.connect(func() -> void:
			close_menu()
			pick.call(id))
		box.add_child(b)

func close_menu() -> void:
	if _menu and is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null

func menu_open() -> bool:
	return _menu != null and is_instance_valid(_menu)
