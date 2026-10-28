class_name DayNightDial
extends Control
## The HUD's day/night widget, docked to the minimap's bottom-left edge (docs/design/durango-prompts/
## 16_hud_day_night_dial.md; DAYNIGHT, owner 2026-10-28: "I don't like the day/night cycle UI and I want
## you to improve it and animate it so it looks cooler"). Three faces for the owner to pick from, one
## switch (`variant`, or `--daynight=a|b|c` after `--` on the command line):
##   a  a flat-top hex sky window: the sun and moon on an arc over a hill line, the clock on the ground,
##      a gold "now" pip riding the rim (midnight at the bottom, noon at the top);
##   b  a half-dial horizon: the sun and moon wheel over a half-disc sky, a 24 h track under it with the
##      daylight span lit and a gold caret at now, the clock under the track;
##   c  a slim sky band that scrolls: the sky colours of the hours around now, the light's path, stars in
##      the night hours, a gold needle at now with the sun or moon on it, the clock under the needle.
## All share the sky gradient (keyed to WorldLighting's phase times), stars that fade in after sunset and
## out before sunrise, and a flourish at sunrise and sunset (rays, a horizon glow, the rim flashing gold).
## A tap opens a label to its left with the phase, the clock and the time until the next phase; it closes
## on a second tap or after OPEN_S. It reads the game's cycle through clock() and never sets it (systems
## PRD:289: the cycle length is the game's tunable, not ours). Cheap: geometry is built on layout, the draw
## writes into preallocated arrays, the strings are rebuilt once a game minute, and it redraws every frame
## only while stars twinkle or a flourish plays (else every 15 game seconds).

const GAP := 6.0  ## between the label and the face
const DOCK := 4.0  ## between the face and the minimap's left edge
const OPEN_S := 4.0  ## the label closes itself after this
const VARIANTS: Array[StringName] = [&"a", &"b", &"c"]
## Where each phase starts: Game.phase_name()'s thresholds, which WorldLighting mirrors (t_lighting).
const STARTS := [[WorldLighting.DAWN, &"dawn"], [WorldLighting.DAY, &"day"], [WorldLighting.DUSK, &"dusk"], [WorldLighting.NIGHT, &"night"]]
## ASSUMPTION: the sun crosses the horizon halfway through dawn and dusk (06:14 and 18:14); the PRD only
## names the phases.
const RISE := (WorldLighting.DAWN + WorldLighting.DAY) * 0.5
const SET := (WorldLighting.DUSK + WorldLighting.NIGHT) * 0.5
const FLOURISH := 0.02  ## share of a day either side of sunrise / sunset the flourish plays (14 s of 720)
const STAR_FADE := 0.05  ## stars fade in over this share of a day after sunset, out before sunrise
## Colour is for things (the sky, the sun, the moon); the rim and the paths are white: it is a control.
const SUN := Color(1.0, 0.78, 0.30)
const MOON := Color(0.86, 0.90, 1.0)
const NIGHT_TOP := Color(0.02, 0.03, 0.10)
const NIGHT_LOW := Color(0.07, 0.09, 0.21)
const DAY_TOP := Color(0.16, 0.42, 0.78)
const DAY_LOW := Color(0.58, 0.79, 0.93)
## [time of day, zenith, horizon]: the sky between the keys is a straight blend.
const SKY_KEYS := [
	[0.0, NIGHT_TOP, NIGHT_LOW], [0.20, NIGHT_TOP, NIGHT_LOW],
	[0.235, Color(0.11, 0.09, 0.28), Color(0.55, 0.28, 0.40)],
	[0.27, Color(0.25, 0.33, 0.62), Color(1.0, 0.60, 0.34)],
	[0.32, DAY_TOP, DAY_LOW], [0.68, DAY_TOP, DAY_LOW],
	[0.745, Color(0.24, 0.22, 0.48), Color(1.0, 0.50, 0.24)],
	[0.79, Color(0.08, 0.06, 0.21), Color(0.36, 0.16, 0.30)],
	[0.83, NIGHT_TOP, NIGHT_LOW], [1.0, NIGHT_TOP, NIGHT_LOW]]
