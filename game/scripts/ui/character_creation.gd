class_name CharacterCreation
extends CanvasLayer
## First launch: build a survivor (eight backgrounds, one starts a skill at
## Lv. 20), a body, and a name. `--occupation=<id>` preselects and starts at once (tests).

signal done(occupation: String, gender: String, player_name: String)

const PHONE_MAX_HEIGHT := 500.0
const PHONE_MIN_ASPECT := 1.75

var _selected: String = ""
var _gender: String = "f"
var _name: LineEdit
var _start: Button
var _cards: Dictionary = {}

func _ready() -> void:
	layer = 60
	var view := Vector2(DisplayServer.window_get_size())
	if view == Vector2.ZERO:
		view = get_viewport().get_visible_rect().size
	var phone_landscape := view.y <= PHONE_MAX_HEIGHT and view.x / maxf(1.0, view.y) >= PHONE_MIN_ASPECT
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.055, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var edge := 10 if phone_landscape else 24
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, edge)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6 if phone_landscape else 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "CREATE YOUR SURVIVOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38 if phone_landscape else 34)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Pick a background. It starts one skill at Lv. 20." if phone_landscape else "Choose a background for one Lv. 20 head start. Then claim your island and begin."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30 if phone_landscape else 18)
	sub.add_theme_color_override("font_color", Color(0.75, 0.82, 0.84))
	box.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6 if phone_landscape else 12)
	grid.add_theme_constant_override("v_separation", 6 if phone_landscape else 12)
	box.add_child(grid)
	for occupation in SkillState.occupations():
		var id := str(occupation.get("id", ""))
		var card := Button.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 74 if phone_landscape else 150)
		var skill := str(SkillState.NAMES.get(str(occupation.get("tree", "")), str(occupation.get("tree", ""))))
		card.text = "%s\n%s 20" % [str(occupation.get("name", id)), skill] if phone_landscape else "%s\n%s\nStarts: %s Lv. 20" % [str(occupation.get("name", id)), str(occupation.get("story", "")), skill]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 34 if phone_landscape else 16)
		card.toggle_mode = true
		card.pressed.connect(func () -> void: _select(id))
		grid.add_child(card)
		_cards[id] = card
	var details := HBoxContainer.new()
	details.add_theme_constant_override("separation", 8 if phone_landscape else 12)
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(details)
	var gl := Label.new()
	gl.text = "Body"
	gl.add_theme_font_size_override("font_size", 30 if phone_landscape else 18)
	details.add_child(gl)
	for g in [["f", "Woman"], ["m", "Man"]]:
		var gb := Button.new()
		gb.text = g[1]
		gb.custom_minimum_size = Vector2(100 if phone_landscape else 140, 48 if phone_landscape else 56)
		gb.add_theme_font_size_override("font_size", 30 if phone_landscape else 18)
		gb.toggle_mode = true
		gb.button_pressed = g[0] == _gender
		var gid: String = g[0]
		gb.pressed.connect(func () -> void:
			_gender = gid
			for c in details.get_children():
				if c is Button:
					(c as Button).button_pressed = (c as Button).text == g[1]
		)
		details.add_child(gb)
	_name = LineEdit.new()
	_name.placeholder_text = "Name"
	_name.text = "Survivor"
	_name.custom_minimum_size = Vector2(170 if phone_landscape else 300, 48 if phone_landscape else 56)
	_name.add_theme_font_size_override("font_size", 32 if phone_landscape else 20)
	details.add_child(_name)
	_start = Button.new()
	_start.text = "ENTER THE RIFT"
	_start.custom_minimum_size = Vector2(190 if phone_landscape else 320, 52 if phone_landscape else 64)
	_start.add_theme_font_size_override("font_size", 32 if phone_landscape else 22)
	_start.disabled = true
	_start.pressed.connect(_finish)
	details.add_child(_start)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--occupation="):
			_select(a.substr(13))
			call_deferred("_finish")

func _select(id: String) -> void:
	_selected = id
	for k in _cards:
		(_cards[k] as Button).button_pressed = k == id
	_start.disabled = false

func _finish() -> void:
	if _selected == "":
		return
	var nm := _name.text.strip_edges()
	if nm == "":
		nm = "Survivor"
	done.emit(_selected, _gender, nm)
	queue_free()
