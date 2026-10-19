class_name UiTokens
extends RefCounted
## Shared presentation tokens for DEADFRONT screens.
## Ink panels, warm-gray dividers, teal selection, red only for danger.
## 8 px spacing, 12 px panel radius, type floors for desktop and phone.

const SPACE := 8
const RADIUS := 12
const HEX := 64.0
const TARGET_MIN := 44.0
const TARGET_PRIMARY := 56.0
const LABEL_MAX_W := 168.0
## Smallest text any screen draws, in logical px (the phone canvas is one px per point).
const TYPE_MIN := 12

const INK := Color(0.035, 0.04, 0.048, 0.94)
const INK_SOLID := Color(0.05, 0.055, 0.062, 0.97)
const DIVIDER := Color(0.55, 0.50, 0.44, 0.55)
const TEAL := Color(0.20, 0.78, 0.74, 1.0)
const TEAL_DIM := Color(0.12, 0.42, 0.42, 0.95)
const DANGER := Color(0.86, 0.22, 0.18, 1.0)
const TEXT := Color(0.95, 0.95, 0.93, 1.0)
const META := Color(0.78, 0.76, 0.70, 1.0)
const ACTION := Color(1, 1, 1, 1)


static func is_phone(view: Vector2) -> bool:
	return view.x < 720.0

static func heading(view: Vector2) -> int:
	return 20 if is_phone(view) else 24

static func body(view: Vector2) -> int:
	return 14 if is_phone(view) else 16

static func meta(view: Vector2) -> int:
	return 12 if is_phone(view) else 13

static func panel_style(alpha: float = 0.94) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var bg := INK
	bg.a = alpha
	sb.bg_color = bg
	sb.border_color = DIVIDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(RADIUS)
	sb.content_margin_left = SPACE * 2
	sb.content_margin_right = SPACE * 2
	sb.content_margin_top = SPACE * 2
	sb.content_margin_bottom = SPACE * 2
	return sb

static func selected_style() -> StyleBoxFlat:
	var sb := panel_style()
	sb.border_color = TEAL
	sb.set_border_width_all(2)
	sb.bg_color = TEAL_DIM
	return sb

static func danger_style() -> StyleBoxFlat:
	var sb := panel_style()
	sb.border_color = DANGER
	sb.set_border_width_all(2)
	return sb

