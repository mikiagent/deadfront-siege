class_name CraftUI
extends Control
## The one crafting menu, open from anywhere (Menu > Craft, the craft key, a station radial's top wedge
## or a tap in its output row). CRAFTRADIAL (docs/design/ui-redesign-spec.md §7 D5): a RIGHT-SIDE
## pop-out (RightSheet) with the world left visible beside it. Header "‹ Craft / Build ✕" (+ Build),
## a Search field, a 2-row grid of category tabs (All, Material Processing, Cooking, Tool, Clothing,
## Building Components, Weapon, Farming; the active one underlined GOLD), the recipes grouped under thin
## section headers as a two-column icon + name list, and the footer hint "Select a pattern.".
## Selecting a recipe swaps the list for its detail (Max Level / Related Skill / Station / odds, the
## materials with have / need, Craft and Craft ×5); ‹ goes back to the list.
## "Materials · Place materials" opens D3 (CraftPlace, full screen): choose which instance leads each
## slot, then Craft. Choosing Craft closes the menu and crafts it like gathering: the survivor walks to
## the station if needed, the hex over it fills once per item (StationCraft). Every number comes from
## Crafting (the same functions the craft rolls with); no crafting rule lives here.
## From the menu the list holds every recipe (each row says its station); from a station only that
## station's recipes.

## [station id, name, symbol icon id]. Symbols are white (HexButton.symbol); system emoji drew in colour.
## Campfire and crock pot have their own symbols: their kit icons alias the bonfire and grill ones.
const STATIONS := [
	["", "By hand", "hands"], ["workbench", "Workbench", "workbench_kit"], ["bonfire", "Bonfire", "bonfire_kit"],
	["campfire", "Campfire", "skewer"], ["drying_rack", "Meat dryer", "drying_rack_kit"],
	["crock_pot", "Crock pot", "boiled_meat"], ["mortar", "Mortar", "mortar_kit"],
	["stone_grill", "Stone grill", "stone_grill_kit"], ["steamer", "Steamer", "steamer_kit"], ["well", "Well", "well_kit"],
	["forge", "Forge", "ingot"], ["anvil", "Anvil", "hammer"],
]
## The category tabs (owner's Durango reference): [key ("" = all), label, symbol ids]. Keys are
## recipes.json `skill` values, except Tool / Weapon, which split weapon_tools by what the recipe
## makes (in_category). # ASSUMPTION: Farming kept as an eighth tab (7 farming recipes have no other home).
## Order (owner 2026-10-29): Materials (Material Processing) first, the tools together (Tool, Weapon),
## then the rest; Build is not a tab but the row at the very bottom of the list page (BuildRow).
## # ASSUMPTION: "All" moves to the last tab and the processing tab reads "Materials" (open question TT3).
const CATEGORIES := [
	["processing", "Materials", ["plank", "ingot"]],
	["tool", "Tool", ["stone_axe", "hammer"]],
	["weapon", "Weapon", ["stone_knife"]],
	["cooking", "Cooking", ["grilled_meat"]],
	["tailoring", "Clothing", ["cloth", "dried_hide"]],
	["construction", "Building Components", ["workbench_kit"]],
	["farming", "Farming", ["berry_seed"]],
	["", "All", ["stone_knife", "hammer"]],
]
## Outputs whose first category is one of these are a Weapon; the rest of weapon_tools is a Tool.
const WEAPON_CATS := [&"weapon", &"ammunition", &"siege_ammunition", &"counter_supply"]
## _station value for "every recipe, any station" (the menu's view).
const ALL := "*"
const NO_LEVEL := LevelDisplay.NONE
const FOOTER_H := 64.0
const TAP := 64.0  ## every control a finger presses (owner rule: 64 px or more)

var player: Player
var _station: String = ALL
var _category: String = ""
var _selected_id: String = ""
var _query: String = ""
var _phone_detail := false  ## the detail page is up instead of the list (every size: one page at a time)
## "build": the same pop-out lists what can be placed (kits in the bag, blueprints); a tap enters the
## existing placement flow (BuildUI.pick_kit ghost / BuildUI.tap_blueprint site).
var _mode := "craft"
var _refresh_left: float = 0.0

