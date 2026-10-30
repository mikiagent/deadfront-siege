class_name InventoryUI
extends Control
## The Bag family (owner spec 13), docked on the right over the live world (addendum 2):
## - Bag page (BAGUI, owner 2026-10-28, Durango reference): SheetChrome header ‹ Bag | Character,
##   "used / capacity" (warning colour when full) and the CurrencyBar, ✕ (capacity counts the worn backpack's slots: backpacks are the only source); a filter rail on the left; a scrolling grid of one instance per slot (BagGrid:
##   Lv., quality dots, NEW, rare corner, gold brackets); the bottom bar (Sort dropdown, Select,
##   Lock, Trash; Take all on a container's tab).
## - Opening it in the field plays the survivor's rummage clip (PlayerAnim.start_rummage); moving
##   closes it.
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
var _chrome: SheetChrome
var _root: VBoxContainer
## BAGUI: the filter rail (one 64 px tab per BagGrid.FILTERS id), the balances, the card's Use button.
var _rail: VBoxContainer
var _rail_btns: Dictionary = {}
var _currency: CurrencyBar
var _use_btn: Button
var _rummaging := false
var _use_id := ""
var _was_moving := true
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
var _sort_btn: OptionButton
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
## BAGUI eat queue: "Eat (n)" eats the marked foods one after another, in the order marked.
var _batch_eat_btn: Button
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
## C1 Character (character_sheet.gd): split out of this sheet; the Character tab opens it.
var _character: CharacterSheet
## ‹ on the Character sheet: the HUD reopens its MENU (hunt_hud.gd open_character connects it).
signal menu_requested

const TAP := 64.0
const EQUIP_LABELS := {"head": "Head", "body": "Body", "arms": "Arms", "legs": "Legs", "accessory1": "Ring", "accessory2": "Ring", "weapon": "Weapon", "tool": "Tool", "food1": "Food 1", "food2": "Food 2"}
const INK := Color(0.95, 0.95, 0.93)
const GOLD := Color("#E6BE54")
const PANEL := Color("#39392F")
## ASSUMPTION: the sheet takes 52% of the view (520-900 px, BAGUI: the Durango reference's right-hand
## bag), so the live world and the item card on its left keep room.
const SHEET_SHARE := 0.52
const SHEET_MIN_PX := 520.0
const SHEET_MAX_PX := 900.0
## The filter rail's icon per BagGrid filter (white UI icons; "action" is the sparkle for Rare).
const RAIL_ICONS := {"": &"bag", "materials": &"gathering", "food": &"eat", "gear": &"equip", "tools": &"tool_pick",
	"building": &"build", "rare": &"action", "locked": &"lock"}

func _ready() -> void:
	theme = SheetChrome.ui_theme() # Roboto Condensed for the whole bag family
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
	# Header (spec 13 s4, BAGUI): the shared chrome across the sheet's width.
	_chrome = SheetChrome.new("")
	_chrome.back_pressed.connect(func () -> void: hide_ui(); menu_requested.emit())
	_chrome.close_pressed.connect(hide_ui)
	_panel.add_child(_chrome)
	_close_btn = _chrome.close
	_close_btn.name = "CloseButton"
	_title = Label.new() # kept for callers that read the screen's title
	_title.visible = false
	_panel.add_child(_title)
	_bag_tab = _chrome.add_tab("Bag", true)
	_bag_tab.name = "BagTab"
	_bag_tab.pressed.connect(func () -> void: _show_page("bag", "bag"))
	_store_tab = _chrome.add_tab("", false)
	_store_tab.name = "StoreTab"
	_store_tab.pressed.connect(func () -> void: _show_page("bag", "store"))
	_char_tab = _chrome.add_tab("Character", false)
	_char_tab.name = "CharacterTab"
	_char_tab.pressed.connect(open_character)
	_cap_label = _chrome.counter
	_cap_label.name = "Capacity"
	_currency = CurrencyBar.new()
	_chrome.right.add_child(_currency)
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = 6
	_root.offset_right = -6
	_root.offset_bottom = -6
	_root.add_theme_constant_override("separation", 6)
	_panel.add_child(_root)
	_build_bag_page()
	_build_card()
	_character = CharacterSheet.new()
	_character.name = "CharacterSheet"
	add_child(_character)
	_character.bag_requested.connect(func () -> void: _show_page("bag", "bag"))
	_character.close_requested.connect(hide_ui)
	_character.back_requested.connect(func () -> void: hide_ui(); menu_requested.emit())
	_character.eat_requested.connect(func (idx: int) -> void:
		hide_ui()
		if _owner_player:
			_owner_player.begin_eat_slot(idx)
	)
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
	visibility_changed.connect(_on_visibility)
	resized.connect(_layout_safe)
	_layout_safe()
	rebuild()

