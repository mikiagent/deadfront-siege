class_name CraftUI
extends Control
## The one crafting menu, open from anywhere (Menu > Craft, the craft key, or a tap on a station).
## UICRAFT (docs/design/ui-redesign-spec.md §7 D1 / D3, §8 chrome): a full-screen sheet with the
## HEADER bar and torn edge, "Back · Craft / Build" and ✕. Three columns:
##   left   - station chooser (By hand / Workbench n m / Bonfire n m ...) over a category grid;
##   middle - search and the recipe list grouped by what it makes (Axe, Knife, Food ...);
##   right  - the recipe: parchment header, Max Level / Related Skill / Station / Time · Success ·
##            Flawless, the materials with have / need, Craft (GOLD) and Craft ×5 pinned at the bottom.
## "Materials · Place materials" opens D3 (CraftPlace): choose which instance leads each slot, then Craft.
## Choosing Craft closes the menu and crafts it like gathering: the survivor walks to the station if
## needed, the hex over it fills once per item, the item lands in the bag (StationCraft). Every number
## comes from Crafting (the same functions the craft rolls with); no crafting rule lives here.
## Phone landscape keeps the three columns at phone type sizes; a portrait phone shows one pane.

## [station id, name, symbol icon id]. Symbols are white (HexButton.symbol); system emoji drew in colour.
## Campfire and crock pot have their own symbols: their kit icons alias the bonfire and grill ones.
const STATIONS := [
	["", "By hand", "hands"], ["workbench", "Workbench", "workbench_kit"], ["bonfire", "Bonfire", "bonfire_kit"],
	["campfire", "Campfire", "skewer"], ["drying_rack", "Meat dryer", "drying_rack_kit"],
	["crock_pot", "Crock pot", "boiled_meat"], ["mortar", "Mortar", "mortar_kit"],
	["stone_grill", "Stone grill", "stone_grill_kit"], ["steamer", "Steamer", "steamer_kit"], ["well", "Well", "well_kit"],
	["forge", "Forge", "ingot"], ["anvil", "Anvil", "hammer"],
]
## The category grid: [recipe skill ("" = all), label, symbol ids]. The skills are recipes.json's own
## `skill` values. # ASSUMPTION: the canvas's Rest / Shelter and Taming tiles have no recipe skill
## behind them, so the grid shows the six skills the data has (spec: don't invent categories).
const CATEGORIES := [
	["", "All", ["stone_knife", "hammer"]],
	["processing", "Material Processing", ["plank", "ingot"]],
	["cooking", "Cooking", ["grilled_meat"]],
	["tailoring", "Clothing", ["cloth", "dried_hide"]],
	["weapon_tools", "Weapons & Tools", ["stone_knife"]],
	["construction", "Structures", ["workbench_kit"]],
	["farming", "Farming", ["berry_seed"]],
]
const NO_LEVEL := LevelDisplay.NONE
const FOOTER_H := 64.0
const TAP := 64.0  ## every control a finger presses (owner rule: 64 px or more)

var player: Player
var _station: String = ""
var _category: String = ""
var _selected_id: String = ""
var _query: String = ""
var _phone_detail := false  ## portrait phone: the detail pane is up instead of the list
var _refresh_left: float = 0.0

var _header: SheetChrome
var _title: Label
var _subtitle: Label
var _hint: Label
var _back_btn: Button
var _build_btn: Button
var _close_btn: Button
var _body: HBoxContainer
var _left: VBoxContainer
var _mid: VBoxContainer
var _right: VBoxContainer
var _tabs: HBoxContainer  ## the station chooser row
var _cats: GridContainer
var _search: LineEdit
var _list: VBoxContainer
var _detail: VBoxContainer
var _footer: HBoxContainer
var _place: CraftPlace

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40  # above the HUD, which is added to the same UI layer after this menu
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = UiTokens.ui_face()
	theme = th
	add_child(SheetChrome.backdrop())
	_header = SheetChrome.new("Craft / Build")
	_header.name = "CraftHeader"
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.back_pressed.connect(_on_back)
	_header.close_pressed.connect(hide_ui)
	add_child(_header)
	_back_btn = _header.back
	_back_btn.name = "CraftBack"
	_title = _header.title
	_title.name = "CraftTitle"
	_subtitle = Label.new()
	_subtitle.name = "CraftSubtitle"
	_subtitle.add_theme_color_override("font_color", UiTokens.MUTED)
	_header.add_child(_subtitle)
	_hint = Label.new()
	_hint.name = "CraftHint"
	_hint.add_theme_color_override("font_color", UiTokens.MUTED)
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header.add_child(_hint)
	# Spec 30 §2: Build (blueprints, construction) is the other half of "Craft / Build".
	_build_btn = mk_btn("Build", _open_build, Vector2(120, TAP), "ghost")
	_build_btn.name = "BuildRow"
	_build_btn.icon = HexButton.symbol(["hammer", "workbench_kit"])
	_build_btn.expand_icon = true
	_build_btn.add_theme_constant_override("icon_max_width", 26)
	_build_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header.right.add_child(_build_btn)
	_close_btn = _header.close
	_close_btn.name = "CraftClose"
	_body = HBoxContainer.new()
	_body.name = "CraftBody"
	add_child(_body)
	_build_left()
	_build_mid()
	_build_right()
	_place = CraftPlace.new()
	_place.name = "CraftPlace"
	_place.host = self
	_place.visible = false
	add_child(_place)
	resized.connect(_layout_safe)
	if get_viewport():
		get_viewport().size_changed.connect(_layout_safe)
	_layout_safe()
	if Game.shot_path.contains("craft"):
		get_tree().create_timer(0.9).timeout.connect(func () -> void: show_for_station(&"bonfire"))