var _sheet: RightSheet
var _backdrop: ColorRect  ## only behind the full-screen D3 view
var _header: SheetChrome
var _title: Label
var _subtitle: Label
var _hint: Label
var _back_btn: Button
var _build_btn: Button
var _close_btn: Button
var _body: VBoxContainer
var _mid: VBoxContainer
var _right: VBoxContainer
var _cats: GridContainer
var _cat_scroll: ScrollContainer
var _search: LineEdit
var _list: VBoxContainer
var _detail: VBoxContainer
var _footer: HBoxContainer
var _place: CraftPlace

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the world left of the panel stays tappable
	z_index = 40  # above the HUD, which is added to the same UI layer after this menu
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = UiTokens.ui_face()
	theme = th
	_backdrop = SheetChrome.backdrop()
	_backdrop.visible = false
	add_child(_backdrop)
	_sheet = RightSheet.new("Craft / Build")
	_sheet.name = "CraftSheet"
	_sheet.back_pressed.connect(_on_back)
	_sheet.close_pressed.connect(hide_ui)
	add_child(_sheet)
	_header = _sheet.header
	_header.name = "CraftHeader"
	_back_btn = _header.back
	_back_btn.name = "CraftBack"
	_title = _header.title
	_title.name = "CraftTitle"
	_subtitle = Label.new()
	_subtitle.name = "CraftSubtitle"
	_subtitle.add_theme_color_override("font_color", UiTokens.MUTED)
	_header.add_child(_subtitle)
	# Spec 30 §2: Build (blueprints, construction) is the other half of "Craft / Build".
	_build_btn = mk_btn("Build", _open_build, Vector2(104, TAP), "ghost")
	_build_btn.name = "BuildRow"
	_build_btn.icon = HexButton.symbol(["hammer", "workbench_kit"])
	_build_btn.expand_icon = true
	_build_btn.add_theme_constant_override("icon_max_width", 26)
	_build_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_btn = _header.close
	_close_btn.name = "CraftClose"
	_body = VBoxContainer.new()
	_body.name = "CraftBody"
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_theme_constant_override("separation", 0)
	_sheet.body.add_child(_body)
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

## The list page: Search, the category tabs, the grouped recipes and the footer hint.
func _build_mid() -> void:
	_mid = VBoxContainer.new()
	_mid.name = "CraftMid"
	_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mid.add_theme_constant_override("separation", 6)
	_body.add_child(_mid)
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
	_mid.add_child(_search)
	_hint = Label.new()
	_hint.name = "CraftHint"
	_hint.add_theme_color_override("font_color", UiTokens.MUTED)
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	_mid.add_child(_hint)
	# A phone (844x390) has no height for two rows of tabs above the list and Build below it: there the
	# tabs are one row that scrolls sideways (the tutorial guide scrolls its tab into view).
	_cat_scroll = ScrollContainer.new()
	_cat_scroll.name = "CategoryScroll"
	_cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mid.add_child(_cat_scroll)
	_cats = GridContainer.new()
	_cats.name = "CategoryGrid"
	_cats.columns = 4
	_cats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cats.add_theme_constant_override("h_separation", 2)
	_cats.add_theme_constant_override("v_separation", 2)
	_cat_scroll.add_child(_cats)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "RecipeScroll"
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.add_theme_stylebox_override("panel", flat(Color(0, 0, 0, 0.18)))
	_mid.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.name = "RecipeList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	list_scroll.add_child(_list)
	# Owner 2026-10-29: Build sits at the very bottom of Craft / Build, under every category and recipe.
	var foot_row := HBoxContainer.new()
	foot_row.name = "CraftFootRow"
	foot_row.add_theme_constant_override("separation", 8)
	_mid.add_child(foot_row)
	var foot := _label("Select a pattern.", 14, UiTokens.MUTED)
	foot.name = "CraftFootHint"
	foot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot_row.add_child(foot)
	foot_row.add_child(_build_btn)

