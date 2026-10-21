class_name InventoryGrid
extends Control
## The shared Durango bag grid (spec 13 s5, s12, s17): one textured panel divided by faint lines
## into square compartments, one per instance, empty ones kept up to capacity. A caged animal
## (slot_span 4) takes a 2x2 block and a span-2 item a 2x1 block. Bound to one Inventory and
## read-only: sorting and filtering are InvView orders; selection is by instance identity, so it
## survives refreshes and sorts. Used by the Bag, storage, dinosaur cargo and the ingredient picker.

signal selection_changed(uid: String)

var inventory: Inventory
## How many compartments wide; the cell size follows the grid's width.
var columns := 7
## Several selected at once (the toolbar's Select toggle).
var multi := false:
	set(v):
		multi = v
		if not v:
			_multi.clear()
		elif _sel != "":
			_multi[_sel] = true # the single selection carries into multi-select
		_paint_selection()
var view_key: StringName = &"acquired"
var filter_id: StringName = &"all"
var lv_px := 20
var new_px := 15
## Character / Equipment candidates: the worn instance, shown first with the worn mark. It is out
## of the bag (worn gear leaves it), so its cell has index -1; selection still goes by its uid.
var pinned: ItemStack
## The instance marked worn when it is in the bag itself (the held tool).
var worn_uid := ""
## Compartments drawn down to at least this many rows (a short candidate list keeps its grid lines).
var min_rows := 0
## When set, only these bag slots show (the ingredient picker's candidates: {slot: true}).
var only: Dictionary = {}
## Search text (storage toolbar): only items whose name contains it show; "" shows all.
var query := ""

var _sel := ""
var _multi := {}
var _dirty := true
var _cell_px := 96.0
var _scroll: ScrollContainer
var _content: Control
var _pool: Array[InventorySlot] = []
var _shown: Array[InventorySlot] = []

func _init() -> void:
	clip_contents = true
	add_child(InvTheme.surface(InvTheme.PANEL, 1.3, 1.0))
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 8
	add_child(_scroll)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)
	var frame := Control.new() # over the cells: the panel's dark, irregular edge
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.draw.connect(func() -> void: InvPaint.frame(frame, Rect2(Vector2.ZERO, frame.size), clampf(_cell_px * 0.02, 2.0, 3.0), get_index()))
	frame.resized.connect(frame.queue_redraw)
	add_child(frame)
	resized.connect(_relayout)

func bind(inv: Inventory) -> void:
	if inventory and inventory.changed.is_connected(_mark):
		inventory.changed.disconnect(_mark)
	inventory = inv
	if inventory:
		inventory.changed.connect(_mark)
	_sel = ""
	_multi.clear()
	refresh()

## Show `filter` in `key` order (presentation only).
func set_view(key: StringName, filter: StringName) -> void:
	view_key = key
	filter_id = filter
	refresh()

## Shows only items whose name contains `text` (case-insensitive); presentation only.
func set_query(text: String) -> void:
	query = text.strip_edges().to_lower()
	refresh()

## Auto Sort: reorder the presentation by `key`; the bag's own slots are untouched.
func auto_sort(key: StringName) -> void:
	set_view(key, filter_id)

func columns_count() -> int:
	return columns

func cell_px() -> float:
	return _cell_px

## Selects the instance with this identity (uid, or "#<slot>" for a fungible stack); "" clears.
func select_uid(key: String) -> void:
	_flush()
	if multi:
		if key != "":
			if _multi.has(key):
				_multi.erase(key)
			else:
				_multi[key] = true
		_sel = key if _multi.has(key) else (str(_multi.keys().back()) if not _multi.is_empty() else "")
	else:
		_sel = key if _cell_for(key) != null else ""
	_paint_selection()
	selection_changed.emit(_sel)
	_scroll_to(_cell_for(_sel))

## Multi-select every item shown (the storage toolbar's select-all); the last one is the focus.
func select_all() -> void:
	_flush()
	multi = true
	for c in _shown:
		if c.stack != null:
			_multi[c.uid] = true
			_sel = c.uid
	_paint_selection()
	selection_changed.emit(_sel)

## True when an item with this identity is shown now.
func has_key(key: String) -> bool:
	_flush()
	return _cell_for(key) != null

func selected_uid() -> String:
	_flush()
	return _sel

## Bag slot of the selection, -1 when none.
func selected_index() -> int:
	var c := _cell_for(selected_uid())
	return c.index if c else -1

## Every selected identity (multi mode), else the single selection.
func selected_uids() -> Array[String]:
	_flush()
	var out: Array[String] = []
	if multi:
		for k in _multi:
			out.append(str(k))
	elif _sel != "":
		out.append(_sel)
	return out

## Bag slots of every selected instance, in view order (the pinned worn piece has none).
func selected_indices() -> Array[int]:
	var out: Array[int] = []
	for c: InventorySlot in item_cells():
		if c.selected and c.index >= 0:
			out.append(c.index)
	return out

## Cells holding an item, in view order.
func item_cells() -> Array:
	_flush()
	return _shown.filter(func(c: InventorySlot) -> bool: return c.stack != null)

## Every compartment shown, empty ones included.
func cells() -> Array:
	_flush()
	return _shown.duplicate()

