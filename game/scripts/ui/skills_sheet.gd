class_name SkillsSheet
extends Control
## C3 Skills (docs/design/ui-redesign-spec.md §7 C3, mockup ui-redesign/c3-skills.webp): a full-screen
## sheet with the shared chrome (§8). Left: a 4-column grid of the twelve skills (name with an unread
## dot when a node is buyable now, white symbol, thin XP bar, Lv.). Right: the selected skill's
## detail (parchment header, Skill XP, SP spent here, what levels it, the unlock list with each node's
## Unlock / Refund / lock reason) and a GOLD button that buys the next node.
## Public entry: open(skills, tree = "") / close(); HuntHud.open_skills() opens it from the HUD.
## F7 skill_debug.gd is separate and unchanged.


## White symbol per skill (icon ids from icons_manifest.json). SkillState.GLYPHS are system emoji,
## which draw in colour on macOS/iOS and break "white = actions".
## ASSUMPTION: these item symbols stand in for skill art until skill icons exist (W1-ICONART).
## Ranged and Weapon / Tools use the dart and pick: the crossbow drew as a thin line, the hammer as a blob.
const SYMBOLS := {
	"survival": "tent_kit", "gathering": "herb_leaf", "butchering": "stone_knife", "processing": "mortar_kit",
	"melee": "club", "ranged": "cactus_spine", "defense": "hide_strap", "weapon_tools": "work_pick",
	"tailoring": "thread", "construction": "pillar", "cooking": "skewer", "farming": "wheat",
}
const COLUMNS := 4
## Smallest skill cell height: 64 px tap target plus room for name, symbol, bar and level.
const ROW_H := 84.0

## Back (‹) is pressed: the host returns to its menu. Nothing connected: the sheet just closes.
signal back_requested

var skills: SkillState
var _c: Dictionary = {}
var _grid: GridContainer
var _scroll: ScrollContainer
var _detail: VBoxContainer
var _parch: PanelContainer
var _title: Label
var _sub: Label
var _xp_label: Label
var _xp_value: Label
var _xp_bar: ProgressBar
var _full: Label
var _spent_label: Label
var _spent: Label
var _box: VBoxContainer  ## the detail's unlock list (node rows are its direct children)
var _spend: Button
var _sp_pill: Label
var _tree: String = "survival"

