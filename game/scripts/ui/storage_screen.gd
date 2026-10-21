class_name StorageScreen
extends Control
## A container and the Bag on the shared grid (spec 13 s17; the owner's storage-transfer reference,
## 2026-10-20): storage boxes, baskets, home cargo, corpse loot and dinosaur cargo. Two tabs over one
## grid, "Bag 91 / 100" and "<container> 5 / 60" (the active one gold); a left rail of category
## filters; the toolbar's Auto Sort, Select All, Select (multi-select: "N Select" in the header and a
## gold check on each picked item), Search and Lock; the inspection panel on the right shows the
## instance tapped last, its yellow primary the transfer ("Transfer to Bag" from the container,
## "Transfer to <container>" from the Bag). A take-only container says why in a notice over the grid.
## The host (InventoryUI) owns the transfer rules and says which moves apply through set_actions.

signal back_pressed
signal close_pressed
## Bag slots to move into the container (every picked one in multi-select).
signal store_pressed(indices: Array[int])
## Container slots to move into the bag.
signal take_pressed(indices: Array[int])
signal take_all_pressed
## The Bag tab's focus changed (the host's store rule reads it).
signal bag_selected(index: int)

var header: InvHeader
var bag_grid: InventoryGrid
var box_grid: InventoryGrid
var toolbar: BagToolbar
var rail: FilterRail
var inspect: ItemInspectPanel
var bag_tab: InvTab
var box_tab: InvTab
var player: Player
## &"storage" or &"cargo" (InvActions ctx.where).
var kind: StringName = &"storage"
## &"box" (the container, as it opens) or &"bag": what the grid shows.
var tab: StringName = &"box"
var _title := ""
var _notice: Label
var _can := {"store": false, "take": false, "take_all": false}
var _note := ""
var _store_why := ""
var _m := {}
## Per tab, 1 -> 0 after items arrive there (InvMotion.FLASH_S).
var _flash := {&"bag": 0.0, &"box": 0.0}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(InvTheme.backdrop()) # opaque: HUD controls must not show through a modal screen
	bag_grid = InventoryGrid.new()
	add_child(bag_grid)
	box_grid = InventoryGrid.new()
	add_child(box_grid)
	rail = FilterRail.new()
	add_child(rail)
	bag_tab = _tab(&"bag")
	box_tab = _tab(&"box")
	toolbar = BagToolbar.new()
	add_child(toolbar)
	inspect = ItemInspectPanel.new()
	inspect.toolbar_actions = []
	add_child(inspect)
	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_notice.clip_text = true
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_stylebox_override("normal", InvTheme.button_box(Color(0.13, 0.13, 0.125, 0.94), Color(0, 0, 0, 0), 4))
	add_child(_notice)
	header = InvHeader.new()
	add_child(header)
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	header.close_pressed.connect(func() -> void: close_pressed.emit())
	bag_grid.selection_changed.connect(func(_k: String) -> void:
		if tab == &"bag":
			bag_selected.emit(bag_grid.selected_index())
		_refresh())
	box_grid.selection_changed.connect(func(_k: String) -> void: _refresh())
	rail.chosen.connect(func(id: StringName) -> void:
		for g in _grids():
			g.set_view(g.view_key, id))
	toolbar.squares = [&"select_all", &"select", &"search", &"lock"]
	toolbar.sort_pressed.connect(func(key: StringName) -> void:
		for g in _grids():
			g.auto_sort(key))
	toolbar.select_toggled.connect(_set_multi)
	toolbar.select_all_pressed.connect(func() -> void:
		_set_multi(true)
		toolbar.set_select(true)
		_grid().select_all())
	toolbar.search_changed.connect(func(t: String) -> void:
		for g in _grids():
			g.set_query(t))
	toolbar.lock_pressed.connect(func() -> void: InvActions.toggle_locks(player, bag_grid.selected_indices(), _ctx()))
	toolbar.drop_pressed.connect(func() -> void:
		for i in bag_grid.selected_indices():
			InvActions.run(&"drop", player, i, _ctx()))
	inspect.action_pressed.connect(_on_action)
	resized.connect(_layout)

func setup(bag: Inventory, box: Inventory, title: String, p: Player = null, p_kind: StringName = &"storage") -> void:
	player = p
	kind = p_kind
	_title = title
	toolbar.close_menu()
	toolbar.set_search(false)
	toolbar.set_select(false)
	bag_grid.multi = false
	box_grid.multi = false
	bag_grid.bind(bag)
	box_grid.bind(box)
	for g in _grids():
		g.query = ""
		g.view_key = &"acquired"
	rail.choose(&"all") # every grid back to All, in pickup order
	for inv in [bag, box]:
		if inv and not (inv as Inventory).changed.is_connected(_paint_tabs):
			(inv as Inventory).changed.connect(_paint_tabs)
	show_tab(&"box")

