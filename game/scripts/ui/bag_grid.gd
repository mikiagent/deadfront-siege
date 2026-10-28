class_name BagGrid
extends Control
## The bag, storage and pet-cargo grid (spec 13 s5-8, s12; spec 05: one item instance per slot).
## A ScrollContainer (touch drag, wheel, scrollbar) over a grid of exactly `capacity` compartments,
## one per bag slot: empty slots stay visible, a unique instance shows "Lv. N" (small, grey, top
## right), a fresh one a blue NEW tag (top left), a green rare trait a green corner mark, a locked
## one a small lock; gold brackets the single selection, cool blue ones a batch mark. No count pills
## and no grouping: two identical stones are two slots. Bound to one Inventory; read-only grids
## ignore taps. Auto Sort and the filter (spec 13 s9) change only the order cells are drawn in
## (`sort_key`, `filter_id`): every cell keeps its real slot index, nothing in the bag moves.

signal selected(index: int)
## Select mode began from the grid itself (a long press or a Shift-press); the host shows its batch bar.
signal multi_started
## The batch marks changed (paint, tap toggle).
signal multi_changed

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
## Select mode (owner 2026-10-27): taps toggle membership in `multi` instead of moving the single
## selection, so several items can be locked, dropped or destroyed in one batch pass.
var multi_mode := false
var multi: Array[int] = []

var inventory: Inventory
## Presentation order (spec 13 s9): "" = bag order, else one of SORTS. Never moves an item.
var sort_key := ""
## "" = every slot, else one of FILTERS: only matching instances are drawn.
var filter_id := ""
## uids the host flags as freshly acquired (blue NEW tag); the host clears them on acknowledge.
var new_uids: Dictionary = {}
const SORTS := ["", "type", "level", "name"]
const SORT_LABELS := {"": "Bag order", "type": "Type", "level": "Level", "name": "Name"}
const FILTERS := ["", "materials", "food", "gear", "tools", "building", "rare", "locked"]
const FILTER_LABELS := {"": "All", "materials": "Materials", "food": "Food", "gear": "Gear", "tools": "Tools", "building": "Building", "rare": "Rare", "locked": "Locked"}
## Cell for each drawn slot index (the view may skip or reorder slots).
var _cell_of: Dictionary = {}

var _scroll: ScrollContainer
var _grid: GridContainer
var _cells: Array[Cell] = []
var _empty := 0
## Press tracking: a tap selects, a drag scrolls. A selection is emitted on release only when the
## pointer stayed inside the deadzone, so dragging a storage box never takes the item under the finger.
var _press_cell := -1
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _last_pos := Vector2.ZERO
## Paint gesture state: the marks before it, the cells it passed in order.
var _painting := false
var _pre: Array[int] = []
var _path: Array[int] = []
var _tap_toggle := false
## Hold this long without moving to enter select mode.
var long_press_s := 0.45
const EDGE_PX := 36.0
const AUTOSCROLL_PX_S := 420.0
const TAP_DEADZONE := 12.0
## Room kept for the vertical scrollbar when counting columns.
const SCROLLBAR_PX := 12.0

