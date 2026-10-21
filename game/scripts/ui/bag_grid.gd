class_name BagGrid
extends Control
## The bag, storage and pet-cargo grid (spec 13 s5, s12; spec 05: one item instance per slot).
## A ScrollContainer (touch drag, wheel, scrollbar) over a grid of exactly `capacity` compartments,
## one per bag slot: empty slots stay visible, a unique instance shows its level, a green mark means
## an instance trait, a selection gets gold corner brackets. No count pills and no grouping: two
## identical stones are two slots. Bound to one Inventory; read-only grids ignore taps.

signal selected(index: int)

## Height of a compartment in logical px; the host keeps it >= 64 on a phone.
var cell_px := 64.0:
	set(v):
		cell_px = maxf(48.0, v)
		_place()
var gap := 6.0
## Compartments wide; recomputed from the grid's width on every resize.
var columns := 5
var selected_index := -1
var readonly := false

var inventory: Inventory

var _scroll: ScrollContainer
var _grid: GridContainer
var _cells: Array[Cell] = []
var _empty := 0

## One compartment: faint frame, item art, "Lv. N" bottom-right, green rare diamond top-left,
## gold corner brackets when selected. It passes pointer events through, so a drag scrolls.
class Cell extends Control:
	var index := -1
	var stack: ItemStack
	var selected := false:
		set(v):
			if selected != v:
				selected = v
				queue_redraw()
	var font_px := 13

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE

	func set_stack(s: ItemStack, i: int) -> void:
		stack = s
		index = i
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if s else Control.CURSOR_ARROW
		tooltip_text = s.tooltip() if s else "Empty slot"
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.10, 0.11, 0.13, 1.0), true)
		draw_rect(r, Color(0.34, 0.33, 0.29, 0.9), false, 1.0)
		if stack == null:
			if selected:
				_brackets(r)
			return
		var tex := ItemIcons.texture(stack.def_id)
		if tex:
			var side := size.x * 0.58
			draw_texture_rect(tex, Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side)), false)
		else:
			# No art for this id: its name, at most two lines, never the raw id.
			var d := stack.def()
			var label := d.display_name if d and d.display_name != "" else str(stack.def_id).capitalize()
			var mid: float = size.y * 0.5 - (float(font_px) if label.length() > 12 else 0.0)
			draw_string(ThemeDB.fallback_font, Vector2(2, mid), label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, font_px)
		# Level label (spec 13 s6): only for an instance that has a meaningful level.
		if stack.level > 1 and not stack.is_fungible():
			var txt := "Lv %d" % stack.level
			draw_string(ThemeDB.fallback_font, Vector2(3, size.y - 3), txt, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, font_px)
		# Rare/green mark (spec 13 s9): the instance carries a trait the def does not give every one.
		if not Inventory.traits(stack).is_empty():
			var c := Vector2(size.y - 7, 7)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), Color(0.36, 0.86, 0.38, 1.0))
		if selected:
			_brackets(r)

	func _brackets(r: Rect2) -> void:
		var gold := Color(0.90, 0.75, 0.33, 1.0)
		var arm := clampf(r.size.x * 0.22, 8.0, 20.0)
		var w := clampf(r.size.x * 0.035, 2.0, 4.0)
		var pts := [
			[r.position, r.position + Vector2(arm, 0)], [r.position, r.position + Vector2(0, arm)],
			[Vector2(r.end.x, r.position.y), Vector2(r.end.x - arm, r.position.y)], [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + arm)],
			[r.end, r.end - Vector2(arm, 0)], [r.end, r.end - Vector2(0, arm)],
			[Vector2(r.position.x, r.end.y), Vector2(r.position.x + arm, r.end.y)], [Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - arm)],
		]
		for pair: Array in pts:
			draw_line(pair[0], pair[1], gold, w)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 8
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.add_theme_constant_override("h_separation", int(gap))
	_grid.add_theme_constant_override("v_separation", int(gap))
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)
	resized.connect(_relayout)

func bind(inv: Inventory) -> void:
	if inventory and inventory.changed.is_connected(rebuild):
		inventory.changed.disconnect(rebuild)
	inventory = inv
	if inventory:
		inventory.changed.connect(rebuild)
	selected_index = -1
	rebuild()

## The number of compartments drawn (= the bag's capacity).
func slot_count() -> int:
	return _cells.size()

## Filled compartments (one per occupied slot).
func filled() -> int:
	return _cells.size() - _empty

## Visible empty compartments.
func empty_visible() -> int:
	return _empty

func cell_for(index: int) -> Cell:
	return _cells[index] if index >= 0 and index < _cells.size() else null

func set_selected(index: int) -> void:
	selected_index = index
	for c in _cells:
		c.selected = c.index == index

## Builds (or reuses) exactly `inventory.slot_count` compartments, one per bag index.
func rebuild() -> void:
	if inventory == null:
		return
	var want := inventory.slot_count
	while _cells.size() < want:
		var c := Cell.new()
		c.name = "Slot%d" % _cells.size()
		c.gui_input.connect(_on_cell_input.bind(c))
		_grid.add_child(c)
		_cells.append(c)
	while _cells.size() > want:
		var c: Cell = _cells.pop_back()
		_grid.remove_child(c)
		c.queue_free()
	_empty = 0
	for i in want:
		var s: ItemStack = inventory.slots[i] if i < inventory.slots.size() else null
		if s != null and s.def_id == Inventory.LOCK:
			s = null
		if s == null:
			_empty += 1
		_cells[i].set_stack(s, i)
		_cells[i].selected = i == selected_index
	_place()

func _on_cell_input(event: InputEvent, c: Cell) -> void:
	if readonly or inventory == null or c.index < 0:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	if c.stack == null:
		return
	selected_index = c.index
	for k in _cells:
		k.selected = k.index == selected_index
	selected.emit(c.index)

func _relayout() -> void:
	var w := maxf(size.x, 1.0)
	columns = maxi(1, int((w + gap) / (cell_px + gap)))
	_grid.columns = columns
	_place()

## Sizes the content: the grid is as wide as the viewport and as tall as its rows, so the
## ScrollContainer scrolls vertically only.
func _place() -> void:
	if _grid == null:
		return
	var sz := Vector2(cell_px, cell_px)
	for c in _cells:
		c.custom_minimum_size = sz
	var rows := int(ceil(float(_cells.size()) / float(maxi(1, columns))))
	_grid.custom_minimum_size = Vector2(size.x, maxf(1.0, rows * cell_px + maxf(0.0, rows - 1) * gap))
	_grid.columns = columns
