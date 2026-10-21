class_name SailScreen
extends Control
## The harbour's Sail chart (spec 15, "The Sail menu"; owner: "Menu scrolls rightward and has many
## islands"). A full-screen sea that scrolls to the right: Home Lv. 10 at the far left, then a band per
## island level that darkens as the level rises, one round SailNode per island (climate art, name,
## Lv., check / "?" / lock with "Survival N"). Tapping a node opens its card with the cost and Sail.
## Sail, "Free return home" and "Return to camp" only emit `chosen`; world_ui travels exactly as the
## old route list did (World.travel(id, &"sail") and friends). Routes, costs and Survival gates are
## shown here, never decided here.
## Scrolling is 1:1 (a 400 px drag moves the sea 400 px) by mouse drag, touch drag, wheel and
## trackpad pan, with no vertical scrolling and no inertia.

signal chosen(id: StringName) ## an island id, or world_ui's &"home" / &"camp"
signal closed

## Durango palette, matched to INVUI's InvTheme (claude/mmo-invui) until that theme merges.
const HEADER := Color("#080809")
const PANEL := Color("#3A3530")
const PRIMARY := Color("#F2C84C")
const PRIMARY_INK := Color("#1B1A14")
const SELECT := Color("#E6BE54")
const TAN := Color("#CAAD69")
const TEXT := Color("#ECEBE4")
const TEXT_2 := Color("#A6A69B")
const DANGER := Color("#F08A70")
const GOOD := Color("#8FD06F")
const EDGE := Color(0.62, 0.61, 0.56, 0.75)
const BUTTON_DARK := Color(0.07, 0.075, 0.065, 0.9)
const TARGET := 64.0 ## smallest tap target (AGENTS.md)
const DRAG_TAP := 12.0 ## a press that moved further than this was a drag, not a tap
const HOME_ID := &"home_grassland"

var scroll_x := 0.0
var content_w := 0.0
var nodes: Dictionary = {} ## island id (String) -> SailNode
var home_button: Button ## "Free return home" (header, off the home island only)
var camp_button: Button ## "Return to camp" (header, off the home island only)
var card_id: StringName = &""
var card_action: Button ## the card's Sail (or "Free return home") button
var survival := 0

var _m: Dictionary = {}
var _view: Control
var _chart: SailChart
var _card: PanelContainer
var _buttons: Array[Button] = [] ## header and card buttons, for tap_targets()
var _drag_px := 0.0
var _touches: Dictionary = {} ## finger index -> true while that finger is down on the sea
var _rebuild_queued := false

static var _theme: Theme

## Sizes for a `view`-sized canvas: the landscape phone (UiTokens.is_compact) or the desktop.
static func metrics(view: Vector2) -> Dictionary:
	var compact := UiTokens.is_compact(view)
	return {
		"compact": compact, "header_h": 72.0 if compact else 96.0, "pad": 8.0 if compact else 16.0,
		"gap": 4.0 if compact else 8.0, "d": 72.0 if compact else 112.0, "node_w": 136.0 if compact else 220.0,
		"title_px": 26 if compact else 40, "name_px": 14 if compact else 20, "lv_px": 13 if compact else 17,
		"need_px": 12 if compact else 16, "band_px": 13 if compact else 18, "body_px": 14 if compact else 20,
		"btn_px": 16 if compact else 22, "chip_px": 16 if compact else 22, "icon": 22.0 if compact else 30.0,
		"card_w": 300.0 if compact else 440.0, "card_icon": TARGET if compact else 96.0, "compass": 28.0 if compact else 50.0,
	}

func _ready() -> void:
	name = "SailScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = _shared_theme()
	_rebuild()
	resized.connect(func () -> void:
		if not _rebuild_queued:
			_rebuild_queued = true
			_rebuild.call_deferred()
	)

## The visible part of the sea, in this screen's coordinates.
func view_rect() -> Rect2:
	return _view.get_global_rect() if _view else Rect2()

## The screen minus the device's safe-area insets.
func safe_rect() -> Rect2:
	var ins := UiTokens.safe_insets(get_viewport())  # x right, y bottom, z top, w left
	return Rect2(ins.w, ins.z, size.x - ins.w - ins.x, size.y - ins.z - ins.y)

## Every header and card button showing now (nodes are in `nodes`).
func tap_targets() -> Array[Button]:
	var out: Array[Button] = []
	for b in _buttons:
		if is_instance_valid(b) and b.is_visible_in_tree():
			out.append(b)
	return out