## One compartment: faint frame, item art, "Lv. N" bottom-right, green rare diamond top-right,
## gold corner brackets when selected. It passes pointer events through, so a drag scrolls.
class Cell extends Control:
	var index := -1
	var stack: ItemStack
	var selected := false:
		set(v):
			if selected != v:
				selected = v
				queue_redraw()
	## Batch membership (Feature A): cooler brackets than the single gold selection.
	var member := false:
		set(v):
			if member != v:
				member = v
				queue_redraw()
	var font_px := 13
	var is_new := false

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
		draw_rect(r, Color(0.16, 0.155, 0.13, 1.0), true)
		draw_rect(r, Color(0.34, 0.33, 0.29, 0.9), false, 1.0)
		if selected:
			draw_rect(r.grow(-2), Color(SEL_COL, 0.12), true)
		if stack != null:
			var tex := ItemIcons.texture(stack.def_id)
			if tex:
				var side := size.x * 0.58
				draw_texture_rect(tex, Rect2((size - Vector2(side, side)) * Vector2(0.5, 0.55), Vector2(side, side)), false)
			else:
				# No art for this id: its name, at most two lines, never the raw id.
				var d := stack.def()
				var label := d.display_name if d and d.display_name != "" else str(stack.def_id).capitalize()
				var mid: float = size.y * 0.5 - (float(font_px) if label.length() > 12 else 0.0)
				draw_string(ThemeDB.fallback_font, Vector2(2, mid), label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, font_px)
			# Level label (spec 13 s6): small, grey, top right; only for an instance with a meaningful level.
			if stack.level > 1 and not stack.is_fungible():
				draw_string(ThemeDB.fallback_font, Vector2(3, font_px + 1), LevelDisplay.label(stack.level), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, font_px, LV_COL)
			# NEW tag (spec 13 s7): blue, white uppercase, top left, at most a third of the cell wide.
			if is_new:
				var tw := ThemeDB.fallback_font.get_string_size("NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
				var tag := Rect2(Vector2(2, 2), Vector2(minf(tw + 6.0, size.x * 0.45), font_px + 3))
				draw_rect(tag, NEW_COL, true)
				draw_string(ThemeDB.fallback_font, tag.position + Vector2(3, font_px), "NEW", HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 4, font_px, Color.WHITE)
			# Rare mark (spec 13 s11): a green corner, much quieter than the brackets.
			if InvAttributes.has_rare(stack):
				var e := r.end - Vector2(2, 2)
				var k := size.x * 0.16
				draw_colored_polygon(PackedVector2Array([e, e - Vector2(k, 0), e - Vector2(0, k)]), Color(InvAttributes.COLORS["rare"], 0.9))
			if stack.is_locked():
				var lk := UiIcons.icon(&"lock")
				if lk:
					var ls := size.x * 0.2
					draw_texture_rect(lk, Rect2(Vector2(3, size.y - ls - 3), Vector2(ls, ls)), false)
		if selected:
			_brackets(r)
		if member:
			_brackets(r, BATCH_COL)

	const LV_COL := Color(0.65, 0.65, 0.61, 1.0)
	const NEW_COL := Color(0.09, 0.41, 0.59, 1.0)
	const SEL_COL := Color(0.90, 0.75, 0.33, 1.0)
	const BATCH_COL := Color(0.42, 0.80, 0.92, 1.0)

	func _brackets(r: Rect2, col: Color = SEL_COL) -> void:
		var arm := clampf(r.size.x * 0.22, 8.0, 20.0)
		var w := clampf(r.size.x * 0.035, 2.0, 4.0)
		var pts := [
			[r.position, r.position + Vector2(arm, 0)], [r.position, r.position + Vector2(0, arm)],
			[Vector2(r.end.x, r.position.y), Vector2(r.end.x - arm, r.position.y)], [Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y + arm)],
			[r.end, r.end - Vector2(arm, 0)], [r.end, r.end - Vector2(0, arm)],
			[Vector2(r.position.x, r.end.y), Vector2(r.position.x + arm, r.end.y)], [Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.end.y - arm)],
		]
		for pair: Array in pts:
			draw_line(pair[0], pair[1], col, w)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(false)
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
	multi.clear()
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

## The cell drawing bag slot `index` (null when the view hides it).
func cell_for(index: int) -> Cell:
	return _cell_of.get(index) as Cell

func set_selected(index: int) -> void:
	selected_index = index
	for c in _cells:
		c.selected = c.index == index and index >= 0

## Select mode (Feature A): taps toggle batch membership rather than the single selection.
func set_multi_mode(on: bool) -> void:
	multi_mode = on
	if not on:
		clear_multi()

## Toggle one slot into the batch. A locked item may still join (its actions skip it and say so),
## but empty compartments and lock-marker slots refuse so the counts track actionable items.
func toggle_multi(index: int) -> bool:
	if inventory == null or index < 0 or index >= inventory.slots.size():
		return false
	var s: ItemStack = inventory.slots[index]
	if s == null or s.def_id == Inventory.LOCK:
		return false
	if multi.has(index):
		multi.erase(index)
	else:
		multi.append(index)
	for c in _cells:
		c.member = multi.has(c.index)
	return multi.has(index)

