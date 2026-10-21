class_name MarketSellForm
extends PanelContainer
## Sell's right panel for the picked instance: its name band, card and facts (read from its dict),
## a count for a stack, the unit price (steppers move inside the reference band, a typed price
## outside it is warned about), the duration, and the fee / tax / proceeds preview from ECON's own
## rules (MarketFormat.preview); the yellow List button along the bottom. It shows and checks
## only; MarketSell sends the ops.
# swap: INVUI ItemInspectPanel for the band, card and facts when it reaches this base.

signal list_pressed

## Preview rows: id, key on a wide panel, key on a phone (two pairs a line there).
const PREVIEW_ROWS := [["fee", "Listing fee (paid now)", "Fee now"], ["tax", "Market tax (when it sells)", "Tax on sale"], ["receive", "You receive", "You receive"], ["net", "Net after the fee", "Net"]]

var entry: Dictionary = {}
var wallet := 0 ## every T-stone (wallet.get): bound ones pay listing fees first (ECON r5, a sink)
var open_listings := 0 ## the account's open listings (market.mine): the server refuses one more past the cap
var lock_s := 0 ## seconds left of the new-account trade lock (wallet.get trade_lock_s, hook H6)
var ref := 0 ## market.item_detail ref_price; 0 = no reference, so no band
var lo := 1 ## the band (0.25x-4x of ref), or 1..max_price without a reference
var hi := 1
var max_price := 1 ## market_rules max_unit_price: the server's own limit
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
var _icon: MarketIcon
var _type: Label
var _level: Label
var _facts: Label
var _form: VBoxContainer
var _count_box: VBoxContainer
var _steps: HFlowContainer
var _count_label: Label
var _preview: GridContainer
var _preview_head: PanelContainer ## the Bag panel's dark "Info" bar over the fee / tax / proceeds rows
var _captions: Array[Label] = []
var _price_caption: Label
var _keys: Array[Label] = []
var _pad: MarginContainer
var _foot: MarginContainer
var _m := {}
var _badge_r := 12.0
var _note := ""

func _ready() -> void:
	name = "SellForm"
	MarketTheme.card(self, 0)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	_title_band = PanelContainer.new()
	var tb := MarketTheme.flat(MarketTheme.PARCHMENT, Color(0, 0, 0, 0), 0, 4)
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
	scroll.add_child(pad)
	_pad = pad
	var body := VBoxContainer.new()
	body.name = "SellBody"
	pad.add_child(body)
	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	body.add_child(card)
	_icon = MarketIcon.new()
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
	var steps := HFlowContainer.new() # Quantity and Price share a line; stacked when the panel cannot fit both
	_steps = steps
	steps.add_theme_constant_override("h_separation", 14)
	steps.add_theme_constant_override("v_separation", 4)
	_form.add_child(steps)
	_count_box = _stepper_box(steps, "Quantity", "count")
	_count_label = MarketTheme.label("", 18)
	_count_label.name = "SellCount"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_box.get_child(1).add_child(_count_label)
	_count_box.get_child(1).move_child(_count_label, 1)
	var price_box := _stepper_box(steps, "Price each", "price")
	_price_caption = price_box.get_child(0)
	price_edit = LineEdit.new()
	price_edit.name = "SellPrice"
	price_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	price_edit.placeholder_text = "Price"
	price_edit.max_length = 7
	price_edit.select_all_on_focus = true
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
		_chip(b, h == hours)
	_preview_head = PanelContainer.new()
	var hb := MarketTheme.flat(MarketTheme.BAND, Color(0, 0, 0, 0), 0, 3)
	hb.content_margin_left = 10
	hb.content_margin_top = 4
	hb.content_margin_bottom = 4
	_preview_head.add_theme_stylebox_override("panel", hb)
	_preview_head.add_child(MarketTheme.label("Fees and proceeds", 15, MarketTheme.TEXT_2))
	_form.add_child(_preview_head)
	_preview = GridContainer.new()
	_preview.name = "SellPreview"
	_preview.draw.connect(_draw_preview_lines)
	_preview.add_theme_constant_override("h_separation", 12)
	_preview.add_theme_constant_override("v_separation", 2)
	_form.add_child(_preview)
	for row: Array in PREVIEW_ROWS:
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
	root.add_child(foot)
	_foot = foot
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
	max_price = rules.num("max_unit_price")
	lo = 1
	hi = max_price
	status.text = ""
	_note = ""
	status.add_theme_color_override("font_color", MarketTheme.TEXT)
	price_edit.text = ""
	if e.is_empty():
		_title.text = "Sell"
		_icon.show_item(&"")
		_icon.visible = false
		_type.visible = false
		_level.visible = false
		_facts.text = "Choose an item from your bag. Listing moves that exact item into the market until it sells, expires or you cancel it."
		_form.visible = false
		list_btn.visible = false
		_band_margin()
		return
	_icon.visible = true
	_type.visible = not _m.get("compact", false)
	_icon.show_item(e.icon, e.tint)
	_title.text = str(e.name)
	_band_margin()
	_type.text = str(e.type) + ("  ·  in market storage" if e.src == "vault" else "")
	_card_text()
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
	return not pending and not entry.is_empty() and str(entry.get("why", "")) == "" and unit >= 1 and unit <= max_price \
		and wallet >= int(MarketFormat.preview(unit, count).fee) and lock_s <= 0 and open_listings < max_listings()

