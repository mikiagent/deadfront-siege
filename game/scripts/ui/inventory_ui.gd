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
var _profile: Label
var _tab_title: Label
var _equip_slots: Dictionary = {}  # slot name -> Button
var _actions: HBoxContainer
var _lock_btn: Button
var _place_btn: Button
var _eat_btn: Button
var _inspect_btn: Button
var _feed_btn: Button
var _store_btn: Button
var _take_all_btn: Button
var _equip_btn: Button
var _food1_btn: Button
var _food2_btn: Button
var _close_btn: Button
var _profile_col: VBoxContainer
var _bag_col: VBoxContainer
var _equip_col: VBoxContainer
var _bag_label: Label
var _equip_label: Label
var _equip_grid: GridContainer
var _equip_pad: Control
var _stat_box: VBoxContainer
var _stat_rows: Array[Label] = []
var _slot_px: float = 64.0
const EQUIP_LABELS := {"head": "Head", "body": "Body", "arms": "Arms", "legs": "Legs", "accessory1": "Ring", "accessory2": "Ring", "weapon": "Weapon", "tool": "Tool", "food1": "Food 1", "food2": "Food 2"}
const INK := Color(0.95, 0.95, 0.93)

var _split: GridContainer
## Visual grouping (W2-INV, prompt 05): the bag grid shows one cell per item id with a count badge;
## a group of several opens into its instances, one cell each, behind a back cell. Instances never
## merge. Each entry: {"slot": i} | {"group": id, "slots": [i...], "units": n} | {"back": true}.
var _cells: Array = []
var _open_group: StringName = &""

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Game.shot_path.contains("bag"):
		get_tree().create_timer(0.9).timeout.connect(func () -> void: visible = true; rebuild())
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_theme_stylebox_override("panel", UiTokens.panel_style())
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UiTokens.SPACE)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UiTokens.SPACE)
	root.add_child(header)
	_title = Label.new()
	_title.text = "CHARACTER"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", INK)
	header.add_child(_title)
	_close_btn = _btn("✕", Vector2(44, 44))
	_close_btn.pressed.connect(hide_ui)
	header.add_child(_close_btn)
	var load := HBoxContainer.new()
	load.add_theme_constant_override("separation", UiTokens.SPACE)
	root.add_child(load)
	_tab_title = Label.new()
	_tab_title.text = "GEAR  1"
	_tab_title.add_theme_color_override("font_color", INK)
	load.add_child(_tab_title)
	for i in 3:
		var loadout := _btn(str(i + 1), Vector2(44, 36))
		loadout.disabled = i > 0
		loadout.tooltip_text = "Active loadout" if i == 0 else "Loadout slot"
		load.add_child(loadout)
	_split = GridContainer.new()
	_split.columns = 3
	_split.add_theme_constant_override("h_separation", UiTokens.SPACE * 2)
	_split.add_theme_constant_override("v_separation", UiTokens.SPACE * 2)
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_split)
	var col_p := VBoxContainer.new()
	col_p.add_theme_constant_override("separation", UiTokens.SPACE)
	col_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_profile_col = col_p
	_split.add_child(col_p)
	_profile = Label.new()
	_profile.add_theme_color_override("font_color", INK)
	_profile.autowrap_mode = TextServer.AUTOWRAP_OFF
	_profile.clip_text = true
	_profile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_profile.custom_minimum_size = Vector2(180, 0)
	_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_p.add_child(_profile)
	_stat_box = VBoxContainer.new()
	_stat_box.add_theme_constant_override("separation", UiTokens.SPACE)
	_stat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_p.add_child(_stat_box)
	for _i in 4:
		var stat := Label.new()
		stat.add_theme_color_override("font_color", INK)
		stat.clip_text = true
		stat.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stat_box.add_child(stat)
		_stat_rows.append(stat)
	var col_b := VBoxContainer.new()
	col_b.add_theme_constant_override("separation", UiTokens.SPACE)
	col_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_col = col_b
	_split.add_child(col_b)
	_bag_label = Label.new()
	_bag_label.text = "BAG"
	_bag_label.add_theme_color_override("font_color", UiTokens.META)
	col_b.add_child(_bag_label)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", UiTokens.SPACE)
	_grid.add_theme_constant_override("v_separation", UiTokens.SPACE)
	col_b.add_child(_grid)
	for i in 20:
		_grid.add_child(_mk_slot(i))
	var col_e := VBoxContainer.new()
	col_e.add_theme_constant_override("separation", UiTokens.SPACE)
	col_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_e.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equip_col = col_e
	_split.add_child(col_e)
	_equip_label = Label.new()
	_equip_label.text = "EQUIPMENT"
	_equip_label.add_theme_color_override("font_color", UiTokens.META)
	col_e.add_child(_equip_label)
	_equip_pad = Control.new()
	_equip_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_e.add_child(_equip_pad)
	_equip_grid = GridContainer.new()
	_equip_grid.columns = 3
	_equip_grid.add_theme_constant_override("h_separation", UiTokens.SPACE)
	_equip_grid.add_theme_constant_override("v_separation", UiTokens.SPACE)
	col_e.add_child(_equip_grid)
	var equip_order := ["head", "body", "arms", "legs", "weapon", "tool", "accessory1", "accessory2", "food1", "food2"]
	for slot_name in equip_order:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var cap := Label.new()
		cap.text = str(EQUIP_LABELS.get(slot_name, slot_name))
		cap.add_theme_color_override("font_color", UiTokens.META)
		cap.clip_text = true
		cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cap.custom_minimum_size = Vector2(_slot_px, 0)
		cell.add_child(cap)
		var b := _btn("", _slot_vec())
		_slot_style(b)
		b.pressed.connect(_on_equip_slot_pressed.bind(slot_name))
		cell.add_child(b)
		_equip_grid.add_child(cell)
		_equip_slots[slot_name] = b
	_tip = Label.new()
	_tip.text = "Tap an item."
	_tip.add_theme_color_override("font_color", INK)
	# Not clipped: with one instance per slot its lines (level, process, attributes) are what tell
	# two stones apart; one clipped line showed only "Stone x1..." (W2-INV bag shots).
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(180, 24)
	_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_e.add_child(_tip)
	_storage_title = Label.new()
	_storage_title.add_theme_color_override("font_color", INK)
	root.add_child(_storage_title)
	_pet_grid = GridContainer.new()
	_pet_grid.columns = 5
	_pet_grid.add_theme_constant_override("h_separation", UiTokens.SPACE)
	_pet_grid.add_theme_constant_override("v_separation", UiTokens.SPACE)
	root.add_child(_pet_grid)
	_storage_note = Label.new()
	_storage_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_storage_note.add_theme_color_override("font_color", UiTokens.DANGER)
	root.add_child(_storage_note)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", UiTokens.SPACE)
	root.add_child(_actions)
	_lock_btn = _action("Lock", _toggle_lock)
	_equip_btn = _action("EQUIP", _on_equip_pressed)
	_food1_btn = _action("Food 1", func () -> void: _set_quick(0))
	_food2_btn = _action("Food 2", func () -> void: _set_quick(1))
	_inspect_btn = _action("Inspect", _on_inspect_food)
	_eat_btn = _action("Eat", _on_eat_food)
	_feed_btn = _action("Feed", _on_feed_pet)
	_place_btn = _action("Place", _on_place_pressed)
	_store_btn = _action("Store", _store_selected)
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

