class_name MarketMine
extends Control
## My Market (spec 06 seller tabs): Active (tap to cancel), Sold, Expired, History, and Receive All,
## which takes everything waiting in market storage (bought items, cancelled or expired listings)
## into the server character's bag. Proceeds are credited to the wallet by the books at sale time
## (MarketBook._pay_seller), so Receive All moves goods and clears the sale notices (inbox.take).

const SUBTABS := [["active", "Active"], ["sold", "Sold"], ["expired", "Expired"], ["history", "History"]]

var screen: MarketScreen
var sub := "active"
var bar: HBoxContainer
var sub_btns := {}
var receive: Button
var waiting: Label
var panel: PanelContainer
var list: VBoxContainer
var empty: Label
var rows: Array[MarketRow] = []
var stored: Array = [] ## vault rows waiting for Receive All: [kind, uid]

func _ready() -> void:
	bar = HBoxContainer.new()
	bar.name = "Bar"
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	for s: Array in SUBTABS:
		var b := MarketScreen.btn(s[1], 18)
		b.name = "Sub_" + str(s[0])
		b.toggle_mode = true
		b.pressed.connect(func () -> void:
			sub = s[0]
			refresh())
		b.draw.connect(func () -> void:
			if sub == s[0]:
				UiTokens.draw_brackets(b, Rect2(Vector2.ZERO, b.size).grow(-2.0), UiTokens.GOLD, 12.0))
		bar.add_child(b)
		sub_btns[s[0]] = b
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	waiting = MarketScreen.lbl("", 16, UiTokens.META)
	waiting.name = "Waiting"
	waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(waiting)
	receive = MarketScreen.btn("Receive All", 22, true)
	receive.name = "ReceiveAll"
	receive.pressed.connect(receive_all)
	bar.add_child(receive)
	panel = PanelContainer.new()
	panel.name = "List"
	panel.add_theme_stylebox_override("panel", MarketScreen.panel_box())
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	empty = MarketScreen.lbl("", 18, UiTokens.META)
	empty.name = "Empty"
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.custom_minimum_size.y = 96
	list.add_child(empty)

func refresh() -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	for k: String in sub_btns:
		sub_btns[k].button_pressed = k == sub
		sub_btns[k].add_theme_color_override("font_color", UiTokens.GOLD if k == sub else UiTokens.TEXT)
		sub_btns[k].queue_redraw()
	var now := screen.client.now()
	var res := screen.client.request("market.mine", {"page_size": 50})
	var r: Dictionary = res.get("r", {})
	match sub:
		"active":
			for l: Dictionary in r.get("listings", []):
				var v := MarketRow.view_of(l.asset, int(l.price))
				v.type = "Ends in %s" % _span(int(l.ends) - now)
				v.listing = l
				_add(v).pressed.connect(open_cancel.bind(v))
		"sold", "expired":
			for l: Dictionary in r.get("closed_listings", []):
				var sold := str(l.state) == "sold"
				if sold != (sub == "sold"):
					continue
				var v := MarketRow.view_of(l.asset, int(l.price) if sold else -1, "" if sold else "Back in storage")
				v.type = "%s %s ago" % [str(l.state).capitalize(), _span(now - int(l.closed))]
				_add(v)
		_:
			for t: Dictionary in r.get("trades", []):
				var key := str(t.key)
				var bought := int(t.buyer) == screen.client.account
				var asset := {"species": key.substr(4)} if key.begins_with("pet:") else {"id": key.substr(5)}
				var v := MarketRow.view_of(asset, -1, ("Paid %s" if bought else "Got %s") % MarketRow._num(int(t.total) if bought else int(t.total) - int(t.tax)))
				v.type = "%s %s ago" % ["Bought" if bought else "Sold", _span(now - int(t.ts))]
				v.level = 0 # a trade record keeps no level
				v.dur = "—"
				_add(v)
	empty.text = MarketConfirm.say_error(res) if not res.get("ok", false) else "Nothing here yet."
	empty.visible = rows.is_empty()
	_count_waiting()

func _add(v: Dictionary) -> MarketRow:
	var row := MarketRow.new(v)
	row.cols = PackedFloat32Array([0.5, 0.66, 0.82])
	row.px = screen.m.get("px", 22)
	row.custom_minimum_size.y = screen.m.get("row_h", 96)
	list.add_child(row)
	rows.append(row)
	return row

func _count_waiting() -> void:
	stored.clear()
	var vr: Dictionary = screen.client.request("vault.get").get("r", {})
	for it: Dictionary in vr.get("items", []):
		stored.append(str(it.uid))
	for p: Dictionary in vr.get("pets", []):
		stored.append(str(p.uid))
	waiting.text = ("%d waiting" % stored.size()) if not stored.is_empty() else "Nothing waiting"
	receive.disabled = stored.is_empty()

func open_cancel(v: Dictionary) -> void:
	var l: Dictionary = v.listing
	var cancel := func () -> Dictionary:
		var res := screen.client.request("market.cancel", {"listing_id": str(l.id)})
		if res.get("ok", false):
			res.say = "Listing cancelled. The item waits in storage: Receive All takes it back. The listing fee is not refunded."
		return res
	var info := [["Price", "%s T-stones" % MarketRow._num(int(l.price))], ["Listing fee paid", MarketRow._num(int(l.get("fee", 0)))], ["Ends in", _span(int(l.ends) - screen.client.now())]]
	screen.confirm.open(v, info, "Cancel listing", cancel, refresh, "", "Keep listing")

## Takes every stored item and animal into the server bag, one withdrawal each (each with its own
## rid, so a retry never pays twice). A full bag stops it with the rest still safe in storage.
func receive_all() -> Dictionary:
	receive.disabled = true
	screen.client.request("inbox.take") # sale / expiry notices: read once
	var got := 0
	var why := ""
	for uid: String in stored:
		var res := screen.client.request("vault.withdraw", {"uid": uid})
		if not res.get("ok", false):
			why = MarketConfirm.say_error(res)
			break
		got += 1
	screen.refresh_wallet()
	refresh()
	waiting.text = ("Received %d. " % got) + (why if why != "" else waiting.text)
	return {"received": got, "why": why}

## 5400 -> "1 h 30 min"; under a minute -> "1 min".
static func _span(s: int) -> String:
	s = maxi(s, 60)
	if s >= 86400:
		return "%d d" % (s / 86400)
	if s >= 3600:
		return "%d h" % (s / 3600) + (" %d min" % (s % 3600 / 60) if s % 3600 >= 60 else "")
	return "%d min" % (s / 60)

func layout(r: Rect2) -> void:
	position = r.position
	size = r.size
	var m := screen.m
	bar.position = Vector2.ZERO
	bar.size = Vector2(r.size.x, 64)
	for b: Button in sub_btns.values():
		b.add_theme_font_size_override("font_size", m.small + 2)
		b.custom_minimum_size.x = 84.0 if m.compact else 140.0
	receive.add_theme_font_size_override("font_size", m.px)
	waiting.add_theme_font_size_override("font_size", m.small)
	panel.position = Vector2(0, 64 + m.gap)
	panel.size = Vector2(r.size.x, r.size.y - 64 - m.gap)
	empty.add_theme_font_size_override("font_size", m.px)
	for row in rows:
		row.px = m.px
		row.custom_minimum_size.y = m.row_h
