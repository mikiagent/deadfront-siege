class_name InventoryUI
extends Control
## Host of the Durango bag family (spec 13): the Bag, a container and the bag on two tabs (storage,
## loot, dinosaur cargo), Character -> Gear, Equipment / My Info and the craft / cook ingredient picker. It keeps the
## API every caller uses (bind, show_storage, show_pet_bag, hide_ui, rebuild, visible) and the
## transfer rules for containers; the screens are presentation over the inventories it binds.
## Toggling `visible` (I, the HUD's Bag entry) opens the Bag; "<" goes back one screen, X and Esc close.

var inventory: Inventory
var pet_bag: Inventory
var _owner_player: Player
var _selected: int = -1
var _storage_opts: Dictionary = {}
var _screen: StringName = &""
var _tracker := InvNewTracker.new()
var _bag: BagScreen
var _storage: StorageScreen
var _character: CharacterScreen
var _equipment: EquipmentScreen
var _picker: ItemPicker
## Runs once when the picker closes (the craft menu comes back), picked or not.
var _on_close: Callable
## Screens "<" returns to (Character -> Equipment goes back to Character).
var _back: Array[StringName] = []

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = InvTheme.theme()
	visibility_changed.connect(_on_visibility)

# ---------------------------------------------------------------- open / close

## Idempotent: a second bind (raid_gear_probe) does not connect twice.
func bind(inv: Inventory, owner_player: Player = null) -> void:
	inventory = inv
	if owner_player:
		_owner_player = owner_player
	_tracker.bind(inv)
	if _bag:
		_bag.bind(inv, _owner_player)
	for s: GearScreen in [_character, _equipment]:
		if s:
			s.bind(inv, _owner_player)

func open_bag() -> void:
	_screen = &"bag"
	_show(_bag_screen())
	visible = true
	_bag.refresh()

## Character -> Gear on gear cell `slot` (the torso, as the reference opens).
func open_character(slot: StringName = &"body") -> void:
	if _character == null:
		_character = _gear_screen(CharacterScreen.new()) as CharacterScreen
		_character.compare_requested.connect(func(s: StringName, uid: String) -> void:
			_back.append(&"character")
			open_equipment(s, uid))
	_screen = &"character"
	_show(_character)
	visible = true
	_character.refresh()
	_character.select_slot(slot)

## Equipment / My Info on gear cell `slot`, with bag instance `uid` picked to compare.
func open_equipment(slot: StringName = &"body", uid: String = "") -> void:
	if _equipment == null:
		_equipment = _gear_screen(EquipmentScreen.new()) as EquipmentScreen
	_screen = &"equipment"
	_show(_equipment)
	visible = true
	_equipment.refresh()
	_equipment.preselect(slot, uid)

func _gear_screen(s: GearScreen) -> GearScreen:
	add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.bind(inventory, _owner_player)
	s.back_pressed.connect(_go_back)
	s.close_pressed.connect(hide_ui)
	return s

## "<": the screen this one was opened from, else close.
func _go_back() -> void:
	var to: StringName = _back.pop_back() if not _back.is_empty() else &""
	match to:
		&"bag":
			open_bag()
		&"character":
			open_character(_equipment.slot if _equipment else &"body")
		_:
			hide_ui()

## The craft / cook ingredient picker (spec 13 s19) on recipe `rid`'s slot `slot_index`. `on_pick`
## gets the exact bag slots chosen; `taken` are slots the recipe's other slots already use;
## `on_close` runs once when the picker closes, picked or not.
func open_picker(rid: StringName, slot_index: int, on_pick: Callable, taken: Array = [], on_close: Callable = Callable()) -> void:
	if _picker == null:
		_picker = ItemPicker.new()
		add_child(_picker)
		_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_picker.closed.connect(hide_ui)
	_screen = &"picker"
	_show(_picker)
	visible = true
	_on_close = on_close
	_picker.open(inventory, Crafting.recipe(rid), slot_index, func(picked: Array) -> void:
		on_pick.call(picked)
		hide_ui(), taken)

func show_pet_bag(rec: PetRecord) -> void:
	var who := rec.name if rec.name != "" else LevelDisplay.nice_name(str(rec.species))
	_open_container(rec.bag, &"cargo", {"title": "%s Cargo" % who, "take_all": false, "allow_deposit": true})

func show_storage(inv: Inventory, owner_player: Player = null, opts: Dictionary = {}) -> void:
	if owner_player:
		_owner_player = owner_player
	_open_container(inv, &"storage", opts)

func hide_ui() -> void:
	visible = false
	_reset()

## &"bag", &"storage", &"cargo", &"character", &"equipment", &"picker"; &"" when closed.
func current_screen() -> StringName:
	return _screen

## Select the instance with this uid on the screen that shows the bag.
func select_uid(uid: String) -> void:
	if _screen == &"bag" and _bag:
		_bag.select_uid(uid)
	elif _storage and _screen in [&"storage", &"cargo"]:
		_storage.select_key(uid)
	elif _picker and _screen == &"picker":
		_picker.grid.select_uid(uid)

