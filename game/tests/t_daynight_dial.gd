extends SceneTree
## HUD-DAYNIGHT checks (spec 16): the HUD has a day/night dial docked to the minimap's bottom-left
## edge (this fails on a HUD without one), its phase at time of day 0.0/0.25/0.5/0.75 is
## night/dawn/day/dusk as Game.phase_name() says, a tap opens a label with the phase, the clock and the
## time to the next phase (rounded minutes, never "60 s"), a release off the dial cancels the tap, it
## lays out again on a resize without touching the minimap, and it never writes the game's clock.
## DAYNIGHT: the half-dial draws, follows the clock across 24 h (the sun up and the moon down by day,
## the moon up by night, stars only after sunset, the clock text the game's), sits inside the view docked
## to the map and off the HUD's taken rects at each size, and redraws a night of frames without
## allocating and within its time budget. The weather shows in it per state (clear, rain, storm with and
## without a strike, heat, cold), each scaled by the weather's strength, the storm easing in, and with no
## weather to read it draws clear.
## Run: godot --headless --path game --script res://tests/t_daynight_dial.gd -> "[t_daynight] PASS", exit 0/1.

const DIAL_PATH := "res://scripts/ui/day_night_dial.gd"
const PHASES := {0.0: &"night", 0.25: &"dawn", 0.5: &"day", 0.75: &"dusk"}
const SIZES := [Vector2i(1600, 900), Vector2i(844, 390), Vector2i(390, 844)]

var failures: Array[String] = []
var _D: Variant  ## the dial's script, loaded at run time (its autoloads do not exist when this compiles)
var _started := false

## Game, World and the HUD scripts reach autoloads, which exist from the first frame.
func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Game") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run()
	return false

func _run() -> void:
	var game: Node = get_root().get_node("Game")
	game.set_process(false)  # the clock stands still, so any change to it below is someone's write
	var keep: float = game.time_of_day
	if not ResourceLoader.exists(DIAL_PATH):
		_check(false, "%s is missing" % DIAL_PATH)
	else:
		_D = load(DIAL_PATH)
		_test_phases(game, _D)
		await _test_face(game)
		await _test_weather(game)
		await _test_hud(game)
	game.time_of_day = keep
	game.set_process(true)
	if failures.is_empty():
		print("[t_daynight] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_daynight] FAIL %s" % f)
		quit(1)

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)

## The dial's phases are the game's: the four named times, then every 1/200 of a day.
func _test_phases(game: Node, D: GDScript) -> void:
	for t: float in PHASES:
		game.time_of_day = t  # the test sets the clock; the dial only reads it
		_check(D.call("phase_at", t) == PHASES[t], "phase_at(%.2f) is %s, want %s" % [t, D.call("phase_at", t), PHASES[t]])
		_check(game.phase_name() == PHASES[t], "Game.phase_name() at %.2f is %s, want %s" % [t, game.phase_name(), PHASES[t]])
		_check(is_equal_approx((D.call("clock") as Vector2).x, t), "the dial reads time %.2f from Game (got %s)" % [t, D.call("clock")])
	var off := 0
	for i in 200:
		game.time_of_day = float(i) / 200.0
		if D.call("phase_at", game.time_of_day) != game.phase_name():
			off += 1
	_check(off == 0, "phase_at disagrees with Game.phase_name() at %d of 200 times" % off)
	var lines: PackedStringArray = D.call("label_lines", 0.5, 720.0)
	_check(lines == PackedStringArray(["Day  12:00", "Dusk in 3 min"]), "noon on a 720 s day reads %s, want Day  12:00 / Dusk in 3 min" % [lines])
	lines = D.call("label_lines", 0.79, 720.0)
	_check(lines == PackedStringArray(["Dusk  18:57", "Night in 8 s"]), "0.79 reads %s, want Dusk  18:57 / Night in 8 s" % [lines])
	lines = D.call("label_lines", 0.9, 720.0)
	_check(lines == PackedStringArray(["Night  21:36", "Dawn in 4 min"]), "0.9 reads %s, want Night  21:36 / Dawn in 4 min (over midnight)" % [lines])
	_test_countdown(D)
	# Things in colour, the control in white (colour = things, white = actions).
	var sun: Color = D.get_script_constant_map()["SUN"]
	var moon: Color = D.get_script_constant_map()["MOON"]
	_check(sun.r > sun.b + 0.4, "the sun is warm (%s)" % sun)
	_check(moon.b >= moon.r and moon.v > 0.85, "the moon is pale (%s)" % moon)
	print("[t_daynight] phases 0.0/0.25/0.5/0.75 = %s; noon label %s" % [PHASES.values(), D.call("label_lines", 0.5, 720.0)])