func _build_left() -> void:
	_left = VBoxContainer.new()
	_left.name = "CraftLeft"
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.size_flags_stretch_ratio = 1.0
	_left.add_theme_constant_override("separation", 12)
	_body.add_child(_left)
	var tab_scroll := ScrollContainer.new()
	tab_scroll.name = "StationScroll"
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_left.add_child(tab_scroll)
	_tabs = HBoxContainer.new()
	_tabs.name = "StationRow"
	_tabs.add_theme_constant_override("separation", 6)
	tab_scroll.add_child(_tabs)
	var cat_scroll := ScrollContainer.new()
	cat_scroll.name = "CategoryScroll"
	cat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_scroll.add_theme_stylebox_override("panel", flat(UiTokens.PANEL, Color(1, 1, 1, 0.06), 1))
	_left.add_child(cat_scroll)
	_cats = GridContainer.new()
	_cats.name = "CategoryGrid"
	_cats.columns = 2
	_cats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cats.add_theme_constant_override("h_separation", 1)
	_cats.add_theme_constant_override("v_separation", 1)
	cat_scroll.add_child(_cats)

func _build_mid() -> void:
	_mid = VBoxContainer.new()
	_mid.name = "CraftMid"
	_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mid.size_flags_stretch_ratio = 1.36
	_mid.add_theme_constant_override("separation", 0)
	_body.add_child(_mid)
	var search_pad := PanelContainer.new()
	search_pad.name = "SearchPad"
	search_pad.add_theme_stylebox_override("panel", pad(UiTokens.PANEL, 14, 14, 12, 12))
	_mid.add_child(search_pad)
	_search = LineEdit.new()
	_search.name = "CraftSearch"
	_search.placeholder_text = "Search"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(0, TAP)
	_search.add_theme_stylebox_override("normal", pad(Color(0.10, 0.17, 0.23, 1.0), 16, 16, 0, 0))
	_search.add_theme_stylebox_override("focus", pad(Color(0.12, 0.20, 0.27, 1.0), 16, 16, 0, 0))
	_search.add_theme_color_override("font_placeholder_color", UiTokens.MUTED)
	_search.text_changed.connect(func (t: String) -> void:
		_query = t.strip_edges().to_lower()
		_refresh_list())
	search_pad.add_child(_search)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "RecipeScroll"
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.add_theme_stylebox_override("panel", flat(UiTokens.PANEL))
	_mid.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.name = "RecipeList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	list_scroll.add_child(_list)

func _build_right() -> void:
	_right = VBoxContainer.new()
	_right.name = "CraftRight"
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_stretch_ratio = 1.03
	_right.add_theme_constant_override("separation", 0)
	_body.add_child(_right)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.add_theme_stylebox_override("panel", flat(UiTokens.PANEL))
	_right.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 0)
	detail_scroll.add_child(_detail)
	var foot_pad := PanelContainer.new()
	foot_pad.name = "FooterPad"
	foot_pad.add_theme_stylebox_override("panel", pad(UiTokens.PANEL, 18, 18, 12, 18))
	_right.add_child(foot_pad)
	_footer = HBoxContainer.new()
	_footer.name = "CraftFooter"
	_footer.add_theme_constant_override("separation", 10)
	_footer.custom_minimum_size = Vector2(0, FOOTER_H)
	foot_pad.add_child(_footer)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _place.visible:
			close_place()
		else:
			hide_ui()
		get_viewport().set_input_as_handled()

func bind(p: Player) -> void:
	player = p
	if not player.inventory.changed.is_connected(_on_inventory_changed):
		player.inventory.changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	if visible:
		rebuild()

func toggle() -> void:
	if visible:
		hide_ui()
	else:
		show_ui()

func show_ui() -> void:
	visible = true
	_phone_detail = false
	_place.visible = false
	_body.visible = true
	_layout_safe()
	rebuild()
	UiTokens.focus_first(_list.find_children("*", "Button", true, false))

## A station tap lands on that station's group.
func show_for_station(sid: StringName) -> void:
	_station = str(sid)
	show_ui()

func hide_ui() -> void:
	visible = false
	_place.visible = false
	_body.visible = true

## Back in the header: D3 back to the recipe, a portrait detail back to the list, else back to the
## MENU sheet (spec §8: Back returns to the MENU, ✕ to the HUD).
func _on_back() -> void:
	if _place.visible:
		close_place()
	elif _phone_detail:
		_back_to_list()
	else:
		hide_ui()
		if is_inside_tree():
			SheetChrome.back_to_menu(get_tree())

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:  # distances change as the survivor walks
		_refresh_left = 0.5
		if not _place.visible:
			_refresh_tabs()

# ---------------------------------------------------------------- build

func rebuild() -> void:
	if player == null:
		return
	if _place.visible:
		_place.rebuild()
		return
	_refresh_tabs()
	_refresh_cats()
	_refresh_list()

