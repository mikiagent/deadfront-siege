class_name InventoryUI
extends Control
## The Bag family (owner spec 13), docked on the right over the live world (addendum 2):
## - Bag page: header "Bag  used / capacity" (warning colour when full), a scrolling grid of one
##   instance per slot (BagGrid: Lv., NEW, rare corner, gold brackets), and the bottom toolbar
##   (Auto Sort, Filter, Select, Lock, Destroy; Take all on a container's tab).
## - The item card (ItemInspectPanel) floats between the world and the bag: facts, gold / grey /
##   green traits and only the actions valid for the selected instance (valid_actions).
## - A container (storage box, basket, loot, a dinosaur's cargo) adds its own tab beside the Bag tab:
##   the same grid, the card's "Transfer to ..." moves the exact instance either way.
## - Character page (spec 13 s13-15): portrait, level and XP, Combat / Crafting / Gathering Power,
##   My Info (Attack / Defense / Accuracy), Detailed Stats; Gear | Decorative Gear tabs, numbered
##   presets (GearPresets) and the worn slots with faded silhouettes; a worn piece selected shows
##   its Unequip.
## Every control a finger presses is at least TAP px (64) tall. Escape or the close button dismisses.

var inventory: Inventory
var pet_bag: Inventory
var _owner_player: Player
var _selected: int = -1
## The selected slot of the open container (its tab), -1 for none.
var _store_sel: int = -1
var _storage_opts: Dictionary = {}
var _food_inspector: FoodInspector
var _bag_inspector: BagInspect
## "bag" or "store": which grid the Bag page shows.
var _tab := "bag"
## "bag" or "character".
var _page := "bag"

var _panel: Panel
var _root: VBoxContainer
var _title: Label
var _grid: BagGrid
var _pet_grid: BagGrid
var _cap_label: Label
var _bag_tab: Button
var _store_tab: Button
var _char_tab: Button
var _storage_title: Label
var _storage_note: Label
var _tip: Label
var _card: ItemInspectPanel
var _bag_page: VBoxContainer
var _toolbar: HBoxContainer
var _sort_btn: Button
var _filter_btn: Button
var _lock_btn: Button
var _place_btn: Button
var _eat_btn: Button
var _inspect_btn: Button
var _feed_btn: Button
var _store_btn: Button
var _take_btn: Button
var _drop_btn: Button
var _destroy_btn: Button
var _take_all_btn: Button
## Feature A: Select mode + batch bar (taps mark; Lock/Drop/Destroy then apply to the whole batch).
var _select_btn: Button
var _batch_row: HBoxContainer
var _batch_label: Label
var _batch_lock_btn: Button
var _batch_drop_btn: Button
var _batch_destroy_btn: Button
var _batch_destroy_armed := false
var _batch_store_btn: Button
var _batch_take_btn: Button
var _equip_btn: Button
var _food1_btn: Button
var _food2_btn: Button
var _close_btn: Button
var _destroy_armed_index := -1
## NEW tags (spec 13 s7): uids that entered the bag since it was bound; a tap acknowledges one,
## closing the bag acknowledges all it showed. Loads never count (bind takes the baseline).
var _known_uids: Dictionary = {}
var _new_uids: Dictionary = {}

# Character page
var _char_page: HBoxContainer
var _info_col: VBoxContainer
var _portrait: TextureRect
var _profile: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _power_rows: Array[Label] = []
var _myinfo: Array[Label] = []
var _power_grid: GridContainer
var _stats_btn: Button
var _stats_scroll: ScrollContainer
var _stats_label: Label
var _gear_tab: Button
var _deco_tab: Button
var _deco_note: Label
var _preset_btns: Array[Button] = []
var _equip_grid: GridContainer
var _equip_slots: Dictionary = {}  # slot name -> Button
var _gear_sel := ""
var _gear_sel_label: Label
var _unequip_btn: Button
var _deco := false

