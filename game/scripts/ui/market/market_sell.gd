class_name MarketSell
extends Control
## Sell (spec 06 seller flow): pick ONE exact instance of your server character (a bag row or a
## bonded animal), type a price, read the fee / tax / proceeds preview, List. List = vault.deposit
## of that instance, then market.list_fixed of exactly one unit. The local single-player bag is not
## the server's, so it is never offered here.
## BAGUI (owner 2026-10-28): the server bag shows in the bag's own grid (BagGrid: Lv., quality dots);
## equipped and locked items are tinted red and cannot be picked. Picking an item fills the price
## with its going rate (going_rate: the median of that item's open listings, else its base price),
## which the player can type over or step with − / +. Bonded animals stay rows under the grid.

var screen: MarketScreen
var rules: EconRules
var picker: PanelContainer
## The server bag as a grid (one instance per slot) and the slot -> its row (listable items only).
var grid: BagGrid
var bag_inv: Inventory
var row_of_slot: Dictionary = {}
var rate_label: Label
var minus_btn: Button
var plus_btn: Button
var going := 0
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
	var pcol := VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 6)
	picker.add_child(pcol)
	grid = BagGrid.new()
	grid.name = "SellGrid"
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.selected.connect(tap_slot)
	pcol.add_child(grid)
	scroll = ScrollContainer.new()
	scroll.name = "Pets"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pcol.add_child(scroll)
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
	price.placeholder_text = "Price in Gold"
	price.custom_minimum_size.y = 64
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	price.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	price.text_changed.connect(func (_t: String) -> void:
		_said = false
		_update())
	pr.add_child(price)
	minus_btn = MarketScreen.btn("−", 22)
	minus_btn.name = "PriceDown"
	minus_btn.custom_minimum_size = Vector2(64, 64)
	minus_btn.pressed.connect(step_price.bind(-1))
	pr.add_child(minus_btn)
	plus_btn = MarketScreen.btn("+", 22)
	plus_btn.name = "PriceUp"
	plus_btn.custom_minimum_size = Vector2(64, 64)
	plus_btn.pressed.connect(step_price.bind(1))
	pr.add_child(plus_btn)
	dur_btn = MarketScreen.btn("", 18)
	dur_btn.name = "Duration"
	dur_btn.custom_minimum_size.x = 88
	dur_btn.pressed.connect(func () -> void:
		var ds: Array = rules.g("durations_h")
		hours = int(ds[(ds.find(hours) + 1) % ds.size()])
		_update())
	pr.add_child(dur_btn)
	rate_label = MarketScreen.lbl("", 16, UiTokens.GOLD)
	rate_label.name = "GoingRate"
	iv.add_child(rate_label)
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
	bag_inv = Inventory.new(maxi(1, bag.size()))
	row_of_slot.clear()
	var blocked := {}
	for i in bag.size():
		var row: Variant = bag[i]
		if not (row is Dictionary) or str(row.get("id", "")) == str(CharacterState.LOCK):
			continue
		bag_inv.slots[i] = ItemStack.from_dict(row)
		if str(row.get("uid", "")) in worn:
			blocked[i] = "equipped" # equipped gear stays on the character: a deposit would unequip it silently
			continue
		var v := MarketRow.view_of(row, -1, "Locked" if "locked" in (row.get("flags", []) as Array) else "")
		v.deposit = {"bag_slot": i, "count": 1}
		if str(v.note) == "Locked":
			blocked[i] = "locked"
		row_of_slot[i] = _add(v, false)
	grid.blocked = blocked
	grid.bind(bag_inv)
	var pets: Dictionary = ch.get("pets", {})
	for pid: String in pets:
		var v := MarketRow.view_of(pets[pid])
		v.deposit = {"pet_uid": pid}
		_add(v)
	empty.visible = rows.is_empty()
	scroll.visible = rows.any(func (r: MarketRow) -> bool: return r.visible)
	scroll.custom_minimum_size.y = 0.0 if not scroll.visible else float(screen.m.get("row_h", 96))
	if not res.get("ok", false):
		empty.text = MarketConfirm.say_error(res)
	for r in rows:
		if uid != "" and str(r.v.uid) == uid:
			pick(r)
	if picked == null and not rows.is_empty():
		var first: Array = rows.filter(func (r: MarketRow) -> bool: return not r.disabled)
		pick(first[0] if not first.is_empty() else rows[0]) # a listable item first, never a locked one
	_update()

## A grid tap: an equipped or locked item cannot be picked; anything else is.
func tap_slot(index: int) -> void:
	if grid.blocked.has(index):
		status.text = "Equipped items can't be sold." if grid.blocked[index] == "equipped" else "Locked: unlock it in the Bag."
		_said = true
		status.add_theme_color_override("font_color", UiTokens.DANGER)
		return
	if row_of_slot.has(index):
		pick(row_of_slot[index])

func _add(v: Dictionary, shown: bool = true) -> MarketRow:
	var row := MarketRow.new(v)
	row.cols = PackedFloat32Array([0.6, 0.78, 0.92])
	row.px = screen.m.get("px", 22)
	row.custom_minimum_size.y = screen.m.get("row_h", 96)
	row.disabled = str(v.note) == "Locked"
	row.pressed.connect(func () -> void: pick(row))
	row.visible = shown # a bag item is picked in the grid; its row only carries the data
	list.add_child(row)
	rows.append(row)
	return row