func _refresh_tabs() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)  # detach first: focus_first and finds must not see rows about to go
		c.queue_free()
	var compact := _compact()
	var view := get_viewport_rect().size
	for row in STATIONS:
		var sid: String = row[0]
		var info := _station_info(sid)
		var status := ""
		if sid == "":
			status = "anywhere"
		elif info["near"]:
			status = "here"
		elif info["exists"]:
			status = "%d m away" % int(info["dist"])
		else:
			status = "none built"
		var chosen := sid == _station
		var b := Button.new()
		b.name = "Station_" + (sid if sid != "" else "hand")
		b.custom_minimum_size = Vector2(104 if compact else 142, TAP if compact else 92)
		style_cell(b, chosen)
		if chosen:  # the canvas draws the chosen station with a full gold rim, not brackets
			for k in ["normal", "hover", "pressed"]:
				var sb := b.get_theme_stylebox(k) as StyleBoxFlat
				sb.border_color = UiTokens.GOLD
				sb.set_border_width_all(2)
		b.pressed.connect(_pick_station.bind(sid))
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", -2)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(box)
		var nm := _label(row[1], UiTokens.body(view) + (0 if compact else 4), UiTokens.GOLD if chosen else UiTokens.TEXT)
		nm.name = "StationName"
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nm)
		var st := _label(status, UiTokens.TYPE_MIN, UiTokens.MUTED if info["exists"] else Color(0.6, 0.45, 0.4))
		st.name = "StationStatus"
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(st)
		_tabs.add_child(b)

func _refresh_cats() -> void:
	for c in _cats.get_children():
		_cats.remove_child(c)
		c.queue_free()
	var recipes := Crafting.recipes_for_station(StringName(_station))
	var compact := _compact()
	for row in CATEGORIES:
		var skill: String = row[0]
		var n := 0
		for rec in recipes:
			if skill == "" or str(rec.get("skill", "")) == skill:
				n += 1
		var cell := _CategoryCell.new()
		cell.name = "Cat_" + (skill if skill != "" else "all")
		cell.title = row[1]
		cell.icon_tex = HexButton.symbol(row[2])
		cell.chosen = skill == _category
		cell.empty = n == 0
		cell.font_px = UiTokens.body(get_viewport_rect().size) + (0 if compact else 8)
		cell.custom_minimum_size = Vector2(0, TAP if compact else 150)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.pressed.connect(_pick_category.bind(skill))
		_cats.add_child(cell)

## The Build menu is created on first press, so the craft sheet works before anything is built.
func _open_build() -> void:
	hide_ui()
	var ui := BuildUI.ensure(player)
	if ui:
		ui.open()

func _pick_station(sid: String) -> void:
	_station = sid
	_phone_detail = false
	rebuild()

func _pick_category(skill: String) -> void:
	_category = skill
	_phone_detail = false
	_refresh_cats()
	_refresh_list()

static func recipe_count(n: int) -> String:
	return "%d recipe%s" % [n, "" if n == 1 else "s"]

## Portrait phone: one pane at a time (stations + recipes, or the detail).
func _single_pane() -> bool:
	return UiTokens.is_narrow(get_viewport_rect().size)

## Phone type sizes and tighter columns, either way up.
func _compact() -> bool:
	return UiTokens.is_compact(get_viewport_rect().size)

## The recipes the list shows: the station's, narrowed by category and search.
func _shown_recipes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec in Crafting.recipes_for_station(StringName(_station)):
		if _category != "" and str(rec.get("skill", "")) != _category:
			continue
		if _query != "" and not _output_name(rec).to_lower().contains(_query):
			continue
		out.append(rec)
	return out

## The list's group heading for a recipe: what it makes. A tool class (Axe, Knife, Pick) when the
## output has one, else the output's first item category (Food, Armor Body, Building).
static func group_of(rec: Dictionary) -> String:
	var out_def := Data.item(StringName(str((rec.get("output", {}) as Dictionary).get("id", ""))))
	if out_def == null:
		return "Other"
	if out_def.tool_class != &"" and out_def.tool_class != &"none":
		return LevelDisplay.nice_name(str(out_def.tool_class))
	if not out_def.categories.is_empty():
		return LevelDisplay.nice_name(str(out_def.categories[0]))
	return "Other"

func _refresh_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var info := _station_info(_station)
	_hint.text = _hint_text(station_name(_station), info)
	var recipes := _shown_recipes()
	if recipes.is_empty():
		var l := _label("No recipes here yet." if _query == "" else "No recipe matches \"%s\"." % _query, UiTokens.body(get_viewport_rect().size), UiTokens.MUTED)
		l.custom_minimum_size = Vector2(0, TAP)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_list.add_child(l)
		_selected_id = ""
		_show_detail(info)
		return
	var found := false
	for rec in recipes:
		if str(rec.get("id", "")) == _selected_id:
			found = true
	if not found:
		_selected_id = str(recipes[0].get("id", ""))
	var groups: Dictionary = {}
	for rec in recipes:
		var g := group_of(rec)
		if not groups.has(g):
			groups[g] = []
		(groups[g] as Array).append(rec)
	var names := groups.keys()
	names.sort()
	var compact := _compact()
	for g in names:
		var head := _label(str(g), UiTokens.body(get_viewport_rect().size) + (0 if compact else 4), UiTokens.TEXT)
		head.name = "Group_" + str(g)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.custom_minimum_size = Vector2(0, 30 if compact else 44)
		head.add_theme_stylebox_override("normal", flat(Color(0.03, 0.07, 0.10, 0.9)))
		_list.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 1)
		grid.add_theme_constant_override("v_separation", 1)
		_list.add_child(grid)
		for rec in groups[g]:
			grid.add_child(_recipe_row(rec, info))
	_show_detail(info)

