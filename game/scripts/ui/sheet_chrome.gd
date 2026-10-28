class_name SheetChrome
extends Control
## THE shared full-screen sheet chrome (docs/design/ui-redesign-spec.md §8). Every full-screen sheet
## draws its header and §8 parts from here so they match pixel for pixel: the blurred, dimmed world
## behind; the HEADER bar (88 px desktop, 64 px phone) with its torn bottom edge; a thin ‹ (back to
## the MENU) and ✕ (back to the HUD); the title; header tabs (GOLD text + underline when active); a
## right-hand slot and counter; PANEL boxes; the parchment header; the full-width GOLD button with
## CTA_INK text; GOLD corner brackets for selection.
##
## Three ways in, one look:
## - an instance as the header (`SheetChrome.new("Animals")`, then `layout(view, safe)`);
## - `build(host, title)` / `fit(parts, view, safe)` for sheets that want a {header, back, …, body}
##   dictionary (Character, Skills, Orders);
## - `UiWorldSheet`, a base class on top of this with the open/relayout lifecycle (Domain, Comms, …).
## Static helpers make the parts; screens never restyle the chrome themselves.

signal back_pressed
signal close_pressed

const TAP := 64.0  # every chrome tap target
const HEADER_PHONE := 64.0  # one 64 px tap target tall
const SIDE := 32.0
const SIDE_PHONE := 16.0

## Screen-space blur of whatever is drawn behind, then the SCREEN_DIM wash. Mipmap LOD 3 is a soft
## blur on every renderer, no extra pass.
const BLUR_SHADER := "shader_type canvas_item;\nuniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;\nuniform vec4 dim : source_color;\nvoid fragment() {\n\tvec3 c = textureLod(screen_tex, SCREEN_UV, 3.0).rgb;\n\tCOLOR = vec4(mix(c * 0.55, dim.rgb, dim.a), 1.0);\n}\n"

var back: Button
var title: Label
var tabs: HBoxContainer
## Free slot left of the counter (SP pill, presets, a rich counter); grows leftwards with its content.
var right: HBoxContainer
var counter: Label
var close: Button
var header_h := 88.0
var top_inset := 0.0

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
	MenuTransition.follow(r, MenuTransition.SHEET_STRENGTH)  # NAVZOOM, lighter under a full-screen sheet
	return r

func _init(p_title: String = "") -> void:
	name = "SheetChrome"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back = Glyph.new(&"back")
	back.name = "Back"
	back.pressed.connect(func () -> void: back_pressed.emit())
	add_child(back)
	title = Label.new()
	title.name = "Title"
	title.text = p_title
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_color", UiTokens.TEXT)
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
	right = HBoxContainer.new()
	right.name = "Right"
	right.add_theme_constant_override("separation", 12)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	close = Glyph.new(&"close")
	close.name = "Close"
	close.pressed.connect(func () -> void: close_pressed.emit())
	add_child(close)
	for c: Control in [counter, right]:  # right-anchored: they grow leftwards when their text changes
		c.anchor_left = 1.0
		c.anchor_right = 1.0
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN

## Height of the header band (without the torn edge) at `view`.
static func header_for(view: Vector2) -> float:
	return HEADER_PHONE if UiTokens.is_compact(view) else UiTokens.HEADER_H

static func side_for(view: Vector2) -> float:
	return SIDE_PHONE if UiTokens.is_compact(view) else SIDE

static func compact(view: Vector2) -> bool:
	return UiTokens.is_compact(view)

## `desk` px on a desktop, `phone` px on a landscape phone.
static func px(view: Vector2, desk: int, phone: int) -> int:
	return phone if UiTokens.is_compact(view) else desk

## Counter / header-pill type size.
static func counter_px(view: Vector2) -> int:
	return UiTokens.body(view) + (0 if UiTokens.is_compact(view) else 4)

