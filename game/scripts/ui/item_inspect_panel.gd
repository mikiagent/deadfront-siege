class_name ItemInspectPanel
extends Control
## The right-hand inspection panel of the bag family (spec 13 s10-11; the Bag and storage-transfer
## references): a tan title band with the item's name, a tan card with its art, kind and "Lv. N" over
## a line with its durability and processing count (the hammer "×3"), then the item's families as
## chips (its categories: what a recipe can use it as), its traits as chips in gold (positive), grey
## (negative) and green (rare), and the black "Info" bar that folds the compact rows (energy, damage,
## held, ...). Only the actions valid for this item show: one yellow primary, the rest dark.

signal action_pressed(action: StringName)

## Toolbar actions the Bag offers itself (its Lock square), so the panel does not repeat them.
var toolbar_actions: Array[StringName] = [&"lock", &"unlock"]
var stack: ItemStack
var ctx := {}
var _notes: Array[Dictionary] = [] # {text, color}: reasons and warnings, read in full above the chips
var _stats: Array = [] # [label, value, colour] on the card's lower line (durability, processing)
var _families: Array[String] = [] # category ids
var _traits: Array[Dictionary] = [] # {text, color}
var _rows: Array[Dictionary] = []  # {text, value, color} under Info
var _actions: Array[StringName] = []
var _title := ""
var _kind := ""
var _sub := ""
var _m := {}
var _info_open := true
var _deco: Control
var _scroll: ScrollContainer
var _box: VBoxContainer
var _buttons: Array[Button] = []

static var _no_bag: Inventory

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
	resized.connect(_rebuild) # chip widths follow the panel's

func apply_metrics(m: Dictionary) -> void:
	_m = m
	_rebuild()

## Shows `s` in context `c` ({where, player, ...}); null shows `summary` rows ([key, value]) instead.
## Screens that own their moves (storage, the picker) pass c.actions (the yellow primary first),
## c.notes ([text, colour] lines read in full first), c.labels ({action: button text}) and c.title
## (the title with nothing shown).
func show_stack(s: ItemStack, c: Dictionary, summary: Array = []) -> void:
	stack = s
	ctx = c
	_notes.clear()
	_stats.clear()
	_families.clear()
	_traits.clear()
	_rows.clear()
	_actions.clear()
	for n: Array in c.get("notes", []):
		_notes.append({"text": str(n[0]), "color": n[1]})
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
	for n in _notes:
		out.append(str(n.text))
	for st: Array in _stats:
		out.append("%s  %s" % [st[0], st[1]])
	for f in _families:
		out.append(family_label(f))
	for t in _traits:
		out.append(str(t.text))
	for r in _rows:
		out.append(("%s  %s" % [r.text, r.value]).strip_edges())
	return out

func actions() -> Array[StringName]:
	return _actions.duplicate()

## The button that runs `action` now (null when it is not offered).
func button_for(action: StringName) -> Button:
	for b in _buttons:
		if b.get_meta(&"action", &"") == action:
			return b
	return null

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

## "Raw Meat", or the data label for ids that do not read well capitalised ("Blade Material").
static func family_label(cat: String) -> String:
	return str((InvView.data().get("category_labels", {}) as Dictionary).get(cat, LevelDisplay.nice_name(cat)))

## The art a family chip shows: an item of that family (the crafting menu's own representative), else
## the inspected item's.
static func family_art(cat: String, own: StringName) -> StringName:
	if _no_bag == null:
		_no_bag = Inventory.new(0)
	var rep := Crafting.sample_def_for_category(_no_bag, StringName(cat))
	return rep if Data.item(rep) != null else own

func _fill(s: ItemStack) -> void:
	var d := s.def()
	var item_name := d.display_name if d and d.display_name != "" else LevelDisplay.nice_name(str(s.def_id))
	var species := str(s.attributes.get("species", ""))
	# A caged animal is titled by its species, as Durango titles the cage "Zebraceratops".
	_title = LevelDisplay.nice_name(species) if species != "" else item_name
	_kind = item_name
	_sub = LevelDisplay.label(s.level) if s.level > 0 else ""
	var player: Player = ctx.get("player") as Player
	if s.max_durability > 0:
		_stats.append(["Durability", "%d / %d%s" % [s.durability, s.max_durability, "  Broken" if s.is_broken() else ""], InvTheme.DANGER if s.is_broken() else InvTheme.PRIMARY_INK])
	if s.process_count > 0:
		_stats.append(["Processed", "×%d" % s.process_count, InvTheme.PRIMARY_INK])
	if d and species == "":
		for c in d.categories:
			_families.append(str(c))
	var sec := InvAttributes.sections(s)
	for cls in [&"positive", &"negative", &"rare"]:
		for r: Dictionary in sec[str(cls)]:
			_traits.append({"text": InvAttributes.line(r), "color": section_color(cls)})
	if s.def_id == &"captured_animal":
		_row("Bond it at a taming pen", "", InvTheme.TEXT_2)
	if s.is_fungible() and s.count > 1:
		_row("Count", "%d" % s.count)
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

