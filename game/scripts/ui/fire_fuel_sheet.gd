class_name FireFuelSheet
extends UiWorldSheet
## FIREFUEL (owner 2026-10-28): a fire's fuel inventory. Ten wood slots, one per minute of fire left
## (the same count the pit draws as logs), the fuel bar and state, and two 64 px buttons that feed the
## fire from the bag: a branch (+1 min) or a log (+5 min), up to 10 min. It refreshes every frame
## while open, so the slots empty as the fire burns. Opened by StationMenu's FUEL hex
## (HuntHud.open_fire_fuel). The fire's fuel_seconds is the whole inventory: nothing new is saved.

const SLOT_PHONE := 40.0
const SLOT_DESK := 60.0

var player: Player
var fire: Bonfire

var _panel: PanelContainer
var _state: Label
var _slots: Array[TextureRect] = []
var _bar: ProgressBar
var _hint: Label
var _branch: Button
var _log: Button
var _msg: Label

func _init() -> void:
	super("Fire")

func _build() -> void:
	name = "FireFuelSheet"
	back_pressed.connect(close)
	close_pressed.connect(close)
	_panel = SheetChrome.panel()
	_panel.name = "Fuel"
	_panel.add_theme_stylebox_override("panel", SheetChrome.panel_style(UiTokens.PANEL, 20.0))
	body.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	_state = SheetChrome.label("", 26, UiTokens.TEXT, true)
	_state.name = "State"
	_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_state)
	var row := HBoxContainer.new()
	row.name = "Slots"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for i in Bonfire.MAX_LOGS:
		var t := TextureRect.new()
		t.name = "Slot%d" % i
		t.texture = ItemIcons.texture(&"wood_log")
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(t)
		_slots.append(t)
	_bar = SheetChrome.thin_bar(0.0, UiTokens.GOLD, 6.0)
	v.add_child(_bar)
	_hint = SheetChrome.label("One log per minute of fire. Branch +1 min, log +5 min, 10 min at most.", 16, UiTokens.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_hint)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	v.add_child(btns)
	_branch = _feed_button(&"branch")
	btns.add_child(_branch)
	_log = _feed_button(&"wood_log")
	btns.add_child(_log)
	_msg = SheetChrome.label("", 16, UiTokens.MUTED)
	_msg.name = "Msg"
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_msg)
	set_process(false)

func _feed_button(item_id: StringName) -> Button:
	var b := SheetChrome.gold_button("")
	b.name = "Add_%s" % item_id
	b.icon = ItemIcons.texture(item_id)
	b.expand_icon = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, SheetChrome.TAP)
	b.pressed.connect(add.bind(item_id))
	return b

func open(p: Player, f: Bonfire) -> void:
	player = p
	fire = f
	_msg.text = ""
	visible = true
	set_process(true)
	_refresh()
	relayout()
	UiTokens.focus_first([_log if not _log.disabled else _branch])

func close() -> void:
	visible = false
	set_process(false)
	fire = null

func is_open() -> bool:
	return visible

## Feed one `item_id` into the fire (the buttons call this; tests too). Returns the seconds gained.
func add(item_id: StringName) -> float:
	if fire == null or not is_instance_valid(fire):
		return 0.0
	var gained := fire.add_fuel(player, item_id)
	_msg.text = ("+%d min" % int(round(gained / 60.0))) if gained > 0.0 else fire.fuel_block_reason(player, item_id)
	_refresh()
	return gained

## Wood slots lit right now (matches fire.logs_shown()).
func filled_slots() -> int:
	var c := 0
	for t in _slots:
		if t.modulate.a > 0.5:
			c += 1
	return c

func _process(_delta: float) -> void:
	if fire == null or not is_instance_valid(fire) or fire.is_queued_for_deletion():
		close()
		return
	_refresh()

func _refresh() -> void:
	if fire == null or not is_instance_valid(fire):
		return
	title_label.text = "Fire Pit" if fire.is_permanent() else str(fire.kind).capitalize()
	var n := fire.logs_shown()
	for i in _slots.size():
		_slots[i].modulate = Color(1, 1, 1, 1) if i < n else Color(1, 1, 1, 0.16)
	_bar.value = fire.fuel_fraction()
	var label: String = {&"roaring": "Roaring", &"burning": "Burning", &"low": "Burning low", &"out": "Out"}.get(fire.fuel_state(), "")
	_state.text = "%s · %s left" % [label, Bonfire._clock(fire.fuel_seconds)] if fire.burning() else "Out · add wood to light it"
	_state.add_theme_color_override("font_color", UiTokens.GOLD if fire.burning() else UiTokens.MUTED)
	for pair in [[_branch, &"branch"], [_log, &"wood_log"]]:
		var b: Button = pair[0]
		var id: StringName = pair[1]
		var have := player.inventory.count_of(id) if player != null and player.inventory != null else 0
		b.text = "%s +%d min  (x%d)" % ["Branch" if id == &"branch" else "Log", int(fire.seconds_for(id) / 60.0), have]
		b.disabled = fire.fuel_block_reason(player, id) != ""

func _layout_body(view: Vector2, rect: Rect2) -> void:
	var compact := UiTokens.is_compact(view)
	var slot := SLOT_PHONE if compact else SLOT_DESK
	for t in _slots:
		t.custom_minimum_size = Vector2(slot, slot)
	_state.add_theme_font_size_override("font_size", 20 if compact else 28)
	_hint.add_theme_font_size_override("font_size", 13 if compact else 17)
	_msg.add_theme_font_size_override("font_size", 13 if compact else 17)
	for b in [_branch, _log]:
		(b as Button).add_theme_font_size_override("font_size", 17 if compact else 22)
		(b as Button).add_theme_constant_override("icon_max_width", 40 if compact else 48)
	var w := minf(rect.size.x, slot * 10.0 + 6.0 * 9.0 + 120.0)
	_panel.size = Vector2(w, 0.0)
	_panel.reset_size()
	var h := minf(_panel.get_combined_minimum_size().y, rect.size.y)
	_panel.size = Vector2(w, h)
	_panel.position = Vector2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y + maxf(0.0, (rect.size.y - h) * 0.35))
