class_name IslandPick
extends CanvasLayer
## ISLANDPICK / spec 29 section 4: the permanent Tamed Island choice at character creation.
## Five shapes (data/world/island_shapes.json), one top-down preview each, and the reference's
## "Terrain selection is final." warning (docs/reference/durango-domain-tamed-island-select.webp).
## Replaces the old five-button terrain sheet: the pick sets both the home island's landmass seed
## and its scatter terrain, and World.pick_shape refuses a second pick.
##
## The previews are drawn from the real generator's analytic coastline and heightmap at preview
## resolution (IslandShape.make + _fill_heightmap at res 81), not a hard-coded picture, so a shape
## added to the json gets a correct map. `preview_count` is what the lab reports.

signal picked(shape_id: StringName)

const TARGET := 64.0  ## spec: every tap target is at least this many logical px
const GOLD := Color(1.0, 0.82, 0.36)
const WARN := Color(1.0, 0.72, 0.38)
const PREVIEW_RES := 81
const PREVIEW_PX := 160

static var _i: IslandPick

static func instance_on(host: Node) -> IslandPick:
	if _i and is_instance_valid(_i):
		return _i
	_i = (load("res://scripts/ui/island_pick.gd") as GDScript).new()
	_i.name = "IslandPick"
	host.add_child(_i)
	return _i

var _selected: StringName = &""
## One confirm per screen: a second tap while the first pick is being built (the island takes
## about a second) must not load and save a second world.
var _confirmed := false
var _cards: Dictionary = {}
var _start: Button
var _check: TextureRect
var _warning: Label
var _previews: Dictionary = {}  ## shape id -> ImageTexture, built once
var _k := 1.0

## Canvas px per fitted px, exactly as character_creation decides it: before DisplayMode's boot
## hook lands, an unfitted 844x390 window would otherwise draw the desktop sheet at 0.43 scale.
static func scale_for(view: Vector2, fitted: Vector2) -> float:
	if fitted.x > 0.0 and fitted.y > 0.0:
		return minf(view.x / fitted.x, view.y / fitted.y)
	return 1.0

func _px(v: float) -> int:
	return roundi(v * _k)

## A top-down map of one shape: sea, beach, land tinted by climate and shaded by height, with the
## same coastline the game builds. Never cached across seeds outside this instance.
static func preview_texture(shape: Dictionary) -> ImageTexture:
	var size := 416.0
	var sh = IslandShape.make(size, int(shape.get("seed", 17)), "private", 10, Vector2.ZERO, true, PREVIEW_RES, "grassland")
	sh.compute()
	var img := Image.create(PREVIEW_PX, PREVIEW_PX, false, Image.FORMAT_RGBA8)
	var tint := Color(str(shape.get("accent", "#6f8f4f")))
	var centre := Vector2(sh.centre.x, sh.centre.y)
	# The land's own box, so every preview fills its card however the shape sits in its square.
	var box := Rect2()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for z in sh.res:
		for x in sh.res:
			if sh.heights[x + z * sh.res] > -0.05:
				var p := Vector2(-size * 0.5 + float(x) * size / float(sh.res - 1), -size * 0.5 + float(z) * size / float(sh.res - 1))
				lo = lo.min(p)
				hi = hi.max(p)
	if lo.x == INF:
		lo = centre - Vector2.ONE * 10.0
		hi = centre + Vector2.ONE * 10.0
	box = Rect2(lo, hi - lo).grow(12.0)
	for py in PREVIEW_PX:
		for px in PREVIEW_PX:
			var u := (float(px) + 0.5) / float(PREVIEW_PX)
			var v := (float(py) + 0.5) / float(PREVIEW_PX)
			var wx := box.position.x + u * box.size.x
			var wz := box.position.y + v * box.size.y
			var h: float = sh.sample_height(wx, wz)
			var c: Color
			if h < -0.6:
				c = Color(0.10, 0.22, 0.32)
			elif h < -0.05:
				c = Color(0.16, 0.38, 0.50)
			elif h < 0.45:
				c = Color(0.78, 0.72, 0.55)  # beach
			else:
				var light := clampf(0.72 + h * 0.055, 0.55, 1.30)
				c = Color(tint.r * light, tint.g * light, tint.b * light)
				var river: float = sh.river_dist(wx, wz)
				if river < float(sh.river_half_width(wx, wz)) * 0.75 and h < 0.5:
					c = Color(0.20, 0.44, 0.58)
			img.set_pixel(px, py, c)
	return ImageTexture.create_from_image(img)