## Identity used for selection: the uid, or the slot for a fungible stack without one.
static func key_of(inv: Inventory, i: int) -> String:
	var s := inv.slots[i] if inv and i >= 0 and i < inv.slot_count else null
	if s == null:
		return ""
	return s.uid if s.uid != "" else "#%d" % i

func refresh() -> void:
	_dirty = false
	for c in _shown:
		c.visible = false
		_pool.append(c)
	_shown.clear()
	if inventory == null:
		return
	_cell_px = floorf(maxf(size.x - 2.0, 40.0) / float(columns))
	var order := InvView.order(inventory, view_key, filter_id)
	if not only.is_empty():
		order = order.filter(func(i: int) -> bool: return only.has(i))
	if query != "":
		order = order.filter(func(i: int) -> bool: return _name_of(inventory.slots[i]).contains(query))
	var taken := {}
	var rows := 0
	if pinned:
		taken[Vector2i.ZERO] = true
		rows = 1
		_put(pinned, -1, pinned.uid, Vector2i.ZERO, Vector2i.ONE)
	for i in order:
		var shape := _shape(inventory.slots[i].slot_span())
		var at := _free_spot(taken, shape)
		for dy in shape.y:
			for dx in shape.x:
				taken[at + Vector2i(dx, dy)] = true
		rows = maxi(rows, at.y + shape.y)
		_place(i, at, shape)
	# Empty compartments: exactly up to capacity in the whole bag; a filtered view completes its rows.
	var all := filter_id == &"all" and only.is_empty() and query == ""
	var empties := inventory.slot_count - inventory.used_slots() if all else 0
	var at := Vector2i.ZERO
	while empties > 0 or at.y < maxi(rows, min_rows):
		if not taken.has(at):
			if all and empties <= 0:
				break
			_place(-1, at, Vector2i.ONE)
			taken[at] = true
			empties -= 1
			rows = maxi(rows, at.y + 1)
		at.x += 1
		if at.x >= columns:
			at = Vector2i(0, at.y + 1)
	_content.custom_minimum_size = Vector2(_cell_px * columns, _cell_px * maxi(rows, min_rows))
	if _sel != "" and _cell_for(_sel) == null:
		_sel = ""
		selection_changed.emit("")
	for k in _multi.keys():
		if _cell_for(str(k)) == null:
			_multi.erase(k)
	_paint_selection()

static func _name_of(s: ItemStack) -> String:
	var d := s.def()
	return (d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(s.def_id))).to_lower()

func _shape(span: int) -> Vector2i:
	match span:
		1:
			return Vector2i.ONE
		2:
			return Vector2i(2, 1)
		4:
			return Vector2i(2, 2)
	return Vector2i(mini(span, columns), ceili(float(span) / float(columns)))

## First row-major position where a w x h block is free.
func _free_spot(taken: Dictionary, shape: Vector2i) -> Vector2i:
	var y := 0
	while true:
		for x in columns - shape.x + 1:
			var ok := true
			for dy in shape.y:
				for dx in shape.x:
					if taken.has(Vector2i(x + dx, y + dy)):
						ok = false
			if ok:
				return Vector2i(x, y)
		y += 1
	return Vector2i.ZERO

func _place(i: int, at: Vector2i, shape: Vector2i) -> void:
	_put(inventory.slots[i] if i >= 0 else null, i, key_of(inventory, i) if i >= 0 else "", at, shape)

func _put(s: ItemStack, i: int, key: String, at: Vector2i, shape: Vector2i) -> void:
	var c: InventorySlot = _pool.pop_back() if not _pool.is_empty() else null
	if c == null:
		c = InventorySlot.new()
		c.pressed.connect(_on_cell_pressed)
		_content.add_child(c)
	c.visible = true
	c.lv_px = lv_px
	c.new_px = new_px
	c.unit = _cell_px
	c.position = Vector2(at) * _cell_px
	c.size = Vector2(shape) * _cell_px
	c.set_stack(s, i, key)
	c.worn = s != null and (s == pinned or (worn_uid != "" and key == worn_uid))
	_shown.append(c)

func _cell_for(key: String) -> InventorySlot:
	if key == "":
		return null
	for c in _shown:
		if c.uid == key and c.stack != null:
			return c
	return null

func _paint_selection() -> void:
	for c in _shown:
		c.checks = multi
		c.selected = c.stack != null and (_multi.has(c.uid) if multi else c.uid == _sel)

## Repaint every cell (a NEW tag was acknowledged, a lock toggled without a bag change).
func redraw() -> void:
	for c in _shown:
		c.queue_redraw()

func _on_cell_pressed(c: InventorySlot) -> void:
	select_uid(c.uid)

func _scroll_to(c: InventorySlot) -> void:
	if c and _scroll and is_inside_tree():
		_scroll.ensure_control_visible.call_deferred(c) # after a fresh refresh the scroll has not sized its content yet

## The bag changed: rebuild once at the end of the frame, or on the next read while hidden.
func _mark() -> void:
	if not _dirty:
		_dirty = true
		if is_visible_in_tree():
			_flush.call_deferred()

func _flush() -> void:
	if _dirty:
		refresh()

func _relayout() -> void:
	var px := floorf(maxf(size.x - 2.0, 40.0) / float(columns))
	if not is_equal_approx(px, _cell_px):
		refresh()