const GROUND := Color(0.035, 0.05, 0.045)
## Star field in face units: x 0..1 across, y 0..1 down the sky (0 = top), z = size in px. c spreads x
## over the night hours instead, so the stars scroll in with the night.
const STARS := [Vector3(0.12, 0.20, 1), Vector3(0.27, 0.08, 2), Vector3(0.38, 0.33, 1), Vector3(0.52, 0.14, 1),
	Vector3(0.63, 0.40, 2), Vector3(0.74, 0.10, 1), Vector3(0.86, 0.28, 1), Vector3(0.20, 0.47, 1),
	Vector3(0.46, 0.55, 1), Vector3(0.80, 0.52, 1), Vector3(0.33, 0.22, 1), Vector3(0.68, 0.24, 1),
	Vector3(0.05, 0.36, 1), Vector3(0.93, 0.14, 2), Vector3(0.57, 0.30, 1), Vector3(0.16, 0.05, 1)]
const BAND_COLS := 12  ## c: sky columns across the band
const PATH_N := 24  ## c: points on the light's path

static var variant: StringName = &""

var _anchor := Vector2.ZERO  ## top-right corner of the face; the label opens leftwards
var _open_left := 0.0  ## seconds until the label closes; 0 = closed
var _down := false
var _tick := -1  ## the 15-game-second step last drawn
var _minute := -1  ## the game minute the strings were built for
var _built := Vector3(-1, -1, -1)  ## face w, h and variant index the geometry was built for
var _face := Vector2(66, 64)
var _compact := false
## Built on layout; the draw only writes colours and positions into them.
var _sky_pts := PackedVector2Array()
var _sky_cols := PackedColorArray()
var _sky_k := PackedFloat32Array()  ## 0 at the zenith, 1 at the horizon
var _sky_dt := PackedFloat32Array()  ## c: the time offset each column shows
var _sky_idx := PackedInt32Array()
var _ground := PackedVector2Array()
var _rim := PackedVector2Array()
var _path := PackedVector2Array()  ## a/b: the bodies' arc; c: the light's path
var _caret := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])  ## b: the now caret
var _stars := PackedVector2Array()
var _star_size := PackedFloat32Array()
var _arc_c := Vector2.ZERO  ## the bodies' arc: centre on the horizon and radii
var _arc_r := Vector2.ZERO
var _r := 0.0  ## a: the hex's circumradius; b: the half-disc's radius
var _hy := 0.0  ## the horizon's y in the face
var _band := 0.0  ## c: the band's height (the clock tab sits under it)
var _win := 0.25  ## c: half the band's width in days
## Rebuilt once a game minute.
var _clock_text := ""
var _phase_text := ""
var _next_text := ""
var _lines := PackedStringArray(["", ""])
## What the last draw put where (face coordinates; NAN when hidden), for tests and labs.
var drawn_sun := Vector2(NAN, NAN)
var drawn_moon := Vector2(NAN, NAN)
var drawn_stars := 0
var draws := 0

func _init() -> void:
	name = "DayNightDial"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE  # like the HUD hexes: a focused control would take Space (roll)
	if variant == &"":
		variant = VARIANTS[0]
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--daynight=") and StringName(a.substr(11)) in VARIANTS:
				variant = StringName(a.substr(11))
	size = face_size(variant, false)

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

## How high the light is at time t, 0..1 (the sun's arc by day, the moon's by night).
static func elev(t: float) -> float:
	var sp := sun_p(t)
	if sp >= 0.0 and sp <= 1.0:
		return sin(sp * PI)
	return maxf(0.0, sin(moon_p(t) * PI))

## The face's size for a variant. Compact canvases get 66x64 for every face: 64 px tall for the tap,
## 66 wide to stay inside the map column UiTokens.hud_reserved keeps clear (234 px in from the right).
static func face_size(v: StringName, compact: bool) -> Vector2:
	if compact:
		return Vector2(66, 64)
	match v:
		&"b":
			return Vector2(112, 76)
		&"c":
			return Vector2(200, 62)
	return Vector2(78, 68)

## The HUD docks the face to the minimap's bottom-left edge, off the map (it grows leftwards while
## the label is open, away from the map).
func dock(map: Rect2) -> void:
	_compact = UiTokens.is_compact(get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900))
	_face = face_size(variant, _compact)
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
	var key := Vector3(_face.x, _face.y, VARIANTS.find(variant))
	if key != _built:
		_built = key
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
	_phase_text = str(phase_at(t)).to_upper()
	_next_text = "%s IN %s" % [str(next_phase(t)[0]).to_upper(), wait_text(t, clock().y).to_upper()]

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
	if tick != _tick or star_alpha(t) > 0.0 or flourish(t) > 0.0:
		_tick = tick
		queue_redraw()

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)

