class_name ChatScreen
extends Control
## Region chat (spec 20, docs/reference/durango-region-chat.webp). Left: the channels, Region and
## System, the selected one gold in yellow corner brackets, dotted separators. Right: a header with
## the channel title, a gold eye that shows or hides the chat overlay on the HUD and a close X; the
## lines, a gold name then text or a white sticker then a small grey relative time, one sender's
## consecutive lines stacked under one name, rows alternating light and dark over the blurred
## world, newest at the bottom; under it "Enter message", "+" (sticker picker) and Send.
## Region needs the island server and says so when there is none; System works offline.
## Text from players is never markup: Labels and RichTextLabel.add_text only (no BBCode, no
## translation lookups). "+ New Group" is left out: NET has no group ops yet.

signal closed
signal overlay_toggled(on: bool)

# shortcut: InvTheme's Durango colours copied here (INVUI is not on this base); use InvTheme once merged.
const GOLD := Color("#F2C84C")
const BRACKET := Color("#E6BE54")
const TEXT := Color("#ECEBE4")
const TIME := Color("#A6A69B")
const PANEL := Color(0.035, 0.045, 0.05, 0.48)
const HEADER := Color(0.02, 0.025, 0.03, 0.8)
const EDGE := Color(0.035, 0.03, 0.024, 0.92)
const BUTTON_EDGE := Color(0.62, 0.61, 0.56, 0.75)
const ROW_LIGHT := Color(1, 1, 1, 0.07)
const ROW_DARK := Color(0, 0, 0, 0.16)
const BLUR := preload("res://scripts/ui/chat_blur.gdshader")
const TITLES := {ChatLog.REGION: "Region", ChatLog.SYSTEM: "System"}
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"sprint"]

var feed: ChatLog
var channel: StringName = ChatLog.REGION
var overlay_on := true
## The on-screen keyboard's height in canvas px; -1 asks the platform (tests and labs set it).
var keyboard_override := -1.0

var _m: Dictionary = {}
var _root: MarginContainer
var _left: PanelContainer
var _chan_buttons: Dictionary = {}  # channel -> ChannelButton
var _title: Label
var _eye: IconButton
var _close: IconButton
var _scroll: ScrollContainer
var _list: VBoxContainer
var _bar: PanelContainer
var _field: LineEdit
var _plus: Button
var _send: Button
var _picker: PanelContainer
var _items: Array = []  # [node, line]: the time each row shows, refreshed by _tick_times
var _note := ""  # why the last line was not sent
var _sending := false
var _time_left := 0.0
var _kb := 0.0
static var _font: FontVariation

func _init(p_log: ChatLog) -> void:
	feed = p_log
	name = "ChatScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	feed.changed.connect(_on_log_changed)
	resized.connect(_apply_metrics)
	select(channel)

