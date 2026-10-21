class_name CcCreateStep
extends Control
## Step 2, "Create Character" (spec 19, docs/reference/durango-create-character.png): the rendered
## portrait in yellow brackets over the Portrait / Appearance / Color tabs and the randomise die on the
## left, the tab's hex column, the live 3D survivor in the middle, the clothing toggles (the preview tries
## a kit on) and the tab's options with a yellow Next on the right. Every option comes from
## CharacterLook (appearance.json and the masks).
##   Portrait:   Pattern, Background Color (the picture itself is rendered by PortraitService)
##   Appearance: Height (a vertical slider) and any part slot with two or more options
##   Color:      one hex per colour slot the model has a mask for; a palette grid for the chosen one

signal back_pressed
signal next_pressed

const TABS := [["appearance", "Appearance"], ["color", "Color"]]
const COLUMNS := 6

var cc: CharacterCreation
var band: CcUi.Band
var tab := "portrait"
var sub := ""
var tab_col: Control
var portrait_box: Control
var tab_rows: Dictionary = {}
var die: Button
var sub_scroll: ScrollContainer
var sub_list: VBoxContainer
var outfit_col: VBoxContainer
var outfits: Dictionary = {}
var panel: Control
var panel_title: Label
var panel_note: Label
var grid_scroll: ScrollContainer
var grid: GridContainer
var slider_box: Control
var slider: VSlider
var slider_value: Label
var original: CcUi.Hex
var next: Button
var _m: Dictionary = {}
var _view := Vector2.ZERO

func _init(p_cc: CharacterCreation) -> void:
	cc = p_cc
	name = "CreateStep"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_col = Control.new()
	tab_col.name = "Tabs"
	tab_col.draw.connect(func () -> void: tab_col.draw_rect(Rect2(Vector2.ZERO, tab_col.size), CcUi.LIST_BG))
	add_child(tab_col)
	portrait_box = Control.new()
	portrait_box.name = "PortraitTab"
	portrait_box.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_box.gui_input.connect(func (e: InputEvent) -> void:
		if _released(e):
			_set_tab("portrait"))
	portrait_box.draw.connect(_draw_portrait_box)
	tab_col.add_child(portrait_box)
	for t in TABS:
		var b := CcUi.row_button(t[1], 22)
		b.name = "Tab_%s" % t[0]
		var id: String = t[0]
		b.pressed.connect(func () -> void: _set_tab(id))
		b.draw.connect(_draw_tab_row.bind(b, id))
		tab_col.add_child(b)
		tab_rows[id] = b
	die = Button.new()
	die.name = "Randomize"
	die.tooltip_text = "Randomize"
	die.flat = true
	die.draw.connect(_draw_die)
	die.pressed.connect(func () -> void: cc.randomize_look())
	tab_col.add_child(die)
	sub_scroll = ScrollContainer.new()
	sub_scroll.name = "SubTabs"
	sub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sub_list = VBoxContainer.new()
	sub_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_scroll.add_child(sub_list)
	add_child(sub_scroll)
	outfit_col = VBoxContainer.new()
	outfit_col.name = "Outfits"
	outfit_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	for o in CharacterLook.preview_outfits():
		var kit := str(o.get("id", ""))
		var b := Button.new()
		b.name = "Outfit_%s" % (kit if kit != "" else "base")
		b.flat = true
		b.tooltip_text = str(o.get("name", kit))
		b.focus_mode = Control.FOCUS_ALL
		b.draw.connect(_draw_outfit.bind(b, kit))
		b.pressed.connect(func () -> void: cc.preview_outfit(kit))
		outfit_col.add_child(b)
		outfits[kit] = b
	add_child(outfit_col)
	panel = Control.new()
	panel.name = "Options"
	add_child(panel)
	panel_title = CcUi.label("", 18)
	panel.add_child(panel_title)
	panel_note = CcUi.label("", 14, CcUi.MUTED)
	panel_note.name = "SlotNote"
	panel_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(panel_note)
	original = CcUi.Hex.new(48)
	original.name = "Original"
	original.caption = "Original"
	original.pressed.connect(func () -> void: cc.set_color(sub, ""))
	panel.add_child(original)
	grid_scroll = ScrollContainer.new()
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid = GridContainer.new()
	grid.name = "Swatches"
	grid.columns = COLUMNS
	grid_scroll.add_child(grid)
	panel.add_child(grid_scroll)
	slider_box = Control.new()
	slider_box.name = "HeightSlider"
	slider_box.draw.connect(_draw_figures)
	panel.add_child(slider_box)
	slider = VSlider.new()
	slider.name = "Height"
	var hr := CharacterLook.height_range()
	slider.min_value = float(hr["min"])
	slider.max_value = float(hr["max"])
	slider.step = float(hr.get("step", 0.01))
	slider.value_changed.connect(func (v: float) -> void: cc.set_height(v))
	slider_box.add_child(slider)
	slider_value = CcUi.label("", 16, CcUi.GOLD)
	slider_box.add_child(slider_value)
	next = CcUi.yellow_button("Next", 24)
	next.name = "Next"
	next.pressed.connect(func () -> void: next_pressed.emit())
	panel.add_child(next)
	band = CcUi.Band.new("Create Character", true)
	band.back_pressed.connect(func () -> void: back_pressed.emit())
	add_child(band)
	PortraitService.shared().changed.connect(_on_portrait)