func _row(key: String, value: String, color: Color = InvTheme.TEXT) -> void:
	_rows.append({"text": key, "value": value, "color": color})

# ---------------------------------------------------------------- layout

func _band_h() -> float:
	return roundf(float(_m.name_font) * 1.9)

func _card_main_h() -> float:
	return roundf(float(_m.name_font) * (2.6 if not _m.compact else 2.4))

## The card's lower line (durability, the hammer count) when the item has either.
func _stat_h() -> float:
	return roundf(float(_m.name_font) * 1.3) if not _stats.is_empty() else 0.0

func _card_h() -> float:
	return _card_main_h() + _stat_h()

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
	for n in _notes:
		_box.add_child(_text_row(str(n.text), "", n.color, true))
	if not _notes.is_empty() and stack:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, float(_m.gap) * 0.5)
		_box.add_child(gap)
	if stack:
		if not _families.is_empty():
			var flow := _flow()
			var per := 3 if _m.compact else 4
			var w := maxf(44.0, floorf((_inner_w() - float(per - 1) * 6.0) / float(per)))
			for f in _families:
				flow.add_child(_FamilyChip.new(family_label(f), family_art(f, stack.def_id), w, px))
		if not _traits.is_empty():
			var flow := _flow()
			for t in _traits:
				var chip := Label.new()
				chip.text = str(t.text)
				chip.add_theme_font_size_override("font_size", px)
				chip.add_theme_color_override("font_color", t.color)
				var sb := InvTheme.button_box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 4)
				sb.content_margin_top = 4
				sb.content_margin_bottom = 4
				chip.add_theme_stylebox_override("normal", sb)
				flow.add_child(chip)
		if not _rows.is_empty():
			_box.add_child(_info_bar())
	if not stack or _info_open:
		for r in _rows:
			_box.add_child(_text_row(str(r.text), str(r.value), r.color, false))
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	var labels: Dictionary = ctx.get("labels", {})
	for i in _actions.size():
		var a := _actions[i]
		var b := Button.new()
		b.text = str(labels.get(a, InvActions.label(a)))
		b.set_meta(&"action", a)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_to_group(&"inv_contextual")
		if i == 0:
			InvTheme.style_primary(b, int(_m.button_font))
		else:
			b.add_theme_font_size_override("font_size", int(_m.button_font) - (2 if _m.compact else 6))
		b.pressed.connect(func() -> void: action_pressed.emit(a))
		add_child(b)
		_buttons.append(b)
	_layout()

func _inner_w() -> float:
	return size.x - float(_m.margin) * 2.0 - 22.0 # the chip row's right margin and the scrollbar

## A wrapping row of chips added to the scroll, with room under it.
func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_bottom", int(_m.gap))
	pad.add_theme_constant_override("margin_right", 10) # the scroll's gutter
	pad.add_child(flow)
	_box.add_child(pad)
	return flow

func _text_row(text: String, value: String, color: Color, wrap: bool) -> HBoxContainer:
	var px: int = _m.row_font
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, float(_m.row_h))
	var k := Label.new()
	k.text = text
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if wrap: # a reason or warning reads in full
		k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		k.custom_minimum_size.x = 40.0 # wraps to the row's width instead of widening it
		k.add_theme_constant_override("line_spacing", -roundi(px * 0.6)) # the font's tall line box read as two rows
	else:
		k.clip_text = true
		k.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.add_theme_font_size_override("font_size", px)
	k.add_theme_color_override("font_color", color)
	row.add_child(k)
	if value != "":
		var v := Label.new()
		v.text = value
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_theme_font_size_override("font_size", px)
		v.add_theme_color_override("font_color", color)
		row.add_child(v)
	var gutter := Control.new() # keeps values clear of the scrollbar
	gutter.custom_minimum_size = Vector2(10, 0)
	row.add_child(gutter)
	return row