func _build_bag_page() -> void:
	# Filter rail (BAGUI) beside the page; the page holds the grids, the tip and the bottom bar.
	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	_root.add_child(body)
	var rail_scroll := ScrollContainer.new()
	rail_scroll.name = "FilterRail"
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	rail_scroll.custom_minimum_size.x = TAP
	body.add_child(rail_scroll)
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 4)
	rail_scroll.add_child(_rail)
	for f: String in BagGrid.FILTERS:
		var rb := _btn(str(BagGrid.FILTER_LABELS[f]), Vector2(TAP, TAP))
		rb.name = "Filter_%s" % (f if f != "" else "all")
		rb.icon = UiIcons.icon(RAIL_ICONS.get(f, &"bag"))
		rb.expand_icon = false
		rb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rb.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		rb.clip_text = true
		rb.tooltip_text = str(BagGrid.FILTER_LABELS[f])
		rb.pressed.connect(_set_filter.bind(f))
		_rail.add_child(rb)
		_rail_btns[f] = rb
	_bag_page = VBoxContainer.new()
	_bag_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bag_page.add_theme_constant_override("separation", 6)
	body.add_child(_bag_page)
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
	# Bottom bar (spec 13 s9, BAGUI): the Sort dropdown, then Select, Lock and Trash.
	_toolbar = HBoxContainer.new()
	_toolbar.name = "Toolbar"
	_toolbar.add_theme_constant_override("separation", 6)
	_bag_page.add_child(_toolbar)
	_sort_btn = OptionButton.new()
	_sort_btn.name = "SortButton"
	_sort_btn.custom_minimum_size = Vector2(120, TAP)
	_sort_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sort_btn.focus_mode = Control.FOCUS_NONE
	_sort_btn.clip_text = true
	for k: String in BagGrid.SORTS:
		_sort_btn.add_item("Sort by %s" % str(BagGrid.SORT_LABELS[k]))
	_sort_btn.item_selected.connect(func (i: int) -> void: _set_sort(BagGrid.SORTS[i]))
	_toolbar.add_child(_sort_btn)
	_batch_label = Label.new()
	_batch_label.text = "0 selected"
	_batch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_batch_label.add_theme_color_override("font_color", INK)
	_batch_label.custom_minimum_size = Vector2(96, TAP)
	_batch_label.visible = false
	_toolbar.add_child(_batch_label)
	_select_btn = _btn("Select", Vector2(TAP, TAP))
	_select_btn.name = "SelectButton"
	_select_btn.pressed.connect(_on_toggle_multi)
	_toolbar.add_child(_select_btn)
	_lock_btn = _btn("Lock", Vector2(TAP, TAP))
	_lock_btn.name = "LockButton"
	_lock_btn.pressed.connect(_toggle_lock)
	_toolbar.add_child(_lock_btn)
	_destroy_btn = _btn("Trash", Vector2(TAP, TAP))
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
	_batch_lock_btn = _btn("Lock", Vector2(TAP, TAP))
	_batch_lock_btn.pressed.connect(_on_batch_lock)
	_toolbar.add_child(_batch_lock_btn)
	_batch_drop_btn = _btn("Drop", Vector2(TAP, TAP))
	_batch_drop_btn.pressed.connect(_on_batch_drop)
	_toolbar.add_child(_batch_drop_btn)
	_batch_destroy_btn = _btn("Trash", Vector2(TAP, TAP))
	_batch_destroy_btn.add_theme_color_override("font_color", UiTokens.DANGER)
	_batch_destroy_btn.pressed.connect(_on_batch_destroy)
	_toolbar.add_child(_batch_destroy_btn)
	_batch_eat_btn = _btn("Eat", Vector2(TAP, TAP))
	_batch_eat_btn.name = "BatchEatButton"
	_batch_eat_btn.pressed.connect(_on_batch_eat)
	_toolbar.add_child(_batch_eat_btn)
	_batch_store_btn = _btn("Deposit", Vector2(TAP, TAP))
	_batch_store_btn.name = "BatchStoreButton"
	_batch_store_btn.pressed.connect(_on_batch_store)
	_toolbar.add_child(_batch_store_btn)
	_batch_take_btn = _btn("Withdraw", Vector2(110, TAP))
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
	# The reference's big Use: the item's main action (use_action), under the smaller ones.
	_use_btn = SheetChrome.gold_button("Use")
	_use_btn.name = "UseButton"
	_use_btn.focus_mode = Control.FOCUS_NONE
	_use_btn.custom_minimum_size = Vector2(TAP, TAP)
	_use_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_use_btn.pressed.connect(_on_use)
	_card.use_row.add_child(_use_btn)
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