## Shows the layer (it may have been built before the pick step was reached).
func open() -> void:
	visible = true
	_i = self
	# WorldUI re-opens the old terrain sheet whenever creation is pending and no creation layer is
	# up; the pick is that layer now, so it stands in for character creation while it is open.
	if not is_in_group(&"character_creation"):
		add_to_group(&"character_creation")
	if _cards.is_empty():
		_build()

func _ready() -> void:
	layer = 62  # over character creation (60); HANDS hides while creation is up
	_i = self
	add_to_group(&"island_pick")
	visible = false  # open() shows it when character creation reaches the pick
	_build()

func _build() -> void:
	var lay := CharacterCreation.layout_for(get_viewport().get_visible_rect().size, DisplayMode.fitted_size(get_window()))
	_k = float(lay["k"])
	var short: bool = lay["short"]
	var phone: bool = lay["phone"]
	var root := Control.new()
	root.name = "IslandPickRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.035, 0.045, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var edge := _px(8 if short else 20)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, edge)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _px(4 if short else 10))
	margin.add_child(box)
	var title := Label.new()
	title.text = "GET YOUR OWN TAMED ISLAND!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _px(20 if phone else 30))
	title.add_theme_color_override("font_color", GOLD)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Select the desired terrain of your Tamed Island."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", _px(14 if short else 17))
	sub.add_theme_color_override("font_color", Color(0.82, 0.84, 0.82))
	box.add_child(sub)
	var row := HBoxContainer.new()
	row.name = "ShapeCards"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", _px(8))
	row.add_theme_constant_override("v_separation", _px(6))
	# Cards centred in the space between the subtitle and the footer (at 1600x900 the block used
	# to sit at the top with half the screen empty).
	var mid := CenterContainer.new()
	mid.name = "CardCentre"
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(row)
	box.add_child(mid)
	for shape in World.home_shapes:
		var id := str(shape.get("id", ""))
		if id == "":
			continue
		var card := _card(shape, short)
		row.add_child(card)
		_cards[id] = card
	# The reference's bottom bar: warning triangle + "Terrain selection is final.", and the
	# confirm button on the right (stacks on a narrow phone).
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("h_separation", _px(14))
	var foot_centre := CenterContainer.new()
	foot_centre.name = "FooterCentre"
	foot_centre.add_child(footer)
	box.add_child(foot_centre)
	_warning = Label.new()
	_warning.name = "FinalWarning"
	_warning.text = "!  Terrain selection is final."
	_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_warning.add_theme_font_size_override("font_size", _px(14 if short else 16))
	_warning.add_theme_color_override("font_color", WARN)
	footer.add_child(_warning)
	_start = Button.new()
	_start.name = "SelectAndMove"
	_start.text = "SELECT AND MOVE"
	_start.disabled = true
	_start.custom_minimum_size = Vector2(_px(240 if phone else 300), _px(64))
	_start.add_theme_font_size_override("font_size", _px(18 if short else 20))
	_start.pressed.connect(_confirm)
	footer.add_child(_start)
	if not _cards.is_empty():
		_select(str(_cards.keys()[0]))
	UiTokens.focus_first(_cards.values())

