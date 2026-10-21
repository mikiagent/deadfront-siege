class_name ItemPicker
extends Control
## The craft and cook ingredient picker (spec 13 s12, s19): the Bag grid filtered to the instances
## that can fill one recipe slot, each one selectable on its own, beside the inspection panel. The
## least valuable instances (Inventory.spend_key: plain before traits, low level first, oldest first)
## come preselected, so a rare one is only spent when the player picks it, and a pick with a rare
## trait or a high level says so before Use. Use hands back the exact bag slots; the craft spends
## those and no other.

signal closed

var inventory: Inventory
var rec: Dictionary = {}
var slot_index := -1
## Units the recipe slot takes (berries for a stew: 1; fibre for twine: 2).
var need := 1
var header: InvHeader
var grid: InventoryGrid
var toolbar: BagToolbar
var inspect: ItemInspectPanel
var _count: Label
var _on_pick: Callable
var _cands: Array[int] = []
var _focus := -1 ## the instance the panel shows: the one tapped last
var _least: Array[int] = [] ## what opening preselected: the least valuable instances
var _syncing := false
var _m := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = InvTheme.BG # opaque, like every screen of the family
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	grid = InventoryGrid.new()
	add_child(grid)
	toolbar = BagToolbar.new()
	toolbar.squares = [] # Auto Sort only: Select is implied, Filter is the recipe's, Lock would hide the item
	add_child(toolbar)
	inspect = ItemInspectPanel.new()
	add_child(inspect)
	header = InvHeader.new()
	header.show_stones = false
	add_child(header)
	_count = Label.new()
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.set_middle(_count)
	header.back_pressed.connect(func() -> void: closed.emit())
	header.close_pressed.connect(func() -> void: closed.emit())
	grid.selection_changed.connect(_on_selection)
	toolbar.sort_pressed.connect(func(key: StringName) -> void: grid.auto_sort(key))
	inspect.action_pressed.connect(func(a: StringName) -> void:
		if a == &"use":
			confirm())
	resized.connect(_layout)

## Opens on recipe `p_rec`'s slot `p_slot`; `taken` are bag slots the recipe's other slots already use.
## `on_pick` gets the chosen bag slots (Array[int], at least one, covering the slot's count).
func open(inv: Inventory, p_rec: Dictionary, p_slot: int, on_pick: Callable, taken: Array = []) -> void:
	inventory = inv
	rec = p_rec
	slot_index = p_slot
	_on_pick = on_pick
	var slots: Array = rec.get("slots", [])
	var slot: Dictionary = slots[p_slot] if p_slot >= 0 and p_slot < slots.size() and slots[p_slot] is Dictionary else {}
	need = maxi(1, int(slot.get("count", 1)))
	_cands.clear()
	if inv and not slot.is_empty():
		for i in Crafting.stacks_for_slot(inv, slot): # locked instances never show (lock protects them)
			if i not in taken:
				_cands.append(i)
	_cands.sort_custom(func(a: int, b: int) -> bool:
		var ka := Inventory.spend_key(inv.slots[a])
		var kb := Inventory.spend_key(inv.slots[b])
		return ka < kb if ka != kb else a < b)
	header.set_title("Choose %s" % LevelDisplay.nice_name(str(slot.get("category", "item"))))
	toolbar.close_menu()
	grid.multi = false
	grid.bind(inv)
	var only := {}
	for i in _cands:
		only[i] = true
	grid.only = only
	grid.multi = need > 1
	grid.set_view(&"acquired", &"all")
	_layout()
	_preselect()

## Every bag slot that can fill this recipe slot, least valuable first.
func candidates() -> Array[int]:
	return _cands.duplicate()

## The least valuable candidate: what opening the picker selects first (-1 when none fits).
func preselected_index() -> int:
	return _cands[0] if not _cands.is_empty() else -1

## Taps the instance at bag slot `index`, as a player would.
func choose(index: int) -> void:
	grid.select_uid(InventoryGrid.key_of(inventory, index))

## The bag slots chosen now, in the order they were picked.
func chosen() -> Array[int]:
	var out: Array[int] = []
	for k in grid.selected_uids():
		var i := _index_of(k)
		if i >= 0:
			out.append(i)
	return out

## True when the chosen instances cover the slot and each of them is needed for it.
func is_complete() -> bool:
	var left := need
	for i in chosen():
		if left <= 0:
			return false
		left -= inventory.slots[i].count
	return left <= 0

