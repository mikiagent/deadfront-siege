class_name BagScreen
extends Control
## Durango's Bag as it opens in play (spec 13 s4-12; the owner's third inventory reference, "inventory
## menu while in game, scrollview"): a panel docked on the right with the black header "< Bag  X",
## the Bag tab with its capacity, the category rail, a scrolling grid of single instances and the
## Auto Sort / Select / Filter / Lock / Trash toolbar. The world stays visible and live on the left
## and the item card (ItemInspectPanel) floats between the world and the panel while an item is
## selected. Selecting a cell moves the brackets, clears its NEW tag and inspects that exact
## instance. Outside the panel and the card the screen ignores the pointer, so a tap on the world
## reaches InventoryUI, which closes the family. Lays itself out from its own size (full-rect child).
# ASSUMPTION: the dock covers every use of the first reference's full-screen Bag (the card carries the
# same inspection and actions), so the Bag is only the dock; the picker keeps that full-screen layout.

signal back_pressed
signal close_pressed
## An action that leaves the bag for the world (eat, place) ran: the host closes the family.
signal leave_requested
## Equip on gear: the host opens Equipment to compare first (spec 13 s15; design assumption 19).
signal equip_requested(index: int)

var inventory: Inventory
var player: Player
var tracker: InvNewTracker
var header: InvHeader
## The capacity in the header on a phone (no tab row there); a desktop shows it on the tab.
var capacity: CapacityIndicator
var tab: InvTab
var rail: FilterRail
var grid: InventoryGrid
var toolbar: BagToolbar
## The floating item card.
var inspect: ItemInspectPanel
var _panel: ColorRect
var _edge: Control
var _dock := Rect2()
var _m := {}
## The instance inspected last. Its NEW tag stays while it is selected (the reference shows a
## selected cage still NEW) and clears when the selection moves on or the bag closes.
var _seen: ItemStack
## Bag slots the trash is asking to discard; the card shows the confirm while this is set.
var _discard: Array[int] = []
## The HUD is faded out beside the phone dock (_sync_hud).
var _hud_away := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = InvTheme.backdrop()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP # a tap on the panel itself never reaches the world
	add_child(_panel)
	_edge = Control.new()
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge.draw.connect(func() -> void: InvPaint.frame(_edge, Rect2(Vector2.ZERO, _edge.size), 3.0, 11))
	add_child(_edge)
	rail = FilterRail.new()
	add_child(rail)
	grid = InventoryGrid.new()
	add_child(grid)
	toolbar = BagToolbar.new()
	add_child(toolbar)
	tab = InvTab.new()
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE # one tab switches nothing: a heading with the count
	tab.label = "Bag"
	tab.active = true
	tab.count_icon = UiIcons.icon(&"bag")
	add_child(tab)
	inspect = ItemInspectPanel.new()
	inspect.visible = false
	add_child(inspect)
	header = InvHeader.new()
	header.show_stones = false # the in-game reference's header holds only back, title and close
	add_child(header)
	header.set_title("Bag")
	capacity = CapacityIndicator.new()
	header.set_middle(capacity)
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	header.close_pressed.connect(func() -> void: close_pressed.emit())
	grid.selection_changed.connect(_on_selection)
	rail.chosen.connect(func(id: StringName) -> void:
		toolbar.set_filter(id)
		grid.set_view(grid.view_key, id))
	toolbar.sort_pressed.connect(func(key: StringName) -> void: grid.auto_sort(key))
	toolbar.filter_chosen.connect(func(id: StringName) -> void: rail.choose(id))
	toolbar.select_toggled.connect(func(on: bool) -> void:
		grid.multi = on
		_on_selection(grid.selected_uid()))
	toolbar.lock_pressed.connect(_toggle_lock)
	toolbar.drop_pressed.connect(_drop_selected)
	toolbar.trash_pressed.connect(_ask_discard)
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
	_set_squares()
	_layout()
	_on_selection(grid.selected_uid())

## Lock and Trash only where they work (offline: the server has neither op yet). Set on every open,
## since a session can go online after the bag was bound.
func _set_squares() -> void:
	var sq: Array[StringName] = [&"select", &"filter"]
	if InvActions.can_lock(player):
		sq.append(&"lock")
	if InvActions.can_discard(player):
		sq.append(&"trash")
	if sq != toolbar.squares:
		toolbar.squares = sq

## Selects the instance at bag slot `i` (-1 clears).
func select_index(i: int) -> void:
	grid.select_uid(InventoryGrid.key_of(inventory, i))

func select_uid(uid: String) -> void:
	grid.select_uid(uid)

func ctx() -> Dictionary:
	return {"where": &"bag", "player": player}

## The docked panel's rect (the world shows left of it, under the card).
func dock_rect() -> Rect2:
	return _dock

func _on_selection(_key: String) -> void:
	var i := grid.selected_index()
	var s: ItemStack = inventory.slots[i] if inventory and i >= 0 else null
	if _seen and _seen != s:
		_acknowledge(_seen)
	_seen = s
	_discard.clear()
	_show_card(s, ctx())
	_update_lock()

## The card floats in while an item is selected and leaves the world clear when none is.
func _show_card(s: ItemStack, c: Dictionary) -> void:
	var was := inspect.visible
	inspect.visible = s != null
	if s:
		inspect.show_stack(s, c)
		if not was:
			InvMotion.fade_in(inspect)

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

## Rebuild the grid and the inspected item from the bag now (the host calls it on open).
func refresh() -> void:
	_set_squares()
	grid.refresh()
	_paint_tab()
	_reinspect()

func _on_inventory_changed() -> void:
	_paint_tab()
	# Hidden, nothing to redraw: open_bag refreshes. Shown, the grid refreshes deferred and the
	# card re-inspects after it, so a locked or used item shows its new state.
	if is_visible_in_tree():
		_reinspect.call_deferred()