## Durango's condensed sans, as the bag family narrows the default font (InvTheme.font()).
static func font() -> Font:
	if _font == null or _font.base_font != ThemeDB.fallback_font:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_transform = Transform2D(Vector2(0.9, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	return _font

func open(ch: StringName = channel) -> void:
	visible = true
	select(ch)
	_jump_to_end()

func close() -> void:
	_picker.visible = false
	_field.release_focus()
	visible = false
	closed.emit()

func select(ch: StringName) -> void:
	channel = ch
	_note = ""
	for k: StringName in _chan_buttons:
		(_chan_buttons[k] as ChannelButton).set_selected(k == ch)
	_title.text = TITLES[ch]
	_rebuild()
	_jump_to_end()

# ---------------------------------------------------------------- build

func _build() -> void:
	var blur := ColorRect.new()
	blur.name = "Blur"
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BLUR
	blur.material = mat
	add_child(blur)
	_root = MarginContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var cols := HBoxContainer.new()
	_root.add_child(cols)
	_left = _panel(PANEL)
	_left.name = "Channels"
	cols.add_child(_left)
	var chans := VBoxContainer.new()
	chans.add_theme_constant_override("separation", 0)
	_left.add_child(chans)
	for ch: StringName in [ChatLog.REGION, ChatLog.SYSTEM]:
		var b := ChannelButton.new(TITLES[ch])
		b.name = "Channel_%s" % ch
		b.pressed.connect(select.bind(ch))
		chans.add_child(b)
		chans.add_child(Dots.new())
		_chan_buttons[ch] = b
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var box := _panel(PANEL)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(box)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	box.add_child(stack)
	var header := _panel(HEADER, 0)
	header.name = "Header"
	stack.add_child(header)
	var hb := HBoxContainer.new()
	header.add_child(hb)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", TEXT)
	hb.add_child(_title)
	_eye = IconButton.new(UiIcons.icon(&"xp"), GOLD)
	_eye.name = "Eye"
	_eye.tooltip_text = "Show chat over the game"
	_eye.pressed.connect(_toggle_overlay)
	hb.add_child(_eye)
	var bar := ColorRect.new()
	bar.color = Color(TIME, 0.6)
	bar.custom_minimum_size = Vector2(1, 0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.name = "EyeDivider"
	hb.add_child(bar)
	_close = IconButton.new(null, TEXT)  # the reference X is two plain strokes; the icon set's has knobs
	_close.name = "Close"
	_close.pressed.connect(close)
	hb.add_child(_close)
	stack.add_child(Dots.new())
	_scroll = ScrollContainer.new()
	_scroll.name = "Lines"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.22)
	grab.set_corner_radius_all(2)
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 2
	track.content_margin_right = 2
	var vbar := _scroll.get_v_scroll_bar()
	for part in ["grabber", "grabber_highlight", "grabber_pressed"]:
		vbar.add_theme_stylebox_override(part, grab)
	vbar.add_theme_stylebox_override("scroll", track)
	stack.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_bar = _panel(PANEL)
	_bar.name = "InputBar"
	right.add_child(_bar)
	var ib := HBoxContainer.new()
	_bar.add_child(ib)
	_field = LineEdit.new()
	_field.name = "Field"
	_field.placeholder_text = "Enter message"
	_field.max_length = NetChat.MAX_LEN
	_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_field.keep_editing_on_text_submit = true
	_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 8
	for s in ["normal", "focus", "read_only"]:
		_field.add_theme_stylebox_override(s, flat)
	_field.add_theme_color_override("font_color", TEXT)
	_field.add_theme_color_override("font_placeholder_color", TIME)
	_field.add_theme_color_override("font_uneditable_color", TIME)
	_field.text_submitted.connect(func (t: String) -> void: _send_text(t))
	ib.add_child(_field)
	_plus = _bordered("+")
	_plus.name = "Plus"
	_plus.pressed.connect(_toggle_picker)
	ib.add_child(_plus)
	_send = _bordered("Send")
	_send.name = "Send"
	_send.pressed.connect(func () -> void: _send_text(_field.text))
	ib.add_child(_send)
	_picker = _panel(HEADER)
	_picker.name = "Stickers"
	(_picker.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(6)
	_picker.visible = false
	var grid := GridContainer.new()
	grid.columns = 4
	_picker.add_child(grid)
	for code in ChatEmotes.CODES:
		var b := _bordered("")
		b.name = "Sticker_%s" % code.replace(":", "")
		b.tooltip_text = code
		var st := ChatEmotes.Sticker.new(code, 1.0)
		st.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(st)
		b.pressed.connect(func () -> void: _picker.visible = false; _send_text(code))
		grid.add_child(b)
	add_child(_picker)
	_apply_metrics()

func _panel(bg: Color, radius: int = 3) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _bordered(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	for s: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.12) if s.contains("pressed") else Color(0, 0, 0, 0.18)
		sb.border_color = Color(BUTTON_EDGE, 0.3) if s == "disabled" else (TEXT if s == "hover" else BUTTON_EDGE)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(2)
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(TIME, 0.6))
	return b

## Sizes per canvas: the landscape phone (844x390) keeps every target 44 px or more.
func _metrics() -> Dictionary:
	var c := UiTokens.is_compact(size) if size.x > 0.0 else true
	return {
		"compact": c, "margin": 8.0 if c else 16.0, "gap": 8.0 if c else 12.0,
		"left_w": roundf(clampf(size.x * 0.16, 128.0, 280.0)), "header_h": 44.0 if c else 64.0,
		"chan_h": 52.0 if c else 76.0, "bar_h": 52.0 if c else 76.0, "button_h": 44.0 if c else 56.0,
		"title_px": 18 if c else 28, "chan_px": 18 if c else 26, "name_px": 16 if c else 26,
		"text_px": 16 if c else 26, "time_px": 12 if c else 17, "sticker": 22.0 if c else 34.0,
		"pad": 6.0 if c else 10.0, "name_gap": 24.0 if c else 40.0, "cell": 52.0 if c else 68.0,
	}

func _apply_metrics() -> void:
	if _root == null:
		return
	_m = _metrics()
	var f := font()
	theme = Theme.new()
	theme.default_font = f
	theme.default_font_size = int(_m.text_px)
	_left.custom_minimum_size.x = _m.left_w
	(_root.get_child(0) as HBoxContainer).add_theme_constant_override("separation", int(_m.gap))
	(_bar.get_parent() as VBoxContainer).add_theme_constant_override("separation", int(_m.gap))
	for b: ChannelButton in _chan_buttons.values():
		b.custom_minimum_size.y = _m.chan_h
		b.add_theme_font_size_override("font_size", int(_m.chan_px))
	var header := _title.get_parent() as HBoxContainer
	header.custom_minimum_size.y = _m.header_h
	header.add_theme_constant_override("separation", 6)
	_title.add_theme_font_size_override("font_size", int(_m.title_px))
	(header.get_parent() as PanelContainer).get_theme_stylebox("panel").content_margin_left = _m.pad * 2.0
	for ib: IconButton in [_eye, _close]:
		ib.custom_minimum_size = Vector2(_m.button_h, _m.button_h)
	(header.get_node("EyeDivider") as Control).custom_minimum_size.y = _m.button_h * 0.5
	_bar.custom_minimum_size.y = _m.bar_h
	(_bar.get_child(0) as HBoxContainer).add_theme_constant_override("separation", int(_m.gap))
	_field.add_theme_font_size_override("font_size", int(_m.text_px))
	_field.custom_minimum_size.y = _m.button_h
	_plus.custom_minimum_size = Vector2(_m.button_h, _m.button_h)
	_plus.add_theme_font_size_override("font_size", int(_m.title_px) + 6)
	_send.custom_minimum_size = Vector2(_m.button_h * 3.0, _m.button_h)
	_send.add_theme_font_size_override("font_size", int(_m.chan_px))
	for b in _picker.get_child(0).get_children():
		(b as Control).custom_minimum_size = Vector2(_m.cell, _m.cell)
		(b.get_child(0) as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, int(_m.cell * 0.18))
	_place_root()
	_rebuild()

func _place_root() -> void:
	var inset := UiTokens.safe_insets(get_viewport()) if is_inside_tree() else Vector4.ZERO
	var mg: float = _m.get("margin", 8.0)
	_root.add_theme_constant_override("margin_left", int(mg + inset.w))
	_root.add_theme_constant_override("margin_right", int(mg + inset.x))
	_root.add_theme_constant_override("margin_top", int(mg + inset.z))
	_root.add_theme_constant_override("margin_bottom", int(maxf(mg + inset.y, _kb + 4.0)))

# ---------------------------------------------------------------- rows

func _on_log_changed(ch: StringName) -> void:
	if ch != channel:
		return
	var at_end := _at_end()
	_rebuild()
	if at_end and visible:
		_scroll_to_end()

func _rebuild() -> void:
	if _list == null or _m.is_empty():
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_items.clear()
	var rows: Array = feed.lines[channel]
	var groups := ChatLog.groups(rows)
	for i in groups.size():
		_list.add_child(_row(groups[i], i))
	var offline := channel == ChatLog.REGION and not feed.online()
	if offline:
		_list.add_child(_banner(_offline_text()))
	elif rows.is_empty():
		_list.add_child(_banner("Nothing yet. Say hi to the island." if channel == ChatLog.REGION else "Level-ups, arrivals and warnings show here."))
	if _note != "" and not offline:
		_list.add_child(_banner(_note))
	_refresh_input()

func _offline_text() -> String:
	match feed.net.state if feed.net else NetClient.State.OFFLINE:
		NetClient.State.CONNECTING, NetClient.State.AUTHENTICATING:
			return "Connecting to the island server..."
		NetClient.State.WAITING:
			return "Connection to the island server lost. Reconnecting..."
	return "Offline. Region chat needs the island server, so nothing can be sent or received. System messages still work."

func _refresh_input() -> void:
	var can := channel == ChatLog.REGION and feed.online() and not _sending
	_field.editable = channel == ChatLog.REGION and feed.online()
	_field.placeholder_text = "Enter message" if _field.editable else ("Offline" if channel == ChatLog.REGION else "System is read-only")
	_send.disabled = not can
	_plus.disabled = not can
	if not can:
		_picker.visible = false

func _row(g: Dictionary, i: int) -> Control:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_LIGHT if i % 2 == 0 else ROW_DARK
	sb.content_margin_left = _m.pad * 2.0
	sb.content_margin_right = _m.pad * 2.0
	sb.content_margin_top = _m.pad
	sb.content_margin_bottom = _m.pad
	row.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(_m.name_gap))
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)
	if str(g["from"]) != "":
		# A RichTextLabel like the text beside it, so both sit on one baseline (a Label's line takes
		# the emoji fallback's taller ascent and sat 10 px low).
		var nm := _rich(int(_m.name_px), false)
		nm.name = "Name"
		nm.add_theme_color_override("default_color", GOLD)
		nm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		nm.add_text(str(g["from"]))
		hb.add_child(nm)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)
	for line: Dictionary in g["items"]:
		col.add_child(_item(line))
	return row

