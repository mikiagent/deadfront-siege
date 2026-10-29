class_name HudLevelBadge
extends RefCounted
## LEVELBADGE (owner 2026-10-28, reversing LEVELBAR's "no top-left level"): the round level badge at the
## vitals' left, after the Durango reference, whose ring "gets more impressive looking as it gets closer
## to 60". Drawn with canvas calls only (no shader, no texture): ~20-70 small draws a frame, the
## animated tiers move with the clock the HUD already redraws on.
## Tiers by shown level (TIER_FROM): 0 plain slate ring, 1 bronze, 2 silver with notches, 3 gold with
## filigree and spikes, 4 glowing gold with a travelling shimmer and orbiting sparks, 5 (the cap) the same
## brighter, with a crown of three tall spikes and a breathing halo.

## ASSUMPTION: the level cap is 60, from the owner's reference; no PRD or data file names one.
const MAX_LEVEL := 60
const TIER_FROM: Array[int] = [1, 10, 25, 40, 55, 60]
## Ring metal per tier: [base, highlight, shade].
const METAL: Array = [
	[Color(0.42, 0.46, 0.52), Color(0.70, 0.74, 0.80), Color(0.18, 0.20, 0.24)],
	[Color(0.70, 0.43, 0.22), Color(0.95, 0.70, 0.45), Color(0.32, 0.17, 0.07)],
	[Color(0.74, 0.78, 0.84), Color(0.97, 0.98, 1.00), Color(0.32, 0.35, 0.40)],
	[Color(0.88, 0.66, 0.22), Color(1.00, 0.90, 0.55), Color(0.42, 0.27, 0.06)],
	[Color(0.96, 0.74, 0.24), Color(1.00, 0.95, 0.68), Color(0.48, 0.30, 0.05)],
	[Color(1.00, 0.80, 0.30), Color(1.00, 0.98, 0.80), Color(0.55, 0.33, 0.04)],
]
## The badge radius and the column it takes left of the bars (spikes and glow reach past the ring).
const R := 30.0
const COLUMN := 78.0
const GLOW := Color(1.0, 0.78, 0.30)
const FACE := Color(0.07, 0.08, 0.10)

static var _num := -1
static var _num_text := ""

static func tier_of(level: int) -> int:
	var t := 0
	for i in TIER_FROM.size():
		if level >= TIER_FROM[i]:
			t = i
	return t

