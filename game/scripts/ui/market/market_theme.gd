class_name MarketTheme
extends RefCounted
## The Island Market's look (spec 13 palette, spec 14 references): colours, per-viewport metrics,
## the condensed font (drawn text, labels and buttons alike), the weathered backdrop and textured
## cards, the torn paper sheet, and the shared draw helpers (dotted separators, yellow L brackets).
# swap: INVUI InvTheme / InvPaint / inv_grain when they land (same palette, same helpers).

const BG := Color("#101714")
const HEADER := Color("#0B0C0E")
const PANEL := Color("#39392F")
const PANEL_2 := Color("#26322C")
const BAND := Color(0.03, 0.035, 0.03, 0.55) ## table header / column title band over the panel
const SEPARATOR := Color(0.62, 0.60, 0.53, 0.45) ## dotted row lines
const BORDER := Color(0.04, 0.04, 0.025, 0.9) ## the references' panels sit in a thin dark rim, not a light stroke
const PANEL_FILL := Color(0.05, 0.055, 0.035, 0.42) ## rail, columns, table: the backdrop shows through, darker
const PARCHMENT := Color(0.69, 0.65, 0.55) ## dialog title bands (the Bag's tan name band)
const PAPER := Color(0.71, 0.70, 0.62, 0.92) ## the torn sheet: pale grey-green paper the backdrop tints a little
const GOLD := Color("#E6BE54") ## names, selection, brackets, the active tab
const PRIMARY := Color("#F2C84C") ## primary button fill (dark text)
const PRIMARY_TEXT := Color("#1B1A14")
const TEXT := Color("#ECEBE4")
const TEXT_2 := Color("#A6A69B")
const TEXT_OFF := Color("#77786F")
const LV := Color(0.6, 0.6, 0.56, 0.8) ## the Bag's dim "Lv. n" in a cell corner: it recedes behind the art
const ACTION := Color(1, 1, 1, 1) ## actions and icons are white (GAUNTLET:61)
const DANGER := Color(0.88, 0.36, 0.30)

static var _backdrop: ShaderMaterial
static var _card: ShaderMaterial
static var _paper: ShaderMaterial
static var _fields := {} ## size px -> the condensed FontVariation of a text field

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

## The project's UI font (no new font files) without the symbol and emoji fallbacks Game adds: a
## shaped line takes the tallest fallback's metrics, so every one-line label stood ~2.1x its size
## (38 px at 18 against 26) and the Sell preview went under List. Market text needs none of them:
## account names are letters, digits, space, _ and - (MarketEngine), item names are ASCII, and the
## few symbols used (· × – — … ‹ ›) are in the base font ("×" for the chip, no "✕" or "→").
static func font() -> Font:
	var fv := ThemeDB.fallback_font as FontVariation # Game's wrapper; plain before Game installs it
	return fv.base_font if fv != null and fv.base_font != null else ThemeDB.fallback_font

## The drawn width of `s` in condensed text (text() below).
static func width(s: String, size_px: int) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * CONDENSE

## Hash and value noise shared by the market's shaders (no texture files, no NoiseTexture2D: it
## generates asynchronously on the web).
const NOISE := """
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
vec3 earth_at(vec2 px) {
	vec2 p = px / 260.0;
	float n = vn(p) * 0.55 + vn(p * 2.3 + 7.0) * 0.3 + vn(p * 5.1 + 3.0) * 0.15;
	float m = vn(p * 0.7 + 19.0);
	vec3 c = mix(vec3(0.26, 0.27, 0.19), mix(vec3(0.5, 0.46, 0.34), vec3(0.4, 0.45, 0.3), m), smoothstep(0.25, 0.85, n));
	return c * (0.94 + 0.12 * h(floor(px)));
}
"""

