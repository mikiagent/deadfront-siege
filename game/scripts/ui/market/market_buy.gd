class_name MarketBuy
extends Control
## Buy (spec 14): a category column (View All + kinds), then the listing table: search field and
## the sortable "Level / Durability / Price" headers (the active one GOLD, a triangle for its
## direction), one row per listed instance. A row opens the confirm with the exact instance and Buy.

## ASSUMPTION: spec 14 shows a Taming Materials column with clade sub-types, which the canon search
## cannot filter (no clade/market_category filter without the old EXCHANGE hooks). These use the
## filters market.search has: items.json categories, and asset=pet for bonded animals.
const CATEGORIES := [
	["View All", {}], ["Tools", {"category": "tool"}], ["Weapons", {"category": "weapon"}],
	["Food", {"category": "food"}], ["Wood", {"category": "wood"}], ["Stone", {"category": "stone"}],
	["Fibre", {"category": "fibre"}], ["Bone", {"category": "bone"}], ["Hide", {"category": "hide"}],
	["Animals", {"asset": "pet"}],
]
const SORTS := [["Level", "level"], ["Durability", "durability"], ["Price", "price"]]
const COLS := [0.5, 0.66, 0.82]

var screen: MarketScreen
var cat := 0
var sort_key := "price"
var sort_asc := true
var q := ""
var cat_panel: PanelContainer
var cat_title: Label
var cat_btns: Array[Button] = []
var table: PanelContainer
var head: Control
var search: LineEdit
var sort_btns: Array[Button] = []
var scroll: ScrollContainer
var list: VBoxContainer
var empty: Label
var rows: Array[MarketRow] = []

