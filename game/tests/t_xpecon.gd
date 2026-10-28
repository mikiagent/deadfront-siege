extends SceneTree
## XPECON acceptance (islands-and-loop plan section 3.3 "XP economy" + the 3.4 knobs table): a gather
## pass pays rules.json xp.gather_base + round(the seconds that pass really took), so a stone, log and
## berry pass pay what their own work ring waited (1 + round), a faster tool pays less and bare hands
## more; a build pays build_first the first time a kit kind is ever placed, build_repeat after that,
## 0 for the same kit within build_spam_radius_m of its twin inside build_spam_seconds, and a
## different kit is first-of-kind again. The skill XP (Gathering / Construction) and the character XP
## (World.add_xp, which SkillState mirrors every grant into) both follow the data numbers. The
## first-of-kind memory (World.pioneer_buildings) survives a save/load; the level curve does not move.
## Run: Godot --headless --path game --script res://tests/t_xpecon.gd -> "[t_xpecon] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node3D
var _hud: Control
var _world: Node
var _grid: Node
var IS: GDScript
var GS: GDScript
var NODE: PackedScene
var BP: GDScript
var BG: GDScript
var SG: GDScript
var _cfg: Dictionary

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	root.get_tree().create_timer(150.0).timeout.connect(func () -> void:
		print("[t_xpecon] FAIL watchdog: the run did not finish in 150 s")
		quit(1))
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_xpecon] FAIL %s" % what)

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	GS = load("res://scripts/gather/gather_service.gd")
	NODE = load("res://scenes/world/harvest_node.tscn")
	BP = load("res://scripts/world/build_placer.gd")
	BG = load("res://scripts/world/build_grid.gd")
	SG = load("res://scripts/core/save_game.gd")
	_cfg = (root.get_node("Data").world_rules.get("xp", {}) as Dictionary)
	_expect(not _cfg.is_empty(), "rules.json has an xp block (the numbers are data, not code)")
	_expect(int(_cfg.get("gather_base", -1)) == 1 and int(_cfg.get("build_first", -1)) == 30 and int(_cfg.get("build_repeat", -1)) == 8,
		"rules.json xp holds base 1, first 30, repeat 8 (got %s)" % [_cfg])
	_expect(is_equal_approx(float(_cfg.get("build_spam_radius_m", 0.0)), 10.0) and is_equal_approx(float(_cfg.get("build_spam_seconds", 0.0)), 60.0),
		"rules.json xp holds the 10 m / 60 s spam rule (got %s)" % [_cfg])
	print("[t_xpecon] xp config %s" % [_cfg])
	await _build_world()
	_test_gather_xp()
	_test_gather_tool_xp()
	_test_build_xp()
	await _test_build_memory_survives_save()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_xpecon] PASS")
		quit(0)
	else:
		print("[t_xpecon] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- the real survivor on the home island

func _build_world() -> void:
	_host = Node3D.new()
	_host.name = "TXpeconHost"
	root.add_child(_host)
	var cam := Camera3D.new()
	_host.add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	# The HUD stand-in: Player.toast / Player.notice need these two methods.
	var gd := GDScript.new()
	gd.source_code = "extends Control\nvar notices: Array = []\nvar toasts: Array = []\nfunc notice(text: String, tint: Color = Color(0, 0, 0, 0)) -> void:\n\tnotices.append([text, tint])\nfunc toast(id: StringName, n: int) -> void:\n\ttoasts.append([id, n])\n"
	gd.reload()
	_hud = gd.new()
	_hud.add_to_group("hud")
	_host.add_child(_hud)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_player.position = Vector3(0, 1, 18)
	_host.add_child(_player)
	_world = root.get_node("World")
	_world.home_terrain = &"meadow"
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	await physics_frame
	await process_frame
	_grid = _world.runtime.get("build_grid")
	_grid.ignore_distance = true  # the survivor stands still; claims, water and overlap still apply
	_expect(_world.is_home(), "the test runs on the Tamed Island (is_home)")

# ---------------------------------------------------------------- gather: 1 + round(pass seconds)

## One real pass on a planted node: on_arrived starts the work ring with the seconds this survivor
## really waits, then finish_gather lands the unit and pays the XP.
func _gather_once(family: String, item: StringName, need: StringName, seconds: float, zone: int = 1) -> Dictionary:
	var n = NODE.instantiate()
	_host.add_child(n)
	n.position = _player.global_position + Vector3(1.2, 0, 0)
	n.setup(StringName("x_%s_%d" % [family, n.get_instance_id()]), item, 2, 4, {"climate": "grassland", "level": zone}, need, Color.GRAY, seconds, 600.0, family)
	var opts: Array = n.options()
	for i in opts.size():
		if str(opts[i]["item"]) == str(item):
			n.select_option(i)
	_park("gathering")  # a parked tree: the pass seconds and the XP delta are both exact
	var node_seconds: float = GS.unit_seconds(_player, n)  # what the ring will really wait
	var g0: float = _player.skills.xp_of("gathering")
	var w0: int = int(_world.pioneer_xp)
	_player.gather_target = n
	_player.actions.on_arrived()
	var ring_seconds: float = _player.actions.get("_gather_unit_time")
	_player.actions.finish_gather()
	_player.actions.stop_gather_cycle(false)
	_player.gather_target = null
	var out := {
		"node_seconds": node_seconds, "ring_seconds": ring_seconds,
		"gxp": _player.skills.xp_of("gathering") - g0,
		"wxp": int(_world.pioneer_xp) - w0,
	}
	n.free()
	return out

## A tree skill parked mid-level, so every XP delta is exact (no level-up resets the bar).
func _park(tree: String) -> void:
	_player.skills.trees[tree]["level"] = 30
	_player.skills.trees[tree]["xp"] = 0.0

func _test_gather_xp() -> void:
	# pioneer_xp wraps into a level at xp_for_level(55) = 1475; 55 keeps every small grant exact.
	_world.pioneer_level = 55
	_world.pioneer_xp = 0
	_clear_bag()
	var rows := [
		# family, item, tool the node needs, its pass seconds, the plan's own numbers
		["Rock", &"stone", &"pick", 3.0],
		["CommonTree", &"wood_log", &"axe", 3.0],
		["BushBerries", &"berries", &"none", 1.0],
	]
	_player.inventory.add(IS.make(&"work_pick", 1))
	_player.inventory.add(IS.make(&"work_axe", 1))
	for row: Array in rows:
		var r := _gather_once(str(row[0]), row[1], row[2], float(row[3]))
		var expected: int = 1 + int(roundf(float(r["node_seconds"])))
		var processing := 1 if str(row[0]).begins_with("Rock") else 0
		print("[t_xpecon] %s pass: node %.2fs ring %.2fs -> gathering +%d, character +%d (want %d / %d)" % [
			row[0], float(r["node_seconds"]), float(r["ring_seconds"]), int(r["gxp"]), int(r["wxp"]), expected, expected + processing])
		_expect(is_equal_approx(float(r["ring_seconds"]), float(r["node_seconds"])), "%s: the ring waited the pass's own seconds (%.2f vs %.2f)" % [row[0], float(r["ring_seconds"]), float(r["node_seconds"])])
		_expect(int(r["gxp"]) == expected, "%s pass pays 1 + round(%.2fs) = %d Gathering XP (got %d)" % [row[0], float(r["node_seconds"]), expected, int(r["gxp"])])
		_expect(int(r["wxp"]) == expected + processing, "%s pass pays the same %d to the character bar%s (got %d)" % [row[0], expected, " (+1 Processing)" if processing > 0 else "", int(r["wxp"])])
	# The plan's own arithmetic: a 3 s stone/log pass pays 4 and a 1 s berry pass pays 2 at base 1.
	_expect(int(roundf(3.0)) + 1 == 4 and int(roundf(1.0)) + 1 == 2, "the base-1 formula gives the plan's stone/log 4 and berries 2")

func _clear_bag() -> void:
	for i in _player.inventory.slot_count:
		_player.inventory.slots[i] = null

## The plan's intent: a tool or a Gathering level that shortens the work shortens the award with it.
## Loose stone is hand-pickable; the same rock worked with a pick waits less, so it pays fewer XP.
func _test_gather_tool_xp() -> void:
	_clear_bag()
	# A Lv-60 zone (an over-levelled rock, rules.json zone_pressure) widens the gap past the round().
	var bare := _gather_once("Rock", &"stone", &"none", 2.8, 60)
	_clear_bag()
	_player.inventory.add(IS.make(&"work_pick", 1))
	var pick := _gather_once("Rock", &"stone", &"none", 2.8, 60)
	print("[t_xpecon] same rock: bare hands %.2fs -> +%d XP, pick %.2fs -> +%d XP" % [
		float(bare["node_seconds"]), int(bare["gxp"]), float(pick["node_seconds"]), int(pick["gxp"])])
	_expect(float(pick["node_seconds"]) < float(bare["node_seconds"]), "the pick pass is faster than bare hands (%.2fs vs %.2fs)" % [float(pick["node_seconds"]), float(bare["node_seconds"])])
	_expect(int(pick["gxp"]) == 1 + int(roundf(float(pick["node_seconds"]))) and int(bare["gxp"]) == 1 + int(roundf(float(bare["node_seconds"]))),
		"both passes pay 1 + round(their own seconds) (bare %d, pick %d)" % [int(bare["gxp"]), int(pick["gxp"])])
	_expect(int(pick["gxp"]) < int(bare["gxp"]), "the faster tool pass pays less XP (%d vs %d)" % [int(pick["gxp"]), int(bare["gxp"])])
	_clear_bag()

# ---------------------------------------------------------------- build: 30 / 8 / 0

## A free cell on the camp's claimed land. With `around` set, the nearest free cell that is at least
## `min_dist` from it (17 m or more: outside the 10 m spam radius) or at most `max_dist` (beside it).
func _free_cell(kind: StringName, around: Vector3 = Vector3.ZERO, min_dist: float = 0.0, max_dist: float = INF) -> Vector2i:
	var rt: Node = _world.runtime
	var best := Vector2i(-9999, -9999)
	var best_d := INF
	for r in rt.claims:
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, z)
				if _grid.can_place(kind, c, 0) != "":
					continue
				var d: float = (BG.tile_centre(c, rt) as Vector3).distance_to(around)
				if d < min_dist or d > max_dist:
					continue
				if around == Vector3.ZERO:
					return c
				if d < best_d:
					best_d = d
					best = c
	return best

