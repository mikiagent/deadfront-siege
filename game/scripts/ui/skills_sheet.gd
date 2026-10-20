class_name SkillsSheet
extends Control
## Twelve skill rows (symbol, name, level, XP bar, owned nodes) in fixed columns; tap a row for
## its tree: nodes with cost, required level and state; tap to unlock. One-handed on a phone
## (rows >= 56 px). The panel sits in the content area between the HUD blocks, never over the vitals;
## on a landscape phone it is an opaque full-screen sheet in two columns, like craft.

## White symbol per skill (icon ids from icons_manifest.json). SkillState.GLYPHS are system emoji,
## which draw in colour on macOS/iOS and break "white = actions".
## ASSUMPTION: these item symbols stand in for skill art until skill icons exist (W1-ICONART).
## Ranged and Weapon / Tools use the dart and pick: the crossbow drew as a thin line, the hammer as a blob.
const SYMBOLS := {
	"survival": "tent_kit", "gathering": "herb_leaf", "butchering": "stone_knife", "processing": "mortar_kit",
	"melee": "club", "ranged": "cactus_spine", "defense": "hide_strap", "weapon_tools": "work_pick",
	"tailoring": "thread", "construction": "pillar", "cooking": "skewer", "farming": "wheat",
}
const PANEL_MAX_W := 760.0
const ROW_H := 56.0
## Fixed name column off portrait, so the XP bar takes the spare width instead of a gap before "Lv.".
const NAME_W_COMPACT := 132.0
const NAME_W := 170.0

var skills: SkillState
var _panel: PanelContainer
var _box: VBoxContainer
var _head: HBoxContainer
var _tree: String = ""

func _ready() -> void:
	# The HUD that hosts this sheet has no size, so anchor to the viewport instead (top_level),
	# and reset offsets: inside the tree set_anchors_preset keeps the current empty rect.
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 45  # above the HUD hexes that share its canvas layer (held slot, rails)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.05, 0.86)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	bg.gui_input.connect(func (ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed) or (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed):
			close()
	)
	_panel = PanelContainer.new()  # styled in _layout (edge to edge on a landscape phone)
	add_child(_panel)
	# Header (title, SP, Close) pinned above the scroll: at the end of the list Close sat below
	# the fold on desktop.
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	_head = HBoxContainer.new()
	_head.name = "SkillsHeader"
	_head.add_theme_constant_override("separation", UiTokens.SPACE)
	column.add_child(_head)
	var scroll := ScrollContainer.new()
	scroll.name = "SkillsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	# Reserve the scrollbar's width: without it the SP label and every row's right edge ran under it.
	var pad := MarginContainer.new()
	pad.name = "ScrollPad"
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_right", scrollbar_reserve(scroll))
	scroll.add_child(pad)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_box)
	resized.connect(_layout)

static func scrollbar_reserve(scroll: ScrollContainer) -> int:
	return int(maxf(12.0, scroll.get_v_scroll_bar().get_combined_minimum_size().x)) + UiTokens.SPACE

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func open(p_skills: SkillState, tree: String = "") -> void:
	skills = p_skills
	_tree = tree
	visible = true
	_layout()
	rebuild()

func close() -> void:
	visible = false

## Panel rect: centred between the vitals (top-left) and the map/quest block (top-right) on
## desktop; on a portrait phone full width from just under the vitals (the opaque panel covers the
## map). A landscape phone gets the whole safe area: under the vitals only 3 of 12 rows fitted.
static func panel_rect(view: Vector2, safe: Vector4 = Vector4.ZERO) -> Rect2:
	if is_sheet(view):
		return Rect2(safe.w, safe.z, view.x - safe.w - safe.x, view.y - safe.z - safe.y)
	var top := 24.0
	var bottom := 24.0
	var w := minf(PANEL_MAX_W, view.x - 2.0 * 340.0)
	if UiTokens.is_compact(view) or w < 480.0:
		w = view.x - 16.0
		top = 100.0
		bottom = 100.0
	return Rect2(Vector2((view.x - w) * 0.5, top), Vector2(w, maxf(200.0, view.y - top - bottom)))

## Landscape phone: full-screen opaque sheet, skill rows in two columns.
static func is_sheet(view: Vector2) -> bool:
	return UiTokens.is_compact(view) and not UiTokens.is_narrow(view)

func _layout() -> void:
	if _panel == null:
		return
	var view := get_viewport_rect().size
	var r := panel_rect(view, UiTokens.safe_insets(get_viewport()))
	_panel.position = r.position
	_panel.size = r.size
	var sb := UiTokens.panel_style(1.0)
	if is_sheet(view):
		# Edge to edge: square corners, so nothing of the HUD peeks past them; 8 px top and bottom fit five rows.
		sb.set_corner_radius_all(0)
		sb.set_border_width_all(0)
		sb.content_margin_top = UiTokens.SPACE
		sb.content_margin_bottom = UiTokens.SPACE
	_panel.add_theme_stylebox_override("panel", sb)
	var scroll := _panel.find_child("SkillsScroll", true, false) as ScrollContainer
	if scroll:
		scroll.custom_minimum_size = Vector2(r.size.x - 32.0, 0.0)

func rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	if skills == null:
		return
	if _tree == "":
		_build_overview()
	else:
		_build_tree()

