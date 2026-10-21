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
## A canvas shorter than this is a landscape phone (same bound as DisplayMode.is_phone_landscape).
const SHORT_MAX := 500.0

const INK := Color(0.035, 0.04, 0.048, 0.94)
const INK_SOLID := Color(0.05, 0.055, 0.062, 0.97)
const DIVIDER := Color(0.55, 0.50, 0.44, 0.55)
const TEAL := Color(0.20, 0.78, 0.74, 1.0)
const TEAL_DIM := Color(0.12, 0.42, 0.42, 0.95)
const DANGER := Color(0.86, 0.22, 0.18, 1.0)
const TEXT := Color(0.95, 0.95, 0.93, 1.0)
const META := Color(0.78, 0.76, 0.70, 1.0)
const ACTION := Color(1, 1, 1, 1)
## Tests turn this on to run the controller focus path without a joypad (wants_focus()).
static var force_focus := false


## Under 720 px wide. Kept at its original meaning: the protected HUD, bag and animal screen pick
## their portrait layouts with it, and DisplayMode never gives a landscape phone a canvas that
## narrow, so they keep their desktop rows there (their portrait rows overlapped at 844x390).
static func is_phone(view: Vector2) -> bool:
	return view.x < 720.0

## Portrait phone: too narrow for side-by-side columns, so screens stack one pane at a time.
## Decided by shape too: a landscape canvas is never narrow, whatever its width.
static func is_narrow(view: Vector2) -> bool:
	return view.x < 720.0 and view.y > view.x

## Phone type sizes and density, either way up: narrow (portrait) or short (landscape, the shipped
## handheld orientation). Owned screens pick their landscape layouts with this, never is_phone.
static func is_compact(view: Vector2) -> bool:
	return is_narrow(view) or view.y < SHORT_MAX

static func heading(view: Vector2) -> int:
	return 20 if is_compact(view) else 24

static func body(view: Vector2) -> int:
	return 14 if is_compact(view) else 16

static func meta(view: Vector2) -> int:
	return 12 if is_compact(view) else 13

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

## Greedy screen-space labels. Higher priority keeps its anchor; the rest step away, from each other
## and from `avoid` (the HUD's blocks and hexes: camp labels drew over the quest card on a phone).
## A label with no free spot within three rows under its anchor is dropped, not drawn on top, and so
## is one whose anchor `avoid` covers. `keep_off` is only stepped away from (the survivor: a building
## behind it keeps its label).
## Each item is {anchor: Vector2, w: float, h: float, priority: int, ...}.
static func layout_labels(items: Array, view: Vector2, avoid: Array[Rect2] = [], keep_off: Array[Rect2] = []) -> Array:
	var ordered: Array = []
	for item in items:
		if item is Dictionary:
			ordered.append((item as Dictionary).duplicate())
	ordered.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var placed: Array[Rect2] = avoid.duplicate()
	placed.append_array(keep_off)
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
		if _hits(rect, placed):  # next to whatever it covers (a label under the quest card)
			rect = free_spot(rect, placed, view)
		# Dropped: no free spot, one more than four rows off its object (it read as part of the HUD),
		# or an object the HUD itself hides.
		if not rect.has_area() or absf(rect.end.y - anchor.y) > (h + float(SPACE) * 0.5) * 4.0 or _covers(avoid, anchor):
			continue
		placed.append(rect)
		row["rect"] = rect
		row["w"] = w
		out.append(row)
	return out

## The nearest spot straight up or down from `box` where it covers nothing in `taken` (2 px apart),
## inside the view; empty when there is none. Toasts, notices and crowded labels take it. With
## `prefer_up` any free spot above wins (a creature plate belongs over its creature, not under it).
static func free_spot(box: Rect2, taken: Array[Rect2], view: Vector2, prefer_up: bool = false) -> Rect2:
	var down := _slide(box, taken, view, 1.0)
	var up := _slide(box, taken, view, -1.0)
	if not up.has_area() or (not prefer_up and down.has_area() and down.position.y - box.position.y <= box.position.y - up.position.y):
		return down
	return up

static func _slide(box: Rect2, taken: Array[Rect2], view: Vector2, dir: float) -> Rect2:
	var moved := true
	while moved:
		moved = false
		for t in taken:
			if box.intersects(t.grow(2.0)):
				box.position.y = t.end.y + 4.0 if dir > 0.0 else t.position.y - 4.0 - box.size.y
				moved = true
		if box.end.y > view.y - 8.0 or box.position.y < 8.0:
			return Rect2()
	return box

static func _covers(rects: Array[Rect2], p: Vector2) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false

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
	return force_focus or not Input.get_connected_joypads().is_empty()

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
		if control and not control.is_queued_for_deletion() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
			return control
	return null

## Where the hand-drawn HUD sits, so radials can keep their hexes off it.
## ASSUMPTION: mirrors hunt_hud.gd geometry (vitals top-left, quest + minimap top-right, rails in the
## bottom corners) until W2-HUD exports its own rects.
static func hud_reserved(view: Vector2) -> Array[Rect2]:
	if is_narrow(view):
		# The third is the portrait map column: minimap, its text, the quest card and the claim hex
		# under it (hunt_hud.gd); a station menu hex sat on the map text. 240 wide: the day/night dial
		# sits left of the map, its left edge 234 px in from the right (DayNightDial).
		return [Rect2(0, 0, view.x, 96.0), Rect2(0, view.y - 96.0, view.x, 96.0), Rect2(view.x - 240.0, 0.0, 240.0, 396.0)]
	if is_compact(view):  # landscape: vitals + quest band, the map/claim/rail column on the right, left rail
		# The fourth zone is the row above the rail (quick food, chase, HANDS stacked over the rail's
		# last hex, held_item_slot.gd) with captions; the fifth is the XP line at the bottom centre (a
		# gather label landed on it); the sixth is the pet whistle row under the vitals (hunt_hud.gd).
		# The first runs to 112: the quest card ends at 106 (a station hex sat on its last line). The
		# second is 240 wide for the day/night dial left of the map (234 px in from the right).
		return [Rect2(0, 0, view.x, 112.0), Rect2(view.x - 240.0, 0, 240.0, view.y), Rect2(0, view.y - 104.0, 330.0, 104.0), Rect2(0.0, view.y - 200.0, 308.0, 96.0), xp_line_zone(view), Rect2(0.0, 96.0, 240.0, 96.0)]
	return [
		Rect2(0, 0, 330.0, 112.0),
		Rect2(view.x - 450.0, 0, 450.0, 240.0),
		Rect2(0, view.y - 104.0, 330.0, 104.0),
		Rect2(view.x - 190.0, view.y - 196.0, 190.0, 196.0),
		xp_line_zone(view),
	]

## The "Lv. 1  5.0%" line hunt_hud draws centred at the bottom (off a portrait phone).
## ASSUMPTION: 180x26 covers hunt_hud's 13 px line at r.y - 7 up to "Lv. 100  100.0%".
static func xp_line_zone(view: Vector2) -> Rect2:
	return Rect2(view.x * 0.5 - 90.0, view.y - 26.0, 180.0, 26.0)

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
