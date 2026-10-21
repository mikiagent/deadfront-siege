class_name MarketMine
extends Control
## The My Market tab (spec 06 seller tabs Active / Sold / Expired / History, and Receive All).
## Every row is the server's: market.mine's open listings (each with Cancel), its closed ones
## (sold; expired and cancelled) and the account's trades. Receive All takes the inbox (shown as
## the status line) and then sends one vault.withdraw per item and pet waiting in market storage,
## paced under the write limit. Sales are credited straight to the wallet by the engine, so
## Receive All moves goods only (exchange-spec A5). Cancel opens MarketConfirm's cancel panel.

signal cancel_pressed(view: Dictionary)
signal loaded ## after every market.mine + vault.get (tests and the lab wait on it)
signal received(moved: int, waiting: int)

const TABS := [[&"active", "Active"], [&"sold", "Sold"], [&"expired", "Expired"], [&"history", "History"]]
const EMPTY := {
	&"active": "Nothing listed. Sell lists an item from your bag.",
	&"sold": "Nothing sold yet.",
	&"expired": "No expired or cancelled listings.",
	&"history": "No trades yet.",
}
const PACE_S := 0.25 ## Receive All: at most 4 withdrawals a second (contract 5.4 allows 5 writes/s)

var client: MarketClient
var tab := &"active"
var mine := {} ## the last market.mine answer
var waiting: Array = [] ## uids in market storage: items, then pets
var page := 1 ## page of closed listings (Sold / Expired)
var pages := 1
var page_size := 20
var rows: Array[MarketRow] = []
var tab_btns := {} ## id -> Button
var receive_btn: Button
var status: Label
var receiving := false
var _waiting_label: Label
var _scroll: MarketDragScroll
var _list: VBoxContainer
var _empty: Label
var _pager: HBoxContainer
var _page_label: Label
var _prev: Button
var _next: Button
var _m := {}

func _ready() -> void:
	for t: Array in TABS:
		var b := Button.new()
		b.name = "Mine_%s" % t[0]
		MarketTheme.bare(b)
		var id: StringName = t[0]
		b.pressed.connect(func () -> void: show_sub(id))
		add_child(b)
		tab_btns[id] = b
	_scroll = MarketDragScroll.new()
	_scroll.name = "MineRows"
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_scroll.add_child(_list)
	_empty = MarketTheme.label("", 16, MarketTheme.TEXT_2)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_empty)
	_pager = HBoxContainer.new()
	_pager.name = "MinePager"
	_pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pager.alignment = BoxContainer.ALIGNMENT_END
	add_child(_pager)
	_prev = _pager_button("‹", "MinePrev", -1)
	_page_label = MarketTheme.label("", 16)
	_pager.add_child(_page_label)
	_next = _pager_button("›", "MineNext", 1)
	status = MarketTheme.label("", 15, MarketTheme.TEXT)
	status.name = "MineStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 2
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(status)
	_waiting_label = MarketTheme.label("", 16, MarketTheme.TEXT_2)
	_waiting_label.name = "MineWaiting"
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_waiting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_waiting_label)
	receive_btn = Button.new()
	receive_btn.name = "ReceiveAll"
	receive_btn.text = "Receive All"
	receive_btn.pressed.connect(receive_all)
	add_child(receive_btn)
	page_size = mini(20, EconRules.load_default().num("page_size_default")) # small frames (exchange-spec §10)

func _pager_button(t: String, nm: String, step: int) -> Button:
	var b := Button.new()
	b.name = nm
	b.text = t
	MarketTheme.action(b, false, 22)
	b.pressed.connect(func () -> void:
		page = clampi(page + step, 1, pages)
		reload())
	_pager.add_child(b)
	return b

func start(p_client: MarketClient) -> void:
	client = p_client
	page = 1
	status.text = ""
	await reload()

func show_sub(id: StringName) -> void:
	tab = id
	_build_rows()
	queue_redraw()

## market.mine (this page of closed listings) and vault.get, then the rows of the shown sub-tab.
func reload() -> void:
	if client == null:
		return
	var res: Dictionary = await client.request("market.mine", {"page": page, "page_size": page_size})
	var vault: Dictionary = await client.request("vault.get")
	mine = res.r if res.get("ok", false) else {}
	pages = maxi(1, ceili(float(int(mine.get("closed_total", {}).get("listings", 0))) / page_size))
	waiting.clear()
	if vault.get("ok", false):
		for k: String in ["items", "pets"]:
			for a: Dictionary in vault.r.get(k, []):
				waiting.append(str(a.uid))
	_waiting_label.text = ("%d waiting in market storage" % waiting.size()) if not waiting.is_empty() else "Market storage is empty"
	receive_btn.disabled = waiting.is_empty() or receiving
	_build_rows()
	if not res.get("ok", false):
		_empty.text = MarketFormat.error_text(res)
	queue_redraw()
	loaded.emit()

