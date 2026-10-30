class_name HudStomach
extends RefCounted
## HUDRULES (owner 2026-10-28): the stomach indicator right of the health bar. Round 3 (owner: "it should be a
## circular bar where red is too full stomach, green is full, yellow is hungry, and red (again) is empty
## stomach. The stomach icon should change depending on hunger. Saturation is a yellow circular bar outside
## that is like a cooldown until you start getting hungry again"):
##   inner ring  the stored stomach in points, coloured by band and blended between the edges (STOPS);
##   glyph       a stomach drawing by state (GLYPH, `_src/icons_p.py`; fed and well fed share one, sized apart);
##   outer ring  the meal buff's time left: fullness above the off line over the decay rate.
## HUNGER (owner-approved memo 2026-10-29 Part 1 s1.4 step 4): "The HUD saturation ring (outer yellow ring)
## shows how long the buff has left, so it finally says something the player cares about." The inner ring
## reads Digestion.fullness() (a saved value that decays 2.5 points a minute), and the outer ring is only lit
## while a while_fed meal buff is on. It only reads the food system; no hunger rule lives here.

const TRACK := Color(0.08, 0.08, 0.1, 0.9)
## Colour stops in stomach points, blended linearly between them: red empty, yellow peckish, green fed
## and well fed, red overfull. The edges are the data's (rules.json hunger.*, read through Digestion), so
## a tuning pass moves the ring with the bands; HUNGER memo 2026-10-29 s1.4 step 4.
static var _stops_cache: Array = []

static func stops() -> Array:
	if not _stops_cache.is_empty():
		return _stops_cache
	var empty := Digestion.hunger_num("empty_below", Digestion.EMPTY_BELOW)
	var peckish := Digestion.hunger_num("peckish_below", Digestion.PECKISH_BELOW)
	var fed := Digestion.hunger_num("fed_below", Digestion.FED_BELOW)
	var well := Digestion.hunger_num("well_fed_below", Digestion.WELL_FED_BELOW)
	# The plateaus keep their own lengths: yellow across peckish and the first half of fed, then green
	# through fed and well fed, so the ring never shows a muddy blend in the middle of a band.
	_stops_cache = [[0.0, UiTokens.STOMACH_EMPTY], [empty, UiTokens.STOMACH_EMPTY],
		[peckish, UiTokens.STOMACH_HUNGRY], [peckish + (fed - peckish) * 0.5, UiTokens.STOMACH_HUNGRY],
		[fed, UiTokens.STOMACH_FULL], [well, UiTokens.STOMACH_FULL],
		[Digestion.OVERFULL_MAX, UiTokens.STOMACH_OVERFULL]]
	return _stops_cache

## The glyph's drawn size per state (owner: "empty stomach looks shrunk, full stomach looks big"); HuntHud
## eases the drawn scale toward it (SCALE_SPEED per second) so a state change grows or shrinks the glyph.
const GLYPH_SCALE := {&"empty": 0.92, &"peckish": 0.95, &"fed": 0.98, &"well_fed": 1.0, &"overfull": 1.06}
const SCALE_SPEED := 0.6
const GLYPH := {&"empty": &"stomach_empty", &"peckish": &"stomach_hungry", &"fed": &"stomach",
	&"well_fed": &"stomach", &"overfull": &"stomach_overfull"}

## How full she is, in stomach points (0 = empty, 100 = a full stomach, above that overfull).
static func fullness_of(p: Player) -> float:
	var dig := Digestion.of(p)
	return dig.fullness() if dig else 0.0

## 0..1 of the meal buff's time left (Digestion.saturation; 0 when no while_fed buff is on).
static func saturation_of(p: Player) -> float:
	var dig := Digestion.of(p)
	return dig.saturation(p) if dig else 0.0

static func state_of(f: float) -> StringName:
	return Digestion.state_for(f)

## The colour for a stomach value in points.
static func color_for(f: float) -> Color:
	var table := stops()
	for i in range(1, table.size()):
		var hi: Array = table[i]
		if f <= float(hi[0]):
			var lo: Array = table[i - 1]
			var t := clampf((f - float(lo[0])) / maxf(0.0001, float(hi[0]) - float(lo[0])), 0.0, 1.0)
			return (lo[1] as Color).lerp(hi[1] as Color, t)
	return table[table.size() - 1][1]

## The arc still lit for `frac` (owner: "degrades clockwise"): it always ends at 12 o'clock, and the gap
## opens from 12 o'clock clockwise as it empties. Returns (start, end) angles, end - start = TAU * frac.
static func arc_for(frac: float) -> Vector2:
	var f := clampf(frac, 0.0, 1.0)
	return Vector2(-PI * 0.5 + TAU * (1.0 - f), -PI * 0.5 + TAU)

## The rings centred on `c` (outer radius `rad`), each lit from where its clockwise gap ends round to
## 12 o'clock; `fullness` is in points; `glyph_scale` sizes the stomach. Returns the box.
static func draw(ci: CanvasItem, c: Vector2, rad: float, fullness: float, saturation: float, glyph_scale: float = 1.0) -> Rect2:
	# Both rings are yellow at times (peckish, fed time left), so they differ in weight: a thin outer ring
	# past a dark gap, a thick inner one.
	var sw := maxf(2.0, rad * 0.1)    # outer meal-buff ring
	var w := maxf(4.0, rad * 0.27)    # inner stomach ring
	var r_in := rad - sw - 2.5 - w * 0.5
	ci.draw_circle(c + Vector2(0, 1.5), rad + 1.5, Color(0, 0, 0, 0.45), true, -1.0, true)  # LEVELBADGE: its own shadow, no panel
	ci.draw_circle(c, rad, UiTokens.HUD_FILL)
	ci.draw_arc(c, rad - sw * 0.5, 0.0, TAU, 40, Color(UiTokens.SATURATION, 0.18), sw, true)
	if saturation > 0.0:
		var sa := arc_for(saturation)
		ci.draw_arc(c, rad - sw * 0.5, sa.x, sa.y, maxi(4, int(40.0 * saturation)), UiTokens.SATURATION, sw, true)
	ci.draw_arc(c, r_in, 0.0, TAU, 40, TRACK, w, true)
	if fullness < Digestion.EMPTY_BELOW:  # empty reads red even with nothing to fill
		ci.draw_arc(c, r_in, 0.0, TAU, 40, Color(UiTokens.STOMACH_EMPTY, 0.45), w, true)
	var fill := clampf(fullness / maxf(1.0, Digestion.cap()), 0.0, 1.0)
	if fill > 0.0:
		var fa := arc_for(fill)
		ci.draw_arc(c, r_in, fa.x, fa.y, maxi(4, int(40.0 * fill)), color_for(fullness), w, true)
	var g := (r_in - w * 0.5) * 1.6 * glyph_scale
	var id: StringName = GLYPH[state_of(fullness)]
	var tex := UiIcons.icon(id) if UiIcons.path_for(id) != "" else null
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1, 1, 1, 0.95))
	return Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
