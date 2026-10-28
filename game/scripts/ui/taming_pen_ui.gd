class_name TamingPenUI
extends UiWorldSheet
## E2 Taming Pen (docs/design/ui-redesign-spec.md §7 E2; spec 02 "Physical taming pen"): the
## tame-or-store dialog. Left: the selected captured animal (parchment header with species and level,
## its nature, what bonding means against the bonded cap, diet / role tiles, info and care lines).
## Right: the dialog card - question header, the animal's row with pen space, the mood slider with the
## pen time above it, the pen grid (the pen's occupant and every captured animal in the bag; tap one
## to pick it), and Store / Tame. Once the pen runs: "Taming started" with a live countdown, Feed meat
## and OK. Wired to the existing pen (TamingPen.try_insert / feed, 30 min x nature, 70 % success)
## through PlayerActions.pen_interact -> HuntHud.open_taming_pen(pen).
##
## ASSUMPTION: no mood system exists. The slider is read-only: before taming it shows the animal's
## nature pen-time knob (a shorter wait reads happier), while the pen runs it shows the elapsed share.
## ASSUMPTION: the pen holds one animal (TamingPen), so "Pen space" is occupied / 1 and Store means the
## animal stays caged in the bag; there is no store-in-pen yet. Spec 02's size-based pen area waits on
## a size field in creature data.

const GRID_COLS := 6
const GRID_ROWS := 2

var player: Player
var pen: TamingPen
var picked := -1  ## bag slot of the captured animal shown (-1: the pen's occupant or none)

var _left: PanelContainer
var _l_scroll: ScrollContainer
var _l_title: Label
var _l_icon: TextureRect
var _l_species: Label
var _l_level: Label
var _l_nature: Label
var _l_bond: Label
var _tags: HBoxContainer
var _info_line: Label
var _care_eats: Label
var _care_time: Label
var _dlg: PanelContainer
var _q: Label
var _a_icon: TextureRect
var _a_name: Label
var _a_sub: Label
var _space: RichTextLabel
var _mood: _MoodSlider
var _grid: GridContainer
var _cells: Array[Button] = []
var _cell_slot: Array[int] = []  ## per cell: bag slot, -2 = pen occupant, -1 = empty
var _store: Button
var _tame: Button
var _feed: Button
var _ok: Button
var _msg: Label

func _init() -> void:
	super("Taming Pen")