func clear_multi() -> void:
	multi.clear()
	for c in _cells:
		c.member = false

## The marked batch as ascending indices (stable order for the destructive passes).
func multi_list() -> Array[int]:
	var out := multi.duplicate()
	out.sort()
	return out

## Builds (or reuses) one compartment per drawn slot: every bag index in bag order, or the sorted /
## filtered view (view_order).
func rebuild() -> void:
	if inventory == null:
		return
	var view := view_order(inventory, sort_key, filter_id)
	var want := view.size()
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
	_cell_of.clear()
	for k in want:
		var i: int = view[k]
		var s: ItemStack = inventory.slots[i] if i < inventory.slots.size() else null
		if s != null and s.def_id == Inventory.LOCK:
			s = null
		if s == null:
			_empty += 1
		_cells[k].set_stack(s, i)
		_cells[k].is_new = s != null and s.uid != "" and new_uids.has(s.uid)
		_cells[k].selected = i == selected_index
		_cells[k].member = multi.has(i)
		_cell_of[i] = _cells[k]
	_place()

## Slot indices in draw order. No sort and no filter: 0..slot_count-1. A sort draws the occupied
## slots in key order, then the empty ones (capacity stays visible); a filter draws matches only.
static func view_order(inv: Inventory, key: String, filter: String) -> Array[int]:
	var out: Array[int] = []
	var empties: Array[int] = []
	for i in inv.slot_count:
		var s: ItemStack = inv.slots[i] if i < inv.slots.size() else null
		if s == null or s.def_id == Inventory.LOCK:
			if filter == "":
				empties.append(i)
			continue
		if filter == "" or matches(s, filter):
			out.append(i)
	if key == "":
		if filter == "":
			out.clear()
			for i in inv.slot_count:
				out.append(i)
		return out
	var keyed := out.map(func(i: int) -> Array: return [sort_value(inv.slots[i], key), i])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	out.clear()
	for row: Array in keyed:
		out.append(int(row[1]))
	out.append_array(empties)
	return out

## Comparable key: type = first category then name; level = highest first; name = display name.
static func sort_value(s: ItemStack, key: String) -> String:
	var d := s.def()
	var nm := (d.display_name if d and d.display_name != "" else str(s.def_id)).to_lower()
	match key:
		"type":
			return "%s|%s|%03d" % [str(d.categories[0]) if d and not d.categories.is_empty() else "~", nm, 999 - s.level]
		"level":
			return "%03d|%s" % [999 - s.level, nm]
	return "%s|%03d" % [nm, 999 - s.level]

## Whether an instance shows under a filter (spec 13 s9 "filter by relevant item categories").
static func matches(s: ItemStack, filter: String) -> bool:
	var d := s.def()
	var food := Food.is_food(s)
	var gear := d != null and Inventory.slot_for(d) not in [&"", &"weapon"] # worn armour, clothes, bags
	var tool := d != null and ((d.tool_class != &"" and d.tool_class != &"none") or d.has_category(&"tool") or d.has_category(&"weapon"))
	var building := d != null and (d.place_as != &"" or d.has_category(&"building"))
	match filter:
		"food":
			return food
		"gear":
			return gear
		"tools":
			return tool
		"building":
			return building
		"rare":
			return InvAttributes.has_rare(s)
		"locked":
			return s.is_locked()
		"materials":
			return not (food or gear or tool or building)
	return true

