class_name RadioUniversityUI
extends UiWorldSheet
## Radio University (systems PRD §15.1; ui-redesign-spec §7 F3, [owner] its own screen): Dr. Lamar's
## career guides from data/world/factions.json "radio_university" - no crates, no fetch quests. Each
## guide is a checklist of skills practised and the only reputation path for this org; each earns
## sp_per_guide SP. Back returns to the Communication screen (CommsUI connects it); ✕ closes.
##
## ASSUMPTION: no career-guide progress exists in code yet, so every guide reads "Not started" and the
## screen is read-only. The guide ids are shown as names; their checklists are not in data.

var player: Player
var row: Dictionary = {}

var _intro: PanelContainer
var _who: Label
var _what: Label
var _list_panel: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _locked: Label

func _init() -> void:
	super("Radio University")

func _build() -> void:
	name = "RadioUniversityUI"
	close_pressed.connect(close)
	for f in CommsUI.load_factions():
		if str(f["id"]) == "radio_university":
			row = f
	_intro = SheetChrome.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
	_intro.name = "Intro"
	body.add_child(_intro)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 0)
	_intro.add_child(iv)
	var parch := PanelContainer.new()
	parch.name = "Parchment"
	parch.add_theme_stylebox_override("panel", SheetChrome.parchment_style())
	iv.add_child(parch)
	_who = SheetChrome.label("Dr. Lamar", 30, UiTokens.PARCHMENT_INK, true)
	_who.name = "Who"
	parch.add_child(_who)
	var pad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + s, 20)
	iv.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)
	_what = SheetChrome.label("", 19, UiTokens.TEXT)
	_what.name = "What"
	_what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_what)
	_locked = SheetChrome.label("", 17, UiTokens.GOLD)
	_locked.name = "Locked"
	_locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_locked)
	_list_panel = SheetChrome.panel(Color(UiTokens.HEADER.lightened(0.06), 0.92))
	_list_panel.name = "Guides"
	body.add_child(_list_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	_scroll.add_child(_list)
	for g in row.get("guides", []):
		_list.add_child(_guide_row(str(g)))

func _guide_row(id: String) -> Control:
	var pad := PanelContainer.new()
	pad.name = "Guide_%s" % id
	var sb := SheetChrome.box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.08), 0)
	sb.border_width_bottom = 1
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	pad.add_theme_stylebox_override("panel", sb)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	pad.add_child(r)
	var name_l := SheetChrome.label(CommsUI.pretty(id), 22, UiTokens.TEXT)
	name_l.name = "Name"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	r.add_child(name_l)
	var state := SheetChrome.label("Not started", 16, UiTokens.MUTED)
	state.name = "State"
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(state)
	var sp := SheetChrome.label("+%d SP" % int(row.get("sp_per_guide", 0)), 18, UiTokens.GOLD)
	sp.name = "SP"
	sp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sp.custom_minimum_size.x = 70
	sp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(sp)
	return pad

func open(p: Player) -> void:
	player = p
	visible = true
	var guides: Array = row.get("guides", [])
	_what.text = "One-man university over the radio. No crates, no fetch quests: career guides only. Each guide is a checklist of skills practised; finishing one is the only way to earn this station's reputation and gives %d SP." % int(row.get("sp_per_guide", 0))
	var need := CommsUI.unlock_level(row)
	var lv: int = p.skills.character_level() if p != null and p.skills != null else 1
	_locked.text = ("Opens at character level %d (you are %d). " % [need, lv] if lv < need else "") + "Guide progress is not tracked in this build yet."
	set_counter("Guides [color=#%s]0[/color] / %d" % [UiTokens.GOLD.to_html(false), guides.size()])
	relayout()

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

func _layout_body(view: Vector2, rect: Rect2) -> void:
	var compact := UiTokens.is_compact(view)
	var gap := 8.0 if compact else 20.0
	var lw := floorf((rect.size.x - gap) * (0.42 if compact else 0.38))
	_intro.position = rect.position
	_intro.size = Vector2(lw, rect.size.y)
	_list_panel.position = Vector2(rect.position.x + lw + gap, rect.position.y)
	_list_panel.size = Vector2(rect.size.x - lw - gap, rect.size.y)
	_who.add_theme_font_size_override("font_size", 18 if compact else 30)
	_what.add_theme_font_size_override("font_size", 13 if compact else 19)
	_locked.add_theme_font_size_override("font_size", 12 if compact else 17)
	var n := maxi(1, _list.get_child_count())
	var row_h := clampf(floorf(rect.size.y / float(n)), 44.0, 76.0)
	for c in _list.get_children():
		var r := c.get_child(0) as HBoxContainer
		r.custom_minimum_size.y = row_h
		(r.get_node("Name") as Label).add_theme_font_size_override("font_size", 15 if compact else 22)
		(r.get_node("State") as Label).add_theme_font_size_override("font_size", 12 if compact else 16)
		(r.get_node("SP") as Label).add_theme_font_size_override("font_size", 13 if compact else 18)