func _slot_style(b: Button, selected: bool = false) -> void:
	var sb := UiTokens.slot_style(selected)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.16, 0.18, 0.2, 1.0)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", UiTokens.slot_style(true))
	b.add_theme_stylebox_override("disabled", sb) # an empty slot stays a visible compartment
	b.add_theme_color_override("font_color", UiTokens.TEXT)
	_fit_slot(b)

## Icon and caption grow with the slot: desktop slots are twice the phone's 64 px, where a 36 px
## icon and 12 px caption read as specks (W2-INV bag shots).
func _fit_slot(b: Button) -> void:
	b.add_theme_font_size_override("font_size", clampi(int(_slot_px / 8.0), 12, UiTokens.body(get_viewport_rect().size)))
	b.add_theme_constant_override("icon_max_width", maxi(36, int(_slot_px * 0.45)))

func _slot_vec() -> Vector2:
	return Vector2(_slot_px, _slot_px)

func _equip_slot(slot: String, pos: Vector2) -> void:
	var b := _btn("", _slot_vec())
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
	var b := _btn("", _slot_vec())
	_slot_style(b)
	if index >= 0:
		b.pressed.connect(func () -> void: _on_cell(index))
	return b

func _mk_storage_slot(index: int) -> Button:
	var b := _btn("", _slot_vec())
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
	_open_group = &""
	pet_bag = null
	_storage_opts = {}

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_ui()
		get_viewport().set_input_as_handled()

