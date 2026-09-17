class_name InventoryUI
extends Control
## Ugly-but-correct slot grid. Tooltip shows attributes, level, process, flags.

var inventory: Inventory
var pet_bag: Inventory
var _grid: GridContainer
var _tip: Label
var _pet_grid: GridContainer

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	_pet_grid.position = Vector2(16, 280)
	add_child(_pet_grid)
	_tip = Label.new()
	_tip.position = Vector2(16, 220)
	_tip.size = Vector2(420, 80)
	add_child(_tip)
	for i in 20:
		_grid.add_child(_mk_slot())
	rebuild()

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
			btn.text = "%s\n%d" % [s.def_id, s.count]
			btn.tooltip_text = s.tooltip()
	for c in _pet_grid.get_children():
		c.queue_free()
	if pet_bag:
		for i in pet_bag.slot_count:
			var b := _mk_slot()
			var s := pet_bag.slots[i]
			b.text = "" if s == null else "%s\n%d" % [s.def_id, s.count]
			_pet_grid.add_child(b)

func _mk_slot() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(72, 48)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_entered.connect(func () -> void: _tip.text = b.tooltip_text)
	return b
