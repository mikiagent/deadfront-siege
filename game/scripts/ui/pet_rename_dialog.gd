class_name PetRenameDialog
extends Control
## The pet radial's Rename: a name field, the reason a name is refused, OK and Cancel. `apply` does the
## rename and returns "" or why not (PlayerActions.rename_pet, the character-name rule), so the rule
## lives in one place. On a landscape phone the card sits at the top, clear of the on-screen keyboard.

var _card: PanelContainer
var _title: Label
var _field: LineEdit
var _why: Label
var _ok: Button
var _cancel: Button
var _apply: Callable

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.add_theme_stylebox_override("panel", UiTokens.panel_style(0.97))
	add_child(_card)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16)
	_card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiTokens.SPACE)
	pad.add_child(col)
	_title = Label.new()
	_title.text = "Rename"
	col.add_child(_title)
	_field = LineEdit.new()
	_field.name = "NameField"
	_field.max_length = 20  # the character-name limit (CharacterStore.name_problem)
	_field.custom_minimum_size = Vector2(0, 56)
	_field.select_all_on_focus = true
	_field.text_submitted.connect(func (_t: String) -> void: submit())
	col.add_child(_field)
	_why = Label.new()
	_why.add_theme_color_override("font_color", UiTokens.DANGER)
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_why)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UiTokens.SPACE)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(buttons)
	_cancel = _button("Cancel", false)
	_cancel.pressed.connect(close)
	buttons.add_child(_cancel)
	_ok = _button("OK", true)
	_ok.pressed.connect(submit)
	buttons.add_child(_ok)
	# The window can change between phone and desktop sizes while the dialog is open (AnimalScreen does the same).
	get_viewport().size_changed.connect(_layout)

func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 64)
	b.add_theme_stylebox_override("normal", UiTokens.button_style(primary))
	b.add_theme_color_override("font_color", UiTokens.ACTION)
	return b

func open(current: String, apply: Callable) -> void:
	_apply = apply
	_field.text = current
	_why.text = ""
	visible = true
	_layout()
	_field.grab_focus()
	_field.select_all()

func close() -> void:
	visible = false
	_field.release_focus()

## OK / Enter: rename through `apply`; a refusal stays open with its reason.
func submit() -> void:
	if not visible or not _apply.is_valid():
		return
	var why := str(_apply.call(_field.text))
	if why == "":
		close()
	else:
		_why.text = why.left(1).to_upper() + why.substr(1)

func refusal() -> String:
	return _why.text

func _gui_input(event: InputEvent) -> void:
	# A tap on the dim backdrop cancels, like a tap outside the radial.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and not _card.get_global_rect().has_point((event as InputEventMouseButton).position):
		accept_event()
		close()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _layout() -> void:
	var view := get_viewport_rect().size
	position = Vector2.ZERO
	size = view
	var compact := UiTokens.is_compact(view)
	_title.add_theme_font_size_override("font_size", UiTokens.heading(view))
	_title.add_theme_color_override("font_color", UiTokens.TEXT)
	_why.add_theme_font_size_override("font_size", UiTokens.body(view))
	_field.add_theme_font_size_override("font_size", UiTokens.heading(view))
	for b: Button in [_ok, _cancel]:
		b.add_theme_font_size_override("font_size", UiTokens.body(view))
	var w := minf(420.0, view.x - 32.0)
	_card.custom_minimum_size = Vector2(w, 0)
	_card.size = Vector2(w, 0)
	_card.reset_size()
	var safe := UiTokens.safe_insets(get_viewport())
	var y := safe.z + 12.0 if compact else (view.y - _card.size.y) * 0.4
	_card.position = Vector2((view.x - w) * 0.5, y)
