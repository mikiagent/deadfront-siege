class_name ItemInspectPanel
extends Control
## The right-hand inspection panel of the Bag (spec 13 s10-11): a tan title band with the item's
## name, a card with its art, type and "Lv. N", compact info rows (type, processing, durability,
## real stats), the attributes in gold (positive), grey (negative) and green (rare) under their
## section labels, and only the actions valid for this item: one yellow primary, the rest dark.

signal action_pressed(action: StringName)

## Toolbar actions the Bag offers itself (its Lock square), so the panel does not repeat them.
var toolbar_actions: Array[StringName] = [&"lock", &"unlock"]
var stack: ItemStack
var ctx := {}
var _rows: Array[Dictionary] = []  # {text, value, color, section}
var _actions: Array[StringName] = []
var _title := ""
var _kind := ""
var _sub := ""
var _m := {}
var _deco: Control
var _scroll: ScrollContainer
var _box: VBoxContainer
var _buttons: Array[Button] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	add_child(InvTheme.surface(InvTheme.PANEL_2, 0.8, 3.0))
	_deco = Control.new()
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 0)
	_scroll.add_child(_box)
	resized.connect(_layout)

func apply_metrics(m: Dictionary) -> void:
	_m = m
	_rebuild()

## Shows `s` in context `c` ({where, player, ...}); null shows `summary` rows ([key, value]) instead.
## Screens that own their moves (storage, the picker) pass c.actions (the yellow primary first),
## c.notes ([text, colour] lines over the item's rows) and c.title (the title with nothing shown).
func show_stack(s: ItemStack, c: Dictionary, summary: Array = []) -> void:
	stack = s
	ctx = c
	_rows.clear()
	_actions.clear()
	for n: Array in c.get("notes", []):
		_rows.append({"text": str(n[0]), "value": "", "color": n[1], "wrap": true}) # a reason reads in full
	if s == null:
		_title = str(c.get("title", "Bag"))
		_sub = ""
		for pair: Array in summary:
			_row(str(pair[0]), str(pair[1]) if pair.size() > 1 else "", InvTheme.TEXT_2)
	else:
		_fill(s)
	for a: StringName in (c.actions if c.has("actions") else InvActions.valid(s, c)):
		if a not in toolbar_actions:
			_actions.append(a)
	_rebuild()

func title_text() -> String:
	return _title

## Every line the panel shows, as plain text (tests and the lab read these).
func rows() -> PackedStringArray:
	var out := PackedStringArray()
	if _sub != "":
		out.append(_sub)
	for r in _rows:
		out.append(("%s  %s" % [r.text, r.value]).strip_edges())
	return out

func actions() -> Array[StringName]:
	return _actions.duplicate()

## Gold for positive traits, grey for negative, green for rare (spec 13 s11).
func section_color(cls: StringName) -> Color:
	match cls:
		&"positive":
			return InvTheme.POSITIVE
		&"negative":
			return InvTheme.TEXT_2
		&"rare":
			return InvTheme.RARE
	return InvTheme.TEXT

