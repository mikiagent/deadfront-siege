class_name UiTokens
extends RefCounted
## Shared presentation tokens for WildLands MMO screens.
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
## Cached FontVariations per weight (ui_font()).
static var _fonts: Dictionary = {}

## Hex HUD palette (docs/design/ui-redesign-spec.md §2). Kept beside the old tokens: restyled screens
## opt in, every existing screen keeps drawing with INK/TEAL/DIVIDER until its own package moves it.
const HUD_FILL := Color(0.039, 0.047, 0.047, 0.92)    # hex interior, HUD panels
const HUD_RIM := Color(0.933, 0.945, 0.949, 0.85)     # light hex rim
const HEADER := Color(0.027, 0.031, 0.035, 1.0)       # full-screen header bar with torn bottom edge
const SCREEN_DIM := Color(0.063, 0.165, 0.243, 0.55)  # wash over the blurred world behind sheets
const PANEL := Color(0.055, 0.118, 0.173, 0.82)       # sheet panel
const GOLD := Color(0.957, 0.769, 0.188, 1.0)         # selection brackets, CTA, active state
const GOLD_DIM := Color(0.957, 0.769, 0.188, 0.12)    # selected row wash
const CTA_INK := Color(0.078, 0.071, 0.047, 1.0)      # text on GOLD buttons
const PARCHMENT_TOP := Color(0.804, 0.722, 0.541, 1.0)
const PARCHMENT_BOTTOM := Color(0.706, 0.620, 0.424, 1.0)
const PARCHMENT_INK := Color(0.102, 0.090, 0.063, 1.0)
const OK_GREEN := Color(0.373, 0.827, 0.416, 1.0)     # build SAVE check, filled material chevrons
const LIFE := Color(0.847, 0.314, 0.227, 1.0)
const ENERGY := Color(0.373, 0.659, 0.816, 1.0)
const XP := Color(0.561, 0.816, 0.910, 1.0)
const MUTED := Color(0.604, 0.651, 0.678, 1.0)        # secondary labels
## Status palette (owner 2026-10-28): green is reserved for healing and positive restores; no negative
## status is ever green, poison/venom/sickness are purple. statuses.json fx colours follow it.
const PLAYER_ENERGY := Color(0.20, 0.45, 0.80, 1.0)  # the survivor's own stamina bar
## Owner 2026-10-28: the mounted energy bar is "segmented and darker blue to indicate mounted energy".
const MOUNT_ENERGY := Color(0.11, 0.24, 0.50, 1.0)
const MOUNT_ENERGY_SEGMENTS := 10  # ASSUMPTION: a tick every 10 %
const HEAL := Color(0.373, 0.827, 0.416, 1.0)         # healing numbers, positive restores (= OK_GREEN)
const WET := Color(74.0 / 255.0, 159.0 / 255.0, 224.0 / 255.0, 1.0)  # #4a9fe0: the Wet effect, water blue (never green)
const SMOKE := Color(154.0 / 255.0, 154.0 / 255.0, 158.0 / 255.0, 1.0)  # #9a9a9e: Smoke Inhalation, ash grey (never green)
const POISON := Color(163.0 / 255.0, 107.0 / 255.0, 217.0 / 255.0, 1.0)  # #a36bd9: venom, poison, sickness

## Trait chips (owner rule §1.4). bg / fg pairs; never reuse for item colour (spec 35).
const TRAIT_NEG_BG := Color(0.243, 0.263, 0.275, 1.0)
const TRAIT_NEG_FG := Color(0.765, 0.796, 0.816, 1.0)
const TRAIT_POS_BG := Color(0.957, 0.769, 0.188, 0.18)
const TRAIT_POS_FG := GOLD
const TRAIT_RARE_BG := Color(0.471, 0.824, 0.431, 0.20)
const TRAIT_RARE_FG := Color(0.561, 0.863, 0.518, 1.0)

