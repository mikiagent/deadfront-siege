class_name ExhaustTreadmill
extends RefCounted
## The exhaustion gauge as a treadmill (owner 2026-10-27: "sleeping should lower the exhaustion,
## treadmill arrow pointed left; being wet, gathering etc, treadmill arrow pointing right;
## treadmill speed conveys how fast it is changing"). Vitals.fatigue_breakdown() only sees gains
## and Vitals.rest() applies sleeps and meals as one-off steps, so the drift is sampled: an EMA
## over fatigue deltas — sleep is a big negative step, walking and climate a steady positive
## creep. HuntHud owns the state and calls these statics; nothing here mutates game state.

const EMA_TAU := 2.5 ## drift averaging window, s: fast enough to react, slow enough to stay readable
const FORGET_TAU := 0.8 ## tighter window right after a one-off step, so a sleep sweep eases off instead of jamming
const FORGET_HOLD_S := 2.0 ## how long the tighter window lasts after a one-off step
const STEP_AFTER := 8.0 ## a sample jump past this many points is a one-off step (sleep/meal), applied instantly
## The idle baseline drains 100 pts over 90 min (EXHAUSTION_PER_SEC x FATIGUE_ACCUMULATION_MULT
## = 0.0185 pt/s); PX_PER_PT sizes the belt so that reads as a slow crawl, not a stall.
const RATE_DEAD := 0.004 ## pt/s: below this the belt holds still
const PX_PER_PT := 350.0 ## belt px/s per drifting pt/s
const MIN_PX := 3.0
const MAX_PX := 150.0
const BELT_H := 16.0 ## the belt replaces the old small fatigue bar; HudLayout.vitals_rect adds the rows

## EMA of d(fatigue)/dt. `forget_left` > 0 (recent one-off step) adopts a tighter window, so a
## sleep's big instant sweep decays in a couple of seconds instead of holding max speed for ~10 s.
static func sample_rate(prev: float, instant: float, dt: float, forget_left: float) -> float:
	var tau := FORGET_TAU if forget_left > 0.0 else EMA_TAU
	var k := 1.0 - exp(-dt / tau)
	return prev + (instant - prev) * k

const PAUSE_TAU := 0.2 ## s: Well Rested brings a moving belt to a stop this fast (eased, not snapped)

## Well Rested (owner 2026-10-28): exhaustion cannot rise, so unless it is falling right now (a rest,
## a meal) the belt pauses: the post-sleep left drift eases to 0 instead of running on.
static func paused_rate(prev: float, instant: float, dt: float) -> float:
	if instant < -RATE_DEAD:
		return sample_rate(prev, instant, dt, 0.0)
	var r := prev * exp(-dt / PAUSE_TAU)
	return 0.0 if absf(r) < RATE_DEAD * 0.25 else r

## +1 exhaustion is rising (belt runs right: work, climate, being wet), -1 easing (left: sleep,
## meals), 0 at rest.
static func direction(rate: float) -> int:
	if rate > RATE_DEAD:
		return 1
	if rate < -RATE_DEAD:
		return -1
	return 0

static func speed_px(rate: float) -> float:
	return clampf(PX_PER_PT * absf(rate), MIN_PX, MAX_PX)

static func phase(prev: float, rate: float, dt: float) -> float:
	var dir := direction(rate)
	return prev if dir == 0 else prev + float(dir) * speed_px(rate) * dt

## --- Look (owner 2026-10-28: "improve the artistry of the treadmill", same size and shape) ---
## A recessed rubber belt of plates with stitched edges and end drums; the strained part glows in the
## tier colours (blended, pure at each tier's middle) up to a lit edge at the marker; chevrons streak
## when it runs fast; a sheen sweeps the plates; Well Rested frosts it over; a worse tier pulses.
## Cost: ~45 canvas commands, no GDScript allocation per frame (one fixed line buffer, cached label).
const SHEEN_S := 2.6 ## a sheen pass over the plates while running, s
const FROST_S := 0.6 ## Well Rested frost fades in/out this fast, s
const PULSE_S := 0.7 ## worse-tier pulse length, s
const STREAK_PX := 60.0 ## belt speed (px/s) where chevrons start to leave a streak
const ICE := Color(0.62, 0.84, 0.98)
const THREAD := Color(0.86, 0.78, 0.60)
const SEGS := 96 ## line pairs per buffer: 232 px / 9 px plates x 2 chevron legs, with room
const SPARKS := 7
const MARKER_TALL := 1.6 ## needle height / belt height. ASSUMPTION: owner asked for "a tall bar"
const MARKER_W := 4.0
const FILL_STOPS := [0.125, 0.375, 0.625, 0.875, 1.0] ## tier middles, then the end: fill quads break here
const TIER_NOTCHES := [0.25, 0.5, 0.75]

