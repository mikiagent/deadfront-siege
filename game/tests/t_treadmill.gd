extends SceneTree
## TREADMILL look (owner 2026-10-28 "improve the artistry of the treadmill", same size and shape): the belt
## keeps its rect at 844x390 and 1600x900, tier colours blend from TOK.MOOD, a worse tier pulses,
## Well Rested frosts it, the marker is a tall needle, and drawing it allocates nothing per frame (net static memory and object count
## flat over 600 draws) at a measured cost.
## Usage: godot --headless --path game --script res://tests/t_treadmill.gd -> "[t_treadmill] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _hud
var _player
var ET: GDScript
var TOK: GDScript

func _process(_delta: float) -> bool:
	if _started or root == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_treadmill] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	ET = load("res://scripts/ui/exhaust_treadmill.gd")
	TOK = load("res://scripts/ui/ui_tokens.gd")
	await _test_cost()  # before the island and player exist, so nothing else moves memory
	var host := Node3D.new()
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 20.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("hands_spot"):
			_hud = c
	await _frames(5)
	_test_colours()
	_test_state()
	for size in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = size
		root.content_scale_size = size
		await _test_rect(Vector2(size))
	if _fails.is_empty():
		print("[t_treadmill] PASS")
		quit(0)
	else:
		print("[t_treadmill] FAIL count=%d" % _fails.size())
		quit(1)

func _test_colours() -> void:
	_expect(ET.tier_of(0.1) == 0 and ET.tier_of(0.25) == 1 and ET.tier_of(0.6) == 2 and ET.tier_of(1.0) == 3,
		"tiers follow the face's 25 / 50 / 75 % words")
	for i in 4:
		_expect(ET.tier_color(0.125 + 0.25 * i).is_equal_approx(TOK.MOOD[i]), "tier %d's middle is its pure MOOD colour" % i)
	var mid: Color = ET.tier_color(0.25)
	_expect(mid.is_equal_approx((TOK.MOOD[0] as Color).lerp(TOK.MOOD[1], 0.5)), "colours blend across a tier border")

func _test_state() -> void:
	ET.tick(0.1, 0.2, false)
	ET.tick(0.1, 0.3, false)
	_expect(ET._pulse > 0.0, "crossing into a worse tier pulses")
	ET.tick(1.0, 0.3, false)
	ET.tick(0.1, 0.1, false)
	_expect(is_zero_approx(ET._pulse), "easing into a better tier does not pulse")
	for i in 20:
		ET.tick(0.05, 0.1, true)
	_expect(is_equal_approx(ET._frost, 1.0), "Well Rested frosts the belt over")
	for i in 20:
		ET.tick(0.05, 0.1, false)
	_expect(is_zero_approx(ET._frost), "the frost thaws when Well Rested ends")

func _test_rect(view: Vector2) -> void:
	await _frames(4)
	var tag := "%dx%d" % [view.x, view.y]
	var phone: bool = TOK.is_phone(view)
	var vit: Rect2 = _hud.drawn_blocks["vitals"]
	# LEVELBAR (owner 2026-10-28): the level disc left of the bars is gone and the row took its 44 px.
	var full_w: float = vit.size.x - HudLevelBadge.COLUMN - 24.0 if TOK.is_compact(view) or phone else 276.0  # LEVELBADGE
	var b: Rect2 = ET.last_rect
	_expect(b.size.is_equal_approx(Vector2(full_w, ET.BELT_H)), "%s the belt keeps its size %s (got %s)" % [tag, Vector2(full_w, ET.BELT_H), b.size])
	var m: Rect2 = ET.marker_rect
	_expect(m.size.y > m.size.x and m.size.y > b.size.y and absf(m.get_center().y - b.get_center().y) < 0.01 and m.position.x >= b.position.x and m.end.x <= b.end.x,
		"%s the strain marker is a tall bar across the belt (%s on %s)" % [tag, m, b])
	# LEVELBADGE (owner 2026-10-28): the level badge is back left of the bars; the belt starts after its column.
	_expect(is_equal_approx(b.position.x, vit.position.x + 8.0 + HudLevelBadge.COLUMN) and vit.encloses(b), "%s the belt keeps its place inside the vitals block (%s in %s)" % [tag, b, vit])

## The belt drawn 50 times a frame on a bare Control, before the world loads. 600 frames with the belt
## off, then 600 with it on: the difference in net static memory and object count is what the belt costs
## to keep (the engine and autoloads move both on their own), and the per-draw script time is printed.
func _test_cost() -> void:
	var src := GDScript.new()
	src.source_code = "extends Control\nvar on := true\nvar n := 0\nvar usec := 0\nvar font: Font\nfunc _draw() -> void:\n\tif not on:\n\t\treturn\n\tvar t := Time.get_ticks_usec()\n\tfor i in 50:\n\t\tExhaustTreadmill.draw_belt(self, Rect2(10, 10, 232, 16), 0.4 if n % 200 < 100 else -0.4, float(n), fposmod(n * 0.003, 1.0), Color.ORANGE, font, 12)\n\tusec += Time.get_ticks_usec() - t\n\tn += 1\nfunc _process(_d: float) -> void:\n\tExhaustTreadmill.tick(1.0 / 60.0, fposmod(n * 0.003, 1.0), n % 300 > 250)\n\tqueue_redraw()\n"
	src.reload()
	var c := Control.new()
	c.set_script(src)
	c.set("font", TOK.ui_font())
	root.add_child(c)
	await _frames(700)  # warm-up past every percent label and the canvas command pool's high-water mark
	c.set("on", false)
	var off := await _delta(600)
	c.set("on", true)
	var u0: int = c.get("usec")
	var n0: int = c.get("n")
	var on := await _delta(600)
	var draws: int = (int(c.get("n")) - n0) * 50
	var per := float(int(c.get("usec")) - u0) / maxf(1.0, float(draws))
	var dmem := on.x - off.x
	var dobj := on.y - off.y
	print("[t_treadmill] cost %.1f us per belt draw over %d draws; 600 frames off: mem %+d B obj %+d, on: mem %+d B obj %+d" % [per, draws, int(off.x), int(off.y), int(on.x), int(on.y)])
	_expect(draws >= 20000, "the belt drew %d times" % draws)
	_expect(absf(dobj) <= 2.0, "drawing the belt creates no objects (%+d vs idle)" % int(dobj))
	# Net heap change, not a malloc counter: a buffer that grew or leaked 8 B a draw would show as 240 KB.
	_expect(absf(dmem) < 32768.0, "drawing the belt keeps nothing per frame (static mem %+d B vs idle over %d draws)" % [int(dmem), draws])
	_expect(per < 200.0, "one belt draw costs %.1f us of script time" % per)
	c.queue_free()

func _delta(frames: int) -> Vector2:
	var m := Performance.get_monitor(Performance.MEMORY_STATIC)
	var o := Performance.get_monitor(Performance.OBJECT_COUNT)
	await _frames(frames)
	return Vector2(Performance.get_monitor(Performance.MEMORY_STATIC) - m, Performance.get_monitor(Performance.OBJECT_COUNT) - o)