func _header(text: String, right: String = "", symbol_id: String = "") -> void:
	var view := get_viewport_rect().size
	var h := _head
	for c in h.get_children():
		h.remove_child(c)
		c.queue_free()
	if symbol_id != "":
		h.add_child(_symbol(symbol_id, 32.0))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiTokens.heading(view))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	if right != "":
		var r := Label.new()
		r.text = right
		r.add_theme_font_size_override("font_size", UiTokens.body(view) + 4)
		r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		h.add_child(r)
	var close_btn := Button.new()
	close_btn.name = "SkillsClose"
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(112, 56)
	close_btn.pressed.connect(close)
	h.add_child(close_btn)

func _symbol(id: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = HexButton.symbol([SYMBOLS.get(id, id), "hammer"])
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## A label in a fixed-width column so every row lines up.
func _cell(text: String, w: float, size_px: int, color: Color = UiTokens.TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(w, 0)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_overview() -> void:
	var view := get_viewport_rect().size
	var narrow := UiTokens.is_narrow(view)
	var compact := UiTokens.is_compact(view)
	var body := UiTokens.body(view)
	var meta := UiTokens.meta(view)
	_header("Skills", "SP %d" % skills.sp_available)
	var grid := GridContainer.new()
	grid.name = "SkillsGrid"
	grid.columns = 2 if is_sheet(view) else 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", UiTokens.SPACE)
	grid.add_theme_constant_override("v_separation", 6)
	_box.add_child(grid)
	var rows: Array[Control] = []
	for id in SkillState.ORDER:
		var lvl := skills.level_of(id)
		var xp := skills.xp_of(id)
		var need := SkillState.xp_to_next(lvl)
		var row := Button.new()
		row.name = "Skill_%s" % id
		row.custom_minimum_size = Vector2(0, ROW_H)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cols := HBoxContainer.new()
		cols.set_anchors_preset(Control.PRESET_FULL_RECT)
		cols.offset_left = 10
		cols.offset_right = -10
		cols.add_theme_constant_override("separation", 10)
		cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cols)
		cols.add_child(_symbol(id, 28.0))
		var name_cell := _cell(str(SkillState.NAMES.get(id, id)), 0.0 if narrow else (NAME_W_COMPACT if compact else NAME_W), body)
		if narrow:
			name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(name_cell)
		cols.add_child(_cell(LevelDisplay.label(lvl), 56.0, body, UiTokens.TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
		var xp_col := VBoxContainer.new()
		xp_col.custom_minimum_size = Vector2(96.0, 0)
		if not narrow:
			xp_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_col.alignment = BoxContainer.ALIGNMENT_CENTER
		xp_col.add_theme_constant_override("separation", 2)
		xp_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cols.add_child(xp_col)
		xp_col.add_child(_cell("%d / %d XP" % [int(xp), int(need)], 0.0, meta, UiTokens.META, HORIZONTAL_ALIGNMENT_RIGHT))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = maxf(1.0, need)
		bar.value = xp
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		xp_col.add_child(bar)
		if not compact:
			var owned := (skills.trees[id]["unlocked"] as Array).size()
			cols.add_child(_cell("%d owned" % owned, 76.0, meta, UiTokens.META, HORIZONTAL_ALIGNMENT_RIGHT))
		var tree_id := id
		row.pressed.connect(func () -> void:
			_tree = tree_id
			rebuild()
		)
		grid.add_child(row)
		rows.append(row)
	UiTokens.focus_first(rows)

func _build_tree() -> void:
	var view := get_viewport_rect().size
	_header("%s  %s" % [SkillState.NAMES.get(_tree, _tree), LevelDisplay.label(skills.level_of(_tree))], "SP %d" % skills.sp_available, _tree)
	var info := Label.new()
	info.text = str((skills.defs.get(_tree, {}) as Dictionary).get("levels_by", ""))
	info.add_theme_color_override("font_color", UiTokens.META)
	info.add_theme_font_size_override("font_size", UiTokens.meta(view))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(info)
	var first: Array[Control] = []
	for n in skills.nodes(_tree):
		var st := skills.node_state(_tree, n)
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(0, 60)
		h.add_theme_constant_override("separation", UiTokens.SPACE)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = "%s  ·  %s  ·  %d SP\n%s" % [str(n.get("id", "")).replace("_", " ").capitalize(), LevelDisplay.label(int(n.get("level", 1))), int(n.get("sp", 0)), str(n.get("unlocks", ""))]
		l.add_theme_font_size_override("font_size", UiTokens.meta(view) + 2)
		match st[0]:
			"owned":
				l.add_theme_color_override("font_color", Color(0.55, 0.9, 0.5))
			"locked":
				l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		h.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(120 if UiTokens.is_narrow(view) else 140, 56)
		var nid := str(n.get("id", ""))
		if st[0] == "owned":
			b.text = "Refund"
			b.pressed.connect(func () -> void:
				skills.refund(_tree, nid)
				rebuild()
			)
		elif st[0] == "available":
			b.text = "Unlock"
			b.pressed.connect(func () -> void:
				skills.unlock(_tree, nid)
				rebuild()
			)
			first.append(b)
		else:
			b.text = str(st[1])
			b.disabled = true
		h.add_child(b)
		_box.add_child(h)
	var back := Button.new()
	back.text = "All skills"
	back.custom_minimum_size = Vector2(0, 56)
	back.pressed.connect(func () -> void:
		_tree = ""
		rebuild()
	)
	_box.add_child(back)
	first.append(back)
	UiTokens.focus_first(first)