static var marker_rect := Rect2() ## the needle's own rect: taller than the belt, centred on it
static var last_rect := Rect2() ## the rect the belt last drew into (tests: it keeps its size)
static var _clock := 0.0
static var _frost := 0.0
static var _tier := -1
static var _pulse := 0.0
static var _pct := -1
static var _pct_text := ""
static var _quad_p := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _quad_c := PackedColorArray([Color(), Color(), Color(), Color()])
static var _n := 0
static var _no_uv := PackedVector2Array()

static func _buf() -> PackedVector2Array:
	var b := PackedVector2Array()
	b.resize(SEGS * 2)
	return b

## Tier 0-3 on the face's scale (RESTED < 25 %, WORN < 50 %, TIRED < 75 %, EXHAUSTED).
static func tier_of(strain: float) -> int:
	return clampi(int(floor(strain * 4.0)), 0, 3)

## UiTokens.MOOD blended along the strain: pure at each tier's middle, mixed across the borders.
static func tier_color(strain: float) -> Color:
	var u := clampf(strain * 4.0 - 0.5, 0.0, 3.0)
	var i := mini(int(u), 2)
	return (UiTokens.MOOD[i] as Color).lerp(UiTokens.MOOD[i + 1], u - float(i))

## Animation state, once per HUD frame (HuntHud._process): the clock, the Well Rested frost fade and
## the worse-tier pulse. Drawing reads it and never mutates.
static func tick(delta: float, strain: float, paused: bool) -> void:
	_clock = fposmod(_clock + delta, 600.0)
	_frost = move_toward(_frost, 1.0 if paused else 0.0, delta / FROST_S)
	var t := tier_of(strain)
	if _tier >= 0 and t > _tier:
		_pulse = PULSE_S
	_tier = t
	_pulse = maxf(0.0, _pulse - delta)