func _ready() -> void:
	# The HUD that hosts this sheet has no size, so anchor to the viewport instead (top_level).
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 45  # above the HUD hexes that share its canvas layer (held slot, rails)
	visible = false
	_c = SheetChrome.build(self, "Skills")
	(_c["back"] as Button).pressed.connect(_on_back)
	var close_btn: Button = _c["close"]
	close_btn.name = "SkillsClose"
	close_btn.pressed.connect(close)
	_sp_pill = SheetChrome.label("", 22, UiTokens.TEXT)
	_sp_pill.name = "SkillsSp"
	_sp_pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(_c["right"] as Control).add_child(_sp_pill)
	var row := HBoxContainer.new()
	row.name = "SkillsBody"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 20)
	(_c["body"] as Control).add_child(row)
	var left := PanelContainer.new()
	left.name = "SkillsGridPanel"
	left.add_theme_stylebox_override("panel", SheetChrome.panel_style())
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	row.add_child(left)
	_scroll = ScrollContainer.new()
	_scroll.name = "SkillsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "SkillsGrid"
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	_scroll.add_child(_grid)
	var right := PanelContainer.new()
	right.name = "SkillsDetail"
	right.add_theme_stylebox_override("panel", SheetChrome.panel_style())
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 0)
	right.add_child(_detail)
	_parch = PanelContainer.new()
	_parch.name = "SkillsParchment"
	_detail.add_child(_parch)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 0)
	_parch.add_child(pv)
	_title = SheetChrome.label("", 32, UiTokens.PARCHMENT_INK, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_title)
	_sub = SheetChrome.label("", 18, UiTokens.PARCHMENT_INK)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_sub)
	var xp_box := VBoxContainer.new()
	xp_box.add_theme_constant_override("separation", 6)
	_detail.add_child(_padded(xp_box, "SkillsXpRow"))
	var xp_line := HBoxContainer.new()
	xp_box.add_child(xp_line)
	_xp_label = SheetChrome.label("Skill XP", 20)
	_xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_line.add_child(_xp_label)
	_xp_value = SheetChrome.label("", 20)
	_xp_value.name = "SkillXp"
	xp_line.add_child(_xp_value)
	_xp_bar = SheetChrome.thin_bar(0.0, UiTokens.XP, 6.0)
	xp_box.add_child(_xp_bar)
	_full = SheetChrome.label("", 15, UiTokens.GOLD)
	_full.name = "SkillXpFull"
	_full.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	xp_box.add_child(_full)
	var sp_line := HBoxContainer.new()
	_detail.add_child(_padded(sp_line, "SkillsSpentRow"))
	_spent_label = SheetChrome.label("SP spent here", 20)
	_spent_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp_line.add_child(_spent_label)
	_spent = SheetChrome.label("", 20, UiTokens.GOLD)
	_spent.name = "SkillsSpent"
	sp_line.add_child(_spent)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "SkillsNodes"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(list_scroll)
	var list_pad := MarginContainer.new()
	list_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "bottom"]:
		list_pad.add_theme_constant_override("margin_" + side, 18)
	list_pad.add_theme_constant_override("margin_right", scrollbar_reserve(list_scroll))
	list_scroll.add_child(list_pad)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_pad.add_child(_box)
	var foot := MarginContainer.new()
	foot.name = "SkillsFooter"
	_detail.add_child(foot)
	_spend = SheetChrome.gold_button("")
	_spend.name = "SkillsSpend"
	_spend.pressed.connect(_on_spend)
	foot.add_child(_spend)
	resized.connect(_layout)

static func scrollbar_reserve(scroll: ScrollContainer) -> int:
	return int(maxf(12.0, scroll.get_v_scroll_bar().get_combined_minimum_size().x)) + UiTokens.SPACE

func _padded(c: Control, nm: String) -> MarginContainer:
	var m := MarginContainer.new()
	m.name = nm
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 18)
	m.add_child(c)
	return m

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

## Opens on `tree` (a SkillState.ORDER id), or on the last selected skill when empty.
func open(p_skills: SkillState, tree: String = "") -> void:
	skills = p_skills
	if tree != "":
		_tree = tree
	visible = true
	_layout()

func close() -> void:
	visible = false

func _on_back() -> void:
	close()
	back_requested.emit()

## The whole safe area: a full-screen sheet on every canvas (spec §8).
static func panel_rect(view: Vector2, safe: Vector4 = Vector4.ZERO) -> Rect2:
	return Rect2(safe.w, safe.z, view.x - safe.w - safe.x, view.y - safe.z - safe.y)

## Kept for callers: the sheet is full-screen everywhere since the C3 rebuild.
static func is_sheet(_view: Vector2) -> bool:
	return true

