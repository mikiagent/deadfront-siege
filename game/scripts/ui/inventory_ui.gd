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
var _equip_box: VBoxContainer
var _equip_slots: Dictionary = {}  # slot name -> Button
var _equip_btn: Button
var _food1_btn: Button
var _food2_btn: Button
var _bag_title: Label
const EQUIP_LABELS := {"weapon": "Weapon", "tool": "Tool", "head": "Head", "body": "Body", "legs": "Legs", "accessory1": "Accessory", "accessory2": "Accessory", "food1": "Quick food 1", "food2": "Quick food 2"}

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40  # above the HUD (same UI layer, added later)
	if Game.shot_path.contains("bag"):
		get_tree().create_timer(0.9).timeout.connect(func () -> void: visible = true; rebuild())
	_layout_safe()
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.1, 0.88)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	# Left column: what the survivor has on. Right: the bag.
	_equip_box = VBoxContainer.new()
	_equip_box.position = Vector2(16, 16)
	_equip_box.add_theme_constant_override("separation", 4)
	add_child(_equip_box)
	var eq_title := Label.new()
	eq_title.text = "Equipped"
	eq_title.add_theme_font_size_override("font_size", 18)
	_equip_box.add_child(eq_title)
	for slot in ["weapon", "tool", "head", "body", "legs", "accessory1", "accessory2", "food1", "food2"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l := Label.new()
		l.text = str(EQUIP_LABELS[slot])
		l.custom_minimum_size = Vector2(96, 0)
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 52)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		var sname: String = str(slot)
		b.pressed.connect(func () -> void: _on_equip_slot_pressed(sname))
		row.add_child(b)
		_equip_slots[slot] = b
		_equip_box.add_child(row)
	_bag_title = Label.new()
	_bag_title.text = "Bag"
	_bag_title.position = Vector2(210, 16)
	_bag_title.add_theme_font_size_override("font_size", 18)
	add_child(_bag_title)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.position = Vector2(210, 44)
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
	_tip.position = Vector2(210, 316)
	_tip.size = Vector2(300, 100)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_tip)
	_lock_btn = Button.new()
	_lock_btn.text = "Lock / Unlock"
	_lock_btn.custom_minimum_size = Vector2(200, 64)
	_lock_btn.position = Vector2(520, 300)
	_lock_btn.pressed.connect(_toggle_lock)
	add_child(_lock_btn)
	_place_btn = Button.new()
	_place_btn.text = "Place"
	_place_btn.custom_minimum_size = Vector2(220, 64)
	_place_btn.position = Vector2(740, 300)
	_place_btn.visible = false
	_place_btn.pressed.connect(_on_place_pressed)
	add_child(_place_btn)
	_inspect_btn = Button.new()
	_inspect_btn.text = "Inspect food"
	_inspect_btn.custom_minimum_size = Vector2(220, 64)
	_inspect_btn.position = Vector2(520, 236)
	_inspect_btn.visible = false
	_inspect_btn.pressed.connect(_on_inspect_food)
	add_child(_inspect_btn)
	_eat_btn = Button.new()
	_eat_btn.text = "Eat"
	_eat_btn.custom_minimum_size = Vector2(220, 64)
	_eat_btn.position = Vector2(740, 236)
	_eat_btn.visible = false
	_eat_btn.pressed.connect(_on_eat_food)
	add_child(_eat_btn)
	_feed_btn = Button.new()
	_feed_btn.text = "Feed pet"
	_feed_btn.custom_minimum_size = Vector2(220, 64)
	_feed_btn.position = Vector2(740, 364)
	_feed_btn.visible = false
	_feed_btn.pressed.connect(_on_feed_pet)
	add_child(_feed_btn)
	_take_all_btn = Button.new()
	_take_all_btn.text = "Take all"
	_take_all_btn.custom_minimum_size = Vector2(220, 64)
	_take_all_btn.position = Vector2(520, 364)
	_equip_btn = Button.new()
	_equip_btn.text = "Equip"
	_equip_btn.custom_minimum_size = Vector2(220, 64)
	_equip_btn.position = Vector2(520, 172)
	_equip_btn.visible = false
	_equip_btn.pressed.connect(_on_equip_pressed)
	add_child(_equip_btn)
	_food1_btn = Button.new()
	_food1_btn.text = "Quick food 1"
	_food1_btn.custom_minimum_size = Vector2(220, 64)
	_food1_btn.position = Vector2(740, 172)
	_food1_btn.visible = false
	_food1_btn.pressed.connect(func () -> void: _set_quick(0))
	add_child(_food1_btn)
	_food2_btn = Button.new()
	_food2_btn.text = "Quick food 2"
	_food2_btn.custom_minimum_size = Vector2(220, 64)
	_food2_btn.position = Vector2(960, 172)
	_food2_btn.visible = false
	_food2_btn.pressed.connect(func () -> void: _set_quick(1))
	add_child(_food2_btn)
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