## Draws the belt over the fatigue row inside `rect` (only the needle reaches past it): chevrons point and
## scroll with the drift (flat ticks while stationary), the strain marker in the face's level
## colour, the strain percentage right-aligned.
static func draw_belt(hud: CanvasItem, rect: Rect2, rate: float, phase: float, strain: float, level_col: Color, font: Font, text_px: int) -> void:
	last_rect = rect
	strain = clampf(strain, 0.0, 1.0)
	var dir := direction(rate)
	var spd := speed_px(rate) if dir != 0 else 0.0
	var fr := _frost
	var pulse := _pulse / PULSE_S
	var tc := tier_color(strain)
	var x0 := rect.position.x
	var x1 := rect.end.x
	var y0 := rect.position.y
	var y1 := rect.end.y
	var h := rect.size.y
	var ym := (y0 + y1) * 0.5
	# Recess and rubber.
	hud.draw_rect(rect, Color(0.02, 0.022, 0.026, 0.95))
	hud.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, rect.size.x - 2.0, h - 2.0), Color(0.075, 0.082, 0.095, 0.95))
	# The strained length glows in the tier colours, brightest at the marker.
	var mx := lerpf(x0 + 4.0, x1 - 4.0, strain)
	var a_fill := 0.42 + 0.18 * pulse
	var s_prev := 0.0
	for s: float in FILL_STOPS:
		var s_end := minf(s, strain)
		if s_end > s_prev:
			var xa := lerpf(x0 + 1.0, mx, s_prev / maxf(strain, 0.001))
			var xb := lerpf(x0 + 1.0, mx, s_end / maxf(strain, 0.001))
			var ca := tier_color(s_prev)
			var cb := tier_color(s_end)
			ca.a = a_fill * (0.25 + 0.75 * s_prev / maxf(strain, 0.001))
			cb.a = a_fill * (0.25 + 0.75 * s_end / maxf(strain, 0.001))
			_quad(hud, xa, xb, y0 + 1.0, y1 - 1.0, ca, cb)
		s_prev = s_end
		if s_end >= strain:
			break
	# Plates: dark seams, a lit bevel after each, chevrons (or flat ticks) mid-plate.
	var gap := maxf(9.0, h * 0.62)
	var tri := h * 0.26
	var xl := x0 + 3.5
	var xr := x1 - 3.5
	var cy0 := y0 + 4.0
	var cy1 := y1 - 4.0
	var off := fposmod(phase, gap)
	var slat := gap * 3.0
	_begin()
	var x := x0 + fposmod(phase, slat) - slat
	while x < xr + slat:
		_clip(Vector2(x, y0 + 1.0), Vector2(x, y1 - 1.0), xl, xr)
		x += slat
	_end(rect)
	hud.draw_multiline(_stage, Color(0, 0, 0, 0.6))
	_begin()
	x = x0 + fposmod(phase, slat) - slat + 1.0
	while x < xr + slat:
		_clip(Vector2(x, y0 + 1.0), Vector2(x, y1 - 1.0), xl, xr)
		x += slat
	_end(rect)
	hud.draw_multiline(_stage, Color(1, 1, 1, 0.10 + 0.06 * fr))
	# Treads: the strained part's chevrons light up in the tier colour, the rest stay dim rubber.
	var dim := Color(Color(0.55, 0.59, 0.64).lerp(ICE, fr), 0.30 if dir == 0 else 0.42)
	var lit := Color(tc.lightened(0.25).lerp(ICE, fr * 0.7), 0.55 if dir == 0 else 0.9)
	if spd > STREAK_PX:  # streak: two fading ghosts trailing the lit chevrons
		var k := clampf((spd - STREAK_PX) / (MAX_PX - STREAK_PX), 0.0, 1.0)
		var trail := -float(dir) * (1.5 + 3.5 * k)
		_chevrons(off + gap * 0.5 + trail, gap, tri, dir, x0, xl, mx, cy0, cy1, ym, rect)
		hud.draw_multiline(_stage, Color(lit, 0.10 + 0.25 * k), 2.0)
		_chevrons(off + gap * 0.5 + trail * 2.0, gap, tri, dir, x0, xl, mx, cy0, cy1, ym, rect)
		hud.draw_multiline(_stage, Color(lit, 0.05 + 0.12 * k), 2.0)
	_chevrons(off + gap * 0.5, gap, tri, dir, x0, mx, xr, cy0, cy1, ym, rect)
	hud.draw_multiline(_stage, dim, 1.4, true)
	_chevrons(off + gap * 0.5, gap, tri, dir, x0, xl, mx, cy0, cy1, ym, rect)
	hud.draw_multiline(_stage, lit, 1.5, true)
	# Stitched edges, travelling with the belt.
	_begin()
	var sx := x0 + fposmod(phase, 6.0) - 6.0
	while sx < xr:
		_clip(Vector2(sx, y0 + 2.5), Vector2(sx + 3.0, y0 + 2.5), xl, xr)
		_clip(Vector2(sx, y1 - 2.5), Vector2(sx + 3.0, y1 - 2.5), xl, xr)
		sx += 6.0
	_end(rect)
	hud.draw_multiline(_stage, Color(THREAD.lerp(ICE, fr), 0.30 + 0.10 * fr))
	# Depth: a lit top, a shaded bottom, drums at both ends.
	hud.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, rect.size.x - 2.0, 1.0), Color(1, 1, 1, 0.16))
	hud.draw_rect(Rect2(x0 + 1.0, y0 + 2.0, rect.size.x - 2.0, h * 0.22), Color(1, 1, 1, 0.04))
	hud.draw_rect(Rect2(x0 + 1.0, y1 - 1.0 - h * 0.28, rect.size.x - 2.0, h * 0.28), Color(0, 0, 0, 0.26))
	hud.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, 3.0, h - 2.0), Color(0.16, 0.17, 0.19, 0.95))
	hud.draw_rect(Rect2(x1 - 4.0, y0 + 1.0, 3.0, h - 2.0), Color(0.16, 0.17, 0.19, 0.95))
	hud.draw_rect(Rect2(x0 + 2.0, y0 + 1.0, 1.0, h - 2.0), Color(1, 1, 1, 0.14))
	hud.draw_rect(Rect2(x1 - 3.0, y0 + 1.0, 1.0, h - 2.0), Color(1, 1, 1, 0.14))
	# Sheen over the plates: runs with the belt, slow and faint while it stands.
	var period := SHEEN_S if dir != 0 else SHEEN_S * 2.4
	var u := fposmod(_clock / period, 1.0)
	if dir < 0:
		u = 1.0 - u
	var sw := 26.0
	var sc := lerpf(x0 - sw, x1 + sw, u)
	var sa := (0.10 if dir != 0 else 0.05) + 0.10 * fr
	var shine := Color(Color(1, 1, 1).lerp(ICE, fr), 0.0)
	var shine_on := Color(shine, sa)
	_quad(hud, sc - sw, sc, y0 + 1.0, y1 - 1.0, shine, shine_on, x0 + 1.0, x1 - 1.0)
	_quad(hud, sc, sc + sw, y0 + 1.0, y1 - 1.0, shine_on, shine, x0 + 1.0, x1 - 1.0)
	# Tier borders: small notches at 25 / 50 / 75 %.
	for b: float in TIER_NOTCHES:
		var bx := roundf(lerpf(x0 + 4.0, x1 - 4.0, b))
		hud.draw_rect(Rect2(bx - 0.5, y0 + 1.0, 1.0, 2.0), Color(1, 1, 1, 0.30))
		hud.draw_rect(Rect2(bx - 0.5, y1 - 3.0, 1.0, 2.0), Color(1, 1, 1, 0.30))
	# Well Rested: frost over the belt, a rimed edge and a few twinkling crystals.
	if fr > 0.0:
		hud.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, rect.size.x - 2.0, h - 2.0), Color(ICE, 0.14 * fr))
		hud.draw_rect(Rect2(x0 + 1.0, y0 + 1.0, rect.size.x - 2.0, 2.0), Color(0.90, 0.97, 1.0, 0.30 * fr))
		hud.draw_rect(Rect2(x0 + 1.0, y1 - 2.0, rect.size.x - 2.0, 1.0), Color(0.90, 0.97, 1.0, 0.18 * fr))
		_begin()
		for i in SPARKS:
			var tw := 0.5 + 0.5 * sin(_clock * 1.7 + float(i) * 2.3)
			var c := Vector2(lerpf(x0 + 10.0, x1 - 34.0, fposmod(float(i) * 0.618, 1.0)), lerpf(y0 + 4.0, y1 - 4.0, fposmod(float(i) * 0.382 + 0.2, 1.0)))
			var r := 0.8 + 1.4 * tw
			_clip(c - Vector2(r, 0), c + Vector2(r, 0), xl, xr)
			_clip(c - Vector2(0, r), c + Vector2(0, r), xl, xr)
		_end(rect)
		hud.draw_multiline(_stage, Color(0.92, 0.98, 1.0, 0.8 * fr), 1.0, true)
	# The lit edge at the marker: a soft glow either side (wider and brighter on a pulse).
	var gw := 10.0 + 8.0 * pulse
	var glow := Color(tc.lerp(ICE, fr * 0.6), 0.0)
	var glow_on := Color(glow, 0.45 + 0.4 * pulse)
	_quad(hud, mx - gw, mx, y0 + 1.0, y1 - 1.0, glow, glow_on, x0 + 1.0, x1 - 1.0)
	_quad(hud, mx, mx + gw, y0 + 1.0, y1 - 1.0, glow_on, glow, x0 + 1.0, x1 - 1.0)
	# Frame: dark, flashing in the tier colour on a pulse.
	hud.draw_rect(rect, Color(0, 0, 0, 0.7), false, 1.0)
	if pulse > 0.0:
		hud.draw_rect(Rect2(x0 + 0.5, y0 + 0.5, rect.size.x - 1.0, h - 1.0), Color(tc, 0.9 * pulse), false, 1.0)
	# The marker (owner 2026-10-28: "make it a tall bar"): a needle MARKER_TALL x the belt, glowing in the tier colour.
	var mh := h * MARKER_TALL
	marker_rect = Rect2(mx - MARKER_W * 0.5, ym - mh * 0.5, MARKER_W, mh)
	var mg := 2.0 + 1.5 * pulse
	hud.draw_rect(marker_rect.grow(mg + 1.0), Color(tc, 0.14 + 0.18 * pulse))
	hud.draw_rect(marker_rect.grow(mg * 0.5), Color(tc, 0.30 + 0.25 * pulse))
	hud.draw_rect(marker_rect.grow(1.0), Color(0.03, 0.035, 0.04, 0.95))
	hud.draw_rect(marker_rect, level_col)
	hud.draw_rect(Rect2(marker_rect.position.x, marker_rect.position.y, 1.0, mh), Color(1, 1, 1, 0.55))
	if font != null and text_px > 0:
		var p := int(round(strain * 100.0))
		if p != _pct:  # the label changes once per percent, not once per frame
			_pct = p
			_pct_text = "%d%%" % p
		var w := font.get_string_size(_pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px).x
		var at := Vector2(x1 - w - 7.0, ym + text_px * 0.36)
		hud.draw_rect(Rect2(at.x - 4.0, y0 + 2.0, w + 7.0, h - 4.0), Color(0.03, 0.035, 0.04, 0.55))
		hud.draw_string(font, at + Vector2(0, 1), _pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px, Color(0, 0, 0, 0.7))
		hud.draw_string(font, at, _pct_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px, Color(0.95, 0.97, 1.0, 0.95))

