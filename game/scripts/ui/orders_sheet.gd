class_name OrdersSheet
extends Control
## C4 Orders (docs/design/ui-redesign-spec.md §7 C4, mockup ui-redesign/c4-orders.webp): the standing
## orders of data/world/objectives.json as a full-screen sheet (shared chrome §8). Left: every order
## in sequence with a numbered circle (a check when done), title, hint and progress. Right: the
## selected order's parchment header, how-to line, reward chips and "Track on HUD", which points the
## HUD quest card at it (hunt_hud.gd reads OrdersSheet.hud_step).
## Public entry: open(player) / close(); HuntHud.open_orders() opens it from the HUD.

const Chrome := preload("res://scripts/ui/uichar_chrome.gd")

## Back (‹) is pressed: the host returns to its menu. Nothing connected: the sheet just closes.
signal back_requested

## The order the HUD card follows; -1 follows the current one. ASSUMPTION: session-only (not saved),
## so the save format is unchanged; a load follows the current order again.
static var tracked: int = -1

var player: Player
var _c: Dictionary = {}
var _list: VBoxContainer
var _parch: PanelContainer
var _title: Label
var _about: Label
var _how: Label
var _how_cap: Label
var _rew_cap: Label
var _rewards: HBoxContainer
var _track: Button
var _done_label: Label
var _chapter: Label
var _sel: int = -1

## A numbered circle, or a green check when done; gold when it is the order now running.
class Marker extends Control:
	var n := 1
	var done := false
	var now := false
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.5
		var col := UiTokens.OK_GREEN if done else (UiTokens.GOLD if now else UiTokens.MUTED)
		draw_arc(c, r, 0.0, TAU, 40, col, 2.0, true)
		if done:
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.4, 0), c + Vector2(-r * 0.1, r * 0.32), c + Vector2(r * 0.45, -r * 0.35)]), col, 2.0, true)
		else:
			UiTokens.draw_centered(self, UiTokens.ui_face(), c, str(n), int(r * 0.9), UiTokens.TEXT)

func _ready() -> void:
	top_level = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 45  # above the HUD hexes that share its canvas layer
	visible = false
	_c = Chrome.build(self, "Orders")
	(_c["back"] as Button).pressed.connect(_on_back)
	var close_btn: Button = _c["close"]
	close_btn.name = "OrdersClose"
	close_btn.pressed.connect(close)
	_done_label = Chrome.label("", 24, UiTokens.TEXT)
	_done_label.name = "OrdersDone"
	_done_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	(_c["right"] as Control).add_child(_done_label)
	var row := HBoxContainer.new()
	row.name = "OrdersBody"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 20)
	(_c["body"] as Control).add_child(row)
	var left := PanelContainer.new()
	left.name = "OrdersListPanel"
	left.add_theme_stylebox_override("panel", Chrome.panel_box())
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.75
	row.add_child(left)
	var lcol := VBoxContainer.new()
	lcol.add_theme_constant_override("separation", 0)
	left.add_child(lcol)
	var chapter := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(1, 1, 1, 0.04)
	csb.content_margin_left = 18
	csb.content_margin_top = 8
	csb.content_margin_bottom = 8
	chapter.add_theme_stylebox_override("panel", csb)
	# ASSUMPTION: objectives.json has no chapters, so the list is headed by what it is.
	_chapter = Chrome.label("Standing orders", 20, UiTokens.TEXT)
	_chapter.name = "OrdersChapter"
	chapter.add_child(_chapter)
	lcol.add_child(chapter)
	var scroll := ScrollContainer.new()
	scroll.name = "OrdersScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lcol.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "OrdersList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	scroll.add_child(_list)
	var right := PanelContainer.new()
	right.name = "OrdersDetail"
	right.add_theme_stylebox_override("panel", Chrome.panel_box())
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var d := VBoxContainer.new()
	d.add_theme_constant_override("separation", 0)
	right.add_child(d)
	_parch = PanelContainer.new()
	_parch.name = "OrdersParchment"
	d.add_child(_parch)
	_title = Chrome.label("", 32, UiTokens.PARCHMENT_INK, true)
	_title.name = "OrdersTitle"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_parch.add_child(_title)
	var info_scroll := ScrollContainer.new()
	info_scroll.name = "OrdersInfoScroll"
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.add_child(info_scroll)
	var pad := MarginContainer.new()
	pad.name = "OrdersInfoPad"
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.add_child(pad)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	pad.add_child(info)
	_about = Chrome.label("", 22)
	_about.name = "OrdersAbout"
	_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_about)
	_how_cap = Chrome.label("HOW", 15, UiTokens.MUTED)
	info.add_child(_how_cap)
	_how = Chrome.label("", 21)
	_how.name = "OrdersHow"
	_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_how)
	_rew_cap = Chrome.label("REWARD", 15, UiTokens.MUTED)
	info.add_child(_rew_cap)
	_rewards = HBoxContainer.new()
	_rewards.name = "OrdersRewards"
	_rewards.add_theme_constant_override("separation", 12)
	info.add_child(_rewards)
	var foot := MarginContainer.new()
	foot.name = "OrdersFooter"
	d.add_child(foot)
	# ASSUMPTION: no "Show on map" button: orders carry no place in objectives.json.
	_track = Chrome.gold_button("Track on HUD")
	_track.name = "OrdersTrack"
	_track.pressed.connect(_on_track)
	foot.add_child(_track)
	resized.connect(_layout)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

## Opens on the order the HUD card shows.
func open(p: Player) -> void:
	player = p
	_sel = shown_index()
	visible = true
	_layout()