## The countdown, every quarter second from 0.25 s to 5 min before dusk on a 720 s day: seconds under
## a minute (1-59, never "60 s", never under the real wait), then whole minutes at most 30 s off
## (ceil read 61 s as "2 min" and 59.5 s as "60 s").
func _test_countdown(D: GDScript) -> void:
	var bad: Array[String] = []
	var dusk: float = D.get_script_constant_map()["STARTS"][2][0]  # not WorldLighting: Game is no autoload yet when this compiles
	for q in range(1, 1201):
		var t: float = dusk - float(q) * 0.25 / 720.0
		var secs: float = (dusk - t) * 720.0
		var wait := str((D.call("label_lines", t, 720.0) as PackedStringArray)[1]).trim_prefix("Dusk in ")
		var n := wait.to_int()
		var ok := (n >= 1 and n <= 59 and n >= secs - 0.001 and n < secs + 1.0) if wait.ends_with(" s") \
			else (wait.ends_with(" min") and secs > 59.0 and absf(n * 60.0 - secs) <= 30.001)
		if not ok and bad.size() < 4:
			bad.append("%.2f s -> %s" % [secs, wait])
	_check(bad.is_empty(), "the countdown misreads the wait: %s" % [bad])

## One face over a day: what it drew where, every 1/96 of a day, then a night of redraws.
func _test_face(game: Node) -> void:
	var v := "dial"
	var dial: Control = _D.new()
	get_root().add_child(dial)
	dial.call("dock", Rect2(1430, 34, 154, 154))
	var face := Rect2(Vector2.ZERO, dial.size)
	var hy: float = dial.get("_hy")
	var bad: Array[String] = []
	var last_sun := -INF
	var start := int(dial.get("draws"))
	for i in 96:
		var t := float(i) / 96.0
		game.time_of_day = t
		dial.call("_process", 0.0)
		dial.queue_redraw()
		await process_frame
		await process_frame  # the draw lands at the end of the first frame
		var sun: Vector2 = (dial.get("drawn_sun") as Vector2)
		var moon: Vector2 = (dial.get("drawn_moon") as Vector2)
		var up: bool = _D.sun_up(t)
		var mp: float = _D.moon_p(t)
		if up and not (face.has_point(sun) and sun.y <= hy):
			bad.append("%.3f: the sun is at %s, want up in the face (horizon %.0f)" % [t, sun, hy])
		if up and not is_nan(moon.x) and moon.y < hy - 1.0:
			bad.append("%.3f: the moon %s is up by day" % [t, moon])
		if mp > 0.0 and mp < 1.0 and not (face.has_point(moon) and moon.y <= hy):
			bad.append("%.3f: the moon is at %s, want up in the face by night" % [t, moon])
		if not up and not is_nan(sun.x) and sun.y < hy - 1.0:
			bad.append("%.3f: the sun %s is up by night" % [t, sun])
		if _D.phase_at(t) == &"day" and int(dial.get("drawn_stars")) > 0:
			bad.append("%.3f: %d stars by day" % [t, int(dial.get("drawn_stars"))])
		if _D.star_alpha(t) > 0.5 and int(dial.get("drawn_stars")) == 0:
			bad.append("%.3f: no stars at night" % t)
		if dial.get("_clock_text") != _D.clock_text(t):
			bad.append("%.3f: the clock reads %s, want %s" % [t, dial.get("_clock_text"), _D.clock_text(t)])
		if up:  # the sun crosses east to west
			if sun.x < last_sun:
				bad.append("%.3f: the sun went back to %.1f from %.1f" % [t, sun.x, last_sun])
			last_sun = sun.x
	_check(int(dial.get("draws")) - start >= 90, "%s: the face drew %d times over 96 steps" % [v, int(dial.get("draws")) - start])
	_check(bad.is_empty(), "%s over a day: %s" % [v, bad.slice(0, 5)])
	# A night of frames: redrawn each frame (the stars twinkle) without allocating.
	game.time_of_day = 0.02
	for i in 10:
		dial.call("_process", 0.016)
		await process_frame
	var objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	var before := int(dial.get("draws"))
	var usec0 := int(dial.get("draw_usec"))
	for i in 120:
		dial.call("_process", 0.016)
		await process_frame
	var grew := Performance.get_monitor(Performance.MEMORY_STATIC) - mem
	var per := float(int(dial.get("draw_usec")) - usec0) / maxf(1.0, float(int(dial.get("draws")) - before))
	# ASSUMPTION: 600 us a draw (headless, GDScript) is the HUD budget for one animated widget.
	_check(per < 600.0, "%s: a night draw takes %.0f us (budget 600)" % [v, per])
	_check(int(dial.get("draws")) - before >= 110, "%s: a night redraws each frame (%d of 120)" % [v, int(dial.get("draws")) - before])
	_check(Performance.get_monitor(Performance.OBJECT_COUNT) == objs, "%s: objects grew over 120 night frames" % v)
	_check(grew <= 4096.0, "%s: static memory grew %d bytes over 120 night frames" % [v, grew])
	print("[t_daynight] %s: face %s, %d draws, +%d B over 120 night frames, %.0f us a draw, stars %d" % [v, face.size, int(dial.get("draws")), grew, per, int(dial.get("drawn_stars"))])
	dial.free()