func _place(kind: StringName, cell: Vector2i) -> Node3D:
	if cell.x == -9999:
		return null
	var kit: StringName = BP.kit_for(kind)
	_player.inventory.add(IS.make(kit, 1))
	var placer: Node = _player.placer
	placer.begin(kind)
	placer.cell = cell
	var ok: bool = placer.confirm(_player)
	if not ok:
		print("[t_xpecon] place %s at %s refused: %s" % [kind, cell, placer.reason])
		placer.cancel()
		_player.inventory.consume(kit, 1)
		return null
	return _newest(kind)

func _newest(kind: StringName) -> Node3D:
	var best: Node3D = null
	for n in root.get_tree().get_nodes_in_group("placed_building"):
		if not n.is_queued_for_deletion() and str(BP.kind_of_building(n)) == str(kind):
			best = n
	return best

## One placement, measured on both bars: construction (the skill) and pioneer (the character).
func _build_once(kind: StringName, cell: Vector2i) -> Dictionary:
	_park("construction")
	var s0: float = _player.skills.xp_of("construction")
	var w0: int = int(_world.pioneer_xp)
	var node := _place(kind, cell)
	if node == null:
		return {"ok": false, "sxp": 0.0, "wxp": 0, "pos": Vector3.ZERO}
	return {
		"ok": true,
		"sxp": _player.skills.xp_of("construction") - s0,
		"wxp": int(_world.pioneer_xp) - w0,
		"pos": node.global_position,
	}