## A horizontal gradient quad (colour ca at xa, cb at xb), optionally cut to [cl, cr].
static func _quad(hud: CanvasItem, xa: float, xb: float, ya: float, yb: float, ca: Color, cb: Color, cl: float = -INF, cr: float = INF) -> void:
	if xb <= cl or xa >= cr or xb <= xa:
		return
	var na := maxf(xa, cl)
	var nb := minf(xb, cr)
	var c0 := ca.lerp(cb, (na - xa) / (xb - xa))
	var c1 := ca.lerp(cb, (nb - xa) / (xb - xa))
	_quad_p[0] = Vector2(na, ya)
	_quad_p[1] = Vector2(nb, ya)
	_quad_p[2] = Vector2(nb, yb)
	_quad_p[3] = Vector2(na, yb)
	_quad_c[0] = c0
	_quad_c[1] = c1
	_quad_c[2] = c1
	_quad_c[3] = c0
	hud.draw_primitive(_quad_p, _quad_c, _no_uv)

## One chevron (or flat tick) per plate into the stage, centred `start` px into the first plate.
static func _chevrons(start: float, gap: float, tri: float, dir: int, x0: float, xl: float, xr: float, cy0: float, cy1: float, ym: float, rect: Rect2) -> void:
	_begin()
	var x := x0 + fposmod(start, gap) - gap - tri
	while x < xr + gap:
		if dir == 0:
			_clip(Vector2(x, cy0), Vector2(x, cy1), xl, xr)
		else:
			var tip := Vector2(x + tri * float(dir), ym)
			_clip(Vector2(x, cy0), tip, xl, xr)
			_clip(Vector2(x, cy1), tip, xl, xr)
		x += gap
	_end(rect)