## Exhaustion tiers (face + belt tint), indexed by the existing four tiers in Vitals.
const MOOD := [Color(0.561, 0.863, 0.518), Color(0.957, 0.769, 0.188),
		Color(0.910, 0.588, 0.165), Color(0.878, 0.412, 0.310)]

## The UI face (owner decision 2026-10-28): Roboto Condensed, a variable-weight TTF under SIL OFL.
## The file is an asset change of its own (game/assets/fonts/RobotoCondensed-Variable.ttf, licence in
## RobotoCondensed-OFL.txt); this package only names it and builds FontVariations from it. No screen
## uses it yet — later restyle packages do.
const UI_FONT_PATH := "res://assets/fonts/RobotoCondensed-Variable.ttf"
const WEIGHT_REGULAR := 400
const WEIGHT_BOLD := 700
## Font sizes at 1600x900 from the §2 canvas, scaled by the screens themselves (sizes only until the
## face ships everywhere).
const TITLE_PX := 28
const HEADER_PX := 22
const CHIP_PX := 12

## Hex orientation, one switch for every hex on every screen. Owner decision 2026-10-28: flat-top
## (the canvas and the Durango references draw flat-top hexes). Pointy-top is still available per hex
## (HexButton.flat_top, hex_points(..., false)) for tests and comparisons, but no screen picks it.
const HEX_FLAT_TOP := true
## Pie-fill sampling: boundary points at least this far apart (radians), plus every vertex passed.
const PIE_STEP := PI / 30.0
## Header bar height at 1600x900 (§8) and the torn edge under it.
const HEADER_H := 88.0
const TORN_MAX := 12.0
## Selection bracket arm / stroke (§8).
const BRACKET_ARM := 18.0
const BRACKET_W := 3.0


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
		# The fourth zone is the quick row above the rail (quick food, chase, HANDS in its fourth slot,
		# HuntHud.hands_spot) with captions; the second also holds INTERACT / ATTACK NEAREST / SPRINT; the fifth is the XP line at the bottom centre (a
		# gather label landed on it); the sixth is the pet whistle row under the vitals (hunt_hud.gd).
		# The first runs to 112: the quest card ends at 106 (a station hex sat on its last line). The
		# second is 240 wide for the day/night dial left of the map (234 px in from the right).
		return [Rect2(0, 0, view.x, 112.0), Rect2(view.x - 240.0, 0, 240.0, view.y), Rect2(0, view.y - 104.0, 330.0, 104.0), Rect2(0.0, view.y - 200.0, 308.0, 96.0), xp_line_zone(view), Rect2(0.0, 96.0, 240.0, 96.0)]
	# Desktop (HudField sizes, owner layout 2026-10-28): the third is the 100 px MENU / BUILD / BAG rail with
	# the quick slots above it and the whistle row beside it; the fourth INTERACT, ATTACK NEAREST above
	# it and SPRINT left of it.
	return [
		Rect2(0, 0, 330.0, 112.0),
		Rect2(view.x - 450.0, 0, 450.0, 240.0),
		Rect2(0, view.y - 250.0, 600.0, 250.0),
		Rect2(view.x - 290.0, view.y - 320.0, 290.0, 320.0),
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

# ---------------------------------------------------------------- hex geometry (§2, §3)

## The six corners of a hex centred on `center` with circumradius `r`, first corner at angle 0
## (flat-top) or -30 degrees (pointy-top). One source for HexButton, chevrons and pie fills.
static func hex_points(center: Vector2, r: float, flat_top: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var off := 0.0 if flat_top else -PI / 6.0
	for i in 6:
		var a := off + TAU * float(i) / 6.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

## Distance from centre to the hex edge along angle `a` (radians), circumradius `r` (spec §4).
static func hex_radius_at(a: float, r: float, flat_top: bool) -> float:
	var apothem := r * cos(PI / 6.0)
	var off := 0.0 if flat_top else PI / 6.0
	var local := fposmod(a - off, PI / 3.0) - PI / 6.0
	return apothem / cos(local)

## The six corner angles in the hex_points() order, in [0, TAU).
static func hex_vertex_angles(flat_top: bool) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var off := 0.0 if flat_top else -PI / 6.0
	for i in 6:
		out.append(fposmod(off + TAU * float(i) / 6.0, TAU))
	return out

## Pie sector inside the hex: the centre plus the boundary from -90 degrees clockwise through
## 360*f degrees, sampled every PIE_STEP and at every hex vertex the sweep crosses. f = 0 gives
## just the centre; f = 1 gives the whole hex as a closed polygon (area = the hex's area).
static func pie_points(center: Vector2, r: float, f: float, flat_top: bool) -> PackedVector2Array:
	var pts := PackedVector2Array([center])
	var frac := clampf(f, 0.0, 1.0)
	if frac <= 0.0:
		return pts
	var start := -PI * 0.5
	var sweep := TAU * frac
	var stops := PackedFloat32Array()
	var n := maxi(1, ceili(sweep / PIE_STEP))
	for i in n + 1:
		stops.append(start + sweep * float(i) / float(n))
	for va in hex_vertex_angles(flat_top):
		# the first crossing of this vertex at or after `start`, while it is inside the sweep
		var k := ceilf((start - va) / TAU)
		var at := va + TAU * k
		if at > start + 0.0001 and at < start + sweep - 0.0001:
			stops.append(at)
	stops.sort()
	var last := -INF
	for a in stops:
		if a <= last + 0.0001:
			continue
		last = a
		pts.append(center + Vector2(cos(a), sin(a)) * hex_radius_at(a, r, flat_top))
	return pts

## Shoelace area of a polygon (absolute).
static func polygon_area(pts: PackedVector2Array) -> float:
	if pts.size() < 3:
		return 0.0
	var sum := 0.0
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5

# ---------------------------------------------------------------- trait chips (§5)

## Chip background/foreground for a trait polarity: &"negative", &"positive" or &"rare".
## Unknown polarities read as negative (the common case in the data, spec §5).
static func trait_chip_style(polarity: StringName) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	match polarity:
		&"positive":
			sb.bg_color = TRAIT_POS_BG
			sb.border_color = TRAIT_POS_FG
		&"rare":
			sb.bg_color = TRAIT_RARE_BG
			sb.border_color = TRAIT_RARE_FG
		_:
			sb.bg_color = TRAIT_NEG_BG
			sb.border_color = TRAIT_NEG_FG
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb

## The colour-blind prefix for a chip: minus, plus, four-pointed star (spec §5). The star is built
## from its code point: a literal here would have to join ui_icons.json's typographic list first.
static func trait_chip_prefix(polarity: StringName) -> String:
	match polarity:
		&"positive":
			return "+"
		&"rare":
			return String.chr(0x2726)
		_:
			return "−"

## The chip's text colour (chrome draws the style box, the text takes this).
static func trait_chip_fg(polarity: StringName) -> Color:
	match polarity:
		&"positive":
			return TRAIT_POS_FG
		&"rare":
			return TRAIT_RARE_FG
		_:
			return TRAIT_NEG_FG

# ---------------------------------------------------------------- selection brackets (§8)

## The four corner brackets' eight line segments (a, b pairs), so a gate can check the geometry
## without a drawing pass. `arm` is capped at half the short side.
static func bracket_segments(rect: Rect2, arm: float = BRACKET_ARM) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not rect.has_area():
		return out
	var a := minf(arm, minf(rect.size.x, rect.size.y) * 0.5)
	var l := rect.position.x
	var r := rect.end.x
	var t := rect.position.y
	var b := rect.end.y
	out.append_array([Vector2(l, t + a), Vector2(l, t), Vector2(l, t), Vector2(l + a, t)])
	out.append_array([Vector2(r - a, t), Vector2(r, t), Vector2(r, t), Vector2(r, t + a)])
	out.append_array([Vector2(l, b - a), Vector2(l, b), Vector2(l, b), Vector2(l + a, b)])
	out.append_array([Vector2(r - a, b), Vector2(r, b), Vector2(r, b), Vector2(r, b - a)])
	return out

## Four gold corner brackets in `rect`: the selection marker used for grid cells, tabs and slots.
static func draw_brackets(ci: CanvasItem, rect: Rect2, color: Color = GOLD, arm: float = BRACKET_ARM, w: float = BRACKET_W) -> void:
	if ci == null:
		return
	var segs := bracket_segments(rect, arm)
	for i in range(0, segs.size(), 2):
		ci.draw_line(segs[i], segs[i + 1], color, w, true)

# ---------------------------------------------------------------- screen chrome (§8)

## The full-screen header bar: HEADER fill, no radius, room for the title on the left.
static func header_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HEADER
	sb.set_corner_radius_all(0)
	sb.content_margin_left = SPACE * 2
	sb.content_margin_right = SPACE * 2
	sb.content_margin_top = SPACE
	sb.content_margin_bottom = SPACE
	return sb

## Deterministic zig-zag along the bottom edge of `rect`: the header's torn paper edge. The teeth
## vary in depth from 0 to `amp` px (spec §8: 0-12 px), keyed off x, so the same width always tears
## the same way (no RNG, a redraw is stable).
static func torn_edge_points(rect: Rect2, amp: float = TORN_MAX, step: float = 16.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if not rect.has_area():
		return pts
	var s := maxf(4.0, step)
	var n := maxi(1, ceili(rect.size.x / s))
	for i in n + 1:
		var x := minf(rect.end.x, rect.position.x + s * float(i))
		var depth := amp * float(abs(sin(float(int(round(x)) % 997) * 0.733)))
		pts.append(Vector2(x, rect.end.y - depth))
	return pts

## Draws the torn edge under a header: the header's fill down to the zig-zag plus its outline.
static func draw_torn_edge(ci: CanvasItem, rect: Rect2, color: Color = HEADER, amp: float = TORN_MAX, step: float = 16.0) -> void:
	if ci == null or not rect.has_area():
		return
	var zig := torn_edge_points(rect, amp, step)
	if zig.size() < 2:
		return
	var poly := PackedVector2Array([Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y)])
	for i in range(zig.size() - 1, -1, -1):
		poly.append(zig[i])
	ci.draw_colored_polygon(poly, color)
	ci.draw_polyline(zig, Color(color.lightened(0.35), 0.5), 1.0, true)

# ---------------------------------------------------------------- type (§2)

## The UI font at `weight` (WEIGHT_REGULAR / WEIGHT_BOLD), built once per weight and cached.
## Empty when the font file is not in this tree yet: callers fall back to ThemeDB.fallback_font.
static func ui_font(weight: int = WEIGHT_REGULAR) -> FontVariation:
	if _fonts.has(weight):
		return _fonts[weight]
	if not ResourceLoader.exists(UI_FONT_PATH):
		return null
	var base := load(UI_FONT_PATH) as Font
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": float(weight)}
	var made := fv
	_fonts[weight] = made
	return made

static func ui_font_regular() -> FontVariation:
	return ui_font(WEIGHT_REGULAR)

static func ui_font_bold() -> FontVariation:
	return ui_font(WEIGHT_BOLD)

## The face a new restyled widget draws with: the UI font when present, else the engine's fallback.
static func ui_face(weight: int = WEIGHT_REGULAR) -> Font:
	var f := ui_font(weight)
	return f if f != null else ThemeDB.fallback_font

## Italic cut of the UI face: the variable TTF has no italic axis Godot exposes, so a 0.2 skew
## (the slant Roboto's own italic uses). Fallback font when the TTF is missing.
static func ui_italic(weight: int = WEIGHT_REGULAR) -> Font:
	var key := "italic%d" % weight
	if not _fonts.has(key):
		var f := ui_font(weight)
		if f == null:
			return ThemeDB.fallback_font
		var it := f.duplicate() as FontVariation
		it.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO)
		_fonts[key] = it
	return _fonts[key]