## Sets the fake weather, lets the dial read it (`settle` seconds of easing) and draw.
func _weather_draw(dial: Control, w: Object, fields: Dictionary, settle := 5.0) -> Dictionary:
	for k in ["rain_amount", "heat", "cold", "frost", "flash"]:
		w.set(k, 0.0)
	w.set("storm", false)
	for k in fields:
		w.set(k, fields[k])
	dial.call("read_weather", settle)
	dial.queue_redraw()
	await process_frame
	await process_frame
	return {"rain": dial.get("drawn_rain"), "bolt": dial.get("drawn_bolt"), "haze": dial.get("drawn_haze"),
		"frost": dial.get("drawn_frost"), "over": dial.get("drawn_overcast"), "storm": dial.get("w_storm")}

func _test_weather(game: Node) -> void:
	var dial: Control = _D.new()
	get_root().add_child(dial)
	dial.call("dock", Rect2(1430, 34, 154, 154))
	game.time_of_day = 0.5
	dial.queue_redraw()
	await process_frame
	await process_frame
	var none := {"rain": dial.get("drawn_rain"), "bolt": dial.get("drawn_bolt"), "haze": dial.get("drawn_haze"), "frost": dial.get("drawn_frost"), "over": dial.get("drawn_overcast")}
	_check(none == {"rain": 0.0, "bolt": false, "haze": 0.0, "frost": 0.0, "over": 0.0}, "with no weather to read the dial draws clear (%s)" % [none])
	if not ResourceLoader.exists("res://scripts/world/world_weather.gd"):
		print("[t_daynight] weather: no WorldWeather in this tree, clear only")
		dial.free()
		return
	var w: Object = load("res://scripts/world/world_weather.gd").new()
	dial.set("weather_source", w)
	var clear := await _weather_draw(dial, w, {})
	_check(clear["rain"] == 0.0 and not clear["bolt"] and clear["haze"] == 0.0 and clear["frost"] == 0.0 and clear["over"] == 0.0, "clear: no rain, bolt, haze, frost or overcast (%s)" % [clear])
	var drizzle := await _weather_draw(dial, w, {"rain_amount": 0.3})
	var rain := await _weather_draw(dial, w, {"rain_amount": 0.7})
	_check(rain["rain"] > 0.0 and rain["over"] > 0.0 and not rain["bolt"] and rain["storm"] == 0.0, "rain: streaks and grey clouds, no storm (%s)" % [rain])
	_check(drizzle["rain"] < rain["rain"] and drizzle["over"] < rain["over"], "rain follows its strength (0.3 %s, 0.7 %s)" % [drizzle, rain])
	var calm := await _weather_draw(dial, w, {"rain_amount": 1.0, "storm": true})
	var strike := await _weather_draw(dial, w, {"rain_amount": 1.0, "storm": true, "flash": 0.8})
	_check(calm["storm"] > 0.9 and calm["over"] > rain["over"] and calm["rain"] > rain["rain"] and not calm["bolt"], "storm: heavier than rain, no bolt between strikes (%s)" % [calm])
	_check(strike["bolt"], "storm: a strike (flash 0.8) draws a bolt (%s)" % [strike])
	var easing := await _weather_draw(dial, w, {"rain_amount": 0.0}, 5.0)
	easing = await _weather_draw(dial, w, {"rain_amount": 1.0, "storm": true}, 0.1)
	_check(easing["storm"] < 0.2, "a storm eases in rather than snapping (%.2f after 0.1 s)" % easing["storm"])
	var heat := await _weather_draw(dial, w, {"heat": 1.0})
	var warm := await _weather_draw(dial, w, {"heat": 0.4})
	_check(heat["haze"] > warm["haze"] and warm["haze"] > 0.0 and heat["frost"] == 0.0 and heat["rain"] == 0.0, "heat: haze scaled by strength, nothing else (%s / %s)" % [warm, heat])
	var cold := await _weather_draw(dial, w, {"cold": 1.0, "frost": 1.0})
	_check(cold["frost"] > 0.9 and cold["haze"] == 0.0 and cold["rain"] == 0.0, "cold: frost on the rim (%s)" % [cold])
	# Cost under the heaviest sky: a storm at night with a strike, every frame.
	game.time_of_day = 0.02
	for k in ["rain_amount", "flash", "frost", "cold"]:
		w.set(k, 1.0)
	w.set("storm", true)
	for i in 10:  # warm up: the canvas item's command buffer grows once to the storm's size
		await process_frame
	var before := int(dial.get("draws"))
	var usec0 := int(dial.get("draw_usec"))
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	for i in 60:
		await process_frame
	var per := float(int(dial.get("draw_usec")) - usec0) / maxf(1.0, float(int(dial.get("draws")) - before))
	_check(int(dial.get("draws")) - before >= 55 and per < 600.0, "storm at night: %d draws, %.0f us a draw (budget 600)" % [int(dial.get("draws")) - before, per])
	var grew := Performance.get_monitor(Performance.MEMORY_STATIC) - mem
	_check(grew <= 4096.0, "storm at night: static memory grew %d bytes over 60 frames" % grew)
	print("[t_daynight] weather: clear %s rain %s storm %s strike %s heat %s cold %s; storm night %.0f us a draw" % [clear, rain, calm, strike, heat, cold, per])
	dial.free()

