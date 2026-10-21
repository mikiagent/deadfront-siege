class_name MarketTable
extends Control
## The Buy table: a header band (search, "Item Name/Type", Level, Durability, Price; a column sorts
## only when the server offers that sort, the active one is yellow), a chip per active search, one
## MarketRow per listing, and an honest empty state. The list scrolls like the reference (no
## pager): near its end it asks for the server's next page and appends it. Sorting and paging
## always ask the server again; nothing is sorted here.

signal search_pressed
signal sort_pressed(col: StringName)
signal chip_removed(key: StringName)
signal page_requested(page: int) ## the next server page, when the list is scrolled near its end
signal row_pressed(view: Dictionary)

## column -> [ascending sort, descending sort, default direction]
const SORT_COLS := {&"level": ["level_asc", "level_desc", -1], &"durability": ["durability_asc", "durability_desc", -1], &"price": ["price_asc", "price_desc", 1]}
const HEADS := {&"level": "Level", &"durability": "Durability", &"price": "Price"}

var sort := "price_asc"
var offered: Array = [] ## sorts the server has (MarketFormat.sorts())
var chips: Array = [] ## [{key, text}]
var page := 1
var pages := 1
var total := 0
var rows: Array[MarketRow] = []
var account := -1
var empty_text := "No listings match."
var loading := false ## a next page is on its way (MarketBuy sets it): ask once
var build_us := 0 ## how long the last show_page took to build its rows (lab: 500-listing gate)
var heads_cut: PackedStringArray = [] ## header words the last draw had to cut (lab: none may be)

var search_btn: Button
var head_btns: Dictionary = {} ## col -> Button (only sortable columns)
var _chip_box: HBoxContainer
var _scroll: MarketDragScroll
var _list: VBoxContainer
var _empty: Label
var _m := {}

func _ready() -> void:
	search_btn = Button.new()
	search_btn.name = "SearchButton"
	search_btn.tooltip_text = "Search"
	MarketTheme.bare(search_btn)
	search_btn.draw.connect(_draw_search)
	search_btn.pressed.connect(func () -> void: search_pressed.emit())
	add_child(search_btn)
	for col: StringName in SORT_COLS:
		var b := Button.new()
		b.name = "Sort_%s" % col
		MarketTheme.bare(b)
		b.pressed.connect(func () -> void: sort_pressed.emit(col))
		add_child(b)
		head_btns[col] = b
	_chip_box = HBoxContainer.new()
	_chip_box.add_theme_constant_override("separation", 8)
	add_child(_chip_box)
	_scroll = MarketDragScroll.new()
	_scroll.name = "Rows"
	_scroll.get_v_scroll_bar().value_changed.connect(func (_v: float) -> void: _maybe_more())
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_empty = MarketTheme.label("", 16, MarketTheme.TEXT_2)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_empty)

## Column geometry shared by the header and every row: Level, Durability and Price take their
## share of the width (14 / 18 / 18 %) or what their full header word with its arrows (and
## Price's "1,000,000") needs, whichever is more; the name gets the rest and is cut first.
func columns() -> Dictionary:
	var w := size.x
	var pad: float = _m.margin
	var name_x: float = pad + _m.icon + 12.0
	var hs: int = _m.head
	var need := func (col: StringName) -> float: return MarketTheme.width(HEADS[col], hs) + hs * 0.7 + 16.0
	var ns: int = _m.name
	var pw := maxf(w * 0.18 - pad * 0.5, maxf(need.call(&"price"), MarketTheme.width("1,000,000", ns) + ns * 1.25 + 14.0))
	var dw := maxf(w * 0.18, need.call(&"durability"))
	var lw := maxf(w * 0.14, need.call(&"level"))
	var price_x := w - pad * 0.5 - pw
	return {"icon_x": pad, "name_x": name_x, "name_w": price_x - dw - lw - name_x - 4.0,
		"level_x": price_x - dw - lw, "level_w": lw, "dur_x": price_x - dw, "dur_w": dw,
		"price_x": price_x, "price_w": pw}

