class_name ItemInspectPanel
extends Control
## The inspection panel of the bag family (spec 13 s10-11; the Bag, storage-transfer and in-game Bag
## references), the storage view's right panel and the in-game Bag's floating card: a tan title band
## with the item's name, a tan card with its art, kind and "Lv. N" over a line with its durability and
## processing count (the hammer "×3"), then the item's families as chips (its categories: what a
## recipe can use it as), its state ("Raw") and traits as chips in gold (positive), grey (negative) and
## green (rare), and black bars that fold their rows: Info (energy, pet food, damage, held, ..., the
## item's colour and a plain description), Maintenance and Create (InvCardFacts reads them all). Only
## the actions valid for this item show: one yellow primary, the rest dark.

signal action_pressed(action: StringName)

## Toolbar actions the Bag offers itself (its Lock square), so the panel does not repeat them.
var toolbar_actions: Array[StringName] = [&"lock", &"unlock"]
var stack: ItemStack
var ctx := {}
var _notes: Array[Dictionary] = [] # {text, color}: reasons and warnings, read in full above the chips
var _stats: Array = [] # [label, value, colour] on the card's lower line (durability, processing)
var _families: Array[String] = [] # category ids
var _traits: Array[Dictionary] = [] # {text, color, cls}
var _states: Array = [] # [text, colour] chips before the traits ("Raw")
var _rows: Array[Dictionary] = []  # {text, value, color} under Info
var _colour := Color(0, 0, 0, 0) # the instance's tint (a = 0: none)
var _flavour := ""
var _sections: Array = [] # {id, title, rows: [[key, value, colour]]} after Info
var _actions: Array[StringName] = []
var _title := ""
## A caged animal's grade ("B"), in a disc before the title as the Bag reference's Zebraceratops.
var _grade := ""
var _kind := ""
var _sub := ""
var _m := {}
## Which bars are open (Info and Maintenance open, Create folded, as the reference shows them).
var _open := {&"info": true, &"care": true, &"make": false}
var _deco: Control
var _scroll: ScrollContainer
var _box: VBoxContainer
var _buttons: Array[Button] = []

## The in-game Bag's card ends under its content (a bone's card left ~170 px empty, review r1), up to
## this height; 0 keeps the size the screen gives (storage, the picker).
var fit_max_h := 0.0
var _built_w := -1.0
var _fit_queued := false

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
	resized.connect(_on_resized)
	# A chip row wraps only once the scroll has laid it out at its width: the card re-fits then (the
	# bone's card measured one row of chips, stopped short and scrolled its Info away, review r1).
	_box.minimum_size_changed.connect(_queue_fit)

func _on_resized() -> void:
	if absf(size.x - _built_w) > 0.5:
		_rebuild() # chip widths follow the panel's
	else:
		_layout() # a new height (the fit) moves only the scroll and the pinned actions

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
	_states.clear()
	_rows.clear()
	_colour = Color(0, 0, 0, 0)
	_flavour = ""
	_sections.clear()
	_actions.clear()
	_grade = ""
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
	if _grade != "":
		out.append("Grade %s" % _grade)
	for n in _notes:
		out.append(str(n.text))
	for st: Array in _stats:
		out.append("%s  %s" % [st[0], st[1]])
	for f in _families:
		out.append(family_label(f))
	for st: Array in _states:
		out.append(str(st[0]))
	for t in _traits:
		out.append(str(t.text))
	for r in _rows:
		out.append(("%s  %s" % [r.text, r.value]).strip_edges())
	if _colour.a > 0.0:
		out.append("Colour  #%s" % _colour.to_html(false).to_upper())
	if _flavour != "":
		out.append(_flavour)
	for sec: Dictionary in _sections:
		out.append(str(sec.title))
		for r: Array in sec.rows:
			out.append(("%s  %s" % [r[0], r[1]]).strip_edges())
	return out

func actions() -> Array[StringName]:
	return _actions.duplicate()

## Enter (spec 13 s21): runs the yellow primary, as a tap on it would. False when none is offered.
func press_primary() -> bool:
	if _actions.is_empty():
		return false
	action_pressed.emit(_actions[0])
	return true

## The button that runs `action` now (null when it is not offered).
func button_for(action: StringName) -> Button:
	for b in _buttons:
		if b.get_meta(&"action", &"") == action:
			return b
	return null