## Line-pair staging: _clip writes pairs here, the caller draws it with draw_multiline right away (the
## server copies the points), then the next pass reuses it. Fixed size, so it never reallocates.
static var _stage := _buf()
static var _used := SEGS ## pairs holding real lines from the previous pass; the rest are parked

static func _begin() -> void:
	_n = 0

## Parks the pairs the last pass used but this one did not as zero-length lines at the corner.
static func _end(rect: Rect2) -> void:
	for i in range(_n * 2, _used * 2):
		_stage[i] = rect.position
	_used = _n

## One x-clipped straight line, so plates and chevrons crossing the belt's ends are cut at the drums
## instead of painting over the panel edge.
static func _clip(a: Vector2, b: Vector2, x_min: float, x_max: float) -> void:
	if _n >= SEGS:
		return
	if a.x > b.x:
		var t := a
		a = b
		b = t
	if b.x < x_min or a.x > x_max:
		return
	if a.x < x_min or b.x > x_max:
		if is_equal_approx(a.x, b.x):
			return
		if a.x < x_min:
			var t0 := (x_min - a.x) / (b.x - a.x)
			a.y += (b.y - a.y) * t0
			a.x = x_min
		if b.x > x_max:
			var t1 := (x_max - a.x) / (b.x - a.x)
			b.y += (b.y - a.y) * t1
			b.x = x_max
	_stage[_n * 2] = a
	_stage[_n * 2 + 1] = b
	_n += 1