func _on_portrait(_t: Texture2D) -> void:
	portrait_box.queue_redraw()

## Lays the step out on a `view` canvas; returns the rect the 3D stage fills.
func layout(view: Vector2, m: Dictionary) -> Rect2:
	_m = m
	_view = view
	size = view
	var inset: Vector4 = m["inset"]
	var px: Callable = m["px"]
	var phone: bool = m["phone"]
	var band_h: float = m["band_h"]
	band.place(Rect2(0, 0, view.x, band_h), m["title_px"], inset.w)
	var pad := float(px.call(8 if phone else 14))
	var tab_w := float(px.call(110 if phone else 210)) + inset.w
	tab_col.position = Vector2(0, band_h)
	tab_col.size = Vector2(tab_w, view.y - band_h)
	var box := minf(tab_w - inset.w - 2.0 * pad, float(px.call(92 if phone else 170)))
	portrait_box.position = Vector2(inset.w + (tab_w - inset.w - box) * 0.5, pad)
	portrait_box.size = Vector2(box, box)
	var row_h := float(px.call(48 if phone else 64))
	var y := portrait_box.position.y + box + pad
	for id in tab_rows:
		var b: Button = tab_rows[id]
		b.add_theme_font_size_override("font_size", px.call(15 if phone else 22))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.content_margin_left = inset.w + pad * 1.5
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(s, sb)
		b.position = Vector2(0, y)
		b.size = Vector2(tab_w, row_h)
		y += row_h
	var d := float(px.call(56 if phone else 60))
	die.size = Vector2(d, d)
	die.position = Vector2(inset.w + pad, tab_col.size.y - inset.y - pad - d)
	var sub_w := float(px.call(86 if phone else 132))
	sub_scroll.position = Vector2(tab_w, band_h + pad)
	sub_scroll.size = Vector2(sub_w, view.y - band_h - inset.y - 2.0 * pad)
	var panel_w := float(px.call(300 if phone else 476))
	panel.position = Vector2(view.x - inset.x - panel_w - pad, band_h + pad)
	panel.size = Vector2(panel_w, view.y - band_h - inset.y - 2.0 * pad)
	var ob := float(px.call(46 if phone else 60))
	outfit_col.add_theme_constant_override("separation", px.call(4 if phone else 10))
	for k in outfits:
		(outfits[k] as Button).custom_minimum_size = Vector2(ob, ob)
	outfit_col.position = Vector2(panel.position.x - pad - ob, panel.position.y)
	outfit_col.size = Vector2(ob, panel.size.y)
	var nb := Vector2(panel_w, px.call(56 if phone else 64))
	next.add_theme_font_size_override("font_size", px.call(18 if phone else 24))
	next.size = nb
	next.position = Vector2(0, panel.size.y - nb.y)
	_rebuild()
	var stage_x := tab_w + sub_w
	return Rect2(stage_x, band_h, outfit_col.position.x - pad - stage_x, view.y - band_h)

