class_name SailNode
extends BaseButton
## One island on the Sail chart (SailScreen, spec 15 "The Sail menu"): a round sea marker with ripple
## rings and the island's climate art, its name and Lv. under it, and a badge: a green check once you
## have sailed there, "?" while you never have. While Survival is too low it also carries a lock and
## "Survival N". Home is a house; a red pin marks the island you stand on. Everything is drawn here
## (no art files). Pressing it opens the island's card; it stays enabled while locked so the card can
## say why. mouse_filter PASS lets a drag that starts on a node scroll the chart.

const DISC := {
	"grassland": Color("#8DB36A"), "savannah": Color("#D9B56E"), "temperate": Color("#8FC27A"),
	"tropical": Color("#5BC2A8"), "tundra": Color("#B9D3DE"), "desert": Color("#E6C487"),
	"swamp": Color("#7E8C55"), "volcanic": Color("#A0523D"),
}
const GOOD := Color("#67B84E")
const UNKNOWN := Color("#33475A")
const GOLD := Color("#F2C84C")
const TAN := Color("#CAAD69")
const TEXT := Color("#ECEBE4")
const TEXT_2 := Color("#A6A69B")
const LOCKED := Color("#F08A70")
const PIN := Color("#D8432F")
const OUTLINE := Color(0, 0, 0, 0.78)

static var _font: FontVariation

var island_id: StringName = &""
var title := ""
var tier := 0
var climate := ""
var home := false
var here := false
var visited := false
var locked := false
var need := 0
## Draw the name lines under the disc (the chart); the card's small copy is the disc alone.
var show_labels := true
var d := 72.0
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var _m: Dictionary = {}

## The condensed face of the Durango screens (INVUI's InvTheme.font(), matched until it merges).
static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = ThemeDB.fallback_font
		_font.variation_transform = Transform2D(Vector2(0.9, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
	return _font

## Node height on the chart for SailScreen.metrics() `m`: the disc and three text lines.
static func height_for(m: Dictionary) -> float:
	return float(m.d) + float(m.gap) + float(int(m.name_px) + int(m.lv_px) + int(m.need_px)) * 1.25

func setup(e: Dictionary, m: Dictionary) -> void:
	_m = m
	island_id = StringName(str(e.id))
	title = str(e.name)
	tier = int(e.tier)
	climate = str(e.climate)
	home = bool(e.home)
	here = bool(e.here)
	visited = bool(e.visited)
	locked = bool(e.locked)
	need = int(e.need)
	d = float(m.d)
	name = "Node_%s" % island_id
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "%s  %s" % [title, LevelDisplay.label(tier)]
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

## "check" once sailed there, "?" while never.
func badge() -> String:
	return "check" if visited else "?"

## Disc centre in this control.
func disc_center() -> Vector2:
	return Vector2(size.x * 0.5, d * 0.5) if show_labels else size * 0.5

func _draw() -> void:
	var r := d * 0.5
	var c := disc_center()
	if show_labels:
		draw_arc(c, r * 1.3, 0.0, TAU, 48, Color(1, 1, 1, 0.13), 2.0, true)
		draw_arc(c, r * 1.15, 0.0, TAU, 48, Color(1, 1, 1, 0.24), 2.0, true)
		draw_circle(c + Vector2(0, r * 0.1), r, Color(0, 0, 0, 0.35))
	var disc: Color = DISC.get(climate, DISC["grassland"])
	draw_circle(c, r, disc.darkened(0.25) if locked else disc)
	_draw_art(c, r * 0.62)
	if locked:
		draw_circle(c, r, Color(0.04, 0.05, 0.07, 0.3))
	var lit := selected or has_focus() or (is_hovered() and not locked)
	draw_arc(c, r, 0.0, TAU, 64, GOLD if lit else Color(TEXT, 0.85), 5.0 if lit else 3.0, true)
	if here:
		_draw_pin(c + Vector2(-r * 0.72, -r * 0.62), r * 0.34)
	var br := maxf(11.0, r * 0.3)
	var bc := c + Vector2(r * 0.74, -r * 0.74)
	draw_circle(bc, br + 1.5, Color(0, 0, 0, 0.6))
	if visited:
		draw_circle(bc, br, GOOD)
		_icon(&"confirm", bc, br * 1.3)
	else:
		draw_circle(bc, br, UNKNOWN)
		_text_c(bc + Vector2(0, br * 0.42), "?", maxi(12, int(br * 1.3)), Color.WHITE, false)
	if locked:
		var lc := c + Vector2(r * 0.74, r * 0.74)
		draw_circle(lc, br + 1.5, Color(0, 0, 0, 0.6))
		draw_circle(lc, br, Color("#22262B"))
		_icon(&"lock", lc, br * 1.25)
	if not show_labels:
		return
	var f := font()
	var y := d + float(_m.gap)
	var name_px := int(_m.name_px)
	var lv_px := int(_m.lv_px)
	var need_px := int(_m.need_px)
	y += float(name_px) * 1.05
	var fit := name_px  # a long name steps down to the 12 px floor before it is cut short
	while fit > UiTokens.TYPE_MIN and f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fit).x > size.x - 4.0:
		fit -= 1
	_text_c(Vector2(size.x * 0.5, y), UiTokens.ellipsis(f, title, size.x - 4.0, fit), fit, TEXT, true)
	y += float(lv_px) * 1.25
	_text_c(Vector2(size.x * 0.5, y), LevelDisplay.label(tier), lv_px, TAN, true)
	y += float(need_px) * 1.25
	if locked:
		_text_c(Vector2(size.x * 0.5, y), "Survival %d" % need, need_px, LOCKED, true)
	elif here:
		_text_c(Vector2(size.x * 0.5, y), "You are here", need_px, TEXT_2, true)

## Text centred on x at baseline y, with a dark outline so it reads on light and dark sea.
func _text_c(at: Vector2, text: String, px: int, col: Color, outline: bool) -> void:
	var f := font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pos := Vector2(at.x - w * 0.5, at.y)
	if outline:
		draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4, OUTLINE)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)