func _layout() -> void:
	if _c.is_empty():
		return
	var view := get_viewport_rect().size
	SheetChrome.fit(_c, view, UiTokens.safe_insets(get_viewport()))
	var compact := SheetChrome.compact(view)
	_parch.add_theme_stylebox_override("panel", SheetChrome.parchment_style(6.0 if compact else 14.0, 6.0 if compact else 14.0))
	_parch.custom_minimum_size = Vector2(0, 48 if compact else 90)
	_title.add_theme_font_size_override("font_size", SheetChrome.px(view, 34, 19))
	_sub.add_theme_font_size_override("font_size", SheetChrome.px(view, 18, 12))
	for l: Label in [_xp_label, _xp_value, _spent, _spent_label]:
		l.add_theme_font_size_override("font_size", SheetChrome.px(view, 20, 13))
	_full.add_theme_font_size_override("font_size", SheetChrome.px(view, 15, 12))
	_sp_pill.add_theme_font_size_override("font_size", SheetChrome.px(view, 24, 16))
	_spend.add_theme_font_size_override("font_size", SheetChrome.px(view, 28, 16))
	_spend.custom_minimum_size = Vector2(0, 72 if not compact else SheetChrome.TAP)
	for m: MarginContainer in [_detail.get_node("SkillsXpRow"), _detail.get_node("SkillsSpentRow")]:
		m.add_theme_constant_override("margin_top", 3 if compact else 12)
		m.add_theme_constant_override("margin_bottom", 3 if compact else 12)
		m.add_theme_constant_override("margin_left", 10 if compact else 18)
		m.add_theme_constant_override("margin_right", 10 if compact else 18)
	var foot := _detail.get_node("SkillsFooter") as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		foot.add_theme_constant_override("margin_" + side, 6 if compact else 18)
	var list_pad := _box.get_parent() as MarginContainer
	for side in ["left", "top", "bottom"]:
		list_pad.add_theme_constant_override("margin_" + side, 10 if compact else 18)
	# The grid takes two thirds of the width on a desktop like the mockup; a phone gives the detail more.
	(_scroll.get_parent() as Control).size_flags_stretch_ratio = 2.0 if not compact else 1.25
	if visible:
		rebuild()

func rebuild() -> void:
	if skills == null or _grid == null:
		return
	_sp_pill.text = "SP  %d free" % skills.sp_available
	_build_grid()
	_build_detail()

## The unread dot: a node of this tree can be bought right now.
func _has_buyable(tree: String) -> bool:
	for n in skills.nodes(tree):
		if not bool(n.get("auto", false)) and skills.node_state(tree, n)[0] == "available":
			return true
	return false

func _build_grid() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)  # now, not at frame end: the new cell kept a generated name beside the old one
		c.queue_free()
	var view := get_viewport_rect().size
	var compact := SheetChrome.compact(view)
	var rows := ceili(float(SkillState.ORDER.size()) / COLUMNS)
	var body: Control = _c["body"]
	# Desktop: the rows fill the panel like the mockup; a phone keeps 84 px rows and scrolls.
	var cell_h := ROW_H if compact else maxf(ROW_H, floorf((body.size.y - 2.0) / rows))
	var focus: Array[Control] = []
	for id in SkillState.ORDER:
		var lvl := skills.level_of(id)
		var xp := skills.xp_of(id)
		var need := SkillState.xp_to_next(lvl)
		var capped := lvl >= skills.level_cap(id)
		var on := id == _tree
		var cell := Button.new()
		cell.name = "Skill_%s" % id
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = Vector2(SheetChrome.TAP, cell_h)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTokens.GOLD_DIM if on else Color(0, 0, 0, 0)
		sb.border_color = Color(1, 1, 1, 0.06)
		sb.set_border_width_all(1)
		var hv := sb.duplicate() as StyleBoxFlat
		hv.bg_color = UiTokens.GOLD_DIM
		for st in ["normal", "focus", "disabled"]:
			cell.add_theme_stylebox_override(st, sb)
		cell.add_theme_stylebox_override("hover", hv)
		cell.add_theme_stylebox_override("pressed", hv)
		var col := VBoxContainer.new()
		col.set_anchors_preset(Control.PRESET_FULL_RECT)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2 if compact else 12)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(col)
		var head := HBoxContainer.new()
		head.alignment = BoxContainer.ALIGNMENT_CENTER
		head.add_theme_constant_override("separation", 6)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(head)
		if _has_buyable(id):
			var dot := SheetChrome.Dot.new()
			dot.name = "Unread"
			dot.custom_minimum_size = Vector2(7, 7)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			head.add_child(dot)
		head.add_child(SheetChrome.label(str(SkillState.NAMES.get(id, id)), SheetChrome.px(view, 22, 13), UiTokens.GOLD if on else UiTokens.TEXT))
		var sym := symbol_rect(id, 22.0 if compact else 36.0)
		sym.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(sym)
		var bar_box := CenterContainer.new()
		bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(bar_box)
		# XP banked at the character-level cap reads as a full bar (spec 25 §7).
		var bar := SheetChrome.thin_bar(1.0 if capped else xp / maxf(1.0, need), UiTokens.XP, 3.0)
		bar.custom_minimum_size = Vector2(56.0 if compact else 160.0, 3.0)
		bar_box.add_child(bar)
		var lv_line := LevelDisplay.label(lvl)
		var lv := SheetChrome.label(lv_line, SheetChrome.px(view, 18, 12), UiTokens.MUTED)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(lv)
		if capped and xp > 0.0:
			# Spec 25 §7: at the cap the cell reads FULL and still shows the XP the next character level spends.
			var banked := SheetChrome.label("FULL · %d XP" % int(xp), SheetChrome.px(view, 14, 12), UiTokens.GOLD)
			banked.name = "SkillFull_%s" % id
			banked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(banked)
		if on:
			cell.add_child(SheetChrome.Brackets.new())
		var tree_id: String = id
		cell.pressed.connect(func () -> void:
			_tree = tree_id
			rebuild()
		)
		_grid.add_child(cell)
		focus.append(cell)
	UiTokens.focus_first(focus)

