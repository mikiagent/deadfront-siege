extends SceneTree
## W2-GATHER: role tools speed hand-pickable nodes, tier raises yields, rare finds roll their
## data odds (and only with the right tool), carcass parts scale with knife and skill, the XP
## sink contract. Game classes load after the Data autoload exists (first frame).

var failures: Array[String] = []
var _done := false
## Each test bumps this on its last line: a SCRIPT ERROR mid-test aborts it and fails the run.
var _finished := 0
var IS: GDScript
var INV: GDScript
var GS: GDScript
var LR: GDScript
var LT: GDScript
var GX: GDScript
var NODE: PackedScene

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	GS = load("res://scripts/gather/gather_service.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	LT = load("res://scripts/gather/loot_tables.gd")
	GX = load("res://scripts/gather/gather_xp.gd")
	NODE = load("res://scenes/world/harvest_node.tscn")
	_test_data_ids()
	_test_tools()
	_test_gather_rares()
	_test_carcass()
	_test_xp_sink()
	_expect(_finished == 5, "all 5 test groups ran to the end (%d did)" % _finished)
	if failures.is_empty():
		print("[t_gather] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_gather] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _node(family: String, item: StringName):
	var n = NODE.instantiate()
	n.setup(StringName("t_" + family), item, 1, 1, {"level": 1}, &"none", Color.GRAY, 1.2, 8.0, family)
	var opts: Array = n.options()
	for i in opts.size():
		if str(opts[i]["item"]) == str(item):
			n.select_option(i)
	return n

func _bag(id: StringName, tier: String):
	var bag = INV.new(20)
	if id != &"":
		bag.add(IS.make(id, 1, {"material_tier": tier}, 1))
	return bag

func _test_data_ids() -> void:
	var data := get_root().get_node("Data")
	var missing: Array[String] = []
	var cfg: Dictionary = LT.gather_cfg()
	for group in ["by_role", "by_family"]:
		for k in cfg.get(group, {}):
			for row in cfg[group][k]:
				if data.item(StringName(str(row["item"]))) == null:
					missing.append(str(row["item"]))
				var cl: Array = row.get("climates", [])
				_expect(not cl.is_empty() and cl.all(func(c): return data.world_climates.has(c)), "%s/%s lists real climates (%s)" % [k, row["item"], cl])
	for k in LT.butcher_cfg().get("part_min_tier", {}):
		if data.item(StringName(str(k))) == null:
			missing.append(str(k))
	_expect(missing.is_empty(), "every loot_tables.json id exists in items.json (missing %s)" % [missing])
	_expect(not cfg.get("by_role", {}).is_empty() and LT.affinity_tool("tree") == &"axe", "loot_tables and gather_rules load")
	_finished += 1

func _test_tools() -> void:
	var bush = _node("Bush", &"fibre_stalk")
	var hands = INV.new(20)
	var knife = _bag(&"stone_knife_work", "stone")
	_expect(GS.effective_tool(hands, bush) == null and GS.effective_tool(knife, bush) != null, "a knife is the bush's helper tool")
	var bare_s: float = GS.unit_seconds_for(hands, bush, 1)
	var knife_s: float = GS.unit_seconds_for(knife, bush, 1)
	print("[t_gather] fibre seconds bare %.2f knife %.2f" % [bare_s, knife_s])
	_expect(knife_s < bare_s, "a stone knife gathers fibre faster than bare hands")
	var tree = _node("CommonTree", &"branch")
	var stone_axe = _bag(&"work_axe", "stone")
	var flint_axe = _bag(&"work_axe", "flint")
	_expect(GS.unit_seconds_for(stone_axe, tree, 1) < GS.unit_seconds_for(hands, tree, 1), "an axe takes branches faster than hands")
	var ys: float = GS.yield_multiplier_for(stone_axe, tree, 1)
	var yf: float = GS.yield_multiplier_for(flint_axe, tree, 1)
	print("[t_gather] branch yield mult stone %.2f flint %.2f" % [ys, yf])
	_expect(yf > ys, "a flint axe yields more per pass than a stone axe")
	var rock = _node("Rock", &"stone")
	var pick = _bag(&"work_pick", "stone")
	_expect(GS.effective_tool(pick, rock) != null and GS.unit_seconds_for(pick, rock, 1) < GS.unit_seconds_for(hands, rock, 1), "a pick works loose stone faster than hands")
	for n in [bush, tree, rock]:
		n.free()
	_finished += 1

func _rate(family: String, role: String, tier: StringName, item: StringName, n: int, seed: int, climate := "temperate") -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hits := 0
	for i in n:
		if LR.roll_gather_rares(family, role, climate, tier, 1, rng).has(item):
			hits += 1
	return float(hits) / float(n)

func _test_gather_rares() -> void:
	var bare := _rate("Rock", "rock", &"", &"flint", 20000, 7)
	var obs := _rate("Rock", "rock", &"obsidian", &"flint", 20000, 7)
	print("[t_gather] flint per stone unit: bare %.4f obsidian pick %.4f (data 0.05)" % [bare, obs])
	_expect(absf(bare - 0.05) < 0.008, "bare-hand flint find rate matches the 0.05 data odds (got %.4f)" % bare)
	_expect(obs > bare * 1.3, "a better pick raises the find rate")
	_expect(_rate("Rock", "rock", &"flint", &"copper_ore", 5000, 3, "desert") == 0.0, "copper_ore never drops below its obsidian tool gate")
	_expect(_rate("Rock", "rock", &"obsidian", &"copper_ore", 20000, 3, "desert") > 0.0, "copper_ore drops with an obsidian pick")
	# world-design s4: each climate gives its own materials. Home grassland rock: no flint, no copper.
	for item in [&"flint", &"copper_ore"]:
		var home := _rate("Rock", "rock", &"obsidian", item, 20000, 11, "grassland")
		_expect(home == 0.0, "a home-grassland rock never yields %s (rate %.4f)" % [item, home])
	_expect(_rate("Rock", "rock", &"obsidian", &"copper_ore", 20000, 3, "temperate") == 0.0, "copper_ore (desert) never rolls on a temperate rock")
	_expect(_rate("Bush", "bush", &"", &"berry_seed", 20000, 5, "grassland") > 0.0, "the home grassland still has a find: berry_seed on a bush")
	var a: Array = LR.roll_gather_rares("PineTree", "tree", "tundra", &"", 1, _seeded(99))
	var b: Array = LR.roll_gather_rares("PineTree", "tree", "tundra", &"", 1, _seeded(99))
	_expect(a == b, "rare rolls are deterministic per seed")
	# Spec 12 s1: no rares purely for reaching a high level. Same tool, Lv60 vs Lv1, same odds.
	var hi := _seeded(5)
	var lo := _seeded(5)
	var same := true
	for i in 2000:
		if LR.roll_gather_rares("Rock", "rock", "temperate", &"stone", 60, hi) != LR.roll_gather_rares("Rock", "rock", "temperate", &"stone", 1, lo):
			same = false
	_expect(same, "Gathering level alone does not raise rare find odds")
	var bc: Dictionary = LT.butcher_cfg()
	var c1: float = LR.scaled_chance(0.12, 1, 1, float(bc.get("rare_tool_tier_bonus", 0.0)), float(bc.get("rare_skill_bonus_per_level", 0.0)), float(bc.get("max_rare_chance", 0.6)))
	var c60: float = LR.scaled_chance(0.12, 1, 60, float(bc.get("rare_tool_tier_bonus", 0.0)), float(bc.get("rare_skill_bonus_per_level", 0.0)), float(bc.get("max_rare_chance", 0.6)))
	_expect(is_equal_approx(c1, c60), "Butchering level alone does not raise rare part odds (%.3f vs %.3f)" % [c1, c60])
	_finished += 1

func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _count(stacks: Array, id: StringName) -> int:
	var n := 0
	for st in stacks:
		if st.def_id == id:
			n += st.count
	return n

func _test_carcass() -> void:
	var data := get_root().get_node("Data")
	var raptor: Dictionary = data.butcher_tables.get("velociraptor", {})
	var base: Array = raptor.get("base", [])
	var rare: Array = raptor.get("rare", [])
	var rng := _seeded(11)
	var meat_stone := 0
	var meat_flint := 0
	var talons := 0
	var runs := 2000
	for i in runs:
		meat_stone += _count(LR.roll_carcass(base, rare, 5, &"stone", 1, 1, false, rng)["stacks"], &"raptor_meat")
		var r: Dictionary = LR.roll_carcass(base, rare, 5, &"flint", 1, 1, false, rng)
		meat_flint += _count(r["stacks"], &"raptor_meat")
		talons += 1 if (r["rares"] as Array).has(&"raptor_talon") else 0
	var talon_rate := float(talons) / float(runs)
	print("[t_gather] raptor meat per carcass: stone knife %.2f flint knife %.2f; talon rate %.3f" % [float(meat_stone) / runs, float(meat_flint) / runs, talon_rate])
	_expect(meat_flint > meat_stone, "a flint knife cuts more meat than a stone knife")
	_expect(talon_rate > 0.05 and talon_rate < 0.5, "the rare talon rolls odds instead of always dropping (got %.3f)" % talon_rate)
	var locked: Dictionary = LR.roll_carcass(base, rare, 5, &"flint", 0, 1, false, rng)
	_expect(_count(locked["stacks"], &"raptor_talon") == 0, "the talon stays locked without its Butchering node")
	var lvl: Dictionary = LR.roll_carcass(base, [], 7, &"stone", 0, 1, false, rng)
	_expect(not (lvl["stacks"] as Array).is_empty() and (lvl["stacks"] as Array)[0].level == 7, "carcass parts keep the animal's level")
	_expect(_count(LR.roll_carcass(base, [], 5, &"stone", 0, 1, true, rng)["stacks"], &"raptor_meat") == 0, "a poisoned carcass gives no meat")
	var trike: Dictionary = data.butcher_tables.get("triceratops", {})
	var tb: Array = trike.get("base", [])
	var stone_parts: Array = LR.roll_carcass(tb, [], 5, &"stone", 0, 1, false, rng)["stacks"]
	var flint_parts: Array = LR.roll_carcass(tb, [], 5, &"flint", 0, 1, false, rng)["stacks"]
	_expect(_count(stone_parts, &"armor_scute") == 0 and _count(stone_parts, &"dense_bone") == 0, "a stone knife cannot cut scutes or dense bone")
	_expect(_count(flint_parts, &"armor_scute") > 0 and _count(flint_parts, &"dense_bone") > 0, "a flint knife cuts scutes and dense bone")
	_expect(_count(stone_parts, &"raw_hide") > 0 and _count(stone_parts, &"bone") > 0, "a stone knife still takes hide and bone")
	_finished += 1

func _test_xp_sink() -> void:
	var got: Array = []
	GX.sink = func(_pl, cat: String, amt: float, src: Dictionary) -> void: got.append([cat, amt, src.get("verb")])
	# A null player is refused before the sink (no XP for nobody).
	GX.award(null, "gathering", 5.0, {"verb": "gather"})
	_expect(got.is_empty(), "no XP without a player")
	var fake := CharacterBody3D.new()
	fake.set_script(load("res://scripts/player/player.gd"))
	GX.award(fake, "gathering", 5.0, {"verb": "gather", "item": "flint", "rare": true, "node_level": 1})
	_expect(got.size() == 1 and got[0][0] == "gathering" and is_equal_approx(got[0][1], 5.0) and got[0][2] == "gather", "GatherXp routes to the W2-SKILLS sink when set (got %s)" % [got])
	GX.sink = Callable()
	fake.free()
	_finished += 1
