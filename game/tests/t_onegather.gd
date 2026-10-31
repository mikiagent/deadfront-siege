extends SceneTree
## ONEGATHER (owner 2026-10-28: "cap it to 1 per harvest and upgrades can change the speed and quality
## of the materials you harvest, not the amount"). On a real survivor through PlayerActions.finish_gather
## and on the server's act.gather: every pass lands exactly one instance at every tool tier and Gathering
## level; a better tool is faster per unit and rolls better rare-trait odds, never more units; a node
## still takes as many passes as its pool holds; the green rare trait keeps its per-unit rate (5% bare,
## the tier step on top); the top-middle feed shows "+1" per pass and collapses repeats.

var failures: Array[String] = []
var _done := false
var _finished := 0
const GROUPS := 5
const TIERS := ["hands", "stone", "bone", "flint", "obsidian", "copper", "bronze", "iron", "steel"]
const SKILLS := [1, 30, 60]
## [family, item, tool id that helps on it]
const NODES := [["Rock", &"stone", &"work_pick"], ["CommonTree", &"branch", &"work_axe"], ["Bush", &"fibre_stalk", &"stone_knife_work"]]
var IS: GDScript
var INV: GDScript
var GS: GDScript
var LR: GDScript
var LT: GDScript
var NODE: PackedScene
var host: Node3D
var player
var hud