## The open-listing cap (limits.json max_open_listings, the number My Market's Active n/50 shows).
static func max_listings() -> int:
	return EconRules.load_default().num("max_open_listings")

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
	band_label.text = ("Recent price %s  ·  usual range %s – %s" % [MarketFormat.group(ref), MarketFormat.group(lo), MarketFormat.group(hi)]) if ref > 0 \
		else "No recent trades: any price %s – %s" % [MarketFormat.group(lo), MarketFormat.group(hi)]
	# A phone has no room for the band's own line: the price caption carries the allowed range.
	_price_caption.text = "Price each  %s – %s" % [MarketFormat.group(lo), MarketFormat.group(hi)] if _m.get("compact", false) and ref > 0 else "Price each"
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
	var note := "" ## a warning this refresh owns (cleared when its cause goes)
	if str(entry.get("why", "")) != "":
		why = "Can't be sold"
	elif lock_s > 0:
		why = "Can't list yet"
		note = MarketFormat.lock_text(lock_s)
	elif open_listings >= max_listings():
		# Checked before the deposit: the server refuses the 51st listing only after the item has left the bag.
		why = "At most %d open listings" % max_listings()
		note = "You have %d listings open, the most the market takes. Cancel one in My Market or wait for a sale." % open_listings
	elif unit <= 0:
		why = "Set a price"
	elif wallet < int(p.fee):
		why = "Not enough T-stones"
		note = "The listing fee is %s T-stones; you have %s." % [MarketFormat.group(p.fee), MarketFormat.group(wallet)]
	var outside := why == "" and ref > 0 and (unit < lo or unit > hi)
	if outside:
		note = "Outside the usual range %s – %s for this item. Check the price; rare traits can be worth more." % [MarketFormat.group(lo), MarketFormat.group(hi)]
	if not pending and note != "":
		say(note, MarketTheme.DANGER)
		_note = note
	elif not pending and _note != "" and status.text == _note:
		say("")
		_note = ""
	list_btn.text = why if why != "" else ("List anyway for %s" if outside else "List for %s") % MarketFormat.group(p.total)
	list_btn.disabled = not can_list()

func _step(id: String, dir: int) -> void:
	if id == "count":
		count = clampi(count + dir, 1, int(entry.get("count", 1)))
	else:
		var base := unit if unit > 0 else (ref if ref > 0 else lo)
		_set_unit(clampi(base + dir * MarketFormat.price_step(base) if unit > 0 else base, lo, hi), true)
	refresh()

## Level (and the stack size) over the asset's facts; on a phone they share the first line.
func _card_text() -> void:
	if entry.is_empty():
		return
	var lv := LevelDisplay.label(int(entry.level)) + ("   ×%d" % int(entry.count) if int(entry.count) > 1 else "")
	var lines := MarketFormat.asset_lines(str(entry.kind), entry.asset)
	lines.remove_at(0) # level and type are on the card already
	var phone: bool = _m.get("compact", false)
	_level.visible = not phone
	_level.text = lv
	# A phone's panel must show the fee preview above List without scrolling: the facts run on as
	# at most two lines there ("Bonded pet" is the B disc in the name band already).
	_facts.max_lines_visible = 2 if phone else -1
	if phone:
		_facts.text = "  ·  ".join(PackedStringArray([lv]) + PackedStringArray(Array(lines).filter(func (l: String) -> bool: return l != "Bonded pet")))
	else:
		_facts.text = "\n".join(lines)

func _set_unit(v: int, write: bool) -> void:
	unit = maxi(0, v)
	if write:
		price_edit.text = str(unit) if unit > 0 else ""
	refresh()

## A typed price over the server's maximum is pulled to it when the field is left. The band is
## advice, not a wall: a rare-trait instance may be worth more than 4x its def's reference.
# ASSUMPTION (exchange-spec A6, revised in B2): steppers keep to the band, a typed price may leave it with a warning.
func _clamp_price() -> void:
	if unit > max_price:
		_set_unit(max_price, true)

