class_name CraftUI
extends Control
## The one crafting menu, open from anywhere (Menu > Craft, the craft key, or a tap on a
## station). Recipes are grouped by station; a group unlocks when a station of that kind is
## within reach, otherwise the row says how far the nearest one is (or that none is built).
## Choosing a recipe closes the menu and crafts it like gathering: the survivor walks to the
## station if needed, the hex over it fills once per item, and the item lands in the bag on
## the full pass (StationCraft).

const STATIONS := [
	["", "By hand", "✋"], ["workbench", "Workbench", "🔨"], ["bonfire", "Bonfire", "🔥"],
	["drying_rack", "Meat dryer", "🪢"], ["mortar", "Mortar", "🥣"], ["stone_grill", "Stone grill", "🍖"],
	["steamer", "Steamer", "♨"], ["well", "Well", "💧"],
]

var player: Player
var _station: String = ""
var _root: VBoxContainer
var _body: GridContainer
var _tabs: VBoxContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _title: Label
var _hint: Label
var _refresh_left: float = 0.0
var _selected_id: String = ""

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40  # above the HUD, which is added to the same UI layer after this menu
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.03, 0.94)
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
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.max_lines_visible = 2
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
	_tabs = VBoxContainer.new()
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
	_layout_safe()
	rebuild()

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
		c.queue_free()
	for row in STATIONS:
		var sid: String = row[0]
		var info := _station_info(sid)
		var status := ""
		var col := Color(0.55, 0.95, 0.6)
		if sid == "":
			status = "always"
		elif info["near"]:
			status = "● here"
		elif info["exists"]:
			status = "○ %d m away" % int(info["dist"])
			col = Color(0.95, 0.85, 0.5)
		else:
			status = "○ none built"
			col = Color(0.6, 0.6, 0.6)
		var count := Crafting.recipes_for_station(StringName(sid)).size()
		var b := _mk_btn("%s %s\n%s · %d" % [row[2], row[1], status, count], _pick_station.bind(sid), Vector2(190, 64))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_color_override("font_color", col)
		if sid == _station:
			b.add_theme_color_override("font_color", UiTokens.TEXT)
			b.add_theme_stylebox_override("normal", UiTokens.button_style(true))
		_tabs.add_child(b)

func _pick_station(sid: String) -> void:
	_station = sid
	rebuild()

func _refresh_list() -> void:
	for c in _list.get_children():
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