func _item(line: Dictionary) -> Control:
	if ChatEmotes.is_emote(str(line["text"])):
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := ChatEmotes.Sticker.new(str(line["text"]), _m.sticker)
		st.name = "Sticker"
		hb.add_child(st)
		var t := _label("", int(_m.time_px), TIME)
		t.size_flags_vertical = Control.SIZE_SHRINK_END
		hb.add_child(t)
		_items.append([t, line])
		_render([t, line])
		return hb
	var rtl := _rich(int(_m.text_px), true)
	rtl.name = "Text"
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items.append([rtl, line])
	_render([rtl, line])
	return rtl

## One line's text (literal) and its relative time.
func _render(item: Array) -> void:
	var ago := ChatLog.ago(float(item[1]["ts"]), feed.now())
	if item[0] is Label:
		(item[0] as Label).text = ago
		return
	var rtl := item[0] as RichTextLabel
	rtl.clear()
	rtl.push_color(TEXT)
	rtl.add_text(str(item[1]["text"]))
	rtl.pop()
	rtl.push_font_size(int(_m.time_px))
	rtl.push_color(TIME)
	rtl.add_text("   " + ago)
	rtl.pop()
	rtl.pop()

## Player text goes in with add_text only: BBCode stays off, so markup is shown, never run.
func _rich(px: int, wrap: bool) -> RichTextLabel:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = false
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rtl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rtl.add_theme_font_size_override("normal_font_size", px)
	return rtl

