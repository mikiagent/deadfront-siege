class_name MarketSell
extends Control
## Sell (spec 06 seller flow): pick ONE exact instance of your server character (a bag row or a
## bonded animal), type a price, read the fee / tax / proceeds preview, List. List = vault.deposit
## of that instance, then market.list_fixed of exactly one unit. The local single-player bag is not
## the server's, so it is never offered here.

var screen: MarketScreen
var rules: EconRules
var picker: PanelContainer
var scroll: ScrollContainer
var list: VBoxContainer
var empty: Label
var rows: Array[MarketRow] = []
var detail: PanelContainer
var d_head: Label
var d_sub: Label
var price: LineEdit
var dur_btn: Button
var preview: Label
var status: Label
var list_btn: Button
var picked: MarketRow
var hours := 24 ## ASSUMPTION: the default listing time; the button cycles the rules' durations
var _said := false ## the status line holds a List result until the player picks or types again

func _ready() -> void:
	rules = EconRules.load_default()
	picker = PanelContainer.new()
	picker.name = "Picker"
	picker.add_theme_stylebox_override("panel", MarketScreen.panel_box())
	add_child(picker)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	empty = MarketScreen.lbl("Your bag on the server is empty. What you gather, craft, capture or tame online can be sold here.", 18, UiTokens.META)
	empty.name = "Empty"
	empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty.custom_minimum_size.y = 96
	list.add_child(empty)
	detail = PanelContainer.new()
	detail.name = "Detail"
	detail.add_theme_stylebox_override("panel", MarketScreen.panel_box())
	add_child(detail)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	detail.add_child(col)
	var parch := PanelContainer.new()
	parch.add_theme_stylebox_override("panel", SheetChrome.parchment_style(12, 12))
	col.add_child(parch)
	var pv := VBoxContainer.new()
	parch.add_child(pv)
	d_head = MarketScreen.lbl("Pick an item", 26, UiTokens.PARCHMENT_INK, true)
	d_head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d_head.clip_text = true
	pv.add_child(d_head)
	d_sub = MarketScreen.lbl("One instance per listing", 16, UiTokens.PARCHMENT_INK)
	d_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d_sub.clip_text = true
	pv.add_child(d_sub)
	var inner := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 12)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(inner)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 8)
	inner.add_child(iv)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	iv.add_child(pr)
	price = LineEdit.new()
	price.name = "Price"
	price.placeholder_text = "Price in T-stones"
	price.custom_minimum_size.y = 64
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	price.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	price.text_changed.connect(func (_t: String) -> void:
		_said = false
		_update())
	pr.add_child(price)
	dur_btn = MarketScreen.btn("", 18)
	dur_btn.name = "Duration"
	dur_btn.custom_minimum_size.x = 88
	dur_btn.pressed.connect(func () -> void:
		var ds: Array = rules.g("durations_h")
		hours = int(ds[(ds.find(hours) + 1) % ds.size()])
		_update())
	pr.add_child(dur_btn)
	preview = MarketScreen.lbl("", 18)
	preview.name = "Preview"
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(preview)
	status = MarketScreen.lbl("", 16, UiTokens.META)
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(status)
	list_btn = MarketScreen.btn("List on market", 24, true)
	list_btn.name = "List"
	list_btn.pressed.connect(press_list)
	iv.add_child(list_btn)

## Rereads the server character's bag and pets; `uid` preselects that instance (Bag -> Sell on Market).
func refresh(uid: String = "") -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	picked = null
	var res := screen.client.request("char.get")
	var ch: Dictionary = res.get("r", {})
	var worn: Array = (ch.get("equipment", {}) as Dictionary).values().map(func (u: Variant) -> String: return str(u)) + [str(ch.get("tool", ""))]
	var bag: Array = ch.get("bag", [])
	for i in bag.size():
		var row: Variant = bag[i]
		if not (row is Dictionary) or str(row.get("id", "")) == str(CharacterState.LOCK) or str(row.get("uid", "")) in worn:
			continue # equipped gear stays on the character: a deposit would unequip it silently
		var v := MarketRow.view_of(row, -1, "Locked" if "locked" in (row.get("flags", []) as Array) else "")
		v.deposit = {"bag_slot": i, "count": 1}
		_add(v)
	var pets: Dictionary = ch.get("pets", {})
	for pid: String in pets:
		var v := MarketRow.view_of(pets[pid])
		v.deposit = {"pet_uid": pid}
		_add(v)
	empty.visible = rows.is_empty()
	if not res.get("ok", false):
		empty.text = MarketConfirm.say_error(res)
	for r in rows:
		if uid != "" and str(r.v.uid) == uid:
			pick(r)
	if picked == null and not rows.is_empty():
		pick(rows[0])
	_update()

