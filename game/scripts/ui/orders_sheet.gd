class_name OrdersSheet
extends Control
## TASKSCREEN (owner 2026-10-28, Durango's Task screen; replaces the C4 Orders sheet): SheetChrome's
## full-screen frame headed "Task". Left: the category tabs (Daily Task, Achievement, Domain Construction,
## Main Task, Weekly Task), a red dot on any with something to receive, GOLD corner brackets on the open one.
## Right: that category's task rows (Tasks.rows): grey flat-top hex icon, GOLD title, grey description,
## a thin GOLD bar with "got/want" centred, the reward line, and a GOLD Receive only when complete.
## Receive pays once (Tasks.claim) and opens the "<Task> Complete" popup listing what was paid.
## Main Task rows are the standing orders; one not yet done can be tracked on the HUD card (hunt_hud.gd
## reads OrdersSheet.hud_step). Public entry: open(player) / close(); HuntHud.open_orders() opens it.
## ASSUMPTION: Durango's "Prodigal Pioneer" (returning-player) tab is left out: no such system exists.

## Back (‹) is pressed: the host returns to its menu. Nothing connected: the sheet just closes.
signal back_requested

## The order the HUD card follows; -1 follows the current one. ASSUMPTION: session-only (not saved),
## so the save format is unchanged; a load follows the current order again.
static var tracked: int = -1
## HUDRULES: the HUD card is expanded (else the minimap badge). Session-only; starts collapsed.
static var hud_expanded: bool = false

## T-stones read "Gold" on screen (owner 2026-10-28, BAGUI currency bar); the field keeps its name.
const REWARD_ICONS := {"t_stones": &"t_stones", "warp_gems": &"warp_gem", "sp": &"brain", "xp": &"xp"}
const REWARD_NAMES := {"t_stones": "Gold", "warp_gems": "Warp Gems", "sp": "Skill Point", "xp": "EXP"}
const REWARD_ORDER := ["t_stones", "warp_gems", "sp", "xp"]

var player: Player
var cat: StringName = &"main"  ## the open category
var _c: Dictionary = {}
var _tabs: VBoxContainer
var _tab_scroll: ScrollContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _empty: Label
var popup: Control           ## the "<Task> Complete" dialog
var _pop_panel: PanelContainer
var _pop_title: Label
var _pop_rows: VBoxContainer
var _pop_ok: Button

## A grey flat-top hex with the task's white icon inside (spec: icons sit in flat-top hexes).
class HexIcon extends Control:
	var tex: Texture2D
	var lit := false
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		var pts := UiTokens.hex_points(c, r, true)
		draw_colored_polygon(pts, Color(0.22, 0.24, 0.26, 0.95))
		pts.append(pts[0])
		draw_polyline(pts, Color(UiTokens.GOLD, 0.8) if lit else Color(UiTokens.MUTED, 0.7), 2.0, true)
		if tex:
			var s := r * 1.05
			draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(0.86, 0.87, 0.88))

## The EXP reward glyph: a small flat-top hex in the XP colour lettered "XP" (Durango's XP hex).
class XpHex extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_colored_polygon(UiTokens.hex_points(c, r, true), UiTokens.XP)
		UiTokens.draw_centered(self, UiTokens.ui_face(UiTokens.WEIGHT_BOLD), c, "XP", maxi(UiTokens.TYPE_MIN, int(r * 0.95)), UiTokens.CTA_INK)

## The icon for reward `k` at `px`: the GOLD coin (T-stones, shown as Gold), the Warp Gem, the white brain (skill point), the XP hex.
static func reward_icon(k: String, px: float) -> Control:
	if k == "xp":
		var x := XpHex.new()
		x.custom_minimum_size = Vector2(px * 1.15, px)
		x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return x
	return SheetChrome.icon_rect(REWARD_ICONS[k], px, UiTokens.GOLD if k == "t_stones" else Color.WHITE)

## The thin GOLD progress bar with "got/want" centred on it.
class Bar extends Control:
	var frac := 0.0
	var text := ""
	var px := 14
	func _draw() -> void:
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(frac, 0.0, 1.0), h)), Color(UiTokens.GOLD, 0.85))
		draw_rect(Rect2(Vector2.ZERO, size), Color(UiTokens.GOLD, 0.45), false, 1.0)
		var f := UiTokens.ui_face(UiTokens.WEIGHT_BOLD)
		var at := UiTokens.centered_origin(f, text, px, size * 0.5)
		draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, Color(0, 0, 0, 0.85))
		draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)