## Places the header's parts across `view` (safe = right, bottom, top, left insets); the owner lays
## out the body under body_top(view).
func layout(view: Vector2, safe: Vector4 = Vector4.ZERO) -> void:
	header_h = header_for(view)
	top_inset = safe.z
	position = Vector2.ZERO
	size = Vector2(view.x, top_inset + header_h)  # the torn edge hangs below the rect
	var c := compact(view)
	var side := side_for(view)
	var y := top_inset + (header_h - TAP) * 0.5
	back.position = Vector2(safe.w + maxf(0.0, side - 12.0), y)
	back.size = Vector2(TAP, TAP)
	close.position = Vector2(view.x - safe.x - side - TAP + 12.0, y)
	close.size = Vector2(TAP, TAP)
	right.custom_minimum_size.y = header_h
	right.offset_top = top_inset
	right.offset_bottom = top_inset + header_h
	right.offset_right = close.position.x - UiTokens.SPACE * 2.0 - view.x  # the hairline sits in this gap
	right.offset_left = right.offset_right - right.get_combined_minimum_size().x
	var right_l := view.x + right.offset_left - (UiTokens.SPACE * 2.0 if right.offset_right > right.offset_left else 0.0)
	for g: Glyph in [back, close]:
		g.small = c
	var cpx := counter_px(view)
	counter.add_theme_font_size_override("font_size", cpx)
	counter.offset_top = top_inset
	counter.offset_bottom = top_inset + header_h
	counter.offset_right = right_l - view.x
	var cw := UiTokens.ui_face().get_string_size(counter.text, HORIZONTAL_ALIGNMENT_LEFT, -1, cpx).x + 4.0 if counter.text != "" else 0.0
	counter.offset_left = counter.offset_right - cw
	var title_px := 26 if c else 40
	title.add_theme_font_size_override("font_size", title_px)
	title.position = Vector2(back.position.x + back.size.x - 8.0, top_inset)
	var room := right_l - cw - UiTokens.SPACE - title.position.x
	var title_w := minf(UiTokens.ui_face(500).get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_px).x + 8.0, maxf(0.0, room))
	title.size = Vector2(title_w, header_h)
	tabs.position = Vector2(title.position.x + title_w + (16.0 if c else 48.0), top_inset)
	tabs.size = Vector2(maxf(0.0, right_l - cw - UiTokens.SPACE - tabs.position.x), header_h)
	for t in tabs.get_children():
		var b := t as Button
		if b:
			b.custom_minimum_size = Vector2(TAP, header_h)
			b.add_theme_font_size_override("font_size", 16 if c else 22)
			tab_style(b, bool(b.get_meta("active", false)), c)
	queue_redraw()

## ‹ on a sheet: reopen the MENU (§8). Asks the HUD for `open_menu()` when it has one, else toggles
## the MENU sheet.
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
func add_tab(t: String, active: bool, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL
	tab_style(b, active)
	tabs.add_child(b)
	return b

## Styles `b` as a header tab, on (GOLD text + 3 px GOLD underline) or off. layout() reapplies it.
static func tab_style(b: Button, active: bool, is_compact: bool = false) -> void:
	b.set_meta("active", active)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UiTokens.GOLD
	sb.border_width_bottom = 3 if active else 0
	sb.content_margin_left = 10 if is_compact else 26
	sb.content_margin_right = sb.content_margin_left
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	var ink := UiTokens.GOLD if active else (UiTokens.MUTED if b.disabled else UiTokens.TEXT)
	for c in ["font_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_hover_color", UiTokens.GOLD if active else Color.WHITE)

func _draw() -> void:
	var band_h := top_inset + header_h
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, band_h)), UiTokens.HEADER)
	UiTokens.draw_torn_edge(self, Rect2(Vector2(0.0, band_h - 1.0), Vector2(size.x, UiTokens.TORN_MAX + 1.0)))
	# A hairline between the counter / right slot and ✕ (the canvas's separator).
	if counter.text != "" or right.get_combined_minimum_size().x > 0.0:
		var x := close.position.x - 4.0
		draw_line(Vector2(x, top_inset + header_h * 0.3), Vector2(x, top_inset + header_h * 0.7), Color(UiTokens.HUD_RIM, 0.25), 1.0)

