class_name CraftUI
extends Control
## The one crafting menu, open from anywhere (Menu > Craft, the craft key, or a tap on a
## station). Recipes are grouped by station; a group unlocks when a station of that kind is
## within reach, otherwise the row says how far the nearest one is (or that none is built).
## Choosing a recipe closes the menu and crafts it like gathering: the survivor walks to the
## station if needed, the hex over it fills once per item, and the item lands in the bag on
## the full pass (StationCraft).
## Desktop: stations | recipes | detail side by side. Phone: one pane at a time: a chip row of
## stations over the recipe list, then the detail as a sheet over both, with Craft / Craft x5
## pinned in a footer (three stacked scroll panes hid the Craft button below a nested scroll).

## [station id, name, symbol icon id]. Symbols are white (HexButton.symbol); system emoji drew in colour.
## Campfire and crock pot have their own symbols: their kit icons alias the bonfire and grill ones.
const STATIONS := [
	["", "By hand", "hands"], ["workbench", "Workbench", "workbench_kit"], ["bonfire", "Bonfire", "bonfire_kit"],
	["campfire", "Campfire", "skewer"], ["drying_rack", "Meat dryer", "drying_rack_kit"],
	["crock_pot", "Crock pot", "boiled_meat"], ["mortar", "Mortar", "mortar_kit"],
	["stone_grill", "Stone grill", "stone_grill_kit"], ["steamer", "Steamer", "steamer_kit"], ["well", "Well", "well_kit"],
]
const NO_LEVEL := LevelDisplay.NONE
const FOOTER_H := 64.0

var player: Player
var _station: String = ""
var _root: VBoxContainer
var _body: GridContainer
var _tabs: BoxContainer  ## vertical column on desktop, horizontal chip row on a phone
var _list: VBoxContainer
var _detail: VBoxContainer
var _title: Label
var _hint: Label
var _refresh_left: float = 0.0
var _selected_id: String = ""
var _footer: HBoxContainer
var _phone_detail := false  ## phone only: the detail sheet is up instead of the list

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40  # above the HUD, which is added to the same UI layer after this menu
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03, 1.0)  # opaque: the HUD vitals must not show through the title
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 8)
	add_child(_root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_root.add_child(header)
	_title = Label.new()
	_title.text = "Craft"
	_title.add_theme_font_size_override("font_size", 26)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	_hint.name = "CraftHint"
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.size_flags_stretch_ratio = 2.0
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One line: the autowrapped version got a zero-height rect in the header and never drew.
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.clip_text = true
	header.add_child(_hint)
	header.add_child(_mk_btn("Close", hide_ui, Vector2(120, 56)))
	_body = GridContainer.new()
	_body.columns = 3
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("h_separation", 12)
	_body.add_theme_constant_override("v_separation", 12)
	_root.add_child(_body)
	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size = Vector2(200, 220)
	tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(tab_scroll)
	_tabs = BoxContainer.new()
	_tabs.vertical = true
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(_tabs)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(220, 220)
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(220, 220)
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(detail_scroll)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_detail)
	_footer = HBoxContainer.new()
	_footer.name = "CraftFooter"
	_footer.add_theme_constant_override("separation", UiTokens.SPACE)
	_footer.custom_minimum_size = Vector2(0, FOOTER_H)
	_footer.visible = false
	_root.add_child(_footer)
	resized.connect(_layout_safe)
	_layout_safe()
	if Game.shot_path.contains("craft"):
		get_tree().create_timer(0.9).timeout.connect(func () -> void: show_for_station(&"bonfire"))

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
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
	_layout_safe()
	rebuild()
	UiTokens.focus_first(_list.get_children())

## A station tap lands on that station's group.
func show_for_station(sid: StringName) -> void:
	_station = str(sid)
	show_ui()

func hide_ui() -> void:
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:  # distances change as the survivor walks
		_refresh_left = 0.5
		_refresh_tabs()

# ---------------------------------------------------------------- build

func rebuild() -> void:
	if player == null:
		return
	_refresh_tabs()
	_refresh_list()

func _refresh_tabs() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)  # detach first: focus_first and finds must not see rows about to go
		c.queue_free()
	for row in STATIONS:
		var sid: String = row[0]
		var info := _station_info(sid)
		var status := ""
		var col := Color(0.55, 0.95, 0.6)
		if sid == "":
			status = "anywhere"
		elif info["near"]:
			status = "here"
		elif info["exists"]:
			status = "%d m away" % int(info["dist"])
			col = Color(0.95, 0.85, 0.5)
		else:
			status = "none built"
			col = Color(0.6, 0.6, 0.6)
		var count := Crafting.recipes_for_station(StringName(sid)).size()
		var b := _mk_btn("%s\n%s · %s" % [row[1], status, recipe_count(count)], _pick_station.bind(sid), Vector2(228 if _single_pane() else 190, 64))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.icon = HexButton.symbol([row[2], "hammer"])
		b.material = HexButton.white_material()
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 28)
		b.add_theme_color_override("font_color", col)
		if sid == _station:
			b.add_theme_color_override("font_color", UiTokens.TEXT)
			b.add_theme_stylebox_override("normal", UiTokens.button_style(true))
		_tabs.add_child(b)