## The face's top-left in the control (the label sits left of it).
func _origin() -> Vector2:
	return Vector2(size.x - _face.x, 0.0)

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
	_sky_pts.clear()
	_sky_k.clear()
	_sky_dt.clear()
	_sky_idx.clear()
	_ground.clear()
	_rim.clear()
	_path.clear()
	_stars.clear()
	_star_size.clear()
	match variant:
		&"b":
			_build_b(_face.x, _face.y)
		&"c":
			_build_c(_face.x, _face.y)
		_:
			_build_a(_face.x, _face.y)
	_sky_cols.resize(_sky_pts.size())

## a: a flat-top hex, sky above a hill line just under its middle, the ground holding the clock.
func _build_a(w: float, h: float) -> void:
	_r = minf(w * 0.5, h / sqrt(3.0)) - 1.0
	var c := Vector2(w * 0.5, h * 0.5)
	var ap := _r * sqrt(3.0) * 0.5
	var hex := UiTokens.hex_points(c, _r, true)  # right, lower right, lower left, left, upper left, upper right
	for i in 6:
		_sky_pts.append(hex[i])
		_sky_k.append(clampf((hex[i].y - (c.y - ap)) / (ap * 1.12), 0.0, 1.0))
		_sky_dt.append(0.0)
	_sky_idx.append_array(PackedInt32Array([0, 1, 2, 0, 2, 3, 0, 3, 5, 3, 4, 5]))
	_rim.append_array(hex)
	_rim.append(hex[0])
	_hy = c.y + ap * 0.12
	var xr := _r - (_hy - c.y) / ap * _r * 0.5  # the hex side at the horizon
	_ground.append_array(PackedVector2Array([Vector2(c.x - xr, _hy), Vector2(c.x - _r * 0.55, _hy - ap * 0.08),
		Vector2(c.x - _r * 0.18, _hy + ap * 0.03), Vector2(c.x + _r * 0.28, _hy - ap * 0.11),
		Vector2(c.x + _r * 0.62, _hy - ap * 0.02), Vector2(c.x + xr, _hy), hex[1], hex[2]]))
	_arc_c = Vector2(c.x, _hy)
	_arc_r = Vector2(_r * 0.64, (_hy - (c.y - ap)) * 0.64)
	_build_arc(20)
	_build_stars(Rect2(c.x - _r * 0.72, c.y - ap * 0.9, _r * 1.44, _hy - (c.y - ap) - ap * 0.25))

## b: a half-disc sky on the horizon, a 24 h track and the clock in a strip under it.
func _build_b(w: float, h: float) -> void:
	var strip := 24.0 if _compact else 28.0
	_hy = h - strip
	_r = minf(w * 0.5 - 1.5, _hy - 1.5)
	var c := Vector2(w * 0.5, _hy)
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		var p := c + Vector2(cos(a), sin(a)) * _r
		_sky_pts.append(p)
		_sky_k.append(clampf((p.y - (c.y - _r)) / _r, 0.0, 1.0))
		_sky_dt.append(0.0)
	for i in range(1, 16):
		_sky_idx.append_array(PackedInt32Array([0, i, i + 1]))
	_rim.append_array(_sky_pts)
	_arc_c = c
	_arc_r = Vector2(_r * 0.74, _r * 0.74)
	_build_arc(24)
	_build_stars(Rect2(c.x - _r * 0.8, c.y - _r * 0.88, _r * 1.6, _r * 0.72))