func _test_hud(game: Node) -> void:
	var hud: Control = load("res://scripts/ui/hunt_hud.gd").new()
	get_root().add_child(hud)
	await process_frame
	var dial := hud.get("_daynight") as Control
	if dial == null or dial.get_parent() != hud:
		_check(false, "HuntHud has no day/night dial (_daynight) beside the minimap")
		hud.free()
		return
	var map := hud.get("_minimap") as Control
	game.time_of_day = 0.4
	hud.call("_layout")
	var start_size := get_root().size
	var start_canvas := get_root().content_scale_size
	for s: Vector2i in SIZES:
		get_root().size = s
		get_root().content_scale_size = s  # the 1:1 canvas DisplayMode gives these windows at boot
		await process_frame
		await process_frame
		var view := get_root().get_visible_rect()
		var closed := dial.get_global_rect()
		var m := map.get_global_rect()
		_check(view.size == Vector2(s), "the canvas is %s for a %s window" % [view.size, s])
		var want := 56.0 if s.x >= 1280 else 48.0  # the judge: 56-64 px on desktop, >= 48 on a phone
		_check(closed.size.x >= want and closed.size.y >= want, "%s: the dial is %s, want >= %d px" % [s, closed.size, want])
		_check(view.encloses(closed), "%s: the dial %s is inside the view" % [s, closed])
		_check(is_equal_approx(closed.end.x, m.position.x - 4.0) and is_equal_approx(closed.end.y, m.end.y),
			"%s: the dial %s is docked to the minimap %s's bottom-left edge (laid out again on resize)" % [s, closed, m])
		_check(not closed.intersects(m), "%s: the dial %s is off the minimap %s" % [s, closed, m])
		var zone_ok := false
		for z: Rect2 in load("res://scripts/ui/ui_tokens.gd").hud_reserved(view.size):
			zone_ok = zone_ok or z.encloses(closed)
		_check(zone_ok, "%s %s: the dial %s is inside a UiTokens.hud_reserved zone" % ["dial", s, closed])
		for tr: Rect2 in load("res://scripts/ui/hud_layout.gd").taken_rects(hud):
			if tr != closed and tr.has_area() and closed.grow(-1.0).intersects(tr):
				_check(false, "%s %s: the dial %s overlaps a taken rect %s" % ["dial", s, closed, tr])
		_push_click(dial)
		await process_frame
		var opened := dial.get_global_rect()
		_check(dial.call("is_open"), "%s: a tap on the dial opens its label" % s)
		_check(opened.size.x > closed.size.x + 60.0 and is_equal_approx(opened.end.x, closed.end.x), "%s: the label opens leftwards (%s from %s)" % [s, opened, closed])
		_check(view.encloses(opened) and not opened.intersects(m), "%s: the open dial %s stays in the view and off the minimap %s" % [s, opened, m])
		_push_click(dial)
		await process_frame
		_check(not dial.call("is_open") and dial.get_global_rect() == closed, "%s: a second tap closes it back to %s (got %s)" % [s, closed, dial.get_global_rect()])
		_push_click(dial, Vector2(-200.0, 120.0))
		await process_frame
		_check(not dial.call("is_open"), "%s: a press on the dial released off it opened the label (BaseButton cancels it)" % s)
		print("[t_daynight] %s %s: map %s dial %s open %s" % ["dial", s, m, closed, opened])
	# The label closes itself, and nothing the dial did moved the clock.
	_push_click(dial)
	await process_frame
	dial.call("_process", 5.0)
	_check(not dial.call("is_open"), "the label closes itself after OPEN_S")
	_check(game.time_of_day == 0.4, "the dial never writes Game.time_of_day (0.4 became %.4f)" % game.time_of_day)
	var src := FileAccess.get_file_as_string(DIAL_PATH)
	_test_draw_source(src)
	var writes := RegEx.create_from_string("(time_of_day|day_length_seconds)\\s*[-+*/]?=(?!=)").search(src)
	_check(writes == null, "day_night_dial.gd assigns the clock: %s" % (writes.get_string() if writes else ""))
	get_root().size = start_size
	get_root().content_scale_size = start_canvas
	hud.free()