func show_pet_bag(rec: PetRecord) -> void:
	pet_bag = rec.bag
	_storage_opts = {"title": "Pet bag", "take_all": false, "allow_deposit": true}
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
	var safe := UiTokens.safe_insets(get_viewport())
	_panel.offset_left = 12.0 + safe.w
	_panel.offset_top = 12.0 + safe.z
	_panel.offset_right = -(12.0 + safe.x)
	_panel.offset_bottom = -(12.0 + safe.y)
	_panel.scale = Vector2.ONE
	if _split:
		_split.columns = 1 if UiTokens.is_phone(r) else 3
	var head := UiTokens.heading(r)
	var body := UiTokens.body(r)
	if _title:
		_title.add_theme_font_size_override("font_size", head)
	if _tab_title:
		_tab_title.add_theme_font_size_override("font_size", body)
	if _profile:
		_profile.add_theme_font_size_override("font_size", body)
	if _tip:
		_tip.add_theme_font_size_override("font_size", UiTokens.meta(r))
		_tip.custom_minimum_size = Vector2(180, UiTokens.meta(r) + UiTokens.SPACE * 2)
	if _storage_title:
		_storage_title.add_theme_font_size_override("font_size", body)
	if _storage_note:
		_storage_note.add_theme_font_size_override("font_size", UiTokens.meta(r))
	if _profile:
		_profile.add_theme_constant_override("line_spacing", UiTokens.SPACE)
	if _bag_label:
		_bag_label.add_theme_font_size_override("font_size", UiTokens.meta(r))
	if _equip_label:
		_equip_label.add_theme_font_size_override("font_size", UiTokens.meta(r))
	for stat in _stat_rows:
		stat.add_theme_font_size_override("font_size", body)
	_apply_slot_metrics(r, safe)
	if inventory != null:
		_refresh_profile()

# ---------------------------------------------------------------- rebuild

func rebuild() -> void:
	if inventory == null:
		return
	_refresh_profile()
	_refresh_equipped()
	_cells = _bag_cells()
	while _grid.get_child_count() < _cells.size():
		_grid.add_child(_mk_slot(_grid.get_child_count()))
	for k in _grid.get_child_count():
		var btn := _grid.get_child(k) as Button
		btn.visible = k < _cells.size()
		if btn.visible:
			_style_cell(btn, _cells[k])
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
				_fit_slot(b)
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
	_title.text = "CHARACTER" if not has_storage else "CHARACTER  ·  %s" % str(_storage_opts.get("title", "Storage"))
	_select(_selected if _selected >= 0 else -1)

func _bag_cells() -> Array:
	var groups := inventory.groups()
	for g in groups:
		if g.def_id == _open_group and (g.slots as Array).size() > 1:
			var open: Array = [{"back": true}]
			for i: int in g.slots:
				open.append({"slot": i})
			return open
	_open_group = &"" # the open group emptied or is down to one
	var out: Array = []
	for g in groups:
		var at: Array = g.slots
		out.append({"slot": at[0]} if at.size() == 1 else {"group": g.def_id, "slots": at, "units": g.units})
	# Spec 13:124 "Empty slots remain visible": one empty cell per free bag slot.
	for k in inventory.slot_count - inventory.used_slots():
		out.append({"empty": true})
	return out