func _build_rows() -> void:
	for old in rows:
		old.queue_free()
	rows.clear()
	var c := columns()
	for model: Dictionary in MarketFormat.mine_rows(mine, tab, client.account if client else -1, client.now() if client else 0):
		var row := MarketRow.new()
		row.setup(model.view, false, c, _m, model)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE # a row here is information; its Cancel is the action
		row.focus_mode = Control.FOCUS_NONE
		if model.cancel:
			var b := Button.new()
			b.name = "Cancel_%s" % model.id
			b.text = "Cancel"
			MarketTheme.action(b, false, int(_m.get("name", 16)))
			var v: Dictionary = model.view
			b.mouse_filter = Control.MOUSE_FILTER_PASS # a drag that starts on Cancel still scrolls
			b.pressed.connect(func () -> void:
				if _scroll.tap_ok():
					cancel_pressed.emit(v))
			row.add_child(b)
		_list.add_child(row)
		rows.append(row)
	_empty.text = "" if not rows.is_empty() else str(EMPTY[tab]) + (" Older ones are on the next page." if pages > 1 and tab in [&"sold", &"expired"] else "")
	_pager.visible = pages > 1 and tab in [&"sold", &"expired"]
	_page_label.text = "  %d / %d  " % [page, pages]
	_prev.disabled = page <= 1
	_next.disabled = page >= pages
	_scroll.scroll_vertical = 0
	if not _m.is_empty():
		layout(_m, Rect2(position, size))

## inbox.take, then every uid in market storage back to the bag, paced. A refusal (a full bag, the
## bonded roster) leaves that one waiting and the rest still come home; pressing again retries only
## what is still there, so nothing moves twice.
func receive_all() -> void:
	if receiving or client == null:
		return
	receiving = true
	receive_btn.disabled = true
	var news: PackedStringArray = []
	var inbox: Dictionary = await client.request("inbox.take")
	if inbox.get("ok", false):
		for e: Dictionary in inbox.r.get("events", []):
			news.append(MarketFormat.event_text(e))
	var todo := waiting.duplicate()
	var moved := 0
	var why := ""
	for i in todo.size():
		if i > 0:
			await get_tree().create_timer(PACE_S).timeout
		_say("Receiving %d of %d…" % [i + 1, todo.size()], MarketTheme.TEXT_2)
		var res: Dictionary = await client.request("vault.withdraw", {"uid": todo[i]})
		if res.get("ok", false):
			moved += 1
		elif why == "":
			why = MarketFormat.error_text(res)
	receiving = false
	await reload()
	var head := "Received %d into your bag." % moved if moved > 0 else ("Nothing was waiting." if todo.is_empty() else "")
	if not waiting.is_empty():
		head = ("%s %d still waiting: %s" % [head, waiting.size(), why]).strip_edges()
	var said := PackedStringArray()
	if head != "":
		said.append(head)
	for n in news.slice(0, 3):
		said.append(n + ".")
	if news.size() > 3:
		said.append("And %d more." % (news.size() - 3))
	_say(" ".join(said), MarketTheme.DANGER if why != "" else MarketTheme.GOLD)
	received.emit(moved, waiting.size())

func _say(text: String, color: Color) -> void:
	status.text = text
	status.tooltip_text = text
	status.add_theme_color_override("font_color", color)

## Column geometry of every row (MarketRow's keys); Active also has the Cancel column, the other
## sub-tabs give that width to the status.
func columns() -> Dictionary:
	var w := size.x
	var pad: float = _m.get("margin", 8.0)
	var name_x: float = pad + float(_m.get("icon", 40.0)) + 12.0
	var price_x := 0.72 if tab == &"active" else 0.8
	return {"icon_x": pad, "name_x": name_x, "name_w": w * 0.38 - name_x - 4.0, "level_x": w * 0.38, "level_w": w * 0.1,
		"dur_x": w * 0.48, "dur_w": w * (price_x - 0.48), "price_x": w * price_x, "price_w": w * 0.13 if tab == &"active" else w * 0.2 - pad,
		"act_x": w * 0.86, "act_w": w * 0.14 - pad}

