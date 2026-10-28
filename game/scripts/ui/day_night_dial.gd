class_name DayNightDial
extends Control
## The HUD's day/night dial, docked to the minimap's bottom-left edge (docs/design/durango-prompts/
## 16_hud_day_night_dial.md). DAYNIGHT (owner 2026-10-28): of three faces the owner kept the half-dial
## ("the right size and shape but I wish it was flashier/more artistic"), so this is that face, dressed:
## a painted half-disc sky (zenith-to-horizon gradient, a warm glow around the sun, a dawn/dusk colour
## band that sweeps up at sunrise and down at sunset), soft clouds drifting with the hours, a sun with a
## corona and lens-flare glints, a moon with a halo, twinkling stars and the odd shooting star, two
## horizon silhouettes (far hills, a near treeline) that drift at different speeds as time passes, a gold
## rim with engraved hour ticks and a gleam that sweeps along it, and a bloom at sunrise and sunset. Under
## the dial a strip holds a 24 h track (night blue, dawn and dusk orange, day gold) with a gold caret at
## now, and the clock.
## A tap opens a label to its left with the phase, the clock and the time until the next phase; it closes
## on a second tap or after OPEN_S. It reads the game's cycle through clock() and never sets it (systems
## PRD:289: the cycle length is the game's tunable, not ours).
## Cheap: every point array is built on layout and only written in place by the draw (the sky, both
## silhouettes and the track are one triangle-array call each); the strings are rebuilt once a game
## minute; it redraws each frame only while something moves in real time (stars, a flourish, the rim
## gleam), else every 15 game seconds. t_daynight times the draw.

const GAP := 6.0  ## between the label and the face
const DOCK := 4.0  ## between the face and the minimap's left edge
const OPEN_S := 4.0  ## the label closes itself after this
const FACE := Vector2(112, 76)  ## desktop; compact canvases get FACE_COMPACT (64 px tall for the tap)
## 66 wide keeps a phone's dial inside the map column UiTokens.hud_reserved keeps clear (234 px in).
const FACE_COMPACT := Vector2(66, 64)
## Where each phase starts: Game.phase_name()'s thresholds, which WorldLighting mirrors (t_lighting).
const STARTS := [[WorldLighting.DAWN, &"dawn"], [WorldLighting.DAY, &"day"], [WorldLighting.DUSK, &"dusk"], [WorldLighting.NIGHT, &"night"]]
## ASSUMPTION: the sun crosses the horizon halfway through dawn and dusk (06:14 and 18:14); the PRD only
## names the phases.
const RISE := (WorldLighting.DAWN + WorldLighting.DAY) * 0.5
const SET := (WorldLighting.DUSK + WorldLighting.NIGHT) * 0.5
const FLOURISH := 0.02  ## share of a day either side of sunrise / sunset the flourish plays (14 s of 720)
const STAR_FADE := 0.05  ## stars fade in over this share of a day after sunset, out before sunrise
const GLEAM_EVERY := 7.0  ## real seconds between gleams along the rim (faster during a flourish)
const GLEAM_S := 1.1  ## how long one gleam takes to cross the rim
const SHOOT_EVERY := 6.0  ## real seconds between shooting-star chances at night
const SHOOT_S := 0.7
## Colour is for things (the sky, the sun, the moon); the rim is gold: the dial is a crafted object.
const SUN := Color(1.0, 0.78, 0.30)
const MOON := Color(0.86, 0.90, 1.0)
const RIM_DARK := Color(0.50, 0.36, 0.10)
const RIM_LIGHT := Color(0.98, 0.84, 0.42)
const NIGHT_TOP := Color(0.02, 0.03, 0.10)
const NIGHT_LOW := Color(0.08, 0.10, 0.24)
const DAY_TOP := Color(0.13, 0.38, 0.76)
const DAY_LOW := Color(0.62, 0.82, 0.95)
const BAND := Color(1.0, 0.46, 0.42)  ## the dawn / dusk band
## [time of day, zenith, horizon]: the sky between the keys is a straight blend.
const SKY_KEYS := [
	[0.0, NIGHT_TOP, NIGHT_LOW], [0.20, NIGHT_TOP, NIGHT_LOW],
	[0.235, Color(0.12, 0.09, 0.30), Color(0.58, 0.28, 0.42)],
	[0.27, Color(0.26, 0.32, 0.62), Color(1.0, 0.62, 0.34)],
	[0.32, DAY_TOP, DAY_LOW], [0.68, DAY_TOP, DAY_LOW],
	[0.745, Color(0.26, 0.21, 0.50), Color(1.0, 0.50, 0.24)],
	[0.79, Color(0.09, 0.06, 0.22), Color(0.38, 0.16, 0.32)],
	[0.83, NIGHT_TOP, NIGHT_LOW], [1.0, NIGHT_TOP, NIGHT_LOW]]