func pick(row: MarketRow) -> void:
	for r in rows:
		r.picked = r == row
	picked = row
	_said = false
	var slot := int((row.v.get("deposit", {}) as Dictionary).get("bag_slot", -1))
	grid.set_selected(slot)
	going = going_rate(row.v)
	price.text = str(going) if going > 0 else ""
	_update()

## The going rate (owner 2026-10-28): the median unit price of the open fixed listings of this item id
## (the market groups an item by id; level is not part of the match), else the item's base price.
func going_rate(v: Dictionary) -> int:
	var asset: Dictionary = v.get("asset", {})
	var id := str(asset.get("id", asset.get("species", "")))
	var prices: Array[int] = []
	if screen and screen.client and id != "":
		var res := screen.client.request("market.search", {"q": id, "kind": "fixed", "page_size": int(rules.num("page_size_max"))})
		for l: Variant in (res.get("r", {}) as Dictionary).get("results", []):
			if l is Dictionary and str((l as Dictionary).get("asset", {}).get("id", (l as Dictionary).get("asset", {}).get("species", ""))) == id:
				prices.append(int((l as Dictionary).get("price", 0)))
	var m := median(prices)
	return m if m > 0 else base_price(id)

## Median of the prices, rounded down between the middle two; 0 for none.
static func median(prices: Array[int]) -> int:
	if prices.is_empty():
		return 0
	var p := prices.duplicate()
	p.sort()
	var n := p.size()
	return p[n / 2] if n % 2 == 1 else (p[n / 2 - 1] + p[n / 2]) / 2

## No listings: the item's market category base price (data/world/market.json base_price_tstones).
# ASSUMPTION: the base price is the documented fallback; level and attributes are not priced in.
static func base_price(id: String) -> int:
	var d: ItemDef = Data.item(StringName(id))
	if d == null:
		return 0
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/market.json"))
	var base: Variant = (parsed as Dictionary).get("base_price_tstones", {}) if parsed is Dictionary else {}
	return int((base as Dictionary).get(str(d.market_category), 0)) if base is Dictionary else 0

## − / +: 5 % of the going rate (at least 1) down or up from the typed price.
func step_price(dir: int) -> void:
	var cur := int(price.text) if price.text.is_valid_int() else going
	var step := maxi(1, int(round(float(maxi(going, cur)) * 0.05)))
	price.text = str(clampi(cur + dir * step, 1, rules.num("max_unit_price")))
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
	rate_label.text = ("Going rate %s" % MarketRow._num(going)) if picked and going > 0 else ""
	var compact := bool(screen.m.get("compact", false))
	rate_label.visible = not compact # a phone shows it on the sub line so List stays on screen
	minus_btn.visible = not compact # and types the price: the row keeps the field >= 64 px
	plus_btn.visible = not compact
	if compact and rate_label.text != "":
		d_sub.text += " · " + rate_label.text
	var why := ""
	if picked == null:
		why = "Pick an item from your bag."
	elif picked.disabled:
		why = "Locked items cannot be listed; unlock it in the Bag."
	elif unit < 1 or unit > rules.num("max_unit_price"):
		why = "Type a price from 1 to %s Gold." % MarketRow._num(rules.num("max_unit_price"))
	if unit >= 1:
		var f := fees(unit)
		preview.text = _sep().join(["Listing fee %s" % MarketRow._num(f.fee), "Tax when sold %s" % MarketRow._num(f.tax), "You receive %s" % MarketRow._num(f.net)])
		if why == "" and int(screen.wallet.get("wallet", 0)) < int(f.fee):
			why = "The listing fee is %d Gold; you have %d." % [f.fee, int(screen.wallet.get("wallet", 0))]
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
	var say := ("Listed %s for %s Gold." % [str(picked.v.name), MarketRow._num(unit)]) if listed else MarketConfirm.say_error(res)
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
	# A phone keeps List on screen: the result line is one line, trimmed (its full text is the tooltip).
	status.autowrap_mode = TextServer.AUTOWRAP_OFF if c else TextServer.AUTOWRAP_WORD_SMART
	status.clip_text = c
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if c else TextServer.OVERRUN_NO_TRIMMING
	preview.add_theme_font_size_override("font_size", 13 if c else 18)
	# wrapped labels need a width before the first layout, or they ask for one word per line
	for l: Label in [preview, status]:
		l.custom_minimum_size.x = dw - 26.0
	empty.custom_minimum_size.x = picker.size.x - 24.0
	price.add_theme_font_size_override("font_size", m.px)
	rate_label.add_theme_font_size_override("font_size", 12 if c else 16)
	dur_btn.custom_minimum_size.x = 64.0 if c else 88.0
	grid.cell_px = 64.0 if c else 88.0
	empty.add_theme_font_size_override("font_size", m.px)
	for row in rows:
		row.px = m.px
		row.custom_minimum_size.y = m.row_h
	if not _said:
		_update() # the phone / desktop parts of the detail (going-rate line, − / +) follow the view
	# Sort the detail now, parents first: a phone / desktop switch hides rows, and a deferred sort
	# would leave List where the taller desktop column had put it until the next frame.
	for ct: Node in [detail] + detail.find_children("*", "Container", true, false):
		ct.notification(Container.NOTIFICATION_SORT_CHILDREN)