## "L " / "U " when any instance in `at` is locked / unstable (a group hides them otherwise).
func _pips(at: Array) -> String:
	var locked := false
	var unstable := false
	for i in at:
		var s := inventory.slots[int(i)]
		locked = locked or s.is_locked()
		unstable = unstable or s.is_unstable()
	return ("L " if locked else "") + ("U " if unstable else "")

func _style_cell(btn: Button, cell: Dictionary) -> void:
	btn.modulate = Color.WHITE
	btn.disabled = cell.has("empty")
	_badge(btn, int(cell.get("units", 0)))
	if cell.has("empty"):
		btn.icon = null
		btn.text = ""
		btn.tooltip_text = ""
		return
	if cell.has("back"):
		btn.icon = UiIcons.icon(&"back") # white = action
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.text = "All"
		btn.tooltip_text = "Back to the whole bag"
		return
	if cell.has("group"):
		var first := inventory.slots[int(cell.slots[0])]
		# A corner count badge (as in ARK and Durango) marks a group that opens into its instances; the
		# caption is their level range. A real stack (ammo, coins) reads "×45" and has no badge.
		ItemIcons.style_slot(btn, first.def_id, _pips(cell.slots) + _level_range(cell.slots))
		btn.tooltip_text = "%d × %s: tap to see each one" % [(cell.slots as Array).size(), first.def().display_name if first.def() else str(first.def_id)]
		return
	var s := inventory.slots[int(cell.slot)]
	# A unique instance shows its level; a stack (ammo, coins) its count.
	ItemIcons.style_slot(btn, s.def_id, _pips([cell.slot]) + ("×%d" % s.count if s.count > 1 else "Lv %d" % s.level))
	btn.tooltip_text = s.tooltip()

## "Lv 1-14" over a group's instances ("Lv 5" when they share one level).
func _level_range(at: Array) -> String:
	var lo := 1 << 30
	var hi := 0
	for i in at:
		lo = mini(lo, inventory.slots[int(i)].level)
		hi = maxi(hi, inventory.slots[int(i)].level)
	return "Lv %d" % lo if lo == hi else "Lv %d-%d" % [lo, hi]

## The group count in the cell's top-right corner; hidden for n = 0 (the grid reuses its buttons).
func _badge(btn: Button, n: int) -> void:
	var b := btn.get_node_or_null("Badge") as Label
	if b == null:
		if n <= 0:
			return
		b = Label.new()
		b.name = "Badge"
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pill := StyleBoxFlat.new()
		pill.bg_color = UiTokens.INK_SOLID
		pill.border_color = UiTokens.TEXT
		pill.set_border_width_all(1)
		pill.set_corner_radius_all(10)
		pill.content_margin_left = 3.0 # a slim pill tucked in the corner covers little of a 64 px cell's icon
		pill.content_margin_right = 3.0
		b.add_theme_stylebox_override("normal", pill)
		b.add_theme_color_override("font_color", UiTokens.TEXT)
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		b.offset_left = -2.0
		b.offset_right = -2.0
		b.offset_top = 2.0
		btn.add_child(b)
	b.visible = n > 0
	b.text = str(n)
	var fs := clampi(int(_slot_px / 7.0), 12, 20)
	b.add_theme_font_size_override("font_size", fs)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size.x = fs * 1.4 # one digit reads as a round pill, not a standing capsule

func _on_cell(k: int) -> void:
	if k < 0 or k >= _cells.size():
		return
	var cell: Dictionary = _cells[k]
	if cell.has("empty"):
		return
	if cell.has("back"):
		_open_group = &""
		rebuild()
	elif cell.has("group"):
		_open_group = cell.group
		_selected = int(cell.slots[0])
		rebuild()
	else:
		_select(int(cell.slot))

