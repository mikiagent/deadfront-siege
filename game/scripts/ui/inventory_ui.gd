class_name InventoryUI
extends Control
## Minecraft-style inventory: a centred grey panel with the armour column on the left, the
## bag grid in the middle, the item tooltip on the right, a quick-food "hotbar" under the bag,
## and a chest/loot grid that appears below when a storage is open. Escape or Close dismisses.

var inventory: Inventory
var pet_bag: Inventory
var _owner_player: Player
var _selected: int = -1
var _storage_opts: Dictionary = {}
var _food_inspector: FoodInspector

var _panel: Panel
var _title: Label
var _grid: GridContainer
var _pet_grid: GridContainer
var _storage_title: Label
var _storage_note: Label
var _tip: Label
var _equip_slots: Dictionary = {}  # slot name -> Button
var _actions: HBoxContainer
var _lock_btn: Button
var _place_btn: Button
var _eat_btn: Button
var _inspect_btn: Button
var _feed_btn: Button
var _take_all_btn: Button
var _equip_btn: Button
var _food1_btn: Button
var _food2_btn: Button
var _close_btn: Button

const PANEL := Vector2(780.0, 600.0)
const SLOT := Vector2(60.0, 56.0)
const EQUIP_LABELS := {"head": "Head", "body": "Body", "legs": "Legs", "accessory1": "Ring", "accessory2": "Ring", "weapon": "Weapon", "tool": "Tool", "food1": "Food 1", "food2": "Food 2"}
const INK := Color(0.22, 0.22, 0.24)

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Game.shot_path.contains("bag"):
		get_tree().create_timer(0.9).timeout.connect(func () -> void: visible = true; rebuild())
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.77, 0.77, 0.77)
	sb.border_color = Color(0.25, 0.25, 0.27)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.size = PANEL
	add_child(_panel)
	_title = _label("Inventory", Vector2(16, 10), 20)
	_close_btn = _btn("Close", Vector2(120, 40))
	_close_btn.position = Vector2(PANEL.x - 136, 8)
	_close_btn.pressed.connect(hide_ui)
	_panel.add_child(_close_btn)
	# Armour column (head, body, legs, rings) and the hands (weapon, tool) beside it.
	var y := 62.0
	for slot in ["head", "body", "legs", "accessory1", "accessory2"]:
		_equip_slot(slot, Vector2(16, y))
		y += SLOT.y + 18.0
	_equip_slot("weapon", Vector2(16 + SLOT.x + 10, 62))
	_equip_slot("tool", Vector2(16 + SLOT.x + 10, 62 + SLOT.y + 18.0))
	_label("Survivor", Vector2(16 + SLOT.x + 10, 62 + (SLOT.y + 18.0) * 2 + 4), 13)
	# Bag grid
	_label("Bag", Vector2(176, 30), 13)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.position = Vector2(176, 48)
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_panel.add_child(_grid)
	for i in 20:
		_grid.add_child(_mk_slot(i))
	# Quick-food hotbar
	_label("Quick food: the two hexes bottom-left; auto-eaten under 50 % hunger", Vector2(310, 322), 11)
	_equip_slot("food1", Vector2(176, 322))
	_equip_slot("food2", Vector2(176 + SLOT.x + 4, 322))
	# Tooltip
	_tip = _label("", Vector2(500, 48), 13)
	_tip.size = Vector2(264, 250)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Storage / loot
	_storage_title = _label("", Vector2(176, 380), 14)
	_storage_title.size = Vector2(300, 22)
	_pet_grid = GridContainer.new()
	_pet_grid.columns = 6
	_pet_grid.position = Vector2(176, 402)
	_pet_grid.add_theme_constant_override("h_separation", 4)
	_pet_grid.add_theme_constant_override("v_separation", 4)
	_panel.add_child(_pet_grid)
	_storage_note = _label("", Vector2(560, 402), 13)
	_storage_note.size = Vector2(204, 60)
	_storage_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_storage_note.add_theme_color_override("font_color", Color(0.6, 0.15, 0.1))
	# Actions row
	_actions = HBoxContainer.new()
	_actions.position = Vector2(16, PANEL.y - 56)
	_actions.add_theme_constant_override("separation", 6)
	_panel.add_child(_actions)
	_lock_btn = _action("Lock", _toggle_lock)
	_equip_btn = _action("Equip", _on_equip_pressed)
	_food1_btn = _action("Quick 1", func () -> void: _set_quick(0))
	_food2_btn = _action("Quick 2", func () -> void: _set_quick(1))
	_inspect_btn = _action("Inspect", _on_inspect_food)
	_eat_btn = _action("Eat", _on_eat_food)
	_feed_btn = _action("Feed pet", _on_feed_pet)
	_place_btn = _action("Place", _on_place_pressed)
	_take_all_btn = _action("Take all", _take_all_storage)
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
	resized.connect(_layout_safe)
	_layout_safe()
	rebuild()

func _label(text: String, pos: Vector2, size_px: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", INK)
	_panel.add_child(l)
	return l

func _btn(text: String, minsz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsz
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b

func _action(text: String, cb: Callable) -> Button:
	var b := _btn(text, Vector2(0, 44))
	b.pressed.connect(cb)
	b.visible = false
	_actions.add_child(b)
	return b

func _slot_style(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.55, 0.55)
	sb.border_color = Color(0.36, 0.36, 0.38)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.68, 0.68, 0.7)
	b.add_theme_stylebox_override("hover", hov)
	var prs := sb.duplicate() as StyleBoxFlat
	prs.bg_color = Color(0.45, 0.45, 0.47)
	b.add_theme_stylebox_override("pressed", prs)
	b.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14))
	b.add_theme_font_size_override("font_size", 12)

