class_name MarketTheme
extends RefCounted
## The Island Market's look (spec 13 palette, spec 14 references): colours, per-viewport metrics,
## the condensed font, the weathered backdrop and the shared draw helpers (dotted separators,
## yellow L brackets, the torn header edge).
# swap: INVUI InvTheme / InvPaint / inv_grain when they land (same palette, same helpers).

const BG := Color("#101714")
const HEADER := Color("#0B0C0E")
const PANEL := Color("#39392F")
const PANEL_2 := Color("#26322C")
const BAND := Color(0.03, 0.035, 0.03, 0.55) ## table header / column title band over the panel
const SEPARATOR := Color(0.62, 0.60, 0.53, 0.45) ## dotted row lines
const BORDER := Color(0.04, 0.04, 0.025, 0.9) ## the references' panels sit in a thin dark rim, not a light stroke
const PANEL_FILL := Color(0.05, 0.055, 0.035, 0.42) ## rail, columns, table: the backdrop shows through, darker
const DIALOG := Color(0.11, 0.105, 0.08, 0.98) ## Sell panel, confirm, search sheet: the list panels' warm brown-black
const PARCHMENT := Color(0.69, 0.65, 0.55) ## the torn band under the header and dialog title bands
const GOLD := Color("#E6BE54") ## names, selection, brackets, the active tab
const PRIMARY := Color("#F2C84C") ## primary button fill (dark text)
const PRIMARY_TEXT := Color("#1B1A14")
const TEXT := Color("#ECEBE4")
const TEXT_2 := Color("#A6A69B")
const TEXT_OFF := Color("#77786F")
const ACTION := Color(1, 1, 1, 1) ## actions and icons are white (GAUNTLET:61)
const DANGER := Color(0.88, 0.36, 0.30)
const TEST_BADGE := Color(0.86, 0.52, 0.16) ## the local test server, never mistaken for the live market

static var _backdrop: ShaderMaterial

## Every size the screens use, from the viewport (reference proportions, exchange-spec §1/§8).
## `px_per_pt`: canvas px per point on the glass. DisplayMode draws the narrowest phones (667x375)
## on an 804 px canvas, so a 44 px target there is 36 pt; `tmin` keeps every target 44 pt.
## `usable_w`: the width inside the safe area, which the rail and the category column share out.
static func metrics(view: Vector2, px_per_pt: float = 1.0, usable_w: float = -1.0) -> Dictionary:
	var uw := view.x if usable_w <= 0.0 else usable_w
	var compact := UiTokens.is_compact(view)
	var h := view.y
	var m := {}
	m.compact = compact
	m.tmin = ceilf(UiTokens.TARGET_MIN * maxf(1.0, px_per_pt))
	m.margin = 8.0 if compact else 16.0
	m.header_h = maxf(m.tmin, roundf(h * 0.106))
	m.edge_h = maxf(8.0, roundf(h * 0.019)) ## the references' torn band is ~2 % of the height
	m.rail_w = roundf(uw * 0.105)
	m.cat_w = roundf(uw * 0.29)
	m.thead_h = maxf(m.tmin, roundf(h * 0.068))
	m.row_h = maxf(m.tmin, roundf(h * 0.134)) ## the references' 13.6 %: 52 px at 390
	m.chip_h = m.tmin if compact else roundf(h * 0.07)
	m.pager_h = m.tmin if compact else 56.0
	# Reference sizes (1078 px tall shots): title 5.6 %, names and rows 3.4 %, headers 3 %, type lines 2.5 %.
	m.title = maxi(20, roundi(h * 0.052))
	m.name = maxi(15, roundi(h * 0.031))
	m.type = maxi(UiTokens.TYPE_MIN + 1, roundi(h * 0.024))
	m.head = maxi(14, roundi(h * 0.029))
	m.tab = maxi(14, roundi(h * 0.029))
	m.icon = roundf(m.row_h * (0.78 if compact else 0.6))
	return m

