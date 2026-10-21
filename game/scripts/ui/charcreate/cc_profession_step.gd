class_name CcProfessionStep
extends Control
## Step 1, "Gender/Profession" (spec 19, docs/reference/durango-character-creation.png): the
## occupation list on the left (dotted rows, the selected one lighter with yellow corner brackets),
## the gold occupation title over the live 3D survivor, the starting skill "Lv. 20 <Tree>" and the
## story at the bottom left, and a bottom bar with the gender hex and a yellow Next.
## The skill line is built from data/skills/occupations.json (tree) and SkillState.NAMES.

signal next_pressed

const GENDER_GLYPH := {"m": "♂", "f": "♀"}
const GENDER_NAME := {"m": "Male", "f": "Female"}

var cc: CharacterCreation
var band: CcUi.Band
## SaveGame._warn_new_world puts its note at index 2 of the creation screen's first VBoxContainer
## (after the skill line and the story), so `info` is built before any other VBoxContainer.
var info: VBoxContainer
var skill_line: Label
var story: Label
var title: Label
var list_scroll: ScrollContainer
var list: VBoxContainer
var rows: Dictionary = {}
var bar: Control
var gender_hex: CcUi.Hex
var gender_label: Label
var model_note: Label
var next: Button
var _stage_rect := Rect2()

func _init(p_cc: CharacterCreation) -> void:
	cc = p_cc
	name = "ProfessionStep"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	info = VBoxContainer.new()
	info.name = "Info"
	info.alignment = BoxContainer.ALIGNMENT_END
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skill_line = CcUi.label("", 24, CcUi.GOLD)
	skill_line.name = "SkillLine"
	info.add_child(skill_line)
	story = CcUi.label("", 18)
	story.name = "Story"
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(story)
	title = CcUi.label("", 36, CcUi.GOLD)
	title.name = "OccupationTitle"
	model_note = CcUi.label("", 14, CcUi.MUTED)
	model_note.name = "ModelNote"
	model_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	model_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	list_scroll = ScrollContainer.new()
	list_scroll.name = "OccupationList"
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.draw.connect(func () -> void: list_scroll.draw_rect(Rect2(Vector2.ZERO, list_scroll.size), CcUi.LIST_BG))
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	for occupation in SkillState.occupations():
		var id := str(occupation.get("id", ""))
		var row := CcUi.row_button(str(occupation.get("name", id)), 22)
		row.name = "Occ_%s" % id
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.pressed.connect(func () -> void: cc.select_occupation(id))
		row.draw.connect(_draw_row.bind(row, id))
		list.add_child(row)
		rows[id] = row
	bar = Control.new()
	bar.name = "BottomBar"
	bar.draw.connect(func () -> void:
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(0.075, 0.075, 0.075))
		CcUi.dotted(bar, Vector2.ZERO, Vector2(bar.size.x, 0)))
	gender_hex = CcUi.Hex.new(64)
	gender_hex.name = "GenderToggle"
	gender_hex.fill = CcUi.GOLD
	gender_hex.glyph_color = CcUi.INK
	gender_hex.pressed.connect(func () -> void: cc.set_gender("f" if cc.look["gender"] == "m" else "m"))
	bar.add_child(gender_hex)
	gender_label = CcUi.label("", 16)
	bar.add_child(gender_label)
	next = CcUi.yellow_button("Next", 24)
	next.name = "Next"
	next.pressed.connect(func () -> void: next_pressed.emit())
	bar.add_child(next)
	band = CcUi.Band.new("Gender/Profession", false)
	for n in [info, title, model_note, list_scroll, bar, band]:
		add_child(n)