func _refresh_profile() -> void:
	if _profile == null or inventory == null:
		return
	var view := get_viewport_rect().size
	var body_px := UiTokens.body(view)
	var name := _owner_player.display_name() if _owner_player else (World.player_name if World.player_name != "" else "Survivor")
	var occupation := World.occupation.capitalize() if World.occupation != "" else "Survivor"
	var hp: float = _owner_player.vitals.health if _owner_player and _owner_player.vitals else 0.0
	var energy: float = _owner_player.vitals.energy if _owner_player and _owner_player.vitals else 0.0
	var gathering: int = _owner_player.skills.level_of("gathering") if _owner_player and _owner_player.skills else 0
	var font := ThemeDB.fallback_font
	var name_w := _name_column_width(view)
	name = UiTokens.ellipsis(font, name, name_w, body_px)
	_profile.add_theme_font_size_override("font_size", body_px)
	_profile.add_theme_constant_override("line_spacing", UiTokens.SPACE)
	_profile.custom_minimum_size = Vector2(minf(180.0, name_w), body_px * 3 + UiTokens.SPACE * 2)
	# The held title sits under the name from character creation on (level 1 holds "Venture into the World").
	var title := UiTokens.ellipsis(font, LevelDisplay.current_title(LevelDisplay.player_level()), name_w, body_px)
	_profile.text = "%s\n%s\n%s  ·  %s" % [name, title, occupation, LevelDisplay.player_label()]
	var lines: PackedStringArray = [
		"HP        %.0f" % hp,
		"Energy    %.0f" % energy,
		"Gathering %d" % gathering,
		"Bag       %d / %d" % [inventory.used_slots(), inventory.slot_count],
	]
	for i in _stat_rows.size():
		_stat_rows[i].text = lines[i] if i < lines.size() else ""
		_stat_rows[i].add_theme_font_size_override("font_size", body_px)

func _name_column_width(view: Vector2) -> float:
	var safe := UiTokens.safe_insets(get_viewport())
	var panel_w := view.x - (24.0 + safe.w + safe.x)
	if UiTokens.is_phone(view):
		return maxf(160.0, panel_w - 8.0)
	var used := 0.0
	if _bag_col:
		used += _bag_col.custom_minimum_size.x
	if _equip_col:
		used += _equip_col.custom_minimum_size.x
	used += float(UiTokens.SPACE) * 4.0
	return maxf(180.0, panel_w - used - 8.0)

func _apply_slot_metrics(view: Vector2, safe: Vector4) -> void:
	var sep := float(UiTokens.SPACE)
	var phone := UiTokens.is_phone(view)
	var panel_w := maxf(280.0, view.x - (24.0 + safe.w + safe.x))
	var panel_h := maxf(280.0, view.y - (24.0 + safe.z + safe.y))
	var slot := 64.0
	# Four equipment columns need 9 slots of 64 px beside the 180 px profile; compact landscape canvases get three.
	var equip_cols := 4 if panel_w >= 180.0 + 9.0 * 64.0 + sep * 11.0 else 3
	if phone:
		slot = floorf((panel_w - sep * 4.0) / 5.0)
		slot = clampf(slot, 56.0, 80.0)
		if _bag_col:
			_bag_col.custom_minimum_size = Vector2.ZERO
			_bag_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _equip_col:
			_equip_col.custom_minimum_size = Vector2.ZERO
			_equip_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _equip_pad:
			_equip_pad.custom_minimum_size = Vector2.ZERO
	else:
		var profile_floor := 280.0
		var h_gaps := sep * 4.0
		# Bag 5 wide + equipment 4 wide (head/body/arms/legs in one row keeps it to three rows).
		var inner_seps := sep * float(3 + equip_cols)
		var chrome := 44.0 + sep + 36.0 + sep
		var label_h := float(UiTokens.meta(view)) + 4.0
		var grid_h := panel_h - chrome - label_h - sep * 2.0
		var by_h := floorf((grid_h - sep * 3.0) / 4.0)
		var by_w := floorf((panel_w - h_gaps - profile_floor - inner_seps) / float(5 + equip_cols))
		slot = maxf(64.0, minf(by_w, by_h))
		var bag_w := 5.0 * slot + sep * 4.0
		var equip_w := float(equip_cols) * slot + sep * float(equip_cols - 1)
		if _bag_col:
			_bag_col.custom_minimum_size = Vector2(bag_w, 0)
			_bag_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if _equip_col:
			_equip_col.custom_minimum_size = Vector2(equip_w, 0)
			_equip_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_slot_px = slot
	if _equip_grid:
		_equip_grid.columns = 3 if phone else equip_cols
	var sz := _slot_vec()
	for child in _grid.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = sz
	for key in _equip_slots.keys():
		var button: Button = _equip_slots[key]
		button.custom_minimum_size = sz
		var cell := button.get_parent()
		if cell and cell.get_child_count() > 0 and cell.get_child(0) is Label:
			var cap := cell.get_child(0) as Label
			cap.custom_minimum_size = Vector2(slot, 0)
			cap.add_theme_font_size_override("font_size", UiTokens.meta(view))
	for child in _pet_grid.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = sz
	if not phone and _equip_pad and _grid and _equip_grid:
		var bag_h := _grid.get_combined_minimum_size().y
		var equip_h := _equip_grid.get_combined_minimum_size().y
		_equip_pad.custom_minimum_size = Vector2(0, maxf(0.0, (bag_h - equip_h) * 0.5))