## A phone header has room for ‹, the tabs, the counter, two balances and ✕: the Character tab
## (also in the nav menu) and the gem "+" go, and with a container open the T-stone pill too.
func _fit_header(compact: bool) -> void:
	_char_tab.visible = not compact
	_currency.add_btn.visible = not compact
	_currency.show_stones(not (compact and pet_bag != null))
	_currency.refresh()

func _tab_style(b: Button, on: bool) -> void:
	SheetChrome.tab_style(b, on, UiTokens.is_compact(get_viewport_rect().size))

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
	if _character:
		_panel.visible = true # the next open (HUD BAG, I key) shows the bag, not the Character sheet
		_character.visible = false
	_set_multi_mode(false)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_ui()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- rummage (BAGUI)

## Open in the field: the survivor rummages (her clip, else idle); closed: back to idle. A move
## (stick, keys, a tap-to-walk route) closes the bag (_process).
func _on_visibility() -> void:
	var p := _owner_player
	if p == null or p.anim == null:
		return
	if is_visible_in_tree() and not _rummaging:
		_rummaging = p.anim.start_rummage()
	elif not is_visible_in_tree() and _rummaging:
		_rummaging = false
		p.anim.stop_rummage()

func _process(_dt: float) -> void:
	if not visible or _owner_player == null or _owner_player.sim == null:
		_was_moving = true # a move already under way when the bag opens does not close it
		return
	var moving := _owner_player.nav_active or _owner_player.sim.input_vector().length() > 0.2
	if moving and not _was_moving:
		hide_ui()
	_was_moving = moving

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

## C1: the Character sheet over the whole view (the bag hides while it shows). Public: the HUD's
## nav menu opens it through HuntHud.open_character().
func open_character() -> void:
	visible = true
	_show_page("character", _tab)

func _show_page(page: String, tab: String) -> void:
	_page = page
	_tab = tab if pet_bag != null else "bag"
	_set_multi_mode(false)
	_layout_safe()
	rebuild()