## Scrolls the sea; with a card open it may run a card's width past the last band, so the far-right
## islands can sit beside the card instead of under it.
func scroll_to(x: float) -> void:
	var past := (float(_m.card_w) + float(_m.pad) * 2.0) if _card else 0.0
	scroll_x = clampf(x, 0.0, maxf(0.0, content_w + past - (_view.size.x if _view else 0.0)))
	if _chart:
		_chart.position.x = -scroll_x

## The control that departs for `id` (probes and the bot): the header's buttons for &"home" and
## &"camp", else the action button on that island's card, which this opens.
func route_button(id: StringName) -> Button:
	if id == &"home" and home_button:
		return home_button
	if id == &"camp":
		return camp_button
	if not nodes.has(str(id)):
		return null
	open_card(id)
	return card_action

func _rebuild() -> void:
	_rebuild_queued = false
	var keep_card := card_id
	var keep_scroll := scroll_x / maxf(1.0, content_w)
	for c in get_children():
		c.free()
	nodes.clear()
	_buttons.clear()
	_touches.clear()  # the old sea view never gets those fingers' releases
	_card = null
	card_id = &""
	card_action = null
	home_button = null
	camp_button = null
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_m = metrics(size)
	var safe := safe_rect()
	var header_h: float = _m.header_h
	var sea := ColorRect.new()
	sea.color = SailChart.DEEP
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sea.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sea)
	_view = Control.new()
	_view.name = "SeaView"
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.position = Vector2(safe.position.x, safe.position.y + header_h)
	_view.size = Vector2(safe.size.x, safe.size.y - header_h)
	_view.gui_input.connect(_on_view_input)
	add_child(_view)
	_chart = SailChart.new()
	_chart.name = "Chart"
	_view.add_child(_chart)
	var entries := _entries()
	for n in _chart.build(entries, _view.size, _m):
		nodes[str(n.island_id)] = n
		var id := n.island_id
		n.button_down.connect(func () -> void: _drag_px = 0.0)
		n.pressed.connect(func () -> void:
			if _drag_px <= DRAG_TAP:
				open_card(id)
		)
		n.focus_entered.connect(_show_node.bind(n))
	content_w = _chart.size.x
	_make_header(safe)
	scroll_to(keep_scroll * content_w)
	if keep_card != &"" and nodes.has(str(keep_card)):
		open_card(keep_card)
	var here: Variant = nodes.get(str(World.island_id), nodes.get(str(HOME_ID)))
	if here:
		if keep_scroll == 0.0:
			_show_node(here)  # opens with the island you stand on in view
		UiTokens.focus_first([here])

## One row per island, Home first, then World.harbour_routes() (level order).
func _entries() -> Array[Dictionary]:
	var player := PlayerRegistry.local()
	survival = player.skills.level_of("survival") if player and player.skills else 0
	var ids: Array[String] = [str(HOME_ID)]
	ids.append_array(World.harbour_routes())
	var out: Array[Dictionary] = []
	for id in ids:
		var sid := StringName(id)
		var def := World.def_of(sid)
		var home := sid == HOME_ID
		var need := World.route_level(sid)
		out.append({
			"id": id, "name": World.island_name(sid), "tier": int(def.get("tier", 10 if home else 60)),
			"climate": str(def.get("climate", "")), "home": home, "here": sid == World.island_id,
			# ASSUMPTION: Home always reads as visited: every survivor starts there.
			"visited": home or World.visited_islands.has(id), "need": need, "locked": not home and survival < need,
			"cost": 0 if home else int(def.get("sail_cost", 5)), "life": float(def.get("lifetime_seconds", 0.0)),
		})
	return out

func _entry(id: StringName) -> Dictionary:
	for e in _entries():
		if StringName(str(e.id)) == id:
			return e
	return {}