## c: a band of BAND_COLS sky columns, each showing the sky at its own hour, the clock under it.
func _build_c(w: float, h: float) -> void:
	_band = h - (24.0 if _compact else 22.0)
	_win = (4.0 if _compact else 6.0) / 24.0
	_hy = _band * 0.8
	for i in BAND_COLS + 1:
		var x := w * float(i) / BAND_COLS
		var dt := (float(i) / BAND_COLS - 0.5) * 2.0 * _win
		_sky_pts.append_array(PackedVector2Array([Vector2(x, 0.0), Vector2(x, _hy)]))
		_sky_k.append_array(PackedFloat32Array([0.0, 1.0]))
		_sky_dt.append_array(PackedFloat32Array([dt, dt]))
	for i in BAND_COLS:
		var a := i * 2
		_sky_idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	_ground.append_array(PackedVector2Array([Vector2(0, _hy), Vector2(w, _hy), Vector2(w, _band), Vector2(0, _band)]))
	_rim.append_array(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, _band), Vector2(0, _band), Vector2(0, 0)]))
	_arc_r = Vector2(0.0, _hy * 0.74)
	for i in PATH_N + 1:
		_path.append(Vector2(w * float(i) / PATH_N, _hy))
	var night := 1.0 - (SET - RISE)
	for s: Vector3 in STARS:  # x: the star's hour, spread over the night; y: its height
		_stars.append(Vector2(fposmod(SET + 0.02 + s.x * (night - 0.04), 1.0), _hy * (0.08 + s.y * 0.62)))
		_star_size.append(s.z)

func _build_arc(n: int) -> void:
	for i in n + 1:
		_path.append(_body_at(float(i) / n))

func _build_stars(box: Rect2) -> void:
	for s: Vector3 in STARS:
		var p := box.position + Vector2(s.x, s.y * 1.6) * box.size
		if p.y <= box.end.y:
			_stars.append(p)
			_star_size.append(s.z)

## A point on the a/b arc: p 0 = the left horizon (east, sunrise), 1 = the right (west, sunset).
func _body_at(p: float) -> Vector2:
	return _arc_c + Vector2(-cos(p * PI) * _arc_r.x, -sin(p * PI) * _arc_r.y)

# ---------------------------------------------------------------- draw

func _draw() -> void:
	draws += 1
	var t := clock().x
	draw_set_transform(_origin())
	for i in _sky_pts.size():
		var tt := t + _sky_dt[i]
		_sky_cols[i] = sky_color(tt, false).lerp(sky_color(tt, true), _sky_k[i])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _sky_idx, _sky_pts, _sky_cols)
	var f := flourish(t)
	match variant:
		&"b":
			_draw_b(t, f)
		&"c":
			_draw_c(t, f)
		_:
			_draw_a(t, f)
	draw_set_transform(Vector2.ZERO)
	if is_open():
		_draw_label(t)

func _rim_color(f: float) -> Color:
	return UiTokens.HUD_RIM.lerp(UiTokens.GOLD, f * 0.85)

func _draw_a(t: float, f: float) -> void:
	_draw_stars_fixed(star_alpha(t))
	draw_polyline(_path, Color(1, 1, 1, 0.22), 1.0, true)
	_draw_bodies(t, f, _r * 0.15, 0.12)
	draw_colored_polygon(_ground, GROUND.lerp(sky_color(t, true), 0.14))
	draw_polyline(_rim, _rim_color(f), 2.5 if _compact else 3.0, true)
	# Now: a gold pip on the rim, midnight at the bottom, 06:00 left, noon top, 18:00 right.
	var a := PI * 0.5 + t * TAU
	var c := _face * 0.5
	var pip := c + Vector2(cos(a), sin(a)) * UiTokens.hex_radius_at(a, _r, true)
	draw_circle(pip, 5.0, UiTokens.CTA_INK)
	draw_circle(pip, 3.5, UiTokens.GOLD)
	var px := 13 if _compact else 15
	var base := (_hy + c.y + _r * 0.866) * 0.5 + px * 0.38
	draw_string(UiTokens.ui_face(UiTokens.WEIGHT_BOLD), Vector2(0.0, base), _clock_text, HORIZONTAL_ALIGNMENT_CENTER, _face.x, px, UiTokens.TEXT)

