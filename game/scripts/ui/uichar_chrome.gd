extends RefCounted
## Shared screen chrome (docs/design/ui-redesign-spec.md §8) for the UICHAR sheets: Character,
## Skills and Orders. A dimmed world, the HEADER bar with "‹ Title" and a torn bottom edge, tabs and
## a right-side slot in the header, ✕ close, PANEL boxes, the parchment header, the full-width GOLD
## button and gold corner brackets. Preloaded by path (no class_name) so a parallel package's own
## chrome cannot collide with it.

const TAP := 64.0

## Desktop is the gate (1600x900); a landscape phone (844x390) gets a 64 px header and smaller type.
static func compact(view: Vector2) -> bool:
	return UiTokens.is_compact(view)

static func header_h(view: Vector2) -> float:
	return TAP if compact(view) else UiTokens.HEADER_H

## Outer margin of the body under the header.
static func gutter(view: Vector2) -> float:
	return 8.0 if compact(view) else 32.0

static func px(view: Vector2, desk: int, phone: int) -> int:
	return phone if compact(view) else desk

## The header bar with its torn edge drawn below its rect.
class Header extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UiTokens.HEADER)
		UiTokens.draw_torn_edge(self, Rect2(Vector2(0, size.y), Vector2(size.x, UiTokens.TORN_MAX)))

## Gold corner brackets over its parent's rect (the selection marker).
class Brackets extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # offsets too: inside the tree the plain preset kept an empty rect
	func _draw() -> void:
		UiTokens.draw_brackets(self, Rect2(Vector2(2, 2), size - Vector2(4, 4)))

## A small dot (unread marker, list bullets).
class Dot extends Control:
	var color := UiTokens.GOLD
	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, color)

## Builds the chrome into `host` (a full-screen Control) and returns its parts:
## {bg, header, back, tabs, right, close, body}. `body` is the area under the header.
static func build(host: Control, title: String) -> Dictionary:
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	var th := Theme.new()
	var f := UiTokens.ui_font()
	if f:
		th.default_font = f
	host.theme = th
	var bg := ColorRect.new()
	bg.name = "Dim"
	# ASSUMPTION: no blur pass exists, so the wash is near-opaque to keep text readable over the world.
	bg.color = Color(UiTokens.SCREEN_DIM.r * 0.5, UiTokens.SCREEN_DIM.g * 0.5, UiTokens.SCREEN_DIM.b * 0.5, 0.93)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(bg)
	var body := Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(body)
	var header := Header.new()
	header.name = "Header"
	host.add_child(header)
	var row := HBoxContainer.new()
	row.name = "HeaderRow"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 16)
	header.add_child(row)
	var back := flat_button("‹  " + title)
	back.name = "Back"
	row.add_child(back)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 8)
	row.add_child(tabs)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var right := HBoxContainer.new()
	right.name = "Right"
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)
	var close := flat_button("×")
	close.name = "Close"
	close.custom_minimum_size = Vector2(TAP, TAP)
	row.add_child(close)
	return {"bg": bg, "header": header, "back": back, "tabs": tabs, "right": right, "close": close, "body": body}

## Header height, body rect and type sizes for the current view (call on resize and open).
static func layout(c: Dictionary, view: Vector2, safe: Vector4) -> void:
	var h := header_h(view)
	var header: Control = c["header"]
	header.position = Vector2.ZERO
	header.size = Vector2(view.x, h + safe.z)
	var row := header.get_node("HeaderRow") as HBoxContainer
	row.add_theme_constant_override("separation", px(view, 16, 6))
	row.offset_left = safe.w + gutter(view)
	row.offset_right = -safe.x - gutter(view) * 0.5
	row.offset_top = safe.z
	var g := gutter(view)
	var body: Control = c["body"]
	body.position = Vector2(safe.w + g, h + safe.z + (UiTokens.TORN_MAX + 6.0 if not compact(view) else UiTokens.TORN_MAX))
	body.size = Vector2(view.x - safe.w - safe.x - 2.0 * g, view.y - body.position.y - safe.y - (g if not compact(view) else 6.0))
	(c["back"] as Button).add_theme_font_size_override("font_size", px(view, 40, 26))
	(c["close"] as Button).add_theme_font_size_override("font_size", px(view, 48, 34))
	for t: Node in (c["tabs"] as Node).get_children():
		if t is Button:
			(t as Button).add_theme_font_size_override("font_size", px(view, 24, 17))
	header.queue_redraw()

## Text-only button (header title, tabs, close): transparent at rest, still a 64 px target.
static func flat_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TAP, TAP)
	var sb := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", UiTokens.TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", UiTokens.GOLD)
	return b

## A header tab: gold text and a gold underline when on.
static func tab_style(b: Button, on: bool, margin: int = 24) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = UiTokens.GOLD
	sb.border_width_bottom = 3 if on else 0
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", UiTokens.GOLD if on else UiTokens.TEXT)
	b.add_theme_color_override("font_hover_color", UiTokens.GOLD if on else Color.WHITE)

## PANEL box with a 1 px light divider; `pad` content margin.
static func panel_box(pad: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.PANEL
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(pad)
	return sb

## The parchment header of a detail panel (PARCHMENT_TOP -> PARCHMENT_BOTTOM).
static func parchment_box(pad: float = 16.0) -> StyleBoxTexture:
	var g := Gradient.new()
	g.colors = PackedColorArray([UiTokens.PARCHMENT_TOP, UiTokens.PARCHMENT_BOTTOM])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 8
	t.height = 64
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.set_content_margin_all(pad)
	return sb

## The full-width GOLD primary action (CTA_INK text); disabled reads grey like "Tracking on HUD".
static func gold_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TAP, TAP)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var on := StyleBoxFlat.new()
	on.bg_color = UiTokens.GOLD
	on.set_content_margin_all(8)
	var hover := on.duplicate() as StyleBoxFlat
	hover.bg_color = UiTokens.GOLD.lightened(0.12)
	var off := on.duplicate() as StyleBoxFlat
	off.bg_color = Color(0.45, 0.47, 0.49, 1.0)
	b.add_theme_stylebox_override("normal", on)
	b.add_theme_stylebox_override("focus", on)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", off)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, UiTokens.CTA_INK)
	b.add_theme_color_override("font_disabled_color", Color(0.12, 0.13, 0.14))
	return b

## A dark secondary button (Unequip, Show on map), 1 px light rim.
static func dark_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TAP, TAP)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTokens.HEADER
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	var hv := sb.duplicate() as StyleBoxFlat
	hv.border_color = UiTokens.GOLD
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	var dis := sb.duplicate() as StyleBoxFlat
	dis.border_color = Color(1, 1, 1, 0.15)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", UiTokens.TEXT)
	return b

## A label with the UI font at `size_px` and `color`.
static func label(text: String, size_px: int, color: Color = UiTokens.TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", 0)
	if bold and UiTokens.ui_font_bold():
		l.add_theme_font_override("font", UiTokens.ui_font_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

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
