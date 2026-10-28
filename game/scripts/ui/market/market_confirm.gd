class_name MarketConfirm
extends Control
## The market's one dialog: a dimmed overlay with a detail panel that opens with a parchment header
## (§8): the exact instance (name, Lv, durability, trait chips), info lines, a status line, and a
## secondary + a full-width GOLD primary. Buy and Cancel listing use it; the action is a Callable
## that returns the economy's {ok, r} / {ok:false, err, msg}.

var screen: MarketScreen
var panel: PanelContainer
var head: Label
var sub: Label
var chips: HFlowContainer
var lines: VBoxContainer
var status: Label
var primary: Button
var secondary: Button
var _action: Callable
var _done: Callable ## runs after a successful action (refresh the pane)

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", MarketScreen.panel_box(0.98))
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var parch := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = UiTokens.PARCHMENT_TOP
	ps.set_content_margin_all(14)
	parch.add_theme_stylebox_override("panel", ps)
	col.add_child(parch)
	var pv := VBoxContainer.new()
	parch.add_child(pv)
	head = MarketScreen.lbl("", 26, UiTokens.PARCHMENT_INK, true)
	head.name = "Head"
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pv.add_child(head)
	sub = MarketScreen.lbl("", 16, UiTokens.PARCHMENT_INK)
	pv.add_child(sub)
	var inner := MarginContainer.new()
	for side in ["left", "right"]:
		inner.add_theme_constant_override("margin_" + side, 14)
	inner.add_theme_constant_override("margin_bottom", 14)
	col.add_child(inner)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 10)
	inner.add_child(iv)
	chips = HFlowContainer.new()
	chips.name = "Chips"
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	iv.add_child(chips)
	lines = VBoxContainer.new()
	lines.name = "Lines"
	iv.add_child(lines)
	status = MarketScreen.lbl("", 16, UiTokens.META)
	status.name = "Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	iv.add_child(row)
	secondary = MarketScreen.btn("Close", 20)
	secondary.name = "Secondary"
	secondary.pressed.connect(func () -> void: visible = false)
	row.add_child(secondary)
	primary = MarketScreen.btn("", 22, true)
	primary.name = "Primary"
	primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary.pressed.connect(press_primary)
	row.add_child(primary)

## Shows `v` (a MarketRow view) with `info` [[label, value], ...]. `why_not` non-empty disables the
## primary and says why (e.g. not enough tradable T-stones), so nothing is sent that would be refused.
func open(v: Dictionary, info: Array, action_text: String, action: Callable, done: Callable, why_not: String = "", secondary_text: String = "Close") -> void:
	head.text = str(v.get("name", ""))
	sub.text = "%s · Lv. %d%s" % [str(v.get("type", "")), int(v.get("level", 1)), (" · Durability %s" % v.dur) if str(v.get("dur", "—")) != "—" else ""]
	for c in chips.get_children():
		c.queue_free()
	var traits := MarketRow.traits_of(v.get("asset", {}))
	for t: Array in traits:
		chips.add_child(_chip(t[0], t[1]))
	chips.visible = not traits.is_empty()
	var px := 14 if screen and bool(screen.m.get("compact", false)) else 18
	for c in lines.get_children():
		c.queue_free()
	for pair: Array in info:
		var h := HBoxContainer.new()
		var k := MarketScreen.lbl(str(pair[0]), px, UiTokens.MUTED)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(k)
		h.add_child(MarketScreen.lbl(str(pair[1]), px, UiTokens.TEXT, true))
		lines.add_child(h)
	status.text = why_not
	status.add_theme_color_override("font_color", UiTokens.DANGER if why_not != "" else UiTokens.META)
	primary.text = action_text
	primary.disabled = why_not != ""
	primary.visible = true
	secondary.text = secondary_text
	_action = action
	_done = done
	visible = true
	if screen:
		layout(screen.size)

func press_primary() -> void:
	if primary.disabled or not _action.is_valid():
		return
	primary.disabled = true # one press, one request (a double tap cannot buy twice; the rid guards retries)
	var res: Dictionary = _action.call()
	if res.get("ok", false):
		status.text = str(res.get("say", "Done."))
		status.add_theme_color_override("font_color", UiTokens.OK_GREEN)
		primary.visible = false
		secondary.text = "Close"
		if _done.is_valid():
			_done.call()
	else:
		status.text = MarketConfirm.say_error(res)
		status.add_theme_color_override("font_color", UiTokens.DANGER)
		primary.disabled = false

## The server's refusal in the player's words (economy error codes, EconArgs.no).
static func say_error(res: Dictionary) -> String:
	match str(res.get("err", "")):
		"offline": return "The Island Market is offline."
		"insufficient_funds": return "Not enough T-stones: %s." % str(res.get("msg", ""))
		"closed", "not_found", "expired": return "Someone got there first: that listing is gone."
		"limit_reached": return str(res.get("msg", "A limit was reached.")).capitalize()
	return "The server refused: %s" % str(res.get("msg", res.get("err", "unknown error")))

func _chip(text: String, polarity: StringName) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTokens.trait_chip_style(polarity))
	p.add_child(MarketScreen.lbl(UiTokens.trait_chip_prefix(polarity) + " " + text, 14, UiTokens.trait_chip_fg(polarity)))
	return p

func layout(view: Vector2) -> void:
	position = Vector2.ZERO
	size = view
	var c := UiTokens.is_compact(view)
	panel.custom_minimum_size = Vector2(minf(view.x - 32.0, 400.0 if c else 560.0), 0)
	for l: Label in [sub, status]:
		l.add_theme_font_size_override("font_size", 13 if c else 16)
	head.add_theme_font_size_override("font_size", 20 if c else 26)
	status.custom_minimum_size.x = panel.custom_minimum_size.x - 30.0 # wrapped: a width before layout
	panel.reset_size()
	panel.size.y = minf(panel.size.y, view.y - 16.0)
	panel.position = (view - panel.size) * 0.5