## The detail page: the recipe, then Craft / Craft ×5 pinned under it.
func _build_right() -> void:
	_right = VBoxContainer.new()
	_right.name = "CraftRight"
	_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 0)
	_right.visible = false
	_body.add_child(_right)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.name = "Detail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 0)
	detail_scroll.add_child(_detail)
	var foot_pad := PanelContainer.new()
	foot_pad.name = "FooterPad"
	foot_pad.add_theme_stylebox_override("panel", pad(Color(0, 0, 0, 0), 0, 0, 8, 0))
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
		elif _phone_detail:
			_back_to_list()
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

## The menu's way in: every recipe, any station.
func toggle() -> void:
	if visible:
		hide_ui()
	else:
		_station = ALL
		_mode = "craft"
		show_ui()

func show_ui() -> void:
	visible = true
	_phone_detail = false
	_place.visible = false
	_body.visible = true
	_apply_phone_pane()
	rebuild()
	UiTokens.focus_first(_list.find_children("*", "Button", true, false))

## A station lands on that station's recipes.
func show_for_station(sid: StringName) -> void:
	_station = str(sid)
	_mode = "craft"
	show_ui()

## A station radial's output slot: that station's list with `rid` open on its detail page.
func show_recipe(sid: StringName, rid: StringName) -> void:
	_station = str(sid)
	_mode = "craft"
	_category = ""
	_query = ""
	_search.text = ""
	show_ui()
	_choose_recipe(str(rid))

func hide_ui() -> void:
	visible = false
	_place.visible = false
	_body.visible = true

## ‹ in the header: D3 back to the recipe, the detail back to the list, else back to the MENU sheet
## (spec §8: Back returns to the MENU, ✕ to the HUD).
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
		if not _place.visible and not _phone_detail and _mode == "craft":
			_hint.text = _hint_text()

# ---------------------------------------------------------------- build

func rebuild() -> void:
	if player == null:
		return
	if _place.visible:
		_place.rebuild()
		return
	_cat_scroll.visible = _mode == "craft"
	_build_btn.text = "Craft" if _mode == "build" else "Build"
	_build_btn.set_meta(&"tut_chosen", _mode == "build")  # Tutorial.guide's gate: the Build page is open
	if _mode == "build":
		_refresh_build_list()
		return
	_refresh_cats()
	_refresh_list()

func _refresh_cats() -> void:
	for c in _cats.get_children():
		_cats.remove_child(c)
		c.queue_free()
	var recipes := _station_recipes()
	var view := get_viewport_rect().size
	for row in CATEGORIES:
		var key: String = row[0]
		var n := 0
		for rec in recipes:
			if in_category(rec, key):
				n += 1
		var cell := _CategoryCell.new()
		cell.name = "Cat_" + (key if key != "" else "all")
		cell.title = row[1]
		cell.icon_tex = HexButton.symbol(row[2])
		cell.chosen = key == _category
		cell.set_meta(&"tut_chosen", cell.chosen)  # Tutorial.guide: the tab is open (checked while it shows)
		cell.empty = n == 0
		cell.font_px = UiTokens.meta(view) + (0 if _compact() else 2)
		cell.custom_minimum_size = Vector2(108 if _compact() else TAP, TAP if _compact() else 76)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.pressed.connect(_pick_category.bind(key))
		_cats.add_child(cell)

## Build / Craft in the header switches the pop-out between the recipe list and the placeables.
func _open_build() -> void:
	_mode = "craft" if _mode == "build" else "build"
	_phone_detail = false
	_apply_phone_pane()
	rebuild()

## The symbol of what a blueprint builds: its station kind's kit icon (Basic Workbench = the workbench
## kit); a kind with no kit falls back to the hammer.
static func blueprint_icon(bp_id: StringName) -> StringName:
	var kind := BuildFlow._grid_kind(bp_id)
	var kit := BuildPlacer.kit_for(kind)
	return kit if kit != &"" else &"hammer"