func close() -> void:
	visible = false

func _on_back() -> void:
	close()
	back_requested.emit()

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

## {title, hint, progress, frac, done, index, count, xp, t_stones} for order `i`. Earlier orders are
## done; the running one reads Objectives.current (best-held count); a later one reads the bag now.
static func row(p: Player, i: int) -> Dictionary:
	var all := steps()
	if i < 0 or i >= all.size():
		return {}
	var s: Dictionary = all[i]
	var out := {"title": str(s.get("title", "")), "hint": str(s.get("hint", "")), "index": i, "count": all.size(),
		"xp": int(s.get("xp", 0)), "t_stones": int(s.get("t_stones", 0))}
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
	Chrome.layout(_c, view, UiTokens.safe_insets(get_viewport()))
	var compact := Chrome.compact(view)
	_parch.add_theme_stylebox_override("panel", Chrome.parchment_box(8.0 if compact else 22.0))
	_parch.custom_minimum_size = Vector2(0, 48 if compact else 76)
	_title.add_theme_font_size_override("font_size", Chrome.px(view, 32, 19))
	_about.add_theme_font_size_override("font_size", Chrome.px(view, 22, 14))
	_how.add_theme_font_size_override("font_size", Chrome.px(view, 21, 14))
	for l: Label in [_how_cap, _rew_cap]:
		l.add_theme_font_size_override("font_size", Chrome.px(view, 15, 12))
	_done_label.add_theme_font_size_override("font_size", Chrome.px(view, 24, 16))
	_chapter.add_theme_font_size_override("font_size", Chrome.px(view, 20, 14))
	var pad := _about.get_parent().get_parent() as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10 if compact else 24)
	var foot := _track.get_parent() as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		foot.add_theme_constant_override("margin_" + side, 6 if compact else 18)
	_track.add_theme_font_size_override("font_size", Chrome.px(view, 28, 16))
	_track.custom_minimum_size = Vector2(0, 72 if not compact else Chrome.TAP)
	if visible:
		rebuild()

func rebuild() -> void:
	if _list == null:
		return
	var all := steps()
	_done_label.text = "Done %d / %d" % [mini(World.objective, all.size()), all.size()]
	if all.is_empty():
		_sel = -1
	else:
		_sel = clampi(_sel, 0, all.size() - 1)
	_build_list()
	_build_detail()

func _build_list() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var view := get_viewport_rect().size
	var compact := Chrome.compact(view)
	for i in steps().size():
		var r := row(player, i)
		var on := i == _sel
		var b := Button.new()
		b.name = "Order_%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, Chrome.TAP if compact else 84.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTokens.GOLD_DIM if on else Color(0, 0, 0, 0)
		sb.border_color = Color(1, 1, 1, 0.06)
		sb.border_width_bottom = 1
		var hv := sb.duplicate() as StyleBoxFlat
		hv.bg_color = UiTokens.GOLD_DIM
		for st in ["normal", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 12 if compact else 18
		h.offset_right = -12 if compact else -18
		h.add_theme_constant_override("separation", 10 if compact else 16)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var m := Marker.new()
		m.n = i + 1
		m.done = bool(r["done"]) and i < World.objective
		m.now = i == World.objective
		m.custom_minimum_size = Vector2(28, 28) if compact else Vector2(38, 38)
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(m)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(col)
		var done := i < World.objective
		var t := Chrome.label(str(r["title"]), Chrome.px(view, 22, 14), UiTokens.MUTED if done else UiTokens.TEXT)
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(t)
		var hint := Chrome.label(str(r["hint"]), Chrome.px(view, 15, 12), UiTokens.MUTED)
		hint.clip_text = true
		hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(hint)
		var p := Chrome.label(str(r["progress"]), Chrome.px(view, 20, 14), UiTokens.GOLD)
		p.name = "Progress"
		p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(p)
		if on:
			b.add_child(Chrome.Brackets.new())
		var idx := i
		b.pressed.connect(func () -> void:
			_sel = idx
			rebuild()
		)
		_list.add_child(b)

func _build_detail() -> void:
	for c in _rewards.get_children():
		_rewards.remove_child(c)
		c.queue_free()
	var r := row(player, _sel)
	if r.is_empty():
		_title.text = "No orders"
		_about.text = ""
		_how.text = ""
		_track.disabled = true
		_track.text = "Track on HUD"
		return
	var view := get_viewport_rect().size
	_title.text = str(r["title"])
	_about.text = "Order %d of %d  ·  %s" % [_sel + 1, int(r["count"]), "done" if _sel < World.objective else ("running now" if _sel == World.objective else "%s so far" % str(r["progress"]))]
	_how.text = str(r["hint"])
	for chip: String in (["+%d XP" % int(r["xp"])] if int(r["xp"]) > 0 else []) + (["+%d T-stones" % int(r["t_stones"])] if int(r["t_stones"]) > 0 else []):
		var pc := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.08)
		sb.set_content_margin_all(10 if not Chrome.compact(view) else 6)
		pc.add_theme_stylebox_override("panel", sb)
		pc.add_child(Chrome.label(chip, Chrome.px(view, 21, 14)))
		_rewards.add_child(pc)
	# Done orders cannot be tracked; the one the card already shows reads "Tracking on HUD" (grey).
	if _sel < World.objective:
		_track.disabled = true
		_track.text = "Done"
	elif _sel == shown_index():
		_track.disabled = true
		_track.text = "Tracking on HUD"
	else:
		_track.disabled = false
		_track.text = "Track on HUD"

func _on_track() -> void:
	tracked = _sel if _sel > World.objective else -1
	rebuild()