func rebuild() -> void:
	if inventory == null or not is_inside_tree():
		return
	if _screen == &"" and visible:
		open_bag()
	elif _screen == &"bag":
		_bag.refresh()
	elif _storage and _screen in [&"storage", &"cargo"]:
		_storage.bag_grid.refresh()
		_storage.box_grid.refresh()
		_refresh_storage_actions()
	elif _screen == &"character":
		_character.refresh()
	elif _screen == &"equipment":
		_equipment.refresh()
	elif _screen == &"picker":
		_picker.grid.refresh()

## Screen-space blocks of the open screen, for the layout labs (ui_real_capture_lab).
func layout_blocks() -> Dictionary:
	var out := {}
	if _screen == &"bag" and _bag:
		for pair in [["header", _bag.header], ["grid", _bag.grid], ["toolbar", _bag.toolbar], ["inspect", _bag.inspect]]:
			out[pair[0]] = (pair[1] as Control).get_global_rect()
	elif _storage and _screen in [&"storage", &"cargo"]:
		var g: InventoryGrid = _storage.bag_grid if _storage.tab == &"bag" else _storage.box_grid
		for pair in [["header", _storage.header], ["tabs", _storage.bag_tab], ["rail", _storage.rail], ["grid", g], ["toolbar", _storage.toolbar], ["inspect", _storage.inspect]]:
			out[pair[0]] = (pair[1] as Control).get_global_rect()
		out["tabs"] = (out["tabs"] as Rect2).merge(_storage.box_tab.get_global_rect())
	elif _picker and _screen == &"picker":
		for pair in [["header", _picker.header], ["grid", _picker.grid], ["toolbar", _picker.toolbar], ["inspect", _picker.inspect]]:
			out[pair[0]] = (pair[1] as Control).get_global_rect()
	elif _screen in [&"character", &"equipment"]:
		var g: GearScreen = _character if _screen == &"character" else _equipment
		out["header"] = g.header.get_global_rect()
		out["gear"] = Rect2(g.cells[0].global_position, g.cells[0].size * 3.0)
		out["list"] = g.list.get_global_rect()
	return out

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		var bars: Array[BagToolbar] = []
		for sc in [_bag, _picker]:
			if sc:
				bars.append(sc.toolbar)
		if _storage:
			bars.append(_storage.toolbar)
		var open_bars := bars.filter(func(b: BagToolbar) -> bool: return b.menu_open())
		if not open_bars.is_empty():
			for b: BagToolbar in open_bars:
				b.close_menu()
		elif _character and _character.stats_panel and _character.stats_panel.is_visible_in_tree():
			_character.stats_panel.visible = false
		else:
			hide_ui()
		get_viewport().set_input_as_handled()

func _on_visibility() -> void:
	if not visible:
		_reset()
	elif _screen == &"" and inventory != null and is_inside_tree():
		open_bag()

func _reset() -> void:
	_screen = &""
	_back.clear()
	pet_bag = null
	_storage_opts = {}
	_selected = -1
	if _bag:
		_bag.toolbar.close_menu()
		_bag.acknowledge_selection()
	var cb := _on_close # once: hide_ui resets twice (visibility change, then directly)
	_on_close = Callable()
	if cb.is_valid():
		cb.call()

func _show(screen: Control) -> void:
	for c in get_children():
		if c is BagScreen or c is StorageScreen or c is GearScreen or c is ItemPicker:
			(c as Control).visible = c == screen

func _bag_screen() -> BagScreen:
	if _bag == null:
		_bag = BagScreen.new()
		_bag.tracker = _tracker
		add_child(_bag)
		_bag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bag.bind(inventory, _owner_player)
		_bag.back_pressed.connect(hide_ui)  # the Bag is the family's first screen
		_bag.close_pressed.connect(hide_ui)
		_bag.leave_requested.connect(hide_ui)
		_bag.equip_requested.connect(func(i: int) -> void:
			var s := inventory.slots[i] if i >= 0 and i < inventory.slot_count else null
			if s:
				_back.append(&"bag")
				open_equipment(Inventory.slot_for(s.def()), s.uid))
	return _bag

# ---------------------------------------------------------------- containers

func _open_container(inv: Inventory, kind: StringName, opts: Dictionary) -> void:
	pet_bag = inv
	_storage_opts = opts.duplicate(true)
	_screen = kind
	_selected = -1
	if pet_bag and not pet_bag.changed.is_connected(_refresh_storage_actions):
		pet_bag.changed.connect(_refresh_storage_actions)
	if is_inside_tree():
		var s := _storage_screen()
		_show(s)
		s.setup(inventory, pet_bag, str(_storage_opts.get("title", "Storage")), _owner_player, kind)
		_refresh_storage_actions()
	visible = true

func _storage_screen() -> StorageScreen:
	if _storage == null:
		_storage = StorageScreen.new()
		add_child(_storage)
		_storage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_storage.back_pressed.connect(hide_ui)
		_storage.close_pressed.connect(hide_ui)
		_storage.store_pressed.connect(_store_indices)
		_storage.take_pressed.connect(_take_indices)
		_storage.take_all_pressed.connect(_take_all_storage)
		_storage.bag_selected.connect(func(i: int) -> void:
			_selected = i
			_refresh_storage_actions())
		_storage.box_grid.selection_changed.connect(func(_k: String) -> void: _refresh_storage_actions())
	return _storage

