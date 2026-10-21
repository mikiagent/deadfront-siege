class_name DetailedStatsPanel
extends Control
## Character -> Detailed Stats (spec 13 s13): the survivor's real numbers grouped Combat / Crafting
## / Gathering / Survival, each with its power and skill levels. Only what the game computes
## (InvStats; groups in data/inv_ui.json detailed_stats): no Strength / Dexterity rows the code
## does not have. A power row's ">" opens this panel at its group.

signal back_pressed
signal close_pressed

var header: InvHeader
var _scroll: ScrollContainer
var _surface: ColorRect
var _frame: Control
var _box: VBoxContainer
var _rows := PackedStringArray()
var _anchors := {}
var _m := {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(InvTheme.backdrop()) # opaque: HUD controls must not show through a modal screen
	_surface = InvTheme.surface(InvTheme.PANEL_2, 0.8, 5.0)
	_surface.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_surface)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(func() -> void: InvPaint.frame(_frame, Rect2(Vector2.ZERO, _frame.size), 2.0 if _m.get("compact", false) else 3.0, 6))
	add_child(_frame)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 0)
	_scroll.add_child(_box)
	header = InvHeader.new()
	header.show_stones = false
	add_child(header)
	header.back_pressed.connect(func() -> void: back_pressed.emit())
	header.close_pressed.connect(func() -> void: close_pressed.emit())
	resized.connect(_layout)

## Fill from `player` now and show; `group` ("combat", ...) scrolls there.
func open(player: Player, group: String = "") -> void:
	if not visible:
		InvMotion.fade_in(self)
	visible = true
	header.set_title("Detailed Stats")
	_layout()
	for c in _box.get_children():
		_box.remove_child(c) # out now: the scroll offset below sums the rows that stay
		c.queue_free()
	_rows.clear()
	_anchors.clear()
	var snap := InvStats.snapshot(player)
	var powers := InvStats.powers_data()
	for g: Dictionary in (InvView.data().get("detailed_stats", {}) as Dictionary).get("groups", []):
		_anchors[str(g.id)] = _row(str(g.label), "", InvTheme.TEXT_OFF, true)
		for k: String in g.get("stats", []):
			_row(_label_of(k), InvStats.fmt(k, snap.get(k, 0)), InvTheme.TEXT)
		var trees: Array = (g.get("trees", []) as Array).duplicate()
		if g.has("power"):
			var p: Dictionary = powers.get(str(g.power), {})
			_row(str(p.get("label", g.power)), "%d" % InvStats.power(player, str(g.power)), InvTheme.SELECT)
			trees = (p.get("trees", []) as Array) + trees
		for t: String in trees:
			_row(str(SkillState.NAMES.get(t, t.capitalize())), LevelDisplay.label(player.skills.level_of(t) if player.skills else 0), InvTheme.TEXT_2)
	# Rows have fixed heights, so the group's offset is known before the box lays out.
	var y := 0.0
	for c: Control in _box.get_children():
		if c == _anchors.get(group):
			break
		y += c.custom_minimum_size.y
	_scroll.scroll_vertical = int(y) if _anchors.has(group) else 0
	_scroll_to.call_deferred(int(y) if _anchors.has(group) else 0)

## Every line shown, "label  value" (tests read these).
func rows() -> PackedStringArray:
	return _rows

func _label_of(key: String) -> String:
	for r in InvStats.ROWS:
		if r[0] == key:
			return r[1]
	return key.capitalize()

func _row(text: String, value: String, color: Color, heading: bool = false) -> Control:
	_rows.append(("%s  %s" % [text, value]).strip_edges())
	var row := HBoxContainer.new()
	var px: int = (_m.get("section_font", 16) as int) if heading else (_m.get("row_font", 20) as int)
	row.custom_minimum_size = Vector2(0, float(_m.get("row_h", 44)) * (0.9 if heading else 1.0))
	for part in [[text, true], [value, false]]:
		if str(part[0]) == "":
			continue
		var l := Label.new()
		l.text = str(part[0])
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if heading else VERTICAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL if part[1] else Control.SIZE_SHRINK_END
		if part[1]: # only the label gives way; a clipped value would shrink to nothing
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.add_theme_font_size_override("font_size", px)
		l.add_theme_color_override("font_color", color if part[1] or not heading else InvTheme.TEXT)
		row.add_child(l)
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(12, 0)
	row.add_child(gutter)
	_box.add_child(row)
	return row

func _scroll_to(y: int) -> void:
	_scroll.scroll_vertical = y # again once the content has its size (a scroll past it is clamped)

func _layout() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var safe := InvTheme.safe(get_viewport()) if is_inside_tree() else Vector4.ZERO
	_m = InvTheme.metrics(Vector2(size.x - safe.w - safe.x, size.y))
	var head_h: float = _m.header_h + safe.z
	header.position = Vector2.ZERO
	header.size = Vector2(size.x, head_h)
	header.insets = safe
	header.apply_metrics(_m)
	# A centred column like the reference panels, not a full-width sheet.
	var w := minf(size.x - float(_m.margin) * 2.0 - safe.w - safe.x, 760.0 if not _m.compact else 560.0)
	_scroll.position = Vector2((size.x - w) * 0.5, head_h + float(_m.gap))
	_scroll.size = Vector2(w, size.y - _scroll.position.y - float(_m.margin) - safe.y)
	_surface.position = _scroll.position - Vector2(12, 0)
	_surface.size = _scroll.size + Vector2(24, 0)
	_frame.position = _surface.position
	_frame.size = _surface.size
	_frame.queue_redraw()