## The sheet: the Bag page docks on the right (the world and the item card on its left).
func _layout_safe() -> void:
	if _panel == null:
		return
	var r := get_viewport_rect().size
	var safe := UiTokens.safe_insets(get_viewport())
	var sheet := side_sheet_rect(r, safe)
	_panel.offset_left = sheet.position.x
	_panel.offset_top = sheet.position.y
	_panel.offset_right = sheet.end.x - r.x
	_panel.offset_bottom = sheet.end.y - r.y
	var compact := UiTokens.is_compact(r)
	var body := 14 if compact else UiTokens.body(r)
	for b: Button in _all_buttons():
		b.add_theme_font_size_override("font_size", body)
	for b: Button in _rail_btns.values():
		b.add_theme_font_size_override("font_size", UiTokens.TYPE_MIN)
		b.add_theme_constant_override("icon_max_width", 24 if compact else 28)
	for l: Label in [_tip, _storage_note]:
		if l:
			l.add_theme_font_size_override("font_size", body)
			l.add_theme_constant_override("line_spacing", 0) # the game theme's spacing made each line 29 px
	_currency.set_px(15 if compact else 20)
	# The chrome spans the sheet; the body sits under its torn edge.
	_fit_header(compact)
	_chrome.layout(sheet.size)
	_cap_label.add_theme_font_size_override("font_size", 18 if compact else 26)
	_root.offset_top = SheetChrome.body_top(r) - (6.0 if compact else 14.0)
	var grid_w := sheet.size.x - 12.0 - TAP - 6.0
	var cell := 64.0 if compact else clampf(floorf((grid_w - 6.0 * 7.0) / 7.0), 64.0, 104.0)
	_grid.cell_px = cell
	_pet_grid.cell_px = cell
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

## Where the item card sits: between the world's left edge and the docked bag (addendum 2), or over
## the bag's left half when the world strip is too narrow for it.
static func card_rect(view: Vector2, safe: Vector4 = Vector4.ZERO) -> Rect2:
	var sheet := side_sheet_rect(view, safe)
	var left := 12.0 + safe.w
	var free := sheet.position.x - 8.0 - left
	if free >= 220.0:
		return Rect2(Vector2(sheet.position.x - 8.0 - minf(free, 440.0), sheet.position.y), Vector2(minf(free, 440.0), sheet.size.y))
	return Rect2(sheet.position, Vector2(minf(sheet.size.x * 0.5, 320.0), sheet.size.y))

## Sizes the card to its content, never taller than its rect (its facts scroll inside).
func _layout_card() -> void:
	if _card == null:
		return
	var view := get_viewport_rect().size
	var r := card_rect(view, UiTokens.safe_insets(get_viewport()))
	_card.actions.columns = 2 if r.size.x < 320.0 else 3
	# A phone card keeps its facts readable: Use joins the small actions' grid instead of its own row.
	var host: Control = _card.actions if UiTokens.is_compact(view) else _card.use_row
	if _use_btn.get_parent() != host:
		_use_btn.reparent(host)
		host.move_child(_use_btn, 0)
	_card.position = r.position
	_card.custom_minimum_size = Vector2(r.size.x, 0)
	_card.fit(r.size.y)

func _all_buttons() -> Array[Button]:
	var out: Array[Button] = [_sort_btn, _select_btn, _lock_btn,
		_destroy_btn, _take_all_btn, _batch_lock_btn, _batch_drop_btn, _batch_destroy_btn,
		_batch_store_btn, _batch_take_btn, _batch_eat_btn, _equip_btn, _eat_btn, _inspect_btn, _food1_btn, _food2_btn, _feed_btn, _place_btn, _store_btn, _take_btn, _drop_btn]
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
	# A chest open (owner 2026-10-28): two tabs, each with its own used / capacity.
	_bag_tab.text = "Bag %d / %d" % [inventory.used_slots(), inventory.capacity()] if has_storage else "Bag"
	var on_bag := _page == "bag"
	_panel.visible = on_bag
	_character.visible = not on_bag
	_grid.visible = on_bag and _tab == "bag"
	_pet_grid.visible = on_bag and _tab == "store"
	_storage_note.text = _readonly_reason()
	_storage_note.visible = on_bag and _tab == "store" and _storage_note.text != ""
	_tab_style(_bag_tab, on_bag and _tab == "bag")
	_tab_style(_store_tab, on_bag and _tab == "store")
	_tab_style(_char_tab, not on_bag)
	if has_storage:
		_cap_label.text = "" # each tab carries its own used / capacity
	if _chrome.size.x > 0.0:
		_fit_header(UiTokens.is_compact(get_viewport_rect().size))
		_chrome.layout(_chrome.size) # the counter's width follows its text
	_take_all_btn.disabled = _readonly_reason() != "" or pet_bag == null or pet_bag.used_slots() <= 0
	_update_toolbar()
	if on_bag:
		if _tab == "store":
			_select_store(_store_sel)
		else:
			_select(_selected)
	else:
		_card.hide_card()
		_character.bind(inventory, _owner_player)
		_character.refresh()
	_update_batch_bar()