func layout(m: Dictionary, rect: Rect2) -> void:
	_m = m
	position = rect.position
	size = rect.size
	var th: float = m.thead_h
	search_btn.position = Vector2(m.margin * 0.5, 0)
	search_btn.size = Vector2(maxf(m.tmin, th), th)
	var c := columns()
	for col: StringName in head_btns:
		var b: Button = head_btns[col]
		b.position = Vector2(c["%s_x" % ("dur" if col == &"durability" else col)], 0)
		b.size = Vector2(c["%s_w" % ("dur" if col == &"durability" else col)], th)
		b.visible = _sortable(col)
	var y := th
	_chip_box.visible = not chips.is_empty()
	if _chip_box.visible:
		_chip_box.position = Vector2(m.margin, y + 4)
		_chip_box.size = Vector2(size.x - m.margin * 2, m.chip_h - 8)
		for ch: Control in _chip_box.get_children():
			ch.custom_minimum_size.y = maxf(m.tmin, m.chip_h - 8)
		y += m.chip_h
	_scroll.position = Vector2(0, y)
	_scroll.size = Vector2(size.x, size.y - y)
	_list.custom_minimum_size.x = size.x
	for r in rows:
		r.relayout(c, m)
	_empty.position = Vector2(m.margin, y + 24)
	_empty.size = Vector2(size.x - m.margin * 2, 80)
	MarketTheme.size_label(_empty, m.name)
	queue_redraw()

