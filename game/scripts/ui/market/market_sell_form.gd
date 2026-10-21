class_name MarketSellForm
extends PanelContainer
## Sell's right panel for the picked instance: its name band, card and facts (read from its dict),
## a count for a stack, the unit price kept inside the reference band, the duration, and the
## fee / tax / proceeds preview from ECON's own rules (MarketFormat.preview); the yellow List
## button along the bottom. It shows and checks only; MarketSell sends the ops.
# swap: INVUI ItemInspectPanel for the band, card and facts when it reaches this base.

signal list_pressed

var entry: Dictionary = {}
var tradable := 0
var ref := 0 ## market.item_detail ref_price; 0 = no reference, so no band
var lo := 1
var hi := 1
var count := 1
var unit := 0 ## 0 = no price yet (nothing is invented: a default only comes from the market's own prices)
var hours := 24
var pending := false

var list_btn: Button
var price_edit: LineEdit
var status: Label
var duration_btns: Dictionary = {} ## hours -> Button
var steppers: Dictionary = {} ## "count_down" / "count_up" / "price_down" / "price_up" -> Button
var band_label: Label
var preview_values: Dictionary = {} ## fee / tax / receive / net -> Label
var _title: Label
var _title_band: PanelContainer
var _icon: TextureRect
var _type: Label
var _level: Label
var _facts: Label
var _form: VBoxContainer
var _count_box: VBoxContainer
var _count_label: Label
var _preview: GridContainer
var _captions: Array[Label] = []
var _keys: Array[Label] = []
var _m := {}
var _badge_r := 12.0

func _ready() -> void:
	name = "SellForm"
	var sb := MarketTheme.flat(Color(0.12, 0.15, 0.13, 0.94), MarketTheme.BORDER, 2, 4)
	sb.set_content_margin_all(0)
	add_theme_stylebox_override("panel", sb)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	_title_band = PanelContainer.new()
	var tb := MarketTheme.flat(Color(0.78, 0.7, 0.5, 0.95), Color(0, 0, 0, 0), 0, 3)
	tb.set_content_margin_all(8)
	tb.content_margin_left = 14
	_title_band.add_theme_stylebox_override("panel", tb)
	root.add_child(_title_band)
	_title = MarketTheme.label("", 22, MarketTheme.PRIMARY_TEXT)
	_title.name = "SellTitle"
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	_title_band.add_child(_title)
	_title_band.draw.connect(_draw_badge)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(pad)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	pad.add_child(body)
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	body.add_child(card)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(_icon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(info)
	_type = MarketTheme.label("", 16, MarketTheme.TEXT_2)
	info.add_child(_type)
	_level = MarketTheme.label("", 22, MarketTheme.TEXT)
	info.add_child(_level)
	_facts = MarketTheme.label("", 15, MarketTheme.TEXT)
	_facts.name = "SellFacts"
	_facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_facts)
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 6)
	body.add_child(_form)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 14)
	_form.add_child(steps)
	_count_box = _stepper_box(steps, "Quantity", "count")
	_count_label = MarketTheme.label("", 18)
	_count_label.name = "SellCount"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_box.get_child(1).add_child(_count_label)
	_count_box.get_child(1).move_child(_count_label, 1)
	var price_box := _stepper_box(steps, "Price each", "price")
	price_edit = LineEdit.new()
	price_edit.name = "SellPrice"
	price_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	price_edit.placeholder_text = "Price"
	price_edit.max_length = 7
	price_edit.select_all_on_focus = true
	price_edit.add_theme_font_override("font", MarketTheme.font())
	price_edit.add_theme_color_override("font_color", MarketTheme.TEXT)
	price_edit.add_theme_stylebox_override("normal", MarketTheme.flat(Color(0.04, 0.05, 0.04, 0.9), MarketTheme.BORDER, 1, 4))
	price_edit.add_theme_stylebox_override("focus", MarketTheme.flat(Color(0, 0, 0, 0), MarketTheme.GOLD, 2, 4))
	price_edit.text_changed.connect(func (t: String) -> void: _set_unit(t.to_int() if t.is_valid_int() else 0, false))
	price_edit.text_submitted.connect(func (_t: String) -> void: _clamp_price())
	price_edit.focus_exited.connect(_clamp_price)
	price_box.get_child(1).add_child(price_edit)
	price_box.get_child(1).move_child(price_edit, 1)
	band_label = MarketTheme.label("", 14, MarketTheme.TEXT_2)
	band_label.name = "SellBand"
	_form.add_child(band_label)
	var dur := HBoxContainer.new()
	dur.add_theme_constant_override("separation", 8)
	_form.add_child(dur)
	var dl := MarketTheme.label("Duration", 15, MarketTheme.TEXT_2)
	_captions.append(dl)
	dur.add_child(dl)
	for h: int in EconRules.load_default().g("durations_h"):
		var b := Button.new()
		b.name = "Duration_%d" % h
		b.text = "%d h" % h
		b.pressed.connect(func () -> void:
			hours = h
			refresh())
		dur.add_child(b)
		duration_btns[h] = b
	_preview = GridContainer.new()
	_preview.name = "SellPreview"
	_preview.add_theme_constant_override("h_separation", 12)
	_preview.add_theme_constant_override("v_separation", 2)
	_form.add_child(_preview)
	for row: Array in [["fee", "Listing fee (paid now)"], ["tax", "Market tax (when it sells)"], ["receive", "You receive"], ["net", "Net after the fee"]]:
		var k := MarketTheme.label(row[1], 15, MarketTheme.TEXT_2)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_keys.append(k)
		_preview.add_child(k)
		var v := MarketTheme.label("", 15, MarketTheme.GOLD if row[0] == "receive" else MarketTheme.TEXT)
		v.name = "Preview_%s" % row[0]
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_preview.add_child(v)
		preview_values[row[0]] = v
	status = MarketTheme.label("", 15, MarketTheme.TEXT)
	status.name = "SellStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	var foot := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		foot.add_theme_constant_override("margin_" + side, 10)
	root.add_child(foot)
	list_btn = Button.new()
	list_btn.name = "SellList"
	list_btn.pressed.connect(func () -> void:
		_clamp_price()
		if can_list():
			list_pressed.emit())
	foot.add_child(list_btn)
	show_entry({})

