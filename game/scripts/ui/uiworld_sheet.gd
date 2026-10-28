class_name UiWorldSheet
extends Control
## Shared full-screen sheet chrome for the UIWORLD screens (docs/design/ui-redesign-spec.md §8):
## a dark wash over the world, the HEADER bar with its torn bottom edge, "‹ Title" (back to the MENU),
## an optional right-hand counter (rich text, GOLD numbers) and the ✕ close. Subclasses build their
## panels under `body` and place them in `_layout_body(view, rect)`; `rect` is the free area under
## the header. Static helpers make the §8 parts: GOLD primary button, ghost button, panel and
## parchment styles, gold corner brackets.
## Used by DomainScreen (F1), CommsUI / RadioUniversityUI (F3) and TamingPenUI (E2).

signal back_pressed
signal close_pressed

const HEADER_DESKTOP := 88.0
const HEADER_COMPACT := 64.0  ## the back / close targets are the header's height: never under 64
const SIDE_DESKTOP := 32.0
const SIDE_COMPACT := 12.0

var backdrop: ColorRect
var header: Control
var back_btn: Button
var title_label: Label
var counter: RichTextLabel
var close_btn: Button
var body: Control

var _title_text := ""

func _init(p_title: String = "") -> void:
	_title_text = p_title

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 44
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(UiTokens.HEADER.lerp(UiTokens.SCREEN_DIM, 0.35), 0.96)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # the sheet owns the screen; taps never reach the world
	add_child(backdrop)
	body = Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	header = _Header.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(header)
	back_btn = flat_button("")
	back_btn.name = "Back"
	back_btn.icon = UiIcons.icon(&"back")
	back_btn.expand_icon = true
	back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.add_theme_constant_override("icon_max_width", 30)
	back_btn.pressed.connect(func () -> void: back_pressed.emit())
	header.add_child(back_btn)
	title_label = label(_title_text, 40, UiTokens.TEXT)
	title_label.name = "Title"
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title_label)
	counter = RichTextLabel.new()
	counter.name = "Counter"
	counter.bbcode_enabled = true
	counter.fit_content = true
	counter.scroll_active = false
	counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_theme_font_override("normal_font", UiTokens.ui_face())
	header.add_child(counter)
	close_btn = flat_button("✕")
	close_btn.name = "Close"
	close_btn.pressed.connect(func () -> void: close_pressed.emit())
	header.add_child(close_btn)
	_build()
	resized.connect(relayout)
	get_viewport().size_changed.connect(relayout)
	relayout()

## Subclasses add their panels to `body` here.
func _build() -> void:
	pass

## Subclasses place their panels inside `rect` (screen space, under the header).
func _layout_body(_view: Vector2, _rect: Rect2) -> void:
	pass

static func header_h(view: Vector2) -> float:
	return HEADER_COMPACT if UiTokens.is_compact(view) else HEADER_DESKTOP

static func side_pad(view: Vector2) -> float:
	return SIDE_COMPACT if UiTokens.is_compact(view) else SIDE_DESKTOP

## GOLD-numbered counter text, e.g. counter_text(["Active missions ", 1, " / 4"]).
func set_counter(bb: String) -> void:
	counter.text = bb
	relayout()

func relayout() -> void:
	if body == null:
		return
	var view := get_viewport_rect().size
	backdrop.position = Vector2.ZERO
	backdrop.size = view
	var compact := UiTokens.is_compact(view)
	var hh := header_h(view)
	var side := side_pad(view)
	header.position = Vector2.ZERO
	header.size = Vector2(view.x, hh)
	var btn := hh
	back_btn.size = Vector2(btn, btn)
	back_btn.position = Vector2(maxf(0.0, side - 20.0), 0.0)
	back_btn.add_theme_constant_override("icon_max_width", 24 if compact else 30)
	close_btn.size = Vector2(btn, btn)
	close_btn.position = Vector2(view.x - btn - maxf(0.0, side - 20.0), 0.0)
	close_btn.add_theme_font_size_override("font_size", 28 if compact else 36)
	title_label.add_theme_font_size_override("font_size", 26 if compact else 40)
	title_label.position = Vector2(back_btn.position.x + btn - 6.0, 0.0)
	title_label.size = Vector2(view.x * 0.45, hh)
	var cpx := 15 if compact else 20
	counter.add_theme_font_size_override("normal_font_size", cpx)
	var cw := minf(view.x * 0.5, 620.0)
	counter.size = Vector2(cw, 0.0)
	counter.reset_size()
	var cs := counter.get_content_height()
	counter.size = Vector2(cw, cs)
	counter.position = Vector2(close_btn.position.x - cw - 12.0, (hh - cs) * 0.5)
	var top := hh + (8.0 if compact else 24.0)
	var rect := Rect2(side, top, view.x - side * 2.0, view.y - top - (8.0 if compact else 32.0))
	body.position = Vector2.ZERO
	body.size = view
	_layout_body(view, rect)
	header.queue_redraw()
	if not _settling:
		_settle()