## Star field in sky units: x -1..1 across the dial, y 0..1 up from the horizon, z = size in px.
const STARS := [Vector3(-0.62, 0.42, 1), Vector3(-0.40, 0.70, 2), Vector3(-0.18, 0.52, 1), Vector3(0.05, 0.86, 1),
	Vector3(0.22, 0.62, 2), Vector3(0.44, 0.78, 1), Vector3(0.63, 0.45, 1), Vector3(-0.50, 0.60, 1),
	Vector3(-0.08, 0.68, 1), Vector3(0.35, 0.50, 1), Vector3(0.10, 0.40, 1), Vector3(-0.30, 0.88, 1),
	Vector3(0.55, 0.64, 2), Vector3(-0.72, 0.30, 1), Vector3(0.75, 0.32, 1), Vector3(-0.22, 0.36, 1)]
## Clouds: [height 0..1 over the horizon, size in sky radii, laps of the sky per day, start].
const CLOUDS := [Vector4(0.62, 0.16, 3.0, 0.1), Vector4(0.42, 0.12, 4.5, 0.55), Vector4(0.78, 0.10, 2.2, 0.8)]
## One cloud's puffs: x, y offsets and radius, in cloud sizes.
const PUFFS := [Vector3(-0.95, 0.12, 0.50), Vector3(-0.35, -0.22, 0.72), Vector3(0.30, -0.08, 0.62), Vector3(0.88, 0.15, 0.44)]
## Lens-flare glints: share of the way from the sun towards the dial's middle, radius in px.
const FLARE := [Vector2(0.75, 1.6), Vector2(1.25, 2.4)]
const RINGS := 4  ## sky mesh rings
const SPOKES := 16  ## sky mesh segments along the arc
const HILL_N := 28  ## far-hill samples
const TREE_N := 56  ## treeline samples
const TREES := 9.0  ## trees across the dial

var _anchor := Vector2.ZERO  ## top-right corner of the face; the label opens leftwards
var _open_left := 0.0  ## seconds until the label closes; 0 = closed
var _down := false
var _tick := -1  ## the 15-game-second step last drawn
var _minute := -1  ## the game minute the strings were built for
var _built := Vector2.ZERO  ## the face size the geometry was built for
var _face := FACE
var _compact := false
## Built on layout; the draw only writes into them.
var _sky_pts := PackedVector2Array()
var _sky_cols := PackedColorArray()
var _sky_idx := PackedInt32Array()
var _hill_pts := PackedVector2Array()
var _hill_cols := PackedColorArray()
var _tree_pts := PackedVector2Array()
var _tree_cols := PackedColorArray()
var _strip_idx := PackedInt32Array()  ## the far hills' quad strip
var _tree_idx := PackedInt32Array()
var _track_pts := PackedVector2Array()
var _track_cols := PackedColorArray()
var _track_idx := PackedInt32Array()
var _ticks_dark := PackedVector2Array()
var _ticks_light := PackedVector2Array()
var _rays := PackedVector2Array()
var _caret := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _stars := PackedVector2Array()
var _star_size := PackedFloat32Array()
var _c := Vector2.ZERO  ## the dial's centre, on the horizon
var _r := 0.0  ## the dial's radius
var _orbit := 0.0  ## the sun's and moon's arc radius
var _hy := 0.0  ## the horizon's y in the face
var _track := Rect2()
## Rebuilt once a game minute.
var _clock_text := ""
var _lines := PackedStringArray(["", ""])
## What the last draw put where (face coordinates; NAN when hidden), for tests and labs.
var drawn_sun := Vector2(NAN, NAN)
var drawn_moon := Vector2(NAN, NAN)
var drawn_stars := 0
var draws := 0
var draw_usec := 0  ## summed time spent in _draw, for the cost check