func _pick_station(sid: String) -> void:
	_station = sid
	_phone_detail = false
	rebuild()

static func recipe_count(n: int) -> String:
	return "%d recipe%s" % [n, "" if n == 1 else "s"]

## Portrait phone: one pane at a time (station chips + recipes, or the detail sheet).
func _single_pane() -> bool:
	return UiTokens.is_narrow(get_viewport_rect().size)

## Phones, either way up, pin Craft / Craft x5 in the footer: in a landscape phone's 230 px tall
## detail column they sat below the fold of its scroll.
func _pinned_actions() -> bool:
	return UiTokens.is_compact(get_viewport_rect().size)

func _refresh_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var name := "By hand"
	for row in STATIONS:
		if row[0] == _station:
			name = row[1]
	var info := _station_info(_station)
	_title.text = "Craft · %s" % name
	if _station == "":
		_hint.text = "Hand recipes craft anywhere. The hex over the survivor fills once per item."
	elif info["near"]:
		_hint.text = "%s in reach. Pick a recipe: the hex over it fills once per item." % name
	elif info["exists"]:
		_hint.text = "Nearest %s is %d m away: picking a recipe walks there first." % [name.to_lower(), int(info["dist"])]
	else:
		_hint.text = "No %s built yet. Craft its kit by hand and place it from Build." % name.to_lower()
	var recipes := Crafting.recipes_for_station(StringName(_station))
	if recipes.is_empty():
		var l := Label.new()
		l.text = "No recipes here yet."
		_list.add_child(l)
		return
	var found := false
	for rec in recipes:
		if str(rec.get("id", "")) == _selected_id:
			found = true
	if not found and not recipes.is_empty():
		_selected_id = str(recipes[0].get("id", ""))
	for rec in recipes:
		_list.add_child(_recipe_row(rec, info))
	_show_detail(info)

## Why a recipe cannot start now ("" = it can).
func _block_reason(rec: Dictionary, info: Dictionary) -> String:
	var blocked := Crafting.progression_block(player, rec)
	if blocked != "":
		return "Locked"
	if not Crafting.picks_valid(player.inventory, rec, Crafting.default_picks(player.inventory, rec)):
		return "Missing items"
	if _station != "" and not info["exists"]:
		return "No station"
	return ""

## One line per recipe: tap the row for details; only a recipe that can start carries a button.
func _recipe_row(rec: Dictionary, info: Dictionary) -> Control:
	var reason := _block_reason(rec, info)
	var can := reason == ""
	var chosen := str(rec.get("id", "")) == _selected_id
	var view := get_viewport_rect().size
	var phone := UiTokens.is_compact(view)
	var row := Button.new()
	row.toggle_mode = false
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_stylebox_override("normal", UiTokens.button_style(chosen))
	row.pressed.connect(_choose_recipe.bind(str(rec.get("id", ""))))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.add_theme_constant_override("separation", UiTokens.SPACE)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var out_row: Dictionary = rec.get("output", {})
	var out_icon := TextureRect.new()
	out_icon.texture = ItemIcons.texture(StringName(str(out_row.get("id", ""))))
	out_icon.custom_minimum_size = Vector2(44, 44)
	out_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	out_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	out_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	out_icon.modulate = Color.WHITE if can else Color(0.6, 0.6, 0.6)
	out_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(out_icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(text)
	var name := Label.new()
	name.text = _output_name(rec)
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", UiTokens.body(view))
	name.add_theme_color_override("font_color", Color.WHITE if can else Color(0.75, 0.75, 0.75))
	text.add_child(name)
	var meta := Label.new()
	meta.name = "RecipeMeta"
	meta.text = "%s · %.1fs%s" % [LevelDisplay.recipe_label(player.inventory, rec), Crafting.recipe_seconds(rec), ("  ·  " + reason) if reason != "" else ""]
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_theme_font_size_override("font_size", UiTokens.meta(view))
	meta.add_theme_color_override("font_color", UiTokens.META if can else Color(1.0, 0.62, 0.5))
	text.add_child(meta)
	if can:
		var label := "Craft"
		if _station != "" and not info["near"]:
			label = "Walk & craft" if not phone else "Walk"
		var b := _mk_btn(label, _start.bind(rec, 1), Vector2(96 if phone else 132, 48))
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	return row

func _output_name(rec: Dictionary) -> String:
	var out_row: Dictionary = rec.get("output", {})
	var out_def := Data.item(StringName(str(out_row.get("id", ""))))
	if out_def and out_def.display_name != "":
		return out_def.display_name
	return str(rec.get("display_name", rec.get("id", "?"))).replace("_", " ").capitalize()

## Icon + "have/need" per slot; red when short.
func _ingredients_row(rec: Dictionary) -> Control:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 8)
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
			if s:
				have += s.count
		var sample_id := StringName(str(cat))
		if i < picks.size() and picks[i] >= 0 and player.inventory.slots[picks[i]]:
			sample_id = player.inventory.slots[picks[i]].def_id
		else:
			sample_id = Crafting.sample_def_for_category(player.inventory, cat)
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var ic := TextureRect.new()
		ic.texture = ItemIcons.texture(sample_id)
		ic.custom_minimum_size = Vector2(24, 24)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.modulate = Color.WHITE if have >= need else Color(1.0, 0.55, 0.45)
		ic.visible = ic.texture != null  # no empty 24 px gap before an icon-less ingredient
		cell.add_child(ic)
		var l := Label.new()
		var d := Data.item(sample_id)
		var nm := d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(cat))
		l.text = "%s %d/%d" % [nm, mini(have, need), need]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.8, 0.85, 0.75) if have >= need else Color(1.0, 0.55, 0.45))
		cell.add_child(l)
		row.add_child(cell)
	return row