## Build page rows: the kits in the bag (place as their kind) and the blueprints (construction sites).
## Same callbacks as the Build drawer, so placement, rotation and confirm stay BuildUI's.
func _refresh_build_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_hint.text = "Pick a building, then place it."
	var ui := BuildUI.ensure(player)
	var kits: Array = []
	var seen := {}
	for st: ItemStack in player.inventory.slots:
		if st == null or Data.item(st.def_id) == null or str(Data.item(st.def_id).get("place_as")) == "" or seen.has(st.def_id):
			continue
		seen[st.def_id] = true
		kits.append({"id": "Kit_" + str(st.def_id), "name": Data.item(st.def_id).display_name, "icon": st.def_id, "meta": "in bag", "cb": func () -> void:
			hide_ui()
			ui.pick_kit(StringName(str(Data.item(st.def_id).get("place_as"))))})
	var bps: Array = []
	for row in BuildFlow.menu_rows(player):
		var id := str(row.get("id", ""))
		var blocked := str(row.get("blocked", ""))
		bps.append({"id": "BP_" + id, "name": str(row.get("name", id)), "icon": blueprint_icon(StringName(id)), "meta": "Buildable" if blocked == "" else blocked, "cb": func () -> void:
			hide_ui()
			if blocked != "":
				player.notice("%s: %s" % [str(row.get("name", id)), blocked])
			elif player.placer:
				player.placer.begin_blueprint(StringName(id))  # the grid-snap / drag / rotate ghost, then a plot
			else:
				ui.tap_blueprint(id)})
	for sec in [["Stations", kits], ["Blueprints", bps]]:
		var head := _label(str(sec[0]), UiTokens.meta(get_viewport_rect().size) + 2, UiTokens.MUTED)
		head.name = "Group_" + str(sec[0])
		head.custom_minimum_size = Vector2(0, 28)
		_list.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		_list.add_child(grid)
		for r: Dictionary in sec[1]:
			var b := mk_btn("  " + str(r["name"]), r["cb"], Vector2(0, TAP), "ghost")
			b.name = str(r["id"])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.icon = ItemIcons.texture(r["icon"])
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 36)
			b.add_theme_font_size_override("font_size", UiTokens.body(get_viewport_rect().size))
			b.tooltip_text = str(r["meta"])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(b)

func _pick_category(key: String) -> void:
	_category = key
	_phone_detail = false
	_refresh_cats()
	_refresh_list()
	_apply_phone_pane()

static func recipe_count(n: int) -> String:
	return "%d recipe%s" % [n, "" if n == 1 else "s"]

## Phone type sizes and tighter rows, either way up.
func _compact() -> bool:
	return UiTokens.is_compact(get_viewport_rect().size)

## Does `rec` belong under category tab `key`? Tool / Weapon split weapon_tools by the output.
static func in_category(rec: Dictionary, key: String) -> bool:
	if key == "":
		return true
	var skill := str(rec.get("skill", ""))
	if key == "tool" or key == "weapon":
		if skill != "weapon_tools":
			return false
		var d := Data.item(StringName(str((rec.get("output", {}) as Dictionary).get("id", ""))))
		var weapon := d != null and not d.categories.is_empty() and d.categories[0] in WEAPON_CATS
		return weapon == (key == "weapon")
	return skill == key

## Every recipe this view lists before filters: one station's, or all of them (ALL).
func _station_recipes() -> Array[Dictionary]:
	if _station != ALL:
		return Crafting.recipes_for_station(StringName(_station))
	var out: Array[Dictionary] = []
	for row in Data.recipe_list:
		if row is Dictionary:
			out.append(row as Dictionary)
	return out