## Weathered earth behind the panels: soft blotches plus fine grain. As light as the references'
## green-tan (~0x5a a channel between panels), so the dark-rimmed panels sit on it like on a sheet.
static func backdrop() -> ShaderMaterial:
	if _backdrop == null:
		_backdrop = _shader("shader_type canvas_item;\n" + NOISE + "void fragment() { COLOR = vec4(earth_at(FRAGCOORD.xy), 1.0); }")
	return _backdrop

## The rail, the category column, the table, the picker and My Market: a dark rim around a darker
## see-through fill, so the lighter backdrop reads as the sheet they sit on (references).
static func panel() -> StyleBoxFlat:
	return flat(PANEL_FILL, BORDER, 2, 6)

## Sell's panel, the confirm, the search sheet and the offline card: the list panels' textured look
## on a panel of their own. The card's shader lays the same earth under the stylebox's colours
## (its fill darkens it like the see-through panels, its rim stays dark), so a card over the dimmed
## list keeps the texture instead of a flat near-black fill (fidelity r2).
static func card(p: PanelContainer, margin: int) -> void:
	var sb := panel()
	sb.anti_aliasing = false # a feathered edge would come out as an opaque earth ring
	sb.set_content_margin_all(margin)
	p.add_theme_stylebox_override("panel", sb)
	if _card == null:
		_card = _shader("shader_type canvas_item;\n" + NOISE + "void fragment() { COLOR = vec4(mix(earth_at(FRAGCOORD.xy), COLOR.rgb, COLOR.a), 1.0); }")
	p.material = _card

## The references' torn paper: the band under the header with a rough, fibrous rip into the black,
## grime and two dark nail heads, carried on as the frame round the body (`hole` is the body, see
## through). Uniforms in the sheet's own px: size, tear (the ragged zone's height), hole (x0, y0, x1, y1).
static func paper() -> ShaderMaterial:
	if _paper == null:
		_paper = _shader("shader_type canvas_item;\n" + NOISE + """
uniform vec2 size = vec2(100.0);
uniform float tear = 16.0;
uniform vec4 hole = vec4(0.0);
uniform vec4 paper : source_color = vec4(0.71, 0.70, 0.62, 0.92);
float fbm(vec2 p) { return vn(p) * 0.5 + vn(p * 2.03 + 5.0) * 0.27 + vn(p * 4.1 + 11.0) * 0.15 + vn(p * 8.3 + 2.0) * 0.08; }
void fragment() {
	vec2 p = UV * size;
	float rip = smoothstep(0.78, 0.95, vn(vec2(p.x / 60.0, 9.0)));
	float e = tear * (0.12 + 0.38 * fbm(vec2(p.x / 34.0, 1.3)) + 0.2 * vn(vec2(p.x / 5.0, 7.1)) + 0.1 * h(vec2(floor(p.x / 1.5), 3.0)) + 0.3 * rip);
	float a = smoothstep(e - 0.75, e + 0.75, p.y);
	if (p.x > hole.x && p.x < hole.z && p.y > hole.y && p.y < hole.w) { a = 0.0; }
	float fib = vn(vec2(p.x / 70.0, p.y / 2.5));
	float blot = fbm(p / 38.0 + 3.0);
	vec3 c = paper.rgb * (0.84 + 0.16 * fib) * (0.9 + 0.12 * h(floor(p)));
	c = mix(c, vec3(0.3, 0.29, 0.22), smoothstep(0.5, 0.8, blot) * 0.6);
	float d = p.y - e;
	c *= mix(0.62, 1.0, smoothstep(0.0, 5.0, d)); // the rip's dirty lip
	c += vec3(0.16) * (1.0 - smoothstep(0.0, 1.6, abs(d - 0.6))) * step(0.5, vn(vec2(p.x / 3.0, 2.0))); // lit fibres on the edge
	for (int i = 0; i < 2; i++) { // nail heads on the band
		vec2 q = (p - vec2(size.x * mix(0.27, 0.77, float(i)), tear * 0.55)) / vec2(tear * 1.1, tear * 0.42);
		float r = dot(q, q);
		c = mix(c, vec3(0.07, 0.06, 0.045), 1.0 - smoothstep(0.85, 1.0, r));
		a = max(a, 1.0 - smoothstep(0.85, 1.0, r));
	}
	COLOR = vec4(c, a * paper.a);
}""")
		_paper.set_shader_parameter("paper", PAPER)
	return _paper.duplicate() as ShaderMaterial # its own uniforms per sheet, one compiled shader

