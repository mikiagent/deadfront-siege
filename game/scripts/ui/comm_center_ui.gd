class_name CommCenterUI
extends Control
## Spec 29 section 4 (Island progression / Personal Communications Center) contribution screen: the
## island's Pioneer rank and plot capacity, the next documented step, one Contribute button per
## required part (it hands over one exact instance from the bag), Withdraw to take it back, and
## Complete to consume the step once and raise the rank. Completing raises CAPACITY only: the copy
## says so, and the Domain screen (which asks the same model) is where land is still claimed.
## Built like the Domain screen: a card on the left, every action at the 64 px tap floor on a phone.

const GOLD := Color(0.96, 0.82, 0.36)

## Emitted when the panel closes, so the Domain screen can come back (it hides while the panel is up:
## this is a modal on top of the Domain card, not a second card in the same space).
signal closed
const CARD_W := 560.0

var player: Player
var rt: IslandRuntime

var _panel: Panel
var _backdrop: ColorRect
var _title: Label
var _rank_line: Label
var _body: Label
var _note: Label
var _rows: VBoxContainer
var _foot: HBoxContainer
var _complete: Button
var _close: Button
var _slot_buttons: Array[Button] = []
var _withdraw_buttons: Array[Button] = []
var _target := 0
var _last_reason := ""
## The body copy in full (a wide canvas) and its one-line phone form: a landscape phone has ~366 px
## of card and the footer must stay on it.
var _body_full := ""
var _body_short := ""

func _ready() -> void:
	visible = false
	name = "CommCenterUI"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45
	# An opaque scrim under the card: the Domain screen and the HUD underneath must not read through
	# the contribution copy (the same reason DomainScreen has one).
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.02, 0.025, 0.03, 0.92)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_panel = Panel.new()
	_panel.name = "Card"
	_panel.add_theme_stylebox_override("panel", UiTokens.panel_style(0.96))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	add_child(_panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiTokens.SPACE * 2)
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", UiTokens.SPACE)
	margin.add_child(stack)
	_title = Label.new()
	_title.name = "Title"
	_title.text = "COMMUNICATIONS CENTER"
	_title.add_theme_color_override("font_color", GOLD)
	stack.add_child(_title)
	_rank_line = Label.new()
	_rank_line.name = "Rank"
	_rank_line.add_theme_color_override("font_color", UiTokens.TEXT)
	stack.add_child(_rank_line)
	_body = Label.new()
	_body.name = "Body"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", UiTokens.META)
	stack.add_child(_body)
	_rows = VBoxContainer.new()
	_rows.name = "Slots"
	_rows.add_theme_constant_override("separation", UiTokens.SPACE)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_rows)
	_note = Label.new()
	_note.name = "Note"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_color_override("font_color", GOLD)
	stack.add_child(_note)
	_foot = HBoxContainer.new()
	_foot.name = "Foot"
	_foot.add_theme_constant_override("separation", UiTokens.SPACE)
	stack.add_child(_foot)
	_complete = _button("COMPLETE UPGRADE", true)
	_complete.name = "Complete"
	_complete.pressed.connect(_on_complete)
	_foot.add_child(_complete)
	_close = _button("CLOSE", false)
	_close.name = "Close"
	_close.pressed.connect(close)
	_foot.add_child(_close)
	resized.connect(_layout)
	if get_viewport():
		get_viewport().size_changed.connect(_layout)
	size = get_viewport_rect().size
	_layout()

