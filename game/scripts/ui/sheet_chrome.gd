class_name SheetChrome
extends Control
## Shared full-screen sheet chrome (docs/design/ui-redesign-spec.md §8): the blurred, dimmed world
## behind, the HEADER bar with its torn bottom edge, "‹ Title" (back to the MENU), optional tabs, a
## right-hand counter and the ✕ close. The Animals screen and the Harbour sheet draw it; the World
## Atlas uses its backdrop, buttons and cards only (its title sits in the left panel, §7 F2).
## Children are plain Controls laid out by the owning screen through `layout(view)`.

signal back_pressed
signal close_pressed

const HEADER_PHONE := 64.0  # one 64 px tap target tall
const SIDE := 32.0
const SIDE_PHONE := 16.0

## Screen-space blur of whatever is drawn behind, then the SCREEN_DIM wash. Mipmap LOD 3 is a soft
## blur on every renderer, no extra pass.
const BLUR_SHADER := "shader_type canvas_item;\nuniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;\nuniform vec4 dim : source_color;\nvoid fragment() {\n\tvec3 c = textureLod(screen_tex, SCREEN_UV, 3.0).rgb;\n\tCOLOR = vec4(mix(c * 0.55, dim.rgb, dim.a), 1.0);\n}\n"

var back: Button
var title: Label
var tabs: HBoxContainer
var counter: Label
var close: Button
var header_h := 88.0

static var _blur: Shader
static var _theme: Theme

## Roboto Condensed (§11) as the default face for everything under a sheet root.
static func ui_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = UiTokens.ui_face()
	return _theme

## A heavier cut of the UI face for titles and names.
static func strong(l: Control, weight: int = 600) -> void:
	l.add_theme_font_override("font", UiTokens.ui_face(weight))

## A full-rect backdrop: the blurred world under SCREEN_DIM. It stops clicks reaching the world.
static func backdrop() -> ColorRect:
	var r := ColorRect.new()
	r.name = "Backdrop"
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.color = Color(0.04, 0.07, 0.09, 1.0)
	if _blur == null:
		_blur = Shader.new()
		_blur.code = BLUR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _blur
	mat.set_shader_parameter("dim", Color(UiTokens.SCREEN_DIM, 0.72))
	r.material = mat
	return r

func _init(p_title: String = "") -> void:
	name = "SheetChrome"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = icon_button(&"back")
	back.name = "Back"
	back.pressed.connect(func () -> void: back_pressed.emit())
	add_child(back)
	title = Label.new()
	title.name = "Title"
	title.text = p_title
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strong(title, 500)
	add_child(title)
	tabs = HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 0)
	add_child(tabs)
	counter = Label.new()
	counter.name = "Counter"
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	counter.add_theme_color_override("font_color", UiTokens.TEXT)
	add_child(counter)
	close = icon_button(&"close")
	close.name = "Close"
	close.pressed.connect(func () -> void: close_pressed.emit())
	add_child(close)

## Height of the header band (without the torn edge) at `view`.
static func header_for(view: Vector2) -> float:
	return HEADER_PHONE if UiTokens.is_compact(view) else UiTokens.HEADER_H

static func side_for(view: Vector2) -> float:
	return SIDE_PHONE if UiTokens.is_compact(view) else SIDE

## Places the header's parts across `view`; the owner lays out the body under body_top(view).
func layout(view: Vector2) -> void:
	header_h = header_for(view)
	position = Vector2.ZERO
	size = Vector2(view.x, header_h + UiTokens.TORN_MAX)
	var compact := UiTokens.is_compact(view)
	var side := side_for(view)
	var tap := 64.0
	var top := (header_h - tap) * 0.5
	back.position = Vector2(maxf(0.0, side - 12.0), maxf(0.0, top - 4.0))
	back.size = Vector2(tap, tap)
	back.add_theme_constant_override("icon_max_width", 22 if compact else 28)
	var title_px := 26 if compact else 40
	title.add_theme_font_size_override("font_size", title_px)
	title.position = Vector2(back.position.x + back.size.x - 8.0, 0.0)
	var title_w := UiTokens.ui_face(500).get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x + 8.0
	title.size = Vector2(title_w, header_h)
	close.position = Vector2(view.x - side - tap + 12.0, top)
	close.size = Vector2(tap, tap)
	close.add_theme_constant_override("icon_max_width", 24 if compact else 32)
	var counter_w := minf(380.0, view.x * 0.32)
	counter.position = Vector2(close.position.x - counter_w - UiTokens.SPACE, 0.0)
	counter.size = Vector2(counter_w, header_h)
	counter.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if compact else 4))
	tabs.position = Vector2(title.position.x + title_w + (16.0 if compact else 48.0), 0.0)
	tabs.size = Vector2(maxf(0.0, counter.position.x - tabs.position.x - UiTokens.SPACE), header_h)
	for t in tabs.get_children():
		var b := t as Button
		if b:
			b.custom_minimum_size = Vector2(0.0, header_h)
			b.add_theme_font_size_override("font_size", 16 if compact else 22)
	queue_redraw()

## ‹ on a sheet: reopen the MENU (§8). ASSUMPTION: B3's nav menu is being rebuilt in parallel; this
## asks the HUD for `open_menu()` when it has one, else toggles today's MENU sheet.
static func back_to_menu(tree: SceneTree) -> void:
	var hud := tree.get_first_node_in_group("hud") if tree else null
	if hud == null:
		return
	if hud.has_method("open_menu"):
		hud.call("open_menu")
	elif hud.has_method("_toggle_sheet"):
		hud.call("_toggle_sheet", &"menu")