## Durango's black "Info" bar; its caret folds the rows under it.
func _info_bar() -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, maxf(44.0, float(_m.row_h) * 1.1))
	b.tooltip_text = "Hide the details" if _info_open else "Show the details"
	b.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, b.size - Vector2(10, 0))
		b.draw_rect(r, Color(0.02, 0.025, 0.02, 0.85))
		var f := InvTheme.font()
		var ipx: int = _m.section_font
		b.draw_string(f, Vector2(float(_m.margin) * 0.5, (r.size.y + f.get_ascent(ipx) - f.get_descent(ipx)) * 0.5), "Info", HORIZONTAL_ALIGNMENT_LEFT, -1, ipx, InvTheme.TEXT_2)
		var c := Vector2(r.end.x - r.size.y * 0.5, r.size.y * 0.5)
		var t := r.size.y * 0.16
		var up := 1.0 if _info_open else -1.0
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-t, t * 0.6 * up), c + Vector2(t, t * 0.6 * up), c + Vector2(0, -t * 0.7 * up)]), InvGlyphs.WHITE))
	b.pressed.connect(func() -> void:
		_info_open = not _info_open
		_rebuild())
	return b

func _layout() -> void:
	if _m.is_empty():
		return
	var pad: float = _m.margin
	var top := _band_h() + (_card_h() if stack else 0.0)
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
		# The tan card (storage reference): art, kind and level, then durability and the hammer count.
		var card := Rect2(Vector2(0, band.end.y), Vector2(size.x, _card_h()))
		_deco.draw_rect(card, Color(InvTheme.TAN, 0.62))
		var pad: float = _m.margin
		var main_h := _card_main_h()
		var icon := Rect2(card.position + Vector2(pad, pad * 0.5), Vector2(main_h - pad, main_h - pad))
		_deco.draw_rect(icon, Color(0, 0, 0, 0.18))
		InvPaint.item_icon(_deco, stack.def_id, icon, 0.86, 0.5)
		var x := icon.end.x + pad
		var spx: int = _m.row_font
		_deco.draw_string(f, Vector2(x, card.position.y + main_h * 0.42), UiTokens.ellipsis(f, _kind, size.x - x - pad, spx), HORIZONTAL_ALIGNMENT_LEFT, -1, spx, InvTheme.PRIMARY_INK)
		if _sub != "":
			_deco.draw_string(f, Vector2(x, card.position.y + main_h * 0.42 + float(npx) * 1.1), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, InvTheme.PRIMARY_INK)
		if not _stats.is_empty():
			var ly := card.position.y + main_h
			_deco.draw_line(Vector2(pad, ly), Vector2(size.x - pad, ly), Color(0, 0, 0, 0.25), 1.0)
			var spx2 := roundi(float(npx) * 0.7) # the reference sets these a size up from the rows
			var base := ly + (_stat_h() + f.get_ascent(spx2) - f.get_descent(spx2)) * 0.5
			for st: Array in _stats:
				if st[0] == "Processed": # the hammer at the right, as Durango marks how often it was processed
					var lw := f.get_string_size(str(st[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, spx2).x
					var s := float(spx2) * 1.2
					var ix := size.x - pad - lw - s - 4.0
					var ic := UiIcons.icon(&"craft")
					if ic:
						_deco.draw_texture_rect(ic, Rect2(Vector2(ix, base - f.get_ascent(spx2) * 0.95), Vector2(s, s)), false, InvTheme.PRIMARY_INK)
					_deco.draw_string(f, Vector2(ix + s + 4.0, base), str(st[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, spx2, st[2])
				else:
					_deco.draw_string(f, Vector2(pad, base), "%s  %s" % [st[0], st[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, spx2, st[2])
	if not _buttons.is_empty():
		var y := size.y - _actions_h()
		_deco.draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.4), 1.0)
	InvPaint.frame(_deco, Rect2(Vector2.ZERO, size), 2.0 if _m.compact else 3.0, 2)

## One family chip: a dark box with an item of that family, its name under it (storage reference).
class _FamilyChip extends Control:
	var text := ""
	var art: StringName
	var px := 14

	func _init(t: String, a: StringName, w: float, font_px: int) -> void:
		text = t
		art = a
		px = maxi(UiTokens.TYPE_MIN, font_px - 2)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := InvTheme.font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 6.0
		custom_minimum_size = Vector2(maxf(w, tw), roundf(w * 0.62) + px * 1.6)
		tooltip_text = t

	func _draw() -> void:
		var bw := size.x
		var box := Rect2(Vector2.ZERO, Vector2(bw, size.y - px * 1.6))
		draw_style_box(InvTheme.button_box(Color(0.03, 0.035, 0.03, 0.85), Color(0, 0, 0, 0), 4), box)
		InvPaint.item_icon(self, art, box, 0.78, 0.5)
		var f := InvTheme.font()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, Vector2((bw - w) * 0.5, box.end.y + 4.0 + f.get_ascent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, InvTheme.TEXT)
