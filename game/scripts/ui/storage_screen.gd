class_name StorageScreen
extends Control
## A container beside the Bag on the shared grid (spec 13 s17): storage boxes, baskets, home cargo,
## corpse loot and dinosaur cargo. Each side is its own InventoryGrid with its own capacity strip and
## Auto Sort / Filter toolbar; the inspection panel on the right shows the exact instance last tapped
## on either side, with the transfer that applies to it as its yellow primary (Store from the bag,
## Take from the container, Take All beside it). The host (InventoryUI) owns the transfer rules and
## says which moves apply through set_actions; this screen only presents them.

signal back_pressed
signal close_pressed
signal store_pressed
signal take_pressed(index: int)
signal take_all_pressed
signal bag_selected(index: int)

var header: InvHeader
var bag_grid: InventoryGrid
var box_grid: InventoryGrid
var bag_bar: BagToolbar
var box_bar: BagToolbar
var inspect: ItemInspectPanel
var player: Player
## &"storage" or &"cargo" (InvActions ctx.where).
var kind: StringName = &"storage"
var _title := ""
var _bag_cap: CapacityIndicator
var _box_cap: CapacityIndicator
var _bag_label: Label
var _box_label: Label
var _can := {"store": false, "take": false, "take_all": false}
var _note := ""
var _store_why := ""
## The side tapped last: its selection is what the panel shows.
var _side: StringName = &""
var _m := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = InvTheme.BG # opaque: HUD controls must not show through a modal screen
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	bag_grid = InventoryGrid.new()
	add_child(bag_grid)
	box_grid = InventoryGrid.new()
	add_child(box_grid)
	_bag_label = _strip_label("Bag")
	_box_label = _strip_label("")
	_bag_cap = CapacityIndicator.new()
	add_child(_bag_cap)
	_box_cap = CapacityIndicator.new()
	add_child(_box_cap)
	bag_bar = _side_bar(bag_grid)
	box_bar = _side_bar(box_grid)
	inspect = ItemInspectPanel.new()
	add_child(inspect)
	header = InvHeader.new()
	header.show_stones = false # the title is long (a pet's name); T-stones belong to the Bag
	add_child(header)
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	header.close_pressed.connect(func() -> void: close_pressed.emit())
	bag_grid.selection_changed.connect(func(k: String) -> void: _on_pick(&"bag", k))
	box_grid.selection_changed.connect(func(k: String) -> void: _on_pick(&"box", k))
	inspect.action_pressed.connect(_on_action)
	resized.connect(_layout)

func _strip_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(l)
	return l

## Auto Sort and Filter for one side; presentation only, like the Bag's.
func _side_bar(g: InventoryGrid) -> BagToolbar:
	var bar := BagToolbar.new()
	bar.squares = [&"filter"]
	bar.sort_pressed.connect(func(key: StringName) -> void: g.auto_sort(key))
	bar.filter_chosen.connect(func(id: StringName) -> void: g.set_view(g.view_key, id))
	add_child(bar)
	return bar

func setup(bag: Inventory, box: Inventory, title: String, p: Player = null, p_kind: StringName = &"storage") -> void:
	player = p
	kind = p_kind
	_title = title
	header.set_title(title)
	_box_label.text = title
	_side = &""
	bag_grid.bind(bag)
	box_grid.bind(box)
	for pair in [[bag_bar, bag_grid], [box_bar, box_grid]]:
		var bar: BagToolbar = pair[0]
		bar.filter_id = &"all"
		bar.close_menu()
		(pair[1] as InventoryGrid).set_view(&"acquired", &"all")
	_bag_cap.bind(bag)
	_box_cap.bind(box)
	_layout()
	_refresh_inspect()

## Which transfers apply now. `note` is the container's read-only reason (grey; Take is not offered),
## `store_why` why the selected bag item cannot go in.
func set_actions(can_store: bool, can_take: bool, can_take_all: bool, note: String, store_why: String = "") -> void:
	_can = {"store": can_store, "take": can_take and note == "", "take_all": can_take_all and note == ""}
	_note = note
	_store_why = store_why
	_refresh_inspect()

## The instance the panel shows: the last tapped side's selection.
func shown_stack() -> ItemStack:
	var g := bag_grid if _side == &"bag" else box_grid
	var i := g.selected_index()
	return g.inventory.slots[i] if _side != &"" and g.inventory and i >= 0 else null

func _on_pick(side: StringName, key: String) -> void:
	if key == "":
		if side == _side and (bag_grid if side == &"bag" else box_grid).selected_uid() == "":
			_side = &""
		_refresh_inspect()
		return
	_side = side
	# One selection at a time: tapping one side clears the other.
	var other := box_grid if side == &"bag" else bag_grid
	if other.selected_uid() != "":
		other.select_uid("")
	if side == &"bag":
		bag_selected.emit(bag_grid.selected_index())
	_refresh_inspect()