func _ready() -> void:
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 45  # above the HUD hexes that share its canvas layer
	visible = false
	_c = SheetChrome.build(self, "Task")
	(_c["back"] as Button).pressed.connect(_on_back)
	var close_btn: Button = _c["close"]
	close_btn.name = "OrdersClose"
	close_btn.pressed.connect(close)
	var row := HBoxContainer.new()
	row.name = "OrdersBody"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	(_c["body"] as Control).add_child(row)
	_tab_scroll = ScrollContainer.new()
	_tab_scroll.name = "TaskTabsScroll"
	_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(_tab_scroll)
	_tabs = VBoxContainer.new()
	_tabs.name = "TaskTabs"
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_constant_override("separation", 4)
	_tab_scroll.add_child(_tabs)
	for c in Tasks.CATS:
		_tabs.add_child(_make_tab(c))
	var right := PanelContainer.new()
	right.name = "TaskListPanel"
	right.add_theme_stylebox_override("panel", SheetChrome.panel_style())
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_scroll = ScrollContainer.new()
	_scroll.name = "TaskScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "TaskList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	_scroll.add_child(_list)
	_empty = SheetChrome.label("Nothing here yet", 20, UiTokens.MUTED)
	_empty.name = "TaskEmpty"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.visible = false
	right.add_child(_empty)
	_build_popup()
	resized.connect(_layout)

func _make_tab(c: StringName) -> Button:
	var b := SheetChrome.Card.new()
	b.name = "Tab_%s" % c
	b.text = Tasks.NAMES[c]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_override("font", UiTokens.ui_face(500))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, UiTokens.TEXT)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.05)
	bg.content_margin_left = 18
	bg.content_margin_right = 26
	b.add_theme_stylebox_override("normal", bg)
	var dot := SheetChrome.Dot.new()
	dot.name = "Dot"
	dot.color = UiTokens.LIFE
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.offset_left = -20
	dot.offset_right = -8
	dot.offset_top = 8
	dot.offset_bottom = 20
	dot.visible = false
	b.add_child(dot)
	b.pressed.connect(func () -> void: select(c))
	return b

func _build_popup() -> void:
	popup = Control.new()
	popup.name = "TaskClaimPopup"
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.mouse_filter = Control.MOUSE_FILTER_STOP
	popup.visible = false
	add_child(popup)
	var dim := ColorRect.new()
	dim.name = "PopDim"
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(center)
	_pop_panel = PanelContainer.new()
	_pop_panel.name = "PopPanel"
	_pop_panel.add_theme_stylebox_override("panel", SheetChrome.panel_style(UiTokens.INK_SOLID))
	center.add_child(_pop_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_pop_panel.add_child(col)
	var head := PanelContainer.new()
	head.name = "PopHead"
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = UiTokens.GOLD
	hsb.set_content_margin_all(12)
	head.add_theme_stylebox_override("panel", hsb)
	col.add_child(head)
	_pop_title = SheetChrome.label("", 26, UiTokens.CTA_INK, true)
	_pop_title.name = "PopTitle"
	_pop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_pop_title)
	var pad := MarginContainer.new()
	pad.name = "PopPad"
	col.add_child(pad)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	pad.add_child(inner)
	_pop_rows = VBoxContainer.new()
	_pop_rows.name = "PopRewards"
	_pop_rows.add_theme_constant_override("separation", 6)
	inner.add_child(_pop_rows)
	_pop_ok = SheetChrome.gold_button("OK")
	_pop_ok.name = "PopOk"
	_pop_ok.pressed.connect(func () -> void: popup.visible = false)
	inner.add_child(_pop_ok)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if popup.visible:
			popup.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()

## Opens on the first category with something to receive, else Main Task.
func open(p: Player) -> void:
	player = p
	cat = &"main"
	for c in Tasks.CATS:
		if Tasks.claimable_count(p, c) > 0:
			cat = c
			break
	popup.visible = false
	visible = true
	_layout()

func close() -> void:
	popup.visible = false
	visible = false

func _on_back() -> void:
	close()
	back_requested.emit()

func select(c: StringName) -> void:
	cat = c
	rebuild()

## Receive: pays task `id` once (Tasks.claim) and shows what it paid. False when it was not claimable.
func receive(id: String) -> bool:
	var r := Tasks.claim(id, player)
	if r.is_empty():
		return false
	_show_popup(r)
	rebuild()
	return true