var _settling := false

## Containers grow to their children's minimum size, and an autowrapped label's first minimum is
## measured at its pre-layout width (one word a line: thousands of px). One more pass a frame later,
## once the labels know their real width, puts every panel back at the size this layout gives it.
func _settle() -> void:
	_settling = true
	await get_tree().process_frame
	if is_inside_tree():
		relayout()
	_settling = false

# ---------------------------------------------------------------- parts

## The header bar: HEADER fill with the torn edge hanging under it.
class _Header extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTokens.HEADER)
		UiTokens.draw_torn_edge(self, Rect2(0.0, size.y - 1.0, size.x, UiTokens.TORN_MAX + 1.0))

## Four GOLD corner brackets over the parent's rect (selection marker, §8). Add as a child.
class Brackets extends Control:
	var arm := UiTokens.BRACKET_ARM
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		UiTokens.draw_brackets(self, Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0), UiTokens.GOLD, arm, UiTokens.BRACKET_W)

static func label(text: String, px: int, color: Color, bold: bool = false, italic: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	var f: Font = UiTokens.ui_face(UiTokens.WEIGHT_BOLD if bold else UiTokens.WEIGHT_REGULAR)
	if italic and f is FontVariation:
		var it := (f as FontVariation).duplicate() as FontVariation
		it.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.2, 1.0), Vector2.ZERO)
		f = it
	l.add_theme_font_override("font", f)
	return l

static func flat_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UiTokens.GOLD
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_color_override("font_color", UiTokens.TEXT)
	b.add_theme_color_override("font_hover_color", UiTokens.GOLD)
	b.add_theme_font_override("font", UiTokens.ui_face())
	return b

static func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

## The §8 primary action: GOLD fill, CTA_INK text, square corners.
static func gold_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.add_theme_stylebox_override("normal", _box(UiTokens.GOLD, UiTokens.GOLD, 0))
	b.add_theme_stylebox_override("hover", _box(UiTokens.GOLD.lightened(0.12), UiTokens.GOLD, 0))
	b.add_theme_stylebox_override("pressed", _box(UiTokens.GOLD.darkened(0.15), UiTokens.GOLD, 0))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), UiTokens.TEXT, 2))
	b.add_theme_stylebox_override("disabled", _box(Color(UiTokens.GOLD, 0.25), Color(UiTokens.GOLD, 0.3), 1))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, UiTokens.CTA_INK)
	b.add_theme_color_override("font_disabled_color", Color(UiTokens.TEXT, 0.45))
	b.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD))
	return b

## A secondary action: near-black fill, thin light border. `danger` draws the border and text in LIFE.
static func ghost_button(text: String, danger: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	var ink := UiTokens.LIFE if danger else UiTokens.TEXT
	var edge := UiTokens.LIFE if danger else Color(UiTokens.HUD_RIM, 0.55)
	b.add_theme_stylebox_override("normal", _box(Color(0.03, 0.035, 0.04, 0.92), edge, 1))
	b.add_theme_stylebox_override("hover", _box(Color(0.08, 0.09, 0.10, 0.95), UiTokens.GOLD, 1))
	b.add_theme_stylebox_override("pressed", _box(UiTokens.GOLD_DIM, UiTokens.GOLD, 2))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), UiTokens.GOLD, 2))
	b.add_theme_stylebox_override("disabled", _box(Color(0.03, 0.035, 0.04, 0.6), Color(UiTokens.MUTED, 0.3), 1))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color(UiTokens.MUTED, 0.6))
	b.add_theme_font_override("font", UiTokens.ui_face())
	return b

## A sheet panel (§8): PANEL fill, 1 px light divider.
static func panel_style(fill: Color = UiTokens.PANEL) -> StyleBoxFlat:
	var sb := _box(fill, Color(1, 1, 1, 0.07), 1)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb

## The parchment header of a detail panel.
static func parchment_style() -> StyleBoxTexture:
	var g := Gradient.new()
	g.set_color(0, UiTokens.PARCHMENT_TOP)
	g.set_color(1, UiTokens.PARCHMENT_BOTTOM)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func panel(fill: Color = UiTokens.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(fill))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## A white action icon (ui_icons.json) as a fixed-size TextureRect.
static func icon_rect(id: StringName, px: float, tint: Color = UiTokens.TEXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiIcons.icon(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Every visible Button under `root` (gates: tap size, in-view, overlap).
static func buttons_in(root: Node) -> Array[Button]:
	var out: Array[Button] = []
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree():
			out.append(b)
	return out

## Smallest side of any visible button (the tap-target gate).
func min_target_px() -> float:
	var lo := INF
	for b in buttons_in(self):
		var r := b.get_global_rect()
		lo = minf(lo, minf(r.size.x, r.size.y))
	return lo if lo < INF else 0.0