func _set_tab(id: String) -> void:
	tab = id
	sub = ""
	_rebuild()

func _set_sub(id: String) -> void:
	sub = id
	if tab == "color":
		cc.show_slot(id)
	_rebuild()

## The tab's hex column and options panel, rebuilt from the current look.
func refresh() -> void:
	_rebuild()

func _subs() -> Array:
	match tab:
		"portrait":
			return [["pattern", "Pattern", Color(0.2, 0.2, 0.2), "#"], ["bg", "Background Color", Color.html(str(cc.look["portrait"]["bg"])), ""]]
		"appearance":
			var out: Array = [["height", "Height", Color(0.2, 0.2, 0.2), "↕"]]
			for s in CharacterLook.pickable_parts(str(cc.look["gender"])):
				out.append([s["id"], s["name"], Color(0.2, 0.2, 0.2), ""])
			return out
	var colors: Array = []
	for s in CharacterLook.color_slots():
		var hex := str(cc.look["colors"].get(s["id"], ""))
		colors.append([s["id"], s["name"], Color.html(hex) if hex != "" else CharacterLook.painted(s["id"]), ""])
	return colors

func _rebuild() -> void:
	if _m.is_empty():
		return
	var px: Callable = _m["px"]
	var phone: bool = _m["phone"]
	var subs := _subs()
	if sub == "" or not subs.any(func (r: Array) -> bool: return r[0] == sub):
		sub = subs[0][0] if not subs.is_empty() else ""
	_clear(sub_list)
	sub_list.add_theme_constant_override("separation", px.call(6 if phone else 12))
	var hex := float(px.call(50 if phone else 76))
	var cap := int(px.call(12 if phone else 14))
	for r in subs:
		var h := CcUi.Hex.new(hex)
		h.name = "Sub_%s" % r[0]
		h.caption = r[1]
		h.caption_px = cap
		h.custom_minimum_size = Vector2(sub_scroll.size.x, hex + cap + 8.0)
		h.fill = r[2]
		h.glyph = r[3]
		h.selected = r[0] == sub
		var id: String = r[0]
		h.pressed.connect(func () -> void: _set_sub(id))
		sub_list.add_child(h)
	_rebuild_panel(px, phone)
	portrait_box.queue_redraw()
	for id in tab_rows:
		(tab_rows[id] as Button).queue_redraw()
	for k in outfits:
		(outfits[k] as Button).queue_redraw()

func _rebuild_panel(px: Callable, phone: bool) -> void:
	_clear(grid)
	var title_px := int(px.call(14 if phone else 18))
	panel_title.add_theme_font_size_override("font_size", title_px)
	panel_title.position = Vector2.ZERO
	var cell := float(px.call(44 if phone else 66))
	var gap := float(px.call(4 if phone else 10))
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap))
	var top := float(title_px) * 1.6
	var is_color := tab == "color"
	original.visible = is_color
	slider_box.visible = tab == "appearance" and sub == "height"
	grid_scroll.visible = not slider_box.visible
	panel_title.text = _sub_name()
	panel_note.text = ""
	if is_color:
		var cur := str(cc.look["colors"].get(sub, ""))
		original.custom_minimum_size = Vector2(cell, cell + 18.0)
		original.size = original.custom_minimum_size
		original.caption_px = int(px.call(12 if phone else 13))
		original.fill = CharacterLook.painted(sub)
		original.selected = cur == ""
		original.check = cur == ""
		original.position = Vector2(panel.size.x - cell, 0)
		panel_note.text = _slot_note(sub)
		top = maxf(top, cell + 22.0)
		for row in CharacterLook.palette(sub):
			for h in row:
				_swatch(cell, Color.html(h), h == cur, cc.set_color.bind(sub, h))
	elif tab == "portrait" and sub == "pattern":
		var bg := Color.html(str(cc.look["portrait"]["bg"]))
		for p in CharacterLook.patterns():
			var pid := str(p.get("id", ""))
			var s := _swatch(cell, bg, pid == str(cc.look["portrait"]["pattern"]), cc.set_portrait.bind("pattern", pid))
			s.texture = ImageTexture.create_from_image(PortraitService.backdrop(pid, bg, 64))
			s.tooltip_text = str(p.get("name", pid))
	elif tab == "portrait":
		for row in CharacterLook.backgrounds():
			for h in row:
				_swatch(cell, Color.html(h), h == str(cc.look["portrait"]["bg"]), cc.set_portrait.bind("bg", h))
	elif tab == "appearance" and sub != "height":
		for s in CharacterLook.pickable_parts(str(cc.look["gender"])):
			if s["id"] != sub:
				continue
			for o in s["options"]:
				var oid := str(o.get("id", ""))
				var sw := _swatch(cell, Color(0.2, 0.2, 0.2), oid == str(cc.look["parts"].get(sub, "")), cc.set_part.bind(sub, oid))
				sw.caption = str(o.get("name", oid))
				sw.caption_px = int(px.call(12))
	elif tab == "appearance":
		panel_note.text = "Visual size only: reach, speed and the hit box stay the same."
	var note_w := panel.size.x - (cell + gap if is_color else 0.0)
	panel_note.add_theme_font_size_override("font_size", px.call(12 if phone else 14))
	panel_note.position = Vector2(0, float(title_px) * 1.5)
	panel_note.size = Vector2(note_w, 0)
	if panel_note.text != "" and not is_color:
		top += panel_note.get_minimum_size().y + gap
	grid_scroll.position = Vector2(0, top)
	grid_scroll.size = Vector2(panel.size.x, next.position.y - top - gap * 2.0)
	if slider_box.visible:
		_layout_slider(px, phone, top)

