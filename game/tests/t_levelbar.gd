extends SceneTree
## LEVELBAR acceptance (owner 2026-10-28): "the level UI in the top left corner is unnecessary because
## your level is shown on the level UI at the bottom of the screen. Add segments to the level UI that
## are proportional to a unit amount of xp and as you level up it should get exponentially harder to
## level up to the next one, the segments reflect that" and "make it green for the xp bar too".
## - the level line sits at the bottom (LEVELBADGE later brought the top-left badge back: t_levelbadge);
## - the bar draws ceil(level cost / unit) segments, at most max_segments, more as levels climb;
## - the curve (pioneer_levels.json xp_curve) is monotonic and exponential; level from total XP
##   matches the table; an old linear save keeps its level as a floor;
## - the bar fills UiTokens.XP_GREEN.
## Usage: godot --headless --path game --script res://tests/t_levelbar.gd -> "[t_levelbar] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _hud
var _world: Node
var TOK: GDScript
var LD: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_levelbar] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_world = root.get_node("World")
	TOK = load("res://scripts/ui/ui_tokens.gd")
	LD = load("res://scripts/ui/level_display.gd")
	_test_curve()
	_test_floor()
	_test_segments_math()
	_host = Node3D.new()
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("quick_row_y"):
			_hud = c
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	var was_size: Vector2i = root.size
	var was_scale: Vector2i = root.content_scale_size
	for size in [Vector2i(844, 390), Vector2i(1600, 900)]:
		root.size = size
		root.content_scale_size = size
		await _test_hud(Vector2(size))
	root.size = was_size
	root.content_scale_size = was_scale
	if _fails.is_empty():
		print("[t_levelbar] PASS")
		quit(0)
	else:
		print("[t_levelbar] FAIL count=%d" % _fails.size())
		quit(1)

func _test_curve() -> void:
	var c: Dictionary = _world.xp_curve()
	var growth := float(c["growth"])
	_expect(growth > 1.0 and int(c["segment_xp"]) > 0 and int(c["max_segments"]) > 0, "xp_curve is in data (%s)" % c)
	var mono := true
	var expo := true
	for n in 80:
		var a: int = _world.xp_for_level(n)
		var b: int = _world.xp_for_level(n + 1)
		mono = mono and b > a
		var want := float(c["base"]) * pow(growth, n) * Progression.mult("player_xp_cost_mult")  # SLOWLEVELS knob
		expo = expo and absf(a - want) <= 0.5 + 0.0001 * want
		if n >= 5:  # rounding blurs the first few ratios
			expo = expo and absf(float(b) / a - growth) < 0.01
	_expect(mono, "every level costs more than the one before (Lv 1-81)")
	_expect(expo, "level n costs round(base x growth^n x player_xp_cost_mult), ratio within 1 %% of %.2f" % growth)
	_expect(_world.xp_for_level(29) > 3 * _world.xp_for_level(9), "Lv 30 costs over 3x Lv 10 (%d vs %d)" % [_world.xp_for_level(29), _world.xp_for_level(9)])
	# level from total XP matches the table
	var total := 0
	var ok := true
	for n in 40:
		ok = ok and _world.level_from_total(total) == Vector2i(n, 0)
		ok = ok and _world.level_from_total(total + 7) == Vector2i(n, 7)
		total += _world.xp_for_level(n)
	_expect(ok, "level_from_total matches the cumulative table for Lv 1-40")

## Old saves: the same total, the level recomputed; never below the stored level.
func _test_floor() -> void:
	# Lv 4 on the old curve with 50 XP: 100 + 125 + 150 + 50 = 425 -> on the x2.5 curve (275 + 308 + 345)
	# that is only Lv 2, so the stored Lv 4 stays as a floor with its 50 XP.
	var low: Vector2i = _world.migrate_linear_xp(3, 50)
	_expect(low == Vector2i(3, 50), "a Lv 4 old save keeps Lv 4 as a floor with its 50 XP (got %s)" % low)
	var gain: Vector2i = _world.migrate_linear_xp(9, 300)  # old total 2100 < new Lv 10 total 4064 (SLOWLEVELS x2.5)
	_expect(gain == Vector2i(9, 300), "a Lv 10 old save keeps Lv 10 as a floor (got %s)" % gain)
	# Recompute upward still works for a total past the curve: Lv 1 + 400 XP over a 275 cost.
	var up: Vector2i = _world.level_from_total(_world.xp_for_level(0) + 7)
	_expect(up == Vector2i(1, 7), "a total past Lv 1's cost recomputes to Lv 2 (got %s)" % up)
	var high: Vector2i = _world.migrate_linear_xp(29, 700)  # old total 13050 + 700 < new Lv 30 total
	_expect(high.x == 29 and high.y == 700, "a Lv 30 old save keeps Lv 30 as a floor (got %s)" % high)
	var near: Vector2i = _world.migrate_linear_xp(29, 5000)  # leftover clamped under the level's cost
	_expect(near.x >= 29 and near.y < _world.xp_for_level(near.x), "the floor never leaves a full bar (got %s)" % near)