func _choose_recipe(rid: String) -> void:
	_selected_id = rid
	_phone_detail = _single_pane()
	rebuild()
	_apply_phone_pane()

func _back_to_list() -> void:
	_phone_detail = false
	_apply_phone_pane()

## Portrait phone: chips + list, or the detail sheet with its pinned footer. Otherwise all three
## panes, with the footer pinned under them on a landscape phone.
func _apply_phone_pane() -> void:
	var single := _single_pane()
	var sheet := single and _phone_detail
	(_tabs.get_parent() as Control).visible = not sheet
	(_list.get_parent() as Control).visible = not sheet
	(_detail.get_parent() as Control).visible = sheet or not single
	_footer.visible = sheet or (_pinned_actions() and not single)

func _start(rec: Dictionary, count: int) -> void:
	hide_ui()
	if player and player.has_method("craft_recipe"):
		player.craft_recipe(StringName(str(rec.get("id", ""))), count)

## {exists, near, dist} for a station kind, from the survivor's position.
func _station_info(sid: String) -> Dictionary:
	if sid == "" or player == null:
		return {"exists": true, "near": true, "dist": 0.0}
	var n := Crafting.nearest_station(player, StringName(sid))
	if n == null:
		return {"exists": false, "near": false, "dist": 0.0}
	var d := player.global_position.distance_to(n.global_position)
	return {"exists": true, "near": d <= Crafting.STATION_RANGE + 0.35, "dist": d}