## SP this tree's learned (bought) nodes cost.
func _spent_in(tree: String) -> int:
	var total := 0
	for n in skills.nodes(tree):
		if not bool(n.get("auto", false)) and skills.is_unlocked(tree, str(n.get("id", ""))):
			total += int(n.get("sp", 0))
	return total

## The node the GOLD button buys: the first available one in tree order.
func _next_buy() -> Dictionary:
	for n in skills.nodes(_tree):
		if not bool(n.get("auto", false)) and skills.node_state(_tree, n)[0] == "available":
			return n
	return {}

func _build_detail() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var view := get_viewport_rect().size
	var compact := SheetChrome.compact(view)
	var lvl := skills.level_of(_tree)
	var xp := skills.xp_of(_tree)
	var need := SkillState.xp_to_next(lvl)
	var capped := lvl >= skills.level_cap(_tree)
	var nm := str(SkillState.NAMES.get(_tree, _tree))
	_title.text = nm
	_sub.text = LevelDisplay.label(lvl)
	_xp_value.text = "%d / %d" % [int(minf(xp, need)), int(need)]
	_xp_bar.value = 1.0 if capped else clampf(xp / maxf(1.0, need), 0.0, 1.0)
	_full.text = ("FULL · %d XP banked for the next character level" % int(xp)) if capped else ""
	_full.visible = capped and xp > 0.0
	_spent.text = str(_spent_in(_tree))
	var body := SheetChrome.px(view, 19, 13)
	var meta := SheetChrome.px(view, 15, 12)
	var levels_by := str((skills.defs.get(_tree, {}) as Dictionary).get("levels_by", ""))
	if levels_by != "":
		var about := SheetChrome.label("Levels by %s." % levels_by, body)
		about.name = "SkillsAbout"
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(about)
	var cap := SheetChrome.label("UNLOCKS", meta, UiTokens.MUTED)
	cap.name = "SkillsUnlocksCaption"
	_box.add_child(cap)
	var auto_learned: PackedStringArray = []
	var later: Array[Label] = []
	for n in skills.nodes(_tree):
		var st := skills.node_state(_tree, n)
		var nid := str(n.get("id", ""))
		var title := str(n.get("name", nid.replace("_", " ").capitalize()))
		var cost := "AUTO" if bool(n.get("auto", false)) else "%d SP" % int(n.get("sp", 0))
		var lv_txt := LevelDisplay.label(int(n.get("level", 1)))
		# Learned-free rows have nothing to tap; one summary line keeps the list actionable.
		if st[0] == "owned" and bool(n.get("auto", false)):
			auto_learned.append(title)
			continue
		# Nodes the game reads nothing from yet (spec 12:215) cannot be bought. They stay listed with
		# level, SP and the lock reason (spec 12 10.6) as muted rows with nothing to tap, after the rest.
		if st[0] == "locked" and st[1] == SkillState.NOT_IN_GAME:
			var lrow := SheetChrome.label("%s   %s  ·  %s  ·  %s" % [lv_txt, title, cost, SkillState.NOT_IN_GAME], meta, Color(UiTokens.MUTED, 0.75))
			lrow.name = "SkillsLater_" + nid
			lrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			later.append(lrow)
			continue
		var h := HBoxContainer.new()
		h.name = "SkillsNode_" + nid
		h.custom_minimum_size = Vector2(0, SheetChrome.TAP)
		h.add_theme_constant_override("separation", 10)
		var lvl_l := SheetChrome.label(lv_txt, body, UiTokens.MUTED)
		lvl_l.custom_minimum_size = Vector2(48 if compact else 64, 0)
		lvl_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(lvl_l)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		h.add_child(col)
		var name_col := UiTokens.OK_GREEN if st[0] == "owned" else (UiTokens.TEXT if st[0] == "available" else Color(UiTokens.TEXT, 0.7))
		var l := SheetChrome.label("%s  ·  %s" % [title, cost], body, name_col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		var unlocks := str(n.get("unlocks", ""))
		if unlocks != "" and unlocks.to_lower() != title.to_lower():
			var u := SheetChrome.label(unlocks, meta, UiTokens.MUTED)
			u.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(u)
		# SKILLTREES: one small honesty line about whether the node's effect is live in the game
		# (trees.json impl). defined -> "Not active yet", partial -> "Partly active"; functional
		# nodes need no line (their effect already runs).
		var impl := str(n.get("impl", ""))
		if impl == "defined":
			var na := SheetChrome.label("Not active yet", meta, UiTokens.MUTED)
			na.name = "ImplLine_" + nid
			na.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(na)
		elif impl == "partial":
			var pa := SheetChrome.label("Partly active", meta, UiTokens.MUTED)
			pa.name = "ImplLine_" + nid
			pa.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(pa)
		# A refund that would be refused (daily limit, a learned node needs it) is greyed and says why before the tap.
		var why := skills.refund_reason(_tree, nid) if st[0] == "owned" else ""
		if why != "":
			var reason := SheetChrome.label("Cannot refund: " + why, meta, UiTokens.MUTED)
			reason.name = "RefundBlock"
			reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(reason)
		var b := SheetChrome.action_button("", &"ghost", false)
		b.custom_minimum_size = Vector2(96 if compact else 140, SheetChrome.TAP)
		b.add_theme_font_size_override("font_size", meta + 1)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if st[0] == "owned":
			b.text = "Refund"
			b.disabled = why != ""
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
			b.tooltip_text = str(st[1])
			b.disabled = true
		h.add_child(b)
		_box.add_child(h)
	if not auto_learned.is_empty():
		var learned := SheetChrome.label("Learned automatically: " + ", ".join(auto_learned), meta, UiTokens.MUTED)
		learned.name = "SkillsLearnedAuto"
		learned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(learned)
	for row in later:
		_box.add_child(row)
	# GOLD action: buy the next node. ASSUMPTION: the mockup's "Spend 1 SP on Melee" maps to the
	# first node that is buyable now (a tree has no SP sink of its own); with none, it says why.
	var next := _next_buy()
	_spend.disabled = next.is_empty()
	if not next.is_empty():
		_spend.text = "Spend %d SP on %s" % [int(next.get("sp", 0)), str(next.get("name", next.get("id", "")))]
	else:
		_spend.text = "No SP to spend" if skills.sp_available <= 0 else "Nothing to unlock in %s yet" % nm

func _on_spend() -> void:
	var next := _next_buy()
	if next.is_empty():
		return
	skills.unlock(_tree, str(next.get("id", "")))
	rebuild()

## A skill's white symbol, `px` square (also on the character creation cards).
static func symbol_rect(id: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = HexButton.symbol([SYMBOLS.get(id, id), "hammer"])
	t.material = HexButton.white_material()
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
