class_name MarketSearch
extends Control
## The search sheet behind the table's magnifier: a name search (becomes a chip) and the market
## categories (open the category column). Categories show only when the server can filter by
## them (hook H2); without it the sheet offers the name search alone.

signal searched(q: String)
signal category_chosen(id: String)
signal cancelled

var field: LineEdit
var categories: Array[Button] = []
var _panel: PanelContainer
var _box: VBoxContainer
var _grid: GridContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func (e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			cancelled.emit())
	add_child(dim)
	_panel = PanelContainer.new()
	var sb := MarketTheme.flat(MarketTheme.DIALOG, MarketTheme.BORDER, 2, 6)
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	field = LineEdit.new()
	field.name = "SearchField"
	field.placeholder_text = "Item or animal name"
	field.max_length = 40 # MarketQuery.search: q is 0..40 characters
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.text_submitted.connect(func (t: String) -> void: searched.emit(t.strip_edges()))
	row.add_child(field)
	var go := Button.new()
	go.name = "SearchGo"
	go.text = "Search"
	go.pressed.connect(func () -> void: searched.emit(field.text.strip_edges()))
	row.add_child(go)
	MarketTheme.action(go, true, 16)
	if MarketFormat.has_filter("market_category"):
		_box.add_child(MarketTheme.label("Categories", 16, MarketTheme.TEXT_2))
		_grid = GridContainer.new()
		_grid.add_theme_constant_override("h_separation", 8)
		_grid.add_theme_constant_override("v_separation", 8)
		_box.add_child(_grid)
		for id: String in [""] + MarketFormat.categories(): # "" = All: leaves a chosen category
			var b := Button.new()
			b.name = "Category_%s" % (id if id != "" else "all")
			b.text = MarketFormat.category_title(id) if id != "" else "All"
			MarketTheme.action(b, false, 15)
			b.pressed.connect(func () -> void: category_chosen.emit(id))
			_grid.add_child(b)
			categories.append(b)

func open(q: String, m: Dictionary) -> void:
	visible = true
	field.text = q
	var safe: Rect2 = m.get("safe", get_viewport_rect())
	var compact: bool = m.compact
	var w := minf(safe.size.x - 32.0, 760.0 if not compact else safe.size.x - 32.0)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.size = Vector2(w, 0)
	field.custom_minimum_size.y = m.tmin
	field.add_theme_font_override("font", MarketTheme.font(m.name))
	field.add_theme_font_size_override("font_size", m.name)
	if _grid:
		_grid.columns = 6 if compact else 4
		for b in categories:
			b.custom_minimum_size = Vector2((w - 32.0 - 8.0 * (_grid.columns - 1)) / _grid.columns, m.tmin)
			b.add_theme_font_size_override("font_size", maxi(UiTokens.TYPE_MIN, int(m.type)))
	_panel.reset_size()
	_panel.position = safe.position + Vector2((safe.size.x - _panel.size.x) * 0.5, maxf(8.0, (safe.size.y - _panel.size.y) * 0.5))
	field.grab_focus.call_deferred()
