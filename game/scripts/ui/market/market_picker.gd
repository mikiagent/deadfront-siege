class_name MarketPicker
extends Control
## Sell's exact-instance picker on the Bag's textured panel: one cell per bag stack or instance,
## bonded pet and stored item (MarketFormat.sell_entries), never merged. A cell shows the art,
## grey "Lv. n" top-right, "×n" for a stack, the "B" badge on a bonded pet (pet carrier art), a
## "Stored" tag on what waits in market storage, an "Equipped" tag on what the character wears or
## holds; the picked one has the four yellow brackets.
## A refused cell stays visible, dimmed, with a lock (or blocked) mark; the Sell panel says why.
# swap: INVUI InventoryGrid / InventorySlot when they reach this base (same look).

signal picked(uid: String)

var entries: Array = []
var selected := "" ## the picked entry's uid
var cells: Array[Button] = [] ## cells[i] shows entries[i]
var stored := 0 ## entries waiting in market storage
var _scroll: MarketDragScroll
var _grid: GridContainer
var _empty: Label
var _fill: Array[Control] = [] ## empty compartments after the last cell, up to the visible rows
var _m := {}
var _cell := 96.0

func _ready() -> void:
	_scroll = MarketDragScroll.new()
	_scroll.name = "Cells"
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	_scroll.add_child(_grid)
	_empty = MarketTheme.label("", 16, MarketTheme.TEXT_2)
	_empty.name = "PickerEmpty"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_empty)

func show_entries(list: Array, p_selected: String, empty_text: String) -> void:
	entries = list
	selected = p_selected
	stored = 0
	for c in cells + _fill: # fillers too: new cells must come first in the grid
		_grid.remove_child(c)
		c.queue_free()
	cells.clear()
	_fill.clear()
	for e: Dictionary in entries:
		var b := Button.new()
		b.name = "Cell_%s" % str(e.uid).validate_node_name()
		b.tooltip_text = str(e.name) if str(e.why) == "" else "%s: %s" % [e.name, e.why]
		MarketTheme.bare(b)
		b.draw.connect(_draw_cell.bind(b, e))
		var uid := str(e.uid)
		b.mouse_filter = Control.MOUSE_FILTER_PASS # a drag over the cells scrolls them
		b.pressed.connect(func () -> void:
			if _scroll.tap_ok():
				picked.emit(uid))
		_grid.add_child(b)
		cells.append(b)
		if e.src == "vault":
			stored += 1
	_empty.text = empty_text if entries.is_empty() else ""
	_scroll.scroll_vertical = 0
	if not _m.is_empty():
		layout(_m, Rect2(position, size))

func set_selected(uid: String) -> void:
	selected = uid
	for c in cells:
		c.queue_redraw()

func cell_of(uid: String) -> Button:
	for i in entries.size():
		if str(entries[i].uid) == uid:
			return cells[i]
	return null

func layout(m: Dictionary, rect: Rect2) -> void:
	_m = m
	position = rect.position
	size = rect.size
	var th: float = m.thead_h
	var pad := 6.0
	var inner := Vector2(size.x - pad * 2.0, size.y - th - pad - 2.0)
	var cols := maxi(3, floori(inner.x / (76.0 if m.compact else 132.0)))
	_cell = floorf(inner.x / cols)
	# Whole rows fill the panel (a part row cut by its edge read as clipped): cells a little taller
	# or shorter than wide, like the Bag's compartments.
	var rows_shown := maxi(1, roundi(inner.y / _cell))
	var cell := Vector2(_cell, floorf(inner.y / rows_shown))
	_grid.columns = cols
	for c in cells:
		c.custom_minimum_size = cell
	# Empty compartments fill the visible rows, like the Bag's grid (they are not targets).
	var want := maxi(0, cols * rows_shown - cells.size())
	while _fill.size() > want:
		var gone: Control = _fill.pop_back()
		_grid.remove_child(gone)
		gone.queue_free()
	while _fill.size() < want:
		var f := Control.new()
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.draw.connect(_draw_edges.bind(f))
		_grid.add_child(f)
		_fill.append(f)
	for f in _fill:
		f.custom_minimum_size = cell
		f.queue_redraw()
	_scroll.position = Vector2(pad, th + 2.0)
	_scroll.size = inner
	_empty.position = Vector2(m.margin, th + 24.0)
	_empty.size = Vector2(size.x - m.margin * 2.0, 80)
	MarketTheme.size_label(_empty, m.name)
	queue_redraw()