func _refresh_inspect() -> void:
	var st := shown_stack()
	var acts: Array[StringName] = []
	var notes: Array = []
	if st and _side == &"bag":
		if _can.store:
			acts.append(&"store")
		elif _store_why != "":
			notes.append([_store_why, InvTheme.TEXT_2])
	elif st:
		if _can.take:
			acts.append(&"take")
		if _can.take_all:
			acts.append(&"take_all")
	elif _can.take_all:
		acts.append(&"take_all")
	if _note != "":
		notes.append([_note.left(1).to_upper() + _note.substr(1), InvTheme.TEXT_2]) # "needs knife" -> "Needs knife"
	var ctx := {"where": kind, "player": player, "actions": acts, "notes": notes, "title": _title}
	var summary: Array = []
	if st == null and bag_grid.inventory and box_grid.inventory:
		summary = [["Bag", _bag_cap.label_text()], [_title, _box_cap.label_text()], ["Tap an item to move it."]]
	inspect.show_stack(st, ctx, summary)

func _on_action(action: StringName) -> void:
	match action:
		&"store":
			store_pressed.emit()
		&"take":
			take_pressed.emit(box_grid.selected_index())
		&"take_all":
			take_all_pressed.emit()

## The transfer buttons the panel shows now, by action (tests and the lab press these).
func action_button(action: StringName) -> Button:
	for c in inspect.get_children():
		if c is Button and (c as Button).text == InvActions.label(action) and (c as Button).is_in_group(&"inv_contextual"):
			return c
	return null

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var safe := UiTokens.safe_insets(get_viewport()) if is_inside_tree() else Vector4.ZERO
	_m = InvTheme.metrics(Vector2(size.x - safe.w - safe.x, size.y))
	var pad: float = _m.margin
	var gap: float = _m.gap
	var head_h: float = _m.header_h + safe.z
	header.position = Vector2.ZERO
	header.size = Vector2(size.x, head_h)
	header.apply_metrics(_m)
	var left := pad + safe.w
	var right := size.x - pad - safe.x
	var bottom := size.y - pad - safe.y
	var top := head_h + gap
	var inspect_w: float = _m.inspect_w
	var grids_w := right - left - inspect_w - gap
	var half := floorf((grids_w - gap) * 0.5)
	# ASSUMPTION: two grids share the Bag's grid width; each keeps compartments wide enough for NEW
	# and "Lv. NN" side by side (84 px on a phone, like the Bag's), so a phone side is 3 wide.
	var cols := maxi(3, int(floorf((half - 2.0) / (84.0 if _m.compact else 104.0))))
	var strip_h: float = float(_m.row_h) * 1.4
	var bar_h: float = _m.toolbar_h
	for side in [[_bag_label, _bag_cap, bag_grid, bag_bar, left], [_box_label, _box_cap, box_grid, box_bar, left + half + gap]]:
		var l: Label = side[0]
		var cap: CapacityIndicator = side[1]
		var g: InventoryGrid = side[2]
		var bar: BagToolbar = side[3]
		var x: float = side[4]
		l.add_theme_font_size_override("font_size", int(_m.row_font) + 2)
		cap.font_px = int(_m.row_font) + 2
		cap.refresh()
		# "Bag [bag] 91 / 100", the way the Bag's header reads; a long pet name gives way to the count.
		var lw := minf(InvTheme.font().get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_m.row_font) + 2).x + 4.0, half - cap.custom_minimum_size.x - 8.0)
		l.position = Vector2(x, top)
		l.size = Vector2(maxf(0.0, lw), strip_h)
		cap.position = Vector2(x + l.size.x + 8.0, top + (strip_h - cap.custom_minimum_size.y) * 0.5)
		cap.size = cap.custom_minimum_size
		bar.position = Vector2(x, bottom - bar_h)
		bar.size = Vector2(half, bar_h)
		bar.apply_metrics(_m)
		g.columns = cols
		g.lv_px = maxi(UiTokens.TYPE_MIN, int(_m.lv_font) - 2)
		g.new_px = maxi(UiTokens.TYPE_MIN, int(_m.new_font) - 1)
		g.position = Vector2(x, top + strip_h)
		g.size = Vector2(half, bar.position.y - 4.0 - (top + strip_h))
		g.refresh()
	var ix := left + half * 2.0 + gap * 2.0
	inspect.position = Vector2(ix, top)
	inspect.size = Vector2(right - ix, bottom - top)
	inspect.apply_metrics(_m)