## Toolbar for the active tab: the bag's tools, or the container's Take all.
func _update_toolbar() -> void:
	var store := _tab == "store"
	var g := _active_grid()
	var multi := g != null and g.multi_mode
	_sort_btn.select(maxi(0, BagGrid.SORTS.find(g.sort_key)))
	_sort_btn.visible = not multi
	for f: String in _rail_btns:
		_rail_style(_rail_btns[f], f == g.filter_id)
	_select_btn.visible = true
	_lock_btn.visible = not store and not multi
	_destroy_btn.visible = not store and not multi
	_take_all_btn.visible = store and bool(_storage_opts.get("take_all", false))
	for b: Button in [_batch_lock_btn, _batch_drop_btn, _batch_destroy_btn]:
		b.visible = multi and not store
	_batch_store_btn.visible = multi and not store and pet_bag != null and bool(_storage_opts.get("allow_deposit", false)) and _readonly_reason() == ""
	_batch_take_btn.visible = multi and store
	_batch_eat_btn.visible = multi and not store and _owner_player != null and pet_bag == null # a chest open: Deposit
	_take_all_btn.visible = _take_all_btn.visible and not multi
	_batch_label.visible = false # the header counter reads "<n> Select" instead

func _active_grid() -> BagGrid:
	return _pet_grid if _tab == "store" and pet_bag != null else _grid

## Sort and filter change only the draw order of the active grid (BagGrid.view_order).
func _set_sort(key: String) -> void:
	var g := _active_grid()
	g.sort_key = key
	g.rebuild()
	_update_toolbar()

func _set_filter(f: String) -> void:
	var g := _active_grid()
	g.filter_id = f
	g.rebuild()
	_update_toolbar()

## A rail tab: GOLD ink and a GOLD left bar when its filter is on.
func _rail_style(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTokens.GOLD, 0.16) if on else Color(0, 0, 0, 0.25)
	sb.border_color = UiTokens.GOLD
	sb.border_width_left = 3 if on else 0
	sb.set_corner_radius_all(3)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 4
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var ink := UiTokens.GOLD if on else UiTokens.TEXT
	for c in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(c, ink)

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

## The card's big button: the item's main action among the valid ones (eat, equip, place), "" for
## an item that is only material (the button then shows Use, disabled).
static func use_action(valid: Array[String]) -> String:
	for a in ["eat", "equip", "place"]:
		if valid.has(a):
			return a
	return ""

const USE_LABELS := {"eat": "Use: Eat", "equip": "Use: Equip", "place": "Use: Place"}