func _label(t: String, px: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", c)
	return l

## A RichTextLabel, as the rows: a wrapped Label spaced its lines by the emoji fallback's height.
func _banner(t: String) -> Control:
	var rtl := _rich(int(_m.text_px), true)
	rtl.name = "Banner"
	var pad := StyleBoxEmpty.new()
	pad.content_margin_top = _m.header_h * 0.6
	pad.content_margin_bottom = _m.header_h * 0.6
	pad.content_margin_left = _m.pad * 2.0
	pad.content_margin_right = _m.pad * 2.0
	rtl.add_theme_stylebox_override("normal", pad)
	rtl.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)
	rtl.push_color(TIME)
	rtl.add_text(t)
	rtl.pop_all()
	return rtl

# ---------------------------------------------------------------- input

func _send_text(t: String) -> void:
	var text := t.strip_edges()
	if text == "" or _sending or channel != ChatLog.REGION or not feed.online():
		return
	_sending = true
	_note = ""
	_refresh_input()
	var req := feed.send(text)
	await req.done
	_sending = false
	if req.ok:
		if text == _field.text.strip_edges():
			_field.clear()
		_scroll_to_end()
	else:
		_note = "Not sent: %s" % req.msg
	_rebuild()

func _toggle_picker() -> void:
	_picker.visible = not _picker.visible
	if _picker.visible:
		_picker.reset_size()
		var p := _plus.get_global_rect()
		_picker.global_position = Vector2(p.end.x - _picker.size.x, _bar.get_global_rect().position.y - _picker.size.y - _m.gap)