func _refresh_equipped() -> void:
	for slot in _equip_slots.keys():
		var b: Button = _equip_slots[slot]
		var st: ItemStack = null
		var caption := ""
		match slot:
			"weapon":
				st = inventory.equipped_weapon()
				if st and st.def():
					caption = "%.0f" % st.scaled_damage()
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
		if st and st.scaled_armor() > 0:
			caption = "%.0f" % st.scaled_armor()
		if st:
			ItemIcons.style_slot(b, st.def_id, caption)
			_fit_slot(b)
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
	for b in [_store_btn, _lock_btn, _equip_btn, _food1_btn, _food2_btn, _inspect_btn, _eat_btn, _feed_btn, _place_btn]:
		b.visible = false
	for k in mini(_grid.get_child_count(), _cells.size()):
		var slot_btn := _grid.get_child(k) as Button
		var cell: Dictionary = _cells[k]
		if slot_btn:
			_slot_style(slot_btn, index >= 0 and (int(cell.get("slot", -1)) == index or index in (cell.get("slots", []) as Array)))
	if none:
		_tip.text = "Tap an item."
		return
	var stack := inventory.slots[index]
	_tip.text = stack.tooltip()
	_lock_btn.visible = true
	_lock_btn.text = "Unlock" if stack.is_locked() else "Lock"
	_store_btn.visible = _can_store_selected()
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
			if inventory.equipment.has(slot) and not inventory.unequip(StringName(slot)) and _owner_player:
				_owner_player.notice("Bag is full.") # the gear stays worn (W2-INV: never dropped)

func _on_equip_pressed() -> void:
	if inventory == null or _selected < 0 or _selected >= inventory.slot_count:
		return
	var st := inventory.slots[_selected]
	if st == null:
		return
	var d := st.def()
	var slot := Inventory.slot_for(d)
	if slot != &"":
		inventory.equip_at(_selected, slot) # the exact item selected, not the first of its id
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

## Loot is take-only unless its owner explicitly exposes writable storage.
func _can_store_selected() -> bool:
	if pet_bag == null or inventory == null or _readonly_reason() != "" or not bool(_storage_opts.get("allow_deposit",false)):
		return false
	if _selected < 0 or _selected >= inventory.slot_count: return false
	var st := inventory.slots[_selected]
	if st == null or st.is_locked() or str(st.def_id) == "_slot_lock": return false
	if inventory.equipped_tool_index == _selected: return false
	if str(st.def_id) in inventory.quick_food: return false # worn gear is out of the bag (W2-INV)
	return true

func _store_selected() -> void:
	if not _can_store_selected(): return
	var moved := inventory.transfer_to(pet_bag,_selected)
	if moved == 0 and _owner_player: _owner_player.notice("Storage is full.")
	rebuild()