func _make_header(safe: Rect2) -> void:
	var h: float = _m.header_h
	var pad: float = _m.pad
	var bar := ColorRect.new()
	bar.name = "Header"
	bar.color = HEADER
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.position = Vector2.ZERO
	bar.size = Vector2(size.x, safe.position.y + h)
	add_child(bar)
	var edge := ColorRect.new()
	edge.color = Color(TAN, 0.55)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge.position = Vector2(0, bar.size.y - 2.0)
	edge.size = Vector2(size.x, 2.0)
	bar.add_child(edge)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(pad))
	row.position = Vector2(safe.position.x + pad, safe.position.y)
	row.size = Vector2(safe.size.x - pad * 2.0, h)
	bar.add_child(row)
	# ASSUMPTION: Durango's back arrow; no screen sits under the chart, so it closes it like X.
	var back := _icon_button(&"back", "Back")
	back.pressed.connect(func () -> void: closed.emit())
	row.add_child(back)
	var title := Label.new()
	title.text = "Sail"
	title.add_theme_font_size_override("font_size", int(_m.title_px))
	title.add_theme_color_override("font_color", TEXT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	row.add_child(_chip(&"survival", "Survival %d" % survival))
	row.add_child(_chip(&"t_stone", str(World.t_stones)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	if not World.is_home():
		camp_button = _text_button("Return to camp", false)
		camp_button.pressed.connect(func () -> void: chosen.emit(&"camp"))
		row.add_child(camp_button)
		home_button = _text_button("Free return home", true)
		home_button.pressed.connect(func () -> void: chosen.emit(&"home"))
		row.add_child(home_button)
	var close := _icon_button(&"close", "Close")
	close.pressed.connect(func () -> void: closed.emit())
	row.add_child(close)

func _chip(icon_id: StringName, text: String) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = UiIcons.icon(icon_id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * float(_m.icon)
	icon.modulate = TAN
	box.add_child(icon)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", int(_m.chip_px))
	lab.add_theme_color_override("font_color", TEXT)
	box.add_child(lab)
	return box

func _icon_button(icon_id: StringName, tip: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.icon = UiIcons.icon(icon_id)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(TARGET, TARGET)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_constant_override("icon_max_width", int(TARGET * 0.5))
	_buttons.append(b)
	return b

func _text_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(TARGET, TARGET)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", int(_m.btn_px))
	if primary:
		_style_primary(b)
	_buttons.append(b)
	return b

## Yellow primary action with dark ink (Durango's main button).
static func _style_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _box(PRIMARY, PRIMARY.darkened(0.3)))
	b.add_theme_stylebox_override("hover", _box(PRIMARY.lightened(0.1), PRIMARY.darkened(0.3)))
	b.add_theme_stylebox_override("pressed", _box(PRIMARY.darkened(0.12), PRIMARY.darkened(0.4)))
	b.add_theme_stylebox_override("hover_pressed", _box(PRIMARY.darkened(0.12), PRIMARY.darkened(0.4)))
	b.add_theme_stylebox_override("disabled", _box(Color(0.24, 0.23, 0.2, 0.95), Color(EDGE, 0.4)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, PRIMARY_INK)
	b.add_theme_color_override("font_disabled_color", TEXT_2)

static func _box(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	return sb

## Dark buttons with a thin light edge and the condensed face (INVUI's bag look), on this screen only.
static func _shared_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = SailNode.font()
	t.default_font_size = 16
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", _box(BUTTON_DARK, EDGE))
	t.set_stylebox("hover", "Button", _box(BUTTON_DARK.lightened(0.08), TEXT))
	t.set_stylebox("pressed", "Button", _box(Color(SELECT, 0.25), SELECT))
	t.set_stylebox("hover_pressed", "Button", _box(Color(SELECT, 0.25), SELECT))
	t.set_stylebox("disabled", "Button", _box(Color(BUTTON_DARK, 0.6), Color(EDGE, 0.3)))
	var focus := _box(Color(0, 0, 0, 0), SELECT)
	focus.draw_center = false
	focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_2)
	t.set_color("icon_normal_color", "Button", TEXT)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	_theme = t
	return t

## The island's card: name, level and climate, visited or not, its Survival gate, life span, cost,
## and the action (Sail; Free return home for Home; disabled with the reason when it cannot go).
func open_card(id: StringName) -> void:
	close_card()
	var e := _entry(id)
	if e.is_empty():
		return
	card_id = id
	var node: SailNode = nodes[str(id)]
	node.selected = true
	var pad: float = _m.pad
	var body_px := int(_m.body_px)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(PANEL, 0.97)
	sb.border_color = Color(TAN, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(pad)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	_card.add_theme_stylebox_override("panel", sb)
	var card_w: float = _m.card_w
	_card.position = Vector2(_view.position.x + _view.size.x - card_w - pad, _view.position.y + pad)
	_card.size = Vector2(card_w, 0.0)  # as tall as its lines and button
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(pad * 0.75))
	_card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", int(pad))
	col.add_child(top)
	var icon := SailNode.new()
	icon.setup(e, _m)
	icon.name = "CardIcon"
	icon.show_labels = false
	icon.d = float(_m.card_icon) - 8.0
	icon.custom_minimum_size = Vector2.ONE * float(_m.card_icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.focus_mode = Control.FOCUS_NONE
	top.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", 0)
	top.add_child(names)
	var title := Label.new()
	title.text = str(e.name)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# One line: a long name steps down to the 12 px floor before it is cut short.
	var title_room := card_w - pad * 4.0 - float(_m.card_icon) - TARGET
	var title_px := int(body_px * (1.15 if _m.compact else 1.4))
	while title_px > UiTokens.TYPE_MIN and SailNode.font().get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x > title_room:
		title_px -= 1
	title.add_theme_font_size_override("font_size", title_px)
	names.add_child(title)
	var climate := str(e.climate).capitalize()
	names.add_child(_line("%s%s" % [LevelDisplay.label(int(e.tier)), ("  ·  " + climate) if climate != "" else ""], body_px - 2, TAN))
	var x := _icon_button(&"close", "Close card")
	x.pressed.connect(close_card)
	top.add_child(x)
	var stones := World.t_stones
	if bool(e.home):
		col.add_child(_line("Your home island. It never sinks.", body_px, TEXT_2))
	else:
		col.add_child(_line("Sailed here before" if bool(e.visited) else "Not visited yet", body_px, GOOD if bool(e.visited) else TEXT_2))
		col.add_child(_line("Survival %d needed (you have %d)" % [int(e.need), survival], body_px, DANGER if bool(e.locked) else GOOD))
		var life := float(e.life)
		if life > 0.0:
			col.add_child(_line("Survivable %s after landing" % (("%d h" % int(life / 3600.0)) if life >= 3600.0 else ("%d min" % int(life / 60.0))), body_px, TEXT_2))
		col.add_child(_line("Fare %d T-stones (you have %d)" % [int(e.cost), stones], body_px, DANGER if stones < int(e.cost) else TEXT))
	var go := _text_button("Sail", true)
	go.name = "CardAction"
	go.set_meta("route_id", str(id))
	go.size_flags_vertical = Control.SIZE_FILL
	if bool(e.here):
		go.text = "You are here"
		go.disabled = true
	elif bool(e.home):
		go.text = "Free return home"
		go.pressed.connect(func () -> void: chosen.emit(&"home"))
	elif bool(e.locked):
		go.text = "Needs Survival %d" % int(e.need)
		go.disabled = true
	elif stones < int(e.cost):
		go.text = "Needs %d T-stones" % int(e.cost)
		go.disabled = true
	else:
		go.text = "Sail  ·  %d T-stones" % int(e.cost)
		go.pressed.connect(func () -> void: chosen.emit(id))
	col.add_child(go)
	card_action = go
	# Keep the chosen island in sight, left of the card.
	var room := _view.size.x - card_w - pad * 2.0
	var nx := node.position.x - scroll_x
	if nx < 0.0 or nx + node.size.x > room:
		scroll_to(node.position.x + node.size.x * 0.5 - room * 0.5)
	if UiTokens.wants_focus():
		(x if go.disabled else go).grab_focus()

func close_card() -> void:
	if _card:
		for b in _card.find_children("*", "Button", true, false):
			_buttons.erase(b)
		remove_child(_card)  # now, so the next card can take the name "Card"
		_card.queue_free()
		_card = null
	if nodes.has(str(card_id)):
		(nodes[str(card_id)] as SailNode).selected = false
	card_id = &""
	card_action = null
	scroll_to(scroll_x)

func _line(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", maxi(UiTokens.TYPE_MIN, px))
	l.add_theme_color_override("font_color", col)
	return l

func _show_node(n: SailNode) -> void:
	var nx := n.position.x - scroll_x
	if nx < 0.0 or nx + n.size.x > _view.size.x:
		scroll_to(n.position.x + n.size.x * 0.5 - _view.size.x * 0.5)

func _drag(dx: float) -> void:
	_drag_px += absf(dx)
	scroll_to(scroll_x - dx)

func _on_view_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return  # a copy of a touch (or mouse) event that also arrives itself: counting both scrolls 2x
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_touches[touch.index] = true
			_drag_px = 0.0
		else:
			_touches.erase(touch.index)
		return
	if event is InputEventMouse and not _touches.is_empty():
		return  # the web build also sends a finger's pointermove as a device-0 mouse motion; ScreenDrag counted it
	var mb := event as InputEventMouseButton
	if mb:
		# Web wheels report a factor near 3 per notch; capped so one notch is at most 3/4 of a band.
		var step := _chart.band_w * 0.5 * (minf(mb.factor, 1.5) if mb.factor > 0.0 else 1.0)
		if not mb.pressed:
			return
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				scroll_to(scroll_x + step)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				scroll_to(scroll_x - step)
			MOUSE_BUTTON_LEFT:
				_drag_px = 0.0
		return
	if event is InputEventScreenDrag:
		_drag((event as InputEventScreenDrag).relative.x)
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag((event as InputEventMouseMotion).relative.x)
	elif event is InputEventPanGesture:  # a vertical two-finger trackpad swipe scrolls the chart too
		var pan := (event as InputEventPanGesture).delta
		scroll_to(scroll_x + (pan.x + pan.y) * _chart.band_w * 0.1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _card:
			close_card()
		else:
			closed.emit()
		get_viewport().set_input_as_handled()