func _hint_text(name: String, info: Dictionary) -> String:
	if _station == "":
		return "Hand recipes craft anywhere."
	var ps := ProcessStation.of(info.get("node", null)) if info["near"] else null
	if ps != null and ps.capacity() > 0:
		# Spec 30 §13: the station's own job queue, so a queued job is visible where it was started.
		return "%s · %d/%d jobs, %d ready · %s" % [name, ps.running_count(), ps.capacity(), ps.ready_count(), ps.time_left_text() if ps.time_left_text() != "" else "queue free"]
	if info["near"]:
		return "%s in reach." % name
	if info["exists"]:
		return "Nearest %s %d m away: a craft walks there first." % [name.to_lower(), int(info["dist"])]
	return "No %s built yet: craft its kit by hand, place it from Build." % name.to_lower()

## Why a recipe cannot start now ("" = it can).
func _block_reason(rec: Dictionary, info: Dictionary) -> String:
	var blocked := Crafting.progression_block(player, rec)
	if blocked != "":
		return "Locked"
	# Spec 30 §10-11: a station's tags and its level gate the recipe, and the row says which.
	if _station != "":
		var st: Variant = info.get("node", null)
		if st is CraftStation:
			var gate := CraftStation.station_gate(rec, (st as CraftStation).station_tags, (st as CraftStation).station_level, StringName(_station))
			if gate != "":
				return gate + "  " + str(rec.get("id", "")).replace("_", " ").capitalize()
	if not Crafting.picks_valid(player.inventory, rec, Crafting.default_picks(player.inventory, rec)):
		return "Missing items"
	if _station != "" and not info["exists"]:
		return "No station"
	return ""