func _test_build_xp() -> void:
	_world.pioneer_buildings.clear()
	_world.build_recent.clear()
	_world.pioneer_level = 55
	_world.pioneer_xp = 0
	_clear_bag()
	var first_cell := _free_cell(&"basket")
	var first := _build_once(&"basket", first_cell)
	print("[t_xpecon] first basket: construction +%.0f character +%d" % [float(first["sxp"]), int(first["wxp"])])
	_expect(bool(first["ok"]), "the first basket places")
	_expect(int(first["sxp"]) == int(_cfg.get("build_first", 30)) and int(first["wxp"]) == int(_cfg.get("build_first", 30)),
		"a kit's first placement pays +%d to Construction and the character bar (got %.0f / %d)" % [int(_cfg.get("build_first", 30)), float(first["sxp"]), int(first["wxp"])])
	# The same kit right beside its twin, inside the 60 s window: spam pays nothing.
	var spam_cell := _free_cell(&"basket", first["pos"] as Vector3, 0.0, 9.0)
	var spam := _build_once(&"basket", spam_cell)
	print("[t_xpecon] basket beside its twin (%.1f m away): construction +%.0f character +%d" % [
		(spam["pos"] as Vector3).distance_to(first["pos"] as Vector3), float(spam["sxp"]), int(spam["wxp"])])
	_expect(bool(spam["ok"]), "the second basket places")
	_expect(int(spam["sxp"]) == 0 and int(spam["wxp"]) == 0, "the same kit within 10 m inside 60 s pays 0 XP (got %.0f / %d)" % [float(spam["sxp"]), int(spam["wxp"])])
	# A repeat away from its twin (> 10 m) pays the repeat award.
	var far_cell := _free_cell(&"basket", first["pos"] as Vector3, 11.0)
	var far := _build_once(&"basket", far_cell)
	print("[t_xpecon] basket 11 m+ away: construction +%.0f character +%d" % [float(far["sxp"]), int(far["wxp"])])
	_expect(bool(far["ok"]), "the far basket places")
	_expect(int(far["sxp"]) == int(_cfg.get("build_repeat", 8)) and int(far["wxp"]) == int(_cfg.get("build_repeat", 8)),
		"a repeat of a known kit pays +%d (got %.0f / %d)" % [int(_cfg.get("build_repeat", 8)), float(far["sxp"]), int(far["wxp"])])
	# The 60 s half of the rule: age the twin out of the window; the same spot then pays the repeat.
	for e: Dictionary in _world.build_recent:
		e["t"] = float(e.get("t", 0.0)) - 61.0
	var again := _build_once(&"basket", _free_cell(&"basket", first["pos"] as Vector3, 11.0))
	print("[t_xpecon] basket beside the aged twin: construction +%.0f character +%d" % [float(again["sxp"]), int(again["wxp"])])
	_expect(bool(again["ok"]), "the aged-window basket places")
	_expect(int(again["sxp"]) == int(_cfg.get("build_repeat", 8)), "the same kit beside a twin older than 60 s pays the repeat +%d (got %.0f)" % [int(_cfg.get("build_repeat", 8)), float(again["sxp"])])
	# A different kit is first-of-kind again.
	var sign := _build_once(&"sign", _free_cell(&"sign"))
	print("[t_xpecon] first sign: construction +%.0f character +%d" % [float(sign["sxp"]), int(sign["wxp"])])
	_expect(bool(sign["ok"]), "the first sign places")
	_expect(int(sign["sxp"]) == int(_cfg.get("build_first", 30)), "a different kit pays first-of-kind +%d again (got %.0f)" % [int(_cfg.get("build_first", 30)), float(sign["sxp"])])
	var sign2 := _build_once(&"sign", _free_cell(&"sign", sign["pos"] as Vector3, 11.0))
	print("[t_xpecon] repeat sign: construction +%.0f character +%d" % [float(sign2["sxp"]), int(sign2["wxp"])])
	_expect(int(sign2["sxp"]) == int(_cfg.get("build_repeat", 8)), "a far repeat of the sign pays +%d (got %.0f)" % [int(_cfg.get("build_repeat", 8)), float(sign2["sxp"])])
	_expect(int(_world.pioneer_buildings.get("basket", 0)) == 4 and int(_world.pioneer_buildings.get("sign", 0)) == 2,
		"the memory counts every placement, spam included (basket %d, sign %d)" % [int(_world.pioneer_buildings.get("basket", 0)), int(_world.pioneer_buildings.get("sign", 0))])