func _draw() -> void:
	if _m.is_empty():
		return
	var th: float = _m.thead_h
	draw_style_box(MarketTheme.panel(), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(2, 2, size.x - 4, th - 2), MarketTheme.BAND)
	MarketTheme.dotted(self, Vector2(6, th), Vector2(size.x - 6, th))
	var hs: int = _m.head
	MarketTheme.text(self, "Your Bag", _m.margin, th * 0.5, size.x * 0.5, hs, MarketTheme.TEXT)
	var n := entries.size() - stored
	var summary := "%d %s" % [n, "item" if n == 1 else "items"] + ("  ·  %d in market storage" % stored if stored > 0 else "")
	MarketTheme.text(self, summary, size.x * 0.4, th * 0.5, size.x * 0.6 - _m.margin, _m.type, MarketTheme.TEXT_2, HORIZONTAL_ALIGNMENT_RIGHT)

## Faint dashed compartment lines on the right and bottom edge (the Bag reference's grid).
func _draw_edges(c: Control) -> void:
	var s := c.size
	MarketTheme.dotted(c, Vector2(s.x - 1, 4), Vector2(s.x - 1, s.y - 4), Color(0.62, 0.6, 0.53, 0.22), 6.0)
	MarketTheme.dotted(c, Vector2(4, s.y - 1), Vector2(s.x - 4, s.y - 1), Color(0.62, 0.6, 0.53, 0.22), 6.0)

func _draw_cell(b: Button, e: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	_draw_edges(b)
	if b.is_hovered() or b.has_focus():
		b.draw_rect(r.grow(-2), Color(1, 1, 1, 0.05))
	var refused := str(e.why) != ""
	var fs: int = _m.type
	var art := r.grow(-r.size.x * 0.17)
	art.position.y += fs * 0.3
	var tint: Color = e.tint
	if refused:
		tint = Color(tint.r * 0.5, tint.g * 0.5, tint.b * 0.5, 0.45)
	MarketIcon.paint(b, e.icon, art, tint)
	var inset := 8.0 # tags and labels sit inside the bracket corners
	MarketTheme.text(b, LevelDisplay.label(e.level), 4, inset + fs * 0.5, r.size.x - inset - 6, fs, MarketTheme.LV, HORIZONTAL_ALIGNMENT_RIGHT)
	if e.badge:
		MarketGlyphs.badge_b(b, Vector2(inset + fs * 0.7, inset + fs * 0.6), fs * 0.7)
	var foot := 0.0 ## a "Stored" / "Equipped" ribbon along the bottom (a top-left tag ran into "Lv. n"); count and mark sit above it
	if e.src == "vault" or e.get("equipped", false):
		foot = roundf(fs * 1.45)
		b.draw_rect(Rect2(3, r.size.y - foot - 3, r.size.x - 6, foot), Color(0.3, 0.25, 0.1, 0.9))
		MarketTheme.text(b, "Equipped" if e.get("equipped", false) else "Stored", 3, r.size.y - 3 - foot * 0.5, r.size.x - 6, fs, MarketTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	if int(e.count) > 1:
		MarketTheme.text(b, "×%d" % int(e.count), 4, r.size.y - inset - fs * 0.5 - foot, r.size.x - inset - 6, fs, MarketTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	if refused and not e.get("equipped", false): # an equipped one says so on its ribbon
		var mark := UiIcons.icon(&"lock" if "locked" in (e.asset.get("flags", []) as Array) else &"blocked")
		if mark:
			var ms := maxf(16.0, fs * 1.3)
			b.draw_texture_rect(mark, Rect2(inset, r.size.y - ms - inset - foot, ms, ms), false)
	if str(e.uid) == selected:
		MarketTheme.brackets(b, r.grow(-3), r.size.x * 0.16, maxf(3.0, r.size.x * 0.03))
