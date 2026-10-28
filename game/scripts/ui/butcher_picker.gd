class_name ButcherPicker
extends Control
## BUTCHER (spec 12 §2): the carcass part picker. Tap a corpse and this opens: one HexButton per part
## the species offers (its icon, units still on the carcass, the cut's seconds, its name under it), the
## cuts left, and what a part is waiting on. Picking a part starts the timed cut (PlayerActions.begin_part_cut);
## the hexes grey out while it runs and the row rebuilds when it ends.
##
## Minimal by design, on the existing UI tokens and HexButton: every hex is 64 px, a tap target the
## ship gate takes (desktop 1600x900 and the landscape phone both lay out two or three a row). A later
## UI pass restyles it; the "Loot chest" button keeps the shipped chest screen reachable.

signal picked(part_id: StringName)
signal closed

const HEX_PX := 64.0
## The hex keeps the 64 px tap target; its cell is wider so the part's name, drawn by the hex itself
## under the outline, has room and never runs into its neighbour's name.
const CELL_W := 116.0
const CELL_H := 108.0
const GAP := 10.0
const COLS := 3
## The picker's own height allowance for the title, the budget line and the footer row.
const CHROME_H := 150.0

var corpse: Corpse
var player: Player
var _panel: PanelContainer
var _title: Label
var _sub: Label
var _scroll: ScrollContainer
var _rows: GridContainer
var _loot_btn: Button
var _close_btn: Button
var _buttons: Dictionary = {}  ## part id -> HexButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # a tap outside the panel closes the picker
	visible = false
	_build()

## Open on `c`; the buttons come from the carcass's live part list (a cut changes it).
func open(p: Player, c: Corpse) -> void:
	player = p
	corpse = c
	_rebuild()
	_layout()
	visible = true

func close() -> void:
	if not visible:
		return
	visible = false
	corpse = null
	player = null
	closed.emit()

func is_open() -> bool:
	return visible

## True when that part's hex can be pressed now.
func can_cut(part_id: StringName) -> bool:
	var b: HexButton = _buttons.get(part_id)
	return b != null and not b.disabled

## The part hexes on screen, for the lab and t_butcher (size and blocked state are measured there).
func part_buttons() -> Array[HexButton]:
	var out: Array[HexButton] = []
	for id in _buttons:
		out.append(_buttons[id])
	return out

## The line under that part's hex showing its name, or null. The gates check the names never overlap.
func name_label(part_id: StringName) -> Label:
	return _rows.get_node_or_null("Cell_%s/Name_%s" % [part_id, part_id]) as Label

## Why that part cannot be cut now ("" when it can), as the picker words it under the hex.
func blocked_reason(part_id: StringName) -> String:
	var why := _rows.get_node_or_null("Cell_%s/Why_%s" % [part_id, part_id]) as Label
	return why.text if why != null and why.visible else ""

## The panel's rect on screen.
func panel_rect() -> Rect2:
	return _panel.get_global_rect() if _panel != null else Rect2()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	# A press anywhere but the panel dismisses (Durango's tap-away), the radial's own rule.
	if not visible or _panel == null:
		return
	var at := Vector2.INF
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		at = (event as InputEventMouseButton).position
	if at == Vector2.INF or _panel.get_global_rect().has_point(at):
		return
	accept_event()
	close()

## Rebuild the hexes from the carcass. Called on open, after a cut, and by Player.refresh_butcher.
func _rebuild() -> void:
	if _panel == null or corpse == null or player == null:
		return
	_title.text = "%s · choose a cut" % corpse.species_display_name()
	var sub := "cuts left %d of %d" % [corpse.cuts_left, corpse.cuts_budget]
	if corpse.poison_spoiled:
		sub += " · meat spoiled"
	if corpse.cut_running:
		sub = "cutting…"
	_sub.text = sub
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	# Each part sits in its own cell (see CELL_W); the button's own rect is the tap target the gates measure.
	_buttons.clear()
	for opt in corpse.part_options(player):
		var id := StringName(str(opt["id"]))
		var b := HexButton.new(HEX_PX)
		b.name = "Part_%s" % id
		b.icon = ItemIcons.texture(id)
		b.color_icon = true
		b.top_text = "%.1fs" % float(opt["seconds"])
		b.bottom_text = "%d" % int(opt["count"])
		b.caption = ""
		if str(opt["blocked"]) != "":
			b.set_blocked(str(opt["blocked"]))
			b.hint_text = ""  # the reason is the label under the cell, not a line run into its neighbour
		if corpse.cut_parts.has(id):
			b.selected = true
		if corpse.cut_running:
			b.disabled = true
		b.pressed.connect(_on_part.bind(id))
		# One cell per part: the 64 px hex (its own tap target) centred, the part's name under it, and
		# the blocked reason under that. Its own column, so two names never run together.
		var cell := VBoxContainer.new()
		cell.name = "Cell_%s" % id
		cell.custom_minimum_size = Vector2(CELL_W, CELL_H)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_constant_override("separation", 2)
		var mid := CenterContainer.new()
		mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mid.add_child(b)
		cell.add_child(mid)
		cell.add_child(_cell_label("Name_%s" % id, str(opt["name"]), UiTokens.TEXT))
		var why := _cell_label("Why_%s" % id, str(opt["blocked"]), UiTokens.DANGER)
		why.visible = str(opt["blocked"]) != ""
		cell.add_child(why)
		_rows.add_child(cell)
		_buttons[id] = b
	_loot_btn.disabled = corpse._is_empty()