## What a colour slot tints on this model (appearance.json "region"), and where it shows.
func _slot_note(slot: String) -> String:
	for s in CharacterLook.color_slots():
		if str(s.get("id", "")) == slot:
			return str(s.get("region", ""))
	return ""

func _swatch(cell: float, color: Color, chosen: bool, on_pick: Callable) -> CcUi.Hex:
	var h := CcUi.Hex.new(cell)
	h.fill = color
	h.selected = chosen
	h.check = chosen
	h.pressed.connect(on_pick)
	grid.add_child(h)
	return h

func _sub_name() -> String:
	for r in _subs():
		if r[0] == sub:
			return r[1]
	return ""

func _layout_slider(px: Callable, phone: bool, top: float) -> void:
	slider_box.position = Vector2(0, top)
	slider_box.size = Vector2(panel.size.x, next.position.y - top - float(px.call(12)))
	var w := float(px.call(56 if phone else 72))
	var fig := float(px.call(34 if phone else 52))
	slider.position = Vector2((slider_box.size.x - w) * 0.5, fig + float(px.call(6)))
	slider.size = Vector2(w, slider_box.size.y - 2.0 * (fig + float(px.call(6))))
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.3, 0.3, 0.3)
	track.content_margin_left = float(px.call(4))
	track.content_margin_right = float(px.call(4))
	var fill := StyleBoxFlat.new()
	fill.bg_color = CcUi.YELLOW
	fill.content_margin_left = float(px.call(4))
	fill.content_margin_right = float(px.call(4))
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob(int(px.call(26 if phone else 34)))
	for k in ["grabber", "grabber_highlight"]:
		slider.add_theme_icon_override(k, knob)
	slider.set_value_no_signal(float(cc.look["height"]))
	slider_value.add_theme_font_size_override("font_size", px.call(14 if phone else 18))
	slider_value.text = "%d%%" % roundi(float(cc.look["height"]) * 100.0)
	slider_value.position = Vector2(slider.position.x + w + float(px.call(10)), slider.position.y + slider.size.y * 0.5 - 10.0)
	slider_box.queue_redraw()