## The ‹ and ✕ of the header, drawn as thin strokes (the canvas's look; no glyph font needed).
## 64x64 tap target; GOLD on hover and focus.
class Glyph extends Button:
	var kind := &"close"
	## Phone header: a smaller, thinner mark in the same 64 px target.
	var small := false:
		set(v):
			small = v
			queue_redraw()

	func _init(p_kind: StringName = &"close") -> void:
		kind = p_kind
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(64, 64)
		tooltip_text = "Back" if kind == &"back" else "Close"
		var empty := StyleBoxEmpty.new()
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(s, empty)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * (0.16 if small else 0.22)
		var w := 2.5 if small else 3.0
		var col := UiTokens.GOLD if (is_hovered() or has_focus()) else UiTokens.TEXT
		if kind == &"back":
			draw_polyline(PackedVector2Array([c + Vector2(r * 0.45, -r), c + Vector2(-r * 0.45, 0), c + Vector2(r * 0.45, r)]), col, w, true)
		else:
			draw_line(c - Vector2(r, r), c + Vector2(r, r), col, w, true)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, w, true)

# ---------------------------------------------------------------- dictionary form

## Builds the chrome into `host` (a full-screen Control) and returns its parts:
## {bg, header, back, tabs, right, close, body}. `body` is the area under the header.
static func build(host: Control, p_title: String) -> Dictionary:
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	host.theme = ui_theme()
	var bg := backdrop()
	bg.name = "Dim"
	host.add_child(bg)
	var body := Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(body)
	var header := SheetChrome.new(p_title)
	header.name = "Header"
	host.add_child(header)
	return {"bg": bg, "header": header, "back": header.back, "tabs": header.tabs, "right": header.right, "close": header.close, "body": body}

## Lays out build()'s parts for `view` (call on resize and open): the header, then the body rect.
static func fit(parts: Dictionary, view: Vector2, safe: Vector4) -> void:
	var header: SheetChrome = parts["header"]
	header.layout(view, safe)
	var c := compact(view)
	var g := 8.0 if c else 32.0
	var body: Control = parts["body"]
	body.position = Vector2(safe.w + g, header.header_h + safe.z + (UiTokens.TORN_MAX if c else UiTokens.TORN_MAX + 6.0))
	body.size = Vector2(view.x - safe.w - safe.x - 2.0 * g, view.y - body.position.y - safe.y - (6.0 if c else g))

# ---------------------------------------------------------------- shared widgets

## A transparent tap target with white ink (tabs, links, zoom ±); GOLD on hover/press, GOLD focus ring.
static func flat_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(TAP, TAP)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, empty)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UiTokens.GOLD
	focus.set_border_width_all(2)
	b.add_theme_stylebox_override("focus", focus)
	for c in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(c, UiTokens.TEXT)
	b.add_theme_color_override("font_hover_color", UiTokens.GOLD)
	b.add_theme_color_override("font_pressed_color", UiTokens.GOLD)
	return b

## A transparent 64 px tap target showing a white UI icon (ui_icons.json: zoom_in, zoom_out, …).
static func icon_button(id: StringName) -> Button:
	var b := flat_button("")
	b.name = str(id).capitalize()
	b.icon = UiIcons.icon(id)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.tooltip_text = str(id).capitalize()
	return b

## kind: &"cta" (GOLD fill, CTA_INK), &"ghost" (dark with a light 1 px edge), &"danger" (LIFE outline).
## `trim`: the owner sizes it and long text ends in an ellipsis; off: it is as wide as its text.
static func action_button(t: String, kind: StringName = &"ghost", trim: bool = true) -> Button:
	var b := Button.new()
	b.text = t
	b.clip_text = trim
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if trim else TextServer.OVERRUN_NO_TRIMMING
	b.custom_minimum_size = Vector2(0, TAP)
	b.focus_mode = Control.FOCUS_ALL
	style_action(b, kind)
	return b

## The §8 primary action: full-width GOLD, CTA_INK text, bold; disabled reads grey.
static func gold_button(t: String) -> Button:
	return action_button(t, &"cta")

## A secondary action: near-black fill, thin light edge; `danger` draws it in LIFE.
static func ghost_button(t: String, danger: bool = false) -> Button:
	return action_button(t, &"danger" if danger else &"ghost")