func _fill(s: ItemStack) -> void:
	var d := s.def()
	var item_name := d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(s.def_id))
	var species := str(s.attributes.get("species", ""))
	# A caged animal is titled by its species, as Durango titles the cage "Zebraceratops".
	_title = LevelDisplay.nice_name(species) if species != "" else item_name
	_kind = item_name if species != "" else (LevelDisplay.nice_name(str(d.categories[0])) if d and not d.categories.is_empty() else "")
	_sub = LevelDisplay.label(s.level) if s.level > 0 else ""
	var player: Player = ctx.get("player") as Player
	if d and not d.categories.is_empty() and species == "":
		_row("Type", LevelDisplay.nice_name(str(d.categories[0])))
	if s.def_id == &"captured_animal":
		_row("Bond it at a taming pen", "", InvTheme.TEXT_2)
	if s.is_fungible() and s.count > 1:
		_row("Count", "%d" % s.count)
	if s.process_count > 0:
		_row("Processed", "%d" % s.process_count)
	if s.max_durability > 0:
		_row("Durability", "%d / %d%s" % [s.durability, s.max_durability, "  Broken" if s.is_broken() else ""], InvTheme.DANGER if s.is_broken() else InvTheme.TEXT)
	if s.scaled_damage() > 0.0:
		_row("Damage", "%.0f" % s.scaled_damage())
	if s.scaled_armor() > 0.0:
		_row("Armor", "%.0f" % s.scaled_armor())
	if d and d.health_bonus > 0.0:
		_row("Max health", "+%.0f" % d.health_bonus_at(s.level))
	if d and d.tool_class not in [&"", &"none"]:
		_row("Tool", "%s  %.2fx" % [str(d.tool_class).capitalize(), s.gather_power()])
	if Food.is_food(s):
		_row("Energy", "+%.0f" % Food.energy_restore(s))
		if Food.is_raw(s):
			_row("Raw", "may upset the stomach", InvTheme.TEXT_2)
		if Food.is_poisoned(s):
			_row("Poisoned", "", InvTheme.DANGER)
		var buffs := Food.buff_ids(s)
		if not buffs.is_empty():
			_row("Buffs", ", ".join(PackedStringArray(buffs.map(func(b: StringName) -> String: return LevelDisplay.nice_name(str(b))))))
	if player and player.inventory.equipped_tool_index >= 0 and player.inventory.slots[player.inventory.equipped_tool_index] == s:
		_row("Held tool", "", InvTheme.SELECT)
	if s.is_locked():
		_row("Locked", "", InvTheme.TEXT_2)
	if s.is_unstable(): # W2-INV's "U" pip: lost if carried off the unstable island on foot
		_row("Unstable", "cargo warp it home", InvTheme.TEXT_2)
	var sec := InvAttributes.sections(s)
	for cls in [&"positive", &"negative", &"rare"]:
		var list: Array = sec[str(cls)]
		if list.is_empty():
			continue
		_rows.append({"text": str(cls).capitalize(), "value": "", "color": InvTheme.TEXT_OFF, "section": true})
		for r: Dictionary in list:
			_rows.append({"text": InvAttributes.line(r), "value": "", "color": section_color(cls)})

func _row(key: String, value: String, color: Color = InvTheme.TEXT) -> void:
	_rows.append({"text": key, "value": value, "color": color})

# ---------------------------------------------------------------- layout

func _band_h() -> float:
	return roundf(float(_m.name_font) * 1.9)

func _card_h() -> float:
	return roundf(float(_m.name_font) * (2.6 if not _m.compact else 2.4))

## Durango's black "Info" bar over the rows.
func _info_h() -> float:
	return roundf(float(_m.row_h) * 1.1) if not _rows.is_empty() else 0.0

func _actions_h() -> float:
	if _actions.is_empty():
		return 0.0
	var rows_n := ceili(float(_actions.size() - 1) / 2.0)
	return float(_m.primary_h) + rows_n * (float(_m.secondary_h) + 6.0) + float(_m.margin) * 2.0

func _rebuild() -> void:
	if _m.is_empty():
		return
	for c in _box.get_children():
		c.queue_free()
	var px: int = _m.row_font
	for r in _rows:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, float(_m.row_h) * (0.85 if r.get("section", false) else 1.0))
		var k := Label.new()
		k.text = str(r.text)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if r.get("wrap", false):
			k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			k.custom_minimum_size.x = 40.0 # wraps to the row's width instead of widening it
			k.add_theme_constant_override("line_spacing", -roundi(px * 0.6)) # the font's tall line box read as two rows
		else:
			k.clip_text = true
			k.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		k.add_theme_font_size_override("font_size", int(_m.section_font) if r.get("section", false) else px)
		k.add_theme_color_override("font_color", r.color)
		row.add_child(k)
		if str(r.value) != "":
			var v := Label.new()
			v.text = str(r.value)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			v.add_theme_font_size_override("font_size", px)
			v.add_theme_color_override("font_color", r.color)
			row.add_child(v)
		var gutter := Control.new() # keeps values clear of the scrollbar
		gutter.custom_minimum_size = Vector2(10, 0)
		row.add_child(gutter)
		_box.add_child(row)
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	for i in _actions.size():
		var a := _actions[i]
		var b := Button.new()
		b.text = InvActions.label(a)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_to_group(&"inv_contextual")
		if i == 0:
			InvTheme.style_primary(b, int(_m.button_font))
		else:
			b.add_theme_font_size_override("font_size", int(_m.button_font) - (2 if _m.compact else 6))
		b.pressed.connect(func() -> void: action_pressed.emit(a))
		add_child(b)
		_buttons.append(b)
	_layout()