func _init() -> void:
	name = "DayNightDial"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE  # like the HUD hexes: a focused control would take Space (roll)
	size = FACE

## The dial's only read of the game clock: x = time of day (0 = midnight, 0.5 = noon), y = real
## seconds per day. Online play returns the server's clock here instead; nothing else changes.
static func clock() -> Vector2:
	return Vector2(Game.time_of_day, Game.day_length_seconds)

static func phase_at(t: float) -> StringName:
	var out: StringName = STARTS[-1][1]  # night runs over midnight
	for s: Array in STARTS:
		if t >= float(s[0]):
			out = s[1]
	return out

## [the next phase, the share of a day until it starts].
static func next_phase(t: float) -> Array:
	for s: Array in STARTS:
		if t < float(s[0]):
			return [s[1], float(s[0]) - t]
	return [STARTS[0][1], 1.0 + float(STARTS[0][0]) - t]

## The label's two lines, e.g. "Day  09:42" and "Dusk in 4 min". Minutes are rounded (never more
## than 30 s off); under a minute it counts seconds, so it never reads "60 s".
static func label_lines(t: float, day_s: float) -> PackedStringArray:
	return PackedStringArray(["%s  %s" % [str(phase_at(t)).capitalize(), clock_text(t)],
		"%s in %s" % [str(next_phase(t)[0]).capitalize(), wait_text(t, day_s)]])

static func clock_text(t: float) -> String:
	var mins := minute_of(t) % 1440
	return "%02d:%02d" % [floori(mins / 60.0), mins % 60]

## The game minute of time t; the nudge keeps a float32 clock (clock() is a Vector2) on its minute.
static func minute_of(t: float) -> int:
	return int(t * 1440.0 + 0.001)

## The wait until the next phase: "8 s" under a minute, else rounded minutes ("4 min").
static func wait_text(t: float, day_s: float) -> String:
	var secs := float(next_phase(t)[1]) * day_s
	return "%d s" % ceili(secs) if ceili(secs) < 60 else "%d min" % roundi(secs / 60.0)

## Where the sun is between rising (0) and setting (1); under 0 or over 1 it is below the horizon.
static func sun_p(t: float) -> float:
	return (fposmod(t - RISE + 0.25, 1.0) - 0.25) / (SET - RISE)

## The moon's run: up from sunset (0) to sunrise (1), opposite the sun.
static func moon_p(t: float) -> float:
	return (fposmod(t - SET + 0.25, 1.0) - 0.25) / (1.0 - (SET - RISE))

static func sun_up(t: float) -> bool:
	return sun_p(t) >= 0.0 and sun_p(t) <= 1.0

## 0 by day; fades in over STAR_FADE after sunset and out over STAR_FADE before sunrise.
static func star_alpha(t: float) -> float:
	if sun_up(t):
		return 0.0
	return smoothstep(0.0, STAR_FADE, fposmod(t - SET, 1.0)) * smoothstep(0.0, STAR_FADE, fposmod(RISE - t, 1.0))

## 1 at sunrise and sunset, falling to 0 FLOURISH either side.
static func flourish(t: float) -> float:
	var d := minf(absf(fposmod(t - RISE + 0.5, 1.0) - 0.5), absf(fposmod(t - SET + 0.5, 1.0) - 0.5))
	return clampf(1.0 - d / FLOURISH, 0.0, 1.0)

## The sky at time t: the zenith colour, or the horizon's.
static func sky_color(t: float, horizon: bool) -> Color:
	t = fposmod(t, 1.0)
	var j := 2 if horizon else 1
	for i in range(1, SKY_KEYS.size()):
		var b: Array = SKY_KEYS[i]
		if t <= float(b[0]):
			var a: Array = SKY_KEYS[i - 1]
			return (a[j] as Color).lerp(b[j], (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])))
	return SKY_KEYS[-1][j]

## The dawn / dusk band: (its height 0..1 over the horizon, its strength). It climbs from the horizon
## through sunrise and sinks back to it through sunset.
static func band_at(t: float) -> Vector2:
	var dawn := (t - (RISE - 0.05)) / 0.10
	if dawn >= 0.0 and dawn <= 1.0:
		return Vector2(0.05 + 0.9 * dawn, sin(dawn * PI))
	var dusk := (t - (SET - 0.05)) / 0.10
	if dusk >= 0.0 and dusk <= 1.0:
		return Vector2(0.95 - 0.9 * dusk, sin(dusk * PI))
	return Vector2.ZERO