func _button(text: String, gold: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", UiTokens.button_style(false))
	b.add_theme_stylebox_override("hover", UiTokens.button_style(true))
	b.add_theme_stylebox_override("pressed", UiTokens.button_style(true))
	b.add_theme_color_override("font_color", GOLD if gold else UiTokens.TEXT)
	b.clip_text = true
	return b

# ---------------------------------------------------------------- open / close

func open(p: Player) -> void:
	player = p
	rt = World.runtime
	visible = true
	_backdrop.visible = true
	_target = int(CommCenter.target_rank())
	_last_reason = ""
	CommCenter.label_station(rt)
	_refresh()
	_layout()
	UiTokens.focus_first(_slot_buttons + [_complete, _close])

func close() -> void:
	if not visible:
		return
	visible = false
	_backdrop.visible = false
	closed.emit()

func is_open() -> bool:
	return visible

## The center now standing on this island, or null (the panel then says to build it).
func station() -> Node:
	if rt == null or not is_instance_valid(rt):
		return null
	for n in get_tree().get_nodes_in_group(str(CommCenter.KIND)):
		if n is Node and rt.is_ancestor_of(n) and not (n as Node).is_queued_for_deletion():
			return n
	return null

# ---------------------------------------------------------------- the card

func _refresh() -> void:
	if _target <= 0:
		_target = int(CommCenter.target_rank())
	var rank := CommCenter.rank()
	var cap := DomainRules.cap()
	var used: int = int(rt.call("claim_used")) if rt != null else 0
	_rank_line.text = "Pioneer rank %d  ·  Plots %d / %d" % [rank, used, cap]
	var built := CommCenter.built(rt)
	if not built:
		_body_full = "The Personal Communications Center is not built on this island. Build it through the Build menu (Construction Parts), then bring it contributions."
		_body_short = "Build the Communications Center first (Build menu, Construction Parts), then bring it contributions."
		_note.text = _last_reason
		_rebuild_rows({})
		_complete.disabled = true
		return
	var step := CommCenter.next_step()
	if step.is_empty():
		_body_full = "Every documented Pioneer step is complete. The island holds its full plot capacity; further ranks have no published figures, so none are invented."
		_body_short = "Every documented Pioneer step is complete."
		_note.text = _last_reason
		_rebuild_rows({})
		_complete.disabled = true
		return
	var next_rank := int(step.get("rank", 0))
	_target = next_rank
	var cap_next := DomainRules.cap_for_rank(next_rank)
	_body_full = "Pioneer rank %d raises the plot capacity to %d (now %d). Raise capacity first, then claim cells from the Domain screen: an upgrade never assigns land by itself." % [next_rank, cap_next, cap]
	_body_short = "Rank %d raises the capacity to %d (now %d). Claim land from the Domain screen." % [next_rank, cap_next, cap]
	_rebuild_rows(step)
	_complete.disabled = CommCenter.complete_reason(next_rank, rt) != ""
	_note.text = _last_reason

func _rebuild_rows(step: Dictionary) -> void:
	for c in _rows.get_children():
		c.queue_free()
	_slot_buttons.clear()
	_withdraw_buttons.clear()
	if step.is_empty():
		return
	var req: Array = step.get("requires", [])
	for i in req.size():
		var row: Dictionary = req[i]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", UiTokens.SPACE)
		var label := Label.new()
		var have := CommCenter.deposited(_target, i)
		var want := CommCenter.needed(_target, i)
		var in_bag := _bag_count(row)
		label.text = "%s  %d / %d   (bag %d)" % [str(row.get("label", row.get("slot_id", "?"))), have, want, in_bag]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.add_theme_color_override("font_color", UiTokens.TEXT if have < want else UiTokens.META)
		line.add_child(label)
		var give := _button("CONTRIBUTE", true)
		give.custom_minimum_size = Vector2(_btn_w(), 0.0)
		give.name = "Give_%d" % i
		give.disabled = CommCenter.deposit_reason(_target, i) != "" or in_bag <= 0
		give.pressed.connect(func () -> void: _on_deposit(i))
		line.add_child(give)
		_slot_buttons.append(give)
		var back := _button("WITHDRAW", false)
		back.custom_minimum_size = Vector2(_btn_w(), 0.0)
		back.name = "Withdraw_%d" % i
		back.disabled = have <= 0
		back.pressed.connect(func () -> void: _on_withdraw(i))
		line.add_child(back)
		_withdraw_buttons.append(back)
		_rows.add_child(line)

## How many units in the bag satisfy this slot (the Contribute button's live count).
func _bag_count(row: Dictionary) -> int:
	if player == null or player.inventory == null:
		return 0
	var n := 0
	for s: ItemStack in player.inventory.slots:
		if s != null and CommCenter.fits(row, s):
			n += s.count
	return n

func _on_deposit(slot: int) -> void:
	if CommCenter.deposit(_target, slot, player.inventory if player else null):
		_last_reason = ""
	else:
		_last_reason = CommCenter.deposit_reason(_target, slot)
	_refresh()
	_layout()

func _on_withdraw(slot: int) -> void:
	if not CommCenter.withdraw(_target, slot, player.inventory if player else null):
		_last_reason = "The bag has no room for that part."
	else:
		_last_reason = ""
	_refresh()
	_layout()

func _on_complete() -> void:
	var out: Dictionary = CommCenter.complete(rt, _target)
	if bool(out["ok"]):
		_last_reason = "Pioneer rank %d: the plot capacity is now %d." % [int(out["rank_after"]), int(out["cap_after"])]
		if player != null:
			player.notice("Pioneer rank %d: %d plots." % [int(out["rank_after"]), int(out["cap_after"])])
	else:
		_last_reason = str(out["reason"])
	_target = int(CommCenter.target_rank())
	_refresh()
	_layout()

# ---------------------------------------------------------------- layout

func _layout() -> void:
	if _panel == null:
		return
	var view := get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	var compact := UiTokens.is_compact(view)
	var body := UiTokens.body(view)
	# A landscape phone gets the short copy so the footer's two 64 px buttons stay on the card.
	_body.text = _body_short if compact else _body_full
	var stack := _panel.get_node_or_null("Margin/Stack") as VBoxContainer
	if stack != null:
		stack.add_theme_constant_override("separation", 6 if compact else UiTokens.SPACE)
	var pad := 12.0 if compact else 20.0
	_title.add_theme_font_size_override("font_size", UiTokens.heading(view))
	for l in [_rank_line, _body, _note]:
		(l as Label).add_theme_font_size_override("font_size", body)
	var btn_h := 64.0 if compact else 56.0
	for b in (_slot_buttons + _withdraw_buttons):
		var row_btn := b as Button
		row_btn.add_theme_font_size_override("font_size", body)
		row_btn.custom_minimum_size = Vector2(_btn_w(), btn_h)
	for b in [_complete, _close]:
		(b as Button).add_theme_font_size_override("font_size", body)
		(b as Button).custom_minimum_size = Vector2(0.0, btn_h)
	_close.custom_minimum_size = Vector2(132.0, btn_h)
	_complete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A landscape phone gets the whole width (three buttons in a row need it); a wide canvas a card.
	var card_w := minf(CARD_W, view.x - pad * 2.0) if compact else minf(620.0, maxf(520.0, view.x * 0.42))
	# A wide canvas gives the card the height its copy needs (never a full-height empty slab); a
	# landscape phone is short, so it takes everything there is and the rows use the room.
	var card_h := view.y - pad * 2.0 if compact else minf(560.0, view.y - pad * 2.0)
	_panel.position = Vector2(pad, pad)
	_panel.size = Vector2(card_w, card_h)
	# The scrim covers exactly the card (a band of dead black over the rest of the world reads broken).
	_backdrop.position = _panel.position
	_backdrop.size = _panel.size
	_backdrop.visible = visible

## A slot row's button width: a phone card is wide and short, so its buttons stay narrow enough
## that the part's count still fits; the label clips (never hidden) and the buttons keep their 64 px.
func _btn_w() -> float:
	var view := get_viewport_rect().size
	return 108.0 if UiTokens.is_compact(view) else 132.0

## Smallest visible interactive control height (the gate's tap-target check).
func min_target_px() -> float:
	var low := INF
	for b in _slot_buttons + _withdraw_buttons + [_complete, _close]:
		var btn := b as Button
		if btn.visible:
			low = minf(low, btn.size.y)
	return low if low < INF else 0.0