func _refresh_storage_actions() -> void:
	if _storage == null or pet_bag == null:
		return
	var box_pick := _storage.box_grid.selected_index()
	_storage.set_actions(_can_store_selected(), box_pick >= 0, bool(_storage_opts.get("take_all", false)) and pet_bag.used_slots() > 0, _readonly_reason(), _store_refusal())

## Legacy entry (earned_training_probe, tests): select bag slot `index` for Store.
func _select(index: int) -> void:
	_selected = index
	if inventory == null or index < 0 or index >= inventory.slot_count:
		return
	var key := InventoryGrid.key_of(inventory, index)
	if _storage and _screen in [&"storage", &"cargo"]:
		_storage.select_key(key)
	elif _bag and _screen == &"bag":
		_bag.select_uid(key)

func _readonly_reason() -> String:
	return str(_storage_opts.get("readonly_reason", ""))

func _take_storage(index: int) -> void:
	if pet_bag == null or inventory == null:
		return
	if _readonly_reason() != "":
		return
	if index < 0 or index >= pet_bag.slot_count:
		return
	var s := pet_bag.slots[index]
	if s == null:
		return
	var taken := pet_bag.remove_at(index, s.count)
	if taken == null:
		return
	var left := inventory.add(taken)
	if left > 0:
		taken.count = left
		pet_bag.add(taken)
		if _owner_player:
			_owner_player.notice("Your bag is full.")
	_notify_storage_take()

func _take_all_storage() -> void:
	if pet_bag == null or inventory == null:
		return
	if _readonly_reason() != "":
		return
	for i in range(pet_bag.slot_count - 1, -1, -1):
		var s := pet_bag.slots[i]
		if s == null:
			continue
		var taken := pet_bag.remove_at(i, s.count)
		if taken == null:
			continue
		var left := inventory.add(taken)
		if left > 0:
			taken.count = left
			pet_bag.add(taken)
	_notify_storage_take()

func _notify_storage_take() -> void:
	var cb: Variant = _storage_opts.get("on_take", null)
	if cb is Callable:
		(cb as Callable).call()
	if pet_bag and pet_bag.used_slots() <= 0:
		var on_empty: Variant = _storage_opts.get("on_empty", null)
		if on_empty is Callable:
			(on_empty as Callable).call()
		# ASSUMPTION: emptied loot closes (nothing left to do); a box the player can put things back
		# into stays open on its tab, the way Transfer works both ways.
		if not bool(_storage_opts.get("allow_deposit", false)):
			hide_ui()

## Why the selected bag item cannot be stored, for the panel ("" when it can, or nothing is picked).
func _store_refusal() -> String:
	if _can_store_selected() or _selected < 0 or inventory == null or _selected >= inventory.slot_count or inventory.slots[_selected] == null:
		return ""
	var st := inventory.slots[_selected]
	if _readonly_reason() != "" or not bool(_storage_opts.get("allow_deposit", false)):
		return "Take only: nothing goes in."
	if st.is_locked():
		return "Locked: unlock it in the Bag to store it."
	if inventory.equipped_tool_index == _selected:
		return "Held tool: let go of it first."
	return "Quick food stays in the bag."

## Loot is take-only unless its owner explicitly exposes writable storage.
func _can_store_selected() -> bool:
	if pet_bag == null or inventory == null or _readonly_reason() != "" or not bool(_storage_opts.get("allow_deposit", false)):
		return false
	if _selected < 0 or _selected >= inventory.slot_count:
		return false
	var st := inventory.slots[_selected]
	if st == null or st.is_locked() or str(st.def_id) == "_slot_lock":
		return false
	if inventory.equipped_tool_index == _selected:
		return false
	if str(st.def_id) in inventory.quick_food: # worn gear is out of the bag (W2-INV)
		return false
	return true

func _store_selected() -> void:
	_store_indices([_selected] as Array[int])

## Transfer to the container: each picked bag slot that may go in, until the container is full.
func _store_indices(indices: Array[int]) -> void:
	var keep := _selected
	for i in indices:
		_selected = i
		if not _can_store_selected():
			continue
		if inventory.transfer_to(pet_bag, i) == 0:
			if _owner_player:
				_owner_player.notice("Storage is full.")
			break
	_selected = keep if keep not in indices else -1
	rebuild()

## Transfer to Bag: each picked container slot, until the bag is full.
func _take_indices(indices: Array[int]) -> void:
	for i in indices:
		if pet_bag == null:
			return # the last item left and the screen closed (on_empty)
		var s := pet_bag.slots[i] if i >= 0 and i < pet_bag.slot_count else null
		if s == null:
			continue
		var uid := s.uid
		_take_storage(i)
		if uid != "" and pet_bag and pet_bag.uids().has(uid):
			break # the bag is full: it went back and the player was told