## Keep the row in step with the carcass while it is open (a cut finished, a part ran out).
func _process(_delta: float) -> void:
	if not visible:
		return
	if player == null or not is_instance_valid(player) or corpse == null or not is_instance_valid(corpse) \
			or corpse.is_queued_for_deletion():
		close()
		return
	if not corpse.cut_running and _stale():
		_rebuild()
		_layout()

func _stale() -> bool:
	if _rows.get_child_count() != corpse.part_options(player).size():
		return true
	for part in corpse.part_options(player):
		var b: HexButton = _buttons.get(part["id"])
		if b == null or int(part["count"]) != int(b.bottom_text) \
				or (str(part["blocked"]) != "") != b.disabled:
			return true
	return false

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.34)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTokens.panel_style(0.96))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # a tap on the panel never falls through to the world
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", GAP)
	_panel.add_child(col)
	_title = Label.new()
	_title.add_theme_color_override("font_color", UiTokens.TEXT)
	col.add_child(_title)
	_sub = Label.new()
	_sub.add_theme_color_override("font_color", UiTokens.META)
	col.add_child(_sub)
	# The hexes live in a scroller: a carcass with many parts on a short landscape phone scrolls
	# instead of running off the panel (the footer stays visible).
	_scroll = ScrollContainer.new()
	_scroll.name = "PartScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_rows = GridContainer.new()
	_rows.name = "Parts"
	_rows.columns = COLS
	_rows.add_theme_constant_override("h_separation", GAP)
	_rows.add_theme_constant_override("v_separation", GAP)
	_scroll.add_child(_rows)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", GAP)
	col.add_child(foot)
	_loot_btn = _foot_button("Loot chest")
	foot.add_child(_loot_btn)
	_loot_btn.pressed.connect(func () -> void:
		var c := corpse
		var p := player
		close()
		if c and p:
			c.open_loot_chest(p))
	_close_btn = _foot_button("Close")
	foot.add_child(_close_btn)
	_close_btn.pressed.connect(close)

## A small centred line in a part's cell: the part's name, or why it cannot be cut.
func _cell_label(id: String, text: String, color: Color) -> Label:
	var l := Label.new()
	l.name = id
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", UiTokens.TYPE_MIN)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _foot_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0.0, HEX_PX)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UiTokens.button_style(false))
	return b

## Centre the panel inside the viewport's safe area; two hexes a row on a phone, three on desktop.
func _layout() -> void:
	if _panel == null:
		return
	var view := get_viewport_rect().size
	var safe := UiTokens.safe_insets(get_viewport())
	var compact := UiTokens.is_compact(view) or view.x < 700.0
	# A landscape phone is wide enough for three; a narrow one gets two.
	_rows.columns = (2 if view.x < 620.0 else 3) if compact else COLS
	_title.add_theme_font_size_override("font_size", UiTokens.heading(view))
	_sub.add_theme_font_size_override("font_size", UiTokens.body(view))
	for id in _buttons:
		var cell := _rows.get_node_or_null("Cell_%s/Name_%s" % [id, id]) as Label
		if cell != null:
			cell.add_theme_font_size_override("font_size", UiTokens.meta(view))
	for b: Button in [_loot_btn, _close_btn]:
		b.add_theme_font_size_override("font_size", UiTokens.body(view))
	var cols := mini(_rows.columns, maxi(1, _rows.get_child_count()))
	var width := minf(view.x - safe.x - safe.w - 24.0, float(cols) * CELL_W + float(GAP) * float(cols + 1))
	_panel.custom_minimum_size = Vector2(maxf(280.0, width), 0.0)
	# How tall the hexes may get before the scroller takes over: the screen less the chrome and margins.
	var rows := ceili(float(_rows.get_child_count()) / float(maxi(1, _rows.columns)))
	var want := float(maxi(1, rows)) * (CELL_H + GAP)
	var room := maxf(CELL_H, view.y - safe.y - safe.z - 24.0 - CHROME_H)
	_scroll.custom_minimum_size = Vector2(0.0, minf(want, room))
	_panel.reset_size()
	var sz := _panel.get_combined_minimum_size()
	var height := sz.y if sz.y > 0.0 else CHROME_H + minf(want, room)
	_panel.position = Vector2(
		clampf((view.x - sz.x) * 0.5, 12.0 + safe.w, maxf(12.0 + safe.w, view.x - sz.x - 12.0 - safe.x)),
		clampf((view.y - height) * 0.5, 12.0 + safe.z, maxf(12.0 + safe.z, view.y - height - 12.0 - safe.y)))

func _on_part(id: StringName) -> void:
	if corpse == null or player == null:
		return
	var why := corpse.begin_cut(id, player)
	if why != "" and why != "started":
		player.notice(why.left(1).to_upper() + why.substr(1))
		_rebuild()
		return
	picked.emit(id)
	_rebuild()