func _add(v: Dictionary) -> void:
	var row := MarketRow.new(v)
	row.cols = PackedFloat32Array([0.6, 0.78, 0.92])
	row.px = screen.m.get("px", 22)
	row.custom_minimum_size.y = screen.m.get("row_h", 96)
	row.disabled = str(v.note) == "Locked"
	row.pressed.connect(func () -> void: pick(row))
	list.add_child(row)
	rows.append(row)

func pick(row: MarketRow) -> void:
	for r in rows:
		r.picked = r == row
	picked = row
	_said = false
	_update()

## Fee and tax exactly as the books charge them (MarketBook.list_fixed / _pay_seller, rounded up).
func fees(unit: int) -> Dictionary:
	var fee := maxi(rules.num("listing_fee_min"), EconRules.ceil_bp(unit, rules.bp("listing_fee")))
	var tax := EconRules.ceil_bp(unit, rules.bp("sales_tax"))
	return {"fee": fee, "tax": tax, "net": unit - tax}

func _update() -> void:
	dur_btn.text = "%d h" % hours
	var v: Dictionary = picked.v if picked else {}
	d_head.text = str(v.get("name", "Pick an item"))
	d_sub.text = ("%s · Lv. %d%s" % [str(v.get("type", "")), int(v.get("level", 1)), (" · %s" % v.dur) if str(v.get("dur", "—")) != "—" else ""]) if picked else "One instance per listing"
	var unit := int(price.text) if price.text.is_valid_int() else 0
	var why := ""
	if picked == null:
		why = "Pick an item from your bag."
	elif picked.disabled:
		why = "Locked items cannot be listed; unlock it in the Bag."
	elif unit < 1 or unit > rules.num("max_unit_price"):
		why = "Type a price from 1 to %s T-stones." % MarketRow._num(rules.num("max_unit_price"))
	if unit >= 1:
		var f := fees(unit)
		preview.text = _sep().join(["Listing fee %s" % MarketRow._num(f.fee), "Tax when sold %s" % MarketRow._num(f.tax), "You receive %s" % MarketRow._num(f.net)])
		if why == "" and int(screen.wallet.get("wallet", 0)) < int(f.fee):
			why = "The listing fee is %d T-stones; you have %d." % [f.fee, int(screen.wallet.get("wallet", 0))]
	else:
		preview.text = _sep().join(["Listing fee —", "Tax when sold —", "You receive —"])
	list_btn.disabled = why != ""
	if not _said:
		status.text = why
		status.add_theme_color_override("font_color", UiTokens.META)

## Phone landscape keeps the preview on one line so List stays on screen.
func _sep() -> String:
	return " · " if bool(screen.m.get("compact", false)) else "\n"

func press_list() -> void:
	if list_btn.disabled or picked == null:
		return
	list_btn.disabled = true
	var unit := int(price.text)
	var dep := screen.client.request("vault.deposit", picked.v.deposit)
	var res := dep
	if dep.get("ok", false):
		res = screen.client.request("market.list_fixed", {"asset": {"uid": str(dep.r.uid), "count": 1}, "unit_price": unit, "duration_h": hours})
	var listed := bool(res.get("ok", false))
	var say := ("Listed %s for %s T-stones." % [str(picked.v.name), MarketRow._num(unit)]) if listed else MarketConfirm.say_error(res)
	if dep.get("ok", false) and not listed:
		say += " The item waits in market storage: Receive All in My Market takes it back."
	screen.refresh_wallet()
	price.text = ""
	refresh()
	status.text = say # after refresh: its _update would put "type a price" here
	_said = true
	status.add_theme_color_override("font_color", UiTokens.OK_GREEN if listed else UiTokens.DANGER)

func layout(r: Rect2) -> void:
	position = r.position
	size = r.size
	var m := screen.m
	var dw: float = m.detail_w
	picker.position = Vector2.ZERO
	picker.size = Vector2(r.size.x - dw - m.gap, r.size.y)
	detail.position = Vector2(r.size.x - dw, 0)
	detail.size = Vector2(dw, r.size.y)
	var c: bool = m.compact
	d_head.add_theme_font_size_override("font_size", 18 if c else 26)
	for l: Label in [d_sub, status]:
		l.add_theme_font_size_override("font_size", 12 if c else 16)
	preview.add_theme_font_size_override("font_size", 13 if c else 18)
	# wrapped labels need a width before the first layout, or they ask for one word per line
	for l: Label in [preview, status]:
		l.custom_minimum_size.x = dw - 26.0
	empty.custom_minimum_size.x = picker.size.x - 24.0
	price.add_theme_font_size_override("font_size", m.px)
	empty.add_theme_font_size_override("font_size", m.px)
	for row in rows:
		row.px = m.px
		row.custom_minimum_size.y = m.row_h