func _refresh_equipped() -> void:
	if inventory == null:
		return
	for slot in _equip_slots.keys():
		var b: Button = _equip_slots[slot]
		var st: ItemStack = null
		var caption := ""
		match slot:
			"weapon":
				st = inventory.equipped_weapon()
				if st:
					caption = "%.0f dmg" % st.def().damage if st.def() else ""
			"tool":
				st = inventory.equipped_gather_tool()
			"food1", "food2":
				var fid := str(inventory.quick_food[0 if slot == "food1" else 1])
				if fid != "":
					var n := inventory.count_of(StringName(fid))
					ItemIcons.style_slot(b, StringName(fid), "×%d" % n)
					b.modulate = Color.WHITE if n > 0 else Color(0.6, 0.6, 0.6)
					b.tooltip_text = fid
					continue
			_:
				st = inventory.equipped_in(StringName(slot))
		if st:
			ItemIcons.style_slot(b, st.def_id, caption)
			b.tooltip_text = st.tooltip()
			b.modulate = Color.WHITE
		else:
			b.icon = null
			b.text = "—"
			b.tooltip_text = "empty"
			b.modulate = Color(0.75, 0.75, 0.75)

## Tap an equipped slot: weapon/armour unequips, tool cycles, quick food eats one now.
func _on_equip_slot_pressed(slot: String) -> void:
	if inventory == null:
		return
	match slot:
		"tool":
			var tools := inventory.gather_tools_in_bag()
			if tools.is_empty():
				return
			var pos := -1
			for i in tools.size():
				if int(tools[i]["index"]) == inventory.equipped_tool_index:
					pos = i
			inventory.set_equipped_tool_index(int(tools[(pos + 1) % tools.size()]["index"]))
		"food1", "food2":
			var fid := str(inventory.quick_food[0 if slot == "food1" else 1])
			var idx := inventory.find_first(StringName(fid)) if fid != "" else -1
			if idx >= 0 and _owner_player:
				visible = false
				_owner_player.begin_eat_slot(idx)
			elif fid != "":
				inventory.set_quick_food(0 if slot == "food1" else 1, &"")
		_:
			if inventory.equipment.has(slot):
				inventory.unequip(StringName(slot))

func _on_equip_pressed() -> void:
	if inventory == null or _selected < 0 or _selected >= inventory.slot_count:
		return
	var st := inventory.slots[_selected]
	if st == null:
		return
	var d := st.def()
	var slot := Inventory.slot_for(d)
	if slot != &"":
		inventory.equip(slot, st.def_id)
	elif d and d.tool_class != &"" and d.tool_class != &"none":
		inventory.set_equipped_tool_index(_selected)
	_select(_selected)

func _set_quick(i: int) -> void:
	if inventory == null or _selected < 0 or _selected >= inventory.slot_count:
		return
	var st := inventory.slots[_selected]
	if st == null or not Food.is_food(st):
		return
	inventory.set_quick_food(i, st.def_id)

func rebuild() -> void:
	if inventory == null:
		return
	_refresh_equipped()
	for i in mini(_grid.get_child_count(), inventory.slot_count):
		var btn := _grid.get_child(i) as Button
		var s := inventory.slots[i]
		if s == null:
			btn.text = ""
			btn.icon = null
			btn.tooltip_text = ""
		elif str(s.def_id) == "_slot_lock":
			btn.text = "—"
			btn.icon = null
			btn.tooltip_text = "occupied"
		else:
			var pip := ""
			if s.is_locked():
				pip = "L "
			if s.is_unstable():
				pip += "U "
			ItemIcons.style_slot(btn, s.def_id, "%s%d" % [pip, s.count])
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
				ItemIcons.style_slot(b, s.def_id, str(s.count))
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
		_equip_btn.visible = false
		_food1_btn.visible = false
		_food2_btn.visible = false
		return
	var stack := inventory.slots[index]
	_tip.text = stack.tooltip()
	_refresh_place_button(stack.def())
	var is_food := Food.is_food(stack)
	_inspect_btn.visible = is_food
	_eat_btn.visible = is_food
	_feed_btn.visible = is_food and _owner_player != null and _owner_player.summoned_pet != null
	_food1_btn.visible = is_food
	_food2_btn.visible = is_food
	var d := stack.def()
	var equippable := Inventory.slot_for(d) != &"" or (d != null and d.tool_class != &"" and d.tool_class != &"none")
	_equip_btn.visible = equippable
	if equippable:
		var slot := Inventory.slot_for(d)
		_equip_btn.text = "Equip (%s)" % (str(slot) if slot != &"" else "tool")

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
