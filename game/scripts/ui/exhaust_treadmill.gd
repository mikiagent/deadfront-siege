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

## Draws the belt over the fatigue row: a track, tread chevrons that point and scroll with the
## drift (flat ticks while stationary), the strain marker across the belt in the face's level
## colour, and the strain percentage right-aligned as before.
static func draw_belt(hud: HuntHud, rect: Rect2, rate: float, phase: float, strain: float, level_col: Color, font: Font, text_px: int) -> void:
	hud.draw_rect(rect, Color(0.07, 0.08, 0.10, 0.9))
	hud.draw_rect(rect, Color(0, 0, 0, 0.6), false, 1.0)
	var dir := direction(rate)
	var gap := maxf(9.0, rect.size.y * 0.62)
	var tri := rect.size.y * 0.30
	var x_min := rect.position.x + 1.5
	var x_max := rect.end.x - 1.5
	var y0 := rect.position.y + 2.0
	var y1 := rect.end.y - 2.0
	var ym := (y0 + y1) * 0.5
	var tick_col := Color(0.63, 0.67, 0.72, 0.30 if dir == 0 else 0.52)
	var start := rect.position.x + fposmod(phase, gap)
	var x := start - gap
	while x < x_max + 0.1:
		if dir == 0:
			_seg(hud, Vector2(x, y0), Vector2(x, y1), tick_col, 1.4, x_min, x_max)
		else:
			var tip := Vector2(x + tri * float(dir), ym)
			_seg(hud, Vector2(x, y0), tip, tick_col, 1.4, x_min, x_max)
			_seg(hud, Vector2(x, y1), tip, tick_col, 1.4, x_min, x_max)
		x += gap
	var m := Vector2(lerpf(rect.position.x + 4.0, rect.end.x - 4.0, clampf(strain, 0.0, 1.0)), ym)
	hud.draw_circle(m, 3.0, Color(0.06, 0.08, 0.09, 0.9))
	hud.draw_circle(m, 2.2, level_col)
	if font != null and text_px > 0:
		var text := "%d%%" % int(round(strain * 100.0))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, text_px).x
		hud.draw_string(font, Vector2(rect.end.x - w - 6.0, ym + text_px * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_px, Color(0.95, 0.97, 1.0, 0.95))

## One x-clipped straight line, so tread chevrons crossing the belt's ends are cut at the frame
## instead of painting over the panel edge.
static func _seg(hud: HuntHud, a: Vector2, b: Vector2, col: Color, w: float, x_min: float, x_max: float) -> void:
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
	hud.draw_line(a, b, col, w)