func _process(_delta: float) -> bool:
	if _done:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	GS = load("res://scripts/gather/gather_service.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	LT = load("res://scripts/gather/loot_tables.gd")
	NODE = load("res://scenes/world/harvest_node.tscn")
	_run.call_deferred()
	return false

func _run() -> void:
	await _build_world()
	_test_one_per_pass()
	_test_speed_and_quality()
	_test_node_units()
	_test_trait_rate()
	_test_server()
	_expect(_finished == GROUPS, "all %d groups ran to the end (%d did)" % [GROUPS, _finished])
	if failures.is_empty():
		print("[t_onegather] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_onegather] FAIL %s" % f)
		quit(1)

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _build_world() -> void:
	host = Node3D.new()
	get_root().add_child(host)
	var gd := GDScript.new()
	gd.source_code = "extends Control\nvar notices: Array = []\nvar toasts: Array = []\nvar drawn_blocks: Dictionary = {}\nfunc notice(text: String, tint: Color = Color(0, 0, 0, 0)) -> void:\n\tnotices.append([text, tint])\nfunc toast(id: StringName, n: int) -> void:\n\ttoasts.append([id, n])\n"
	gd.reload()
	hud = gd.new()
	hud.add_to_group("hud")
	host.add_child(hud)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame

func _clear_bag(tool: StringName, tier: String) -> void:
	for i in player.inventory.slot_count:
		player.inventory.slots[i] = null
	if tier != "hands":
		player.inventory.add(IS.make(tool, 1, {"material_tier": tier}, 1))

func _planted(family: String, item: StringName):
	var n = NODE.instantiate()
	host.add_child(n)
	n.position = Vector3(1.2, 0, 0)
	n.setup(StringName("og_%s_%d" % [family, n.get_instance_id()]), item, 2, 4, {"climate": "grassland", "level": 1}, &"none", Color.GRAY, 1.2, 8.0, family)
	var opts: Array = n.options()
	for i in opts.size():
		if str(opts[i]["item"]) == str(item):
			n.select_option(i)
	return n

## The radial (opened by walking up to a node) lets go before the node is freed.
func _drop(n) -> void:
	if player._gather_radial and player._gather_radial.is_open():
		player._gather_radial.close()
	n.free()

## One real finish_gather; returns the units it landed.
func _pass(node) -> int:
	var before: int = player.inventory.count_of(node.yield_def_id)
	player.gather_target = node
	player.actions.finish_gather()
	player.actions.stop_gather_cycle(false)
	player.gather_target = null
	return player.inventory.count_of(node.yield_def_id) - before

func _test_one_per_pass() -> void:
	var keep_lv: int = player.skills.trees["gathering"]["level"]
	var bad: Array[String] = []
	for spec in NODES:
		for tier in TIERS:
			for sk in SKILLS:
				_clear_bag(spec[2], tier)
				player.skills.trees["gathering"]["level"] = sk
				var n = _planted(spec[0], spec[1])
				for k in 3:
					var got := _pass(n)
					if got != 1:
						bad.append("%s %s skill %d pass %d: %d" % [spec[1], tier, sk, k, got])
				_drop(n)
	player.skills.trees["gathering"]["level"] = keep_lv
	print("[t_onegather] %d passes (3 nodes x %d tiers x %d skills x 3), off-by-count: %s" % [NODES.size() * TIERS.size() * SKILLS.size() * 3, TIERS.size(), SKILLS.size(), bad])
	_expect(bad.is_empty(), "every pass lands exactly 1 at every tool tier and Gathering level (%s)" % [bad])
	# The feed: one pass toasts +1, and a repeat collapses into the same row (+1 then +2).
	_clear_bag(&"work_pick", "stone")
	hud.toasts.clear()
	var rock = _planted("Rock", &"stone")
	_pass(rock)
	_pass(rock)
	var stone_toasts: Array = hud.toasts.filter(func(t): return t[0] == &"stone")
	_expect(stone_toasts.size() == 2 and stone_toasts.all(func(t): return int(t[1]) == 1), "each pass toasts +1 stone (%s)" % [stone_toasts])
	var feed = load("res://scripts/ui/top_feed.gd").new()
	feed.sync(player)
	player.inventory.add(IS.make(&"stone", 1, {"level": 1}, 1))
	feed.push_gain(player, &"stone", 1)
	var r0: Array = (feed.rows + feed.waiting).map(func(r: Dictionary) -> int: return int(r.get("n", 0)))
	player.inventory.add(IS.make(&"stone", 1, {"level": 1}, 1))
	feed.push_gain(player, &"stone", 1)
	var all: Array = feed.rows + feed.waiting
	var stone_rows: Array = all.filter(func(r: Dictionary) -> bool: return r.get("kind") == &"gain" and r.get("id") == &"stone")
	print("[t_onegather] feed rows after two +1 stone: %s" % [stone_rows.map(func(r): return r.get("n"))])
	_expect(r0 == [1], "the feed's first row reads +1 (%s)" % [r0])
	_expect(stone_rows.size() == 1 and int(stone_rows[0].get("n", 0)) == 2, "a repeat collapses into the same row as +2 (%s)" % [stone_rows.map(func(r): return r.get("n"))])
	_drop(rock)
	_finished += 1

## Seconds per unit fall (never rise) with the tier and the steel tool is clearly faster; the rare-trait
## odds rise with the tier; the count is 1 throughout (the group above).
func _test_speed_and_quality() -> void:
	for spec in NODES:
		var n = _planted(spec[0], spec[1])
		var line := []
		var prev := INF
		var mono := true
		for tier in TIERS:
			var bag = INV.new(20)
			if tier != "hands":
				bag.add(IS.make(spec[2], 1, {"material_tier": tier}, 1))
			var s: float = GS.unit_seconds_for(bag, n, 1)
			mono = mono and s <= prev + 0.0001
			prev = s
			line.append("%s %.2fs" % [tier, s])
		var stone_bag = INV.new(20)
		stone_bag.add(IS.make(spec[2], 1, {"material_tier": "stone"}, 1))
		var steel_bag = INV.new(20)
		steel_bag.add(IS.make(spec[2], 1, {"material_tier": "steel"}, 1))
		print("[t_onegather] %s seconds per unit: %s" % [spec[1], ", ".join(line)])
		_expect(mono and GS.unit_seconds_for(steel_bag, n, 1) < GS.unit_seconds_for(stone_bag, n, 1) * 0.6, "%s: a better tool is faster per unit (%s)" % [spec[1], line])
		_expect(GS.unit_seconds_for(stone_bag, n, 60) < GS.unit_seconds_for(stone_bag, n, 1), "%s: Gathering level speeds a pass" % spec[1])
		_drop(n)
	var base := float(LT.trait_cfg().get("chance", 0.0))
	var odds := []
	var prev_c := -1.0
	var rising := true
	for tier in TIERS:
		var c: float = LR.trait_chance(&"" if tier == "hands" else StringName(tier))
		rising = rising and c >= prev_c
		prev_c = c
		odds.append("%s %.4f" % [tier, c])
	print("[t_onegather] rare-trait odds per unit: %s" % ", ".join(odds))
	_expect(is_equal_approx(LR.trait_chance(&""), base) and is_equal_approx(LR.trait_chance(&"stone"), base), "bare hands and stone keep the documented 5%")
	_expect(rising and LR.trait_chance(&"steel") > base * 1.5, "a better tier rolls better rare-trait odds (%s)" % [odds])
	_finished += 1

## A node still takes exactly its pool's passes, one unit each.
func _test_node_units() -> void:
	for spec in NODES:
		_clear_bag(spec[2], "steel")
		var n = _planted(spec[0], spec[1])
		var units: int = n.active_pool_max()
		var passes := 0
		var landed := 0
		while n.units_left_for(spec[1]) > 0 and passes < 500:
			landed += _pass(n)
			passes += 1
		print("[t_onegather] %s pool %d: %d passes, %d units landed (steel tool)" % [spec[1], units, passes, landed])
		_expect(units > 0 and passes == units and landed == units, "%s: a node gives its pool of %d units over %d passes (landed %d)" % [spec[1], units, passes, landed])
		_drop(n)
	_finished += 1

## The green rare trait per unit: 5% with bare hands, the tier step with steel (stamp_traits, as both
## client and server call it).
func _test_trait_rate() -> void:
	const N := 6000
	for tier in [&"", &"steel"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 404
		var hits := 0
		for i in N:
			var inv = INV.new(4)
			var st = IS.make(&"stone", 1, {"level": 1}, 1)
			inv.add(st)
			hits += GS.stamp_traits(inv, {}, st, 1, rng, tier).size()
		var want: float = LR.trait_chance(tier)
		var got := float(hits) / float(N)
		print("[t_onegather] rare trait per unit, tool %s: %.4f (want %.4f)" % [tier if tier != &"" else &"hands", got, want])
		_expect(absf(got - want) < 0.015, "rare-trait rate per unit honoured for %s (%.4f vs %.4f)" % [tier, got, want])
	_finished += 1

## The server's act.gather lands one per pass too (srvdom's fixture rock is [2, 4] per pass).
func _test_server() -> void:
	var w = (load("res://tests/srvdom_checks.gd") as GDScript).call("make_world")
	var st = load("res://scripts/server/character_store.gd").new(w, "", 7)
	st.apply("char.create", 1, {"name": "OneGather"}, 1)
	var gained := []
	for i in 12:
		var r: Dictionary = st.apply("act.gather", 1, {"node_id": "rock", "option": 0}, 2 + i)
		gained.append(int(r.get("r", {}).get("gained", -1)) if r.get("ok", false) else -1)
	print("[t_onegather] server act.gather on a [2, 4] rock: %s" % [gained])
	_expect(gained.all(func(g): return g == 1), "the server's act.gather lands exactly 1 per pass (%s)" % [gained])
	_finished += 1