func _on_cell_input(event: InputEvent, c: Cell) -> void:
	if readonly or inventory == null or c.index < 0:
		return
	var mm := event as InputEventMouseMotion
	if mm != null:
		var at_m: Vector2 = c.get_global_rect().position + mm.position
		_last_pos = at_m
		if _painting:
			paint_to(_index_at(at_m))
			c.accept_event() # the finger paints; the ScrollContainer must not scroll
		elif _press_cell >= 0 and at_m.distance_to(_press_pos) > TAP_DEADZONE:
			_press_cell = -1 # it became a scroll: no long-press
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var at: Vector2 = c.get_global_rect().position + mb.position
	if mb.pressed:
		_press_cell = c.index
		_press_pos = at
		_last_pos = at
		_press_ms = Time.get_ticks_msec()
		# In select mode (or with Shift held) a press paints at once; else a long press enters it.
		if multi_mode or mb.shift_pressed:
			if not multi_mode:
				multi_started.emit()
				set_multi_mode(true)
			begin_paint(c.index)
			c.accept_event()
		set_process(true)
		return
	if _painting:
		end_paint()
		c.accept_event()
		return
	if _press_cell != c.index:
		return # released over another cell (or a drag left this one)
	_press_cell = -1
	if at.distance_to(_press_pos) > TAP_DEADZONE or c.stack == null:
		return
	if multi_mode:
		toggle_multi(c.index) # the host repaints its batch bar from multi_list()
		multi_changed.emit()
		return
	selected_index = c.index
	for k in _cells:
		k.selected = k.index == selected_index
	selected.emit(c.index)

## Long press and edge auto-scroll run here while a finger is down.
func _process(delta: float) -> void:
	if _press_cell >= 0 and not _painting and Time.get_ticks_msec() - _press_ms >= int(long_press_s * 1000.0):
		var start := _press_cell
		_press_cell = -1
		if not multi_mode:
			multi_started.emit()
			set_multi_mode(true)
		begin_paint(start)
	if _painting:
		var r := get_global_rect()
		var dir := 0.0
		if _last_pos.y < r.position.y + EDGE_PX:
			dir = -1.0
		elif _last_pos.y > r.end.y - EDGE_PX:
			dir = 1.0
		if dir != 0.0:
			_scroll.scroll_vertical += int(dir * AUTOSCROLL_PX_S * delta)
			paint_to(_index_at(_last_pos))
	elif _press_cell < 0:
		set_process(false)

## Paint selection (owner 2026-10-27, "hold/drag to select multiple"): the gesture's path starts at
## `index`; each cell the pointer enters joins the batch, and moving back onto a cell already on the
## path un-paints everything after it (they return to how they were before the gesture).
func begin_paint(index: int) -> void:
	_painting = true
	_pre = multi.duplicate()
	_path.clear()
	_tap_toggle = true
	paint_to(index)

func paint_to(index: int) -> void:
	if not _painting or index < 0 or inventory == null:
		return
	var at := _path.find(index)
	if at >= 0:
		if at == _path.size() - 1:
			return
		for k in range(_path.size() - 1, at, -1):
			var gone: int = _path.pop_back()
			if not _pre.has(gone):
				multi.erase(gone)
		_tap_toggle = false
	else:
		var s: ItemStack = inventory.slots[index] if index < inventory.slots.size() else null
		if s == null or s.def_id == Inventory.LOCK:
			return # empty compartments never join (they would only skew the count)
		_path.append(index)
		if _path.size() > 1:
			_tap_toggle = false
		if not multi.has(index):
			multi.append(index)
	for c in _cells:
		c.member = multi.has(c.index)
	multi_changed.emit()

## End of the gesture. A one-cell press that started on an already-marked cell is a tap: it unmarks.
func end_paint() -> void:
	if not _painting:
		return
	_painting = false
	_press_cell = -1
	if _tap_toggle and _path.size() == 1 and _pre.has(_path[0]):
		multi.erase(_path[0])
	for c in _cells:
		c.member = multi.has(c.index)
	_path.clear()
	multi_changed.emit()

## The slot index drawn under a global point, -1 for none.
func _index_at(p: Vector2) -> int:
	for c in _cells:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return c.index
	return -1

## Whether a press/release pair counts as a tap (used by the lab to drive the same path as touch).
func is_tap(press: Vector2, release: Vector2) -> bool:
	return press.distance_to(release) <= TAP_DEADZONE

func _relayout() -> void:
	var w := maxf(size.x - SCROLLBAR_PX, 1.0)
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
	# Width 0: the ScrollContainer fills it; a width of size.x plus the scrollbar grew the grid past
	# its panel every layout pass (t_invscreens overflow check).
	_grid.custom_minimum_size = Vector2(0.0, maxf(1.0, rows * cell_px + maxf(0.0, rows - 1) * gap))
	_grid.columns = columns
