class_name InventoryUI
extends Control
## Slot grid. Tap a slot for its tooltip (no hover-only). Lock combat tools so they skip gather auto-equip.

var inventory: Inventory
var pet_bag: Inventory
var _grid: GridContainer
var _tip: Label
var _pet_grid: GridContainer
var _lock_btn: Button
var _selected: int = -1

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout_safe()
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.1, 0.88)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.position = Vector2(16, 16)
	add_child(_grid)
	_pet_grid = GridContainer.new()
	_pet_grid.columns = 5
	_pet_grid.position = Vector2(16, 420)
	add_child(_pet_grid)
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
	for i in 20:
		_grid.add_child(_mk_slot(i))
	rebuild()
	resized.connect(_layout_safe)

func bind(inv: Inventory) -> void:
	inventory = inv
	inventory.changed.connect(rebuild)
	rebuild()

func show_pet_bag(rec: PetRecord) -> void:
	pet_bag = rec.bag
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
			var b := _mk_slot(-1)
			var s := pet_bag.slots[i]
			b.text = "" if s == null else "%s\n%d" % [s.def_id, s.count]
			_pet_grid.add_child(b)

func _mk_slot(index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 64)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	if index >= 0:
		b.pressed.connect(func () -> void: _select(index))
	return b

func _select(index: int) -> void:
	_selected = index
	if inventory == null or index < 0 or index >= inventory.slot_count or inventory.slots[index] == null:
		_tip.text = ""
		return
	_tip.text = inventory.slots[index].tooltip()

func _toggle_lock() -> void:
	if inventory == null or _selected < 0 or _selected >= inventory.slot_count:
		return
	var s := inventory.slots[_selected]
	if s == null:
		return
	s.set_flag(&"locked", not s.is_locked())
	inventory.changed.emit()
	_select(_selected)

func _layout_safe() -> void:
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var view := get_viewport_rect().size
		var win := Vector2(DisplayServer.window_get_size())
		if win.x > 0.0:
			offset_left = maxf(8.0, safe.position.x * view.x / win.x)
			offset_top = maxf(8.0, safe.position.y * view.y / win.y)