## The recipes the list shows: the station's, narrowed by category and search.
func _shown_recipes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec in _station_recipes():
		if not in_category(rec, _category):
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
	_hint.text = _hint_text()
	var recipes := _shown_recipes()
	if recipes.is_empty():
		var l := _label("No recipes here yet." if _query == "" else "No recipe matches \"%s\"." % _query, UiTokens.body(get_viewport_rect().size), UiTokens.MUTED)
		l.custom_minimum_size = Vector2(0, TAP)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_list.add_child(l)
		_selected_id = ""
		_show_detail()
		return
	# The detail page is built for the chosen recipe, else the first one (shown once picked).
	if not recipes.any(func (r: Dictionary) -> bool: return str(r.get("id", "")) == _selected_id):
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
		# A thin section header: the group name over a hairline (Durango's "Processed Material").
		var head := _label(str(g), UiTokens.meta(get_viewport_rect().size) + (0 if compact else 2), UiTokens.MUTED)
		head.name = "Group_" + str(g)
		head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		head.custom_minimum_size = Vector2(0, 24 if compact else 32)
		var sb := pad(Color(0, 0, 0, 0), 8, 8, 0, 2)
		sb.border_color = Color(1, 1, 1, 0.12)
		sb.border_width_bottom = 1
		head.add_theme_stylebox_override("normal", sb)
		_list.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		_list.add_child(grid)
		for rec in groups[g]:
			grid.add_child(_recipe_row(rec))
	_show_detail()

## The list's one-line context: which station this view is, and where it is.
func _hint_text() -> String:
	if _station == ALL:
		return "All patterns · %s" % recipe_count(_shown_recipes().size())
	if _station == "":
		return "Hand recipes craft anywhere."
	var name := station_name(_station)
	var info := _station_info(_station)
	var ps := ProcessStation.of(info.get("node", null)) if info["near"] else null
	if ps != null and ps.capacity() > 0:
		# Spec 30 §13: the station's own job queue, so a queued job is visible where it was started.
		return "%s · %d/%d jobs, %d ready · %s" % [name, ps.running_count(), ps.capacity(), ps.ready_count(), ps.time_left_text() if ps.time_left_text() != "" else "queue free"]
	if info["near"]:
		return "%s in reach." % name
	if info["exists"]:
		return "Nearest %s %d m away: a craft walks there first." % [name.to_lower(), int(info["dist"])]
	return "No %s built yet: craft its kit by hand, place it from Build." % name.to_lower()

## Why a recipe cannot start now ("" = it can). The recipe's own station decides (ALL lists many).
func _block_reason(rec: Dictionary, info: Dictionary = {}) -> String:
	var sid := Crafting.station_id(rec)
	if info.is_empty():
		info = _station_info(sid)
	# RECIPETOOLS: a tool gate names the tool ("Needs work axe (flint)") like the station gates below.
	var tool := Crafting.tool_block(player.inventory, rec)
	var blocked := Crafting.progression_block(player, rec)
	if blocked != "":
		return tool if blocked == tool else "Locked"
	# Spec 30 §10-11: a station's tags and its level gate the recipe, and the row says which.
	if sid != "":
		var st: Variant = info.get("node", null)
		if st is CraftStation:
			var gate := CraftStation.station_gate(rec, (st as CraftStation).station_tags, (st as CraftStation).station_level, StringName(sid))
			if gate != "":
				return gate + "  " + str(rec.get("id", "")).replace("_", " ").capitalize()
	if not Crafting.picks_valid(player.inventory, rec, Crafting.default_picks(player.inventory, rec)):
		return "Missing items"
	if sid != "" and not info["exists"]:
		return "No station"
	return ""

