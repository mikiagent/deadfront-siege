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
## Canvas px per fitted px: 1 once DisplayMode.install runs, ~2.3 on an unfitted 844x390 phone.
var _k := 1.0
## Gold, like SP: it reads on the dark card and on the teal selected one (teal text did not).
const START_COLOR := Color(1.0, 0.85, 0.35)
## The fallback font's 16 px lines sit ~37 px apart; two-line stories read as two loose captions.
const STORY_TIGHTEN := 8
## Desktop cards: the head-start skill's white symbol fills the band between story and head start.
const CARD_SYMBOL_PX := 56.0

## Layout choice for a canvas `view` whose window DisplayMode would fit to `fitted`. Decided on the
## fitted canvas, then scaled by k, so the screen is the same with or without the canvas fit (the
## boot hook may land later; before this an unfitted landscape phone got the desktop layout at 0.43).
static func layout_for(view: Vector2, fitted: Vector2) -> Dictionary:
	var k := 1.0
	if fitted.x > 0.0 and fitted.y > 0.0:
		k = minf(view.x / fitted.x, view.y / fitted.y)
	var phone := UiTokens.is_compact(fitted)
	return {"k": k, "fitted": fitted, "phone": phone, "short": phone and not UiTokens.is_narrow(fitted), "narrow": UiTokens.is_narrow(fitted)}

func _px(v: float) -> int:
	return roundi(v * _k)

func _ready() -> void:
	layer = 60
	add_to_group(&"character_creation")  # HANDS (layer 64) hides while this is up
	# Phones: ~390 px wide in portrait (two columns, wrapped details), ~390 px tall in landscape
	# (four columns, everything on one screen).
	var lay := layout_for(get_viewport().get_visible_rect().size, DisplayMode.fitted_size(get_window()))
	_k = float(lay["k"])
	var fitted: Vector2 = lay["fitted"]
	var phone: bool = lay["phone"]
	var short: bool = lay["short"]
	var root := Control.new()
	root.name = "CharacterCreationRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.045, 0.055, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var edge := _px(10 if short else 24)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, edge)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _px(6 if short else 14))
	margin.add_child(box)
	var title := Label.new()
	title.text = "CREATE YOUR SURVIVOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _px(22 if short else (24 if phone else 34)))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Pick a background. It starts one skill at Lv. 20." if phone else "Choose a background for one Lv. 20 head start. Then claim your island and begin."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", _px(14 if phone else 18))
	sub.add_theme_color_override("font_color", Color(0.75, 0.82, 0.84))
	box.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 2 if lay["narrow"] else 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", _px(6 if short else 12))
	grid.add_theme_constant_override("v_separation", _px(6 if short else 12))
	box.add_child(grid)
	for occupation in SkillState.occupations():
		var id := str(occupation.get("id", ""))
		var card := Button.new()
		card.name = "Card_%s" % id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, _px(56 if short else (88 if phone else 150)))
		var skill := str(SkillState.NAMES.get(str(occupation.get("tree", "")), str(occupation.get("tree", ""))))
		# Name, story and head start as separate lines: one 16 px button string left the desktop
		# cards mostly empty with no hierarchy.
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_left = _px(12)
		stack.offset_right = -_px(12)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", _px(2 if phone else 10))
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(stack)
		stack.add_child(_card_line(str(occupation.get("name", id)), _px(16 if phone else 24), UiTokens.TEXT))
		if not phone:
			# Title and story from the top, head start pinned to the bottom: centred stacks put a
			# one-line story's title 13 px below its row neighbours.
			stack.alignment = BoxContainer.ALIGNMENT_BEGIN
			stack.offset_top = _px(24)
			stack.offset_bottom = -_px(24)
			var story := _card_line(str(occupation.get("story", "")), _px(16), UiTokens.META)
			story.add_theme_constant_override("line_spacing", -_px(STORY_TIGHTEN))
			stack.add_child(story)
			# The band between story and head start (~130 px at 1600x900) was empty.
			var band := CenterContainer.new()
			band.name = "CardSymbol"
			band.size_flags_vertical = Control.SIZE_EXPAND_FILL
			band.mouse_filter = Control.MOUSE_FILTER_IGNORE
			band.add_child(SkillsSheet.symbol_rect(str(occupation.get("tree", "")), _px(CARD_SYMBOL_PX)))
			stack.add_child(band)
		# Phone: the skill alone (the subtitle gives the Lv. 20); "Weapon / Tools Lv. 20" wrapped in a
		# portrait card and dropped its title below its neighbour's.
		var start_text := skill if phone else "Starts: %s %s" % [skill, LevelDisplay.label(20)]
		stack.add_child(_card_line(start_text, _px(14 if phone else 18), START_COLOR))
		card.toggle_mode = true
		card.pressed.connect(func () -> void: _select(id))
		grid.add_child(card)
		_cards[id] = card
	# Flow, not a row: on a phone the name field and the start button wrap onto their own lines.
	var details := HFlowContainer.new()
	details.add_theme_constant_override("h_separation", _px(8 if short else 12))
	details.add_theme_constant_override("v_separation", _px(8))
	details.alignment = FlowContainer.ALIGNMENT_CENTER
	box.add_child(details)
	var gl := Label.new()
	gl.text = "Body"
	gl.add_theme_font_size_override("font_size", _px(16 if short else 18))
	details.add_child(gl)
	for g in [["f", "Woman"], ["m", "Man"]]:
		var gb := Button.new()
		gb.name = "Body_%s" % g[0]
		gb.text = g[1]
		gb.custom_minimum_size = Vector2(_px(100 if short else (120 if phone else 140)), _px(56))
		gb.add_theme_font_size_override("font_size", _px(16 if short else 18))
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
	_name.name = "NameField"
	_name.placeholder_text = "Name"
	_name.text = "Survivor"
	_name.custom_minimum_size = Vector2(_px(200 if short else (fitted.x - 48.0 if phone else 300.0)), _px(56))
	_name.add_theme_font_size_override("font_size", _px(16 if short else 20))
	details.add_child(_name)
	_start = Button.new()
	_start.name = "EnterRift"
	_start.text = "ENTER THE RIFT"
	_start.custom_minimum_size = Vector2(_px(200 if short else (fitted.x - 48.0 if phone else 320.0)), _px(64))
	_start.add_theme_font_size_override("font_size", _px(18 if short else 22))
	_start.disabled = true
	_start.pressed.connect(_finish)
	details.add_child(_start)
	UiTokens.focus_first(_cards.values())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--occupation="):
			_select(a.substr(13))
			call_deferred("_finish")

func _card_line(text: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

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