static func button_style(selected: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TEAL_DIM if selected else Color(0.09, 0.10, 0.12, 0.96)
	sb.border_color = TEAL if selected else DIVIDER
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(RADIUS)
	sb.content_margin_left = SPACE
	sb.content_margin_right = SPACE
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

static func slot_style(selected: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.11, 0.13, 1.0)
	sb.border_color = TEAL if selected else DIVIDER
	sb.set_border_width_all(2 if selected else 1)
	sb.set_corner_radius_all(8)
	return sb

## Viewport insets. x = right, y = bottom, z = top, w = left.
static func safe_insets(viewport: Viewport) -> Vector4:
	if viewport == null or not OS.has_feature("mobile"):
		return Vector4.ZERO
	var rect := viewport.get_visible_rect().size
	var win := Vector2(DisplayServer.window_get_size())
	var scale := rect / win if win.x > 0.0 and win.y > 0.0 else Vector2.ONE
	var safe := DisplayServer.get_display_safe_area()
	return Vector4(
		maxf(0.0, win.x - (safe.position.x + safe.size.x)) * scale.x,
		maxf(0.0, win.y - (safe.position.y + safe.size.y)) * scale.y,
		maxf(0.0, safe.position.y) * scale.y,
		maxf(0.0, safe.position.x) * scale.x)

static func ellipsis(font: Font, text: String, width: float, size_px: int) -> String:
	if font == null or text == "" or width <= 0.0:
		return text
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= width:
		return text
	var ell := "…"
	var lo := 0
	var hi := text.length()
	var best := ell
	while lo <= hi:
		var mid := (lo + hi) >> 1
		var candidate := text.substr(0, mid).rstrip(" ") + ell
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= width:
			best = candidate
			lo = mid + 1
		else:
			hi = mid - 1
	return best

## Greedy screen-space labels. Higher priority keeps its anchor; the rest step away.
## Each item is {anchor: Vector2, w: float, h: float, priority: int, ...}.
static func layout_labels(items: Array, view: Vector2) -> Array:
	var ordered: Array = []
	for item in items:
		if item is Dictionary:
			ordered.append((item as Dictionary).duplicate())
	ordered.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var placed: Array[Rect2] = []
	var out: Array = []
	for item in ordered:
		var row := item as Dictionary
		var w := minf(float(row.get("w", 80.0)), LABEL_MAX_W)
		var h := float(row.get("h", 22.0))
		var anchor: Vector2 = row.get("anchor", Vector2.ZERO)
		var rect := Rect2(anchor - Vector2(w * 0.5, h), Vector2(w, h))
		var tries := 0
		while tries < 12 and _hits(rect, placed):
			rect.position.y -= h + float(SPACE) * 0.5
			if rect.position.y < 8.0:
				rect.position.y = anchor.y + 6.0
				rect.position.x += w * 0.35 + float(SPACE)
			tries += 1
		rect.position.x = clampf(rect.position.x, 8.0, maxf(8.0, view.x - w - 8.0))
		rect.position.y = clampf(rect.position.y, 8.0, maxf(8.0, view.y - h - 8.0))
		if _hits(rect, placed):
			rect.position.y = clampf(anchor.y - h * 2.0 - 8.0, 8.0, maxf(8.0, view.y - h - 8.0))
		placed.append(rect)
		row["rect"] = rect
		row["w"] = w
		out.append(row)
	return out

static func _hits(rect: Rect2, placed: Array[Rect2]) -> bool:
	var grown := rect.grow(2.0)
	for prior in placed:
		if grown.intersects(prior):
			return true
	return false

## Left edge that centres a run of `width` px on `center_x`.
static func centered_x(center_x: float, width: float) -> float:
	return center_x - width * 0.5

## Baseline origin that centres `text` on `center` both ways. draw_string with
## HORIZONTAL_ALIGNMENT_CENTER and a width centres inside [x, x + width], so passing the centre as x
## shifted every glyph right by half that width (plate letters fell out of their circles).
static func centered_origin(font: Font, text: String, size_px: int, center: Vector2) -> Vector2:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var y := center.y + (font.get_ascent(size_px) - font.get_descent(size_px)) * 0.5
	return Vector2(centered_x(center.x, w), y)

static func draw_centered(ci: CanvasItem, font: Font, center: Vector2, text: String, size_px: int, color: Color) -> Vector2:
	if font == null or text == "":
		return center
	var at := centered_origin(font, text, maxi(TYPE_MIN, size_px), center)
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(TYPE_MIN, size_px), color)
	return at

## Menus put focus on their first control only when a controller is connected; with a mouse the
## ring would just be noise and Space would press it.
static func wants_focus() -> bool:
	return not Input.get_connected_joypads().is_empty()

static func focus_first(controls: Array) -> void:
	if not wants_focus():
		return
	var first := first_focusable(controls)
	if first:
		first.grab_focus()

## The first visible control in `controls` that can take focus (null when none can).
static func first_focusable(controls: Array) -> Control:
	for c in controls:
		var control := c as Control
		if control and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
			return control
	return null

## Where the hand-drawn HUD sits, so radials can keep their hexes off it.
## ASSUMPTION: mirrors hunt_hud.gd geometry (vitals top-left, quest + minimap top-right, rails in the
## bottom corners) until W2-HUD exports its own rects.
static func hud_reserved(view: Vector2) -> Array[Rect2]:
	if is_phone(view):
		return [Rect2(0, 0, view.x, 96.0), Rect2(0, view.y - 96.0, view.x, 96.0)]
	return [
		Rect2(0, 0, 330.0, 112.0),
		Rect2(view.x - 450.0, 0, 450.0, 240.0),
		Rect2(0, view.y - 104.0, 330.0, 104.0),
		Rect2(view.x - 190.0, view.y - 196.0, 190.0, 196.0),
	]

static func style_label(label: Label, view: Vector2, kind: String) -> void:
	var size_px := body(view)
	if kind == "heading":
		size_px = heading(view)
	elif kind == "meta":
		size_px = meta(view)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", META if kind == "meta" else TEXT)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