func _card(shape: Dictionary, short: bool) -> Button:
	var id := str(shape.get("id", ""))
	var card := Button.new()
	card.name = "Shape_%s" % id
	card.toggle_mode = true
	# Square-ish cards: the map fills the width and the text sits under it (a stretched card left
	# wide empty bands above and below each preview at 1600x900).
	card.custom_minimum_size = Vector2(_px(126 if short else 196), _px(150 if short else 340))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_font_size_override("font_size", _px(15))
	# Two anchored blocks, not a VBox: the map fills the card above a fixed-height text block, so
	# every card's title and blurb sit on one line however long the blurb is (a VBox let a wrapped
	# blurb push its own title down and clipped the neighbour's).
	var text_h := _px(52 if short else 92)
	var tex := preview_texture(shape)
	_previews[id] = tex
	var prev := TextureRect.new()
	prev.name = "Preview"
	prev.texture = tex
	prev.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prev.offset_left = _px(4)
	prev.offset_right = -_px(4)
	prev.offset_top = _px(4)
	prev.offset_bottom = -(text_h + _px(4))
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev.custom_minimum_size = Vector2(_px(96 if short else 120), _px(60 if short else 150))
	prev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(prev)
	var text_block := VBoxContainer.new()
	text_block.name = "Text"
	text_block.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	text_block.offset_left = _px(4)
	text_block.offset_right = -_px(4)
	text_block.offset_top = -(text_h + _px(2))
	text_block.offset_bottom = -_px(6)
	text_block.add_theme_constant_override("separation", 0)
	text_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(text_block)
	var name_l := Label.new()
	name_l.text = str(shape.get("display_name", id))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", _px(14 if short else 16))
	name_l.add_theme_color_override("font_color", UiTokens.TEXT)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_block.add_child(name_l)
	var blurb := Label.new()
	blurb.text = str(shape.get("blurb", ""))
	# A landscape phone card is 390 px tall in total: the name (and the SELECTED tick) fit, a
	# wrapped blurb did not and drew over the footer.
	blurb.visible = not short
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(0, _px(36))
	blurb.add_theme_font_size_override("font_size", _px(12 if short else 13))
	blurb.add_theme_color_override("font_color", UiTokens.META)
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_block.add_child(blurb)
	var tick := Label.new()
	tick.name = "Tick"
	tick.text = "SELECTED"
	tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tick.add_theme_font_size_override("font_size", _px(12 if short else 13))
	tick.add_theme_color_override("font_color", GOLD)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The tick overlays the blurb's tail on tiny cards; short and desktop both have room for it
	# under the title, above the blurb start.
	tick.size_flags_vertical = Control.SIZE_SHRINK_END
	text_block.add_child(tick)
	card.pressed.connect(func () -> void: _select(id))
	return card

## Selected card: the reference's warm frame, a gold tick and, on desktop, a check badge.
func _select(id: String) -> void:
	_selected = StringName(id)
	for key in _cards:
		var card: Button = _cards[key]
		card.button_pressed = key == id
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.09, 0.12, 0.13, 0.96) if key != id else Color(0.13, 0.18, 0.17, 0.98)
		normal.set_corner_radius_all(_px(10))
		normal.set_border_width_all(_px(3) if key == id else _px(1))
		normal.border_color = GOLD if key == id else Color(0.35, 0.40, 0.38, 0.7)
		card.add_theme_stylebox_override("normal", normal)
		card.add_theme_stylebox_override("hover", normal)
		card.add_theme_stylebox_override("pressed", normal)
		var tick := card.find_child("Tick", true, false) as Label
		if tick:
			tick.visible = key == id
	_start.disabled = false

func _confirm() -> void:
	if _selected == &"" or _confirmed:
		return
	_confirmed = true
	# Dead while the world builds the island: a double tap lands on a disabled button.
	_set_targets_enabled(false)
	picked.emit(_selected)
	# The world builds the island synchronously and calls close() on success; on a refused pick it
	# calls failed() and the screen comes back live.

## The world refused the pick: stay up, let the player choose again.
func failed() -> void:
	_confirmed = false
	_set_targets_enabled(true)

func _set_targets_enabled(on: bool) -> void:
	if _start:
		_start.disabled = not on
	for key in _cards:
		(_cards[key] as Button).disabled = not on

## The pick landed: nothing more to do on this screen.
func close() -> void:
	remove_from_group(&"character_creation")
	queue_free()

func is_confirmed() -> bool:
	return _confirmed

## What the lab measures: the five previews actually shown, the warning text on screen, and the
## smallest tap target (logical px) the layout drew.
func preview_count() -> int:
	var n := 0
	for key in _cards:
		var prev := (_cards[key] as Button).find_child("Preview", true, false) as TextureRect
		if prev and prev.texture != null and prev.is_visible_in_tree():
			n += 1
	return n

func warning_visible() -> bool:
	return _warning != null and _warning.is_visible_in_tree() and _warning.text.contains("final")

func min_target_px() -> float:
	var lo := INF
	for key in _cards:
		var r := (_cards[key] as Control).get_global_rect()
		lo = minf(lo, minf(r.size.x, r.size.y))
	if _start:
		var sr := _start.get_global_rect()
		lo = minf(lo, minf(sr.size.x, sr.size.y))
	return 0.0 if lo == INF else lo

func selected_id() -> StringName:
	return _selected