## One cell per recipe: icon, name, level · time. Tap selects it; gold brackets mark the selection.
## Button > HBox > VBox > RecipeMeta (ui_real_capture_lab walks up from the meta to the button).
func _recipe_row(rec: Dictionary, info: Dictionary) -> Control:
	var reason := _block_reason(rec, info)
	var can := reason == ""
	var chosen := str(rec.get("id", "")) == _selected_id
	var view := get_viewport_rect().size
	var compact := _compact()
	var row := Button.new()
	row.name = "Recipe_" + str(rec.get("id", ""))
	row.custom_minimum_size = Vector2(0, TAP if compact else 92)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_cell(row, chosen)
	row.pressed.connect(_choose_recipe.bind(str(rec.get("id", ""))))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10 if compact else 18
	h.offset_right = -8
	h.add_theme_constant_override("separation", 8 if compact else 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var out_row: Dictionary = rec.get("output", {})
	var out_icon := TextureRect.new()
	out_icon.texture = ItemIcons.texture(StringName(str(out_row.get("id", ""))))
	out_icon.custom_minimum_size = Vector2(34, 34) if compact else Vector2(52, 52)
	out_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	out_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	out_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	out_icon.modulate = Color.WHITE if can else Color(0.55, 0.55, 0.55, 0.8)
	out_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(out_icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(text)
	var col := UiTokens.GOLD if chosen else (UiTokens.TEXT if can else UiTokens.MUTED)
	var name := _label(_output_name(rec), UiTokens.body(view) + (0 if compact else 4), col)
	name.name = "RecipeName"
	text.add_child(name)
	var meta := _label("%s · %s%s" % [LevelDisplay.recipe_label(player.inventory, rec), Crafting.preview_time(rec), ("  ·  " + reason) if reason != "" else ""], UiTokens.TYPE_MIN, UiTokens.MUTED if can else Color(0.86, 0.55, 0.45))
	meta.name = "RecipeMeta"
	text.add_child(meta)
	if chosen:
		row.add_child(SheetChrome.Brackets.new())
	return row

func _output_name(rec: Dictionary) -> String:
	var out_row: Dictionary = rec.get("output", {})
	var out_def := Data.item(StringName(str(out_row.get("id", ""))))
	if out_def and out_def.display_name != "":
		return out_def.display_name
	return str(rec.get("display_name", rec.get("id", "?"))).replace("_", " ").capitalize()

## Per recipe slot: {category, need, have, sample_id, name}. The same numbers the old row showed.
func slot_rows(rec: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var picks := Crafting.default_picks(player.inventory, rec)
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		if not slots[i] is Dictionary:
			continue
		var slot: Dictionary = slots[i]
		var cat := StringName(str(slot.get("category", "")))
		var need := int(slot.get("count", 1))
		var have := 0
		for idx in player.inventory.find_by_category(cat):
			var s := player.inventory.slots[idx]
			if s and Crafting._allowed(slot, s):
				have += s.count
		var sample_id := StringName(str(cat))
		if i < picks.size() and picks[i] >= 0 and player.inventory.slots[picks[i]]:
			sample_id = player.inventory.slots[picks[i]].def_id
		else:
			sample_id = Crafting.sample_def_for_category(player.inventory, cat)
		var d := Data.item(sample_id)
		var nm := d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(cat))
		out.append({"category": cat, "need": need, "have": have, "sample_id": sample_id, "name": nm})
	return out

func _choose_recipe(rid: String) -> void:
	_selected_id = rid
	_phone_detail = _single_pane()
	rebuild()
	_apply_phone_pane()

func _back_to_list() -> void:
	_phone_detail = false
	_apply_phone_pane()

## Portrait phone: the list pane (stations + recipes) or the detail pane. Otherwise all three.
func _apply_phone_pane() -> void:
	var single := _single_pane()
	_left.visible = not single
	_mid.visible = not single or not _phone_detail
	_right.visible = not single or _phone_detail
	var stations := _tabs.get_parent()
	if single and stations.get_parent() != _mid:
		stations.reparent(_mid)
		_mid.move_child(stations, 0)
	elif not single and stations.get_parent() != _left:
		stations.reparent(_left)
		_left.move_child(stations, 0)

func _start(rec: Dictionary, count: int) -> void:
	start_with(rec, count, [])

## Crafts `count` of `rec`; `uids` (one per recipe slot, from D3) name the instance that leads each
## slot, empty = the default picks.
func start_with(rec: Dictionary, count: int, uids: Array[String]) -> void:
	hide_ui()
	if player and player.has_method("craft_recipe"):
		player.craft_recipe(StringName(str(rec.get("id", ""))), count, uids)

## {exists, near, dist} for a station kind, from the survivor's position.
func _station_info(sid: String) -> Dictionary:
	if sid == "" or player == null:
		return {"exists": true, "near": true, "dist": 0.0}
	var n := Crafting.nearest_station(player, StringName(sid))
	if n == null:
		return {"exists": false, "near": false, "dist": 0.0, "node": null}
	var d := player.global_position.distance_to(n.global_position)
	return {"exists": true, "near": d <= Crafting.STATION_RANGE + 0.35, "dist": d, "node": n}

func station_name(sid: String) -> String:
	for row in STATIONS:
		if row[0] == sid:
			return row[1]
	return LevelDisplay.nice_name(sid)

func _show_detail(info: Dictionary) -> void:
	if _detail == null:
		return
	# Detach before freeing: a queued sibling still holds "CraftOne", so the new button got renamed.
	for pane in [_detail, _footer]:
		for c in pane.get_children():
			pane.remove_child(c)
			c.queue_free()
	var view := get_viewport_rect().size
	var compact := _compact()
	var rec := _selected_recipe()
	if rec.is_empty():
		var empty := _label("Select a recipe.", UiTokens.body(view), UiTokens.MUTED)
		empty.custom_minimum_size = Vector2(0, TAP)
		_detail.add_child(_padded(empty))
		return
	var out_row: Dictionary = rec.get("output", {})
	var out_def := Data.item(StringName(str(out_row.get("id", ""))))
	# Parchment header (§8: detail panels open with one).
	var head := _label("★  " + _output_name(rec), UiTokens.heading(view) + (0 if compact else 4), UiTokens.PARCHMENT_INK)
	head.name = "DetailHead"
	head.custom_minimum_size = Vector2(0, 44 if compact else 72)
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	head.add_theme_stylebox_override("normal", _parchment())
	_detail.add_child(head)
	var title := _label("%s  ·  %s  ·  makes %d" % [LevelDisplay.recipe_label(player.inventory, rec), Crafting.preview_time(rec), int(out_row.get("count", 1))], UiTokens.body(view) + (0 if compact else 2), UiTokens.TEXT)
	title.name = "DetailTitle"
	_detail.add_child(_padded(title, 6 if compact else 14))
	var stats := LevelDisplay.stat_lines(out_def)
	if not stats.is_empty():
		var st := _label("  ·  ".join(stats), UiTokens.meta(view), UiTokens.MUTED)
		st.name = "DetailStats"
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		st.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		st.clip_text = false
		_detail.add_child(_padded(st, 0))
	_detail.add_child(_rule())
	# CRAFTFEEL (plan §3.3, specs 04/25 §8): the odds from Crafting's own functions, the ones the craft rolls.
	var picks := Crafting.default_picks(player.inventory, rec)
	var primary: ItemStack = null
	if picks.size() > Crafting.primary_index(rec) and picks[Crafting.primary_index(rec)] >= 0:
		primary = player.inventory.slots[picks[Crafting.primary_index(rec)]]
	var qual := Crafting.preview_quality(rec, player, primary)
	_kv("Max Level", LevelDisplay.label(int(rec.get("max_level", 60))), UiTokens.GOLD)
	_kv("Related Skill", LevelDisplay.nice_name(str(rec.get("skill", ""))), UiTokens.GOLD)
	_kv("Station", station_name(Crafting.station_id(rec)), UiTokens.GOLD)
	_kv("Time · Success · Flawless", "%s · %d%% · %d%%" % [Crafting.preview_time(rec), int(round(float(qual["success"]) * 100.0)), int(round(float(qual["flawless"]) * 100.0))], UiTokens.TEXT).name = "DetailOdds"
	# W2-SKILLS: a recipe a skill node gates is listed but locked (spec 03): say what unlocks it,
	# above the materials so a phone shows it without scrolling.
	var locked := Crafting.progression_block(player, rec)
	if locked != "":
		var why := _label(locked.left(1).to_upper() + locked.substr(1), UiTokens.body(view), UiTokens.DANGER)
		why.name = "DetailLock"
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		why.clip_text = false
		_detail.add_child(_padded(why, 8))
	# Materials: the bar opens D3 (place materials) for this recipe when the bag can make it.
	var missing := Crafting.missing_ingredient_name(player.inventory, rec)
	var mat := mk_btn("Materials" if missing != "" else "Materials      ·  Place materials", open_place.bind(str(rec.get("id", ""))), Vector2(0, TAP), "bar")
	mat.name = "DetailMaterialsHead"
	mat.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mat.disabled = missing != ""
	mat.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 4))
	_detail.add_child(mat)
	for row in slot_rows(rec):
		_detail.add_child(_material_row(row))
	if missing != "":
		var lock := _label("Needs %s" % LevelDisplay.nice_name(missing), UiTokens.body(view), UiTokens.DANGER)
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		lock.clip_text = false
		_detail.add_child(_padded(lock, 8))
	elif _station != "" and not bool(info.get("exists", false)):
		var lock := _label("Station not built. The recipe stays listed.", UiTokens.body(view), UiTokens.DANGER)
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		lock.clip_text = false
		_detail.add_child(_padded(lock, 8))
	var odds := _label(craftfeel_text(qual), UiTokens.meta(view), UiTokens.MUTED if float(qual["success"]) >= 0.999 else Color(0.95, 0.85, 0.5))
	odds.name = "DetailChance"
	odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	odds.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	odds.clip_text = false
	_detail.add_child(_padded(odds, 10))
	# Spec 31 §10: a bag preview built by the same function the craft uses (Crafting.bag_preview).
	var prev := Crafting.bag_preview(player.inventory, rec, picks, player)
	if not prev.is_empty():
		var bl := _label("BAG PREVIEW\n" + _bag_preview_text(prev), UiTokens.meta(view), UiTokens.TEXT)
		bl.name = "DetailBagPreview"
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		bl.clip_text = false
		_detail.add_child(_padded(bl, 8))
	# Craft (GOLD CTA) and Craft ×5, pinned under the scroll so they are never below the fold.
	var can := _block_reason(rec, info) == ""
	var walk := _station != "" and not bool(info.get("near", false))
	var one := mk_btn("Walk & craft" if walk else "Craft", _start.bind(rec, 1), Vector2(110, FOOTER_H if compact else 76), "cta")
	one.name = "CraftOne"
	one.disabled = not can
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	one.size_flags_stretch_ratio = 1.6
	if compact:
		one.add_theme_font_size_override("font_size", 20)
	_footer.add_child(one)
	var five := mk_btn("Craft ×5", _start.bind(rec, 5), Vector2(100, FOOTER_H if compact else 76), "ghost")
	five.name = "CraftFive"
	five.disabled = not can
	five.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if compact:
		five.add_theme_font_size_override("font_size", 18)
	_footer.add_child(five)

