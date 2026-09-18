class_name SkillsSheet
extends Control
## Twelve skill rows (glyph, name, level, XP bar, SP); tap a row for its tree: nodes with
## cost, required level and state; tap to unlock. One-handed on a phone (rows ≥ 56 px).

var skills: SkillState
var _panel: PanelContainer
var _box: VBoxContainer
var _tree: String = ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_panel = PanelContainer.new()
	_panel.position = Vector2(40, 30)
	_panel.custom_minimum_size = Vector2(620, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.10, 0.97)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 800)
	_panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.custom_minimum_size = Vector2(580, 0)
	scroll.add_child(_box)

func open(p_skills: SkillState, tree: String = "") -> void:
	skills = p_skills
	_tree = tree
	visible = true
	rebuild()

func close() -> void:
	visible = false

func rebuild() -> void:
	for c in _box.get_children():
		c.queue_free()
	if skills == null:
		return
	if _tree == "":
		_build_overview()
	else:
		_build_tree()

func _header(text: String, right: String = "") -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if right != "":
		var r := Label.new()
		r.text = right
		r.add_theme_font_size_override("font_size", 20)
		r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		h.add_child(r)
	_box.add_child(h)

func _build_overview() -> void:
	_header("Skills", "SP %d" % skills.sp_available)
	for id in SkillState.ORDER:
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 58)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var lvl := skills.level_of(id)
		var xp := skills.xp_of(id)
		var need := SkillState.xp_to_next(lvl)
		row.text = "%s  %-16s Lv. %2d     %3.0f / %3.0f XP    owned %d" % [SkillState.GLYPHS.get(id, "•"), SkillState.NAMES.get(id, id), lvl, xp, need, (skills.trees[id]["unlocked"] as Array).size()]
		row.add_theme_font_size_override("font_size", 17)
		var tree_id := id
		row.pressed.connect(func () -> void:
			_tree = tree_id
			rebuild()
		)
		_box.add_child(row)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = need
		bar.value = xp
		bar.show_percentage = false
		_box.add_child(bar)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 56)
	close_btn.pressed.connect(close)
	_box.add_child(close_btn)

func _build_tree() -> void:
	_header("%s %s  Lv. %d" % [SkillState.GLYPHS.get(_tree, ""), SkillState.NAMES.get(_tree, _tree), skills.level_of(_tree)], "SP %d" % skills.sp_available)
	var info := Label.new()
	info.text = str((skills.defs.get(_tree, {}) as Dictionary).get("levels_by", ""))
	info.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(info)
	for n in skills.nodes(_tree):
		var st := skills.node_state(_tree, n)
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(0, 60)
		var l := Label.new()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = "%s  · Lv. %d · %d SP\n%s" % [str(n.get("id", "")).replace("_", " ").capitalize(), int(n.get("level", 1)), int(n.get("sp", 0)), str(n.get("unlocks", ""))]
		l.add_theme_font_size_override("font_size", 15)
		match st[0]:
			"owned":
				l.add_theme_color_override("font_color", Color(0.55, 0.9, 0.5))
			"locked":
				l.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		h.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(140, 56)
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
		else:
			b.text = str(st[1])
			b.disabled = true
		h.add_child(b)
		_box.add_child(h)
	var back := Button.new()
	back.text = "◀ All skills"
	back.custom_minimum_size = Vector2(0, 56)
	back.pressed.connect(func () -> void:
		_tree = ""
		rebuild()
	)
	_box.add_child(back)