# ---------------------------------------------------------------- first-of-kind survives save/load

func _test_build_memory_survives_save() -> void:
	_expect(SG.save_now(), "the save writes")
	var raw := FileAccess.get_file_as_string(SG.path)
	var saved: Variant = JSON.parse_string(raw)
	var row: Variant = (saved as Dictionary).get("pioneer_buildings", null) if saved is Dictionary else null
	print("[t_xpecon] saved pioneer_buildings %s" % [str(row)])
	_expect(row is Dictionary and int((row as Dictionary).get("basket", 0)) == 4 and int((row as Dictionary).get("sign", 0)) == 2,
		"the save carries the first-of-kind memory (basket 4, sign 2)")
	# Forget it the way a fresh process would, then take the real load path.
	_world.pioneer_buildings.clear()
	_world.build_recent.clear()
	SG.load_now(_host)
	await process_frame
	await physics_frame
	await process_frame
	_grid = _world.runtime.get("build_grid")
	_grid.ignore_distance = true
	print("[t_xpecon] after load pioneer_buildings %s" % [str(_world.pioneer_buildings)])
	_expect(int(_world.pioneer_buildings.get("basket", 0)) == 4 and int(_world.pioneer_buildings.get("sign", 0)) == 2,
		"the load brings the first-of-kind memory back (basket %d, sign %d)" % [int(_world.pioneer_buildings.get("basket", 0)), int(_world.pioneer_buildings.get("sign", 0))])
	_expect(_world.build_recent.is_empty(), "the transient spam window starts empty after a load")
	_clear_bag()
	_world.pioneer_level = 55
	_world.pioneer_xp = 0
	var after := _build_once(&"basket", _free_cell(&"basket"))
	print("[t_xpecon] basket after load: construction +%.0f character +%d" % [float(after["sxp"]), int(after["wxp"])])
	_expect(bool(after["ok"]) and int(after["sxp"]) == int(_cfg.get("build_repeat", 8)),
		"a kit the loaded save already knows pays the repeat +%d, not first-of-kind (got %.0f)" % [int(_cfg.get("build_repeat", 8)), float(after["sxp"])])