func _test_segments_math() -> void:
	var c: Dictionary = _world.xp_curve()
	var unit := int(c["segment_xp"])
	var cap := int(c["max_segments"])
	var last := 0
	var ok := true
	for n in 80:
		var cost: int = _world.xp_for_level(n)
		var s: Vector2i = LD.xp_segments(cost)
		var raw := ceili(float(cost) / unit)
		ok = ok and s.x <= cap and s.x == ceili(float(cost) / s.y) and s.y % unit == 0
		ok = ok and (s.x == raw if raw <= cap else s.y > unit)
		ok = ok and (s.x >= last or raw > cap)
		last = s.x
	_expect(ok, "segments = ceil(cost / unit), unit a multiple of %d XP, at most %d, growing with level" % [unit, cap])
	var lv2: Vector2i = LD.xp_segments(_world.xp_for_level(1))
	var lv30: Vector2i = LD.xp_segments(_world.xp_for_level(29))
	_expect(lv30.x > lv2.x * 5, "Lv 30 draws far more segments than Lv 2 (%d vs %d)" % [lv30.x, lv2.x])

func _test_hud(view: Vector2) -> void:
	var tag := "%dx%d" % [view.x, view.y]
	for shown in [2, 10, 30]:
		_world.pioneer_level = shown - 1
		_world.pioneer_xp = 0
		_hud.queue_redraw()
		await _frames(3)
		var cost: int = _world.xp_for_level(shown - 1)
		var want: Vector2i = LD.xp_segments(cost)
		_expect(_hud.xp_bar_segments == want.x, "%s Lv %d: the bar draws %d segments of %d XP (got %d)" % [tag, shown, want.x, want.y, _hud.xp_bar_segments])
		var bar: Rect2 = _hud.xp_bar_rect
		_expect(bar.end.y >= view.y - 0.5 and bar.size.x >= view.x - 0.5, "%s the bar runs along the bottom (%s)" % [tag, bar])
		var lvl: Rect2 = _hud.drawn_blocks.get("level", Rect2())
		_expect(lvl.has_area() and lvl.position.y > view.y * 0.5, "%s the level line is at the bottom (%s)" % [tag, lvl])
	var vit: Rect2 = _hud.drawn_blocks.get("vitals", Rect2())
	# Owner: the freed circle's room goes to health, energy, hunger and exhaustion.
	var hp: Rect2 = _hud.hp_bar_rect
	var ring: Rect2 = _hud.stomach_rect
	var tread: Rect2 = _hud.get("_fatigue_rect")
	var phone: bool = TOK.is_phone(view)
	var old_bar_w := (232.0 if not phone else maxf(88.0, vit.size.x - 54.0)) - ((16.0 if not phone else 12.0) * 2.0 + 6.0) - 6.0
	# LEVELBADGE: the badge took room back; on a compact canvas the bars give some of it (still wider than pre-LEVELBAR).
	_expect(hp.size.x >= old_bar_w + (5.0 if TOK.is_compact(view) else 40.0), "%s the HP/energy bars are wider than before (%.0f vs %.0f)" % [tag, hp.size.x, old_bar_w])
	# LEVELBADGE (owner 2026-10-28) brought the badge back: the bars and the treadmill start right after its column.
	var col: float = load("res://scripts/ui/hud_level_badge.gd").COLUMN
	_expect(hp.position.x - vit.position.x <= 10.0 + col and tread.position.x - vit.position.x <= 10.0 + col, "%s bars and treadmill start after the badge column (bars at %.0f, treadmill at %.0f, panel at %.0f)" % [tag, hp.position.x, tread.position.x, vit.position.x])
	# LEVELBADGE (owner 2026-10-28): the stomach ring moved down to lead the buff row; bars and treadmill share the width.
	_expect(not ring.intersects(hp) and ring.position.y >= vit.end.y, "%s the stomach ring sits under the vitals (%s / %s)" % [tag, ring, hp])
	_expect(vit.encloses(hp) and vit.encloses(Rect2(tread.position, Vector2(tread.size.x, 1.0))), "%s bars and treadmill stay in the vitals panel (%s)" % [tag, vit])
	_expect(absf(tread.end.x - hp.end.x) <= 12.0, "%s the treadmill spans the bars' width (ends %.0f vs %.0f)" % [tag, tread.end.x, hp.end.x])
	for k in _hud.drawn_blocks:
		var other: Rect2 = _hud.drawn_blocks[k]
		if str(k) != "vitals" and other.has_area():
			_expect(not other.intersects(Rect2(hp.position, Vector2(hp.size.x, hp.size.y * 2.0 + 6.0))), "%s %s keeps off the vitals group" % [tag, k])
	# LEVELBADGE reversed "no top-left level": t_levelbadge checks the badge; the bottom line still shows the level.
	var src := FileAccess.get_file_as_string("res://scripts/ui/hunt_hud.gd")
	_expect(TOK.XP_GREEN.h > 0.25 and TOK.XP_GREEN.h < 0.45 and TOK.XP_GREEN.s > 0.4, "%s the bar fills XP_GREEN (green, owner exception)" % tag)
	_expect(src.contains("UiTokens.XP_GREEN"), "%s the bar's fill is UiTokens.XP_GREEN" % tag)