## Drawn text (title, rail, headers, rows, columns, tags) is Durango's condensed sans: the project's
## font squeezed to this width by the canvas transform, so glyphs and the gaps between them narrow
## evenly. (A FontVariation transform narrows outlines, not advances: wide letters left gaps.)
const CONDENSE := 0.85

## The project's font (no new font files). Labels and buttons use it as is.
static func font() -> Font:
	return ThemeDB.fallback_font

## The drawn width of `s` in condensed text (text() below).
static func width(s: String, size_px: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * CONDENSE

## Weathered earth behind the panels: soft blotches plus fine grain, no texture files and no
## NoiseTexture2D (it generates asynchronously on the web). As light as the references' green-tan
## (~0x5a a channel between panels), so the dark-rimmed panels sit on it like on a sheet.
static func backdrop() -> ShaderMaterial:
	if _backdrop == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform vec4 dark : source_color = vec4(0.26, 0.27, 0.19, 1.0);
uniform vec4 earth : source_color = vec4(0.5, 0.46, 0.34, 1.0);
uniform vec4 moss : source_color = vec4(0.4, 0.45, 0.3, 1.0);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = FRAGCOORD.xy / 260.0;
	float n = vn(p) * 0.55 + vn(p * 2.3 + 7.0) * 0.3 + vn(p * 5.1 + 3.0) * 0.15;
	float m = vn(p * 0.7 + 19.0);
	vec3 c = mix(dark.rgb, mix(earth.rgb, moss.rgb, m), smoothstep(0.25, 0.85, n));
	c *= 0.94 + 0.12 * h(floor(FRAGCOORD.xy));
	COLOR = vec4(c, 1.0);
}"""
		_backdrop = ShaderMaterial.new()
		_backdrop.shader = sh
	return _backdrop

## The rail, the category column, the table, the picker and My Market: a dark rim around a darker
## see-through fill, so the lighter backdrop reads as the sheet they sit on (references).
static func panel() -> StyleBoxFlat:
	return flat(PANEL_FILL, BORDER, 2, 6)

static func flat(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb

## A Button that draws nothing itself (rows, tabs and headers paint in _draw); keeps focus visible.
static func bare(b: Button) -> void:
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, none)
	b.add_theme_stylebox_override("focus", flat(Color(0, 0, 0, 0), GOLD, 2, 4))
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## Primary (yellow, dark text) or secondary (outlined, white text) action button.
static func action(b: Button, primary: bool, size_px: int) -> void:
	var fill := PRIMARY if primary else Color(0.08, 0.09, 0.08, 0.9)
	var edge := PRIMARY if primary else Color(0.85, 0.84, 0.78, 0.8)
	b.add_theme_stylebox_override("normal", flat(fill, edge, 2, 6))
	b.add_theme_stylebox_override("hover", flat(fill.lightened(0.08), edge, 2, 6))
	b.add_theme_stylebox_override("pressed", flat(fill.darkened(0.15), edge, 2, 6))
	b.add_theme_stylebox_override("disabled", flat(Color(0.35, 0.33, 0.25, 0.8) if primary else Color(0.08, 0.09, 0.08, 0.6), Color(0.45, 0.44, 0.4, 0.6), 2, 6))
	b.add_theme_stylebox_override("focus", flat(Color(0, 0, 0, 0), ACTION, 2, 6))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ink := PRIMARY_TEXT if primary else ACTION
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, ink)
	b.add_theme_color_override("font_disabled_color", TEXT_OFF)
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size_px)

static func label(text: String, size_px: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	size_label(l, size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A label's size, with the line pitch pulled back to ~1.3x the size: the project font's symbol and
## emoji fallbacks report a line height of ~2.1x (38 px at 18), which double-spaced every wrapped line.
static func size_label(l: Label, size_px: int) -> void:
	var px := maxi(UiTokens.TYPE_MIN, size_px)
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_constant_override("line_spacing", mini(0, roundi(px * 1.3 - font().get_height(px))))

## Condensed text in a box: ellipsized to the width, vertically centred on `mid_y`. True when it was cut.
static func text(ci: CanvasItem, s: String, x: float, mid_y: float, w: float, size_px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> bool:
	var f := font()
	var fit := UiTokens.ellipsis(f, s, w / CONDENSE, size_px)
	var base := mid_y + (f.get_ascent(size_px) - f.get_descent(size_px)) * 0.5
	var tw := width(fit, size_px)
	var dx := x + ((w - tw) * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else (w - tw if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0))
	ci.draw_set_transform(Vector2(dx, base), 0.0, Vector2(CONDENSE, 1.0))
	ci.draw_string(f, Vector2.ZERO, fit, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
	ci.draw_set_transform(Vector2.ZERO)
	return fit != s

static func dotted(ci: CanvasItem, a: Vector2, b: Vector2, color: Color = SEPARATOR, step := 5.0) -> void:
	var n := int(a.distance_to(b) / step)
	var d := (b - a).normalized() * step
	for i in n:
		var p := a + d * i
		ci.draw_rect(Rect2(p, Vector2(1.6, 1.6)), color)

## Four yellow L corners around `r` (the active tab, the reference's selection).
static func brackets(ci: CanvasItem, r: Rect2, arm: float, stroke: float, color: Color = GOLD) -> void:
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		ci.draw_rect(Rect2(corner.x + (0.0 if sx > 0 else -stroke), corner.y + (0.0 if sy > 0 else -arm), stroke, arm), color)
		ci.draw_rect(Rect2(corner.x + (0.0 if sx > 0 else -arm), corner.y + (0.0 if sy > 0 else -stroke), arm, stroke), color)

## The references' torn parchment band under the header: a light strip whose top edge is ripped
## into the black band in irregular bites, a few dark scuffs, and two dark rivet blobs. A
## deterministic hash, so it is the same every frame and in every shot.
static func torn_edge(ci: CanvasItem, y: float, w: float, h: float) -> void:
	var rnd := func (n: int, k: float) -> float: return fmod(absf(sin(n * 12.9898 + k) * 43758.5453), 1.0)
	var top := PackedVector2Array()
	var x := 0.0
	var i := 0
	while x < w:
		var bite := 1.0 if rnd.call(i, 3.1) > 0.82 else 0.0 # now and then a deep rip
		top.append(Vector2(x, y + h * (0.04 + 0.22 * rnd.call(i, 1.7) + 0.38 * bite)))
		x += 4.0 + 14.0 * rnd.call(i, 7.3)
		i += 1
	top.append(Vector2(w, y + h * 0.1))
	var band := top.duplicate()
	var j := 0
	x = w
	while x > 0.0: # a softer lower edge into the sheet
		band.append(Vector2(x, y + h * (0.86 + 0.14 * rnd.call(j, 5.9))))
		x -= 10.0 + 22.0 * rnd.call(j, 2.3)
		j += 1
	band.append(Vector2(0, y + h * 0.9))
	ci.draw_colored_polygon(band, PARCHMENT)
	ci.draw_polyline(top, Color(0.88, 0.85, 0.77, 0.8), 1.5) # the paper's lit edge
	for k in 9: # dark scuffs across the strip
		var sx: float = w * rnd.call(k, 9.1)
		var sw: float = w * (0.02 + 0.05 * rnd.call(k, 4.4))
		ci.draw_rect(Rect2(sx, y + h * (0.3 + 0.35 * rnd.call(k, 6.6)), sw, maxf(1.0, h * 0.12)), Color(0.25, 0.22, 0.16, 0.35))
	for f: float in [0.27, 0.77]: # rivet blobs
		ci.draw_set_transform(Vector2(w * f, y + h * 0.42), 0.0, Vector2(2.6, 1.0))
		ci.draw_circle(Vector2.ZERO, h * 0.32, Color(0.07, 0.06, 0.045, 0.95))
		ci.draw_set_transform(Vector2.ZERO)