# ---------------------------------------------------------------- data (also for the HUD card)

static func steps() -> Array:
	return Objectives._steps()

## The order the HUD card follows: the tracked one while it is still ahead, else the current one.
static func shown_index() -> int:
	var cur := World.objective
	return tracked if tracked > cur and tracked < steps().size() else cur

## What the HUD quest card draws: Objectives.current for the running order (unchanged), or the
## tracked later order's row in the same shape. Only the running order pays out (Objectives.settle).
static func hud_step(p: Player) -> Dictionary:
	var i := shown_index()
	if p == null or i == World.objective:
		return Objectives.current(p)
	return row(p, i)

## HUDRULES: does fighting `c` serve order `i`? Its objectives.json `fight` list names creature ids;
## "*" = any wild animal (an order such as "Hunt something for meat").
static func served_by_fight(i: int, c: Creature) -> bool:
	var all := steps()
	if c == null or c.def == null or i < 0 or i >= all.size():
		return false
	var want: Variant = (all[i] as Dictionary).get("fight", [])
	if not want is Array:
		return false
	return "*" in want or str(c.def.id) in want

## {title, hint, progress, frac, done, index, count, xp, t_stones} for order `i`. Earlier orders are
## done; the running one reads Objectives.current (best-held count); a later one reads the bag now.
static func row(p: Player, i: int) -> Dictionary:
	var all := steps()
	if i < 0 or i >= all.size():
		return {}
	var s: Dictionary = all[i]
	var out := {"title": str(s.get("title", "")), "hint": str(s.get("hint", "")), "index": i, "count": all.size(),
		"xp": int(s.get("xp", 0)), "t_stones": int(s.get("t_stones", 0)), "warp_gems": int(s.get("warp_gems", 0))}
	if i < World.objective:
		out.merge({"progress": "Done", "frac": 1.0, "done": true})
	elif i == World.objective and p != null:
		var cur := Objectives.current(p)
		out.merge({"progress": str(cur.get("progress", "")), "frac": float(cur.get("frac", 0.0)), "done": bool(cur.get("done", false))})
	elif p != null:
		var st := Objectives._progress(p, s)
		out.merge({"progress": str(st["label"]), "frac": float(st["frac"]), "done": false})
	else:
		out.merge({"progress": "", "frac": 0.0, "done": false})
	return out

# ---------------------------------------------------------------- layout

func _layout() -> void:
	if _c.is_empty():
		return
	var view := get_viewport_rect().size
	SheetChrome.fit(_c, view, UiTokens.safe_insets(get_viewport()))
	var compact := SheetChrome.compact(view)
	(_tab_scroll.get_parent() as HBoxContainer).add_theme_constant_override("separation", 8 if compact else 16)
	_tab_scroll.custom_minimum_size = Vector2(204 if compact else 300, 0)
	_tabs.add_theme_constant_override("separation", 2 if compact else 6)
	for b: Button in _tabs.get_children():
		b.custom_minimum_size = Vector2(0, SheetChrome.TAP if compact else 84.0)
		b.add_theme_font_size_override("font_size", SheetChrome.px(view, 24, 16))
		(b.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_left = 12 if compact else 22
	_empty.add_theme_font_size_override("font_size", SheetChrome.px(view, 22, 15))
	_pop_title.add_theme_font_size_override("font_size", SheetChrome.px(view, 30, 20))
	_pop_panel.custom_minimum_size = Vector2(minf(view.x - 32.0, 560.0 if not compact else 400.0), 0)
	var pad := _pop_rows.get_parent().get_parent() as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12 if compact else 24)
	_pop_ok.add_theme_font_size_override("font_size", SheetChrome.px(view, 26, 18))
	_pop_ok.custom_minimum_size = Vector2(0, 72 if not compact else SheetChrome.TAP)
	if visible:
		rebuild()

func rebuild() -> void:
	if _list == null:
		return
	for b: SheetChrome.Card in _tabs.get_children():
		var c := StringName(str(b.name).trim_prefix("Tab_"))
		b.selected = c == cat
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, UiTokens.GOLD if c == cat else UiTokens.TEXT)
		(b.get_node("Dot") as Control).visible = Tasks.claimable_count(player, c) > 0
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var rows := Tasks.rows(cat, player)
	_empty.visible = rows.is_empty()
	for r in rows:
		_list.add_child(_make_row(r))