## Lays the step out on a `view` canvas; returns the rect the 3D stage fills.
func layout(view: Vector2, m: Dictionary) -> Rect2:
	var inset: Vector4 = m["inset"]  # right, bottom, top, left
	var px: Callable = m["px"]
	var phone: bool = m["phone"]
	size = view
	var band_h: float = m["band_h"]
	band.place(Rect2(0, 0, view.x, band_h), m["title_px"], inset.w)
	var list_w := float(px.call(190 if phone else 340)) + inset.w
	var body_top := band_h
	list_scroll.position = Vector2(0, body_top)
	list_scroll.size = Vector2(list_w, view.y - body_top)
	var row_h := maxf(float(px.call(48 if phone else 64)), floorf((view.y - body_top - inset.y) / maxf(1.0, rows.size())))
	for id in rows:
		var row: Button = rows[id]
		row.custom_minimum_size = Vector2(0, row_h)
		row.add_theme_font_size_override("font_size", px.call(17 if phone else 24))
		row.add_theme_constant_override("h_separation", 0)
		for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = CcUi.ROW_SELECTED if id == cc.occupation() else Color(0, 0, 0, 0)
			sb.content_margin_left = inset.w + float(px.call(16 if phone else 26))
			if s == "focus":
				sb.draw_center = false
				sb.border_color = Color(1, 1, 1, 0.5)
				sb.set_border_width_all(1)
			row.add_theme_stylebox_override(s, sb)
	var bar_h := float(px.call(68 if phone else 96))
	bar.position = Vector2(list_w, view.y - bar_h)
	bar.size = Vector2(view.x - list_w, bar_h)
	var pad := float(px.call(12 if phone else 24))
	var hex := float(px.call(56 if phone else 64))
	gender_hex.custom_minimum_size = Vector2(hex, hex)
	gender_hex.size = Vector2(hex, hex)
	gender_hex.position = Vector2(pad, (bar_h - hex) * 0.5)
	gender_label.add_theme_font_size_override("font_size", px.call(14 if phone else 16))
	gender_label.position = Vector2(pad + hex + float(px.call(14)), (bar_h - gender_label.get_minimum_size().y) * 0.5)
	var nb := Vector2(px.call(170 if phone else 260), px.call(56 if phone else 64))
	next.add_theme_font_size_override("font_size", px.call(18 if phone else 24))
	next.size = nb
	next.position = Vector2(bar.size.x - inset.x - pad - nb.x, (bar_h - nb.y) * 0.5)
	_stage_rect = Rect2(list_w, body_top, view.x - list_w, view.y - body_top - bar_h)
	var s := _stage_rect
	title.add_theme_font_size_override("font_size", px.call(24 if phone else 38))
	title.position = s.position + Vector2(pad, float(px.call(10 if phone else 22)))
	title.size = Vector2(s.size.x * 0.6, title.get_minimum_size().y)
	skill_line.add_theme_font_size_override("font_size", px.call(16 if phone else 24))
	story.add_theme_font_size_override("font_size", px.call(13 if phone else 18))
	# The fallback font's lines sit far apart: two-line stories read as two loose captions.
	story.add_theme_constant_override("line_spacing", -px.call(4 if phone else 6))
	info.add_theme_constant_override("separation", px.call(4 if phone else 8))
	var info_w := minf(s.size.x * (0.46 if phone else 0.4), float(px.call(460)))
	# Bottom-anchored column (ALIGNMENT_END): a save warning added under the story grows it upward.
	info.position = Vector2(s.position.x + pad, title.position.y + title.size.y + float(px.call(8)))
	info.size = Vector2(info_w, s.end.y - float(px.call(12 if phone else 24)) - info.position.y)
	model_note.add_theme_font_size_override("font_size", px.call(12 if phone else 14))
	model_note.size = Vector2(s.size.x * 0.34, 0)
	model_note.position = Vector2(s.end.x - inset.x - pad - model_note.size.x, title.position.y + float(px.call(4)))
	refresh()
	return _stage_rect

func refresh() -> void:
	var id := cc.occupation()
	var row := cc.occupation_row(id)
	title.text = str(row.get("name", ""))
	skill_line.text = skill_text(row)
	story.text = str(row.get("story", ""))
	var g := str(cc.look["gender"])
	gender_hex.glyph = GENDER_GLYPH.get(g, "")
	gender_label.text = GENDER_NAME.get(g, "")
	gender_label.size = gender_label.get_minimum_size()
	# No female survivor model exists yet: say so instead of faking one.
	model_note.text = "No female model yet. Showing the current survivor." if g == "f" else ""
	next.disabled = id == ""
	for k in rows:
		var b: Button = rows[k]
		b.queue_redraw()
		for s in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := b.get_theme_stylebox(s) as StyleBoxFlat
			if sb:
				sb.bg_color = CcUi.ROW_SELECTED if k == id else Color(0, 0, 0, 0)
	gender_hex.queue_redraw()

## "Lv. 20 Melee": the occupation's tree from occupations.json, named by SkillState.NAMES.
static func skill_text(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	var tree := str(row.get("tree", ""))
	# PRD 5.1's head start; t_charcreate checks the line against SkillState.apply_occupation's result.
	return "%s %s" % [LevelDisplay.label(SkillState.OCCUPATION_LEVEL), str(SkillState.NAMES.get(tree, tree.capitalize()))]

func _draw_row(row: Button, id: String) -> void:
	var r := Rect2(Vector2.ZERO, row.size)
	CcUi.dotted(row, Vector2(0, r.end.y - 1.0), Vector2(r.end.x, r.end.y - 1.0))
	if id == cc.occupation():
		CcUi.brackets(row, r.grow(-2.0), minf(18.0, r.size.y * 0.28))