## The draw path allocates nothing: no array or dictionary literals, packed-array constructors, copies or
## string building in any _draw* function (memory growth alone would miss a buffer freed each frame).
func _test_draw_source(src: String) -> void:
	var alloc := RegEx.create_from_string("(?<![\\w\\]\\)])\\[|\\{|Packed\\w+Array\\(|\\.duplicate\\(|\\bstr\\(|\\bArray\\(|\"\\s*%|\\+\\s*\"|\\.format\\(")
	var hits: Array[String] = []
	var funcs := 0
	for chunk in src.split("\nfunc "):
		if not chunk.begins_with("_draw"):
			continue
		funcs += 1
		var body := chunk.substr(chunk.find("\n"))
		for line in body.split("\n"):
			var code := line.get_slice("#", 0)
			var m := alloc.search(code)
			if m:
				hits.append("%s: %s" % [chunk.get_slice("(", 0), code.strip_edges().left(60)])
	_check(funcs >= 10, "found %d _draw* functions in the dial" % funcs)
	_check(hits.is_empty(), "the dial's draw allocates: %s" % [hits.slice(0, 4)])

## Left press at the dial's disc and release there, or `off` px away, in window pixels (as t_ui does).
func _push_click(c: Control, off := Vector2.ZERO) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var at: Vector2 = c.get_global_rect().position + Vector2(c.size.x - c.size.y * 0.5, c.size.y * 0.5)  # the disc
	click.position = get_root().get_final_transform() * at
	click.global_position = click.position
	get_root().push_input(click)
	var up := click.duplicate() as InputEventMouseButton
	up.pressed = false
	up.position = get_root().get_final_transform() * (at + off)
	up.global_position = up.position
	get_root().push_input(up)
