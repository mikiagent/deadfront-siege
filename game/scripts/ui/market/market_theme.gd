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
const BORDER := Color(0.36, 0.35, 0.31, 0.9)
const GOLD := Color("#E6BE54") ## names, selection, brackets, the active tab
const PRIMARY := Color("#F2C84C") ## primary button fill (dark text)
const PRIMARY_TEXT := Color("#1B1A14")
const TEXT := Color("#ECEBE4")
const TEXT_2 := Color("#A6A69B")
const TEXT_OFF := Color("#77786F")
const ACTION := Color(1, 1, 1, 1) ## actions and icons are white (GAUNTLET:61)
const DANGER := Color(0.88, 0.36, 0.30)
const TEST_BADGE := Color(0.86, 0.52, 0.16) ## the local test server, never mistaken for the live market

static var _font: FontVariation
static var _backdrop: ShaderMaterial

## Every size the screens use, from the viewport (reference proportions, exchange-spec §1/§8).
static func metrics(view: Vector2) -> Dictionary:
	var compact := UiTokens.is_compact(view)
	var h := view.y
	var m := {}
	m.compact = compact
	m.margin = 8.0 if compact else 16.0
	m.header_h = maxf(UiTokens.TARGET_MIN, roundf(h * 0.106))
	m.edge_h = 6.0 if compact else 9.0
	m.rail_w = roundf(view.x * 0.105)
	m.cat_w = roundf(view.x * 0.29)
	m.thead_h = maxf(UiTokens.TARGET_MIN, roundf(h * 0.068))
	m.row_h = 48.0 if compact else roundf(h * 0.136)
	m.chip_h = UiTokens.TARGET_MIN if compact else roundf(h * 0.07)
	m.pager_h = UiTokens.TARGET_MIN if compact else 56.0
	m.title = maxi(20, roundi(h * 0.045))
	m.name = maxi(14, roundi(h * 0.029))
	m.type = maxi(UiTokens.TYPE_MIN, roundi(h * 0.022))
	m.head = maxi(13, roundi(h * 0.026))
	m.tab = maxi(13, roundi(h * 0.027))
	m.icon = roundf(m.row_h * (0.78 if compact else 0.6))
	return m

## Durango's condensed sans: the project's fallback font narrowed (no new font files).
static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_transform = Transform2D(Vector2(0.92, 0), Vector2(0, 1), Vector2.ZERO)
		_font.spacing_glyph = -1 # the transform narrows outlines, not advances: pull the letters back together
	return _font

## Weathered earth behind the panels: soft blotches plus fine grain, no texture files and no
## NoiseTexture2D (it generates asynchronously on the web).
static func backdrop() -> ShaderMaterial:
	if _backdrop == null:
		var sh := Shader.new()
		sh.code = """shader_type canvas_item;
uniform vec4 dark : source_color = vec4(0.12, 0.115, 0.09, 1.0);
uniform vec4 earth : source_color = vec4(0.37, 0.31, 0.21, 1.0);
uniform vec4 moss : source_color = vec4(0.27, 0.30, 0.19, 1.0);
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
	l.add_theme_font_override("font", font())
	size_label(l, size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## A label's size, with the line pitch pulled back to ~1.3x the size: the project font's symbol and
## emoji fallbacks report a line height of ~2.1x (38 px at 18), which double-spaced every wrapped line.
static func size_label(l: Label, size_px: int) -> void:
	var px := maxi(UiTokens.TYPE_MIN, size_px)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_constant_override("line_spacing", mini(0, roundi(px * 1.3 - font().get_height(px))))

## Text in a box: ellipsized to the width, vertically centred on `mid_y`.
static func text(ci: CanvasItem, s: String, x: float, mid_y: float, width: float, size_px: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := font()
	var fit := UiTokens.ellipsis(f, s, width, size_px)
	var base := mid_y + (f.get_ascent(size_px) - f.get_descent(size_px)) * 0.5
	ci.draw_string(f, Vector2(x, base), fit, align, width, size_px, color)

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

## The light ragged band under the header: a deterministic jitter, the same every frame.
static func torn_edge(ci: CanvasItem, y: float, w: float, h: float) -> void:
	var pts := PackedVector2Array([Vector2(0, y)])
	var x := 0.0
	var i := 0
	while x < w:
		x = minf(w, x + 7.0 + fmod(float(i) * 13.7, 11.0))
		var jag := fmod(float(i) * 37.3, 1.0)
		pts.append(Vector2(x, y + h * (0.35 + 0.65 * jag)))
		i += 1
	pts.append(Vector2(w, y))
	ci.draw_colored_polygon(pts, Color(0.66, 0.62, 0.52, 0.9))
	ci.draw_rect(Rect2(0, y, w, 2.0), Color(0.84, 0.8, 0.7, 0.75))