## Gives an existing button the cta / ghost / danger look (sheets with their own button factories).
static func style_action(b: Button, kind: StringName) -> void:
	var ink := UiTokens.CTA_INK if kind == &"cta" else (UiTokens.LIFE if kind == &"danger" else UiTokens.TEXT)
	b.add_theme_stylebox_override("normal", action_style(kind, false))
	b.add_theme_stylebox_override("hover", action_style(kind, false, 0.08))
	b.add_theme_stylebox_override("pressed", action_style(kind, false, -0.1))
	b.add_theme_stylebox_override("focus", action_style(kind, true))
	b.add_theme_stylebox_override("disabled", action_style(&"cta_off" if kind == &"cta" else &"ghost", false))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, ink)
	b.add_theme_color_override("font_disabled_color", Color(0.12, 0.13, 0.14) if kind == &"cta" else UiTokens.MUTED)
	b.add_theme_font_override("font", UiTokens.ui_face(UiTokens.WEIGHT_BOLD if kind == &"cta" else UiTokens.WEIGHT_REGULAR))

static func action_style(kind: StringName, focus: bool, shade: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match kind:
		&"cta":
			sb.bg_color = UiTokens.GOLD.lightened(shade) if shade >= 0.0 else UiTokens.GOLD.darkened(-shade)
			sb.border_color = UiTokens.GOLD.lightened(0.3)
		&"cta_off":
			sb.bg_color = Color(0.45, 0.47, 0.49, 1.0)
			sb.border_color = sb.bg_color
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
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

## A square StyleBoxFlat: `bg` fill, `bw` px `border`, 12/4 px content margins.
static func box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
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

## A sheet panel (§8): PANEL fill, a 1 px light divider, square corners, `pad` content margin.
static func panel_style(fill: Color = UiTokens.PANEL, pad: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = Color(UiTokens.HUD_RIM, 0.08)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(pad)
	return sb

static func panel(fill: Color = UiTokens.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(fill))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p

## The parchment header of a detail panel (PARCHMENT_TOP -> PARCHMENT_BOTTOM, top to bottom).
static func parchment_style(pad_x: float = 20.0, pad_y: float = 8.0) -> StyleBoxTexture:
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
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb

## A panel's section header band ("Pack slots", "Stats", "Needs").
static func section_label(t: String, view: Vector2) -> Label:
	var l := Label.new()
	l.text = t
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

## A small one-line label with colour and size, trimmed with an ellipsis.
static func text(t: String, size_px: int, color: Color = UiTokens.TEXT) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l

## A label in the UI face at `size_px`; bold / italic cuts on request. Not trimmed.
static func label(t: String, size_px: int, color: Color = UiTokens.TEXT, bold: bool = false, italic: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 0)
	var f: Font = UiTokens.ui_face(UiTokens.WEIGHT_BOLD if bold else UiTokens.WEIGHT_REGULAR)
	if italic and f is FontVariation:
		var it := (f as FontVariation).duplicate() as FontVariation
		it.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.2, 1.0), Vector2.ZERO)
		f = it
	l.add_theme_font_override("font", f)
	return l

## A white action icon (ui_icons.json) as a fixed-size TextureRect.
static func icon_rect(id: StringName, size_px: float, tint: Color = UiTokens.TEXT) -> TextureRect:
	var t := TextureRect.new()
	t.texture = UiIcons.icon(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size_px, size_px)
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## A thin progress bar (XP, needs): `col` fill on a dark track, `h` px tall.
static func thin_bar(frac: float, col: Color, h: float = 4.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = clampf(frac, 0.0, 1.0)
	bar.custom_minimum_size = Vector2(0, h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

## A trait chip (§5) as a Label: "Pack hunter". Polarity picks the colours; no prefix for neutral tags.
static func chip(t: String, polarity: StringName = &"negative", size_px: int = 13) -> Label:
	var l := text(t, size_px, UiTokens.trait_chip_fg(polarity))
	var sb := UiTokens.trait_chip_style(polarity)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	l.clip_text = false
	l.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING  # a trimming label's min width is 0
	return l

## Four GOLD corner brackets over the parent's rect (the selection marker, §8). Add as a child.
class Brackets extends Control:
	var arm := UiTokens.BRACKET_ARM

	func _init() -> void:
		name = "Brackets"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # offsets too: inside the tree the plain preset kept an empty rect

	func _draw() -> void:
		UiTokens.draw_brackets(self, Rect2(Vector2(2, 2), size - Vector2(4, 4)), UiTokens.GOLD, arm, UiTokens.BRACKET_W)

## A small dot (unread marker, list bullets).
class Dot extends Control:
	var color := UiTokens.GOLD

	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, color)

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