static func _shader(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

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
	ink(b, PRIMARY_TEXT if primary else ACTION)
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size_px)

## A button's words in `color` (TEXT_OFF when disabled), drawn condensed: the button's own text is
## made transparent and keeps sizing it, so only the glyphs change.
static func ink(b: Button, color: Color, off: Color = TEXT_OFF) -> void:
	b.set_meta(&"ink", color)
	b.set_meta(&"ink_off", off)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(k, Color(0, 0, 0, 0))
	condense(b)
	b.queue_redraw()

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
	condense(l)

## One typeface everywhere (fidelity r2: dialog labels were the wide font next to condensed lists).
## A label or button keeps its own layout (wrap, minimum size, alignment box); its glyphs are hidden
## (a label shows 0 characters after shaping, a button's ink is transparent) and drawn again, narrow,
## by the canvas transform. Wrapped text breaks at the condensed width, so it fills the box.
static func condense(c: Control) -> void:
	if c.has_meta(&"condensed"):
		return
	c.set_meta(&"condensed", true)
	if c is Label:
		(c as Label).visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		(c as Label).visible_characters = 0
		c.draw.connect(_draw_label.bind(c))
	elif c is Button:
		c.draw.connect(_draw_button.bind(c))

static func _draw_label(l: Label) -> void:
	if l.text == "":
		return
	var p := TextParagraph.new()
	p.add_string(l.text, font(), l.get_theme_font_size(&"font_size"))
	p.width = l.size.x / CONDENSE
	p.alignment = l.horizontal_alignment
	p.break_flags = TextServer.BREAK_MANDATORY | (TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE if l.autowrap_mode != TextServer.AUTOWRAP_OFF else 0)
	p.max_lines_visible = l.max_lines_visible
	p.line_spacing = l.get_theme_constant(&"line_spacing")
	if l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or l.clip_text:
		p.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var y := 0.0
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y = (l.size.y - p.get_size().y) * 0.5
	elif l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y = l.size.y - p.get_size().y
	l.draw_set_transform(Vector2(0, roundf(y)), 0.0, Vector2(CONDENSE, 1.0))
	p.draw(l.get_canvas_item(), Vector2.ZERO, l.get_theme_color(&"font_color"))
	l.draw_set_transform(Vector2.ZERO)

static func _draw_button(b: Button) -> void:
	if b.text == "":
		return
	var sb := b.get_theme_stylebox(&"normal")
	var x := sb.get_margin(SIDE_LEFT) if sb else 0.0
	var w := b.size.x - x - (sb.get_margin(SIDE_RIGHT) if sb else 0.0)
	var col: Color = b.get_meta(&"ink_off", TEXT_OFF) if b.disabled else b.get_meta(&"ink", ACTION)
	text(b, b.text, x, b.size.y * 0.5, w, b.get_theme_font_size(&"font_size"), col, HORIZONTAL_ALIGNMENT_CENTER)

## A text field's font: the same narrow face as a FontVariation (a field draws its own text). Its
## transform narrows the outlines and the spacing pulls the advances back by what they lost on an
## average glyph (Open Sans digits share one advance, so a price field closes up evenly).
static func field_font(size_px: int) -> Font:
	if not _fields.has(size_px):
		var fv := FontVariation.new()
		fv.base_font = font()
		fv.variation_transform = Transform2D(Vector2(CONDENSE, 0), Vector2(0, 1), Vector2.ZERO)
		fv.spacing_glyph = -roundi(font().get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * (1.0 - CONDENSE))
		_fields[size_px] = fv
	return _fields[size_px]

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