func _reinspect() -> void:
	_on_selection(grid.selected_uid())

func _paint_tab() -> void:
	tab.count = capacity.label_text()
	tab.count_color = capacity.count_color()
	tab.queue_redraw()

func _update_lock() -> void:
	var picked := grid.selected_indices()
	toolbar.set_lock_state(InvActions.all_locked(inventory, picked), not picked.is_empty())
	toolbar.set_trash_state(not picked.is_empty())

func _toggle_lock() -> void:
	InvActions.toggle_locks(player, grid.selected_indices(), ctx())

func _drop_selected() -> void:
	for i in grid.selected_indices():
		InvActions.run(&"drop", player, i, ctx())

## The trash: the card asks first (a discard cannot be undone); locked items stay (spec 13 s9).
func _ask_discard() -> void:
	var picked := grid.selected_indices()
	if picked.is_empty() or inventory == null:
		return
	var ask := InvActions.discard_prompt(inventory, picked, player)
	_discard = ask.gone
	var focus := inventory.slots[_discard[0] if not _discard.is_empty() else picked[0]]
	_show_card(focus, {"where": &"bag", "player": player, "actions": ask.actions, "notes": ask.notes})

func _run(action: StringName) -> void:
	if action == &"keep":
		_reinspect()
		return
	if action == &"discard":
		var gone := _discard.duplicate()
		_discard.clear()
		for i in gone:
			InvActions.run(&"discard", player, i, ctx())
		return
	var i := grid.selected_index()
	if i < 0 or player == null:
		return
	if action == &"equip":
		equip_requested.emit(i)
		return
	if InvActions.closes_ui(action):
		leave_requested.emit()
	InvActions.run(action, player, i, ctx())

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var safe := InvTheme.safe(get_viewport()) if is_inside_tree() else Vector4.ZERO
	_m = InvTheme.dock_metrics(Vector2(size.x - safe.w - safe.x, size.y))
	var pad: float = _m.margin
	var gap: float = _m.gap
	var dock_w: float = float(_m.dock_w) + safe.x
	var x0 := size.x - dock_w
	_dock = Rect2(x0, 0.0, dock_w, size.y)
	_panel.position = _dock.position
	_panel.size = _dock.size
	_edge.position = _dock.position
	_edge.size = _dock.size
	var head_h: float = float(_m.header_h) + safe.z
	header.position = Vector2(x0, 0.0)
	header.size = Vector2(dock_w, head_h)
	header.insets = Vector4(safe.x, safe.y, safe.z, 0.0) # the dock's left edge is mid-screen: no inset there
	header.apply_metrics(_m)
	capacity.visible = bool(_m.compact)
	capacity.font_px = int(_m.row_font) + 4
	capacity.refresh()
	var left := x0 + pad
	var right := size.x - pad - safe.x
	var bottom := size.y - pad - safe.y
	var top := head_h + gap
	var rail_w: float = _m.rail_w
	var gx := left + rail_w + gap
	tab.visible = not bool(_m.compact)
	if tab.visible:
		tab.px = int(_m.row_font) + 2
		tab.pad = pad
		_paint_tab()
		tab.position = Vector2(gx, top)
		tab.size = Vector2(minf(tab.wanted_width(200.0), right - gx), _m.tab_h)
		top += float(_m.tab_h) + 4.0
	toolbar.position = Vector2(left, bottom - float(_m.toolbar_h))
	toolbar.size = Vector2(right - left, _m.toolbar_h)
	toolbar.apply_metrics(_m)
	var body_bottom := toolbar.position.y - gap
	rail.position = Vector2(left, top)
	rail.size = Vector2(rail_w, body_bottom - top)
	rail.set_side(rail_w)
	grid.columns = int(_m.columns)
	grid.lv_px = int(_m.lv_font)
	grid.new_px = int(_m.new_font)
	grid.position = Vector2(gx, top)
	grid.size = Vector2(minf(float(_m.grid_w) + 2.0, right - gx), body_bottom - top)
	grid.refresh()
	# The card floats between the world and the panel, from just under the header's line down to the
	# HUD's level line along the bottom edge (it ran over "Lv. 13 70.5%" at 1600x900).
	var card_w: float = _m.card_w
	var card_bottom := bottom if bool(_m.compact) else minf(bottom, size.y - InvTheme.HUD_STRIP)
	inspect.position = Vector2(x0 - gap - card_w, head_h + 4.0)
	inspect.fit_max_h = card_bottom - head_h - 4.0 # it ends under its content (ItemInspectPanel._fit)
	inspect.size = Vector2(card_w, minf(inspect.size.y, inspect.fit_max_h) if inspect.size.y > 0.0 else inspect.fit_max_h)
	inspect.apply_metrics(_m)
	_sync_hud()

## On a phone the dock and the card leave the HUD no room beside them (at 844x390 the card ran over
## the vitals and the hexes: "BUIL"), so the HUD steps aside while the Bag is open there and comes back
## when it closes. It takes no taps meanwhile anyway (a tap on the world closes the Bag).
func _sync_hud() -> void:
	var hud := get_tree().get_first_node_in_group(&"hud") as CanvasItem if is_inside_tree() else null
	var away := hud != null and is_visible_in_tree() and bool(_m.get("compact", false))
	if hud and away != _hud_away:
		hud.modulate.a = 0.0 if away else 1.0
	_hud_away = away

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_hud()
	elif what == NOTIFICATION_EXIT_TREE and _hud_away:
		var hud := get_tree().get_first_node_in_group(&"hud") as CanvasItem
		if hud:
			hud.modulate.a = 1.0
		_hud_away = false