## Which transfers apply now. `note` is the container's read-only reason (shown over the grid; Take
## is not offered), `store_why` why the Bag's focus cannot go in.
func set_actions(can_store: bool, can_take: bool, can_take_all: bool, note: String, store_why: String = "") -> void:
	_can = {"store": can_store, "take": can_take and note == "", "take_all": can_take_all and note == ""}
	_note = note
	_store_why = store_why
	_refresh()

## Shows the Bag (&"bag") or the container (&"box") in the grid.
func show_tab(t: StringName) -> void:
	var changed := t != tab
	tab = t
	bag_grid.visible = t == &"bag"
	box_grid.visible = t == &"box"
	# Lock and Drop act on the player's own bag only (nothing locked can be in a container).
	var sq: Array[StringName] = [&"select_all", &"select", &"search"]
	if t == &"bag":
		sq.append(&"lock")
	toolbar.squares = sq
	if t == &"bag":
		bag_selected.emit(bag_grid.selected_index())
	_layout()
	_refresh()
	if changed:
		InvMotion.fade_in(active_grid(), InvMotion.TAB_S)

## Small transfer feedback (spec 13 s20): the tab that received items lights up briefly.
func flash_tab(id: StringName) -> void:
	InvMotion.run(self, func(t: float) -> void:
		_flash[id] = 1.0 - t
		_paint_tabs(), InvMotion.FLASH_S)

## The grid the open tab shows.
func active_grid() -> InventoryGrid:
	return _grid()

## Selects the instance with this identity on whichever side holds it, switching to that tab.
func select_key(key: String) -> void:
	if bag_grid.has_key(key):
		show_tab(&"bag")
		bag_grid.select_uid(key)
	elif box_grid.has_key(key):
		show_tab(&"box")
		box_grid.select_uid(key)

## The instance the panel shows: the active tab's focus.
func shown_stack() -> ItemStack:
	var g := _grid()
	var i := g.selected_index()
	return g.inventory.slots[i] if g.inventory and i >= 0 else null

## The take-only reason over the grid ("" when none).
func notice_text() -> String:
	return _notice.text if _notice.visible else ""

## The transfer buttons the panel shows now, by action (tests and the lab press these).
func action_button(action: StringName) -> Button:
	return inspect.button_for(action)

func _tab(id: StringName) -> InvTab:
	var b := InvTab.new()
	b.pressed.connect(func() -> void: show_tab(id))
	add_child(b)
	return b

func _grids() -> Array[InventoryGrid]:
	return [bag_grid, box_grid]

func _grid() -> InventoryGrid:
	return bag_grid if tab == &"bag" else box_grid

func _ctx() -> Dictionary:
	return {"where": &"bag", "player": player}

func _set_multi(on: bool) -> void:
	for g in _grids():
		g.multi = on
	_refresh()

func _tab_text(id: StringName) -> Array:
	var inv := bag_grid.inventory if id == &"bag" else box_grid.inventory
	return ["Bag" if id == &"bag" else _title, "%d / %d" % [inv.used_slots(), inv.slot_count] if inv else ""]

## The reference's tabs (InvTab): the active one gold with its underline; a tab lights up as items land.
func _paint_tabs() -> void:
	for pair in [[bag_tab, &"bag"], [box_tab, &"box"]]:
		var b: InvTab = pair[0]
		var parts := _tab_text(pair[1])
		b.label = str(parts[0])
		b.count = str(parts[1])
		b.active = tab == pair[1]
		b.flash = float(_flash[pair[1]])
		if not _m.is_empty():
			b.px = int(_m.row_font) + (2 if _m.compact else 4)
			b.pad = float(_m.margin) + 4.0
		b.queue_redraw()

## The tab's width: its name, a gap and its count, never narrower than the reference's.
func _tab_w(id: StringName) -> float:
	return (bag_tab if id == &"bag" else box_tab).wanted_width(150.0 if _m.compact else 230.0)

func _refresh() -> void:
	var g := _grid()
	if g.multi:
		header.set_title("Select", "%d" % g.selected_indices().size())
	else:
		header.set_title(_title)
	if tab == &"bag":
		var picked := bag_grid.selected_indices()
		toolbar.set_lock_state(InvActions.all_locked(bag_grid.inventory, picked), not picked.is_empty())
	_notice.text = (_note.left(1).to_upper() + _note.substr(1)) if _note != "" else ""
	_notice.visible = _note != "" and tab == &"box"
	_paint_tabs()
	_refresh_inspect()
	if not _m.is_empty():
		_place_notice()

