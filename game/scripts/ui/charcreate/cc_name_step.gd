class_name CcNameStep
extends Control
## Step 3, "Name" (spec 19, owner's "enter name"): back arrow, the dressed and coloured survivor on
## the left half, "Enter the character's name." with a wide field, the rule line with a ? mark, an
## inline error and a yellow OK that stays disabled until the name is valid. The field sits high on
## the right so a landscape phone's keyboard opens under it (and the column moves up if it does not).

signal back_pressed
signal ok_pressed

const MAX_LEN := 20
const HELP := "Can use up to 20 characters, including spaces and special characters such as - and ."

static var _allowed: RegEx

var cc: CharacterCreation
var band: CcUi.Band
var column: Control
var prompt: Label
var field: LineEdit
var help_mark: Control
var help: Label
var error: Label
var ok: Button
var _m: Dictionary = {}
var _column_y := 0.0

## The one name check. 1-20 characters; letters of any script, digits, spaces, "-" and "."; no
## space at either end and none doubled. "" when the name is fine. Online, the server's uniqueness
## check joins here.
static func name_error(raw: String) -> String:
	if raw.strip_edges() == "":
		return "Enter a name."
	if raw != raw.strip_edges():
		return "No spaces at the start or end."
	if raw.length() > MAX_LEN:
		return "Use at most %d characters." % MAX_LEN
	if raw.contains("  "):
		return "Use one space between words."
	if _allowed == null:
		_allowed = RegEx.create_from_string("^[\\p{L}\\p{M}\\p{Nd} .\\-]+$")
	if _allowed.search(raw) == null:
		return "Use letters, digits, spaces, - and . only."
	return ""

func _init(p_cc: CharacterCreation) -> void:
	cc = p_cc
	name = "NameStep"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	column = Control.new()
	column.name = "NameColumn"
	add_child(column)
	prompt = CcUi.label("Enter the character's name.", 22)
	column.add_child(prompt)
	field = LineEdit.new()
	field.name = "NameField"
	field.text = "Survivor"
	field.max_length = MAX_LEN
	field.select_all_on_focus = true
	field.text_changed.connect(func (_t: String) -> void: validate())
	field.text_submitted.connect(func (_t: String) -> void:
		if validate():
			ok_pressed.emit())
	column.add_child(field)
	help_mark = Control.new()
	help_mark.draw.connect(func () -> void:
		var r := help_mark.size.x * 0.5
		help_mark.draw_circle(Vector2(r, r), r, CcUi.MUTED)
		var f := help_mark.get_theme_default_font()
		var fs := maxi(12, int(r * 1.3))
		var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		help_mark.draw_string(f, Vector2(r - w * 0.5, r + fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, CcUi.INK))
	column.add_child(help_mark)
	help = CcUi.label(HELP, 15, CcUi.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	error = CcUi.label("", 15, CcUi.ERROR)
	error.name = "NameError"
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(error)
	ok = CcUi.yellow_button("OK", 24)
	ok.name = "OK"
	ok.pressed.connect(func () -> void:
		if validate():
			ok_pressed.emit())
	column.add_child(ok)
	band = CcUi.Band.new("Name", true)
	band.back_pressed.connect(func () -> void: back_pressed.emit())
	add_child(band)

func layout(view: Vector2, m: Dictionary) -> Rect2:
	_m = m
	size = view
	var inset: Vector4 = m["inset"]
	var px: Callable = m["px"]
	var phone: bool = m["phone"]
	var band_h: float = m["band_h"]
	band.place(Rect2(0, 0, view.x, band_h), m["title_px"], inset.w)
	var pad := float(px.call(12 if phone else 28))
	var half := view.x * 0.5
	var w := view.x - inset.x - half - 2.0 * pad
	_column_y = band_h + pad
	column.position = Vector2(half + pad, _column_y)
	column.size = Vector2(w, view.y - _column_y - inset.y)
	prompt.add_theme_font_size_override("font_size", px.call(16 if phone else 24))
	prompt.position = Vector2.ZERO
	prompt.size = Vector2(w, prompt.get_minimum_size().y)
	var fh := float(px.call(56 if phone else 64))
	field.add_theme_font_size_override("font_size", px.call(18 if phone else 24))
	field.position = Vector2(0, prompt.size.y + float(px.call(8 if phone else 16)))
	field.size = Vector2(w, fh)
	var hm := float(px.call(16 if phone else 20))
	help_mark.size = Vector2(hm, hm)
	help_mark.position = Vector2(0, field.position.y + fh + float(px.call(10)))
	help.add_theme_font_size_override("font_size", px.call(12 if phone else 15))
	help.add_theme_constant_override("line_spacing", -px.call(4 if phone else 5))
	help.position = Vector2(hm + float(px.call(8)), help_mark.position.y - 1.0)
	help.size = Vector2(w - help.position.x, 0)
	help.size.y = help.get_minimum_size().y
	error.add_theme_font_size_override("font_size", px.call(13 if phone else 16))
	error.position = Vector2(0, help.position.y + help.size.y + float(px.call(6)))
	error.size = Vector2(w, float(px.call(18 if phone else 24)))
	var ob := Vector2(px.call(150 if phone else 240), px.call(56 if phone else 64))
	ok.add_theme_font_size_override("font_size", px.call(18 if phone else 24))
	ok.size = ob
	ok.position = Vector2(w - ob.x, error.position.y + error.size.y + float(px.call(6 if phone else 14)))
	validate()
	return Rect2(inset.w, band_h, half - inset.w, view.y - band_h)

## Shows the inline error and enables OK only for a valid name.
func validate() -> bool:
	var why := name_error(field.text)
	error.text = why
	ok.disabled = why != ""
	return why == ""

func player_name() -> String:
	return field.text.strip_edges()

## A landscape phone's keyboard can cover the column: lift it until the field clears the keyboard.
func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var kb := float(DisplayServer.virtual_keyboard_get_height())
	var win := Vector2(DisplayServer.window_get_size())
	var view := get_viewport_rect().size
	var kb_canvas := kb * (view.y / win.y) if win.y > 0.0 else 0.0
	var field_bottom := _column_y + field.position.y + field.size.y + 8.0
	var lift := maxf(0.0, field_bottom - (view.y - kb_canvas)) if kb_canvas > 0.0 else 0.0
	column.position.y = _column_y - lift