## One cell per recipe: icon, name, level · time. Tap selects it; gold brackets mark the selection.
## Button > HBox > VBox > RecipeMeta (ui_real_capture_lab walks up from the meta to the button).
func _recipe_row(rec: Dictionary) -> Control:
	var reason := _block_reason(rec)
	var can := reason == ""
	var chosen := str(rec.get("id", "")) == _selected_id
	var view := get_viewport_rect().size
	var compact := _compact()
	var row := Button.new()
	row.name = "Recipe_" + str(rec.get("id", ""))
	row.custom_minimum_size = Vector2(0, TAP if compact else 92)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	style_cell(row, chosen)
	row.set_meta(&"tut_chosen", chosen)  # Tutorial.guide: Craft below acts on this recipe
	row.set_meta(&"tut_hard", true)  # checked on the detail page too, where the list is hidden
	row.pressed.connect(_choose_recipe.bind(str(rec.get("id", ""))))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10 if compact else 18
	h.offset_right = -8
	h.add_theme_constant_override("separation", 8 if compact else 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var out_row := output_row(player.inventory, rec)
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

## OUTPUTS: the output row the picks' slot-1 instance makes (Crafting.output_for); `output` when
## slot 1 is unfilled. Default picks when `picks` is empty. Shared with CraftPlace (D3).
static func output_row(inv: Inventory, rec: Dictionary, picks: Array[int] = []) -> Dictionary:
	if picks.is_empty() and inv:
		picks = Crafting.default_picks(inv, rec)
	var pi := Crafting.primary_index(rec)
	var primary: ItemStack = inv.slots[picks[pi]] if inv and pi < picks.size() and picks[pi] >= 0 else null
	return Crafting.output_for(rec, primary)

func _output_name(rec: Dictionary) -> String:
	var out_row := output_row(player.inventory, rec)
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
	_phone_detail = rid != ""
	rebuild()
	_apply_phone_pane()

func _back_to_list() -> void:
	_phone_detail = false
	_apply_phone_pane()
	rebuild()

## One page at a time in the pop-out: the list (search, tabs, recipes) or the chosen recipe's detail.
func _apply_phone_pane() -> void:
	_mid.visible = not _phone_detail
	_right.visible = _phone_detail
	_title.text = "Craft" if _phone_detail else ("Build" if _mode == "build" else "Craft / Build")
	_layout_safe()

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

func _show_detail() -> void:
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
	var info := _station_info(Crafting.station_id(rec))
	var out_row := output_row(player.inventory, rec)
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
	elif Crafting.station_id(rec) != "" and not bool(info.get("exists", false)):
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
	var walk := Crafting.station_id(rec) != "" and not bool(info.get("near", false))
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
	return Crafting.recipe(StringName(_selected_id)) if _selected_id != "" else {}

# ---------------------------------------------------------------- D3 place materials

## Opens the place-materials view for recipe `rid` (D3), in its own wider right pop-out.
func open_place(rid: String) -> void:
	var rec := Crafting.recipe(StringName(rid))
	if rec.is_empty() or player == null:
		return
	visible = true
	_place.visible = true
	_body.visible = false
	_layout_safe()
	_place.open(rec)

## The Construction panel (spec 30 §7, Durango "Construction"): the same D3 view filling a
## ConstructionSite's blueprint slots by tag. A site tap lands here (BuildUI.show_site).
func open_site(site: ConstructionSite) -> void:
	if site == null or player == null:
		return
	site.bind_bag(player.inventory)
	visible = true
	_place.visible = true
	_body.visible = false
	_layout_safe()
	_place.open_site(site)
	_layout_safe()

func close_place() -> void:
	var was_site := _place.site != null
	_place.visible = false
	_place.site = null
	_body.visible = true
	if was_site:
		hide_ui()
		return
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
	var placing := _place.visible
	# D3 / Construction needs its four columns: the same pop-out, widened to most of the view.
	_sheet.share = 0.86 if placing else 0.42
	if placing:
		_title.text = "Construction" if _place.site != null else "Craft"
	_build_btn.visible = not placing and not _phone_detail
	_build_btn.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 2))
	_build_btn.custom_minimum_size = Vector2(96 if compact else 120, TAP)
	_subtitle.visible = placing
	_subtitle.text = _place.subtitle() if placing else ""
	_sheet.layout(view, safe)
	_body.queue_sort()  # a body resized while hidden (D3 was up) kept its children's old rects
	_subtitle.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 4))
	_subtitle.position = Vector2(_title.position.x + _title.size.x + 14.0, safe.z)
	_subtitle.size = Vector2(maxf(0.0, _header.right.position.x - _subtitle.position.x - 8.0) if _header.right.visible else _subtitle.get_combined_minimum_size().x, _header.header_h)
	_subtitle.clip_text = true
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place.position = _sheet.position + _sheet.body.position
	_place.size = _sheet.body.size
	_hint.add_theme_font_size_override("font_size", UiTokens.meta(view))
	_hint.custom_minimum_size = Vector2(0, 18 if compact else 22)
	_search.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 4))
	_mid.add_theme_constant_override("separation", 4 if compact else 8)
	_cats.columns = CATEGORIES.size() if compact else 4

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