func _refresh_inspect() -> void:
	var st := shown_stack()
	var acts: Array[StringName] = []
	var notes: Array = []
	if tab == &"bag":
		if st and _can.store:
			acts.append(&"store")
		elif st and _store_why != "":
			notes.append([_store_why, InvTheme.TEXT_2])
	else:
		if st and _can.take:
			acts.append(&"take")
		if _can.take_all:
			acts.append(&"take_all")
	var labels := {&"store": "Transfer to %s" % ("Cargo" if kind == &"cargo" else _title), &"take": "Transfer to Bag"}
	var ctx := {"where": kind, "player": player, "actions": acts, "notes": notes, "title": _title, "labels": labels}
	var summary: Array = []
	if st == null and bag_grid.inventory and box_grid.inventory:
		var bag_t := _tab_text(&"bag")
		var box_t := _tab_text(&"box")
		summary = [[bag_t[0], bag_t[1]], [box_t[0], box_t[1]], ["Tap items to pick them." if _grid().multi else "Tap an item to move it."]]
	inspect.show_stack(st, ctx, summary)

func _on_action(action: StringName) -> void:
	match action:
		&"store":
			store_pressed.emit(bag_grid.selected_indices())
		&"take":
			take_pressed.emit(box_grid.selected_indices())
		&"take_all":
			take_all_pressed.emit()

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var safe := InvTheme.safe(get_viewport()) if is_inside_tree() else Vector4.ZERO
	_m = InvTheme.metrics(Vector2(size.x - safe.w - safe.x, size.y))
	var pad: float = _m.margin
	var gap: float = _m.gap
	var head_h: float = _m.header_h + safe.z
	header.position = Vector2.ZERO
	header.size = Vector2(size.x, head_h)
	header.insets = safe
	header.apply_metrics(_m)
	var left := pad + safe.w
	var right := size.x - pad - safe.x
	var bottom := size.y - pad - safe.y
	var top := head_h + gap * 0.5
	var tab_h := 44.0 if _m.compact else 56.0
	var bar_h: float = _m.toolbar_h
	var inspect_w: float = _m.inspect_w
	var main_r := right - inspect_w - gap
	_paint_tabs() # their texts and type, before they are measured
	# Tabs over the rail and grid, from the left edge, the reference's way.
	bag_tab.position = Vector2(left, top)
	bag_tab.size = Vector2(_tab_w(&"bag"), tab_h)
	box_tab.position = Vector2(bag_tab.position.x + bag_tab.size.x + 6.0, top)
	box_tab.size = Vector2(minf(_tab_w(&"box"), main_r - box_tab.position.x), tab_h)
	var body_y := top + tab_h + (6.0 if _m.compact else 10.0)
	var rail_w := 44.0 if _m.compact else 56.0
	toolbar.position = Vector2(left, bottom - bar_h)
	toolbar.size = Vector2(main_r - left, bar_h)
	toolbar.apply_metrics(_m)
	rail.position = Vector2(left, body_y)
	rail.size = Vector2(rail_w, toolbar.position.y - 6.0 - body_y)
	rail.set_side(rail_w)
	var gx := left + rail_w + 6.0
	# ASSUMPTION: the container view is denser than the Bag (the reference shows 13 columns): cells
	# of about data storage.cell px, still wide enough for NEW beside "Lv. NN".
	var sdata: Dictionary = InvView.data().get("storage", {})
	var want := float(sdata.get("cell_compact" if _m.compact else "cell", 84 if _m.compact else 100))
	var cols := maxi(3, int(floorf((main_r - gx - 2.0) / want)))
	for g in _grids():
		g.columns = cols
		var cell := floorf((main_r - gx - 2.0) / cols)
		g.lv_px = maxi(UiTokens.TYPE_MIN, roundi(cell * 0.14))
		g.new_px = maxi(UiTokens.TYPE_MIN, roundi(cell * 0.11))
		g.position = Vector2(gx, body_y)
		g.size = Vector2(main_r - gx, rail.position.y + rail.size.y - body_y)
		g.refresh()
	var ix := main_r + gap
	inspect.position = Vector2(ix, top)
	inspect.size = Vector2(right - ix, bottom - top)
	inspect.apply_metrics(_m)
	_place_notice()
	_paint_tabs()

## The notice sits over the top of the grid, centred, like the reference's tooltip.
func _place_notice() -> void:
	var g := _grid()
	var px: int = _m.row_font
	_notice.add_theme_font_size_override("font_size", px)
	var w := InvTheme.font().get_string_size(_notice.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 32.0
	_notice.size = Vector2(minf(w, g.size.x - 16.0), float(px) * 2.0)
	_notice.position = Vector2(g.position.x + (g.size.x - _notice.size.x) * 0.5, g.position.y + 6.0)