## Gold for positive traits, grey for negative, green for rare (spec 13 s11); the chips add the shape.
func section_color(cls: StringName) -> Color:
	return InvPaint.pip_color(cls) if InvPaint.PIP_SHAPES.has(cls) else InvTheme.TEXT

## "Raw Meat", or the data label for ids that do not read well capitalised ("Blade Material").
static func family_label(cat: String) -> String:
	return str((InvView.data().get("category_labels", {}) as Dictionary).get(cat, LevelDisplay.nice_name(cat)))

## The white pictogram a family chip shows (data/inv_ui.json family_icons, else the icon of the bag
## filter holding that category): Durango's chips are distinct white family glyphs, where the item's
## own art three times over said nothing (review r1). &"" when neither has one.
static func family_icon(cat: String) -> StringName:
	var own: Variant = (InvView.data().get("family_icons", {}) as Dictionary).get(cat)
	if own is String:
		return StringName(own)
	for f: Dictionary in InvView.filters():
		if cat in (f.get("categories", []) as Array):
			return StringName(str(f.get("icon", "")))
	return &""

func _fill(s: ItemStack) -> void:
	var f := InvCardFacts.of(s, ctx.get("player") as Player)
	_title = str(f.title)
	_grade = str(f.get("grade", ""))
	_kind = str(f.kind)
	_sub = str(f.sub)
	_stats = f.stats
	for c: String in f.families:
		_families.append(c)
	_states = f.states
	for t: Dictionary in f.traits:
		_traits.append(t)
	for r: Array in f.info:
		_row(str(r[0]), str(r[1]), r[2])
	_colour = f.colour
	_flavour = str(f.flavour)
	_sections = f.sections

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
	var rows_n := 0 if _tucked() else ceili(float(_actions.size() - 1) / 2.0)
	return float(_m.primary_h) + rows_n * (float(_m.secondary_h) + 6.0) + float(_m.margin) * 2.0

## A phone's panel is short: only the yellow primary stays pinned at the bottom and the other actions
## scroll in under the rows (pinned, two 56 px rows of them left the in-game card no room to read).
func _tucked() -> bool:
	return bool(_m.get("compact", false))

func _rebuild() -> void:
	if _m.is_empty():
		return
	_built_w = size.x
	for c in _box.get_children():
		_box.remove_child(c)
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
			var per := 3 if _m.compact or _inner_w() < 320.0 else 4 # the floating card: three a row, as the in-game reference
			var w := maxf(44.0, floorf((_inner_w() - float(per - 1) * 6.0) / float(per)))
			for f in _families: # every chip one width, so a long name never breaks the row of three
				flow.add_child(_FamilyChip.new(family_label(f), family_icon(f), stack.def_id, w, px))
		if not _traits.is_empty() or not _states.is_empty():
			var flow := _flow()
			for st: Array in _states:
				flow.add_child(TraitChip.new(str(st[0]), &"state", px, st[1]))
			for t in _traits:
				flow.add_child(TraitChip.new(str(t.text), t.cls, px))
		if not _rows.is_empty() or _colour.a > 0.0 or _flavour != "":
			_box.add_child(_section_bar("Info", &"info"))
	if not stack or _open[&"info"]:
		for r in _rows:
			_box.add_child(_text_row(str(r.text), str(r.value), r.color, false))
		if stack and _colour.a > 0.0:
			_box.add_child(_Swatch.new(_colour, float(_m.row_h) * 1.5))
		if stack and _flavour != "":
			_box.add_child(_text_row(_flavour, "", InvTheme.TEXT, true))
	for sec: Dictionary in _sections:
		_box.add_child(_section_bar(str(sec.title), sec.id))
		if _open.get(sec.id, true):
			for r: Array in sec.rows:
				_box.add_child(_text_row(str(r[0]), str(r[1]), r[2], false))
	for b in _buttons:
		if b.get_parent() == self: # tucked ones went with the scroll's rows above
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
		b.disabled = a in (ctx.get("disabled", []) as Array) # shown, not offered: the notes say why
		if i == 0:
			InvTheme.style_primary(b, int(_m.button_font))
		else:
			InvTheme.set_px(b, int(_m.button_font) - (2 if _m.compact else 6))
		b.pressed.connect(func() -> void: action_pressed.emit(a))
		if i > 0 and _tucked():
			b.custom_minimum_size = Vector2(0, _m.secondary_h)
			var pad := MarginContainer.new() # clear of the scrollbar, a gap under the row above
			pad.add_theme_constant_override("margin_right", 10)
			pad.add_theme_constant_override("margin_top", 6)
			pad.add_child(b)
			_box.add_child(pad)
		else:
			add_child(b)
		_buttons.append(b)
	_layout()
	_queue_fit()