func _layout() -> void:
	if _m.is_empty():
		return
	var pad: float = _m.margin
	var top := _band_h() + (_card_h() + _info_h() if stack else 0.0)
	var bottom := size.y - _actions_h()
	_scroll.position = Vector2(pad, top + pad * (1.0 if stack else 0.5))
	_scroll.size = Vector2(size.x - pad * 2.0, maxf(0.0, bottom - _scroll.position.y))
	if not _buttons.is_empty():
		# The first action is the yellow primary along the bottom; the rest sit above it, two a row.
		var w := size.x - pad * 2.0
		var y := size.y - pad - float(_m.primary_h)
		_buttons[0].position = Vector2(pad, y)
		_buttons[0].size = Vector2(w, _m.primary_h)
		var rest := _buttons.slice(1)
		var rows_n := ceili(float(rest.size()) / 2.0)
		var half := (w - 6.0) * 0.5
		for i in rest.size():
			var row := i / 2
			var col := i % 2
			var alone := col == 0 and i == rest.size() - 1
			var b: Button = rest[i]
			b.size = Vector2(w if alone else half, _m.secondary_h)
			b.position = Vector2(pad + col * (half + 6.0), y - (rows_n - row) * (float(_m.secondary_h) + 6.0))
	_deco.queue_redraw()

func _draw_deco() -> void:
	if _m.is_empty():
		return
	var f := InvTheme.font()
	var band := Rect2(Vector2.ZERO, Vector2(size.x, _band_h()))
	_deco.draw_rect(band, InvTheme.TAN)
	_deco.draw_dashed_line(Vector2(0, band.end.y), Vector2(size.x, band.end.y), Color(0, 0, 0, 0.45), 1.5, 5.0)
	var npx: int = _m.name_font
	var title := UiTokens.ellipsis(f, _title, size.x - float(_m.margin) * 2.0, npx)
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x
	_deco.draw_string(f, Vector2((size.x - tw) * 0.5, (band.size.y + f.get_ascent(npx) - f.get_descent(npx)) * 0.5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, InvTheme.PRIMARY_INK)
	if stack:
		var card := Rect2(Vector2(0, band.end.y), Vector2(size.x, _card_h()))
		_deco.draw_rect(card, Color(InvTheme.TAN_DARK, 0.55))
		var pad: float = _m.margin
		var icon := Rect2(card.position + Vector2(pad, pad * 0.5), Vector2(card.size.y - pad, card.size.y - pad))
		_deco.draw_rect(icon, Color(0, 0, 0, 0.35))
		InvPaint.item_icon(_deco, stack.def_id, icon, 0.86, 0.5)
		var x := icon.end.x + pad
		var spx: int = _m.row_font
		_deco.draw_string(f, Vector2(x, card.position.y + card.size.y * 0.42), UiTokens.ellipsis(f, _kind, size.x - x - pad, spx), HORIZONTAL_ALIGNMENT_LEFT, -1, spx, InvTheme.TEXT)
		if _sub != "":
			_deco.draw_string(f, Vector2(x, card.position.y + card.size.y * 0.42 + float(npx) * 1.1), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, InvTheme.TEXT)
		if _info_h() > 0.0:
			var bar := Rect2(Vector2(0, card.end.y + pad * 0.5), Vector2(size.x, _info_h()))
			_deco.draw_rect(bar, Color(0.02, 0.025, 0.02, 0.85))
			var ipx: int = _m.section_font
			_deco.draw_string(f, Vector2(pad, bar.position.y + (bar.size.y + f.get_ascent(ipx) - f.get_descent(ipx)) * 0.5), "Info", HORIZONTAL_ALIGNMENT_LEFT, -1, ipx, InvTheme.TEXT_2)
	if not _buttons.is_empty():
		var y := size.y - _actions_h()
		_deco.draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.4), 1.0)
	_deco.draw_rect(Rect2(Vector2.ZERO, size), InvTheme.BORDER, false, 2.0)
