class_name CharacterCreation
extends CanvasLayer
## First launch: build a survivor (eight backgrounds, one starts a skill at
## Lv. 20), a body, and a name. `--occupation=<id>` preselects and starts at once (tests).

signal done(occupation: String, gender: String, player_name: String)

var _selected: String = ""
var _gender: String = "f"
var _name: LineEdit
var _start: Button
var _cards: Dictionary = {}

func _ready() -> void:
	layer = 60
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	centre.add_child(box)
	var title := Label.new()
	title.text = "Create your survivor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Choose a background for one Lv. 20 head start. Then claim your island and begin."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	box.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	box.add_child(grid)
	for row in SkillState.occupations():
		var id := str(row.get("id", ""))
		var card := Button.new()
		card.custom_minimum_size = Vector2(300, 150)
		card.text = "%s\n%s\nStarts: %s Lv. 20" % [str(row.get("name", id)), str(row.get("story", "")), SkillState.NAMES.get(str(row.get("tree", "")), str(row.get("tree", "")))]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 16)
		card.toggle_mode = true
		card.pressed.connect(func () -> void: _select(id))
		grid.add_child(card)
		_cards[id] = card
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row2)
	var gl := Label.new()
	gl.text = "Body:"
	row2.add_child(gl)
	for g in [["f", "Woman"], ["m", "Man"]]:
		var gb := Button.new()
		gb.text = g[1]
		gb.custom_minimum_size = Vector2(140, 56)
		gb.toggle_mode = true
		gb.button_pressed = g[0] == _gender
		var gid: String = g[0]
		gb.pressed.connect(func () -> void:
			_gender = gid
			for c in row2.get_children():
				if c is Button:
					(c as Button).button_pressed = (c as Button).text == g[1]
		)
		row2.add_child(gb)
	_name = LineEdit.new()
	_name.placeholder_text = "Name"
	_name.text = "Survivor"
	_name.custom_minimum_size = Vector2(300, 56)
	_name.add_theme_font_size_override("font_size", 20)
	row2.add_child(_name)
	_start = Button.new()
	_start.text = "Enter the Durango rift"
	_start.custom_minimum_size = Vector2(320, 64)
	_start.add_theme_font_size_override("font_size", 22)
	_start.disabled = true
	_start.pressed.connect(_finish)
	box.add_child(_start)
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