## The HUD docks the face to the minimap's bottom-left edge, off the map (it grows leftwards while
## the label is open, away from the map).
func dock(map: Rect2) -> void:
	_compact = UiTokens.is_compact(get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900))
	_face = FACE_COMPACT if _compact else FACE
	_anchor = Vector2(map.position.x - DOCK, map.end.y - _face.y)
	_fit()

func is_open() -> bool:
	return _open_left > 0.0

func toggle() -> void:
	_open_left = 0.0 if is_open() else OPEN_S
	_fit()

func _fit() -> void:
	var w := _face.x
	_strings(clock().x, true)
	if is_open():
		var view := get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
		var font := UiTokens.ui_face()
		w += GAP + 24.0 + maxf(font.get_string_size(_lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.body(view)).x,
			font.get_string_size(_lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view)).x)
	size = Vector2(w, _face.y)
	position = _anchor - Vector2(w, 0.0)
	if _face != _built:
		_built = _face
		_build()
	queue_redraw()

## The strings, once a game minute (or when forced).
func _strings(t: float, force := false) -> void:
	var minute := minute_of(t)
	if minute == _minute and not force:
		return
	_minute = minute
	_lines = label_lines(t, clock().y)
	_clock_text = clock_text(t)

## True while something on the face moves in real time, so it redraws every frame.
func animating(t: float) -> bool:
	return star_alpha(t) > 0.0 or flourish(t) > 0.0 or _gleam(t) >= 0.0

func _process(delta: float) -> void:
	if is_open():
		_open_left = maxf(0.0, _open_left - delta)
		if not is_open():
			_fit()
	var t := clock().x
	if minute_of(t) != _minute:
		_strings(t)
		if is_open():
			_fit()  # the countdown's width changes
	var tick := int(t * 5760.0)
	if tick != _tick or animating(t):
		_tick = tick
		queue_redraw()

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

## Tap or click: press, then release on the dial, as BaseButton does: a release off it cancels the
## tap (a touch and its emulated mouse toggle once).
func _gui_input(event: InputEvent) -> void:
	var press: bool
	var at: Vector2
	if event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		press = (event as InputEventMouseButton).pressed
		at = (event as InputEventMouseButton).position
	else:
		return
	accept_event()
	if press:
		_down = true
	elif _down:
		_down = false
		if _has_point(at):
			toggle()

# ---------------------------------------------------------------- geometry (on layout only)

