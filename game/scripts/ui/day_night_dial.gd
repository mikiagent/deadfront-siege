class_name DayNightDial
extends Control
## The HUD's day/night dial, docked to the minimap's bottom-left edge (docs/design/durango-prompts/
## 16_hud_day_night_dial.md, docs/reference/durango-hud-daynight.webp). A 24-hour face, noon at the top
## and midnight at the bottom: the sun disc rides a white arc across the sky by day and the moon (opposite
## it) by night, over a sky tinted by the phase. A tap opens a label to its left with the phase, the
## clock and the time until the next phase; it closes on a second tap or after OPEN_S. It reads the
## game's cycle through clock() and never sets it (systems PRD:289: the cycle length is the game's
## tunable, not ours).

const DISC := 60.0  ## the round tap target, px (UiTokens.TARGET_MIN is 44)
const GAP := 6.0  ## between the label and the disc
const DOCK := 4.0  ## between the disc and the minimap's left edge
const OPEN_S := 4.0  ## the label closes itself after this
## Where each phase starts: Game.phase_name()'s thresholds, which WorldLighting mirrors (t_lighting).
const STARTS := [[WorldLighting.DAWN, &"dawn"], [WorldLighting.DAY, &"day"], [WorldLighting.DUSK, &"dusk"], [WorldLighting.NIGHT, &"night"]]
## Colour is for things (the sky, the sun, the moon); the ring and the arc are white: it is a control.
const SKY := {&"night": Color(0.06, 0.08, 0.18), &"dawn": Color(0.42, 0.27, 0.36), &"day": Color(0.20, 0.42, 0.62), &"dusk": Color(0.50, 0.27, 0.19)}
const SUN := Color(1.0, 0.78, 0.30)
const MOON := Color(0.86, 0.90, 1.0)
const GROUND := Color(0.0, 0.0, 0.0, 0.38)

var _anchor := Vector2.ZERO  ## top-right corner of the disc; the label opens leftwards
var _open_left := 0.0  ## seconds until the label closes; 0 = closed
var _down := false
var _minute := -1  ## the game minute last drawn

func _init() -> void:
	name = "DayNightDial"
	size = Vector2(DISC, DISC)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE  # like the HUD hexes: a focused control would take Space (roll)

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
	var nxt := next_phase(t)
	var secs := float(nxt[1]) * day_s
	var wait := "%d s" % ceili(secs) if ceili(secs) < 60 else "%d min" % roundi(secs / 60.0)
	var mins := int(t * 1440.0) % 1440
	return PackedStringArray(["%s  %02d:%02d" % [str(phase_at(t)).capitalize(), floori(mins / 60.0), mins % 60],
		"%s in %s" % [str(nxt[0]).capitalize(), wait]])

## Where the sun sits on the face: midnight down, 06:00 left, noon up, 18:00 right.
static func sun_dir(t: float) -> Vector2:
	return Vector2(-sin(t * TAU), cos(t * TAU))

## The HUD docks the disc to the minimap's bottom-left edge, off the map (it grows leftwards while
## the label is open, away from the map).
func dock(map: Rect2) -> void:
	_anchor = Vector2(map.position.x - DOCK, map.end.y - DISC)
	_fit()

func is_open() -> bool:
	return _open_left > 0.0

func toggle() -> void:
	_open_left = 0.0 if is_open() else OPEN_S
	_fit()

func _fit() -> void:
	var w := DISC
	if is_open():
		var view := get_viewport_rect().size if is_inside_tree() else Vector2(1600, 900)
		var lines := label_lines(clock().x, clock().y)
		var font := ThemeDB.fallback_font
		w += GAP + 24.0 + maxf(font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.body(view)).x,
			font.get_string_size(lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view)).x)
	size = Vector2(w, DISC)
	position = _anchor - Vector2(w, 0.0)
	queue_redraw()

func _process(delta: float) -> void:
	if is_open():
		_open_left = maxf(0.0, _open_left - delta)
		if not is_open():
			_fit()
	var minute := int(clock().x * 1440.0)
	if minute != _minute:
		_minute = minute
		if is_open():
			_fit()  # the countdown's width changes
		queue_redraw()

func _has_point(point: Vector2) -> bool:
	if is_open():
		return Rect2(Vector2.ZERO, size).has_point(point)
	return point.distance_to(_centre()) <= DISC * 0.5

func _centre() -> Vector2:
	return Vector2(size.x - DISC * 0.5, DISC * 0.5)

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

func _draw() -> void:
	var t := clock().x
	var phase := phase_at(t)
	var c := _centre()
	var r := DISC * 0.5 - 1.5
	var arc := r * 0.6  # the sun's and moon's path
	draw_circle(c, r, SKY[phase])
	draw_arc(c, arc, PI - 0.4, TAU + 0.4, 32, Color(1, 1, 1, 0.6), 1.5, true)  # the path, a little past each horizon
	var night := phase == &"night"
	var at := c + (-sun_dir(t) if night else sun_dir(t)) * arc
	if night:
		draw_circle(at, r * 0.26, MOON)
		draw_circle(at + Vector2(r * 0.12, -r * 0.09), r * 0.21, SKY[phase])  # the dark side makes a crescent
	else:
		draw_circle(at, r * 0.36, Color(SUN, 0.35))  # glow
		draw_circle(at, r * 0.24, SUN)
	var ground := PackedVector2Array()
	for i in 17:
		ground.append(c + Vector2(cos(PI * float(i) / 16.0), sin(PI * float(i) / 16.0)) * r)
	draw_colored_polygon(ground, GROUND)  # over the path, so a sun below the horizon is dimmed
	draw_line(c - Vector2(r, 0.0), c + Vector2(r, 0.0), Color(1, 1, 1, 0.35), 1.0)
	draw_arc(c, r, 0.0, TAU, 48, Color.WHITE, 2.0, true)
	if not is_open():
		return
	var view := get_viewport_rect().size
	var box := Rect2(Vector2.ZERO, Vector2(size.x - DISC - GAP, DISC))
	draw_rect(box, UiTokens.INK)
	draw_rect(Rect2(box.position, Vector2(3.0, box.size.y)), MOON if night else SUN)
	var lines := label_lines(t, clock().y)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12.0, DISC * 0.5 - 4.0), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.body(view), UiTokens.TEXT)
	draw_string(font, Vector2(12.0, DISC * 0.5 + 15.0), lines[1], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.meta(view), UiTokens.META)
