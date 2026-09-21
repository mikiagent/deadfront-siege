class_name InventoryUI
extends Control
## Slot grid. Tap a slot for its tooltip (no hover-only). Lock combat tools so they skip gather auto-equip.

var inventory: Inventory
var pet_bag: Inventory
var _grid: GridContainer
var _tip: Label
var _pet_grid: GridContainer
var _storage_title: Label
var _storage_note: Label
var _lock_btn: Button
var _place_btn: Button
var _eat_btn: Button
var _inspect_btn: Button
var _feed_btn: Button
var _take_all_btn: Button
var _owner_player: Player
var _selected: int = -1
var _storage_opts: Dictionary = {}
var _food_inspector: FoodInspector

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40  # above the HUD (same UI layer, added later)
	_layout_safe()
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.1, 0.88)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.position = Vector2(16, 16)
	add_child(_grid)
	_storage_title = Label.new()
	_storage_title.position = Vector2(16, 388)
	_storage_title.size = Vector2(480, 24)
	add_child(_storage_title)
	_pet_grid = GridContainer.new()
	_pet_grid.columns = 5
	_pet_grid.position = Vector2(16, 420)
	add_child(_pet_grid)
	_storage_note = Label.new()
	_storage_note.position = Vector2(520, 420)
	_storage_note.size = Vector2(320, 82)
	_storage_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_storage_note)
	_tip = Label.new()
	_tip.position = Vector2(16, 300)
	_tip.size = Vector2(420, 100)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_tip)
	_lock_btn = Button.new()
	_lock_btn.text = "Lock / Unlock"
	_lock_btn.custom_minimum_size = Vector2(200, 64)
	_lock_btn.position = Vector2(240, 300)
	_lock_btn.pressed.connect(_toggle_lock)
	add_child(_lock_btn)
	_place_btn = Button.new()
	_place_btn.text = "Place"
	_place_btn.custom_minimum_size = Vector2(220, 64)
	_place_btn.position = Vector2(460, 300)
	_place_btn.visible = false
	_place_btn.pressed.connect(_on_place_pressed)
	add_child(_place_btn)
	_inspect_btn = Button.new()
	_inspect_btn.text = "Inspect food"
	_inspect_btn.custom_minimum_size = Vector2(220, 64)
	_inspect_btn.position = Vector2(460, 236)
	_inspect_btn.visible = false
	_inspect_btn.pressed.connect(_on_inspect_food)
	add_child(_inspect_btn)
	_eat_btn = Button.new()
	_eat_btn.text = "Eat"
	_eat_btn.custom_minimum_size = Vector2(220, 64)
	_eat_btn.position = Vector2(700, 236)
	_eat_btn.visible = false
	_eat_btn.pressed.connect(_on_eat_food)
	add_child(_eat_btn)
	_feed_btn = Button.new()
	_feed_btn.text = "Feed pet"
	_feed_btn.custom_minimum_size = Vector2(220, 64)
	_feed_btn.position = Vector2(700, 300)
	_feed_btn.visible = false
	_feed_btn.pressed.connect(_on_feed_pet)
	add_child(_feed_btn)
	_take_all_btn = Button.new()
	_take_all_btn.text = "Take all"
	_take_all_btn.custom_minimum_size = Vector2(220, 64)
	_take_all_btn.position = Vector2(460, 332)
	_take_all_btn.visible = false
	_take_all_btn.pressed.connect(_take_all_storage)
	add_child(_take_all_btn)
	_food_inspector = FoodInspector.new()
	_food_inspector.name = "FoodInspector"
	add_child(_food_inspector)
	_food_inspector.eat_pressed.connect(func (idx: int) -> void:
		visible = false
		if _owner_player:
			_owner_player.begin_eat_slot(idx)
	)
	_food_inspector.feed_pressed.connect(func (idx: int) -> void:
		if _owner_player:
			_owner_player.feed_summoned_pet_slot(idx)
	)
	for i in 20:
		_grid.add_child(_mk_slot(i))
	rebuild()
	resized.connect(_layout_safe)

func bind(inv: Inventory, owner_player: Player = null) -> void:
	inventory = inv
	_owner_player = owner_player
	inventory.changed.connect(rebuild)
	rebuild()

func show_pet_bag(rec: PetRecord) -> void:
	pet_bag = rec.bag
	_storage_opts = {"title": "Pet bag", "take_all": false}
	if pet_bag and not pet_bag.changed.is_connected(rebuild):
		pet_bag.changed.connect(rebuild)
	visible = true
	rebuild()

func show_storage(inv: Inventory, owner_player: Player = null, opts: Dictionary = {}) -> void:
	pet_bag = inv
	_storage_opts = opts.duplicate(true)
	if owner_player:
		_owner_player = owner_player
	if pet_bag and not pet_bag.changed.is_connected(rebuild):
		pet_bag.changed.connect(rebuild)
	visible = true
	rebuild()