func _kv(key: String, value: String, value_col: Color) -> Label:
	var view := get_viewport_rect().size
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24 if _compact() else 34)
	var k := _label(key, UiTokens.body(view) + (0 if _compact() else 2), UiTokens.MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := _label(value, UiTokens.body(view) + (0 if _compact() else 2), value_col)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.clip_text = false
	v.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.add_child(v)
	_detail.add_child(_padded(row, 0))
	return v

## One material line: ✓ (OK_GREEN) or ✕, icon, name, have / need (red when short).
func _material_row(row: Dictionary) -> Control:
	var view := get_viewport_rect().size
	var ok := int(row.have) >= int(row.need)
	var h := HBoxContainer.new()
	h.name = "Material_" + str(row.category)
	h.custom_minimum_size = Vector2(0, 36 if _compact() else 50)
	h.add_theme_constant_override("separation", 12)
	var mark := _label("✓" if ok else "✕", UiTokens.body(view) + 4, UiTokens.OK_GREEN if ok else UiTokens.LIFE)
	mark.custom_minimum_size = Vector2(22, 0)
	mark.add_theme_font_override("font", ThemeDB.fallback_font)
	h.add_child(mark)
	var ic := TextureRect.new()
	ic.texture = ItemIcons.texture(row.sample_id)
	ic.custom_minimum_size = Vector2(30, 30)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color.WHITE if ok else Color(1.0, 0.55, 0.45)
	h.add_child(ic)
	var nm := _label(str(row.name), UiTokens.body(view) + (0 if _compact() else 2), UiTokens.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nm)
	var n := _label("%d / %d" % [int(row.have), int(row.need)], UiTokens.body(view) + (0 if _compact() else 2), UiTokens.GOLD if ok else UiTokens.LIFE)
	n.name = "HaveNeed"
	n.clip_text = false
	n.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	h.add_child(n)
	return _padded(h, 0)

func _selected_recipe() -> Dictionary:
	for rec in Crafting.recipes_for_station(StringName(_station)):
		if str(rec.get("id", "")) == _selected_id:
			return rec
	return {}

# ---------------------------------------------------------------- D3 place materials

## Opens the place-materials sub-view for recipe `rid` (D3).
func open_place(rid: String) -> void:
	var rec := Crafting.recipe(StringName(rid))
	if rec.is_empty() or player == null:
		return
	_place.visible = true
	_body.visible = false
	_layout_safe()
	_place.open(rec)

func close_place() -> void:
	_place.visible = false
	_body.visible = true
	_layout_safe()
	rebuild()

# ---------------------------------------------------------------- layout

func _layout_safe() -> void:
	if _body == null:
		return
	var view := get_viewport_rect().size
	if view.x < 8.0:
		return
	var safe := UiTokens.safe_insets(get_viewport())
	var compact := _compact()
	var hh := 64.0 if compact else UiTokens.HEADER_H
	var margin := 10.0 if compact else 32.0
	var top := safe.z
	_title.text = "Craft" if _place.visible else "Craft / Build"
	_build_btn.visible = not _place.visible
	_build_btn.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 4))
	_build_btn.custom_minimum_size = Vector2(104 if compact else 132, TAP)
	_header.layout(view, safe)
	_subtitle.visible = _place.visible
	_subtitle.text = _place.subtitle() if _place.visible else ""
	_subtitle.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 6))
	_subtitle.position = Vector2(_title.position.x + _title.size.x + 14.0, top + 2.0)
	_subtitle.size = Vector2(_subtitle.get_combined_minimum_size().x, hh)
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The hint takes the room between the title and Build; hidden when it would not fit (phones).
	var hint_l := _title.position.x + _title.size.x + 24.0
	var hint_w := view.x + _header.right.offset_left - 16.0 - hint_l
	_hint.add_theme_font_size_override("font_size", UiTokens.meta(view) + 2)
	_hint.position = Vector2(hint_l, top)
	_hint.size = Vector2(maxf(0.0, hint_w), hh)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.visible = not compact and not _place.visible and hint_w > 160.0
	var body_top := top + hh + (10.0 if compact else 30.0)
	_body.position = Vector2(safe.w + margin, body_top)
	_body.size = Vector2(view.x - safe.w - safe.x - margin * 2.0, view.y - safe.y - (8.0 if compact else 32.0) - body_top)
	_body.add_theme_constant_override("separation", 8 if compact else 20)
	var place_top := top + hh + (10.0 if compact else 22.0)
	_place.position = Vector2(safe.w + (8.0 if compact else 24.0), place_top)
	_place.size = Vector2(view.x - safe.w - safe.x - (16.0 if compact else 48.0), view.y - safe.y - place_top - (8.0 if compact else 24.0))
	(_tabs.get_parent() as ScrollContainer).custom_minimum_size = Vector2(0, TAP if compact else 92)
	(_footer.get_parent() as PanelContainer).add_theme_stylebox_override("panel", pad(UiTokens.PANEL, 8 if compact else 18, 8 if compact else 18, 6 if compact else 12, 6 if compact else 18))
	(_search.get_parent() as PanelContainer).add_theme_stylebox_override("panel", pad(UiTokens.PANEL, 8 if compact else 14, 8 if compact else 14, 6 if compact else 12, 6 if compact else 12))
	_search.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 6))
	_apply_phone_pane()