func _build() -> void:
	name = "TamingPenUI"
	back_pressed.connect(close)
	close_pressed.connect(close)
	_left = UiWorldSheet.panel(Color(UiTokens.HEADER.lightened(0.07), 0.94))
	_left.name = "Animal"
	body.add_child(_left)
	_l_scroll = ScrollContainer.new()
	_l_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left.add_child(_l_scroll)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 0)
	_l_scroll.add_child(lv)
	var parch := PanelContainer.new()
	parch.name = "Parchment"
	parch.add_theme_stylebox_override("panel", UiWorldSheet.parchment_style())
	lv.add_child(parch)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	parch.add_child(pv)
	_l_title = UiWorldSheet.label("", 28, UiTokens.PARCHMENT_INK, true)
	_l_title.name = "Title"
	_l_title.clip_text = true
	pv.add_child(_l_title)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 14)
	pv.add_child(who)
	_l_icon = TextureRect.new()
	_l_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_l_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_l_icon.custom_minimum_size = Vector2(64, 64)
	who.add_child(_l_icon)
	var wv := VBoxContainer.new()
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_theme_constant_override("separation", 0)
	who.add_child(wv)
	_l_species = UiWorldSheet.label("", 18, UiTokens.PARCHMENT_INK)
	wv.add_child(_l_species)
	_l_level = UiWorldSheet.label("", 26, UiTokens.PARCHMENT_INK)
	wv.add_child(_l_level)
	var sep := ColorRect.new()
	sep.color = Color(UiTokens.PARCHMENT_INK, 0.25)
	sep.custom_minimum_size.y = 1
	pv.add_child(sep)
	_l_nature = UiWorldSheet.label("", 18, UiTokens.PARCHMENT_INK)
	_l_nature.name = "Nature"
	pv.add_child(_l_nature)
	var bpad := _pad(lv)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	bpad.add_child(bv)
	_l_bond = UiWorldSheet.label("", 18, UiTokens.TEXT)
	_l_bond.name = "Bond"
	_l_bond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(_l_bond)
	_tags = HBoxContainer.new()
	_tags.name = "Tags"
	_tags.add_theme_constant_override("separation", 10)
	bv.add_child(_tags)
	lv.add_child(_band("Info"))
	var ipad := _pad(lv)
	_info_line = UiWorldSheet.label("", 18, UiTokens.MUTED.lightened(0.2))
	_info_line.name = "Info"
	_info_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ipad.add_child(_info_line)
	lv.add_child(_band("Care"))
	var cpad := _pad(lv)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cpad.add_child(cv)
	_care_eats = _care_row(cv, "Eats")
	_care_time = _care_row(cv, "Pen time")

	_dlg = UiWorldSheet.panel(Color(UiTokens.HEADER.lightened(0.10), 0.96))
	_dlg.name = "Dialog"
	body.add_child(_dlg)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 0)
	_dlg.add_child(dv)
	var qp := PanelContainer.new()
	qp.name = "Question"
	qp.add_theme_stylebox_override("panel", UiWorldSheet.parchment_style())
	dv.add_child(qp)
	_q = UiWorldSheet.label("", 26, UiTokens.PARCHMENT_INK, true)
	_q.name = "Q"
	_q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_q.clip_text = true
	qp.add_child(_q)
	var arow_bg := PanelContainer.new()
	arow_bg.add_theme_stylebox_override("panel", UiWorldSheet._box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0))
	dv.add_child(arow_bg)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 16)
	arow_bg.add_child(arow)
	_a_icon = TextureRect.new()
	_a_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_a_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_a_icon.custom_minimum_size = Vector2(80, 80)
	arow.add_child(_a_icon)
	var av := VBoxContainer.new()
	av.alignment = BoxContainer.ALIGNMENT_CENTER
	av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	av.add_theme_constant_override("separation", 0)
	arow.add_child(av)
	_a_name = UiWorldSheet.label("", 30, UiTokens.GOLD)
	_a_name.name = "AnimalName"
	_a_name.clip_text = true
	av.add_child(_a_name)
	_a_sub = UiWorldSheet.label("", 19, UiTokens.TEXT)
	av.add_child(_a_sub)
	_space = RichTextLabel.new()
	_space.name = "PenSpace"
	_space.bbcode_enabled = true
	_space.fit_content = true
	_space.scroll_active = false
	_space.autowrap_mode = TextServer.AUTOWRAP_OFF
	_space.custom_minimum_size.x = 170
	_space.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_space.add_theme_font_override("normal_font", UiTokens.ui_face())
	arow.add_child(_space)
	_mood = _MoodSlider.new()
	_mood.name = "Mood"
	dv.add_child(_mood)
	_grid = GridContainer.new()
	_grid.name = "PenGrid"
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_grid)
	for i in GRID_COLS * GRID_ROWS:
		var cell := Button.new()
		cell.name = "Cell%d" % i
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var sb := UiWorldSheet._box(Color(0, 0, 0, 0.18), Color(1, 1, 1, 0.07), 1)
		for s in ["normal", "hover", "pressed", "disabled"]:
			cell.add_theme_stylebox_override(s, sb)
		cell.add_theme_stylebox_override("focus", UiWorldSheet._box(Color(0, 0, 0, 0), UiTokens.GOLD, 1))
		cell.expand_icon = true
		cell.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_theme_constant_override("icon_max_width", 72)
		var lvl := UiWorldSheet.label("", 14, UiTokens.MUTED)
		lvl.name = "Lv"
		lvl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		lvl.offset_left = -60
		lvl.offset_right = -8
		lvl.offset_top = 4
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cell.add_child(lvl)
		var mark := UiWorldSheet.Brackets.new()
		mark.name = "Brackets"
		mark.visible = false
		cell.add_child(mark)
		var idx := i
		cell.pressed.connect(func () -> void: _on_cell(idx))
		_grid.add_child(cell)
		_cells.append(cell)
		_cell_slot.append(-1)
	_msg = UiWorldSheet.label("", 15, UiTokens.GOLD)
	_msg.name = "Message"
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_msg)
	var fpad := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		fpad.add_theme_constant_override("margin_" + s, 16)
	dv.add_child(fpad)
	var foot := HBoxContainer.new()
	foot.name = "Foot"
	foot.add_theme_constant_override("separation", 14)
	fpad.add_child(foot)
	_store = UiWorldSheet.ghost_button("Store")
	_store.name = "Store"
	_store.pressed.connect(_on_store)
	_tame = UiWorldSheet.gold_button("Tame")
	_tame.name = "Tame"
	_tame.pressed.connect(_on_tame)
	_feed = UiWorldSheet.ghost_button("Feed meat")
	_feed.name = "Feed"
	_feed.pressed.connect(_on_feed)
	_ok = UiWorldSheet.gold_button("OK")
	_ok.name = "OK"
	_ok.pressed.connect(close)
	for b in [_store, _tame, _feed, _ok]:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(b)
	_tame.size_flags_stretch_ratio = 1.6
	_ok.size_flags_stretch_ratio = 1.6