static func body_top(view: Vector2) -> float:
	return header_for(view) + UiTokens.TORN_MAX + (8.0 if UiTokens.is_compact(view) else 20.0)

## A header tab ("Pack", "Taming Pen"): GOLD text and underline when active.
func add_tab(text: String, active: bool, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta("active", active)
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, _tab_style(active))
	var ink := UiTokens.GOLD if active else (UiTokens.TEXT if enabled else UiTokens.MUTED)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, ink)
	tabs.add_child(b)
	return b

static func _tab_style(active: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UiTokens.GOLD
	sb.border_width_bottom = 3 if active else 0
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	return sb

func _draw() -> void:
	var band := Rect2(Vector2.ZERO, Vector2(size.x, header_h))
	draw_rect(band, UiTokens.HEADER)
	UiTokens.draw_torn_edge(self, Rect2(Vector2(0.0, header_h - 1.0), Vector2(size.x, UiTokens.TORN_MAX + 1.0)))
	# A hairline between the counter and ✕ (the canvas's separator).
	var x := close.position.x - 6.0
	draw_line(Vector2(x, header_h * 0.3), Vector2(x, header_h * 0.7), Color(UiTokens.HUD_RIM, 0.25), 1.0)

# ---------------------------------------------------------------- shared widgets

## A transparent tap target with white ink (‹, ✕, zoom ±).
static func flat_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, UiTokens.TEXT)
	return b

## A transparent 64 px tap target showing a white UI icon (ui_icons.json: back, close).
static func icon_button(id: StringName) -> Button:
	var b := flat_button("")
	b.name = str(id).capitalize()
	b.icon = UiIcons.icon(id)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.tooltip_text = str(id).capitalize()
	return b

## kind: &"cta" (GOLD fill, CTA_INK), &"ghost" (dark with a light 1 px edge), &"danger" (LIFE outline).
static func action_button(text: String, kind: StringName = &"ghost") -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(0, 64)
	b.focus_mode = Control.FOCUS_ALL
	var ink := UiTokens.CTA_INK if kind == &"cta" else (UiTokens.LIFE if kind == &"danger" else UiTokens.TEXT)
	b.add_theme_stylebox_override("normal", action_style(kind, false))
	b.add_theme_stylebox_override("hover", action_style(kind, false, 0.08))
	b.add_theme_stylebox_override("pressed", action_style(kind, false, -0.1))
	b.add_theme_stylebox_override("focus", action_style(kind, true))
	b.add_theme_stylebox_override("disabled", action_style(&"ghost", false))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", UiTokens.MUTED)
	return b

static func action_style(kind: StringName, focus: bool, shade: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match kind:
		&"cta":
			sb.bg_color = UiTokens.GOLD.lightened(shade) if shade >= 0.0 else UiTokens.GOLD.darkened(-shade)
			sb.border_color = UiTokens.GOLD.lightened(0.3)
		&"danger":
			sb.bg_color = Color(UiTokens.LIFE, 0.06 + maxf(0.0, shade))
			sb.border_color = UiTokens.LIFE
		_:
			sb.bg_color = Color(0.02, 0.025, 0.03, 0.9 + shade)
			sb.border_color = Color(UiTokens.HUD_RIM, 0.35)
	sb.set_border_width_all(1)
	if focus:
		sb.border_color = UiTokens.GOLD if kind != &"cta" else UiTokens.TEXT
		sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb

## A sheet panel (§8): PANEL fill, a 1 px light divider, square corners.
static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.PANEL
	sb.border_color = Color(UiTokens.HUD_RIM, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	return sb

## A panel's section header band ("Pack slots", "Stats", "Needs").
static func section_label(text: String, view: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.name = "Section"
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.28)
	sb.content_margin_left = 18 if not UiTokens.is_compact(view) else 10
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_font_size_override("font_size", UiTokens.body(view) + (0 if UiTokens.is_compact(view) else 3))
	l.add_theme_color_override("font_color", UiTokens.TEXT)
	l.custom_minimum_size = Vector2(0, 32 if UiTokens.is_compact(view) else 46)
	return l

## A small label with colour and size.
static func text(t: String, px: int, color: Color = UiTokens.TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", color)
	return l

## A trait chip (§5) as a Label: "Pack hunter". Polarity picks the colours; no prefix for neutral tags.
static func chip(t: String, polarity: StringName = &"negative", px: int = 13) -> Label:
	var l := text(t, px, UiTokens.trait_chip_fg(polarity))
	var sb := UiTokens.trait_chip_style(polarity)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	l.clip_text = false
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING  # a trimming label's min width is 0
	return l


## A selectable list card: a Button whose own text is empty; the owner adds labels inside (mouse
## ignored). Selected = GOLD_DIM wash + four GOLD corner brackets (§8). Unselected = a hairline below.
class Card extends Button:
	var selected := false:
		set(v):
			selected = v
			queue_redraw()

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_contents = true
		var clear := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(s, clear)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if selected:
			draw_rect(r, UiTokens.GOLD_DIM)
			UiTokens.draw_brackets(self, r.grow(-UiTokens.BRACKET_W * 0.5 - 2.0))
		elif is_hovered() or has_focus():
			draw_rect(r, Color(1, 1, 1, 0.04))
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Color(UiTokens.HUD_RIM, 0.1), 1.0)