## Height the card's content takes: band, card, the scroll's rows, the pinned actions.
func content_height() -> float:
	var pad: float = _m.margin
	return _band_h() + (_card_h() if stack else 0.0) + pad * 2.0 + _box.get_combined_minimum_size().y + _actions_h()

## Shrinks (or grows back, up to fit_max_h) to the content once its rows have wrapped.
func _fit() -> void:
	if not is_inside_tree() or fit_max_h <= 0.0 or _m.is_empty():
		_fit_queued = false
		return
	await get_tree().process_frame
	_fit_queued = false
	if fit_max_h > 0.0:
		size.y = minf(fit_max_h, ceilf(content_height()))

func _queue_fit() -> void:
	if fit_max_h > 0.0 and not _fit_queued:
		_fit_queued = true
		_fit.call_deferred()
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
	InvTheme.set_px(k, px)
	k.add_theme_color_override("font_color", color)
	row.add_child(k)
	if value != "":
		var v := Label.new()
		v.text = value
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		InvTheme.set_px(v, px)
		v.add_theme_color_override("font_color", color)
		row.add_child(v)
	var gutter := Control.new() # keeps values clear of the scrollbar
	gutter.custom_minimum_size = Vector2(10, 0)
	row.add_child(gutter)
	return row

## Durango's black section bar ("Info", "Maintenance", "Create"); its caret folds the rows under it.
func _section_bar(title: String, id: StringName) -> Button:
	var open: bool = _open.get(id, true)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, maxf(44.0, float(_m.row_h) * 1.1))
	b.tooltip_text = ("Hide " if open else "Show ") + title
	b.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, b.size - Vector2(10, 0))
		b.draw_rect(r, Color(0.02, 0.025, 0.02, 0.85))
		var ipx: int = _m.section_font
		var f := InvTheme.font_at(ipx)
		b.draw_string(f, Vector2(float(_m.margin) * 0.5, (r.size.y + f.get_ascent(ipx) - f.get_descent(ipx)) * 0.5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ipx, InvTheme.TEXT_2)
		var c := Vector2(r.end.x - r.size.y * 0.5, r.size.y * 0.5)
		var t := r.size.y * 0.16
		var up := 1.0 if open else -1.0
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-t, t * 0.6 * up), c + Vector2(t, t * 0.6 * up), c + Vector2(0, -t * 0.7 * up)]), InvGlyphs.WHITE))
	b.pressed.connect(func() -> void:
		_open[id] = not open
		_rebuild())
	return b