## Why the chosen instances deserve a second look before Use: a rare trait (always, even when every
## candidate has one), or a level at or above data picker.warn_level on an instance the player chose
## over the least valuable ones. "" when they are ordinary.
func warning_text() -> String:
	var warn_level := int((InvView.data().get("picker", {}) as Dictionary).get("warn_level", 40))
	for i in chosen():
		var s := inventory.slots[i]
		var rare: Array = InvAttributes.sections(s).rare
		if not rare.is_empty():
			return "Uses up a rare trait: %s." % InvAttributes.line(rare[0])
		if s.level >= warn_level and i not in _least:
			return "Uses up a %s item." % LevelDisplay.label(s.level)
	return ""

## Use: hands the chosen slots back (only when they cover the slot exactly).
func confirm() -> void:
	if is_complete() and _on_pick.is_valid():
		_on_pick.call(chosen())

func _preselect() -> void:
	_syncing = true
	var units := 0
	for i in _cands:
		if units >= need:
			break
		choose(i)
		units += inventory.slots[i].count
	_syncing = false
	_least = chosen()
	_on_selection(grid.selected_uid())

func _on_selection(key: String) -> void:
	if _syncing:
		return
	if grid.multi:
		# Full: a new pick replaces the earliest one, so the choice always fits the slot.
		_syncing = true
		var keys := grid.selected_uids()
		while keys.size() > 1 and _units(keys) - inventory.slots[_index_of(keys[0])].count >= need:
			grid.select_uid(keys[0]) # toggles it off
			keys = grid.selected_uids()
		_syncing = false
	var keys := grid.selected_uids()
	_focus = _index_of(key if key != "" else (keys.back() if not keys.is_empty() else ""))
	_refresh_panel()

func _units(keys: Array[String]) -> int:
	var n := 0
	for k in keys:
		var i := _index_of(k)
		n += inventory.slots[i].count if i >= 0 else 0
	return n

func _index_of(key: String) -> int:
	if key == "":
		return -1
	for c: InventorySlot in grid.item_cells():
		if c.uid == key:
			return c.index
	return -1

func _refresh_panel() -> void:
	if inventory == null:
		return
	var units := _units(grid.selected_uids())
	var notes: Array = []
	var warn := warning_text()
	if warn != "":
		notes.append([warn, UiTokens.DANGER]) # the one way a rare item gets spent: said out loud
	if not is_complete():
		notes.append([("Choose %d more" % (need - units)) if units < need else "Choose fewer", InvTheme.TEXT_2])
	var acts: Array[StringName] = []
	if is_complete():
		acts.append(&"use")
	var summary: Array = [["None in the bag."]] if _cands.is_empty() else [["Fit this slot", "%d" % _cands.size()], ["Tap the ones to use."]]
	inspect.show_stack(inventory.slots[_focus] if _focus >= 0 else null, {"where": &"picker", "actions": acts, "notes": notes, "title": header.title}, summary)
	_count.text = "%d / %d" % [mini(units, need), need]
	if not _m.is_empty():
		var px := int(_m.cap_font)
		_count.add_theme_font_size_override("font_size", px)
		_count.custom_minimum_size = Vector2(InvTheme.font().get_string_size(_count.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 4.0, InvTheme.font().get_height(px)) # the Label's own height, so the header centres it

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
	var top: float = head_h + _m.gap
	var grid_w: float = _m.grid_w + 2.0
	grid.columns = int(_m.columns)
	grid.lv_px = int(_m.lv_font)
	grid.new_px = int(_m.new_font)
	grid.min_rows = 0
	toolbar.position = Vector2(left, bottom - _m.toolbar_h)
	toolbar.size = Vector2(grid_w, _m.toolbar_h)
	toolbar.apply_metrics(_m)
	grid.position = Vector2(left, top)
	grid.size = Vector2(grid_w, toolbar.position.y - 4.0 - top)
	grid.min_rows = ceili(grid.size.y / maxf(1.0, floorf((grid_w - 2.0) / float(_m.columns)))) # the panel keeps its compartments
	grid.refresh()
	var ix: float = left + grid_w + _m.gap
	inspect.position = Vector2(ix, top)
	inspect.size = Vector2(right - ix, bottom - top)
	inspect.apply_metrics(_m)
	_refresh_panel()