func _draw_b(t: float, f: float) -> void:
	_draw_stars_fixed(star_alpha(t))
	draw_arc(_arc_c, _arc_r.x, PI, TAU, 24, Color(1, 1, 1, 0.22), 1.0, true)
	for i in 5:  # 06, 09, 12, 15, 18 ticks inside the rim
		var d := Vector2.from_angle(PI + PI * float(i) / 4.0)
		draw_line(_arc_c + d * (_r - 5.0), _arc_c + d * (_r - 1.5), Color(1, 1, 1, 0.5), 1.0, true)
	_draw_bodies(t, f, _r * 0.14, 0.08)
	# The strip: a 24 h track (the daylight span lit, a gold caret at now) and the clock.
	draw_rect(Rect2(0.0, _hy, _face.x, _face.y - _hy), UiTokens.HUD_FILL)
	var track := Rect2(6.0, _hy + 4.0, _face.x - 12.0, 3.0)
	draw_rect(track, Color(0.22, 0.27, 0.45))
	draw_rect(Rect2(track.position.x + track.size.x * RISE, track.position.y, track.size.x * (SET - RISE), track.size.y), Color(SUN, 0.85))
	var cx := track.position.x + track.size.x * t
	_caret[0] = Vector2(cx, track.position.y + 1.0)
	_caret[1] = Vector2(cx - 4.0, track.end.y + 5.0)
	_caret[2] = Vector2(cx + 4.0, track.end.y + 5.0)
	draw_colored_polygon(_caret, UiTokens.GOLD)
	var px := 13 if _compact else 15
	draw_string(UiTokens.ui_face(UiTokens.WEIGHT_BOLD), Vector2(0.0, _face.y - 3.0), _clock_text, HORIZONTAL_ALIGNMENT_CENTER, _face.x, px, UiTokens.TEXT)
	draw_polyline(_rim, _rim_color(f), 2.5 if _compact else 3.0, true)
	draw_line(Vector2(0.0, _hy), Vector2(_face.x, _hy), UiTokens.HUD_RIM.lerp(UiTokens.GOLD, f), 1.5)

func _draw_c(t: float, f: float) -> void:
	var w := _face.x
	# Stars at their own hour scroll with the sky; each shows only in the night hours.
	drawn_stars = 0
	var tw := float(Time.get_ticks_msec()) * 0.001
	for i in _stars.size():
		var dt := fposmod(_stars[i].x - t + 0.5, 1.0) - 0.5
		var a := star_alpha(_stars[i].x)
		if absf(dt) > _win or a <= 0.0:
			continue
		drawn_stars += 1
		var x := w * 0.5 + dt / _win * w * 0.5
		draw_rect(Rect2(Vector2(x, _stars[i].y), Vector2.ONE * _star_size[i]), Color(1, 1, 1, a * (0.65 + 0.35 * sin(tw * 2.1 + i * 1.7))))
	# The light's path: the sun's arc by day, the moon's by night, so the next sunset is in view.
	for i in PATH_N + 1:
		_path[i].y = _hy - elev(t + (float(i) / PATH_N - 0.5) * 2.0 * _win) * _arc_r.y
	draw_polyline(_path, Color(1, 1, 1, 0.3), 1.0, true)
	drawn_sun = Vector2(NAN, NAN)
	drawn_moon = Vector2(NAN, NAN)
	var sp := sun_p(t)
	var mp := moon_p(t)
	var rb := 6.0 if _compact else 7.0
	if f > 0.0:
		draw_circle(Vector2(w * 0.5, _hy), rb * 3.4, Color(SUN, 0.22 * f))
	if mp > -0.1 and mp < 1.1:
		drawn_moon = Vector2(w * 0.5, _hy - sin(mp * PI) * _arc_r.y)
		_draw_moon(drawn_moon, rb * 0.85)
	if sp > -0.1 and sp < 1.1:
		drawn_sun = Vector2(w * 0.5, _hy - sin(sp * PI) * _arc_r.y)
		_draw_sun(drawn_sun, rb, f)
	draw_colored_polygon(_ground, GROUND.lerp(sky_color(t, true), 0.14))
	if f > 0.0:
		draw_rect(Rect2(0.0, _hy - 1.0, w, 2.0), Color(UiTokens.GOLD, f))
	# Now: the gold needle, and the clock in a tab under it.
	draw_line(Vector2(w * 0.5, 0.0), Vector2(w * 0.5, _band), Color(UiTokens.CTA_INK, 0.6), 3.0)
	draw_line(Vector2(w * 0.5, 0.0), Vector2(w * 0.5, _band), UiTokens.GOLD, 1.5)
	draw_rect(Rect2(0.0, _band, w, _face.y - _band), UiTokens.HUD_FILL)
	draw_rect(Rect2(0.0, _band, w, 2.0), UiTokens.GOLD)
	var px := 13 if _compact else 15
	var base := _band + (_face.y - _band) * 0.5 + px * 0.38
	draw_string(UiTokens.ui_face(UiTokens.WEIGHT_BOLD), Vector2(0.0, base), _clock_text, HORIZONTAL_ALIGNMENT_CENTER, w, px, UiTokens.TEXT)
	if not _compact:
		var reg := UiTokens.ui_face()
		draw_string(reg, Vector2(8.0, base), _phase_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.CHIP_PX - 1, UiTokens.MUTED)
		# "NIGHT IN 25 S" needs ~70 px at 11 px; at 12 in 66 px it lost its last letters.
		draw_string(reg, Vector2(w * 0.5 + 20.0, base), _next_text, HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5 - 26.0, UiTokens.CHIP_PX - 1, UiTokens.MUTED)
	draw_polyline(_rim, _rim_color(f), 2.0, true)

