class_name StorageScreen
extends Control
## A container beside the Bag on the shared grid (spec 13 s17): storage boxes, baskets, corpse
## loot and dinosaur cargo. Each side is its own InventoryGrid with its own capacity; the exact
## instance moves with Store / Take. B1 keeps it to that; B3 adds per-side sort and filter and
## the inspect overlay (design section 7). The host (InventoryUI) owns the transfer rules.

signal back_pressed
signal close_pressed
signal store_pressed
signal take_pressed(index: int)
signal take_all_pressed
signal bag_selected(index: int)

var header: InvHeader
var bag_grid: InventoryGrid
var box_grid: InventoryGrid
var _bag_cap: CapacityIndicator
var _box_cap: CapacityIndicator
var _bag_label: Label
var _box_label: Label
var _note: Label
var _store: Button
var _take: Button
var _take_all: Button
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
	_note = _strip_label("")
	_note.add_theme_color_override("font_color", InvTheme.TEXT_2)
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_store = _action("Store", func() -> void: store_pressed.emit())
	_take = _action("Take", func() -> void: take_pressed.emit(box_grid.selected_index()))
	InvTheme.style_primary(_store, 20) # the moves themselves are the yellow primaries; Take All stays dark
	InvTheme.style_primary(_take, 20)
	_take_all = _action("Take All", func() -> void: take_all_pressed.emit())
	header = InvHeader.new()
	add_child(header)
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	header.close_pressed.connect(func() -> void: close_pressed.emit())
	bag_grid.selection_changed.connect(func(_k: String) -> void: bag_selected.emit(bag_grid.selected_index()))
	resized.connect(_layout)

func _strip_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(l)
	return l

func _action(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_to_group(&"inv_contextual")
	b.pressed.connect(cb)
	add_child(b)
	return b

func setup(bag: Inventory, box: Inventory, title: String) -> void:
	header.set_title(title)
	_box_label.text = title
	bag_grid.bind(bag)
	box_grid.bind(box)
	_bag_cap.bind(bag)
	_box_cap.bind(box)
	_layout()

## Which transfers apply now; `note` is the read-only reason (grey), shown instead of Take.
func set_actions(can_store: bool, can_take: bool, can_take_all: bool, note: String) -> void:
	_store.visible = can_store
	_take.visible = can_take and note == ""
	_take_all.visible = can_take_all and note == ""
	_note.text = note
	_layout()

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
	var inner_w := size.x - left - pad - safe.x
	var half := floorf((inner_w - gap) * 0.5)
	var cols := 6 if floorf((half - 2.0) / 6.0) >= 72.0 else 5
	var strip_h: float = float(_m.row_h) * 1.4
	var bar_h: float = _m.secondary_h + 8.0
	var top := head_h + gap
	var grid_h := size.y - pad - safe.y - bar_h - 6.0 - (top + strip_h)
	for side in [[_bag_label, _bag_cap, bag_grid, left], [_box_label, _box_cap, box_grid, left + half + gap]]:
		var l: Label = side[0]
		var cap: CapacityIndicator = side[1]
		var g: InventoryGrid = side[2]
		var x: float = side[3]
		l.add_theme_font_size_override("font_size", int(_m.row_font) + 2)
		cap.font_px = int(_m.row_font) + 2
		cap.refresh()
		cap.position = Vector2(x + half - cap.custom_minimum_size.x, top + (strip_h - cap.custom_minimum_size.y) * 0.5)
		cap.size = cap.custom_minimum_size
		l.position = Vector2(x, top)
		l.size = Vector2(maxf(0.0, half - cap.size.x - 8.0), strip_h)
		g.columns = cols
		g.lv_px = maxi(UiTokens.TYPE_MIN, int(_m.lv_font) - 2)
		g.new_px = int(_m.new_font)
		g.position = Vector2(x, top + strip_h)
		g.size = Vector2(half, grid_h)
		g.refresh()
	var by := size.y - pad - safe.y - bar_h + 4.0
	var x2 := left + inner_w
	for b in [_take_all, _take, _store]:
		if not (b as Button).visible:
			continue
		var w := maxf(160.0 if not _m.compact else 96.0, InvTheme.font().get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_m.button_font)).x + 32.0)
		(b as Button).add_theme_font_size_override("font_size", int(_m.button_font) - (2 if _m.compact else 6))
		(b as Button).size = Vector2(w, _m.secondary_h)
		(b as Button).position = Vector2(x2 - w, by)
		x2 -= w + 8.0
	_note.add_theme_font_size_override("font_size", int(_m.row_font))
	_note.position = Vector2(left, by)
	_note.size = Vector2(maxf(0.0, x2 - left - 8.0), _m.secondary_h)