## Folds or opens one bar (&"info", &"care", &"make"), as a tap on it does.
func set_section_open(id: StringName, on: bool) -> void:
	_open[id] = on
	_rebuild()

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
		var rest: Array = [] if _tucked() else _buttons.slice(1)
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
	var fn := InvTheme.font_at(npx)
	var title := UiTokens.ellipsis(fn, _title, size.x - float(_m.margin) * 2.0, npx)
	var tw := fn.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, npx).x
	var tx := (size.x - tw) * 0.5
	if _grade != "": # the grade disc before the name, the pair centred together
		var gr := band.size.y * 0.3
		tx += gr + 4.0
		var gc := Vector2(tx - gr - 8.0, band.size.y * 0.5)
		_deco.draw_circle(gc, gr, Color("#5C4C30"))
		_deco.draw_arc(gc, gr, 0.0, TAU, 32, Color(0, 0, 0, 0.35), 1.5, true)
		var gpx := roundi(gr * 1.3)
		var gf := InvTheme.font_at(gpx)
		UiTokens.draw_centered(_deco, gf, gc, _grade, gpx, InvTheme.TEXT)
	_deco.draw_string(fn, Vector2(tx, (band.size.y + fn.get_ascent(npx) - fn.get_descent(npx)) * 0.5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, npx, InvTheme.PRIMARY_INK)
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

## One family chip: a dark box with the family's white pictogram, its name under it (storage and
## in-game references). Every chip is `w` wide: a long name steps down to the type floor, then
## shortens with an ellipsis (its tooltip keeps it whole).
class _FamilyChip extends Control:
	var text := ""
	var icon: StringName
	var art: StringName ## the item's own art, only when the family has no pictogram
	var px := 14

	func _init(t: String, ic: StringName, own: StringName, w: float, font_px: int) -> void:
		icon = ic
		art = own
		px = maxi(UiTokens.TYPE_MIN, font_px - 2)
		while px > UiTokens.TYPE_MIN and InvTheme.font_at(px).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > w - 4.0:
			px -= 1
		text = UiTokens.ellipsis(InvTheme.font_at(px), t, w - 4.0, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(w, roundf(w * 0.62) + px * 1.6)
		tooltip_text = t

	func _draw() -> void:
		var bw := size.x
		var box := Rect2(Vector2.ZERO, Vector2(bw, size.y - px * 1.6))
		draw_style_box(InvTheme.button_box(Color(0.03, 0.035, 0.03, 0.85), Color(0, 0, 0, 0), 4), box)
		var tex := UiIcons.icon(icon) if icon != &"" else null
		if tex:
			var s := box.size.y * 0.78 # the icon set's glyphs carry their own margin
			draw_texture_rect(tex, Rect2(box.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), false, InvGlyphs.WHITE)
		else:
			InvPaint.item_icon(self, art, box, 0.78, 0.5)
		var f := InvTheme.font_at(px)
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, Vector2((bw - w) * 0.5, box.end.y + 4.0 + f.get_ascent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, InvTheme.TEXT)

## One trait chip (storage reference: "Firm Lv. 4" gold, "Heavy Lv. 2" grey): the class's pip shape
## before the text, so positive / negative / rare read without colour too (spec 13 s11; B4).
## A `cls` of &"state" is the item's state ("Raw", the in-game reference's "Cru"): no pip, in `ink`.
class TraitChip extends Control:
	const CLASS_WORDS := {&"positive": "Positive trait", &"negative": "Negative trait", &"rare": "Rare trait", &"state": "State"}
	var text := ""
	var cls: StringName = &"positive"
	var px := 14
	var ink := Color(0, 0, 0, 0)

	func _init(t: String, c: StringName, font_px: int, color: Color = Color(0, 0, 0, 0)) -> void:
		text = t
		cls = c
		px = font_px
		ink = color if color.a > 0.0 else InvPaint.pip_color(c)
		tooltip_text = "%s: %s" % [CLASS_WORDS.get(c, "Trait"), t]
		var f := InvTheme.font_at(px)
		custom_minimum_size = Vector2(f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + _pip_px() + (22.0 if _pip_px() > 0.0 else 16.0), roundf(px * 1.9))

	func _pip_px() -> float:
		return maxf(6.0, roundf(px * 0.45)) if InvPaint.PIP_SHAPES.has(cls) else 0.0

	func _draw() -> void:
		draw_style_box(InvTheme.button_box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 4), Rect2(Vector2.ZERO, size))
		var p := _pip_px()
		if p > 0.0:
			InvPaint.pip(self, Rect2(Vector2(8.0, (size.y - p) * 0.5), Vector2(p, p)), cls)
		var f := InvTheme.font_at(px)
		draw_string(f, Vector2(8.0 + (p + 6.0 if p > 0.0 else 0.0), (size.y + f.get_ascent(px) - f.get_descent(px)) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, ink)

## The item's colour (its tint) as Durango's hexagon swatch; the hex code is its tooltip and a row in
## rows(), so the colour is never the only way to read it.
class _Swatch extends Control:
	var colour := Color.WHITE

	func _init(c: Color, side: float) -> void:
		colour = c
		custom_minimum_size = Vector2(side, side)
		tooltip_text = "Colour #%s" % c.to_html(false).to_upper()

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.42
		var c := Vector2(r + 8.0, size.y * 0.5)
		var pts := PackedVector2Array()
		for k in 6:
			pts.append(c + Vector2.from_angle(PI / 6.0 + k * PI / 3.0) * r)
		draw_colored_polygon(pts, colour)
		pts.append(pts[0])
		draw_polyline(pts, Color(0.02, 0.02, 0.02, 0.9), maxf(2.0, r * 0.12), true)