func _ready() -> void:
	cat_panel = PanelContainer.new()
	cat_panel.name = "Categories"
	cat_panel.add_theme_stylebox_override("panel", MarketScreen.panel_box())
	add_child(cat_panel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	cat_panel.add_child(cv)
	cat_title = MarketScreen.lbl("Categories", 22, UiTokens.TEXT, true)
	cat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_title.custom_minimum_size.y = 56
	cat_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cv.add_child(cat_title)
	var cs := ScrollContainer.new()
	cs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(cs)
	var cl := VBoxContainer.new()
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.add_theme_constant_override("separation", 0)
	cs.add_child(cl)
	for i in CATEGORIES.size():
		var b := Button.new()
		b.name = "Cat%d" % i
		b.text = CATEGORIES[i][0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 64
		b.pressed.connect(func () -> void:
			cat = i
			refresh())
		b.draw.connect(_draw_cat.bind(b, i))
		cl.add_child(b)
		cat_btns.append(b)
	table = PanelContainer.new()
	table.name = "Table"
	table.add_theme_stylebox_override("panel", MarketScreen.panel_box())
	add_child(table)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	table.add_child(tv)
	head = Control.new()
	head.name = "Head"
	head.custom_minimum_size.y = 64
	head.draw.connect(func () -> void: head.draw_rect(Rect2(Vector2.ZERO, head.size), Color(UiTokens.HEADER, 0.6)))
	head.resized.connect(_place_head)
	tv.add_child(head)
	search = LineEdit.new()
	search.name = "Search"
	search.placeholder_text = "Search item name"
	search.clear_button_enabled = true
	search.add_theme_font_override("font", UiTokens.ui_face())
	search.text_submitted.connect(func (t: String) -> void:
		q = t.strip_edges()
		refresh())
	search.text_changed.connect(func (t: String) -> void:
		if t == "" and q != "": # the clear (x) button: back to every listing
			q = ""
			refresh())
	head.add_child(search)
	for s: Array in SORTS:
		var b := Button.new()
		b.name = "Sort_" + str(s[1])
		b.flat = true
		b.text = s[0]
		b.add_theme_font_override("font", UiTokens.ui_face())
		b.pressed.connect(func () -> void:
			sort_asc = (not sort_asc) if sort_key == s[1] else true
			sort_key = s[1]
			refresh())
		b.draw.connect(_draw_sort.bind(b, str(s[1])))
		head.add_child(b)
		sort_btns.append(b)
	scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tv.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)
	empty = MarketScreen.lbl("No listings here yet.", 18, UiTokens.META)
	empty.name = "Empty"
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.custom_minimum_size.y = 96
	list.add_child(empty)

func refresh() -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	var args := {"sort": "%s_%s" % [sort_key, "asc" if sort_asc else "desc"], "page_size": 50, "q": q}
	args.merge(CATEGORIES[cat][1])
	var res := screen.client.request("market.search", args)
	empty.text = "No listings here yet." if res.get("ok", false) else MarketConfirm.say_error(res)
	for l: Dictionary in res.get("r", {}).get("results", []):
		var v := MarketRow.view_of(l.asset, int(l.price))
		v.listing = l
		var row := MarketRow.new(v)
		row.cols = PackedFloat32Array(COLS)
		row.px = screen.m.get("px", 22)
		row.custom_minimum_size.y = screen.m.get("row_h", 96)
		row.pressed.connect(open_listing.bind(v))
		list.add_child(row)
		rows.append(row)
	empty.visible = rows.is_empty()
	_paint()

## Header and category colours follow the state (set here, not in _draw, which would redraw forever).
func _paint() -> void:
	for i in cat_btns.size():
		cat_btns[i].add_theme_color_override("font_color", UiTokens.GOLD if i == cat else UiTokens.TEXT)
		cat_btns[i].add_theme_color_override("font_hover_color", UiTokens.GOLD)
		cat_btns[i].add_theme_color_override("font_focus_color", UiTokens.GOLD if i == cat else UiTokens.TEXT)
		cat_btns[i].queue_redraw()
	for i in sort_btns.size():
		var on: bool = SORTS[i][1] == sort_key
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			sort_btns[i].add_theme_color_override(c, UiTokens.GOLD if on else UiTokens.TEXT)
		sort_btns[i].queue_redraw()

## The confirm for one listed instance: seller, price, what the buyer can spend, then Buy.
func open_listing(v: Dictionary) -> void:
	var l: Dictionary = v.listing
	var price := int(l.price)
	var own := int(l.get("seller", -1)) == screen.client.account
	var why := "This is your own listing." if own else ("You have %d tradable T-stones; this costs %d." % [screen.tradable(), price] if screen.tradable() < price else "")
	var info := [["Seller", str(l.get("seller_name", "?"))], ["Price", "%s T-stones" % MarketRow._num(price)],
		["Your tradable T-stones", MarketRow._num(screen.tradable())]]
	var buy := func () -> Dictionary:
		var res := screen.client.request("market.buy", {"listing_id": str(l.id), "count": 1})
		if res.get("ok", false):
			res.say = "Bought. It waits in My Market: tap Receive All to take it into your bag."
		return res
	var done := func () -> void:
		screen.refresh_wallet()
		refresh()
	screen.confirm.open(v, info, "Buy for %s" % MarketRow._num(price), buy, done, why)

func layout(r: Rect2) -> void:
	position = r.position
	size = r.size
	var m := screen.m
	var g: float = m.gap
	cat_panel.position = Vector2.ZERO
	cat_panel.size = Vector2(m.cat_w, r.size.y)
	cat_title.add_theme_font_size_override("font_size", m.px)
	for b in cat_btns:
		b.add_theme_font_override("font", UiTokens.ui_face())
		b.add_theme_font_size_override("font_size", m.px)
		_flat(b)
	table.position = Vector2(m.cat_w + g, 0)
	table.size = Vector2(r.size.x - m.cat_w - g, r.size.y)
	search.add_theme_font_size_override("font_size", m.small + 2)
	for b in sort_btns:
		b.add_theme_font_size_override("font_size", m.small + 2)
	empty.add_theme_font_size_override("font_size", m.px)
	for row in rows:
		row.px = m.px
		row.custom_minimum_size.y = m.row_h
	_place_head()

func _place_head() -> void:
	if search == null or sort_btns.size() < SORTS.size():
		return # head resizes while _ready still builds it
	var w := head.size.x
	search.position = Vector2(10, 8)
	search.size = Vector2(w * COLS[0] - 20, 48)
	for i in sort_btns.size():
		var x0: float = w * COLS[i]
		var x1: float = w * (COLS[i + 1] if i + 1 < COLS.size() else 1.0)
		sort_btns[i].position = Vector2(x0, 0)
		sort_btns[i].size = Vector2(x1 - x0, 64)

func _flat(b: Button) -> void:
	var empty_sb := StyleBoxEmpty.new()
	empty_sb.content_margin_left = 16
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(s, empty_sb)

## The selected category is GOLD-washed with a GOLD label and a chevron (spec 14's Raptor Type row).
func _draw_cat(b: Button, i: int) -> void:
	var on := i == cat
	if on:
		b.draw_rect(Rect2(Vector2.ZERO, b.size), Color(UiTokens.GOLD, 0.22))
		var c := Vector2(b.size.x - 22, b.size.y * 0.5)
		b.draw_polyline(PackedVector2Array([c + Vector2(-5, -9), c + Vector2(4, 0), c + Vector2(-5, 9)]), UiTokens.GOLD, 3.0, true)
	var x := 0.0
	while x < b.size.x:
		b.draw_line(Vector2(x, b.size.y - 1), Vector2(minf(x + 3, b.size.x), b.size.y - 1), Color(UiTokens.DIVIDER, 0.5))
		x += 7.0

## The active sort header is GOLD with a filled triangle for its direction; the others show both.
func _draw_sort(b: Button, key: String) -> void:
	var on := key == sort_key
	var f := b.get_theme_font("font")
	var px := b.get_theme_font_size("font_size")
	var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var c := Vector2(b.size.x * 0.5 + tw * 0.5 + 10, b.size.y * 0.5)
	var col := UiTokens.GOLD if on else UiTokens.MUTED
	if not on or sort_asc:
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -2), c + Vector2(5, -2), c + Vector2(0, -8)]), col)
	if not on or not sort_asc:
		b.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 2), c + Vector2(5, 2), c + Vector2(0, 8)]), col)