func _pad(parent: Control) -> MarginContainer:
	var m := MarginContainer.new()
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 18)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	parent.add_child(m)
	return m

func _band(text: String) -> PanelContainer:
	var band := PanelContainer.new()
	band.add_theme_stylebox_override("panel", UiWorldSheet._box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0))
	var l := UiWorldSheet.label(text, 20, UiTokens.TEXT)
	l.name = "BandLabel"
	band.add_child(l)
	return band

func _care_row(parent: Control, key: String) -> Label:
	var r := HBoxContainer.new()
	var k := UiWorldSheet.label(key, 18, UiTokens.TEXT)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(k)
	var v := UiWorldSheet.label("", 18, UiTokens.GOLD)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	parent.add_child(r)
	return v

# ---------------------------------------------------------------- data

## Bag slots holding a captured animal, in bag order.
func caged_slots() -> Array[int]:
	var out: Array[int] = []
	if player == null or player.inventory == null:
		return out
	for i in player.inventory.slots.size():
		var s: ItemStack = player.inventory.slots[i]
		if s != null and s.def_id == &"captured_animal":
			out.append(i)
	return out

## The stack the screen describes: the picked bag animal, else the pen's occupant.
func shown_stack() -> ItemStack:
	if picked >= 0 and player != null and picked < player.inventory.slots.size():
		var s: ItemStack = player.inventory.slots[picked]
		if s != null and s.def_id == &"captured_animal":
			return s
	if pen != null and is_instance_valid(pen) and pen.occupant != null:
		return pen.occupant
	return null

func is_running() -> bool:
	return pen != null and is_instance_valid(pen) and pen.running and pen.occupant != null

## The wait this animal would take in the pen (TamingPen.BASE_SECONDS x its nature's knob).
static func pen_seconds(s: ItemStack) -> float:
	if s == null:
		return TamingPen.BASE_SECONDS
	var nat := StringName(str(s.attributes.get("nature", "")))
	return TamingPen.BASE_SECONDS * float(CreatureNatures.knobs(nat).get("pen_time_mult", 1.0))

static func clock(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	if s >= 3600:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]

static func duration(seconds: float) -> String:
	var m := maxi(1, roundi(seconds / 60.0))
	return "%dh" % (m / 60) if m % 60 == 0 and m >= 60 else ("%dh %dm" % [m / 60, m % 60] if m > 60 else "%dm" % m)

# ---------------------------------------------------------------- open / actions

## Open on `pen` (null: the bag's captured animals only, nothing can start).
func open(p: Player, the_pen: TamingPen = null) -> void:
	player = p
	pen = the_pen
	visible = true
	var cages := caged_slots()
	picked = -1 if is_running() or cages.is_empty() else cages[0]
	_msg.text = ""
	_refresh()
	relayout()
	UiTokens.focus_first([_ok if is_running() else _tame])

func close() -> void:
	visible = false

func is_open() -> bool:
	return visible

func _on_cell(i: int) -> void:
	var slot := _cell_slot[i]
	if slot == -1:
		return
	picked = slot if slot >= 0 else -1
	_msg.text = ""
	_refresh()

## Store: the animal stays caged in the bag (no store-in-pen exists yet).
func _on_store() -> void:
	close()