## Draws the badge centred on `c` with outer ring radius `r`; `time` in seconds drives the animation.
## Returns the rect it covers (spikes and glow included).
static func draw(ci: CanvasItem, c: Vector2, r: float, level: int, time: float, font: Font) -> Rect2:
	var tier := tier_of(level)
	var m: Array = METAL[tier]
	var base: Color = m[0]
	var hi: Color = m[1]
	var sh: Color = m[2]
	var pulse := 0.5 + 0.5 * sin(time * 2.4)
	# Glow behind everything (tier 4+), breathing.
	if tier >= 4:
		var g := 0.18 + 0.14 * pulse + (0.10 if tier == 5 else 0.0)
		for k in 3:
			ci.draw_circle(c, r * (1.42 - 0.12 * k), Color(GLOW, g * (0.35 + 0.3 * k)))
	# Drop shadow: the badge reads over sand and over night grass alike.
	ci.draw_circle(c + Vector2(0, 2.0), r + 2.5, Color(0, 0, 0, 0.45))
	# Spikes (tier 3+): a star of points behind the ring; tier 5 adds a crown of three tall ones on top.
	if tier >= 3:
		var n := 12 if tier == 3 else 16
		var spin := time * 0.15 if tier >= 4 else 0.0
		var star := PackedVector2Array()
		for i in n * 2:
			var a := spin + TAU * float(i) / float(n * 2) - PI * 0.5
			star.append(c + Vector2(cos(a), sin(a)) * (r * (1.22 if i % 2 == 0 else 0.98)))
		ci.draw_colored_polygon(star, sh)
		var inner := PackedVector2Array()
		for i in n * 2:
			var a := spin + TAU * float(i) / float(n * 2) - PI * 0.5
			inner.append(c + Vector2(cos(a), sin(a)) * (r * (1.15 if i % 2 == 0 else 0.96)))
		ci.draw_colored_polygon(inner, base)
	if tier == 5:
		for a: float in [-0.5, 0.0, 0.5]:
			var d := Vector2(sin(a), -cos(a))
			var s := Vector2(-d.y, d.x)
			var tall := r * (1.40 if a == 0.0 else 1.30)
			ci.draw_colored_polygon(PackedVector2Array([c + d * r * 0.9 - s * r * 0.16, c + d * tall, c + d * r * 0.9 + s * r * 0.16]), hi)
			ci.draw_colored_polygon(PackedVector2Array([c + d * r * 0.9 - s * r * 0.16, c + d * tall, c + d * r * 0.95]), base)
	# The ring: dark rim, metal band, bevel (lit top-left, shaded bottom-right).
	var band := r * (0.18 if tier == 0 else 0.22)
	ci.draw_circle(c, r + 1.0, Color(0, 0, 0, 0.8), true, -1.0, true)
	ci.draw_circle(c, r, base, true, -1.0, true)
	ci.draw_arc(c, r - band * 0.3, PI * 0.95, PI * 1.85, 20, hi, band * 0.45, true)
	ci.draw_arc(c, r - band * 0.3, PI * -0.05, PI * 0.85, 20, sh, band * 0.4, true)
	# Notches (tier 2+): dark ticks around the band; filigree dots between them (tier 3+).
	if tier >= 2:
		var ticks := 12 if tier == 2 else 24
		for i in ticks:
			var a := TAU * float(i) / float(ticks)
			var d := Vector2(cos(a), sin(a))
			ci.draw_line(c + d * (r - band * 0.85), c + d * (r - band * 0.15), Color(sh, 0.9), 1.2, true)
			if tier >= 3:
				var b := a + PI / float(ticks)
				ci.draw_circle(c + Vector2(cos(b), sin(b)) * (r - band * 0.5), maxf(1.0, band * 0.16), hi)
	# Travelling shimmer (tier 4+): a bright arc that circles the band.
	if tier >= 4:
		var a0 := fposmod(time * 1.6, TAU)
		ci.draw_arc(c, r - band * 0.5, a0, a0 + 0.7, 10, Color(1, 1, 1, 0.55), band * 0.55, true)
		ci.draw_arc(c, r - band * 0.5, a0 + 0.15, a0 + 0.45, 6, Color(1, 1, 1, 0.75), band * 0.3, true)
	# The face: a dark well with an inner rim and a soft top sheen.
	var fr := r - band
	ci.draw_circle(c, fr, Color(0, 0, 0, 0.85), true, -1.0, true)
	ci.draw_circle(c, fr - 1.5, FACE, true, -1.0, true)
	ci.draw_arc(c, fr - 1.5, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.10), fr * 0.25, true)
	if tier >= 4:
		ci.draw_arc(c, fr - 1.5, 0.0, TAU, 32, Color(GLOW, 0.35 + 0.35 * pulse), 1.5, true)
	# Sparks (tier 4+): small four-point twinkles orbiting outside the ring.
	if tier >= 4:
		var sparks := 4 if tier == 4 else 7
		for i in sparks:
			var a := time * (0.7 + 0.13 * i) + float(i) * 2.17
			var tw := maxf(0.0, sin(time * 3.1 + float(i) * 1.9))
			if tw <= 0.05:
				continue
			var p := c + Vector2(cos(a), sin(a)) * r * (1.12 + 0.12 * sin(time + i))
			var s := (1.0 + 2.6 * tw) * (r / 30.0)
			var col := Color(1.0, 0.95, 0.75, tw)
			ci.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 1.2, true)
			ci.draw_line(p - Vector2(0, s), p + Vector2(0, s), col, 1.2, true)
	# The number and LEVEL under it.
	if font:
		if level != _num:
			_num = level
			_num_text = str(level)
		var num_px := int(round(fr * (0.95 if level < 100 else 0.75)))
		var cap_px := maxi(7, int(round(fr * 0.34)))
		var num_col := Color.WHITE if tier < 3 else hi
		var ny := c.y + num_px * 0.22
		ci.draw_string_outline(font, Vector2(c.x - fr, ny), _num_text, HORIZONTAL_ALIGNMENT_CENTER, fr * 2.0, num_px, 3, Color(0, 0, 0, 0.85))
		ci.draw_string(font, Vector2(c.x - fr, ny), _num_text, HORIZONTAL_ALIGNMENT_CENTER, fr * 2.0, num_px, num_col)
		ci.draw_string(font, Vector2(c.x - fr, ny + cap_px + 2.0), "LEVEL", HORIZONTAL_ALIGNMENT_CENTER, fr * 2.0, cap_px, Color(base.lerp(Color.WHITE, 0.35), 0.95))
	var reach := r * (1.42 if tier == 5 else (1.42 if tier == 4 else (1.22 if tier == 3 else 1.0))) + 3.0
	return Rect2(c - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