func rebuild() -> void:
	if inventory == null:
		return
	for i in mini(_grid.get_child_count(), inventory.slot_count):
		var btn := _grid.get_child(i) as Button
		var s := inventory.slots[i]
		if s == null:
			btn.text = ""
			btn.tooltip_text = ""
		elif str(s.def_id) == "_slot_lock":
			btn.text = "—"
			btn.tooltip_text = "occupied"
		else:
			var pip := ""
			if s.is_locked():
				pip = "L "
			if s.is_unstable():
				pip += "U "
			btn.text = "%s%s\n%d" % [pip, s.def_id, s.count]
			btn.tooltip_text = s.tooltip()
	for c in _pet_grid.get_children():
		c.queue_free()
	if pet_bag:
		for i in pet_bag.slot_count:
			var b := _mk_storage_slot(i)
			var s := pet_bag.slots[i]
			if s == null:
				b.text = ""
				b.tooltip_text = ""
				b.disabled = true
			else:
				b.text = "%s\n%d" % [s.def_id, s.count]
				b.tooltip_text = s.tooltip()
				b.disabled = false
				if _readonly_reason() != "":
					b.modulate = Color(0.7, 0.7, 0.7, 0.8)
				else:
					b.modulate = Color.WHITE
			_pet_grid.add_child(b)
	_storage_title.text = str(_storage_opts.get("title", ""))
	_storage_title.visible = pet_bag != null and _storage_title.text != ""
	_storage_note.visible = pet_bag != null
	_storage_note.text = _readonly_reason()
	_take_all_btn.visible = pet_bag != null and bool(_storage_opts.get("take_all", false))
	_take_all_btn.disabled = _readonly_reason() != "" or pet_bag == null or pet_bag.used_slots() <= 0
	_select(_selected if _selected >= 0 else -1)

func _mk_slot(index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 64)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	if index >= 0:
		b.pressed.connect(func () -> void: _select(index))
	return b

func _mk_storage_slot(index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 64)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(func () -> void: _take_storage(index))
	return b

func _select(index: int) -> void:
	_selected = index
	if inventory == null or index < 0 or index >= inventory.slot_count or inventory.slots[index] == null:
		_tip.text = ""
		_place_btn.visible = false
		_inspect_btn.visible = false
		_eat_btn.visible = false
		_feed_btn.visible = false
		return
	var stack := inventory.slots[index]
	_tip.text = stack.tooltip()
	_refresh_place_button(stack.def())
	var is_food := Food.is_food(stack)
	_inspect_btn.visible = is_food
	_eat_btn.visible = is_food
	_feed_btn.visible = is_food and _owner_player != null and _owner_player.summoned_pet != null

func _on_inspect_food() -> void:
	if inventory == null or _selected < 0:
		return
	var stack := inventory.slots[_selected]
	if stack == null or not Food.is_food(stack):
		return
	print("[food] inspect\n%s" % Food.inspector_text(stack))
	var can_feed := _owner_player != null and _owner_player.summoned_pet != null
	_food_inspector.show_stack(stack, _selected, can_feed)

func _on_eat_food() -> void:
	if _owner_player == null or _selected < 0:
		return
	visible = false
	_owner_player.begin_eat_slot(_selected)

func _on_feed_pet() -> void:
	if _owner_player == null or _selected < 0:
		return
	_owner_player.feed_summoned_pet_slot(_selected)

func _toggle_lock() -> void:
	if inventory == null or _selected < 0 or _selected >= inventory.slot_count:
		return
	var s := inventory.slots[_selected]
	if s == null:
		return
	s.set_flag(&"locked", not s.is_locked())
	inventory.changed.emit()
	_select(_selected)

func _refresh_place_button(def: ItemDef) -> void:
	if _place_btn == null:
		return
	if def == null or def.place_as == &"":
		_place_btn.visible = false
		return
	var w := maxi(1, def.footprint.x)
	var h := maxi(1, def.footprint.y)
	_place_btn.text = "Place %dx%d" % [w, h]
	_place_btn.visible = true

func _on_place_pressed() -> void:
	if inventory == null or _owner_player == null:
		return
	if _selected < 0 or _selected >= inventory.slot_count:
		return
	var stack := inventory.slots[_selected]
	if stack == null:
		return
	var def := stack.def()
	if def == null or def.place_as == &"":
		return
	visible = false
	pet_bag = null
	_owner_player.placer.begin(def.place_as)
	TouchControls.set_context(&"place")

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
		visible = false
		pet_bag = null

func _layout_safe() -> void:
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var view := get_viewport_rect().size
		var win := Vector2(DisplayServer.window_get_size())
		if win.x > 0.0:
			offset_left = maxf(8.0, safe.position.x * view.x / win.x)
			offset_top = maxf(8.0, safe.position.y * view.y / win.y)