func _build() -> void:
	var w := _face.x
	var strip := 24.0 if _compact else 28.0
	_hy = _face.y - strip
	_r = minf(w * 0.5 - 1.5, _hy - 1.5)
	_c = Vector2(w * 0.5, _hy)
	_orbit = _r * 0.72
	# The sky: a centre vertex, then RINGS rings of SPOKES + 1 points.
	_sky_pts.clear()
	_sky_idx.clear()
	_sky_pts.append(_c)
	for j in range(1, RINGS + 1):
		for i in SPOKES + 1:
			_sky_pts.append(_c + Vector2.from_angle(PI + PI * float(i) / SPOKES) * _r * float(j) / RINGS)
	for i in SPOKES:
		_sky_idx.append_array(PackedInt32Array([0, 1 + i, 2 + i]))
	for j in range(1, RINGS):
		var a := 1 + (j - 1) * (SPOKES + 1)
		var b := a + SPOKES + 1
		for i in SPOKES:
			_sky_idx.append_array(PackedInt32Array([a + i, b + i, a + i + 1, a + i + 1, b + i, b + i + 1]))
	_sky_cols.resize(_sky_pts.size())
	# Silhouettes: a top and a bottom point per sample, across the horizon chord.
	_hill_pts.resize((HILL_N + 1) * 2)
	_hill_cols.resize(_hill_pts.size())
	_tree_pts.resize((TREE_N + 1) * 2)
	_tree_cols.resize(_tree_pts.size())
	_strip_idx = _quad_strip(HILL_N)
	_tree_idx = _quad_strip(TREE_N)
	for i in HILL_N + 1:
		_hill_pts[i * 2 + 1] = Vector2(_c.x - _r + 2.0 * _r * float(i) / HILL_N, _hy + 1.0)
	for i in TREE_N + 1:
		_tree_pts[i * 2 + 1] = Vector2(_c.x - _r + 2.0 * _r * float(i) / TREE_N, _hy + 1.0)
	# Engraved hour ticks on the rim: every hour on desktop, every three on a phone; 06, 12, 18 longer.
	_ticks_dark.clear()
	_ticks_light.clear()
	for h in range(6, 19, 3 if _compact else 1):
		var p := clampf((float(h) / 24.0 - RISE) / (SET - RISE), 0.0, 1.0)
		var d := Vector2.from_angle(PI + p * PI)
		var inner := _r - (6.5 if h % 6 == 0 else 4.0)
		_ticks_dark.append_array(PackedVector2Array([_c + d * inner, _c + d * (_r - 1.0)]))
		var o := Vector2(0.6, 0.6)  # the light edge of the engraving
		_ticks_light.append_array(PackedVector2Array([_c + d * inner + o, _c + d * (_r - 1.0) + o]))
	_rays.resize(16)
	_stars.clear()
	_star_size.clear()
	for s: Vector3 in STARS:
		var p := _c + Vector2(s.x * _r, -(0.22 + s.y * 0.7) * _r)
		if p.distance_to(_c) < _r * 0.9:
			_stars.append(p)
			_star_size.append(s.z if not _compact else 1.0)
	# The 24 h track: night, dawn, day, dusk, night colour stops (static).
	_track = Rect2(6.0, _hy + 5.0, w - 12.0, 3.0 if _compact else 4.0)
	var stops := PackedFloat32Array([0.0, RISE - 0.04, RISE + 0.02, 0.5, SET - 0.02, SET + 0.04, 1.0])
	var cols := PackedColorArray([Color(0.16, 0.20, 0.42), Color(0.20, 0.22, 0.45), Color(1.0, 0.55, 0.30),
		Color(1.0, 0.86, 0.40), Color(1.0, 0.52, 0.26), Color(0.20, 0.22, 0.45), Color(0.16, 0.20, 0.42)])
	_track_pts.clear()
	_track_cols.clear()
	for i in stops.size():
		var x := _track.position.x + _track.size.x * stops[i]
		_track_pts.append_array(PackedVector2Array([Vector2(x, _track.position.y), Vector2(x, _track.end.y)]))
		_track_cols.append_array(PackedColorArray([cols[i], cols[i]]))
	_track_idx = _quad_strip(stops.size() - 1)