## a/b: the sun and moon on the arc, each drawn a little past its horizon (the ground then covers it).
func _draw_bodies(t: float, f: float, rb: float, past: float) -> void:
	drawn_sun = Vector2(NAN, NAN)
	drawn_moon = Vector2(NAN, NAN)
	var sp := sun_p(t)
	var mp := moon_p(t)
	if f > 0.0:  # the horizon glows on the side the sun crosses
		var side := _body_at(0.0 if absf(sp) < absf(sp - 1.0) else 1.0)
		draw_circle(side, rb * 3.2, Color(SUN, 0.22 * f))
		draw_circle(side, rb * 2.0, Color(1.0, 0.62, 0.3, 0.3 * f))
	if mp > -past and mp < 1.0 + past:
		drawn_moon = _body_at(mp)
		_draw_moon(drawn_moon, rb * 0.9)
	if sp > -past and sp < 1.0 + past:
		drawn_sun = _body_at(sp)
		_draw_sun(drawn_sun, rb, f)

func _draw_sun(at: Vector2, rb: float, f: float) -> void:
	draw_circle(at, rb * 2.0, Color(SUN, 0.16 + 0.2 * f))
	draw_circle(at, rb * 1.45, Color(SUN, 0.3))
	if f > 0.0:  # sunrise / sunset: rays that turn and grow
		var spin := float(Time.get_ticks_msec()) * 0.0006
		for i in 8:
			var d := Vector2.from_angle(spin + TAU * float(i) / 8.0)
			draw_line(at + d * rb * 1.4, at + d * rb * (1.6 + 1.4 * f), Color(1.0, 0.86, 0.5, 0.85 * f), 1.5, true)
	draw_circle(at, rb, SUN)
	draw_circle(at - Vector2(rb, rb) * 0.3, rb * 0.45, Color(1.0, 0.95, 0.75, 0.8))

func _draw_moon(at: Vector2, rb: float) -> void:
	draw_circle(at, rb * 1.9, Color(MOON, 0.12))
	draw_circle(at, rb, MOON)
	draw_circle(at + Vector2(rb * 0.3, -rb * 0.2), rb * 0.28, Color(0.68, 0.73, 0.86))
	draw_circle(at + Vector2(-rb * 0.35, rb * 0.3), rb * 0.2, Color(0.70, 0.75, 0.88))

func _draw_stars_fixed(a: float) -> void:
	drawn_stars = 0
	if a <= 0.0:
		return
	var tw := float(Time.get_ticks_msec()) * 0.001
	for i in _stars.size():
		drawn_stars += 1
		draw_rect(Rect2(_stars[i], Vector2.ONE * _star_size[i]), Color(1, 1, 1, a * (0.6 + 0.4 * sin(tw * 2.3 + i * 1.7))))

func _draw_label(t: float) -> void:
	var view := get_viewport_rect().size
	var box := Rect2(Vector2.ZERO, Vector2(size.x - _face.x - GAP, _face.y))
	draw_rect(box, UiTokens.HUD_FILL)
	draw_rect(Rect2(box.position, Vector2(3.0, box.size.y)), SUN if sun_up(t) else MOON)
	draw_string(UiTokens.ui_face(UiTokens.WEIGHT_BOLD), Vector2(12.0, _face.y * 0.5 - 4.0), _lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.body(view), UiTokens.TEXT)
	draw_string(UiTokens.ui_face(), Vector2(12.0, _face.y * 0.5 + 15.0), _lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), UiTokens.META)
