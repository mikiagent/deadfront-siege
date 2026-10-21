class_name BagToolbar
extends Control
## Durango's bottom bag toolbar (spec 13 s9): a wide dark Auto Sort button with its dropdown caret
## on the left; square Select, Filter and Lock buttons on the right (a Drop square only when a
## package that owns dropping sets InvActions.drop_handler). The storage view (2026-10-20 storage
## reference) adds Select All and Search, whose field opens beside Auto Sort. Each one does something real.

signal sort_pressed(key: StringName)
signal filter_chosen(id: StringName)
signal select_toggled(on: bool)
signal lock_pressed
signal drop_pressed
signal select_all_pressed
signal search_changed(text: String)

var sort_key: StringName = &"type"
## The right-hand squares this toolbar shows, in this order (the Bag: Select, Filter, Lock; storage:
## Select All, Select, Search, Lock; the picker none).
var squares: Array[StringName] = [&"select", &"filter", &"lock"]
var filter_id: StringName = &"all"
var select_on := false
var _sort: Button
var _caret: Button
var _select: Button
var _filter: Button
var _lock: Button
var _drop: Button
var _select_all: Button
var _search: Button
var _query: LineEdit
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
	_select_all = _button("", "Select every item shown")
	_select_all.draw.connect(func() -> void: InvGlyphs.select_all(_select_all, Rect2(Vector2.ZERO, _select_all.size)))
	_select_all.pressed.connect(func() -> void: select_all_pressed.emit())
	_search = _button("", "Search by name")
	_search.toggle_mode = true
	_search.icon = UiIcons.icon(&"inspect")
	_search.expand_icon = true
	_search.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search.toggled.connect(_on_search_toggled)
	_query = LineEdit.new()
	_query.placeholder_text = "Search"
	_query.visible = false
	_query.clear_button_enabled = true
	_query.add_theme_stylebox_override("normal", InvTheme.button_box(Color(0, 0, 0, 0.55), InvTheme.BUTTON_EDGE))
	_query.add_theme_stylebox_override("focus", InvTheme.button_box(Color(0, 0, 0, 0.55), InvTheme.SELECT))
	_query.text_changed.connect(func(t: String) -> void: search_changed.emit(t))
	add_child(_query)
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
	_search.add_theme_constant_override("icon_max_width", int(m.square * 0.46))
	_query.add_theme_font_size_override("font_size", int(m.button_font) - (2 if m.compact else 6))
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
	var sort_w := maxf(roundf(size.x * 0.24), InvTheme.font().get_string_size(_sort.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_m.button_font)).x + 24.0)
	_sort.position = Vector2(pad, pad)
	_sort.size = Vector2(sort_w, sq)
	_caret.position = Vector2(pad + sort_w - 1.0, pad)
	_caret.size = Vector2(maxf(44.0, sq * 0.9), sq)
	var shown: Array[Button] = []
	var by_id := {&"select_all": _select_all, &"select": _select, &"search": _search, &"filter": _filter, &"lock": _lock}
	for id: StringName in by_id:
		(by_id[id] as Button).visible = false
	for id in squares:
		if by_id.has(id):
			(by_id[id] as Button).visible = true
			shown.append(by_id[id])
	_drop.visible = InvActions.drop_handler.is_valid() and squares.has(&"lock") # with the bag's own squares
	if _drop.visible:
		shown.append(_drop)
	var x := size.x - pad
	for i in range(shown.size() - 1, -1, -1):
		x -= sq
		shown[i].position = Vector2(x, pad)
		shown[i].size = Vector2(sq, sq)
		x -= float(UiTokens.SPACE) * (1.0 if _m.compact else 2.0)
	# The search field fills the room between the caret and the squares, up to a comfortable width.
	_query.visible = _search.visible and _search.button_pressed
	var from := _caret.position.x + _caret.size.x + float(UiTokens.SPACE) * 2.0
	_query.position = Vector2(from, pad + (sq - maxf(44.0, sq * 0.8)) * 0.5)
	_query.size = Vector2(maxf(0.0, minf(x - from, size.x * 0.4)), maxf(44.0, sq * 0.8))

## The query typed now ("" when the search square is off).
func query() -> String:
	return _query.text if _query.visible else ""

## Search on or off (with `text` typed); off clears the query so every item shows again.
func set_search(on: bool, text: String = "") -> void:
	_search.button_pressed = on
	if on and text != "":
		_query.text = text
		search_changed.emit(text)

func _on_search_toggled(on: bool) -> void:
	_layout()
	if on:
		if _query.is_inside_tree() and not OS.has_feature("mobile"):
			_query.grab_focus() # desktop types at once; a phone opens its keyboard on the tap
	elif _query.text != "":
		_query.text = ""
		search_changed.emit("")

## Select shows on or off without emitting (the screen turned multi-select on itself).
func set_select(on: bool) -> void:
	select_on = on
	_select.set_pressed_no_signal(on)
	_select.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.035, 0.03, 0.82))
	InvPaint.frame(self, Rect2(Vector2.ZERO, size), 2.0 if _m.get("compact", false) else 3.0, 5)

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