const TAP := 64.0
const EQUIP_ORDER := ["head", "body", "arms", "legs", "weapon", "tool", "accessory1", "accessory2", "food1", "food2"]
const EQUIP_LABELS := {"head": "Head", "body": "Body", "arms": "Arms", "legs": "Legs", "accessory1": "Ring", "accessory2": "Ring", "weapon": "Weapon", "tool": "Tool", "food1": "Food 1", "food2": "Food 2"}
## Faded silhouettes for empty gear slots (spec 13 s14): a representative item's art at low alpha.
const SILHOUETTES := {"head": &"forager_hood", "body": &"forager_vest", "arms": &"forager_wraps", "legs": &"forager_leggings", "weapon": &"stone_knife", "tool": &"work_pick", "accessory1": &"basic_bag", "accessory2": &"basic_bag", "food1": &"berry", "food2": &"berry"}
const INK := Color(0.95, 0.95, 0.93)
const GOLD := Color("#E6BE54")
const PANEL := Color("#39392F")
## ASSUMPTION: the sheet may use 68% of the view, capped at 1120 px, so the live world remains
## visible on the left (where the item card floats) while the bag keeps usable widths.
const SHEET_SHARE := 0.68
const SHEET_MIN_PX := 520.0
const SHEET_MAX_PX := 1120.0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if Game.shot_path.contains("bag"):
		get_tree().create_timer(0.9).timeout.connect(func () -> void: visible = true; rebuild())
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var psb := UiTokens.panel_style()
	psb.bg_color = Color(PANEL, 0.97)
	psb.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override("panel", psb)
	add_child(_panel)
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 6
	_root.offset_top = 6
	_root.offset_right = -6
	_root.offset_bottom = -6
	_root.add_theme_constant_override("separation", 6)
	_panel.add_child(_root)
	# Header (spec 13 s4): "Bag  91 / 100", the container's tab, Character, close.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	_root.add_child(header)
	_title = Label.new() # kept for callers that read the screen's title
	_title.visible = false
	header.add_child(_title)
	_bag_tab = _btn("Bag", Vector2(72, TAP))
	_bag_tab.name = "BagTab"
	_bag_tab.pressed.connect(func () -> void: _show_page("bag", "bag"))
	header.add_child(_bag_tab)
	_cap_label = Label.new()
	_cap_label.name = "Capacity"
	_cap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cap_label.custom_minimum_size = Vector2(76, TAP)
	_cap_label.add_theme_color_override("font_color", INK)
	header.add_child(_cap_label)
	_store_tab = _btn("", Vector2(150, TAP))
	_store_tab.name = "StoreTab"
	_store_tab.clip_text = true
	_store_tab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_store_tab.pressed.connect(func () -> void: _show_page("bag", "store"))
	header.add_child(_store_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_char_tab = _btn("Character", Vector2(112, TAP))
	_char_tab.name = "CharacterTab"
	_char_tab.pressed.connect(func () -> void: _show_page("character", _tab))
	header.add_child(_char_tab)
	_close_btn = _btn("✕", Vector2(TAP, TAP))
	_close_btn.name = "CloseButton"
	_close_btn.pressed.connect(hide_ui)
	header.add_child(_close_btn)
	_build_bag_page()
	_build_char_page()
	_build_card()
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
	# Spec 31 §9: a bag's inspect panel (level, capacity breakdown, quality, durability, comparison).
	_bag_inspector = BagInspect.new()
	_bag_inspector.name = "BagInspector"
	add_child(_bag_inspector)
	resized.connect(_layout_safe)
	_layout_safe()
	rebuild()

func _build_bag_page() -> void:
	_bag_page = VBoxContainer.new()
	_bag_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_page.add_theme_constant_override("separation", 6)
	_root.add_child(_bag_page)
	_storage_title = Label.new() # the container's name lives on its tab; kept for callers
	_storage_title.visible = false
	_bag_page.add_child(_storage_title)
	_storage_note = Label.new()
	_storage_note.add_theme_color_override("font_color", UiTokens.DANGER)
	_storage_note.clip_text = true
	_storage_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bag_page.add_child(_storage_note)
	_grid = BagGrid.new()
	_grid.name = "BagGrid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.selected.connect(_on_bag_slot_tapped)
	_bag_page.add_child(_grid)
	_pet_grid = BagGrid.new()
	_pet_grid.name = "StoreGrid"
	_pet_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pet_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pet_grid.selected.connect(_on_store_slot_tapped)
	_pet_grid.visible = false
	_bag_page.add_child(_pet_grid)
	_tip = Label.new()
	_tip.text = "Tap an item."
	_tip.add_theme_color_override("font_color", UiTokens.META)
	_tip.clip_text = true
	_tip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_bag_page.add_child(_tip)
	# Bottom toolbar (spec 13 s9): wide Auto Sort, then Filter, Select, Lock and the trash.
	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.add_theme_constant_override("separation", 6)
	_bag_page.add_child(_toolbar)
	_sort_btn = _btn("Auto Sort", Vector2(120, TAP))
	_sort_btn.name = "SortButton"
	_sort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort_btn.pressed.connect(_on_sort)
	_toolbar.add_child(_sort_btn)
	_filter_btn = _btn("All", Vector2(92, TAP))
	_filter_btn.name = "FilterButton"
	_filter_btn.pressed.connect(_on_filter)
	_toolbar.add_child(_filter_btn)
	_batch_label = Label.new()
	_batch_label.text = "0 selected"
	_batch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_batch_label.add_theme_color_override("font_color", INK)
	_batch_label.custom_minimum_size = Vector2(96, TAP)
	_batch_label.visible = false
	_toolbar.add_child(_batch_label)
	_select_btn = _btn("Select", Vector2(84, TAP))
	_select_btn.name = "SelectButton"
	_select_btn.pressed.connect(_on_toggle_multi)
	_toolbar.add_child(_select_btn)
	_lock_btn = _btn("Lock", Vector2(80, TAP))
	_lock_btn.name = "LockButton"
	_lock_btn.pressed.connect(_toggle_lock)
	_toolbar.add_child(_lock_btn)
	_destroy_btn = _btn("Destroy", Vector2(92, TAP))
	_destroy_btn.name = "DestroyButton"
	_destroy_btn.add_theme_color_override("font_color", UiTokens.DANGER)
	_destroy_btn.pressed.connect(_destroy_selected)
	_toolbar.add_child(_destroy_btn)
	_take_all_btn = _btn("Take all", Vector2(100, TAP))
	_take_all_btn.name = "TakeAllButton"
	_take_all_btn.pressed.connect(_take_all_storage)
	_toolbar.add_child(_take_all_btn)
	# Select mode's batch actions share the toolbar row (they replace sort, filter, lock and trash).
	_batch_row = _toolbar
	_batch_lock_btn = _btn("Lock", Vector2(80, TAP))
	_batch_lock_btn.pressed.connect(_on_batch_lock)
	_toolbar.add_child(_batch_lock_btn)
	_batch_drop_btn = _btn("Drop", Vector2(80, TAP))
	_batch_drop_btn.pressed.connect(_on_batch_drop)
	_toolbar.add_child(_batch_drop_btn)
	_batch_destroy_btn = _btn("Destroy", Vector2(92, TAP))
	_batch_destroy_btn.add_theme_color_override("font_color", UiTokens.DANGER)
	_batch_destroy_btn.pressed.connect(_on_batch_destroy)
	_toolbar.add_child(_batch_destroy_btn)
	_batch_store_btn = _btn("Store", Vector2(84, TAP))
	_batch_store_btn.name = "BatchStoreButton"
	_batch_store_btn.pressed.connect(_on_batch_store)
	_toolbar.add_child(_batch_store_btn)
	_batch_take_btn = _btn("Transfer to Bag", Vector2(150, TAP))
	_batch_take_btn.name = "BatchTakeButton"
	_batch_take_btn.pressed.connect(_on_batch_take)
	_toolbar.add_child(_batch_take_btn)
	# Hold-and-drag selection (owner 2026-10-27): a long press or a Shift-press on either grid
	# enters Select mode there; painting the cells updates the "N selected" count.
	for g: BagGrid in [_grid, _pet_grid]:
		g.multi_started.connect(func () -> void: _set_multi_mode(true))
		g.multi_changed.connect(func () -> void: _disarm_batch_destroy(); _update_batch_bar())

func _build_card() -> void:
	_card = ItemInspectPanel.new()
	_card.z_index = 1
	add_child(_card)
	_equip_btn = _action("Equip", _on_equip_pressed)
	_eat_btn = _action("Eat", _on_eat_food)
	_inspect_btn = _action("Inspect", _on_inspect)
	_food1_btn = _action("Food 1", func () -> void: _set_quick(0))
	_food2_btn = _action("Food 2", func () -> void: _set_quick(1))
	_feed_btn = _action("Feed", _on_feed_pet)
	_place_btn = _action("Place", _on_place_pressed)
	_store_btn = _action("Store", _store_selected)
	_store_btn.name = "StoreButton"
	_take_btn = _action("Transfer to Bag", func () -> void: _take_storage(_store_sel))
	_take_btn.name = "TakeButton"
	_drop_btn = _action("Drop", _drop_selected)
	_drop_btn.name = "DropButton"

func _build_char_page() -> void:
	_char_page = HBoxContainer.new()
	_char_page.name = "CharacterPage"
	_char_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_char_page.add_theme_constant_override("separation", 10)
	_char_page.visible = false
	_root.add_child(_char_page)
	_info_col = VBoxContainer.new()
	_info_col.add_theme_constant_override("separation", 4)
	_char_page.add_child(_info_col)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 8)
	_info_col.add_child(who)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.custom_minimum_size = Vector2(TAP, TAP)
	who.add_child(_portrait)
	_profile = Label.new()
	_profile.name = "Profile"
	_profile.clip_text = true
	_profile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile.add_theme_color_override("font_color", INK)
	who.add_child(_profile)
	_level_label = Label.new()
	_level_label.add_theme_color_override("font_color", INK)
	_info_col.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.show_percentage = false
	_xp_bar.max_value = 1.0
	_xp_bar.custom_minimum_size = Vector2(0, 8)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#0C0F0C")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#3E8E3A")
	_xp_bar.add_theme_stylebox_override("background", track)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	_info_col.add_child(_xp_bar)
	# Powers (left) beside My Info (spec 13 s15: Attack / Defense / Accuracy, right), one row each.
	_power_grid = GridContainer.new()
	_power_grid.name = "MyInfo"
	_power_grid.columns = 2
	_power_grid.add_theme_constant_override("h_separation", 10)
	_power_grid.add_theme_constant_override("v_separation", 2)
	_info_col.add_child(_power_grid)
	for _i in 3:
		var l := Label.new()
		l.add_theme_color_override("font_color", INK)
		l.clip_text = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_power_grid.add_child(l)
		_power_rows.append(l)
		var m := Label.new()
		m.add_theme_color_override("font_color", GOLD)
		_power_grid.add_child(m)
		_myinfo.append(m)
	_stats_scroll = ScrollContainer.new()
	_stats_scroll.name = "DetailedStats"
	_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_scroll.visible = false
	_info_col.add_child(_stats_scroll)
	_stats_label = Label.new()
	_stats_label.add_theme_color_override("font_color", INK)
	_stats_scroll.add_child(_stats_label)
	_stats_btn = _btn("Detailed Stats", Vector2(0, TAP))
	_stats_btn.name = "DetailedStatsButton"
	_stats_btn.pressed.connect(_toggle_stats)
	_info_col.add_child(_stats_btn)
	# Right: Gear | Decorative Gear, presets, the worn slots, the selected piece and Unequip.
	var gear := VBoxContainer.new()
	gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear.add_theme_constant_override("separation", 6)
	_char_page.add_child(gear)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	gear.add_child(tabs)
	_gear_tab = _btn("Gear", Vector2(88, TAP))
	_gear_tab.pressed.connect(func () -> void: _deco = false; _refresh_character())
	tabs.add_child(_gear_tab)
	_deco_tab = _btn("Decorative", Vector2(104, TAP))
	_deco_tab.pressed.connect(func () -> void: _deco = true; _refresh_character())
	tabs.add_child(_deco_tab)
	for k in GearPresets.count():
		var b := _btn(str(k + 1), Vector2(TAP, TAP))
		b.name = "Preset%d" % (k + 1)
		b.pressed.connect(_on_preset.bind(k))
		tabs.add_child(b)
		_preset_btns.append(b)
	_equip_grid = GridContainer.new()
	_equip_grid.columns = 5
	_equip_grid.add_theme_constant_override("h_separation", 6)
	_equip_grid.add_theme_constant_override("v_separation", 6)
	gear.add_child(_equip_grid)
	for slot_name: String in EQUIP_ORDER:
		var b := _btn("", Vector2(TAP, TAP))
		b.name = "Equip_%s" % slot_name
		b.clip_text = true
		b.expand_icon = true
		b.pressed.connect(_on_equip_slot_pressed.bind(slot_name))
		_equip_grid.add_child(b)
		_equip_slots[slot_name] = b
	# ASSUMPTION: the game has no decorative (cosmetic) gear yet, so its tab says so instead of
	# inventing slots (spec 13 s13: only what the game supports).
	_deco_note = Label.new()
	_deco_note.text = "No decorative gear yet."
	_deco_note.add_theme_color_override("font_color", UiTokens.META)
	_deco_note.visible = false
	gear.add_child(_deco_note)
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 6)
	gear.add_child(sel)
	_gear_sel_label = Label.new()
	_gear_sel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_sel_label.clip_text = true
	_gear_sel_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_gear_sel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gear_sel_label.custom_minimum_size = Vector2(0, TAP)
	_gear_sel_label.add_theme_color_override("font_color", INK)
	sel.add_child(_gear_sel_label)
	_unequip_btn = _btn("Unequip", Vector2(112, TAP))
	_unequip_btn.name = "UnequipButton"
	_unequip_btn.pressed.connect(_on_unequip_pressed)
	sel.add_child(_unequip_btn)