func _make_row(r: Dictionary) -> Control:
	var view := get_viewport_rect().size
	var compact := SheetChrome.compact(view)
	var box := PanelContainer.new()
	box.name = "Task_%s" % str(r["id"]).replace(".", "_")
	box.set_meta("task_id", r["id"])
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.035)
	sb.border_color = Color(1, 1, 1, 0.07)
	sb.border_width_bottom = 1
	sb.content_margin_left = 10 if compact else 20
	sb.content_margin_right = sb.content_margin_left
	sb.content_margin_top = 6 if compact else 14
	sb.content_margin_bottom = sb.content_margin_top
	box.add_theme_stylebox_override("panel", sb)
	if r["claimed"]:
		box.modulate = Color(1, 1, 1, 0.55)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10 if compact else 20)
	box.add_child(h)
	var hex := HexIcon.new()
	hex.name = "Icon"
	var icon_id := StringName(str(r["icon"]))
	hex.tex = UiIcons.icon(icon_id if UiIcons.path_for(icon_id) != "" else &"notice")
	hex.lit = r["claimable"]
	hex.custom_minimum_size = Vector2(56, 50) if compact else Vector2(96, 84)
	hex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(hex)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2 if compact else 6)
	h.add_child(col)
	var title := SheetChrome.text(str(r["title"]), SheetChrome.px(view, 26, 17), UiTokens.GOLD)
	title.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	col.add_child(title)
	col.add_child(SheetChrome.text(str(r["desc"]), SheetChrome.px(view, 19, 13), UiTokens.MUTED))
	var bar := Bar.new()
	bar.name = "Bar"
	bar.frac = float(r["frac"])
	bar.text = "%d/%d" % [int(r["got"]), int(r["want"])]
	bar.px = SheetChrome.px(view, 16, 12)
	bar.custom_minimum_size = Vector2(0, 14 if compact else 20)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar)
	col.add_child(_reward_line(r["rewards"], view))
	var cta: Control = null
	if r["claimable"]:
		var b := SheetChrome.gold_button("Receive")
		b.name = "Receive"
		var id := str(r["id"])
		b.pressed.connect(func () -> void: receive(id))
		cta = b
	elif r["claimed"]:
		cta = SheetChrome.label("Received", SheetChrome.px(view, 20, 14), UiTokens.MUTED)
		(cta as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif r["cat"] == &"main":
		var i := int(r["index"])
		var b := SheetChrome.ghost_button("Tracking" if i == shown_index() else "Track")
		b.name = "Track"
		b.disabled = i == shown_index()
		b.pressed.connect(func () -> void:
			tracked = i if i > World.objective else -1
			rebuild())
		cta = b
	if cta:
		cta.custom_minimum_size = Vector2(112 if compact else 180, SheetChrome.TAP if compact else 72.0)
		cta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if cta is Button:
			cta.add_theme_font_size_override("font_size", SheetChrome.px(view, 26, 17))
		h.add_child(cta)
	return box

## The reward line: one icon and amount per reward the task pays (T-stones, skill point, EXP).
func _reward_line(rw: Dictionary, view: Vector2) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "Rewards"
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var px := SheetChrome.px(view, 19, 13)
	for k in REWARD_ORDER:
		if int(rw.get(k, 0)) <= 0:
			continue
		line.add_child(reward_icon(k, px + 6))
		var l := SheetChrome.label("%d" % int(rw[k]), px, UiTokens.TEXT)
		line.add_child(l)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(px * 0.6, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(gap)
	return line

func _show_popup(r: Dictionary) -> void:
	var view := get_viewport_rect().size
	_pop_title.text = "%s Complete" % str(r["title"])
	for c in _pop_rows.get_children():
		_pop_rows.remove_child(c)
		c.queue_free()
	var px := SheetChrome.px(view, 24, 16)
	var rw: Dictionary = r["rewards"]
	for k in REWARD_ORDER:
		if int(rw.get(k, 0)) <= 0:
			continue
		var line := HBoxContainer.new()
		line.name = "Pop_%s" % k
		line.add_theme_constant_override("separation", 14)
		var ic := reward_icon(k, 34.0 if SheetChrome.compact(view) else 46.0)
		ic.name = "Icon"
		line.add_child(ic)
		var nm := SheetChrome.label(REWARD_NAMES[k], px, UiTokens.TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(nm)
		var amt := SheetChrome.label("%d" % int(rw[k]), px, UiTokens.GOLD, true)
		amt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(amt)
		_pop_rows.add_child(line)
	popup.visible = true