func footer_h() -> float:
	return float(_m.pager_h) + 12.0

func layout(m: Dictionary, rect: Rect2) -> void:
	_m = m
	position = rect.position
	size = rect.size
	var th: float = m.thead_h
	var tw := minf(220.0, roundf(size.x * 0.18))
	for i in TABS.size():
		var b: Button = tab_btns[TABS[i][0]]
		b.position = Vector2(m.margin * 0.5 + i * tw, 0)
		b.size = Vector2(tw, th)
	var px: float = m.margin * 0.5 + TABS.size() * tw
	_pager.position = Vector2(px, 0)
	_pager.size = Vector2(size.x - px - m.margin, th)
	for b: Button in [_prev, _next]:
		b.custom_minimum_size = Vector2(maxf(UiTokens.TARGET_MIN, th), UiTokens.TARGET_MIN)
	MarketTheme.size_label(_page_label, m.name)
	var fh := footer_h()
	_scroll.position = Vector2(0, th)
	_scroll.size = Vector2(size.x, size.y - th - fh)
	_list.custom_minimum_size.x = size.x
	var c := columns()
	var bh := maxf(UiTokens.TARGET_MIN, minf(56.0, m.row_h * 0.5))
	for r in rows:
		r.relayout(c, m)
		for b in r.get_children():
			if b is Button:
				MarketTheme.action(b, false, m.name)
				b.position = Vector2(c.act_x, (m.row_h - bh) * 0.5)
				b.size = Vector2(c.act_w, bh)
	_empty.position = Vector2(m.margin, th + 24)
	_empty.size = Vector2(size.x - m.margin * 2, 80)
	MarketTheme.size_label(_empty, m.name)
	var rw := 150.0 if m.compact else 220.0
	receive_btn.size = Vector2(rw, fh - 12.0)
	receive_btn.position = Vector2(size.x - rw - m.margin, size.y - fh + 5.0)
	MarketTheme.action(receive_btn, true, m.name)
	MarketTheme.size_label(_waiting_label, m.type + (0 if m.compact else 2))
	var ww := _waiting_label.get_minimum_size().x + 4.0
	_waiting_label.position = Vector2(receive_btn.position.x - ww - m.margin, size.y - fh)
	_waiting_label.size = Vector2(ww, fh)
	status.position = Vector2(m.margin, size.y - fh)
	status.size = Vector2(_waiting_label.position.x - m.margin * 2, fh)
	MarketTheme.size_label(status, m.type)
	queue_redraw()

func _draw() -> void:
	if _m.is_empty():
		return
	var th: float = _m.thead_h
	draw_style_box(MarketTheme.flat(Color(0.03, 0.04, 0.03, 0.24), MarketTheme.BORDER, 2, 3), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(2, 2, size.x - 4, th - 2), MarketTheme.BAND)
	MarketTheme.dotted(self, Vector2(6, th), Vector2(size.x - 6, th))
	var fy := size.y - footer_h()
	draw_rect(Rect2(2, fy, size.x - 4, footer_h() - 2), MarketTheme.BAND)
	MarketTheme.dotted(self, Vector2(6, fy), Vector2(size.x - 6, fy))
	for t: Array in TABS:
		var b: Button = tab_btns[t[0]]
		var r := Rect2(b.position, b.size)
		var on: bool = t[0] == tab
		if on:
			draw_rect(r.grow(-3), Color(0.78, 0.72, 0.52, 0.2))
			MarketTheme.brackets(self, r.grow(-3), minf(r.size.x, r.size.y) * 0.22, maxf(2.0, r.size.y * 0.05))
		elif t != TABS.back():
			draw_rect(Rect2(r.end.x - 1, r.position.y + r.size.y * 0.3, 1.5, r.size.y * 0.4), Color(0.5, 0.5, 0.46, 0.6))
		var label: String = t[1]
		if t[0] == &"active" and not mine.is_empty():
			label += "  %d/%d" % [(mine.get("listings", []) as Array).size(), EconRules.load_default().num("max_open_listings")]
		MarketTheme.text(self, label, r.position.x + 6, r.get_center().y, r.size.x - 12, _m.name, MarketTheme.GOLD if on else MarketTheme.ACTION, HORIZONTAL_ALIGNMENT_CENTER)