func _chip(b: Button, on: bool) -> void:
	var edge := MarketTheme.GOLD if on else Color(0.5, 0.49, 0.44, 0.8)
	b.add_theme_stylebox_override("normal", MarketTheme.flat(Color(0.3, 0.26, 0.14, 0.85) if on else Color(0.05, 0.06, 0.05, 0.8), edge, 2 if on else 1, 4))
	b.add_theme_stylebox_override("hover", MarketTheme.flat(Color(0.2, 0.19, 0.14, 0.9), edge, 2, 4))
	b.add_theme_stylebox_override("pressed", MarketTheme.flat(Color(0.3, 0.26, 0.14, 0.9), MarketTheme.GOLD, 2, 4))
	b.add_theme_stylebox_override("focus", MarketTheme.flat(Color(0, 0, 0, 0), MarketTheme.ACTION, 2, 4))
	MarketTheme.ink(b, MarketTheme.GOLD if on else MarketTheme.TEXT)
	b.add_theme_font_override("font", MarketTheme.font())
	b.disabled = pending

## Dotted lines between the desktop preview rows (the Bag's Info list).
func _draw_preview_lines() -> void:
	if _preview.columns != 2:
		return
	var gap := _preview.get_theme_constant("v_separation") * 0.5
	for k: Label in _keys.slice(0, _keys.size() - 1):
		var y := k.position.y + k.size.y + gap
		MarketTheme.dotted(_preview, Vector2(0, y), Vector2(_preview.size.x, y))

## The bonded "B" disc before the name (the Bag reference's "B Zebraceratops").
func _draw_badge() -> void:
	if entry.get("badge", false):
		MarketGlyphs.badge_b(_title_band, Vector2(14.0 + _badge_r, _title_band.size.y * 0.5), _badge_r)

func _band_margin() -> void:
	(_title_band.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 14.0 + (_badge_r * 2.0 + 8.0 if entry.get("badge", false) else 0.0)
	_title_band.queue_redraw()

## The panel width that keeps Quantity and Price on one line (MarketSell gives it when it can, so a
## phone still sees the fee preview without scrolling the panel).
func one_line_width() -> float:
	var w := get_theme_stylebox("panel").get_minimum_size().x + _pad.get_theme_constant("margin_left") + _pad.get_theme_constant("margin_right")
	var shown := _steps.get_children().filter(func (c: Control) -> bool: return c.visible)
	for c: Control in shown:
		w += c.get_combined_minimum_size().x
	return w + 14.0 * maxi(0, shown.size() - 1)

func fit(m: Dictionary) -> void:
	_m = m
	var compact: bool = m.compact
	var tgt: float = m.tmin if compact else 52.0
	MarketTheme.size_label(_title, m.name + (2 if compact else 6))
	_badge_r = (m.name + (2 if compact else 6)) * 0.62
	_band_margin()
	var isz := 36.0 if compact else 128.0
	for box: Control in [_pad.get_child(0), _form]: # a phone's panel is ~330 px tall: tighter rhythm
		box.add_theme_constant_override("separation", 4 if compact else 12)
	var tb := _title_band.get_theme_stylebox("panel") as StyleBoxFlat
	tb.content_margin_top = 4.0 if compact else 8.0
	tb.content_margin_bottom = tb.content_margin_top
	_icon.custom_minimum_size = Vector2(isz, isz)
	MarketTheme.size_label(_type, m.type)
	_type.visible = not compact and not entry.is_empty() # the name band says it already; a phone needs the line
	for side in ["left", "right", "top", "bottom"]:
		_pad.add_theme_constant_override("margin_" + side, 6 if compact else 12)
	band_label.visible = not compact
	for i in _keys.size():
		_keys[i].text = PREVIEW_ROWS[i][2 if compact else 1]
	MarketTheme.size_label(_level, m.name + (0 if compact else 4))
	_card_text()
	for side in ["left", "right", "top", "bottom"]:
		_foot.add_theme_constant_override("margin_" + side, 6 if compact else 10)
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
	price_edit.add_theme_font_override("font", MarketTheme.field_font(m.name))
	price_edit.add_theme_font_size_override("font_size", m.name)
	for b: Button in steppers.values():
		b.custom_minimum_size = Vector2(tgt, tgt)
	for b: Button in duration_btns.values():
		b.custom_minimum_size = Vector2(maxf(52.0, tgt) if compact else 72.0, tgt)
		b.add_theme_font_size_override("font_size", m.type + 1)
	_preview.columns = 4 if compact else 2
	# A desktop panel spaces its rows like the Bag's Info list (dotted lines between them) under a dark
	# bar; a phone keeps two pairs a line with no bar, so the preview shows above List without scrolling.
	_preview_head.visible = not compact
	MarketTheme.size_label(_preview_head.get_child(0) as Label, m.type)
	_preview.add_theme_constant_override("v_separation", 2 if compact else roundi(m.row_h * 0.1))
	MarketTheme.action(list_btn, true, m.name)
	list_btn.custom_minimum_size = Vector2(0, tgt if compact else 60.0)
	refresh()