func _recipe_row(rec: Dictionary, info: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var picks := Crafting.default_picks(player.inventory, rec)
	var have := Crafting.picks_valid(player.inventory, rec, picks)
	var reachable: bool = _station == "" or bool(info["exists"])
	var can := have and reachable
	var chosen := str(rec.get("id", "")) == _selected_id
	sb.bg_color = UiTokens.TEAL_DIM if chosen else (Color(0.10, 0.12, 0.13, 0.95) if can else Color(0.08, 0.09, 0.1, 0.92))
	sb.border_color = UiTokens.TEAL if chosen else UiTokens.DIVIDER
	sb.set_border_width_all(2 if chosen else 1)
	sb.set_corner_radius_all(UiTokens.RADIUS)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var phone := UiTokens.is_phone(get_viewport_rect().size)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	# Buttons sit under the title so the name row keeps the column width.
	# Only the recipe name ellipsises; Lv / time keeps a reserved width.
	panel.add_child(stack)
	stack.add_child(h)
	stack.add_child(actions)
	var out_row0: Dictionary = rec.get("output", {})
	var out_icon := TextureRect.new()
	out_icon.texture = ItemIcons.texture(StringName(str(out_row0.get("id", ""))))
	out_icon.custom_minimum_size = Vector2(44, 44) if phone else Vector2(52, 52)
	out_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	out_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	out_icon.modulate = Color.WHITE if can else Color(0.6, 0.6, 0.6)
	h.add_child(out_icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UiTokens.SPACE)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(line)
	var out_row: Dictionary = rec.get("output", {})
	var out_def := Data.item(StringName(str(out_row.get("id", ""))))
	var out_name := out_def.display_name if out_def and out_def.display_name != "" else str(rec.get("display_name", rec.get("id", "?")))
	var view := get_viewport_rect().size
	var name_px := UiTokens.body(view)
	var font := ThemeDB.fallback_font
	var level := Crafting.preview_level(player.inventory, rec)
	var seconds := Crafting.recipe_seconds(rec)
	var meta_text := "Lv %d · %.1fs" % [level, seconds]
	var reserve_w := font.get_string_size("Lv 60 · 3.0s", HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x if font else 108.0
	var actual_w := font.get_string_size(meta_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x if font else reserve_w
	var meta_w := maxf(reserve_w, actual_w) + float(UiTokens.SPACE)
	var name := Label.new()
	name.text = out_name
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(0, name_px + 4)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", name_px)
	name.add_theme_color_override("font_color", Color.WHITE if can else Color(0.75, 0.75, 0.75))
	line.add_child(name)
	var meta := Label.new()
	meta.text = meta_text
	meta.clip_text = false
	meta.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	meta.custom_minimum_size = Vector2(ceilf(meta_w), name_px + 4)
	meta.size_flags_horizontal = Control.SIZE_SHRINK_END
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.add_theme_font_size_override("font_size", name_px)
	meta.add_theme_color_override("font_color", Color.WHITE if can else Color(0.75, 0.75, 0.75))
	line.add_child(meta)
	var pick := Button.new()
	pick.text = "Details"
	pick.custom_minimum_size = Vector2(88, 44)
	pick.pressed.connect(_choose_recipe.bind(str(rec.get("id", ""))))
	actions.add_child(pick)
	var btn_text := "Craft"
	if not have:
		btn_text = "Missing"
	elif _station != "" and not info["exists"]:
		btn_text = "No station"
	elif _station != "" and not info["near"]:
		btn_text = "Walk & craft"
	var b := _mk_btn(btn_text, _start.bind(rec, 1), Vector2(120 if not phone else 96, 56))
	b.disabled = not can
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	actions.add_child(b)
	var b5 := _mk_btn("×5", _start.bind(rec, 5), Vector2(64, 56))
	b5.disabled = not can
	actions.add_child(b5)
	return panel

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
		cell.add_child(ic)
		var l := Label.new()
		var d := Data.item(sample_id)
		var nm := d.display_name if d and d.display_name != "" else str(cat).replace("_", " ")
		l.text = "%s %d/%d" % [nm, mini(have, need), need]
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Color(0.8, 0.85, 0.75) if have >= need else Color(1.0, 0.55, 0.45))
		cell.add_child(l)
		row.add_child(cell)
	return row

func _ingredients_text(rec: Dictionary) -> String:
	var parts: PackedStringArray = []
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
		var label := str(cat).replace("_", " ")
		if i < picks.size() and picks[i] >= 0 and player.inventory.slots[picks[i]]:
			var d := player.inventory.slots[picks[i]].def()
			if d and d.display_name != "":
				label = d.display_name
		else:
			var sample := Data.item(Crafting.sample_def_for_category(player.inventory, cat))
			if sample and sample.display_name != "":
				label = sample.display_name
		parts.append("%s %d/%d" % [label, mini(have, need), need])
	return "  ·  ".join(parts)

func _choose_recipe(rid: String) -> void:
	_selected_id = rid
	rebuild()

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
	for c in _detail.get_children():
		c.queue_free()
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
	var out_name := out_def.display_name if out_def and out_def.display_name != "" else str(rec.get("display_name", rec.get("id", "?")))
	var icon := TextureRect.new()
	icon.texture = ItemIcons.texture(StringName(str(out_row.get("id", ""))))
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail.add_child(icon)
	var title := Label.new()
	title.text = "%s\nLv %d    ×%d" % [out_name, Crafting.preview_level(player.inventory, rec), int(out_row.get("count", 1))]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", UiTokens.body(get_viewport_rect().size))
	title.add_theme_color_override("font_color", UiTokens.TEXT)
	_detail.add_child(title)
	var need := Label.new()
	need.text = "INGREDIENTS"
	need.add_theme_font_size_override("font_size", UiTokens.meta(get_viewport_rect().size))
	need.add_theme_color_override("font_color", UiTokens.META)
	_detail.add_child(need)
	_detail.add_child(_ingredients_row(rec))
	var missing := Crafting.missing_ingredient_name(player.inventory, rec)
	if missing != "":
		var lock := Label.new()
		lock.text = "Needs %s" % missing.replace("_", " ")
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
	var phone := UiTokens.is_phone(view)
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
	var inner_h := maxf(180.0, view.y - 36.0 - safe.y - safe.z)
	var section_h := maxf(112.0, (inner_h - 72.0) / 3.0) if phone else 220.0
	for scroll_name in ["tab", "list", "detail"]:
		var scroll: ScrollContainer = null
		if scroll_name == "tab" and _tabs:
			scroll = _tabs.get_parent() as ScrollContainer
		elif scroll_name == "list" and _list:
			scroll = _list.get_parent() as ScrollContainer
		elif scroll_name == "detail" and _detail:
			scroll = _detail.get_parent() as ScrollContainer
		if scroll:
			scroll.custom_minimum_size = Vector2(0.0 if phone else scroll.custom_minimum_size.x, section_h)
	if _title:
		_title.add_theme_font_size_override("font_size", UiTokens.heading(view))
	if _hint:
		_hint.add_theme_font_size_override("font_size", UiTokens.meta(view))

func _mk_btn(text: String, cb: Callable, minsz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsz
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b