func _on_use() -> void:
	var btn: Variant = _action_buttons().get(_use_id, null)
	if btn is Button and not (btn as Button).disabled:
		(btn as Button).pressed.emit()

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
	_inspect_btn.text = "Inspect bag" if BagCapacity.is_bag(stack.def_id) and not Food.is_food(stack) else "Inspect"
	var d := stack.def()
	var slot := Inventory.slot_for(d)
	_equip_btn.text = "Equip %s" % (str(EQUIP_LABELS.get(str(slot), slot)) if slot != &"" else "tool")
	if slot == &"" and inventory.equipped_tool_index == _selected:
		_equip_btn.text = "Unequip tool"
	if _place_btn.visible:
		_place_btn.text = "Place %dx%d" % [maxi(1, d.footprint.x), maxi(1, d.footprint.y)]
	if _store_btn.visible:
		_store_btn.text = "Transfer to %s" % str(_storage_opts.get("title", "Storage"))
	_card.show_stack(stack)
	# A chest open (owner 2026-10-28): the big button moves the item into it.
	_use_id = "store" if valid.has("store") else use_action(valid)
	_use_btn.disabled = _use_id == "" or (_action_buttons()[_use_id] as Button).disabled if _use_id != "" else true
	_use_btn.text = ("Transfer to %s" % str(_storage_opts.get("title", "Storage"))) if _use_id == "store" else str(USE_LABELS.get(_use_id, "Use"))
	_use_btn.visible = true
	if _use_id != "":
		(_action_buttons()[_use_id] as Button).visible = false # the big button is that action
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
	_use_btn.visible = false # a container's item is taken first, then used
	_card.show_stack(stack, str(_storage_opts.get("title", "Storage")))
	_layout_card()

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
		# The held tool's button unequips it (back to the best tool in the bag): the HUD's HANDS hex is gone.
		inventory.set_equipped_tool_index(-1 if inventory.equipped_tool_index == _selected else _selected)
	_select(_selected)

func _set_quick(i: int) -> void:
	if inventory == null or _selected < 0 or _selected >= inventory.slot_count:
		return
	var st := inventory.slots[_selected]
	if st == null or not Food.is_food(st):
		return
	inventory.set_quick_food(i, st.def_id)

## Spec 31 §9/§11: one Inspect action opens the right panel; a bag shows its storage breakdown and
## the capacity change against the worn bag. Food keeps the food inspector.
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
	var st := inventory.slots[_selected] if _selected < inventory.slot_count else null
	hide_ui()
	if not _owner_player.begin_eat_slot(_selected) and st != null:
		_owner_player.notice("Too full to eat." if Food.can_eat(_owner_player, st) == "full" else "You can't eat that now.") # never a silent no

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
		_destroy_btn.text = "Trash?"
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
		_destroy_btn.text = "Trash"

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
		if inventory and _cap_label.text.ends_with("Select"):
			_cap_label.text = "%d / %d" % [inventory.used_slots(), inventory.capacity()]
			_chrome.layout(_chrome.size)
		return
	var n := _active_grid().multi.size()
	_batch_label.text = "%d selected" % n
	var foods := _marked_foods().size()
	_batch_eat_btn.text = "Eat (%d)" % foods
	_batch_eat_btn.disabled = foods == 0
	_cap_label.text = "%d Select" % n # the header counts the marks while Select is on (reference)
	_chrome.layout(_chrome.size)
	_batch_take_btn.disabled = n == 0 or _readonly_reason() != ""
	_batch_store_btn.disabled = n == 0
	_batch_lock_btn.disabled = n == 0
	_batch_drop_btn.disabled = n == 0
	_batch_destroy_btn.disabled = n == 0
	if _batch_destroy_armed:
		_batch_destroy_btn.text = "Confirm"
	else:
		_batch_destroy_btn.text = "Trash"

func _disarm_batch_destroy() -> void:
	_batch_destroy_armed = false
	if _batch_destroy_btn:
		_batch_destroy_btn.text = "Trash"

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
	_finish_batch(res, "Deposited", done)

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

## The marked foods as exact instances, in the order they were marked.
func _marked_foods() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	if inventory == null or _grid == null:
		return out
	for i: int in _grid.multi_order():
		var s := inventory.slots[i] if i >= 0 and i < inventory.slot_count else null
		if s != null and Food.is_food(s) and not s.is_locked():
			out.append(s)
	return out

## Eat (n): close the bag and eat the marked foods in order through the normal eat flow (EatSession
## queue: each bite's own time; a move, a hit or a Full stomach stops it with a notice).
func _on_batch_eat() -> void:
	var foods := _marked_foods()
	if foods.is_empty() or _owner_player == null or _owner_player.eat_session == null:
		return
	hide_ui()
	if _owner_player.eat_session.begin_queue(foods) == 0:
		_owner_player.notice("Too full to eat." if Food.can_eat(_owner_player, foods[0]) == "full" else "Nothing to eat.")

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