func _on_tame() -> void:
	if pen == null or not is_instance_valid(pen) or player == null:
		_msg.text = "Stand at a taming pen to start taming."
		return
	if pen.try_insert(player, picked):
		picked = -1
		_msg.text = ""
	else:
		_msg.text = "The pen is busy." if pen.running else "No captured animal to put in."
	_refresh()
	relayout()

func _on_feed() -> void:
	if pen == null or not is_instance_valid(pen):
		return
	_msg.text = "" if pen.feed(player) else "Needs raptor meat in your bag (each feed cuts the wait to 60 %)."
	_refresh()

func _process(_delta: float) -> void:
	if visible and is_running():
		_refresh_timer()

func _refresh() -> void:
	var s := shown_stack()
	var running := is_running()
	var cages := caged_slots()
	var has_pen := pen != null and is_instance_valid(pen)
	_store.visible = not running
	_tame.visible = not running
	_feed.visible = running
	_ok.visible = running
	_tame.disabled = s == null or not has_pen or (pen.running if has_pen else true)
	_store.disabled = s == null
	if running and pen.remaining <= 0.0:
		_q.text = "Taming done: waiting for a free pack slot"
	elif running:
		_q.text = "Taming started: check back in %s" % duration(pen.remaining / maxf(0.01, Game.time_scale))
	elif s == null:
		_q.text = "The pen is empty"
	elif has_pen:
		_q.text = "Tame it now, or keep it caged?"
	else:
		_q.text = "Bring it to a taming pen to tame it"
	var species := StringName(str(s.attributes.get("species", ""))) if s != null else &""
	var def: CreatureDef = Data.creature(species) if species != &"" else null
	var sp_name := def.species if def != null else str(species).capitalize()
	var lvl := int(s.attributes.get("level", 1)) if s != null else 0
	var nat := StringName(str(s.attributes.get("nature", ""))) if s != null else &""
	var icon := ItemIcons.texture(&"captured_animal")
	if icon == null:
		icon = UiIcons.icon(&"capture")
	_l_icon.texture = icon
	_a_icon.texture = icon
	if s == null:
		_l_title.text = "No captured animal"
		_l_species.text = "Net a weakened animal"
		_l_level.text = ""
		_l_nature.text = "Stunned, or at 30 % HP or less"
		_l_bond.text = "Capture one with a net (stunned, or at 30 % HP or less), then bring it here."
		_a_name.text = "Nothing in the pen"
		_a_sub.text = "Captured animals in your bag show in the grid below."
		_info_line.text = ""
		_care_eats.text = "-"
		_care_time.text = duration(TamingPen.BASE_SECONDS)
	else:
		_l_title.text = "Captured %s" % sp_name
		_l_species.text = sp_name
		_l_level.text = "Lv. %d" % lvl
		var nl := CreatureNatures.label(nat)
		_l_nature.text = "Nature: %s" % (nl if nl != "" else "unknown")
		var cap := Data.bonded_cap()
		var have: int = player.bonded.size() if player != null else 0
		_l_bond.text = "Once tamed here it bonds with you and joins your pack (%d / %d)." % [have, cap]
		_a_name.text = "Captured %s" % sp_name
		_a_sub.text = "Lv. %d%s" % [lvl, " · %s" % nl if nl != "" else ""]
		_info_line.text = "%s · %s · about %.0f m long" % [def.clade, def.period, def.real_length_m] if def != null and def.clade != "" else ""
		var foods: Array[String] = []
		if def != null:
			for f in def.preferred_food:
				var fd := Data.item(f)
				foods.append(fd.display_name if fd != null and fd.display_name != "" else CommsUI.pretty(str(f)))
		_care_eats.text = ", ".join(foods) if not foods.is_empty() else "-"
		_care_time.text = duration(pen_seconds(s))
	_fill_tags(def)
	var occ := 1 if has_pen and pen.occupant != null else 0
	_space.text = "[right]Pen space [color=#%s]%d[/color] / 1[/right]" % [UiTokens.GOLD.to_html(false), occ]
	# The grid: the pen's occupant first, then every captured animal in the bag.
	var shown: Array[int] = []
	if has_pen and pen.occupant != null:
		shown.append(-2)
	shown.append_array(cages)
	for i in _cells.size():
		var cell := _cells[i]
		var slot: int = shown[i] if i < shown.size() else -1
		_cell_slot[i] = slot
		var st: ItemStack = pen.occupant if slot == -2 else (player.inventory.slots[slot] if slot >= 0 else null)
		cell.icon = icon if st != null else null
		cell.disabled = st == null
		(cell.get_node("Lv") as Label).text = "Lv. %d" % int(st.attributes.get("level", 1)) if st != null else ""
		var sel: bool = st != null and ((slot == -2 and picked < 0) or slot == picked)
		(cell.get_node("Brackets") as Control).visible = sel
		cell.modulate = Color(1, 1, 1, 0.55) if slot == -2 and running and not sel else Color.WHITE
	_mood.pen_time = pen_seconds(s)
	_refresh_timer()

