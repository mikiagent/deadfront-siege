class_name MarketCategories
extends Control
## The middle column while a category is chosen (reference: "Taming Materials" over View All and
## the sub-types): the category title with a close control, then one row per sub-type. The
## selected row is a gold gradient with a yellow chevron.

signal picked(key: String) ## "" = View All
signal closed

var title := ""
var entries: Array = [] ## [{key, title}], View All first
var selected := ""
var close_btn: Button
var buttons: Array[Button] = []
var _scroll: MarketDragScroll
var _list: VBoxContainer
var _m := {}

func _ready() -> void:
	close_btn = Button.new()
	close_btn.name = "CategoryClose"
	close_btn.tooltip_text = "All categories"
	close_btn.icon = UiIcons.icon(&"close")
	close_btn.expand_icon = true
	close_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	MarketTheme.bare(close_btn)
	close_btn.pressed.connect(func () -> void: closed.emit())
	add_child(close_btn)
	_scroll = MarketDragScroll.new()
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_scroll.add_child(_list)

func show_entries(p_title: String, p_entries: Array, p_selected: String) -> void:
	title = p_title
	entries = [{"key": "", "title": "View All"}] + p_entries
	selected = p_selected
	for b in buttons:
		b.queue_free()
	buttons.clear()
	for e: Dictionary in entries:
		var b := Button.new()
		b.name = ("Cat_%s" % (e.key if e.key != "" else "all")).validate_node_name()
		MarketTheme.bare(b)
		var key: String = e.key
		var t: String = e.title
		b.draw.connect(func () -> void: _draw_row(b, t, key == selected))
		b.mouse_filter = Control.MOUSE_FILTER_PASS # a drag over the rows scrolls them
		b.pressed.connect(func () -> void:
			if not _scroll.tap_ok():
				return
			selected = key
			for o in buttons:
				o.queue_redraw()
			picked.emit(key))
		_list.add_child(b)
		buttons.append(b)
	if not _m.is_empty():
		layout(_m, Rect2(position, size))

func layout(m: Dictionary, rect: Rect2) -> void:
	_m = m
	position = rect.position
	size = rect.size
	var th: float = m.thead_h
	var side := maxf(UiTokens.TARGET_MIN, th)
	close_btn.position = Vector2(size.x - side, 0)
	close_btn.size = Vector2(side, th)
	close_btn.add_theme_constant_override("icon_max_width", int(minf(side, th) * 0.42))
	_scroll.position = Vector2(0, th)
	_scroll.size = Vector2(size.x, size.y - th)
	_list.custom_minimum_size.x = size.x
	var rh := maxf(UiTokens.TARGET_MIN, roundf(m.row_h * 0.8))
	for b in buttons:
		b.custom_minimum_size = Vector2(size.x, rh)
		b.queue_redraw()
	queue_redraw()

func _draw() -> void:
	if _m.is_empty():
		return
	var th: float = _m.thead_h
	draw_style_box(MarketTheme.flat(Color(0.03, 0.04, 0.03, 0.24), MarketTheme.BORDER, 2, 3), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(2, 2, size.x - 4, th - 2), MarketTheme.BAND)
	MarketTheme.text(self, title, close_btn.size.x * 0.5, th * 0.5, size.x - close_btn.size.x * 2.0, _m.name, MarketTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_row(b: Button, t: String, on: bool) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	if on:
		var grad := PackedColorArray([Color(0.62, 0.55, 0.3, 0.7), Color(0.62, 0.55, 0.3, 0.7), Color(0.45, 0.42, 0.25, 0.25), Color(0.45, 0.42, 0.25, 0.25)])
		b.draw_polygon(PackedVector2Array([r.position, Vector2(r.position.x, r.end.y), r.end, Vector2(r.end.x, r.position.y)]), grad)
		var cs := r.size.y * 0.42
		MarketGlyphs.draw(b, &"chevron", Rect2(r.end.x - cs - _m.margin * 1.5, r.get_center().y - cs * 0.5, cs, cs), MarketTheme.GOLD)
	MarketTheme.dotted(b, Vector2(6, r.end.y - 1), Vector2(r.end.x - 6, r.end.y - 1))
	MarketTheme.text(b, t, _m.margin * 2.0, r.get_center().y, r.size.x - _m.margin * 4.0 - r.size.y * 0.42, _m.name, MarketTheme.GOLD if on else MarketTheme.TEXT)
