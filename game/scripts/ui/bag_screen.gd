class_name BagScreen
extends Control
## Durango's Bag (spec 13 s4-12, reference durango-bag-instances): the black header with
## "< Bag [bag] used / cap", the dense textured grid on the left with the Auto Sort / Select /
## Filter / Lock toolbar under it, and the item inspection panel on the right whose yellow primary
## button lines up with the toolbar. Selecting a cell moves the brackets, clears its NEW tag and
## inspects that exact instance. Lays itself out from its own size (full-rect child of the host).

signal back_pressed
signal close_pressed
## An action that leaves the bag for the world (eat, place) ran: the host closes the family.
signal leave_requested

var inventory: Inventory
var player: Player
var tracker: InvNewTracker
var header: InvHeader
var capacity: CapacityIndicator
var grid: InventoryGrid
var toolbar: BagToolbar
var inspect: ItemInspectPanel
var _m := {}
## The instance inspected last. Its NEW tag stays while it is selected (the reference shows a
## selected cage still NEW) and clears when the selection moves on or the bag closes.
var _seen: ItemStack

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = InvTheme.BG # opaque: HUD controls must not show through a modal screen
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	grid = InventoryGrid.new()
	add_child(grid)
	toolbar = BagToolbar.new()
	add_child(toolbar)
	inspect = ItemInspectPanel.new()
	add_child(inspect)
	header = InvHeader.new()
	add_child(header)
	header.set_title("Bag")
	capacity = CapacityIndicator.new()
	header.set_middle(capacity)
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	header.close_pressed.connect(func() -> void: close_pressed.emit())
	grid.selection_changed.connect(_on_selection)
	toolbar.sort_pressed.connect(func(key: StringName) -> void: grid.auto_sort(key))
	toolbar.filter_chosen.connect(func(id: StringName) -> void: grid.set_view(grid.view_key, id))
	toolbar.select_toggled.connect(func(on: bool) -> void:
		grid.multi = on
		_on_selection(grid.selected_uid()))
	toolbar.lock_pressed.connect(_toggle_lock)
	toolbar.drop_pressed.connect(_drop_selected)
	inspect.action_pressed.connect(_run)
	resized.connect(_layout)

func bind(inv: Inventory, p: Player) -> void:
	if inventory and inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	inventory = inv
	player = p
	capacity.bind(inv)
	grid.bind(inv)
	if inventory:
		inventory.changed.connect(_on_inventory_changed)
	_layout()
	_on_selection(grid.selected_uid())

## Selects the instance at bag slot `i` (-1 clears).
func select_index(i: int) -> void:
	grid.select_uid(InventoryGrid.key_of(inventory, i))

func select_uid(uid: String) -> void:
	grid.select_uid(uid)

func ctx() -> Dictionary:
	return {"where": &"bag", "player": player}

func _on_selection(key: String) -> void:
	var i := grid.selected_index()
	var s: ItemStack = inventory.slots[i] if inventory and i >= 0 else null
	if _seen and _seen != s:
		_acknowledge(_seen)
	_seen = s
	if s:
		inspect.show_stack(s, ctx())
	else:
		inspect.show_stack(null, ctx(), _summary())
	_update_lock()

## Clears NEW on the item being inspected (the bag is closing).
func acknowledge_selection() -> void:
	if _seen:
		_acknowledge(_seen)

func _acknowledge(st: ItemStack) -> void:
	if tracker:
		tracker.acknowledge(st)
	else:
		st.set_flag(&"new", false)
	grid.redraw()

## What the panel says with nothing selected: the bag's state, no actions.
func _summary() -> Array:
	if inventory == null:
		return []
	return [["Slots used", "%d / %d" % [inventory.used_slots(), inventory.slot_count]], ["Filter", InvView.filter_label(grid.filter_id)],
		["Sort", InvView.sort_label(grid.view_key)], ["Tap an item to inspect it."]]

## Rebuild the grid and the inspected item from the bag now (the host calls it on open).
func refresh() -> void:
	grid.refresh()
	_reinspect()

func _on_inventory_changed() -> void:
	# Hidden, nothing to redraw: open_bag refreshes. Shown, the grid refreshes deferred and the
	# panel re-inspects after it, so a locked or used item shows its new state.
	if is_visible_in_tree():
		_reinspect.call_deferred()

func _reinspect() -> void:
	_on_selection(grid.selected_uid())

func _selected_indices() -> Array[int]:
	var out: Array[int] = []
	for c: InventorySlot in grid.item_cells():
		if c.selected:
			out.append(c.index)
	return out

func _update_lock() -> void:
	var picked := _selected_indices()
	var all_locked := not picked.is_empty()
	for i in picked:
		all_locked = all_locked and inventory.slots[i].is_locked()
	toolbar.set_lock_state(all_locked, not picked.is_empty())

func _toggle_lock() -> void:
	var picked := _selected_indices()
	if picked.is_empty():
		return
	# All locked -> unlock them all; otherwise lock the ones that are not yet locked.
	var want := false
	for i in picked:
		want = want or not inventory.slots[i].is_locked()
	for i in picked:
		if inventory.slots[i].is_locked() != want:
			InvActions.run(&"lock", player, i, ctx())

func _drop_selected() -> void:
	for i in _selected_indices():
		InvActions.run(&"drop", player, i, ctx())

func _run(action: StringName) -> void:
	var i := grid.selected_index()
	if i < 0 or player == null:
		return
	if InvActions.closes_ui(action):
		leave_requested.emit()
	InvActions.run(action, player, i, ctx())

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var safe := UiTokens.safe_insets(get_viewport()) if is_inside_tree() else Vector4.ZERO
	_m = InvTheme.metrics(Vector2(size.x - safe.w - safe.x, size.y))
	var pad: float = _m.margin
	var left := pad + safe.w
	var right := size.x - pad - safe.x
	var bottom := size.y - pad - safe.y
	var head_h: float = _m.header_h + safe.z
	header.position = Vector2.ZERO
	header.size = Vector2(size.x, head_h)
	header.apply_metrics(_m)
	capacity.font_px = int(_m.cap_font)
	capacity.refresh()
	var top: float = head_h + _m.gap
	var grid_w: float = _m.grid_w + 2.0
	grid.columns = int(_m.columns)
	grid.lv_px = int(_m.lv_font)
	grid.new_px = int(_m.new_font)
	toolbar.position = Vector2(left, bottom - _m.toolbar_h)
	toolbar.size = Vector2(grid_w, _m.toolbar_h)
	toolbar.apply_metrics(_m)
	grid.position = Vector2(left, top)
	grid.size = Vector2(grid_w, toolbar.position.y - 4.0 - top)
	grid.refresh()
	var ix: float = left + grid_w + _m.gap
	inspect.position = Vector2(ix, top)
	inspect.size = Vector2(right - ix, bottom - top)
	inspect.apply_metrics(_m)