func _equip_slot(slot: String, pos: Vector2) -> void:
	var b := _btn("", SLOT)
	b.position = pos
	_slot_style(b)
	var sname: String = slot
	b.pressed.connect(func () -> void: _on_equip_slot_pressed(sname))
	_panel.add_child(b)
	_equip_slots[slot] = b
	var cap := Label.new()
	cap.text = str(EQUIP_LABELS.get(slot, slot))
	cap.position = pos + Vector2(2, -15)
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", Color(0.35, 0.35, 0.37))
	_panel.add_child(cap)

func _mk_slot(index: int) -> Button:
	var b := _btn("", SLOT)
	_slot_style(b)
	if index >= 0:
		b.pressed.connect(func () -> void: _select(index))
	return b

func _mk_storage_slot(index: int) -> Button:
	var b := _btn("", SLOT)
	_slot_style(b)
	b.pressed.connect(func () -> void: _take_storage(index))
	return b

# ---------------------------------------------------------------- open / close

func bind(inv: Inventory, owner_player: Player = null) -> void:
	inventory = inv
	_owner_player = owner_player
	inventory.changed.connect(rebuild)
	rebuild()

func hide_ui() -> void:
	visible = false
	pet_bag = null
	_storage_opts = {}

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_ui()
		get_viewport().set_input_as_handled()

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

func _layout_safe() -> void:
	if _panel == null:
		return
	var r := get_viewport_rect().size
	var scale := minf(1.0, minf((r.x - 16.0) / PANEL.x, (r.y - 16.0) / PANEL.y))
	_panel.scale = Vector2(scale, scale)
	_panel.position = (r - PANEL * scale) * 0.5

# ---------------------------------------------------------------- rebuild

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
	var has_storage := pet_bag != null
	if has_storage:
		for i in pet_bag.slot_count:
			var b := _mk_storage_slot(i)
			var s := pet_bag.slots[i]
			if s == null:
				b.text = ""
				b.disabled = true
			else:
				ItemIcons.style_slot(b, s.def_id, str(s.count))
				b.tooltip_text = s.tooltip()
				b.disabled = false
				b.modulate = Color(0.7, 0.7, 0.7, 0.8) if _readonly_reason() != "" else Color.WHITE
			_pet_grid.add_child(b)
	_storage_title.text = str(_storage_opts.get("title", "")) if has_storage else ""
	_storage_title.visible = has_storage and _storage_title.text != ""
	_storage_note.visible = has_storage
	_storage_note.text = _readonly_reason()
	_take_all_btn.visible = has_storage and bool(_storage_opts.get("take_all", false))
	_take_all_btn.disabled = _readonly_reason() != "" or pet_bag == null or pet_bag.used_slots() <= 0
	_title.text = "Inventory" if not has_storage else "Inventory  ·  %s" % str(_storage_opts.get("title", "Storage"))
	_select(_selected if _selected >= 0 else -1)

func _refresh_equipped() -> void:
	for slot in _equip_slots.keys():
		var b: Button = _equip_slots[slot]
		var st: ItemStack = null
		var caption := ""
		match slot:
			"weapon":
				st = inventory.equipped_weapon()
				if st and st.def():
					caption = "%.0f" % st.def().damage
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
			b.text = ""
			b.tooltip_text = "empty"
			b.modulate = Color.WHITE

# ---------------------------------------------------------------- selection + actions

func _select(index: int) -> void:
	_selected = index
	var none := inventory == null or index < 0 or index >= inventory.slot_count or inventory.slots[index] == null
	for b in [_lock_btn, _equip_btn, _food1_btn, _food2_btn, _inspect_btn, _eat_btn, _feed_btn, _place_btn]:
		b.visible = false
	if none:
		_tip.text = "Tap an item."
		return
	var stack := inventory.slots[index]
	_tip.text = stack.tooltip()
	_lock_btn.visible = true
	_lock_btn.text = "Unlock" if stack.is_locked() else "Lock"
	var d := stack.def()
	var is_food := Food.is_food(stack)
	_inspect_btn.visible = is_food
	_eat_btn.visible = is_food
	_food1_btn.visible = is_food
	_food2_btn.visible = is_food
	_feed_btn.visible = is_food and _owner_player != null and _owner_player.summoned_pet != null
	var slot := Inventory.slot_for(d)
	var equippable := slot != &"" or (d != null and d.tool_class != &"" and d.tool_class != &"none")
	_equip_btn.visible = equippable
	if equippable:
		_equip_btn.text = "Equip %s" % (str(slot) if slot != &"" else "tool")
	_place_btn.visible = d != null and d.place_as != &""
	if _place_btn.visible:
		_place_btn.text = "Place %dx%d" % [maxi(1, d.footprint.x), maxi(1, d.footprint.y)]

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
				hide_ui()
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
	hide_ui()
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
	hide_ui()
	_owner_player.placer.begin(def.place_as)
	TouchControls.set_context(&"place")

# ---------------------------------------------------------------- storage

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
		hide_ui()