static func _knob(d: int) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := float(d) * 0.5
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(1, 1, 1, clampf(r - 1.0 - dist, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

## Small figure under the slider, tall figure over it (the reference's size icons).
func _draw_figures() -> void:
	var cx := slider_box.size.x * 0.5
	var top_h := slider.position.y - 6.0
	_figure(Vector2(cx, top_h), top_h * 0.95)
	_figure(Vector2(cx, slider_box.size.y), top_h * 0.62)

func _figure(feet: Vector2, h: float) -> void:
	var c := Color(0.8, 0.8, 0.8)
	var head := h * 0.14
	slider_box.draw_circle(feet - Vector2(0, h - head), head, c)
	slider_box.draw_rect(Rect2(feet.x - h * 0.11, feet.y - h + head * 2.2, h * 0.22, h * 0.42), c)
	slider_box.draw_rect(Rect2(feet.x - h * 0.1, feet.y - h * 0.46, h * 0.08, h * 0.46), c)
	slider_box.draw_rect(Rect2(feet.x + h * 0.02, feet.y - h * 0.46, h * 0.08, h * 0.46), c)

func _draw_portrait_box() -> void:
	var r := Rect2(Vector2.ZERO, portrait_box.size)
	var tex := PortraitService.shared().texture()
	if tex:
		portrait_box.draw_texture_rect(tex, r.grow(-6.0), false)
	else:
		portrait_box.draw_rect(r.grow(-6.0), Color.html(str(cc.look["portrait"]["bg"])))
	if tab == "portrait":
		CcUi.brackets(portrait_box, r, minf(20.0, r.size.x * 0.18))

func _draw_tab_row(b: Button, id: String) -> void:
	var r := Rect2(Vector2.ZERO, b.size)
	CcUi.dotted(b, Vector2(0, r.end.y - 1.0), Vector2(r.end.x, r.end.y - 1.0))
	if id == tab:
		b.draw_rect(Rect2(r.position, Vector2(4.0, r.size.y)), CcUi.YELLOW)

## The reference's round clothing toggle: a dark disc with a T-shirt outline, gold and dotted when worn.
func _draw_outfit(b: Button, kit: String) -> void:
	var s := b.size
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.5 - 2.0
	var worn := cc.stage != null and cc.stage.outfit == kit
	b.draw_circle(c, r, Color(0.16, 0.16, 0.16))
	if worn:
		var ring := PackedVector2Array()
		for i in 33:
			ring.append(c + Vector2.from_angle(TAU * float(i) / 32.0) * (r - 1.5))
		b.draw_polyline(ring, CcUi.GOLD, 2.0, true)
	var u := r * 0.42
	var shirt := PackedVector2Array([
		c + Vector2(-0.35, -0.8) * u, c + Vector2(-1.0, -0.45) * u, c + Vector2(-0.75, 0.0) * u,
		c + Vector2(-0.5, -0.12) * u, c + Vector2(-0.5, 0.85) * u, c + Vector2(0.5, 0.85) * u,
		c + Vector2(0.5, -0.12) * u, c + Vector2(0.75, 0.0) * u, c + Vector2(1.0, -0.45) * u,
		c + Vector2(0.35, -0.8) * u, c + Vector2(0.0, -0.55) * u, c + Vector2(-0.35, -0.8) * u])
	var ink := CcUi.GOLD if worn else Color(0.78, 0.78, 0.76)
	if kit == "":
		b.draw_polyline(shirt, ink, 2.0, true)
	else:
		b.draw_colored_polygon(shirt, ink.darkened(0.15))
		# One to three bands tell the kits apart (their order in appearance.json).
		var n := maxi(1, CharacterLook.preview_outfits().map(func (o: Dictionary) -> String: return str(o.get("id", ""))).find(kit))
		for i in n:
			var yy := c.y + u * (0.15 + 0.22 * float(i))
			b.draw_line(Vector2(c.x - 0.45 * u, yy), Vector2(c.x + 0.45 * u, yy), Color(0.16, 0.16, 0.16), 2.0)
	if b.has_focus():
		b.draw_arc(c, r + 1.0, 0.0, TAU, 32, Color.WHITE, 1.5, true)

## A die face (five pips), drawn: no emoji.
func _draw_die() -> void:
	var s := die.size
	var r := Rect2(s * 0.18, s * 0.64)
	die.draw_rect(r, Color(0.9, 0.9, 0.88))
	for p in [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]:
		die.draw_circle(r.position + r.size * p, r.size.x * 0.08, CcUi.INK)

## A pressed swatch rebuilds the panel it sits in: detach now, free after its signal returns.
static func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

static func _released(e: InputEvent) -> bool:
	return (e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not e.pressed and e.device != InputEvent.DEVICE_ID_EMULATION) or (e is InputEventScreenTouch and not e.pressed)