func _icon(id: StringName, at: Vector2, s: float) -> void:
	var tex := UiIcons.icon(id)
	if tex:
		draw_texture_rect(tex, Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)), false)

func _draw_pin(tip: Vector2, s: float) -> void:
	var head := tip + Vector2(0, -s * 1.5)
	draw_colored_polygon(PackedVector2Array([tip, head + Vector2(-s * 0.86, s * 0.5), head + Vector2(s * 0.86, s * 0.5)]), PIN)
	draw_circle(head, s, PIN)
	draw_arc(head, s, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 1.5, true)
	draw_circle(head, s * 0.4, Color.WHITE)

static func _ellipse(c: Vector2, rad: Vector2, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	return pts

## Climate art inside the disc, `s` = half its size: Durango's palm / umbrella tree / snowy pine idea.
func _draw_art(c: Vector2, s: float) -> void:
	var bark := Color("#5A3E2B")
	match climate:
		"savannah":  # umbrella tree on dry ground
			draw_line(c + Vector2(-s * 0.95, s * 0.8), c + Vector2(s * 0.95, s * 0.8), Color("#8A6A3A"), s * 0.14, true)
			draw_line(c + Vector2(0, s * 0.8), c + Vector2(0, -s * 0.15), bark, s * 0.15, true)
			draw_line(c + Vector2(0, s * 0.15), c + Vector2(-s * 0.48, -s * 0.32), bark, s * 0.1, true)
			draw_line(c + Vector2(0, s * 0.15), c + Vector2(s * 0.5, -s * 0.34), bark, s * 0.1, true)
			draw_colored_polygon(_ellipse(c + Vector2(0, -s * 0.45), Vector2(s * 0.98, s * 0.3)), Color("#5E6B2E"))
			draw_colored_polygon(_ellipse(c + Vector2(-s * 0.15, -s * 0.55), Vector2(s * 0.6, s * 0.16)), Color("#76843A"))
		"temperate":  # broadleaf tree
			draw_line(c + Vector2(0, s * 0.85), c + Vector2(0, -s * 0.1), bark, s * 0.2, true)
			draw_circle(c + Vector2(-s * 0.38, -s * 0.2), s * 0.45, Color("#2F6A2A"))
			draw_circle(c + Vector2(s * 0.38, -s * 0.2), s * 0.45, Color("#2F6A2A"))
			draw_circle(c + Vector2(0, -s * 0.52), s * 0.5, Color("#3C7F34"))
			draw_circle(c + Vector2(-s * 0.12, -s * 0.66), s * 0.2, Color("#5A9C4A"))
		"tropical":  # palm
			var top := c + Vector2(-s * 0.1, -s * 0.42)
			draw_polyline(PackedVector2Array([c + Vector2(s * 0.25, s * 0.9), c + Vector2(s * 0.12, s * 0.25), top]), Color("#7A5533"), s * 0.15, true)
			for a in [-2.7, -2.2, -1.6, -0.95, -0.45]:
				var dir := Vector2(cos(a), sin(a))
				var mid := top + dir * s * 0.5 + Vector2(0, -s * 0.05)
				var end := top + dir * s * 0.92 + Vector2(0, s * 0.3)
				draw_polyline(PackedVector2Array([top, mid, end]), Color("#2E7D4A"), s * 0.16, true)
			draw_circle(top + Vector2(s * 0.08, s * 0.12), s * 0.1, Color("#5A3E2B"))
		"tundra":  # snowy pine
			draw_line(c + Vector2(0, s * 0.9), c + Vector2(0, s * 0.55), bark, s * 0.18, true)
			for i in 3:
				var y := s * (0.6 - 0.48 * float(i))
				var w := s * (0.85 - 0.22 * float(i))
				var apex := c + Vector2(0, y - s * 0.62)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-w, y), apex, c + Vector2(w, y)]), Color("#1F4A3A"))
				draw_colored_polygon(PackedVector2Array([apex + Vector2(-w * 0.42, s * 0.26), apex, apex + Vector2(w * 0.42, s * 0.26)]), Color("#F4F8FA"))
		"desert":  # cactus on a dune
			draw_colored_polygon(_ellipse(c + Vector2(s * 0.1, s * 1.05), Vector2(s * 1.1, s * 0.42)), Color("#C99A55"))
			var green := Color("#3E7A3A")
			draw_line(c + Vector2(0, s * 0.75), c + Vector2(0, -s * 0.7), green, s * 0.3, true)
			draw_circle(c + Vector2(0, -s * 0.7), s * 0.15, green)
			draw_polyline(PackedVector2Array([c + Vector2(0, s * 0.15), c + Vector2(-s * 0.45, s * 0.15), c + Vector2(-s * 0.45, -s * 0.35)]), green, s * 0.2, true)
			draw_circle(c + Vector2(-s * 0.45, -s * 0.35), s * 0.1, green)
			draw_polyline(PackedVector2Array([c + Vector2(0, -s * 0.1), c + Vector2(s * 0.42, -s * 0.1), c + Vector2(s * 0.42, -s * 0.5)]), green, s * 0.2, true)
			draw_circle(c + Vector2(s * 0.42, -s * 0.5), s * 0.1, green)
		"swamp":  # reeds and cattails over dark water
			draw_colored_polygon(_ellipse(c + Vector2(0, s * 0.72), Vector2(s * 0.95, s * 0.22)), Color("#3E4F3A"))
			for i in 4:
				var x := s * (-0.5 + 0.33 * float(i))
				var h := s * (0.95 + 0.25 * float(i % 2))
				draw_line(c + Vector2(x, s * 0.72), c + Vector2(x + s * 0.06, s * 0.72 - h), Color("#4F6B2E"), s * 0.09, true)
				draw_colored_polygon(_ellipse(c + Vector2(x + s * 0.04, s * 0.72 - h * 0.72), Vector2(s * 0.09, s * 0.22), 12), Color("#6B4628"))
		"volcanic":  # cone, lava and smoke
			draw_circle(c + Vector2(s * 0.15, -s * 0.85), s * 0.22, Color(0.85, 0.85, 0.85, 0.85))
			draw_circle(c + Vector2(-s * 0.1, -s * 0.62), s * 0.18, Color(0.75, 0.75, 0.75, 0.85))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.95, s * 0.85), c + Vector2(-s * 0.28, -s * 0.38), c + Vector2(s * 0.28, -s * 0.38), c + Vector2(s * 0.95, s * 0.85)]), Color("#3A2A26"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.28, -s * 0.38), c + Vector2(s * 0.28, -s * 0.38), c + Vector2(s * 0.12, -s * 0.05), c + Vector2(0, s * 0.3), c + Vector2(-s * 0.14, -s * 0.08)]), Color("#E8692A"))
		_:  # home: a house
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.62, s * 0.8), c + Vector2(-s * 0.62, -s * 0.05), c + Vector2(s * 0.62, -s * 0.05), c + Vector2(s * 0.62, s * 0.8)]), Color("#F1E6CF"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.85, 0.0), c + Vector2(0, -s * 0.78), c + Vector2(s * 0.85, 0.0)]), Color("#B5482F"))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.18, s * 0.8), c + Vector2(-s * 0.18, s * 0.3), c + Vector2(s * 0.18, s * 0.3), c + Vector2(s * 0.18, s * 0.8)]), Color("#5A3E2B"))