func _btn(text: String, minsz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsz
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_NONE
	return b

## A card action: hidden until valid_actions lists it for the selection.
func _action(text: String, cb: Callable) -> Button:
	var b := _btn(text, Vector2(0, TAP))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(cb)
	b.visible = false
	_card.actions.add_child(b)
	return b

## Active tab / preset: gold with dark text; the rest stay dark.
func _tab_style(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GOLD if on else Color("#26322C")
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(6)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color("#1B1A14") if on else INK)
	b.add_theme_color_override("font_hover_color", Color("#1B1A14") if on else INK)

# ---------------------------------------------------------------- open / close

func bind(inv: Inventory, owner_player: Player = null) -> void:
	inventory = inv
	_owner_player = owner_player
	_known_uids = _all_uids()
	_new_uids.clear()
	inventory.changed.connect(rebuild)
	rebuild()

func hide_ui() -> void:
	if visible:
		_new_uids.clear() # seen: closing the bag acknowledges what it showed
	visible = false
	pet_bag = null
	_storage_opts = {}
	_store_sel = -1
	_tab = "bag"
	_page = "bag"
	if _card:
		_card.hide_card()
	_set_multi_mode(false)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_ui()
		get_viewport().set_input_as_handled()

func show_pet_bag(rec: PetRecord) -> void:
	# Spec 13 s17: a bonded dinosaur's cargo is the same grid on its own tab.
	show_storage(rec.bag, null, {"title": "%s cargo" % rec.name if rec.name != "" else "Pet bag", "take_all": false, "allow_deposit": true})

func show_storage(inv: Inventory, owner_player: Player = null, opts: Dictionary = {}) -> void:
	pet_bag = inv
	_storage_opts = opts.duplicate(true)
	if owner_player:
		_owner_player = owner_player
	if pet_bag and not pet_bag.changed.is_connected(rebuild):
		pet_bag.changed.connect(rebuild)
	_store_sel = -1
	_tab = "store" if pet_bag else "bag"
	_page = "bag"
	visible = true
	rebuild()

func _show_page(page: String, tab: String) -> void:
	_page = page
	_tab = tab if pet_bag != null else "bag"
	_set_multi_mode(false)
	_layout_safe()
	rebuild()

## The sheet: the Bag page docks on the right (the world and the item card on its left); the
## Character page takes the whole view like the reference.
func _layout_safe() -> void:
	if _panel == null:
		return
	var r := get_viewport_rect().size
	var safe := UiTokens.safe_insets(get_viewport())
	var sheet := side_sheet_rect(r, safe) if _page == "bag" else full_rect(r, safe)
	_panel.offset_left = sheet.position.x
	_panel.offset_top = sheet.position.y
	_panel.offset_right = sheet.end.x - r.x
	_panel.offset_bottom = sheet.end.y - r.y
	var compact := UiTokens.is_compact(r)
	var body := 14 if compact else UiTokens.body(r)
	for b: Button in _all_buttons():
		b.add_theme_font_size_override("font_size", body)
	for l: Label in [_cap_label, _tip, _storage_note, _profile, _level_label, _stats_label, _gear_sel_label, _deco_note] + _power_rows + _myinfo:
		if l:
			l.add_theme_font_size_override("font_size", body)
			l.add_theme_constant_override("line_spacing", 0) # the game theme's spacing made each line 29 px
	_cap_label.add_theme_font_size_override("font_size", 18 if compact else 26)
	var cell := 64.0 if compact else clampf(floorf((sheet.size.x - 12.0 - 6.0 * 7.0) / 8.0), 64.0, 120.0)
	_grid.cell_px = cell
	_pet_grid.cell_px = cell
	_info_col.custom_minimum_size = Vector2(320.0 if compact else 460.0, 0)
	# Icon over the slot's name inside a 64 px cell (the art's own size made the gear rows 93 px).
	for b: Button in _equip_slots.values():
		b.add_theme_constant_override("icon_max_width", 30 if compact else 56)
		b.custom_minimum_size = Vector2(TAP, TAP) if compact else Vector2(96, 96)
	_card.set_scale_for(r)
	_layout_card()

static func side_sheet_rect(view: Vector2, safe: Vector4 = Vector4.ZERO) -> Rect2:
	var left := 12.0 + safe.w
	var right := view.x - 12.0 - safe.x
	var top := 12.0 + safe.z
	var bottom := view.y - 12.0 - safe.y
	var available := maxf(0.0, right - left)
	var width := minf(available, clampf(view.x * SHEET_SHARE, SHEET_MIN_PX, SHEET_MAX_PX))
	return Rect2(Vector2(right - width, top), Vector2(width, maxf(0.0, bottom - top)))

static func full_rect(view: Vector2, safe: Vector4 = Vector4.ZERO) -> Rect2:
	var p := Vector2(12.0 + safe.w, 12.0 + safe.z)
	return Rect2(p, Vector2(maxf(0.0, view.x - 24.0 - safe.w - safe.x), maxf(0.0, view.y - 24.0 - safe.z - safe.y)))

## Where the item card sits: between the world's left edge and the docked bag (addendum 2), or over
## the bag's left half when the world strip is too narrow for it.
static func card_rect(view: Vector2, safe: Vector4 = Vector4.ZERO) -> Rect2:
	var sheet := side_sheet_rect(view, safe)
	var left := 12.0 + safe.w
	var free := sheet.position.x - 8.0 - left
	if free >= 220.0:
		return Rect2(Vector2(left, sheet.position.y), Vector2(minf(free, 400.0), sheet.size.y))
	return Rect2(sheet.position, Vector2(minf(sheet.size.x * 0.5, 320.0), sheet.size.y))

## Sizes the card to its content, never taller than its rect (its facts scroll inside).
func _layout_card() -> void:
	if _card == null:
		return
	var view := get_viewport_rect().size
	var r := card_rect(view, UiTokens.safe_insets(get_viewport()))
	_card.actions.columns = 2 if r.size.x < 320.0 else 3
	_card.position = r.position
	_card.custom_minimum_size = Vector2(r.size.x, 0)
	_card.fit(r.size.y)

func _all_buttons() -> Array[Button]:
	var out: Array[Button] = [_bag_tab, _store_tab, _char_tab, _close_btn, _sort_btn, _filter_btn, _select_btn, _lock_btn,
		_destroy_btn, _take_all_btn, _batch_lock_btn, _batch_drop_btn, _batch_destroy_btn, _stats_btn, _gear_tab, _deco_tab,
		_unequip_btn, _batch_store_btn, _batch_take_btn, _equip_btn, _eat_btn, _inspect_btn, _food1_btn, _food2_btn, _feed_btn, _place_btn, _store_btn, _take_btn, _drop_btn]
	out.append_array(_preset_btns)
	for b: Button in _equip_slots.values():
		out.append(b)
	return out

# ---------------------------------------------------------------- rebuild

func rebuild() -> void:
	if inventory == null:
		return
	_track_new()
	if _grid == null:
		return
	var has_storage := pet_bag != null
	if not has_storage:
		_tab = "bag"
	_grid.new_uids = _new_uids
	_grid.bind(inventory)
	_grid.set_selected(_selected)
	# The header keeps "used / capacity" from the data (spec 13 s4); full is a warning colour.
	var used := inventory.used_slots()
	var cap := inventory.capacity()
	_cap_label.text = "%d / %d" % [used, cap]
	_cap_label.add_theme_color_override("font_color", UiTokens.DANGER if used >= cap else INK)
	_store_tab.visible = has_storage
	if has_storage:
		_store_tab.text = "%s %d / %d" % [str(_storage_opts.get("title", "Storage")), pet_bag.used_slots(), pet_bag.slot_count]
		_pet_grid.readonly = false # a take-only box still selects; its card says why it cannot take
		_pet_grid.bind(pet_bag)
		_pet_grid.set_selected(_store_sel)
	_storage_title.text = str(_storage_opts.get("title", "")) if has_storage else ""
	_title.text = "Bag" if not has_storage else "Bag  ·  %s" % _storage_title.text
	var on_bag := _page == "bag"
	_bag_page.visible = on_bag
	_char_page.visible = not on_bag
	_grid.visible = on_bag and _tab == "bag"
	_pet_grid.visible = on_bag and _tab == "store"
	_storage_note.text = _readonly_reason()
	_storage_note.visible = on_bag and _tab == "store" and _storage_note.text != ""
	_tab_style(_bag_tab, on_bag and _tab == "bag")
	_tab_style(_store_tab, on_bag and _tab == "store")
	_tab_style(_char_tab, not on_bag)
	_take_all_btn.disabled = _readonly_reason() != "" or pet_bag == null or pet_bag.used_slots() <= 0
	_update_toolbar()
	if on_bag:
		if _tab == "store":
			_select_store(_store_sel)
		else:
			_select(_selected)
	else:
		_card.hide_card()
		_refresh_character()
	_update_batch_bar()

## Toolbar for the active tab: the bag's tools, or the container's Take all.
func _update_toolbar() -> void:
	var store := _tab == "store"
	var g := _active_grid()
	var multi := g != null and g.multi_mode
	_sort_btn.text = "Auto Sort: %s" % str(BagGrid.SORT_LABELS.get(g.sort_key, "Bag order"))
	_filter_btn.text = str(BagGrid.FILTER_LABELS.get(g.filter_id, "All"))
	_sort_btn.visible = not multi
	_filter_btn.visible = not multi
	_select_btn.visible = true
	_lock_btn.visible = not store and not multi
	_destroy_btn.visible = not store and not multi
	_take_all_btn.visible = store and bool(_storage_opts.get("take_all", false))
	for b: Button in [_batch_lock_btn, _batch_drop_btn, _batch_destroy_btn]:
		b.visible = multi and not store
	_batch_store_btn.visible = multi and not store and pet_bag != null and bool(_storage_opts.get("allow_deposit", false)) and _readonly_reason() == ""
	_batch_take_btn.visible = multi and store
	_take_all_btn.visible = _take_all_btn.visible and not multi
	_batch_label.visible = multi

func _active_grid() -> BagGrid:
	return _pet_grid if _tab == "store" and pet_bag != null else _grid

func _on_sort() -> void:
	var g := _active_grid()
	g.sort_key = BagGrid.SORTS[(BagGrid.SORTS.find(g.sort_key) + 1) % BagGrid.SORTS.size()]
	g.rebuild()
	_update_toolbar()

func _on_filter() -> void:
	var g := _active_grid()
	g.filter_id = BagGrid.FILTERS[(BagGrid.FILTERS.find(g.filter_id) + 1) % BagGrid.FILTERS.size()]
	g.rebuild()
	_update_toolbar()

## Every uid this survivor owns now: the bag and worn gear (unequipping is not "new").
func _all_uids() -> Dictionary:
	var out := inventory.uids() if inventory else {}
	if inventory:
		for v: Variant in inventory.equipment.values():
			if v is ItemStack and (v as ItemStack).uid != "":
				out[(v as ItemStack).uid] = true
	return out

func _track_new() -> void:
	var now := _all_uids()
	for uid: Variant in inventory.uids():
		if not _known_uids.has(uid):
			_new_uids[uid] = true
	for uid: Variant in _new_uids.keys():
		if not now.has(uid):
			_new_uids.erase(uid)
	_known_uids = now

## A tap on a compartment: select that exact instance (one item per slot); in Select mode it
## toggles the batch membership instead (Feature A).
func _on_bag_slot_tapped(index: int) -> void:
	if _grid.multi_mode:
		_grid.toggle_multi(index)
		_disarm_batch_destroy()
		_update_batch_bar()
		return
	_select(index)

func _on_store_slot_tapped(index: int) -> void:
	_select_store(index)

## The actions valid for one instance, by what it is and where it sits (spec 13 s10: "only show
## valid actions"). ctx: {where: "bag"|"store", pet: bool, deposit: bool (an open container takes
## it), take: bool (the container lets it out), world: bool}. Lock and Destroy live on the toolbar.
static func valid_actions(stack: ItemStack, ctx: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	if stack == null or stack.def_id == Inventory.LOCK:
		return out
	if str(ctx.get("where", "bag")) == "store":
		if bool(ctx.get("take", true)):
			out.append("take")
		return out
	var d := stack.def()
	var food := Food.is_food(stack)
	if food:
		out.append_array(["eat", "food1", "food2", "inspect"])
		if bool(ctx.get("pet", false)):
			out.append("feed")
	elif BagCapacity.is_bag(stack.def_id):
		out.append("inspect")
	if Inventory.slot_for(d) != &"" or (d != null and d.tool_class != &"" and d.tool_class != &"none"):
		out.append("equip")
	if d != null and d.place_as != &"":
		out.append("place")
	if bool(ctx.get("deposit", false)):
		out.append("store")
	out.append("drop")
	return out

func _action_buttons() -> Dictionary:
	return {"eat": _eat_btn, "food1": _food1_btn, "food2": _food2_btn, "inspect": _inspect_btn, "feed": _feed_btn,
		"equip": _equip_btn, "place": _place_btn, "store": _store_btn, "take": _take_btn, "drop": _drop_btn}

func _show_actions(valid: Array[String]) -> void:
	var btns := _action_buttons()
	for id: String in btns:
		(btns[id] as Button).visible = valid.has(id)

## Select a bag slot: brackets on the grid, the card fills, the valid actions show.
func _select(index: int) -> void:
	_disarm_destroy()
	_selected = index
	var none := inventory == null or index < 0 or index >= inventory.slot_count or inventory.slots[index] == null or inventory.slots[index].def_id == Inventory.LOCK
	if _grid:
		_grid.set_selected(index if not none else -1)
	_lock_btn.disabled = none
	_lock_btn.text = "Lock"
	_destroy_btn.disabled = true
	if none:
		_show_actions([])
		if _card:
			_card.hide_card()
		_tip.text = "Select mode: tap items to mark a batch." if (_grid != null and _grid.multi_mode) else "Tap an item."
		return
	var stack := inventory.slots[index]
	if stack.uid != "" and _new_uids.erase(stack.uid):
		_grid.new_uids = _new_uids
		var c := _grid.cell_for(index)
		if c:
			c.is_new = false
			c.queue_redraw()
	_tip.text = stack.tooltip().get_slice("\n", 0)
	_lock_btn.text = "Unlock" if stack.is_locked() else "Lock"
	_destroy_btn.disabled = not _can_remove_selected()
	_destroy_btn.tooltip_text = "Unlock this item before destroying it." if stack.is_locked() else "Permanently destroy this item. Requires a second tap."
	var valid := valid_actions(stack, {"where": "bag", "pet": _owner_player != null and _owner_player.summoned_pet != null,
		"deposit": _can_store_selected()})
	_show_actions(valid)
	_drop_btn.disabled = not _can_drop_selected()
	_drop_btn.tooltip_text = "Unlock this item before dropping it." if stack.is_locked() else "Drop this item in a loot bag."
	if BagCapacity.is_bag(stack.def_id) and not Food.is_food(stack):
		_inspect_btn.text = "Inspect bag"
	else:
		_inspect_btn.text = "Inspect"
	var d := stack.def()
	var slot := Inventory.slot_for(d)
	_equip_btn.text = "Equip %s" % (str(EQUIP_LABELS.get(str(slot), slot)) if slot != &"" else "tool")
	if _place_btn.visible:
		_place_btn.text = "Place %dx%d" % [maxi(1, d.footprint.x), maxi(1, d.footprint.y)]
	if _store_btn.visible:
		_store_btn.text = "Transfer to %s" % str(_storage_opts.get("title", "Storage"))
	_card.show_stack(stack)
	_layout_card()

## Select a slot of the open container: its card offers "Transfer to Bag" (disabled with the reason
## when the container is take-only for this player).
func _select_store(index: int) -> void:
	_store_sel = index
	var none := pet_bag == null or index < 0 or index >= pet_bag.slot_count or pet_bag.slots[index] == null or pet_bag.slots[index].def_id == Inventory.LOCK
	_pet_grid.set_selected(index if not none else -1)
	if none:
		_store_sel = -1
		_show_actions([])
		_card.hide_card()
		_tip.text = "Tap an item."
		return
	var stack := pet_bag.slots[index]
	_tip.text = stack.tooltip().get_slice("\n", 0)
	_show_actions(valid_actions(stack, {"where": "store"}))
	_take_btn.disabled = _readonly_reason() != "" or stack.is_locked()
	_take_btn.tooltip_text = _readonly_reason()
	_card.show_stack(stack, str(_storage_opts.get("title", "Storage")))
	_layout_card()

# ---------------------------------------------------------------- character page

func _refresh_character() -> void:
	if inventory == null or _char_page == null:
		return
	var nm := _owner_player.display_name() if _owner_player else (World.player_name if World.player_name != "" else "Survivor")
	var title := LevelDisplay.current_title(LevelDisplay.player_level())
	var clan := World.occupation.capitalize() if World.occupation != "" else "Survivor"
	_profile.text = "%s\n%s" % [nm, title]
	_profile.max_lines_visible = 2
	_portrait.texture = PlayerPortrait.texture_for({"own": true, "id": "self"}, self) if _owner_player else PlayerPortrait.silhouette()
	_level_label.text = "%s  ·  %s  ·  XP %d%%" % [LevelDisplay.player_label(), clan, roundi(World.pioneer_progress() * 100.0)]
	_xp_bar.value = World.pioneer_progress()
	var snap := InvStats.snapshot(_owner_player)
	var groups := InvStats.powers_data()
	var keys := ["combat", "crafting", "gathering"]
	for i in _power_rows.size():
		var g: Dictionary = groups.get(keys[i], {})
		_power_rows[i].text = "%s   %d" % [str(g.get("label", keys[i].capitalize())), int(snap.get(keys[i] + "_power", 0))]
	var mi := ["attack", "defense", "accuracy"]
	for i in _myinfo.size():
		var lab := str(InvStats.ROWS[i][1])
		_myinfo[i].text = "%s %s" % [lab, InvStats.fmt(mi[i], snap.get(mi[i], 0))] if not snap.is_empty() else "%s -" % lab
	var lines: PackedStringArray = []
	for r: Array in InvStats.ROWS:
		if snap.has(r[0]):
			lines.append("%s   %s" % [r[1], InvStats.fmt(str(r[0]), snap[r[0]])])
	_stats_label.text = "\n".join(lines) if not lines.is_empty() else "No survivor bound."
	_tab_style(_gear_tab, not _deco)
	_tab_style(_deco_tab, _deco)
	_equip_grid.visible = not _deco
	_deco_note.visible = _deco
	var lv := LevelDisplay.player_level()
	var active := GearPresets.active(inventory, lv)
	for k in _preset_btns.size():
		var b := _preset_btns[k]
		var open := k < GearPresets.unlocked_count(lv)
		b.disabled = not open
		b.text = str(k + 1) if open else LevelDisplay.label(GearPresets.unlock_level(k))
		b.tooltip_text = "Preset %d" % (k + 1) if open else "Preset %d unlocks at %s." % [k + 1, LevelDisplay.label(GearPresets.unlock_level(k))]
		_tab_style(b, open and k == active and not inventory.presets.is_empty())
	_refresh_equipped()

func _toggle_stats() -> void:
	_stats_scroll.visible = not _stats_scroll.visible
	_power_grid.visible = not _stats_scroll.visible
	_stats_btn.text = "Back" if _stats_scroll.visible else "Detailed Stats"

func _on_preset(k: int) -> void:
	if inventory == null:
		return
	var why := GearPresets.switch(inventory, k)
	_tip.text = why
	if why != "" and _owner_player:
		_owner_player.notice(why)
	_refresh_character()

## A worn slot's item (food slots show the first of the chosen food).
func _worn_in(slot: String) -> ItemStack:
	match slot:
		"weapon":
			return inventory.equipped_weapon()
		"tool":
			return inventory.equipped_gather_tool()
		"food1", "food2":
			var fid := str(inventory.quick_food[0 if slot == "food1" else 1])
			var idx := inventory.find_first(StringName(fid)) if fid != "" else -1
			return inventory.slots[idx] if idx >= 0 else null
	return inventory.equipped_in(StringName(slot))

## The worn slots: real art and Lv. when worn, a faded silhouette and the slot's name when empty,
## gold brackets (a gold frame) on the selected one.
func _refresh_equipped() -> void:
	for slot: String in _equip_slots.keys():
		var b: Button = _equip_slots[slot]
		var st := _worn_in(slot)
		var sb := UiTokens.slot_style(slot == _gear_sel)
		sb.bg_color = Color("#141810")
		if slot == _gear_sel:
			sb.border_color = GOLD
			sb.set_border_width_all(3)
		for k in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(k, sb)
		if st:
			b.icon = ItemIcons.texture(st.def_id)
			b.text = LevelDisplay.label(st.level) if st.level > 1 else ""
			b.tooltip_text = st.tooltip()
			b.self_modulate = Color.WHITE
		else:
			b.icon = ItemIcons.texture(SILHOUETTES.get(slot, &""))
			b.text = str(EQUIP_LABELS.get(slot, slot))
			b.tooltip_text = "%s: empty" % str(EQUIP_LABELS.get(slot, slot))
			b.self_modulate = Color(1, 1, 1, 0.35)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	var sel := _worn_in(_gear_sel) if _gear_sel != "" else null
	_gear_sel_label.text = "%s %s%s" % [sel.def().display_name if sel.def() else str(sel.def_id), LevelDisplay.label(sel.level),
		"  Dur %d/%d" % [sel.durability, sel.max_durability] if sel.max_durability > 0 else ""] if sel else "Tap a slot."
	_unequip_btn.visible = sel != null and _gear_sel not in ["food1", "food2", "tool"]

func _on_unequip_pressed() -> void:
	if inventory == null or _gear_sel == "":
		return
	if inventory.equipment.has(_gear_sel) and not inventory.unequip(StringName(_gear_sel)) and _owner_player:
		_owner_player.notice("Bag is full.") # the gear stays worn (W2-INV: never dropped)
	_refresh_character()

## Character page: a worn armour/weapon slot selects it (Unequip below); the tool slot cycles the
## held tool; a food slot eats its food (or clears the empty shortcut), as before.
func _on_equip_slot_pressed(slot: String) -> void:
	if inventory == null:
		return
	match slot:
		"tool":
			var tools := inventory.gather_tools_in_bag()
			if not tools.is_empty():
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
				return
			elif fid != "":
				inventory.set_quick_food(0 if slot == "food1" else 1, &"")
	_gear_sel = slot
	_refresh_character()

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

## Spec 31 §9/§11: one Inspect action opens the right panel; a bag shows its storage breakdown and
## the capacity change against the worn bag. Ordinary gear/food keeps the food inspector.
func _on_inspect() -> void:
	if inventory == null or _selected < 0 or _selected >= inventory.slot_count:
		return
	var stack := inventory.slots[_selected]
	if stack != null and BagCapacity.is_bag(stack.def_id):
		_on_inspect_bag()
		return
	_on_inspect_food()

func _on_inspect_bag() -> void:
	if inventory == null or _selected < 0:
		return
	var stack := inventory.slots[_selected]
	if stack == null or not BagCapacity.is_bag(stack.def_id):
		return
	print("[bags] inspect %s\n%s" % [stack.def_id, BagInspect.text_for(stack, inventory)])
	_bag_inspector.show_stack(stack, _selected, inventory)

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

## Drop preserves the exact selected instance in the world's persistent loot-bag format. Destroy is
## deliberately a two-tap action. A locked item refuses both, matching the inventory contract.
# ASSUMPTION: both actions apply to the whole selected slot; the current inventory has no quantity picker.
func _can_remove_selected() -> bool:
	if inventory == null or _selected < 0 or _selected >= inventory.slot_count:
		return false
	var stack := inventory.slots[_selected]
	if stack == null or stack.def_id == Inventory.LOCK or stack.is_locked():
		return false
	return _owner_player == null or _owner_player.actions == null or not _owner_player.actions.online

func _can_drop_selected() -> bool:
	return _can_remove_selected() and _owner_player != null and World.runtime != null

func _drop_selected() -> void:
	if not _can_drop_selected():
		return
	var index := _selected
	var source := inventory.slots[index]
	var count := source.count
	var id := source.def_id
	var item_name := source.def().display_name if source.def() else str(id).capitalize()
	_selected = -1
	_disarm_destroy()
	var dropped := inventory.remove_at(index, count)
	if dropped == null:
		return
	# ASSUMPTION: an inventory drop lands at the survivor's feet rather than being thrown.
	LootBag.drop(_owner_player.global_position, [dropped])
	_clear_empty_shortcuts(id)
	_owner_player.notice("Dropped %s." % item_name)
	print("[item] dropped %s x%d" % [id, count])

func _destroy_selected() -> void:
	if not _can_remove_selected():
		return
	if _destroy_armed_index != _selected:
		_destroy_armed_index = _selected
		_destroy_btn.text = "Destroy?"
		_destroy_btn.tooltip_text = "Tap again to permanently destroy this item."
		return
	var index := _selected
	var source := inventory.slots[index]
	var count := source.count
	var id := source.def_id
	var item_name := source.def().display_name if source.def() else str(id).capitalize()
	_selected = -1
	_disarm_destroy()
	if inventory.remove_at(index, count) == null:
		return
	_clear_empty_shortcuts(id)
	if _owner_player:
		_owner_player.notice("Destroyed %s." % item_name)
	print("[item] destroyed %s x%d" % [id, count])

func _disarm_destroy() -> void:
	_destroy_armed_index = -1
	if _destroy_btn:
		_destroy_btn.text = "Destroy"

func _clear_empty_shortcuts(id: StringName) -> void:
	if inventory == null or inventory.count_of(id) > 0:
		return
	for i in 2:
		if StringName(str(inventory.quick_food[i])) == id:
			inventory.set_quick_food(i, &"")

# ---------------------------------------------------------------- batch (Feature A)

## Owner 2026-10-27: mark several bag items at once, then Lock / Drop / Destroy them in one pass.
## Select mode is explicit (a header toggle) so the normal single-tap flow is untouched; every
## per-item rule holds — a batch action skips an item for exactly the reason the single action
## would refuse it, and the tip reports what was skipped and why.

func _on_toggle_multi() -> void:
	_set_multi_mode(_grid == null or not _active_grid().multi_mode)

## Mode swap: the batch bar replaces the item-action row, which is left unselected while Select
## mode is active (taps there mark, they don't pick). Done returns to the single-selection flow.
func _set_multi_mode(on: bool) -> void:
	if _grid == null or _batch_row == null:
		return
	if on:
		_active_grid().set_multi_mode(true)
	else:
		_grid.set_multi_mode(false)
		_pet_grid.set_multi_mode(false)
	_disarm_batch_destroy()
	_select_btn.text = "Done" if on else "Select"
	_batch_label.text = "0 selected"
	_update_toolbar()
	_update_batch_bar()
	if on:
		_select(-1)
		_tip.text = "Select mode: tap items to mark a batch."
	else:
		_select(_selected)

## The bar mirrors the grid's marks; the destroy button arms itself here and anywhere else the
## marks change (a second tap on the same marks is what confirms).
func _update_batch_bar() -> void:
	if _batch_row == null:
		return
	var on := _grid != null and _active_grid().multi_mode
	if not on:
		return
	var n := _active_grid().multi.size()
	_batch_label.text = "%d selected" % n
	_batch_take_btn.disabled = n == 0 or _readonly_reason() != ""
	_batch_store_btn.disabled = n == 0
	_batch_lock_btn.disabled = n == 0
	_batch_drop_btn.disabled = n == 0
	_batch_destroy_btn.disabled = n == 0
	if _batch_destroy_armed:
		_batch_destroy_btn.text = "Confirm destroy"
	else:
		_batch_destroy_btn.text = "Destroy"

func _disarm_batch_destroy() -> void:
	_batch_destroy_armed = false
	if _batch_destroy_btn:
		_batch_destroy_btn.text = "Destroy"

## The single-item call gates (_can_remove_selected / _can_drop_selected) as batch context:
## destroying and dropping are solo-camp actions, and a drop additionally needs the live world
## (the loot bag it lands in).
func _batch_gates() -> Array:
	var act: Variant = _owner_player.actions if _owner_player else null
	var offline: bool = act == null or not act.online
	return [offline, World.runtime != null] # the loot bag lands at the survivor, else at the origin

func _on_batch_lock() -> void:
	if inventory == null or _grid == null:
		return
	var gates := _batch_gates()
	var res := batch_check(inventory, _grid.multi_list(), "lock", bool(gates[0]), bool(gates[1]))
	for idx: int in res["ok"]:
		inventory.slots[idx].set_flag(&"locked", true)
	inventory.changed.emit()
	_finish_batch(res, "Locked")

func _on_batch_drop() -> void:
	if inventory == null or _grid == null:
		return
	var gates := _batch_gates()
	var res := batch_check(inventory, _grid.multi_list(), "drop", bool(gates[0]), bool(gates[1]))
	var pos: Vector3 = _owner_player.global_position if _owner_player else Vector3.ZERO
	var done := 0
	for idx: int in res["ok"]:
		var s: ItemStack = inventory.slots[idx]
		var dropped := inventory.remove_at(idx, s.count)
		if dropped == null:
			continue
		LootBag.drop(pos, [dropped])
		_clear_empty_shortcuts(dropped.def_id)
		done += 1
	if done > 0 and _owner_player:
		_owner_player.notice("Dropped %d item(s)." % done)
		_selected = -1
	_finish_batch(res, "Dropped", done)

func _on_batch_destroy() -> void:
	if inventory == null or _grid == null:
		return
	var gates := _batch_gates()
	# Re-checked at both taps, so only what is still there and still eligible is destroyed.
	var res := batch_check(inventory, _grid.multi_list(), "destroy", bool(gates[0]), bool(gates[1]))
	if not _batch_destroy_armed:
		_batch_destroy_armed = true
		_update_batch_bar()
		_tip.text = "Destroy %d item(s)? Tap Confirm again." % (res["ok"] as Array).size()
		return
	var done := 0
	var ids := {}
	for idx: int in res["ok"]:
		var s: ItemStack = inventory.slots[idx]
		var gone := inventory.remove_at(idx, s.count)
		if gone == null:
			continue
		ids[str(gone.def_id)] = true
		done += 1
	for id in ids.keys():
		_clear_empty_shortcuts(StringName(str(id)))
	if done > 0:
		_selected = -1
		if _owner_player:
			_owner_player.notice("Destroyed %d item(s)." % done)
	_finish_batch(res, "Destroyed", done)

## Batch Store: every marked, unlocked bag instance into the open container, in slot order;
## a full container leaves the rest in the bag (Inventory.transfer_to moves only what fits).
func _on_batch_store() -> void:
	if inventory == null or pet_bag == null or _readonly_reason() != "" or not bool(_storage_opts.get("allow_deposit", false)):
		return
	var res := batch_check(inventory, _grid.multi_list(), "lock", true, true) # lock's gate: not empty, not locked
	var done := 0
	for idx: int in res["ok"]:
		if idx == inventory.equipped_tool_index:
			continue
		if inventory.transfer_to(pet_bag, idx) > 0:
			done += 1
	if done < (res["ok"] as Array).size() and _owner_player:
		_owner_player.notice("Storage is full.")
	_finish_batch(res, "Stored", done)

## Batch take from the open container: each marked instance into the bag; what does not fit stays.
func _on_batch_take() -> void:
	if pet_bag == null or inventory == null or _readonly_reason() != "":
		return
	var marks := _pet_grid.multi_list()
	var done := 0
	for i in range(marks.size() - 1, -1, -1):
		var s := pet_bag.slots[marks[i]] if marks[i] < pet_bag.slot_count else null
		if s == null or s.is_locked():
			continue
		if pet_bag.transfer_to(inventory, marks[i]) > 0:
			done += 1
	_pet_grid.clear_multi()
	_tip.text = "Took %d item(s)." % done
	_update_batch_bar()
	_notify_storage_take()

## After a pass: release the marks, keep Select mode on for the next batch, and summarise what was
## skipped in the tip (or confirm the whole batch went through).
func _finish_batch(res: Dictionary, verb: String, done: int = -1) -> void:
	_disarm_batch_destroy()
	_grid.clear_multi()
	_update_batch_bar()
	var skip := res.get("skip", {}) as Dictionary
	var skipped := _skip_text(skip)
	if done == 0:
		_tip.text = "Nothing to %s: %s." % [verb.to_lower(), skipped]
	elif skipped == "":
		_tip.text = "%s %d item(s)." % [verb, done]
	else:
		_tip.text = "%s %d item(s); skipped %d (%s)." % [verb, done, skip.size(), skipped]

## "1 locked, 2 empty, 1 while online" — the skip reasons read like a sentence, most common first.
static func _skip_text(skip: Dictionary) -> String:
	var words := {"locked": "locked", "empty": "empty", "online": "while online", "world": "no world"}
	var parts: Array[String] = []
	for why in ["locked", "empty", "online", "world"]:
		var n := 0
		for k in skip.keys():
			if str(skip[k]) == why:
				n += 1
		if n > 0:
			parts.append("%d %s" % [n, words[why]])
	return ", ".join(parts)

## Batch eligibility in one place. It mirrors the single-item gates: empty slots and lock markers
## never join ("empty"), a locked item refuses everything until unlocked ("locked"), destroy is
## offline-only like the single action ("online" when refused) and a drop also needs the live world
## ("world"). Returns {"ok": ascending Array[int], "skip": {index: reason}} for the tip.
static func batch_check(inv: Inventory, indices: Array[int], action: String, offline: bool, world: bool) -> Dictionary:
	var ok: Array[int] = []
	var skip := {}
	for i in indices:
		var s: ItemStack = null
		if inv != null and i >= 0 and i < inv.slots.size():
			s = inv.slots[i]
		if s == null or s.def_id == Inventory.LOCK:
			skip[i] = "empty"
			continue
		if s.is_locked():
			skip[i] = "locked"
			continue
		if action != "lock":
			if not offline:
				skip[i] = "online"
				continue
			if action == "drop" and not world:
				skip[i] = "world"
				continue
		ok.append(i)
	return {"ok": ok, "skip": skip}

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
	# A take-only container (loot, a corpse) closes once emptied; a box or cargo you also store into stays.
	if pet_bag and pet_bag.used_slots() <= 0 and not bool(_storage_opts.get("allow_deposit", false)):
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