## A caption over [lower] value [higher]; the value control is inserted between the two buttons.
func _stepper_box(parent: Control, caption: String, id: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var c := MarketTheme.label(caption, 14, MarketTheme.TEXT_2)
	_captions.append(c)
	box.add_child(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	for dir in [-1, 1]:
		var b := Button.new()
		b.name = "Sell_%s_%s" % [id, "down" if dir < 0 else "up"]
		b.tooltip_text = ("Fewer" if id == "count" else "Lower") if dir < 0 else ("More" if id == "count" else "Higher")
		MarketTheme.action(b, false, 16)
		var glyph := &"chevron_left" if dir < 0 else &"chevron"
		b.draw.connect(func () -> void:
			var s := b.size.y * 0.42
			MarketGlyphs.draw(b, glyph, Rect2(b.size * 0.5 - Vector2(s, s) * 0.5, Vector2(s, s)), MarketTheme.TEXT_OFF if b.disabled else MarketTheme.ACTION))
		b.pressed.connect(_step.bind(id, dir))
		row.add_child(b)
		steppers["%s_%s" % [id, "down" if dir < 0 else "up"]] = b
	return box

## Shows one picker entry ({} = nothing picked). Price and band wait for set_reference().
func show_entry(e: Dictionary) -> void:
	entry = e
	ref = 0
	unit = 0
	count = int(e.get("count", 1))
	hours = 24 # ASSUMPTION (exchange-spec A7): 24 h unless the player picks another duration
	pending = false
	var rules := EconRules.load_default()
	lo = 1
	hi = rules.num("max_unit_price")
	status.text = ""
	status.add_theme_color_override("font_color", MarketTheme.TEXT)
	price_edit.text = ""
	if e.is_empty():
		_title.text = "Sell"
		_icon.texture = null
		_icon.visible = false
		_type.text = "Choose an item from your bag."
		_level.text = ""
		_facts.text = "Listing moves that exact item into the market until it sells, expires or you cancel it."
		_form.visible = false
		list_btn.visible = false
		_band_margin()
		return
	_icon.visible = true
	_icon.texture = ItemArt.texture_for(e.icon)
	_icon.modulate = e.tint
	_title.text = str(e.name)
	_band_margin()
	_type.text = str(e.type) + ("  ·  in market storage" if e.src == "vault" else "")
	_level.text = LevelDisplay.label(int(e.level)) + ("   ×%d" % count if count > 1 else "")
	var lines := MarketFormat.asset_lines(str(e.kind), e.asset)
	lines.remove_at(0) # level and type are on the card already
	_facts.text = "\n".join(lines)
	list_btn.visible = true
	var refused := str(e.why) != ""
	_form.visible = not refused
	_count_box.visible = count > 1
	if refused:
		status.text = str(e.why)
		status.add_theme_color_override("font_color", MarketTheme.DANGER)
	refresh()

## market.item_detail for the picked entry: the band around ref_price, and a starting price taken
## only from the market's own numbers (reference, last trade, cheapest ask); none -> the player sets it.
func set_reference(d: Dictionary) -> void:
	ref = int(d.get("ref_price", 0))
	var b := MarketFormat.band(ref)
	if not b.is_empty():
		lo = b[0]
		hi = b[1]
	if unit == 0:
		for k in ["ref_price", "last_price", "best_ask"]:
			if int(d.get(k, 0)) > 0:
				_set_unit(clampi(int(d[k]), lo, hi), true)
				break
	refresh()

func can_list() -> bool:
	return not pending and not entry.is_empty() and str(entry.get("why", "")) == "" and unit >= lo and unit <= hi \
		and tradable >= int(MarketFormat.preview(unit, count).fee)

func set_pending(on: bool, text: String) -> void:
	pending = on
	say(text, MarketTheme.TEXT_2)
	refresh()

func say(text: String, color: Color = MarketTheme.TEXT) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)

## Band, preview, steppers, duration chips and the List button from the current values.
func refresh() -> void:
	if entry.is_empty():
		return
	band_label.text = ("Recent price %s  ·  allowed %s – %s" % [MarketFormat.group(ref), MarketFormat.group(lo), MarketFormat.group(hi)]) if ref > 0 \
		else "No recent trades: any price %s – %s" % [MarketFormat.group(lo), MarketFormat.group(hi)]
	var p := MarketFormat.preview(unit, count)
	for k: String in preview_values:
		(preview_values[k] as Label).text = MarketFormat.group(int(p[k])) if unit > 0 else "—"
	_count_label.text = "%d / %d" % [count, int(entry.get("count", 1))]
	steppers.count_down.disabled = pending or count <= 1
	steppers.count_up.disabled = pending or count >= int(entry.get("count", 1))
	steppers.price_down.disabled = pending or unit <= lo
	steppers.price_up.disabled = pending or unit >= hi
	for s: Button in steppers.values():
		s.queue_redraw()
	for h: int in duration_btns:
		_chip(duration_btns[h], h == hours)
	price_edit.editable = not pending
	var why := ""
	if str(entry.get("why", "")) != "":
		why = "Can't be sold"
	elif unit <= 0:
		why = "Set a price"
	elif tradable < int(p.fee):
		why = "Not enough tradable T-stones"
		if not pending:
			say("The listing fee is %s tradable T-stones; you have %s. Bound T-stones can't pay market fees." % [MarketFormat.group(p.fee), MarketFormat.group(tradable)], MarketTheme.DANGER)
	list_btn.text = why if why != "" else "List for %s" % MarketFormat.group(p.total)
	list_btn.disabled = not can_list()

func _step(id: String, dir: int) -> void:
	if id == "count":
		count = clampi(count + dir, 1, int(entry.get("count", 1)))
		_level.text = LevelDisplay.label(int(entry.level)) + ("   ×%d" % int(entry.count) if int(entry.count) > 1 else "")
	else:
		var base := unit if unit > 0 else (ref if ref > 0 else lo)
		_set_unit(clampi(base + dir * MarketFormat.price_step(base) if unit > 0 else base, lo, hi), true)
	refresh()

func _set_unit(v: int, write: bool) -> void:
	unit = maxi(0, v)
	if write:
		price_edit.text = str(unit) if unit > 0 else ""
	refresh()

## A typed price is pulled into the band when the field is left (the stepper never leaves it).
func _clamp_price() -> void:
	if unit > 0 and (unit < lo or unit > hi):
		_set_unit(clampi(unit, lo, hi), true)

func _chip(b: Button, on: bool) -> void:
	var edge := MarketTheme.GOLD if on else Color(0.5, 0.49, 0.44, 0.8)
	b.add_theme_stylebox_override("normal", MarketTheme.flat(Color(0.3, 0.26, 0.14, 0.85) if on else Color(0.05, 0.06, 0.05, 0.8), edge, 2 if on else 1, 4))
	b.add_theme_stylebox_override("hover", MarketTheme.flat(Color(0.2, 0.19, 0.14, 0.9), edge, 2, 4))
	b.add_theme_stylebox_override("pressed", MarketTheme.flat(Color(0.3, 0.26, 0.14, 0.9), MarketTheme.GOLD, 2, 4))
	b.add_theme_stylebox_override("focus", MarketTheme.flat(Color(0, 0, 0, 0), MarketTheme.ACTION, 2, 4))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, MarketTheme.GOLD if on else MarketTheme.TEXT)
	b.add_theme_font_override("font", MarketTheme.font())
	b.disabled = pending