func _toggle_overlay() -> void:
	overlay_on = not overlay_on
	_eye.tint = GOLD if overlay_on else TIME
	_eye.crossed = not overlay_on
	_eye.tooltip_text = "Hide chat over the game" if overlay_on else "Show chat over the game"
	_eye.queue_redraw()
	overlay_toggled.emit(overlay_on)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _picker.visible:
			_picker.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and _field.has_focus():
		# Movement is polled (Input.get_vector), so a typed W or A would walk the survivor.
		for a in MOVE_ACTIONS:
			if InputMap.has_action(a) and event.is_action(a):
				Input.action_release(a)

func _process(delta: float) -> void:
	if not visible:
		return
	var kb := keyboard_height()
	if not is_equal_approx(kb, _kb):
		_kb = kb
		_place_root()
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 15.0
		for item in _items:
			_render(item)

## The on-screen keyboard over the canvas, in canvas px: the input bar rides above it.
func keyboard_height() -> float:
	if keyboard_override >= 0.0:
		return keyboard_override
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) or not is_inside_tree():
		return 0.0  # asking an unsupported display server warns every frame
	var px := DisplayServer.virtual_keyboard_get_height()
	if px <= 0:
		return 0.0
	return float(px) / maxf(0.01, get_viewport().get_screen_transform().get_scale().y)

func _at_end() -> bool:
	var vb := _scroll.get_v_scroll_bar()
	return vb.value >= vb.max_value - vb.page - 4.0

func _jump_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

## Newest at the bottom: a short glide down to it once the rows have their sizes.
func _scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	var vb := _scroll.get_v_scroll_bar()
	var target := maxf(0.0, vb.max_value - vb.page)
	create_tween().tween_property(_scroll, "scroll_vertical", int(target), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- parts

## A channel row: gold text in yellow corner brackets when selected (InvPaint.brackets' look).
class ChannelButton extends Button:
	var selected := false
	func _init(t: String) -> void:
		text = t
		flat = true
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		focus_mode = Control.FOCUS_NONE
		add_theme_constant_override("h_separation", 0)
		var pad := StyleBoxEmpty.new()
		pad.content_margin_left = 14
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			add_theme_stylebox_override(s, pad)
		set_selected(false)
	func set_selected(on: bool) -> void:
		selected = on
		var c := ChatScreen.GOLD if on else ChatScreen.TEXT
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			add_theme_color_override(k, c)
		queue_redraw()
	func _draw() -> void:
		if not selected:
			return
		var r := Rect2(Vector2.ZERO, size).grow(-2.0)
		draw_rect(r, Color(1, 1, 1, 0.08))
		var arm := minf(14.0, size.y * 0.28)
		var w := 3.0
		for corner: Array in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
				[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
			var p: Vector2 = corner[0]
			var d: Vector2 = corner[1]
			draw_rect(Rect2(p, Vector2(arm * d.x, w * d.y)).abs(), ChatScreen.BRACKET)
			draw_rect(Rect2(p, Vector2(w * d.x, arm * d.y)).abs(), ChatScreen.BRACKET)

## The reference's dotted separator.
class Dots extends Control:
	func _init() -> void:
		custom_minimum_size.y = 2.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(x, 0.0, 2.0, 1.0), Color(1, 1, 1, 0.3))
			x += 5.0

## A flat button drawing one white UiIcons texture in a tint (the eye, the close X).
class IconButton extends Button:
	var tex: Texture2D
	var tint := Color.WHITE
	var crossed := false
	func _init(p_tex: Texture2D, p_tint: Color) -> void:
		tex = p_tex
		tint = p_tint
		flat = true
		focus_mode = Control.FOCUS_NONE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		var s := minf(size.x, size.y) * 0.62
		var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
		if tex:
			draw_texture_rect(tex, r, false, tint)
		else:  # a plain X
			var k := r.grow(-s * 0.14)
			draw_line(k.position, k.end, tint, maxf(2.5, s * 0.1), true)
			draw_line(Vector2(k.end.x, k.position.y), Vector2(k.position.x, k.end.y), tint, maxf(2.5, s * 0.1), true)
		if crossed:
			draw_line(r.position + Vector2(s * 0.1, s * 0.1), r.end - Vector2(s * 0.1, s * 0.1), tint, maxf(2.0, s * 0.08))
