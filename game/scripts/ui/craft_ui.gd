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
	["drying_rack", "Drying rack", "🪢"], ["mortar", "Mortar", "🥣"], ["stone_grill", "Stone grill", "🍖"],
	["steamer", "Steamer", "♨"], ["well", "Well", "💧"],
]

var player: Player
var _station: String = ""
var _root: VBoxContainer
var _tabs: VBoxContainer
var _list: VBoxContainer
var _title: Label
var _hint: Label
var _refresh_left: float = 0.0

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40  # above the HUD, which is added to the same UI layer after this menu
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1, 0.94)
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
	header.add_child(_hint)
	header.add_child(_mk_btn("Close", hide_ui, Vector2(120, 56)))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	_root.add_child(body)
	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size = Vector2(200, 300)
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(tab_scroll)
	_tabs = VBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_scroll.add_child(_tabs)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(list_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list)
	resized.connect(_layout_safe)
	_layout_safe()
	if Game.shot_path.contains("craft"):
		get_tree().create_timer(0.9).timeout.connect(func () -> void: show_for_station(&"bonfire"))

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
		b.add_theme_color_override("font_color", col)
		if sid == _station:
			b.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.22, 0.2, 0.12, 0.95)
			sb.corner_radius_top_left = 6
			sb.corner_radius_bottom_left = 6
			b.add_theme_stylebox_override("normal", sb)
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
	for rec in recipes:
		_list.add_child(_recipe_row(rec, info))

func _recipe_row(rec: Dictionary, info: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var picks := Crafting.default_picks(player.inventory, rec)
	var have := Crafting.picks_valid(player.inventory, rec, picks)
	var reachable: bool = _station == "" or bool(info["exists"])
	var can := have and reachable
	sb.bg_color = Color(0.12, 0.16, 0.12, 0.95) if can else Color(0.12, 0.13, 0.15, 0.9)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(text)
	var name := Label.new()
	var out_row: Dictionary = rec.get("output", {})
	var out_def := Data.item(StringName(str(out_row.get("id", ""))))
	var out_name := out_def.display_name if out_def and out_def.display_name != "" else str(rec.get("display_name", rec.get("id", "?")))
	name.text = "%s   Lv %d · %.1fs" % [out_name, Crafting.preview_level(player.inventory, rec), Crafting.recipe_seconds(rec)]
	name.add_theme_font_size_override("font_size", 18)
	name.add_theme_color_override("font_color", Color.WHITE if can else Color(0.75, 0.75, 0.75))
	text.add_child(name)
	var ing := Label.new()
	ing.text = _ingredients_text(rec)
	ing.add_theme_font_size_override("font_size", 13)
	ing.add_theme_color_override("font_color", Color(0.8, 0.85, 0.75) if have else Color(1.0, 0.55, 0.45))
	ing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(ing)
	var btn_text := "Craft"
	if not have:
		btn_text = "Missing"
	elif _station != "" and not info["exists"]:
		btn_text = "No station"
	elif _station != "" and not info["near"]:
		btn_text = "Walk & craft"
	var b := _mk_btn(btn_text, _start.bind(rec, 1), Vector2(130, 56))
	b.disabled = not can
	h.add_child(b)
	var b5 := _mk_btn("×5", _start.bind(rec, 5), Vector2(64, 56))
	b5.disabled = not can
	h.add_child(b5)
	return panel

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

func _layout_safe() -> void:
	if _root == null:
		return
	var pad_l := 14.0
	var pad_t := 12.0
	var pad_r := 14.0
	var pad_b := 12.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var view := get_viewport_rect().size
		var win := Vector2(DisplayServer.window_get_size())
		if win.x > 0.0 and win.y > 0.0:
			pad_l = maxf(14.0, safe.position.x * view.x / win.x)
			pad_t = maxf(12.0, safe.position.y * view.y / win.y)
			pad_r = maxf(14.0, (win.x - (safe.position.x + safe.size.x)) * view.x / win.x)
			pad_b = maxf(12.0, (win.y - (safe.position.y + safe.size.y)) * view.y / win.y)
	_root.offset_left = pad_l
	_root.offset_top = pad_t
	_root.offset_right = -pad_r
	_root.offset_bottom = -pad_b

func _mk_btn(text: String, cb: Callable, minsz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minsz
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(cb)
	return b