## The bonded "B" disc before the name (the Bag reference's "B Zebraceratops").
func _draw_badge() -> void:
	if entry.get("badge", false):
		MarketGlyphs.badge_b(_title_band, Vector2(14.0 + _badge_r, _title_band.size.y * 0.5), _badge_r)

func _band_margin() -> void:
	(_title_band.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 14.0 + (_badge_r * 2.0 + 8.0 if entry.get("badge", false) else 0.0)
	_title_band.queue_redraw()

func fit(m: Dictionary) -> void:
	_m = m
	var compact: bool = m.compact
	var tgt := UiTokens.TARGET_MIN if compact else 52.0
	MarketTheme.size_label(_title, m.name + (2 if compact else 6))
	_badge_r = (m.name + (2 if compact else 6)) * 0.62
	_band_margin()
	var isz := 48.0 if compact else 112.0
	_icon.custom_minimum_size = Vector2(isz, isz)
	MarketTheme.size_label(_type, m.type)
	MarketTheme.size_label(_level, m.name + (0 if compact else 4))
	MarketTheme.size_label(_facts, m.type)
	for l: Label in _captions + _keys + [band_label]:
		MarketTheme.size_label(l, m.type)
	for v: Label in preview_values.values():
		MarketTheme.size_label(v, m.type + (0 if compact else 2))
	MarketTheme.size_label(status, m.type)
	MarketTheme.size_label(_count_label, m.name)
	_count_label.custom_minimum_size = Vector2(56 if compact else 72, tgt)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_edit.custom_minimum_size = Vector2(80 if compact else 120, tgt)
	price_edit.add_theme_font_size_override("font_size", m.name)
	for b: Button in steppers.values():
		b.custom_minimum_size = Vector2(tgt, tgt)
	for b: Button in duration_btns.values():
		b.custom_minimum_size = Vector2(52 if compact else 72, tgt)
		b.add_theme_font_size_override("font_size", m.type + 1)
	_preview.columns = 2
	MarketTheme.action(list_btn, true, m.name)
	list_btn.custom_minimum_size = Vector2(0, tgt if compact else 60.0)
	refresh()