# ---------------------------------------------------------------- widgets

## A Button in one of the sheet's looks: "cell" (dark panel), "cta" (GOLD with CTA_INK), "ghost"
## (dark with a light rim), "bar" (the dark section bar) or "icon" (bare glyph in the header).
static func mk_btn(text: String, cb: Callable, minsz: Vector2, kind: String = "ghost") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(minsz.x, maxf(minsz.y, TAP))
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	if cb.is_valid():
		b.pressed.connect(cb)
	match kind:
		"cta":
			SheetChrome.style_action(b, &"cta")
			b.add_theme_font_size_override("font_size", 28)
		"bar":
			_btn_styles(b, Color(0.03, 0.07, 0.10, 0.92), Color(0, 0, 0, 0), 0, UiTokens.TEXT)
			b.add_theme_font_size_override("font_size", 20)
		"icon":
			_btn_styles(b, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, UiTokens.TEXT)
		_:
			SheetChrome.style_action(b, &"ghost")
			b.add_theme_font_size_override("font_size", 24)
	return b

static func _btn_styles(b: Button, bg: Color, border: Color, bw: int, fg: Color) -> void:
	var normal := pad(bg, 16, 16, 4, 4)
	normal.border_color = border
	normal.set_border_width_all(bw)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.08) if bg.a > 0.0 else Color(1, 1, 1, 0.06)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = bg.darkened(0.15) if bg.a > 0.0 else Color(1, 1, 1, 0.10)
	var dis := normal.duplicate() as StyleBoxFlat
	dis.bg_color = Color(0.35, 0.31, 0.18, 0.9) if bg == UiTokens.GOLD else Color(bg, bg.a * 0.5)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.draw_center = false
	focus.border_color = UiTokens.GOLD
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", focus)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	b.add_theme_color_override("icon_normal_color", fg)