func _show_detail(info: Dictionary) -> void:
	if _detail == null:
		return
	# Detach before freeing: a queued sibling still holds "CraftOne", so the new button got renamed.
	for pane in [_detail, _footer]:
		for c in pane.get_children():
			pane.remove_child(c)
			c.queue_free()
	if _single_pane():
		var back := _mk_btn("Back to recipes", _back_to_list, Vector2(0, UiTokens.TARGET_PRIMARY))
		back.name = "CraftBack"
		_detail.add_child(back)
	var head := Label.new()
	head.text = "RESULT"
	head.add_theme_font_size_override("font_size", UiTokens.meta(get_viewport_rect().size))
	head.add_theme_color_override("font_color", UiTokens.META)
	_detail.add_child(head)
	var rec := _selected_recipe()
	if rec.is_empty():
		var empty := Label.new()
		empty.text = "Select a recipe."
		empty.add_theme_font_size_override("font_size", UiTokens.body(get_viewport_rect().size))
		_detail.add_child(empty)
		return
	var out_row: Dictionary = rec.get("output", {})
	var out_def := Data.item(StringName(str(out_row.get("id", ""))))
	var out_name := _output_name(rec)
	var icon := TextureRect.new()
	icon.texture = ItemIcons.texture(StringName(str(out_row.get("id", ""))))
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail.add_child(icon)
	var title := Label.new()
	title.name = "DetailTitle"
	title.text = "%s\n%s · %.1fs    ×%d" % [out_name, LevelDisplay.recipe_label(player.inventory, rec), Crafting.recipe_seconds(rec), int(out_row.get("count", 1))]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", UiTokens.body(get_viewport_rect().size))
	title.add_theme_color_override("font_color", UiTokens.TEXT)
	_detail.add_child(title)
	var stats := LevelDisplay.stat_lines(out_def)
	if not stats.is_empty():
		var st := Label.new()
		st.name = "DetailStats"
		st.text = "\n".join(stats)
		st.add_theme_font_size_override("font_size", UiTokens.meta(get_viewport_rect().size))
		st.add_theme_color_override("font_color", UiTokens.META)
		_detail.add_child(st)
	var need := Label.new()
	need.text = "INGREDIENTS"
	need.add_theme_font_size_override("font_size", UiTokens.meta(get_viewport_rect().size))
	need.add_theme_color_override("font_color", UiTokens.META)
	_detail.add_child(need)
	_detail.add_child(_ingredients_row(rec))
	var missing := Crafting.missing_ingredient_name(player.inventory, rec)
	if missing != "":
		var lock := Label.new()
		lock.text = "Needs %s" % LevelDisplay.nice_name(missing)
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.add_theme_font_size_override("font_size", UiTokens.body(get_viewport_rect().size))
		lock.add_theme_color_override("font_color", UiTokens.DANGER)
		_detail.add_child(lock)
	elif _station != "" and not bool(info.get("exists", false)):
		var lock := Label.new()
		lock.text = "Station not built. The recipe stays listed."
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.add_theme_font_size_override("font_size", UiTokens.body(get_viewport_rect().size))
		lock.add_theme_color_override("font_color", UiTokens.DANGER)
		_detail.add_child(lock)
	# The repeated per-row buttons live here once: craft one or five of the selected recipe.
	# On a phone they sit in the pinned footer, never below the fold of a scroll.
	var can := _block_reason(rec, info) == ""
	var pinned := _pinned_actions()
	var actions := _footer as HBoxContainer
	if not pinned:
		actions = HBoxContainer.new()
		actions.add_theme_constant_override("separation", UiTokens.SPACE)
		_detail.add_child(actions)
	var btn_h := FOOTER_H if pinned else 56.0
	var one := _mk_btn("Craft", _start.bind(rec, 1), Vector2(120, btn_h))
	one.name = "CraftOne"
	one.disabled = not can
	var five := _mk_btn("Craft ×5", _start.bind(rec, 5), Vector2(120, btn_h))
	five.name = "CraftFive"
	five.disabled = not can
	for b in [one, five]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _single_pane() else Control.SIZE_FILL
		if pinned and not _single_pane():
			b.custom_minimum_size.x = 180.0  # right-aligned under the detail column
		actions.add_child(b)

func _selected_recipe() -> Dictionary:
	for rec in Crafting.recipes_for_station(StringName(_station)):
		if str(rec.get("id", "")) == _selected_id:
			return rec
	return {}

func _layout_safe() -> void:
	if _root == null:
		return
	var view := get_viewport_rect().size
	var safe := UiTokens.safe_insets(get_viewport())
	_root.offset_left = 16.0 + safe.w
	_root.offset_top = 12.0 + safe.z
	_root.offset_right = -(16.0 + safe.x)
	_root.offset_bottom = -(12.0 + safe.y)
	var phone := UiTokens.is_narrow(view)  # one column of panes; a landscape phone keeps three
	if _body:
		_body.columns = 1 if phone else 3
	if _list:
		var list_scroll := _list.get_parent() as Control
		if list_scroll:
			list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			list_scroll.size_flags_stretch_ratio = 1.0 if phone else 1.7
	if _tabs:
		var tab_scroll := _tabs.get_parent() as Control
		if tab_scroll:
			tab_scroll.size_flags_stretch_ratio = 1.0
	if _detail:
		var detail_scroll := _detail.get_parent() as Control
		if detail_scroll:
			detail_scroll.size_flags_stretch_ratio = 1.0
	if _tabs:
		# Phone: one horizontal chip row (scrolls sideways), so the recipe list gets the height.
		_tabs.vertical = not phone
		var tab_scroll := _tabs.get_parent() as ScrollContainer
		tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if phone else ScrollContainer.SCROLL_MODE_DISABLED
		tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if phone else ScrollContainer.SCROLL_MODE_AUTO
		tab_scroll.size_flags_vertical = Control.SIZE_FILL if phone else Control.SIZE_EXPAND_FILL
		tab_scroll.custom_minimum_size = Vector2(0, 80) if phone else Vector2(200, 220)
	for pane in [_list, _detail]:
		if pane:
			(pane.get_parent() as Control).custom_minimum_size = Vector2(0, 0) if phone else Vector2(220, 220)
	if _footer:
		_footer.alignment = BoxContainer.ALIGNMENT_BEGIN if phone else BoxContainer.ALIGNMENT_END
		_apply_phone_pane()
	if _title:
		_title.add_theme_font_size_override("font_size", UiTokens.heading(view))
	if _hint:
		_hint.add_theme_font_size_override("font_size", UiTokens.meta(view))
		# Phones cut it ("Hand reci..." in portrait, "...once per it..." on the 804 px canvas); the
		# station tabs already say where each station is.
		_hint.visible = not UiTokens.is_compact(view)

func _mk_btn(text: String, cb: Callable, minsz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsz
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b