## Indices for a strip of n quads over points laid out top, bottom, top, bottom...
static func _quad_strip(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in n:
		var a := i * 2
		out.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	return out

## A point on the bodies' arc: p 0 = the left horizon (east, sunrise), 1 = the right (west, sunset).
func _body_at(p: float) -> Vector2:
	return _c + Vector2(-cos(p * PI), -sin(p * PI)) * _orbit

## Where the rim gleam is (0..1 across the rim), or -1 between gleams. Real time: it is shine, not time.
func _gleam(t: float) -> float:
	var every := GLEAM_EVERY * (0.35 if flourish(t) > 0.0 else 1.0)
	var u := fmod(float(Time.get_ticks_msec()) * 0.001, every) / GLEAM_S
	return u if u <= 1.0 else -1.0

# ---------------------------------------------------------------- draw

func _draw() -> void:
	var start := Time.get_ticks_usec()
	draws += 1
	var t := clock().x
	var now := float(Time.get_ticks_msec()) * 0.001
	var f := flourish(t)
	draw_set_transform(Vector2(size.x - _face.x, 0.0))
	var zen := sky_color(t, false)
	var hor := sky_color(t, true)
	var sp := sun_p(t)
	var mp := moon_p(t)
	var sun := _body_at(sp)
	_draw_sky(t, zen, hor, sun, sp, f, now)
	var stars := star_alpha(t)
	_draw_stars(stars, now)
	drawn_sun = Vector2(NAN, NAN)
	drawn_moon = Vector2(NAN, NAN)
	if mp > -0.08 and mp < 1.08:
		drawn_moon = _body_at(mp)
		_draw_moon(drawn_moon, _r * 0.12, stars)
	if sp > -0.08 and sp < 1.08:
		drawn_sun = sun
		_draw_sun(sun, _r * 0.14, f, now)
	_draw_clouds(t, zen, hor, sp)
	_draw_land(t, hor, sun)
	if sun_up(t) and not _compact:
		_draw_flare(sun, sp)
	_draw_rim(t, f)
	_draw_strip(t)
	draw_set_transform(Vector2.ZERO)
	if is_open():
		_draw_label(t)
	draw_usec += Time.get_ticks_usec() - start

## The painted sky: zenith to horizon, a warm glow round the sun, the dawn / dusk band, a bloom that
## pulses at sunrise and sunset.
func _draw_sky(t: float, zen: Color, hor: Color, sun: Vector2, sp: float, f: float, now: float) -> void:
	var band := band_at(t)
	var up := sin(clampf(sp, 0.0, 1.0) * PI)
	var glow := (0.25 + 0.55 * (1.0 - up)) if sp > -0.12 and sp < 1.12 else 0.0
	var bloom := f * (0.75 + 0.25 * sin(now * 4.0))
	for i in _sky_pts.size():
		var p := _sky_pts[i]
		var k := clampf((_hy - p.y) / _r, 0.0, 1.0)
		var col := hor.lerp(zen, pow(k, 0.8))
		if band.y > 0.0:
			col = col.lerp(BAND, band.y * 0.55 * maxf(0.0, 1.0 - absf(k - band.x) / 0.3))
		if glow > 0.0:
			col = col.lerp(Color(1.0, 0.80, 0.50), glow * 0.6 * maxf(0.0, 1.0 - p.distance_to(sun) / (_r * 0.9)))
		if bloom > 0.0:
			col = col.lerp(Color(1.0, 0.72, 0.42), bloom * 0.5 * maxf(0.0, 1.0 - k / 0.6))
		_sky_cols[i] = col
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _sky_idx, _sky_pts, _sky_cols)

func _draw_stars(a: float, now: float) -> void:
	drawn_stars = 0
	if a <= 0.0:
		return
	for i in _stars.size():
		drawn_stars += 1
		var tw := 0.55 + 0.45 * sin(now * (1.7 + 0.31 * i) + i * 2.1)
		draw_rect(Rect2(_stars[i] - Vector2.ONE * _star_size[i] * 0.5, Vector2.ONE * _star_size[i]), Color(1, 1, 1, a * tw))
	# Now and then a shooting star, high in the sky, left to right or right to left.
	var n := floorf(now / SHOOT_EVERY)
	var u := (now - n * SHOOT_EVERY) / SHOOT_S
	if a > 0.6 and u <= 1.0 and fposmod(n * 0.618, 1.0) < 0.7:
		var dir := 1.0 if fposmod(n * 0.37, 1.0) < 0.5 else -1.0
		var head := Vector2(_c.x - dir * _r * 0.55 + dir * _r * u, _hy - _r * (0.55 + 0.25 * fposmod(n * 0.73, 1.0)) + _r * 0.18 * u)
		var fade := sin(u * PI) * a
		draw_line(head - Vector2(dir * _r * 0.3, _r * 0.055), head, Color(1, 1, 1, 0.45 * fade), 1.0, true)
		draw_circle(head, 1.2, Color(1, 1, 1, fade))

func _draw_sun(at: Vector2, rb: float, f: float, now: float) -> void:
	var room := _r - 2.0 - at.distance_to(_c)  # the corona stays inside the rim
	draw_circle(at, minf(rb * 3.0, room + rb), Color(SUN, 0.10 + 0.12 * f))  # corona
	draw_circle(at, minf(rb * 2.1, room + rb), Color(SUN, 0.18 + 0.15 * f))
	draw_circle(at, rb * 1.45, Color(1.0, 0.86, 0.5, 0.45))
	var spin := now * 0.35
	var reach := minf(1.75 + 1.6 * f, maxf(1.45, (room + rb) / rb))  # rays stay inside the rim too
	for i in 8:
		var d := Vector2.from_angle(spin + TAU * float(i) / 8.0)
		_rays[i * 2] = at + d * rb * 1.35
		_rays[i * 2 + 1] = at + d * rb * (reach if i % 2 == 0 else reach * 0.8)
	draw_multiline(_rays, Color(1.0, 0.90, 0.6, 0.35 + 0.5 * f), 1.2, true)
	draw_circle(at, rb, SUN)
	draw_circle(at - Vector2(rb, rb) * 0.28, rb * 0.5, Color(1.0, 0.97, 0.82, 0.85))

