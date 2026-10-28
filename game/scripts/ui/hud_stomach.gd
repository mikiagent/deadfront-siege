class_name HudStomach
extends RefCounted
## HUDRULES (owner 2026-10-28): the stomach indicator right of the health bar. Round 3 (owner: "it should be a
## circular bar where red is too full stomach, green is full, yellow is hungry, and red (again) is empty
## stomach. The stomach icon should change depending on hunger. Saturation is a yellow circular bar outside
## that is like a cooldown until you start getting hungry again"):
##   inner ring  fullness, coloured by state and blended between the bands (STOPS);
##   glyph       a stomach drawing by state (GLYPH, `_src/icons_p.py`; normal and full share one, sized apart);
##   outer ring  saturation, yellow, draining like a cooldown while the last meal digests.
## It only reads the food system; no hunger rule changes.
# ASSUMPTION: this build has no satiety meter (PRD :72/:1030, survival-needs.md "Food & relief"). Fullness is
# what is still in her stomach: each digesting meal's foods.json `fullness` (0-100 scale, cap
# `defaults.caps.fullness`) times the share of its Energy still undigested, summed, over the cap. Above
# 1.0 she has eaten more than a full stomach holds (overfull). Saturation is the longest digestion row's
# time left over its digest time: full on a fresh meal, empty when nothing digests.

const TRACK := Color(0.08, 0.08, 0.1, 0.9)
## Colour stops: red empty, yellow hungry, green full, red overfull, blended linearly between them.
## Band edges live in Digestion (the survival model the fatigue rate shares).
const STOPS := [[0.0, UiTokens.STOMACH_EMPTY], [Digestion.EMPTY_BELOW, UiTokens.STOMACH_EMPTY], [0.3, UiTokens.STOMACH_HUNGRY],
	[0.5, UiTokens.STOMACH_HUNGRY], [0.8, UiTokens.STOMACH_FULL], [Digestion.OVERFULL_ABOVE, UiTokens.STOMACH_FULL],
	[1.2, UiTokens.STOMACH_OVERFULL]]
## The glyph's drawn size per state (owner: "empty stomach looks shrunk, full stomach looks big"); HuntHud
## eases the drawn scale toward it (SCALE_SPEED per second) so a state change grows or shrinks the glyph.
const GLYPH_SCALE := {&"empty": 0.92, &"hungry": 0.95, &"normal": 0.98, &"full": 1.0, &"overfull": 1.06}
const SCALE_SPEED := 0.6
const GLYPH := {&"empty": &"stomach_empty", &"hungry": &"stomach_hungry", &"normal": &"stomach",
	&"full": &"stomach", &"overfull": &"stomach_overfull"}

## How full she is: 0 = empty, 1 = a full stomach, above 1 = overfull (Digestion.fullness, the model's value).
static func fullness_of(p: Player) -> float:
	var dig := Digestion.of(p)
	return dig.fullness() if dig else 0.0

## 0..1 of the digestion cooldown left (Digestion.saturation).
static func saturation_of(p: Player) -> float:
	var dig := Digestion.of(p)
	return dig.saturation() if dig else 0.0

static func state_of(f: float) -> StringName:
	return Digestion.state_for(f)

static func color_for(f: float) -> Color:
	for i in range(1, STOPS.size()):
		var hi: Array = STOPS[i]
		if f <= float(hi[0]):
			var lo: Array = STOPS[i - 1]
			var t := clampf((f - float(lo[0])) / maxf(0.0001, float(hi[0]) - float(lo[0])), 0.0, 1.0)
			return (lo[1] as Color).lerp(hi[1] as Color, t)
	return STOPS[STOPS.size() - 1][1]

## The arc still lit for `frac` (owner: "degrades clockwise"): it always ends at 12 o'clock, and the gap
## opens from 12 o'clock clockwise as it empties. Returns (start, end) angles, end - start = TAU * frac.
static func arc_for(frac: float) -> Vector2:
	var f := clampf(frac, 0.0, 1.0)
	return Vector2(-PI * 0.5 + TAU * (1.0 - f), -PI * 0.5 + TAU)

## The rings centred on `c` (outer radius `rad`), each lit from where its clockwise gap ends round to
## 12 o'clock; `glyph_scale` sizes the stomach. Returns the box.
static func draw(ci: CanvasItem, c: Vector2, rad: float, fullness: float, saturation: float, glyph_scale: float = 1.0) -> Rect2:
	# Both rings are yellow at times (hungry, saturation), so they differ in weight: a thin outer ring past a
	# dark gap, a thick inner one.
	var sw := maxf(2.0, rad * 0.1)    # outer saturation ring
	var w := maxf(4.0, rad * 0.27)    # inner fullness ring
	var r_in := rad - sw - 2.5 - w * 0.5
	ci.draw_circle(c, rad, UiTokens.HUD_FILL)
	ci.draw_arc(c, rad - sw * 0.5, 0.0, TAU, 40, Color(UiTokens.SATURATION, 0.18), sw, true)
	if saturation > 0.0:
		var sa := arc_for(saturation)
		ci.draw_arc(c, rad - sw * 0.5, sa.x, sa.y, maxi(4, int(40.0 * saturation)), UiTokens.SATURATION, sw, true)
	ci.draw_arc(c, r_in, 0.0, TAU, 40, TRACK, w, true)
	if fullness < Digestion.EMPTY_BELOW:  # empty reads red even with nothing to fill
		ci.draw_arc(c, r_in, 0.0, TAU, 40, Color(UiTokens.STOMACH_EMPTY, 0.45), w, true)
	var fill := clampf(fullness, 0.0, 1.0)
	if fill > 0.0:
		var fa := arc_for(fill)
		ci.draw_arc(c, r_in, fa.x, fa.y, maxi(4, int(40.0 * fill)), color_for(fullness), w, true)
	var g := (r_in - w * 0.5) * 1.6 * glyph_scale
	var id: StringName = GLYPH[state_of(fullness)]
	var tex := UiIcons.icon(id) if UiIcons.path_for(id) != "" else null
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(1, 1, 1, 0.95))
	return Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