func _refresh_timer() -> void:
	if is_running():
		var total := pen_seconds(pen.occupant)
		_mood.ratio = clampf(1.0 - pen.remaining / maxf(1.0, total), 0.0, 1.0)
		_mood.caption = clock(pen.remaining / maxf(0.01, Game.time_scale))
	else:
		var s := shown_stack()
		# Shorter than the base wait reads happier (nature knob, 0.5x .. 1.5x mapped to 1 .. 0).
		var mult := pen_seconds(s) / TamingPen.BASE_SECONDS
		_mood.ratio = clampf(1.5 - mult, 0.0, 1.0) * 0.6 + 0.2 if s != null else 0.0
		_mood.caption = duration(pen_seconds(s)) if s != null else "-"
	_mood.queue_redraw()

func _fill_tags(def: CreatureDef) -> void:
	for c in _tags.get_children():
		c.queue_free()
	if def == null:
		return
	var tags: Array = [[&"eat", "Herbivore" if def.is_herbivore_diet() else "Carnivore"]]
	for role in def.tamed_role:
		match str(role):
			"mount":
				tags.append([&"ride", "Rideable"])
			"cargo", "bag":
				tags.append([&"cargo", "Carrier"])
			"scout":
				tags.append([&"map", "Scout"])
			"combat":
				tags.append([&"attack", "Fighter"])
			_:
				tags.append([&"pets", CommsUI.pretty(str(role))])
	var compact := UiTokens.is_compact(get_viewport_rect().size)
	for t in tags:
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", UiWorldSheet._box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(UiWorldSheet.icon_rect(t[0], 24.0 if compact else 36.0))
		var l := UiWorldSheet.label(str(t[1]), 12 if compact else 16, UiTokens.TEXT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		tile.add_child(v)
		tile.custom_minimum_size = Vector2(64.0 if compact else 96.0, 56.0 if compact else 90.0)
		_tags.add_child(tile)

# ---------------------------------------------------------------- layout

func _layout_body(view: Vector2, rect: Rect2) -> void:
	var compact := UiTokens.is_compact(view)
	var lw := floorf(minf(420.0, rect.size.x * 0.30)) if not compact else floorf(rect.size.x * 0.34)
	_left.position = rect.position
	_left.size = Vector2(lw, rect.size.y)
	var free_x := rect.position.x + lw + (8.0 if compact else 20.0)
	var free_w := rect.end.x - free_x
	var dw := minf(free_w, 880.0) if not compact else free_w
	var dh := minf(rect.size.y, 690.0) if not compact else rect.size.y
	_dlg.position = Vector2(free_x + (free_w - dw) * 0.5, rect.position.y + (rect.size.y - dh) * 0.5)
	_dlg.size = Vector2(dw, dh)
	_l_title.add_theme_font_size_override("font_size", 17 if compact else 28)
	_l_species.add_theme_font_size_override("font_size", 13 if compact else 18)
	_l_level.add_theme_font_size_override("font_size", 17 if compact else 26)
	_l_nature.add_theme_font_size_override("font_size", 13 if compact else 18)
	_l_icon.custom_minimum_size = Vector2.ONE * (40.0 if compact else 64.0)
	for l in [_l_bond, _info_line]:
		(l as Label).add_theme_font_size_override("font_size", 13 if compact else 18)
	for l in [_care_eats, _care_time]:
		(l as Label).add_theme_font_size_override("font_size", 13 if compact else 18)
		((l as Label).get_parent().get_child(0) as Label).add_theme_font_size_override("font_size", 13 if compact else 18)
	for band in _left.find_children("BandLabel", "Label", true, false):
		(band as Label).add_theme_font_size_override("font_size", 14 if compact else 20)
	var ps := _left.find_child("Parchment", true, false) as PanelContainer
	(ps.get_theme_stylebox("panel") as StyleBoxTexture).content_margin_left = 10 if compact else 18
	_q.add_theme_font_size_override("font_size", 16 if compact else 26)
	var qs := (_q.get_parent() as PanelContainer).get_theme_stylebox("panel") as StyleBoxTexture
	qs.content_margin_top = 4 if compact else 16
	qs.content_margin_bottom = 4 if compact else 16
	_a_icon.custom_minimum_size = Vector2.ONE * (40.0 if compact else 80.0)
	_a_name.add_theme_font_size_override("font_size", 17 if compact else 30)
	_a_sub.add_theme_font_size_override("font_size", 12 if compact else 19)
	_space.add_theme_font_size_override("normal_font_size", 13 if compact else 20)
	_space.custom_minimum_size.x = 110.0 if compact else 170.0
	_mood.custom_minimum_size.y = 40.0 if compact else 66.0
	_mood.px = 13 if compact else 18
	# A landscape phone has room for one row of pen cells; the second row hides.
	for i in _cells.size():
		_cells[i].visible = not compact or i < GRID_COLS
		_cells[i].custom_minimum_size = Vector2(0.0, 64.0)
		(_cells[i].get_node("Lv") as Label).add_theme_font_size_override("font_size", 11 if compact else 14)
		_cells[i].add_theme_constant_override("icon_max_width", 40 if compact else 72)
	_msg.add_theme_font_size_override("font_size", 12 if compact else 15)
	var fpad := _store.get_parent().get_parent() as MarginContainer
	for s in ["left", "right", "top", "bottom"]:
		fpad.add_theme_constant_override("margin_" + s, 6 if compact else 16)
	for b in [_store, _tame, _feed, _ok]:
		(b as Button).custom_minimum_size = Vector2(0.0, 64.0 if compact else 76.0)
		(b as Button).add_theme_font_size_override("font_size", 18 if compact else 28)

## The mood slider: angry face, track with a GOLD fill to `ratio`, happy face, and a boxed caption
## (pen time, or the countdown) riding above the fill's end.
class _MoodSlider extends Control:
	var ratio := 0.5
	var caption := ""
	var pen_time := 0.0
	var px := 18
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _face(c: Vector2, r: float, happy: bool) -> void:
		draw_rect(Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2.0), UiTokens.GOLD if happy else UiTokens.LIFE)
		var ink := UiTokens.CTA_INK
		draw_circle(c + Vector2(-r * 0.38, -r * 0.2), r * 0.13, ink)
		draw_circle(c + Vector2(r * 0.38, -r * 0.2), r * 0.13, ink)
		var pts := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			var x := lerpf(-r * 0.45, r * 0.45, t)
			# y grows downward: a smile sags in the middle, a frown arches up.
			var y := (0.15 + 0.2 * sin(t * PI)) * r if happy else (0.4 - 0.2 * sin(t * PI)) * r
			pts.append(c + Vector2(x, y))
		draw_polyline(pts, ink, maxf(1.5, r * 0.12), true)
	func _draw() -> void:
		var r := clampf(size.y * 0.22, 7.0, 14.0)
		var w := minf(size.x * 0.4, 300.0)
		var cy := size.y * 0.68
		var x0 := (size.x - w) * 0.5
		_face(Vector2(x0 - r * 3.0, cy), r, false)
		_face(Vector2(x0 + w + r * 3.0, cy), r, true)
		draw_line(Vector2(x0, cy), Vector2(x0 + w, cy), Color(UiTokens.MUTED, 0.5), 3.0)
		var end := x0 + w * clampf(ratio, 0.0, 1.0)
		draw_line(Vector2(x0, cy), Vector2(end, cy), UiTokens.GOLD, 3.0)
		if caption == "":
			return
		var f := UiTokens.ui_face()
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 14.0
		var th := float(px) + 8.0
		var box := Rect2(Vector2(clampf(end - tw * 0.5, 0.0, size.x - tw), cy - r - th - 4.0), Vector2(tw, th))
		draw_rect(box, Color(0.14, 0.15, 0.16, 0.95))
		UiTokens.draw_centered(self, f, box.get_center(), caption, px, UiTokens.TEXT)