## A grid cell's look: PANEL, a GOLD_DIM wash when chosen (its brackets are a child SheetChrome.Brackets).
static func style_cell(b: Button, chosen: bool) -> void:
	_btn_styles(b, Color(0.055, 0.118, 0.173, 1.0), Color(1, 1, 1, 0.07), 1, UiTokens.TEXT)
	if chosen:
		for k in ["normal", "hover", "pressed"]:
			var sb := b.get_theme_stylebox(k) as StyleBoxFlat
			sb.bg_color = Color(0.20, 0.20, 0.12, 1.0)  # GOLD_DIM over PANEL, solid
			sb.border_color = Color(UiTokens.GOLD, 0.35)

static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	return sb

static func pad(bg: Color, l: int, r: int, t: int, b: int) -> StyleBoxFlat:
	var sb := flat(bg)
	sb.content_margin_left = l
	sb.content_margin_right = r
	sb.content_margin_top = t
	sb.content_margin_bottom = b
	return sb

static func parchment() -> StyleBox:
	return SheetChrome.parchment_style(18, 0)

func _parchment() -> StyleBox:
	return parchment()

func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.08)
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _padded(c: Control, v: int = 6) -> MarginContainer:
	var m := MarginContainer.new()
	var side := 10 if _compact() else 20
	m.add_theme_constant_override("margin_left", side)
	m.add_theme_constant_override("margin_right", side)
	m.add_theme_constant_override("margin_top", v)
	m.add_theme_constant_override("margin_bottom", v)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(c)
	return m

static func _label(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(UiTokens.TYPE_MIN, px))
	l.add_theme_color_override("font_color", col)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## CRAFTFEEL: the stake lines of a recipe card. Success, flawless, the inherited primary traits, and —
## only when a failure is possible — that the materials are lost. A recipe that cannot fall short
## (required_ability 0, every recipe today) reads "Success 100 %", like the skewer in spec 25 §8.
static func craftfeel_text(qual: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Success %d%%   Flawless %d%%" % [int(round(float(qual.get("success", 1.0)) * 100.0)), int(round(float(qual.get("flawless", 0.0)) * 100.0))])
	var req := float(qual.get("required_ability", 0.0))
	if req > 0.0:
		lines.append("Ability %.0f / %.0f needed" % [float(qual.get("ability", 0.0)), req])
	var inherited: Array = qual.get("inherited", [])
	if not inherited.is_empty():
		var names: PackedStringArray = []
		for a: Variant in inherited:
			names.append(str(a).replace("_", " ").capitalize())
		lines.append("Inherits: %s" % ", ".join(names))
	if bool(qual.get("loses_materials", false)):
		lines.append("Materials are lost on failure.")
	return "\n".join(lines)

## Spec 31 §10 preview lines: expected level, base storage, inherited storage attributes, Pocket,
## other modifiers, final expected capacity, and the survivor's capacity wearing it. Numbers come from
## Crafting.bag_preview, so this text can never disagree with the crafted bag.
static func _bag_preview_text(prev: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Expected level: %d" % int(prev.get("level", 0)))
	lines.append("Base storage: +%d" % int(prev.get("base", 0)))
	var inherited: Dictionary = prev.get("inherited", {})
	for key: Variant in inherited:
		var k := str(key)
		if k == "pocket":
			continue
		lines.append("%s inherited: %s" % [k.capitalize(), str(inherited[key])])
	lines.append("Pocket %s: +%d" % [LevelDisplay.label(int(prev.get("pocket_level", 0))), int(prev.get("pocket", 0))])
	if int(prev.get("capacity", 0)) > 0:
		lines.append("Capacity attribute: +%d" % int(prev.get("capacity", 0)))
	if int(prev.get("other", 0)) > 0:
		lines.append("Bag modifier: +%d" % int(prev.get("other", 0)))
	lines.append("Final storage: +%d" % int(prev.get("bonus", 0)))
	lines.append("Worn bag capacity: %d" % int(prev.get("total_capacity", 0)))
	lines.append("Success: %d%%   Flawless: %d%%" % [int(round(float(prev.get("success", 1.0)) * 100.0)), int(round(float(prev.get("flawless", 0.0)) * 100.0))])
	return "\n".join(lines)

# ---------------------------------------------------------------- drawn pieces

## One category tile: a faint symbol behind the name, gold brackets and gold text when chosen.
## The name is drawn here (`title`), so Button.text stays empty and the theme draws nothing twice.
class _CategoryCell extends Button:
	var title := ""
	var icon_tex: Texture2D
	var chosen := false
	var empty := false
	var font_px := 16

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		CraftUI.style_cell(self, false)

	func _draw() -> void:
		var c := size * 0.5
		if icon_tex:
			var s := minf(size.y * 0.62, size.x * 0.5)
			draw_texture_rect(icon_tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, 0.10))
		var col := UiTokens.GOLD if chosen else (UiTokens.MUTED if empty else UiTokens.TEXT)
		var font := UiTokens.ui_face()
		var shown := UiTokens.ellipsis(font, title, size.x - 16.0, font_px)
		UiTokens.draw_centered(self, font, c, shown, font_px, col)
		if chosen:
			var arm := clampf(minf(size.x, size.y) * 0.2, 10.0, 32.0)
			var inset := Vector2(minf(22.0, size.x * 0.1), minf(18.0, size.y * 0.1))
			UiTokens.draw_brackets(self, Rect2(inset, size - inset * 2.0), UiTokens.GOLD, arm, UiTokens.BRACKET_W)