## One server page, rows in the order the server sent them, one per listing. Page 1 replaces the
## list; a later page is appended, skipping a listing already shown (a sale or a new listing
## between two requests shifts the server's pages by one).
func show_page(r: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	total = int(r.get("total", 0))
	page = int(r.get("page", 1))
	var per := maxi(1, int(r.get("page_size", 20)))
	pages = maxi(1, ceili(float(total) / per))
	loading = false
	var shown := {}
	if page <= 1:
		for old in rows:
			old.queue_free()
		rows.clear()
		_scroll.scroll_vertical = 0
	else:
		for row in rows:
			shown[str(row.view.get("id", ""))] = true
	for v: Dictionary in r.get("results", []):
		if shown.has(str(v.get("id", ""))):
			continue
		var row := MarketRow.new()
		row.setup(v, account >= 0 and int(v.get("seller", -2)) == account, columns(), _m)
		row.mouse_filter = Control.MOUSE_FILTER_PASS # a drag over the rows scrolls them (MarketDragScroll)
		row.pressed.connect(func () -> void:
			if _scroll.tap_ok():
				row_pressed.emit(row.view))
		_list.add_child(row)
		rows.append(row)
	_empty.text = "" if not rows.is_empty() else empty_text
	build_us = Time.get_ticks_usec() - t0
	if not _m.is_empty() and page <= 1:
		layout(_m, Rect2(position, size))
	_maybe_more.call_deferred() # a tall screen may show the whole page at once

func remove_listing(id: String) -> void:
	for row in rows.duplicate():
		if str(row.view.get("id", "")) == id:
			rows.erase(row)
			row.queue_free()

## Asks for the next page once the last two rows come into view.
func _maybe_more() -> void:
	if loading or page >= pages or rows.is_empty() or not is_visible_in_tree():
		return
	var left := _list.size.y - (_scroll.scroll_vertical + _scroll.size.y)
	if left <= float(_m.get("row_h", 48.0)) * 2.0:
		loading = true
		page_requested.emit(page + 1)

## A failed search: no rows, the reason in their place.
func show_error(text: String) -> void:
	show_page({})
	_empty.text = text

func set_chips(list: Array) -> void:
	chips = list
	for c in _chip_box.get_children():
		c.queue_free()
	for c: Dictionary in chips:
		var b := Button.new()
		b.name = "Chip_%s" % c.key
		b.text = "%s  ✕" % c.text
		b.tooltip_text = "Clear %s" % c.text
		for st: String in ["normal", "hover", "pressed"]: # even padding on both sides of the words (references)
			var sb := MarketTheme.flat(Color(0.06, 0.06, 0.05, 0.82) if st == "normal" else Color(0.12, 0.12, 0.11, 0.9), MarketTheme.GOLD if st == "pressed" else Color(0.3, 0.3, 0.28, 1), 1, 4)
			sb.content_margin_left = 14
			sb.content_margin_right = 12
			b.add_theme_stylebox_override(st, sb)
		var cs := maxi(14, int(_m.get("name", 16)) - 2)
		b.add_theme_font_override("font", MarketTheme.font())
		b.add_theme_font_size_override("font_size", cs)
		b.add_theme_color_override("font_color", MarketTheme.TEXT)
		var key: StringName = c.key
		b.pressed.connect(func () -> void: chip_removed.emit(key))
		_chip_box.add_child(b)

func _sortable(col: StringName) -> bool:
	var s: Array = SORT_COLS[col]
	return s[0] in offered or s[1] in offered

## The sort a header press asks for: the other direction of the active column when the server has
## it, else the column's default direction (higher level / durability first, cheapest first).
func next_sort(col: StringName) -> String:
	var s: Array = SORT_COLS[col]
	if sort == s[0] and s[1] in offered:
		return s[1]
	if sort == s[1] and s[0] in offered:
		return s[0]
	var first: String = s[0] if int(s[2]) == 1 else s[1]
	return first if first in offered else (s[1] if first == s[0] else s[0])

func _draw() -> void:
	if _m.is_empty():
		return
	var th: float = _m.thead_h
	draw_style_box(MarketTheme.panel(), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(2, 2, size.x - 4, th - 2), MarketTheme.BAND)
	MarketTheme.dotted(self, Vector2(6, th), Vector2(size.x - 6, th))
	var c := columns()
	var hs: int = _m.head
	heads_cut.clear()
	if MarketTheme.text(self, "Item Name/Type", search_btn.position.x + search_btn.size.x, th * 0.5, c.level_x - search_btn.size.x - 8.0, hs, MarketTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER):
		heads_cut.append("Item Name/Type")
	for col: StringName in SORT_COLS:
		var key := "dur" if col == &"durability" else str(col)
		var x: float = c["%s_x" % key]
		var w: float = c["%s_w" % key]
		draw_rect(Rect2(x, th * 0.3, 1.5, th * 0.4), Color(0.5, 0.5, 0.46, 0.6))
		var s: Array = SORT_COLS[col]
		var active: bool = sort == s[0] or sort == s[1]
		var col_c := MarketTheme.GOLD if active else MarketTheme.TEXT
		var label: String = HEADS[col]
		var aw := hs * 0.7 if _sortable(col) else 0.0
		var tw := minf(MarketTheme.width(label, hs), w - aw - 10.0)
		var tx := x + (w - tw - aw) * 0.5
		if MarketTheme.text(self, label, tx, th * 0.5, tw, hs, col_c):
			heads_cut.append(label)
		if _sortable(col):
			var dir := (1 if sort == s[0] else -1) if active else 0
			MarketGlyphs.sort_arrows(self, Vector2(tx + tw + aw * 0.6, th * 0.5), hs * 1.1, dir, col_c, col_c.darkened(0.45) if active else col_c)

func _draw_search() -> void:
	var r := Rect2(Vector2.ZERO, search_btn.size)
	var d := minf(r.size.x, r.size.y) * 0.72
	search_btn.draw_circle(r.get_center(), d * 0.5, Color(0.12, 0.12, 0.11, 0.9))
	var tex := UiIcons.icon(&"inspect")
	if tex:
		search_btn.draw_texture_rect(tex, Rect2(r.get_center() - Vector2(d, d) * 0.32, Vector2(d, d) * 0.64), false)
