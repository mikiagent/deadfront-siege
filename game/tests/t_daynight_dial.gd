extends SceneTree
## HUD-DAYNIGHT checks (spec 16): the HUD has a day/night dial docked to the minimap's bottom-left
## edge (this fails on a HUD without one), its phase at time of day 0.0/0.25/0.5/0.75 is
## night/dawn/day/dusk as Game.phase_name() says, a tap opens a label with the phase, the clock and the
## time to the next phase (rounded minutes, never "60 s"), a release off the dial cancels the tap, it
## lays out again on a resize without touching the minimap, and it never writes the game's clock.
## Run: godot --headless --path game --script res://tests/t_daynight_dial.gd -> "[t_daynight] PASS", exit 0/1.

const DIAL_PATH := "res://scripts/ui/day_night_dial.gd"
const PHASES := {0.0: &"night", 0.25: &"dawn", 0.5: &"day", 0.75: &"dusk"}
const SIZES := [Vector2i(1600, 900), Vector2i(844, 390), Vector2i(390, 844)]

var failures: Array[String] = []
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
		_test_phases(game, load(DIAL_PATH))
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
		print("[t_daynight] %s: map %s dial %s open %s" % [s, m, closed, opened])
	# The label closes itself, and nothing the dial did moved the clock.
	_push_click(dial)
	await process_frame
	dial.call("_process", 5.0)
	_check(not dial.call("is_open"), "the label closes itself after OPEN_S")
	_check(game.time_of_day == 0.4, "the dial never writes Game.time_of_day (0.4 became %.4f)" % game.time_of_day)
	var src := FileAccess.get_file_as_string(DIAL_PATH)
	var writes := RegEx.create_from_string("(time_of_day|day_length_seconds)\\s*[-+*/]?=(?!=)").search(src)
	_check(writes == null, "day_night_dial.gd assigns the clock: %s" % (writes.get_string() if writes else ""))
	get_root().size = start_size
	get_root().content_scale_size = start_canvas
	hud.free()

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