func _draw_moon(at: Vector2, rb: float, a: float) -> void:
	draw_circle(at, rb * 2.6, Color(MOON, 0.06 + 0.06 * a))  # halo
	draw_circle(at, rb * 1.7, Color(MOON, 0.12 + 0.08 * a))
	draw_circle(at, rb, MOON)
	draw_circle(at + Vector2(rb * 0.32, -rb * 0.18), rb * 0.28, Color(0.68, 0.73, 0.86))
	draw_circle(at + Vector2(-rb * 0.34, rb * 0.30), rb * 0.20, Color(0.70, 0.75, 0.88))
	draw_circle(at + Vector2(-rb * 0.1, -rb * 0.45), rb * 0.12, Color(0.72, 0.77, 0.90))

## Soft clouds drift across the dial with the hours; lit by the sky, white at noon, rose at dusk, slate
## at night, each fading out before it reaches the rim.
func _draw_clouds(t: float, zen: Color, hor: Color, sp: float) -> void:
	var day := clampf(sin(clampf(sp, 0.0, 1.0) * PI) * 1.6, 0.0, 1.0) if sun_up(t) else 0.0
	var lit := hor.lerp(Color.WHITE, 0.35 + 0.45 * day)
	var shade := zen.lerp(hor, 0.5).darkened(0.15)
	var alpha := (0.42 + 0.3 * day) if sun_up(t) else 0.18 + 0.2 * (1.0 - star_alpha(t))
	for cl: Vector4 in CLOUDS:
		var s := cl.y * _r
		var y := _hy - cl.x * _r
		var half := sqrt(maxf(0.0, _r * _r - (_hy - y) * (_hy - y))) - s
		var x := _c.x - half - s * 2.0 + fposmod(cl.w + t * cl.z, 1.0) * (half * 2.0 + s * 4.0)
		var edge := clampf((half - absf(x - _c.x)) / (s * 1.5), 0.0, 1.0)
		if edge <= 0.0:
			continue
		for pf: Vector3 in PUFFS:
			draw_circle(Vector2(x + pf.x * s, y + pf.y * s + s * 0.18), pf.z * s, Color(shade, alpha * edge * 0.6))
		for pf: Vector3 in PUFFS:
			draw_circle(Vector2(x + pf.x * s, y + pf.y * s), pf.z * s, Color(lit, alpha * edge))

## Far hills and a near treeline, each drifting at its own speed as the day turns (parallax), the
## hills' tops lit on the sun's side.
func _draw_land(t: float, hor: Color, sun: Vector2) -> void:
	var far := hor.lerp(Color(0.10, 0.13, 0.16), 0.62)
	var far_low := far.darkened(0.35)
	var near := hor.lerp(Color(0.02, 0.035, 0.03), 0.86)
	var lit := 0.35 if sun_up(t) else 0.0
	for i in HILL_N + 1:
		var u := float(i) / HILL_N
		var x := _c.x - _r + 2.0 * _r * u
		var v := u + t
		var h := 0.13 + 0.06 * sin(TAU * v) + 0.035 * sin(TAU * 3.0 * v + 1.3)
		_hill_pts[i * 2] = Vector2(x, _hy - h * _r * _taper(x))
		_hill_cols[i * 2] = far.lerp(Color(1.0, 0.85, 0.6), lit * maxf(0.0, 1.0 - absf(x - sun.x) / _r) * 0.5)
		_hill_cols[i * 2 + 1] = far_low
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _strip_idx, _hill_pts, _hill_cols)
	for i in TREE_N + 1:
		var u := float(i) / TREE_N
		var x := _c.x - _r + 2.0 * _r * u
		var v := u + t * 3.0
		var tri := 1.0 - absf(fposmod(v * TREES, 1.0) * 2.0 - 1.0)  # a pointed crown per tree
		var h := 0.045 + 0.10 * tri * tri * (0.7 + 0.3 * sin(TAU * 2.0 * v + 0.4))
		_tree_pts[i * 2] = Vector2(x, _hy - h * _r * _taper(x))
		_tree_cols[i * 2] = near.lerp(hor, 0.12)
		_tree_cols[i * 2 + 1] = near
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _tree_idx, _tree_pts, _tree_cols)

## Silhouettes flatten into the horizon near the rim, so they never leave the dial.
func _taper(x: float) -> float:
	return clampf((_r - absf(x - _c.x)) / (_r * 0.32), 0.0, 1.0)

## Lens-flare glints on the line from the sun through the dial's middle (desktop only).
func _draw_flare(sun: Vector2, sp: float) -> void:
	var mid := _c - Vector2(0.0, _r * 0.45)
	var a := 0.14 * clampf(sin(clampf(sp, 0.0, 1.0) * PI) * 2.0, 0.0, 1.0)
	for i in FLARE.size():
		var g: Vector2 = FLARE[i]
		var p := sun.lerp(mid, g.x)
		if p.distance_to(_c) < _r * 0.86 and p.y < _hy - 6.0:
			draw_circle(p, g.y, Color(1.0, 0.92, 0.7, a))

func _draw_rim(t: float, f: float) -> void:
	var w := 3.0 if _compact else 4.0
	draw_arc(_c, _r, PI, TAU, 40, RIM_DARK, w, true)
	draw_arc(_c, _r - w * 0.25, PI, TAU, 40, RIM_LIGHT.lerp(Color.WHITE, f * 0.5), w * 0.4, true)
	draw_multiline(_ticks_dark, Color(UiTokens.CTA_INK, 0.75), 1.0, true)
	draw_multiline(_ticks_light, Color(RIM_LIGHT, 0.55), 1.0, true)
	var g := _gleam(t)
	if g >= 0.0:  # a bright gleam sweeping along the gold, east to west
		var a := PI + g * PI
		var s := sin(g * PI)
		draw_arc(_c, _r - w * 0.3, a - 0.22, a + 0.22, 8, Color(1.0, 0.96, 0.8, 0.35 * s), w * 1.4, true)
		draw_arc(_c, _r - w * 0.3, a - 0.09, a + 0.09, 6, Color(1, 1, 1, 0.9 * s), w * 0.6, true)

## The strip: the 24 h track, a gold caret at now and the clock.
func _draw_strip(t: float) -> void:
	draw_rect(Rect2(_c.x - _r - 1.0, _hy, _r * 2.0 + 2.0, _face.y - _hy), UiTokens.HUD_FILL)
	draw_line(Vector2(_c.x - _r - 1.0, _hy), Vector2(_c.x + _r + 1.0, _hy), RIM_LIGHT, 1.5)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _track_idx, _track_pts, _track_cols)
	var cx := _track.position.x + _track.size.x * t
	draw_circle(Vector2(cx, _track.get_center().y), 5.0, Color(UiTokens.GOLD, 0.25))
	_caret[0] = Vector2(cx, _track.position.y)
	_caret[1] = Vector2(cx - 4.0, _track.end.y + 5.0)
	_caret[2] = Vector2(cx + 4.0, _track.end.y + 5.0)
	draw_colored_polygon(_caret, UiTokens.GOLD)
	var px := 13 if _compact else 15
	draw_string(UiTokens.ui_face(UiTokens.WEIGHT_BOLD), Vector2(0.0, _face.y - 3.0), _clock_text, HORIZONTAL_ALIGNMENT_CENTER, _face.x, px, UiTokens.TEXT)

func _draw_label(t: float) -> void:
	var view := get_viewport_rect().size
	var box := Rect2(Vector2.ZERO, Vector2(size.x - _face.x - GAP, _face.y))
	draw_rect(box, UiTokens.HUD_FILL)
	draw_rect(Rect2(box.position, Vector2(3.0, box.size.y)), SUN if sun_up(t) else MOON)
	draw_string(UiTokens.ui_face(UiTokens.WEIGHT_BOLD), Vector2(12.0, _face.y * 0.5 - 4.0), _lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.body(view), UiTokens.TEXT)
	draw_string(UiTokens.ui_face(), Vector2(12.0, _face.y * 0.5 + 15.0), _lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), UiTokens.META)
