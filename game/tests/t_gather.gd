extends SceneTree
## W2-GATHER: role tools speed hand-pickable nodes, tier raises yields, the green rare trait rolls the
## documented 5% per item, finds roll their data odds (never the node's own yield, none at home), carcass
## parts scale with knife and skill. Then live, on a real survivor: after_unit reads the node's climate
## and keeps to free slots; a finish_gather pays 2 + the rare bonus into Gathering and wears the helper
## knife; a real raptor's corpse pays rare part XP at the take through both take paths, and a kill out
## of view rolls silently; a yield stack keeps off other nodes; two finds in one frame both reach the screen.
## Game classes load after the Data and World autoloads exist (first frame).

var failures: Array[String] = []
var _done := false
## Each test bumps this on its last line: a SCRIPT ERROR mid-test aborts it and fails the run.
var _finished := 0
const GROUPS := 17
var IS: GDScript
var INV: GDScript
var GS: GDScript
var LR: GDScript
var LT: GDScript
var PS: GDScript
var NODE: PackedScene
var BL: GDScript
var GF: GDScript
var CORPSE: GDScript
var data: Node
var host: Node3D
var player
var hud

func _process(_delta: float) -> bool:
	if _done:
		return false  # the live half awaits frames; it quits itself
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	data = get_root().get_node("Data")
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	GS = load("res://scripts/gather/gather_service.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	LT = load("res://scripts/gather/loot_tables.gd")
	PS = load("res://scripts/items/progression_scaling.gd")
	NODE = load("res://scenes/world/harvest_node.tscn")
	BL = load("res://scripts/gather/butcher_loot.gd")
	GF = load("res://scripts/gather/gather_feedback.gd")
	CORPSE = load("res://scripts/creatures/corpse.gd")
	_test_data_ids()
	_test_tools()
	_test_gather_rares()
	_test_traits()
	_test_carcass()
	_run_live.call_deferred()
	return false

func _run_live() -> void:
	await _build_world()
	_test_after_unit_climate()
	_test_full_bag()
	_test_butcher_hook()
	_test_rare_take_xp()
	_test_gather_live()
	await _test_corpse_live()
	await _test_off_other_nodes()
	await _test_two_finds_one_frame()
	_test_xp_without_skills()
	_test_hud_notice_life()
	_test_server_gather()
	await _test_hud_draw()
	_expect(_finished == GROUPS, "all %d test groups ran to the end (%d did)" % [GROUPS, _finished])
	if failures.is_empty():
		print("[t_gather] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_gather] FAIL %s" % f)
		quit(1)

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

## Runs `body` with loot_tables.json values overridden (path -> value), then restores them.
func _with(cfg: Dictionary, key: String, value: Variant, body: Callable) -> void:
	var had := cfg.has(key)
	var old: Variant = cfg.get(key)
	cfg[key] = value
	body.call()
	if had:
		cfg[key] = old
	else:
		cfg.erase(key)

func _test_data_ids() -> void:
	var missing: Array[String] = []
	var cfg: Dictionary = LT.gather_cfg()
	for group in ["by_role", "by_family"]:
		for k in cfg.get(group, {}):
			for row in cfg[group][k]:
				if data.item(StringName(str(row["item"]))) == null:
					missing.append(str(row["item"]))
				var cl: Array = row.get("climates", [])
				_expect(not cl.is_empty() and cl.all(func(c): return data.world_climates.has(c)), "%s/%s lists real climates (%s)" % [k, row["item"], cl])
				# world-design s4: a climate gives its own materials, so a find is one of them.
				for c in cl:
					var mats: Array = (data.world_climates.get(c, {}) as Dictionary).get("materials", [])
					_expect(mats.any(func(m): return m is Dictionary and str(m.get("id", "")) == str(row["item"])), "%s/%s is in %s's materials (climates.json)" % [k, row["item"], c])
				# tier_index reads an unknown name as stone: a typo would open the row to every tool.
				if row.has("min_tool_tier"):
					_expect(StringName(str(row["min_tool_tier"])) in PS.TOOL_TIERS, "%s/%s min_tool_tier '%s' is a ProgressionScaling tier" % [k, row["item"], row["min_tool_tier"]])
				# A find never opens an item below the pick tier its own node needs (W2-DATA's ladder).
				var need_idx := -1
				for fam in data.nature_families:
					var gate: Dictionary = data.nature_families[fam].get("min_pick_tier", {})
					if gate.has(str(row["item"])):
						need_idx = maxi(need_idx, PS.TOOL_TIERS.find(StringName(str(gate[str(row["item"])]))))
				var row_idx: int = PS.TOOL_TIERS.find(StringName(str(row.get("min_tool_tier", "")))) if row.has("min_tool_tier") else -1
				# A row no node can roll is dead data (silver sat on BlackIronNode, which no snowfield grows).
				var grows := false
				for c in cl:
					for fam in (data.world_climates.get(c, {}) as Dictionary).get("vegetation", []):
						var fd: Dictionary = data.nature_families.get(fam, {})
						var fits: bool = (fam == k) if group == "by_family" else (str(fd.get("role", "")) == k)
						grows = grows or (fits and not (fd.get("harvest", {}) as Dictionary).has(str(row["item"])))
				_expect(grows, "%s/%s can roll: a %s node grows in %s and does not yield it itself" % [k, row["item"], k, cl])
				_expect(row_idx >= need_idx, "%s/%s find gate '%s' is not below its nodes' min_pick_tier (%s)" % [k, row["item"], row.get("min_tool_tier", "none"), PS.TOOL_TIERS[need_idx] if need_idx >= 0 else "none"])
	var gates: Dictionary = LT.butcher_cfg().get("part_min_tier", {})
	for k in gates:
		if data.item(StringName(str(k))) == null:
			missing.append(str(k))
		_expect(StringName(str(gates[k])) in PS.TOOL_TIERS, "part_min_tier %s '%s' is a ProgressionScaling tier" % [k, gates[k]])
	_expect(missing.is_empty(), "every loot_tables.json id exists in items.json (missing %s)" % [missing])
	_expect(not cfg.get("by_role", {}).is_empty() and LT.affinity_tool("tree") == &"axe", "loot_tables and gather_rules load")
	# world-design.md:55 "5% chance of a rare extra (green pip)"; spec 04:11 names the six green traits.
	var tc: Dictionary = LT.trait_cfg()
	_expect(is_equal_approx(float(tc.get("chance", 0.0)), 0.05), "the rare trait chance is world-design.md:55's 5%% (data %s)" % tc.get("chance"))
	_expect((tc.get("traits", []) as Array) == ["black_sheen", "low_vibration", "wide_serration", "narrow_hook", "split_easily", "vivid_inspiration"], "the green traits are spec 04:11's six")
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
	# Spec 12:44: the helper tool wears like a required one; a required tool is worn by PlayerActions only.
	var k = knife.find_gather_tool(&"knife")
	var d0: int = k.durability
	GS.wear_role_tool(knife, &"none", "Bush")
	GS.wear_role_tool(knife, &"knife", "Bush")
	_expect(k.durability == d0 - 1, "a knife helping on a bush wears 1 per unit, a required one is not worn twice (%d -> %d)" % [d0, k.durability])
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
	var bare := _rate("Rock", "rock", &"", &"flint", 5000, 7)
	var stone := _rate("Rock", "rock", &"stone", &"flint", 5000, 7)
	var bone := _rate("Rock", "rock", &"bone", &"flint", 20000, 7)
	var obs := _rate("Rock", "rock", &"obsidian", &"flint", 20000, 7)
	print("[t_gather] flint per stone unit: bare %.4f stone %.4f bone pick %.4f obsidian pick %.4f (data 0.05 x 1.15 per tier)" % [bare, stone, bone, obs])
	# FlintNode gates flint behind a bone pick (W2-DATA ladder): a find never skips that rung.
	_expect(bare == 0.0 and stone == 0.0, "flint never drops below the bone pick FlintNode needs (bare %.4f, stone %.4f)" % [bare, stone])
	_expect(absf(bone - 0.0575) < 0.008, "bone-pick flint find rate matches the 0.05 data odds plus one tier bonus (got %.4f)" % bone)
	_expect(obs > bone * 1.15, "a better pick raises the find rate")
	_expect(_rate("Rock", "rock", &"flint", &"copper_ore", 5000, 3, "desert") == 0.0, "copper_ore never drops below its obsidian tool gate")
	_expect(_rate("Rock", "rock", &"obsidian", &"copper_ore", 20000, 3, "desert") > 0.0, "copper_ore drops with an obsidian pick")
	# world-design s4: each climate gives its own materials. Home grassland rock: no flint, no copper.
	for item in [&"flint", &"copper_ore"]:
		var home := _rate("Rock", "rock", &"obsidian", item, 20000, 11, "grassland")
		_expect(home == 0.0, "a home-grassland rock never yields %s (rate %.4f)" % [item, home])
	_expect(_rate("Rock", "rock", &"obsidian", &"copper_ore", 20000, 3, "temperate") == 0.0, "copper_ore (desert) never rolls on a temperate rock")
	# A find is never the node's own yield ("RARE Herb Leaf" over "+2 Herb Leaf"), on any family in any
	# climate; and the home grassland, whose materials are all its nodes' own yields, has no finds at all.
	var own_hits: Array[String] = []
	var home_hits: Array[String] = []
	var home_veg: Array = (data.world_climates.get("grassland", {}) as Dictionary).get("vegetation", [])
	var rng := _seeded(13)
	for fam in data.nature_families:
		var role := str(data.nature_families[fam].get("role", ""))
		var harvest: Dictionary = data.nature_families[fam].get("harvest", {})
		for cl in data.world_climates:
			for i in 300:
				for id in LR.roll_gather_rares(fam, role, cl, &"steel", 1, rng):
					if harvest.has(str(id)):
						own_hits.append("%s/%s/%s" % [fam, cl, id])
					if cl == "grassland" and fam in home_veg:
						home_hits.append("%s/%s" % [fam, id])
	_expect(own_hits.is_empty(), "no find is the node's own yield (%s)" % [own_hits.slice(0, 5)])
	_expect(home_hits.is_empty(), "the home grassland rolls no finds (%s)" % [home_hits.slice(0, 5)])
	var a: Array = LR.roll_gather_rares("PineTree_Snow", "tree", "tundra", &"", 1, _seeded(99))
	var b: Array = LR.roll_gather_rares("PineTree_Snow", "tree", "tundra", &"", 1, _seeded(99))
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
	# Typo or hostile rows are skipped, not a SCRIPT ERROR that aborts the unit (and its popup), and a
	# misspelt tier is not read as stone: with them in the table every seed rolls what it rolled without.
	var rock_rows: Array = LT.gather_cfg()["by_role"]["rock"]
	var kept := rock_rows.duplicate()
	var ref: Array = []
	for sd in 200:
		ref.append(LR.roll_gather_rares("Rock", "rock", "temperate", &"obsidian", 1, _seeded(sd)))
	rock_rows.push_front("oops")
	rock_rows.append({"item": "pearl", "chance": 1.0, "climates": "temperate"})  # a String, not a list
	rock_rows.append({"item": "salt", "chance": 1.0, "climates": ["temperate"], "min_tool_tier": "obsidain"})
	var diff := 0
	for sd in 200:
		if LR.roll_gather_rares("Rock", "rock", "temperate", &"obsidian", 1, _seeded(sd)) != ref[sd]:
			diff += 1
	rock_rows.assign(kept)
	_expect(diff == 0 and ref.any(func(r): return not r.is_empty()), "bad rows and a misspelt tier are skipped, the good rows still roll (%d of 200 seeds differ)" % diff)
	_finished += 1

func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

## Units of `id` in `inv` carrying any green trait, and how many slots hold them.
func _traited(inv, id: StringName) -> int:
	var traits: Array = LT.trait_cfg().get("traits", [])
	var n := 0
	for st in inv.slots:
		if st and st.def_id == id and traits.any(func(t): return st.attributes.get(str(t), false) == true):
			n += st.count
	return n

## world-design.md:55: 5% of gathered items carry one green trait; the swap never loses or mints a unit.
func _test_traits() -> void:
	var inv = INV.new(400)
	var rng := _seeded(17)
	var stamped := 0
	for i in 4000:
		var st = IS.make(&"fibre_stalk", 1, {"level": 1}, 1)
		inv.add(st)
		stamped += GS.stamp_traits(inv, st, 1, rng).size()
	var traited := _traited(inv, &"fibre_stalk")
	var rate := float(traited) / 4000.0
	print("[t_gather] rare trait rate %.4f over 4000 fibre (data 0.05), %d stamped" % [rate, stamped])
	_expect(absf(rate - 0.05) < 0.012 and stamped == traited, "about 5%% of gathered items carry a green trait (got %.4f, stamped %d, in bag %d)" % [rate, stamped, traited])
	_expect(inv.count_of(&"fibre_stalk") == 4000, "trait swaps keep every unit (%d of 4000)" % inv.count_of(&"fibre_stalk"))
	var one_each := true
	for st in inv.slots:
		if st and st.def_id == &"fibre_stalk":
			var n := 0
			for t in LT.trait_cfg()["traits"]:
				n += 1 if st.attributes.has(str(t)) else 0
			one_each = one_each and n <= 1
	_expect(one_each, "an item carries at most one rare trait")
	# A full bag: the hit unit stays plain where it was, nothing lost or minted.
	var full = INV.new(3)
	var plain = IS.make(&"stone", 5, {"level": 1}, 1)
	full.add(plain)
	full.add(IS.make(&"branch", 1, {"level": 1}, 1))
	full.add(IS.make(&"clay", 1, {"level": 1}, 1))
	_with(LT.trait_cfg(), "chance", 1.0, func() -> void:
		var got: Array = GS.stamp_traits(full, plain, 2, _seeded(3))
		_expect(got.is_empty() and full.count_of(&"stone") == 5 and _traited(full, &"stone") == 0, "with no free slot the item stays plain and whole (stamped %s, stone %d)" % [got, full.count_of(&"stone")]))
	_finished += 1

func _count(stacks: Array, id: StringName) -> int:
	var n := 0
	for st in stacks:
		if st.def_id == id:
			n += st.count
	return n

func _test_carcass() -> void:
	var raptor: Dictionary = data.butcher_tables.get("velociraptor", {})
	var base: Array = raptor.get("base", [])
	var rare: Array = raptor.get("rare", [])
	var rng := _seeded(11)
	var meat_none := 0
	var meat_stone := 0
	var meat_flint := 0
	var talons := 0
	var runs := 2000
	for i in runs:
		meat_none += _count(LR.roll_carcass(base, rare, 5, &"", 1, 1, false, rng)["stacks"], &"raptor_meat")
		meat_stone += _count(LR.roll_carcass(base, rare, 5, &"stone", 1, 1, false, rng)["stacks"], &"raptor_meat")
		var r: Dictionary = LR.roll_carcass(base, rare, 5, &"flint", 1, 1, false, rng)
		meat_flint += _count(r["stacks"], &"raptor_meat")
		talons += 1 if (r["rares"] as Array).has(&"raptor_talon") else 0
	var talon_rate := float(talons) / float(runs)
	print("[t_gather] raptor meat per carcass: no knife %.2f stone knife %.2f flint knife %.2f; talon rate %.3f" % [float(meat_none) / runs, float(meat_stone) / runs, float(meat_flint) / runs, talon_rate])
	_expect(meat_flint > meat_stone, "a flint knife cuts more meat than a stone knife")
	# loot_tables.json no_knife_count_mult: bare hands butcher less, as they gather slower.
	_expect(meat_none < meat_stone * 0.85, "no knife cuts less meat than a stone knife (%.2f vs %.2f)" % [float(meat_none) / runs, float(meat_stone) / runs])
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
	# A misspelt part gate keeps the part on the carcass instead of opening it to any knife.
	_with(LT.butcher_cfg()["part_min_tier"], "armor_scute", "flnit", func() -> void:
		var typo: Array = LR.roll_carcass(tb, [], 5, &"steel", 0, 1, false, rng)["stacks"]
		_expect(_count(typo, &"armor_scute") == 0, "a misspelt part_min_tier keeps the scute on the carcass"))
	_finished += 1

# --- live: a real survivor (player.tscn), a HUD stand-in that records toasts and notices ---------

func _build_world() -> void:
	host = Node3D.new()
	host.name = "TGather"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var gd := GDScript.new()
	gd.source_code = "extends Control\nvar notices: Array = []\nvar toasts: Array = []\nfunc notice(text: String, tint: Color = Color(0, 0, 0, 0)) -> void:\n\tnotices.append([text, tint])\nfunc toast(id: StringName, n: int) -> void:\n\ttoasts.append([id, n])\n"
	gd.reload()
	hud = gd.new()
	hud.add_to_group("hud")
	host.add_child(hud)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 0.9, 0)
	host.add_child(player)
	await physics_frame

func _clear_bag() -> void:
	for i in player.inventory.slot_count:
		player.inventory.slots[i] = null

## A node as IslandScatter.plant_at makes one: in the scene, climate and level in its yield attributes.
func _planted(family: String, item: StringName, climate: String, need: StringName, at := Vector3.ZERO):
	var n = NODE.instantiate()
	host.add_child(n)
	n.position = at
	n.setup(StringName("t_%s_%s_%d" % [family, climate, n.get_instance_id()]), item, 2, 4, {"climate": climate, "level": 1}, need, Color.GRAY, 1.2, 8.0, family)
	var opts: Array = n.options()
	for i in opts.size():
		if str(opts[i]["item"]) == str(item):
			n.select_option(i)
	return n

func _rock(climate: String):
	return _planted("Rock", &"stone", climate, &"pick")

## `units` passes of one stone each, added to the bag then handed to after_unit as PlayerActions does.
func _gather_units(node, units: int) -> int:
	var landed := 0
	for i in units:
		var st = IS.make(&"stone", 1, {"level": 1}, 1)
		var gained: int = 1 - player.inventory.add(st)
		landed += GS.after_unit(player, node, st, gained).size()
	return landed

func _tinted(n: Array) -> bool:
	return (n[1] as Color).a > 0.0

func _test_after_unit_climate() -> void:
	_clear_bag()
	player.inventory.add(IS.make(&"work_pick", 1, {"material_tier": "obsidian"}, 1))
	GS.rng.seed = 21
	var home = _rock("grassland")
	_gather_units(home, 300)
	var f_home: int = player.inventory.count_of(&"flint")
	var c_home: int = player.inventory.count_of(&"copper_ore")
	_expect(f_home == 0 and c_home == 0, "after_unit on a home-grassland rock (obsidian pick, 300 units) finds no flint (%d) or copper (%d)" % [f_home, c_home])
	_clear_bag()
	player.inventory.add(IS.make(&"work_pick", 1, {"material_tier": "obsidian"}, 1))
	var temperate = _rock("temperate")
	var got := _gather_units(temperate, 300)
	var f_temp: int = player.inventory.count_of(&"flint")
	print("[t_gather] after_unit 300 units: grassland rock flint %d copper %d; temperate rock flint %d" % [f_home, c_home, f_temp])
	_expect(f_temp > 0 and got == f_temp, "after_unit on a temperate rock finds flint (%d landed, %d in the bag)" % [got, f_temp])
	var i: int = player.inventory.find_first(&"flint")
	var st = player.inventory.slots[i] if i >= 0 else null
	_expect(st != null and str(st.attributes.get("climate", "")) == "temperate" and st.level == 1, "a find is stamped with the node's climate and level (%s)" % [st.attributes if st else {}])
	_expect(hud.notices.all(_tinted), "every rare notice is tinted, never the red refusal box")
	home.free()
	temperate.free()
	_finished += 1

## A full bag takes no find, even one that would stack onto a flint already there.
func _test_full_bag() -> void:
	_clear_bag()
	var inv = player.inventory
	inv.add(IS.make(&"work_pick", 1, {"material_tier": "obsidian"}, 1))
	inv.add(IS.make(&"flint", 1, {"level": 1}, 1))
	var lvl := 2
	while inv.used_slots() < inv.slot_count:
		inv.add(IS.make(&"stone", 1, {"level": lvl}, lvl))  # distinct levels never merge
		lvl += 1
	GS.rng.seed = 22
	var rock = _rock("temperate")
	var got := _gather_units(rock, 400)
	print("[t_gather] full bag: %d finds landed, flint %d, used %d/%d" % [got, inv.count_of(&"flint"), inv.used_slots(), inv.slot_count])
	_expect(got == 0 and inv.count_of(&"flint") == 1 and inv.used_slots() == inv.slot_count, "a full bag takes no rare find (landed %d, flint %d)" % [got, inv.count_of(&"flint")])
	rock.free()
	_finished += 1

func _carcasses(species: StringName, n: int, ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		out[id] = 0
	for i in n:
		var c = CORPSE.new()
		c.species = species
		c.level = 1
		BL.roll_into(c)
		for id in ids:
			out[id] += c.loot.count_of(id)
		c.free()
	return out

## The corpse.gd hook: the local survivor's own knife decides the cut.
func _test_butcher_hook() -> void:
	var ids := [&"raw_meat", &"armor_scute", &"dense_bone"]
	BL.rng.seed = 31
	_clear_bag()
	var none := _carcasses(&"triceratops", 150, ids)
	player.inventory.add(IS.make(&"stone_knife_work", 1, {"material_tier": "flint"}, 1))
	var flint := _carcasses(&"triceratops", 150, ids)
	print("[t_gather] roll_into x150 triceratops: no knife %s, flint knife %s" % [none, flint])
	_expect(flint[&"raw_meat"] > none[&"raw_meat"], "the survivor's flint knife cuts more meat than no knife (%d vs %d)" % [flint[&"raw_meat"], none[&"raw_meat"]])
	_expect(none[&"armor_scute"] == 0 and none[&"dense_bone"] == 0, "without a knife no scutes or dense bone come off")
	_expect(flint[&"armor_scute"] > 0 and flint[&"dense_bone"] > 0, "the survivor's flint knife cuts scutes and dense bone")
	_finished += 1

## Unlocks every Butchering node (the talon row needs one); returns what to lock again.
func _unlock_butchering() -> Array:
	var unlocked: Array = []
	for id in data.survival_nodes:
		if str(data.survival_nodes[id].get("kind", "")) == "butchering" and not data.is_survival_unlocked(id):
			data.set_survival_unlocked(id, true)
			unlocked.append(id)
	return unlocked

func _relock(unlocked: Array) -> void:
	for id in unlocked:
		data.set_survival_unlocked(id, false)

## A skill tree parked mid-level, so an XP delta is exact (no level-up resets the bar).
func _park(tree: String) -> void:
	player.skills.trees[tree]["level"] = 30
	player.skills.trees[tree]["xp"] = 0.0

## Rare part XP is paid when the part is taken, once, to the taker; not when the animal falls.
func _test_rare_take_xp() -> void:
	var unlocked := _unlock_butchering()
	_park("butchering")
	var bonus := float(LT.rules()["xp"]["rare_butcher_bonus"])
	BL.rng.seed = 41
	var c = null
	for i in 300:
		c = CORPSE.new()
		c.species = &"velociraptor"
		c.level = 1
		if BL.roll_into(c).has(&"raptor_talon"):
			break
		c.free()
		c = null
	_expect(c != null, "a raptor carcass rolled a talon within 300 tries")
	if c:
		_expect(player.skills.xp_of("butchering") == 0.0, "no rare XP when the animal falls (got %.1f)" % player.skills.xp_of("butchering"))
		_expect(hud.notices.any(func(n): return str(n[0]).contains("Raptor Talon") and n[1] == GF.GOLD), "the talon is announced in gold")
		var before: int = c.loot.count_of(&"raw_hide")
		BL.on_take(c, player)
		_expect(player.skills.xp_of("butchering") == 0.0, "taking nothing rare pays no rare XP")
		c.loot.remove_at(c.loot.find_first(&"raptor_talon"), 1)
		BL.on_take(c, player)
		BL.on_take(c, player)
		_expect(is_equal_approx(player.skills.xp_of("butchering"), bonus), "the talon pays its %.0f XP once, at the take (got %.1f)" % [bonus, player.skills.xp_of("butchering")])
		_expect(c.loot.count_of(&"raw_hide") == before, "on_take moves no loot")
		c.free()
	_relock(unlocked)
	_finished += 1

## The PlayerActions.finish_gather hook on a real survivor, no stubs: a home bush gathered with a knife
## in the bag pays 2 Gathering XP plus the rare bonus per traited item, and the helper knife wears.
func _test_gather_live() -> void:
	_clear_bag()
	_park("gathering")
	player.inventory.add(IS.make(&"stone_knife_work", 1, {}, 1))
	var knife = player.inventory.find_gather_tool(&"knife")
	var d0: int = knife.durability
	var bush = _planted("Bush", &"fibre_stalk", "grassland", &"none", Vector3(1.2, 0, 0))
	var bonus := float(LT.rules()["xp"]["rare_gather_bonus"])
	_with(LT.trait_cfg(), "chance", 1.0, func() -> void:
		player.gather_target = bush
		player.actions.finish_gather()
		player.actions.stop_gather_cycle()
		player.gather_target = null)
	var fibre: int = player.inventory.count_of(&"fibre_stalk")
	var traited := _traited(player.inventory, &"fibre_stalk")
	var xp: float = player.skills.xp_of("gathering")
	print("[t_gather] finish_gather on a home bush (trait odds forced to 1): fibre %d, traited %d, gathering XP %.1f, knife %d -> %d" % [fibre, traited, xp, d0, knife.durability])
	_expect(fibre > 0 and traited == fibre, "every gathered item took a trait with the odds forced to 1 (%d of %d)" % [traited, fibre])
	_expect(is_equal_approx(xp, 2.0 + bonus * traited), "finish_gather pays 2 + %.0f per rare item into Gathering (got %.1f, want %.1f)" % [bonus, xp, 2.0 + bonus * traited])
	_expect(knife.durability == d0 - 1, "the helper knife wore once for the unit (%d -> %d)" % [d0, knife.durability])
	_expect(hud.toasts.any(func(t): return t[0] == &"fibre_stalk"), "the unit toasts as before")
	bush.free()
	_finished += 1

## A raptor that really dies (Creature -> Corpse.setup -> _roll_loot -> ButcherLoot.roll_into) with
## its talon forced; the talon taken through PlayerActions.loot (the radial take) and through
## Corpse.take_slot (_on_take_from_loot, the chest screen's on_take) each pays 3 + the rare bonus.
func _raptor_corpse(at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	host.add_child(c)
	c.spawn(data.creature(&"velociraptor"))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	c.health.take_damage(99999.0, player)
	await process_frame
	for n in get_nodes_in_group("corpse"):
		if n.get("_owner") == c:
			return n
	return null

func _test_corpse_live() -> void:
	var unlocked := _unlock_butchering()
	var bc: Dictionary = LT.butcher_cfg()
	var keep := [bc.get("default_rare_chance"), bc.get("max_rare_chance")]
	bc["default_rare_chance"] = 1.0
	bc["max_rare_chance"] = 1.0
	_clear_bag()
	player.inventory.add(IS.make(&"stone_knife_work", 1, {}, 1))
	var bonus := float(LT.rules()["xp"]["rare_butcher_bonus"])
	hud.notices.clear()
	var a = await _raptor_corpse(Vector3(1.5, 0.5, 1.0))
	_expect(a != null and a.loot.count_of(&"raptor_talon") > 0, "a real raptor death leaves a corpse with the forced talon")
	_expect(hud.notices.any(func(n): return str(n[0]).contains("Raptor Talon")), "a kill in view announces its talon")
	if a:
		_park("butchering")
		var moved: int = player.actions.loot(a, a.loot.find_first(&"raptor_talon"))
		var xp: float = player.skills.xp_of("butchering")
		print("[t_gather] PlayerActions.loot talon: moved %d, butchering XP %.1f" % [moved, xp])
		_expect(moved > 0 and is_equal_approx(xp, 3.0 + bonus), "the radial take (PlayerActions.loot) pays 3 + %.0f for the talon (got %.1f)" % [bonus, xp])
	var b = await _raptor_corpse(Vector3(-1.5, 0.5, 1.0))
	if b:
		_park("butchering")
		var taken = b.take_slot(b.loot.find_first(&"raptor_talon"), player)
		var xp: float = player.skills.xp_of("butchering")
		print("[t_gather] Corpse.take_slot talon: %s, butchering XP %.1f" % [taken.def_id if taken else &"", xp])
		_expect(taken != null and is_equal_approx(xp, 3.0 + bonus), "the chest-screen take (_on_take_from_loot) pays 3 + %.0f for the talon (got %.1f)" % [bonus, xp])
	# A kill far out of view (a turret's, another island corner's) rolls its talon without a notice.
	hud.notices.clear()
	var far = await _raptor_corpse(Vector3(400.0, 0.5, 0.0))
	_expect(far != null and far.loot.count_of(&"raptor_talon") > 0 and not hud.notices.any(func(n): return str(n[0]).contains("Raptor Talon")), "a kill out of view rolls its talon silently (notices %s)" % [hud.notices])
	bc["default_rare_chance"] = keep[0]
	bc["max_rare_chance"] = keep[1]
	_relock(unlocked)
	_finished += 1

## A yield stack never sits on another node: with a second rock right where the stack would rise,
## it goes beside the ring instead, and its nearest edge stays within MAX_SHIFT of the ring.
func _test_off_other_nodes() -> void:
	current_scene = host  # GatherFeedback draws its stacks under the current scene
	var cam: Camera3D = player.get_viewport().get_camera_3d()
	var a = _planted("Rock", &"stone", "grassland", &"none", Vector3(3.0, 0, 2.5))
	var b = _planted("Rock", &"stone", "grassland", &"none", Vector3(3.0, 0, 0.0))
	var at: Vector3 = a.global_position + Vector3(0, a.top_of_node() + 0.3, 0)
	var anchor: Vector2 = cam.unproject_position(at)
	var b_rects: Array[Rect2] = GF.node_rects(player, anchor)
	var above := Rect2(anchor.x - 60.0, anchor.y - GF.RING_CLEAR - 60.0, 120.0, 60.0)
	_expect(b_rects.any(func(r: Rect2) -> bool: return r.intersects(above)), "set-up: the second rock covers the space above the first one's ring (%s vs %s)" % [b_rects, above])
	var box = GF.popup(player, at, [["+3 Stone", GF.CREAM, false]])
	for i in 3:
		await process_frame
	var r: Rect2 = box.get_global_rect() if is_instance_valid(box) and box.visible else Rect2()
	var on_b := b_rects.any(func(x: Rect2) -> bool: return x.intersects(r))
	var gap: Vector2 = GF._gap(r, anchor)
	print("[t_gather] stack beside a second rock: %s, anchor %s, gap %s, on the other rock %s" % [r, anchor, gap, on_b])
	_expect(r.has_area() and not on_b, "the stack keeps off the other rock (%s)" % r)
	_expect(gap.x <= GF.MAX_SHIFT and gap.y <= GF.MAX_SHIFT, "the stack's nearest edge is within %d px of the ring (%s)" % [GF.MAX_SHIFT, gap])
	if is_instance_valid(box):
		box.queue_free()
	a.free()
	b.free()
	# The nudge limit counts the stack's nearest edge, not just its slide: a column above the ring slid
	# up 100 px (under MAX_SHIFT) ends 144 px from the ring and is refused.
	var c := Vector2(1000, 1000)
	var cols: Array[Rect2] = [Rect2(c.x - 45.0, c.y - GF.RING_CLEAR - 40.0, 90.0, 40.0)]
	var block: Array[Rect2] = [Rect2(c.x - 100.0, c.y - GF.RING_CLEAR - 40.0 - 56.0, 200.0, 600.0)]
	_expect(GF._best_offset(cols, block, c, Vector2(2000, 2000)) == Vector2.INF, "a spot whose nearest edge ends past MAX_SHIFT from the ring is refused")
	_finished += 1

## Two finds announced in the same frame (a unit landing as a pet kills a raptor): both reach the
## screen, as a gold stack or a gold notice. The old shared callable failed to connect and lost both.
func _test_two_finds_one_frame() -> void:
	hud.notices.clear()
	_clear_bag()
	current_scene = host
	GF.announce_rares(player, Vector3(-1, 1, 0), [&"pearl"] as Array[StringName])
	GF.announce_rares(player, Vector3(1, 1, 0), [&"raptor_talon"] as Array[StringName])
	for i in 3:
		await process_frame
	var shown: Array = []
	var layer := current_scene.get_node_or_null("GatherPopups")
	for box in (layer.get_children() if layer else []):
		if box.visible and not box.is_queued_for_deletion():
			for l in box.get_children():
				shown.append(l.text)
	for n in hud.notices:
		if _tinted(n):
			shown.append(n[0])
	print("[t_gather] two finds in one frame: %s" % [shown])
	for nm in ["Pearl", "Raptor Talon"]:
		_expect(shown.any(func(t): return str(t).contains(nm)), "%s announced (stack or gold notice) when two finds share a frame" % nm)
	# A drawn stack cut short (replaced within SHOWN_MS) hands its find to the gold notice.
	hud.notices.clear()
	var first = GF.popup(player, Vector3(-1, 1, 0), [["RARE  Resin", GF.GOLD, true]], func() -> void: hud.notice("Rare find: Resin", GF.GOLD))
	for i in 2:
		await process_frame
	var drawn: bool = is_instance_valid(first) and first.visible
	GF.announce_rares(player, Vector3(1, 1, 0), [&"flint"] as Array[StringName])
	_expect(drawn and hud.notices.any(func(n): return str(n[0]).contains("Resin") and _tinted(n)), "a rare stack replaced before it was read is announced by the gold notice (drawn %s, notices %s)" % [drawn, hud.notices])
	# A trait the stack cannot show goes to a green notice.
	hud.notices.clear()
	GF.show_yield(player, Vector3(0, 1, 400), &"stone", 1, [] as Array[StringName], [&"black_sheen"] as Array[StringName])
	_expect(hud.notices.any(func(n): return str(n[0]) == "Rare trait: Black Sheen Stone" and n[1] == GF.GREEN), "an unshown trait reaches the HUD as a green notice (%s)" % [hud.notices])
	# Owner 2026-10-21 "make it flashy": a rare stack lands big and bright and eases back; a plain one does not pop.
	var plain = GF.popup(player, Vector3(-1, 1, 0), [["+1 Stone", GF.CREAM, false]])
	var plain_pop: bool = plain.scale != Vector2.ONE
	var rare = GF.popup(player, Vector3(-1, 1, 0), [["Black Sheen Stone", GF.GREEN, true], ["+1 Stone", GF.CREAM, false]])
	var s0: float = rare.scale.x
	var f0: float = rare.modulate.r
	await create_timer(GF.PUNCH_S * 1.6 + 0.1).timeout
	var s1: float = rare.scale.x if is_instance_valid(rare) else -1.0
	var f1: float = rare.modulate.r if is_instance_valid(rare) else -1.0
	print("[t_gather] rare punch: scale %.2f -> %.2f, flash %.2f -> %.2f, plain pops %s" % [s0, s1, f0, f1, plain_pop])
	_expect(not plain_pop and s0 > 1.2 and f0 > 1.5 and is_equal_approx(s1, 1.0) and is_equal_approx(f1, 1.0), "a rare stack pops and flashes, then eases to normal; a plain one does not (scale %.2f -> %.2f, flash %.2f -> %.2f, plain %s)" % [s0, s1, f0, f1, plain_pop])
	_finished += 1

## Rare XP without a skill tree still counts (general player XP), as the base +2 does.
func _test_xp_without_skills() -> void:
	var world := get_root().get_node("World")
	var lv0: int = world.pioneer_level
	var x0: int = world.pioneer_xp
	var gx: GDScript = load("res://scripts/gather/gather_xp.gd")
	var keep = player.skills
	player.skills = null
	gx.award(player, "gathering", 10.0)
	player.skills = keep
	_expect(world.pioneer_level > lv0 or world.pioneer_xp == x0 + 10, "rare XP without skills goes to player XP (%d -> %d)" % [x0, world.pioneer_xp])
	_finished += 1

## The real HUD (hunt_hud.gd): a rare notice is tinted and lives as long as the stack it stands in for
## (NOTICE_T0 into the 3.2 s life), so it is gone before the next thing on screen; a plain one is unchanged.
func _test_hud_notice_life() -> void:
	var h = load("res://scripts/ui/hunt_hud.gd").new()
	h.notice("Rare find: Flint", GF.GOLD)
	h.notice("Too far.")
	var rare: Dictionary = h._events.notices[0]
	var plain: Dictionary = h._events.notices[1]
	_expect(rare.get("tint") == GF.GOLD and is_equal_approx(float(rare["t"]), GF.NOTICE_T0) and not plain.has("tint"), "a rare notice is tinted and starts at NOTICE_T0, a plain one is not (%s, %s)" % [rare, plain])
	_expect(int(rare.get("born", -1)) >= 0, "a rare notice records when it was raised")
	# No room on the HUD: a fresh rare notice waits (clock held), one raised NOTICE_WAIT_MS ago ages on.
	var fresh := {"text": "a", "t": 1.8, "tint": GF.GOLD, "born": Time.get_ticks_msec()}
	var stale := {"text": "b", "t": 1.8, "tint": GF.GOLD, "born": Time.get_ticks_msec() - GF.NOTICE_WAIT_MS - 1}
	var other := {"text": "c", "t": 1.8}
	for n in [fresh, stale, other]:
		GF.hold_notice(n)
	_expect(is_equal_approx(fresh["t"], GF.NOTICE_T0) and is_equal_approx(stale["t"], 1.8) and is_equal_approx(other["t"], 1.8), "with no room a fresh rare notice waits, a stale or plain one ages (%s %s %s)" % [fresh["t"], stale["t"], other["t"]])
	# A rare notice goes once the survivor works another node; the node it came from keeps it.
	var na = _planted("Bush", &"fibre_stalk", "grassland", &"none", Vector3(-3, 0, 0))
	var nb = _planted("Bush", &"fibre_stalk", "grassland", &"none", Vector3(-5, 0, 0))
	player.gather_target = na
	var own := {"text": "d", "t": 0.0}
	GF.stamp_notice(own, GF.GREEN, player)
	var same: bool = GF.notice_stale(own, player)
	player.gather_target = nb
	var moved: bool = GF.notice_stale(own, player)
	var plain_moved: bool = GF.notice_stale({"text": "e", "t": 1.0}, player)
	player.gather_target = null
	_expect(not same and moved and own["t"] == INF and not plain_moved, "a rare notice goes when the survivor works another node, not before (same %s, moved %s, plain %s)" % [same, moved, plain_moved])
	# ...or opens the bag or a loot screen over it (an InventoryUI out of the tree stands in for the HUD's).
	var keep_ui = player.ui
	var ui = load("res://scripts/ui/inventory_ui.gd").new()
	ui.visible = false
	player.ui = ui
	var lone := {"text": "f", "t": 0.0}
	GF.stamp_notice(lone, GF.GOLD, player)
	var closed: bool = GF.notice_stale(lone, player)
	ui.visible = true
	var opened: bool = GF.notice_stale(lone, player)
	player.ui = keep_ui
	ui.free()
	_expect(not closed and opened, "a rare notice goes when a bag or loot screen opens (closed %s, open %s)" % [closed, opened])
	na.free()
	nb.free()
	h._events.tick(GF.LIFE + 0.9)
	var texts: Array = h._events.notices.map(func(n): return n["text"])
	_expect(not texts.has("Rare find: Flint") and texts.has("Too far."), "after the stack's life the rare notice is gone, a plain one stays (%s)" % [texts])
	h.free()
	_finished += 1

## The server's act.gather (the W2-GATHER hunk in intent_handlers.gd), odds forced to 1: on a temperate
## rock the helper pick wears 1 (the knife does not), every item takes a green trait and keeps a uid,
## the flint find is minted with a uid, counted as minted and listed in r.rares; a grassland rock
## yields no find; on a bush the helper knife wears 1.
func _test_server_gather() -> void:
	var w = load("res://scripts/server/world_facade.gd").new()
	var one := [{"item": "stone", "tool": "none", "min": 1, "max": 1, "left": 50}]
	w.add_node("temperate", Vector3(1.5, 0, 0), one, 1, "Rock")
	w.add_node("home", Vector3(-1.5, 0, 0), one, 1, "Rock")
	w.add_node("bush", Vector3(0, 0, 1.5), [{"item": "fibre_stalk", "tool": "none", "min": 1, "max": 1, "left": 50}], 1, "Bush")
	w.nodes["temperate"]["attributes"]["climate"] = "temperate"  # W3-SRVACT stamps the island climate
	w.nodes["home"]["attributes"]["climate"] = "grassland"
	var st = load("res://scripts/server/character_store.gd").new(w, "", 5)
	st.apply("char.create", 1, {"name": "Gatherer"}, 1)
	var ch = st.character(1)
	var inv = ch.inventory()
	inv.add(IS.make(&"work_pick", 1, {"material_tier": "obsidian"}, 1))
	inv.add(IS.make(&"stone_knife_work", 1, {}, 1))
	ch.commit(inv, "test", 0)
	var start := _tool_durability(st)
	var flint_row: Dictionary = (LT.gather_cfg()["by_role"]["rock"] as Array).filter(func(r): return r is Dictionary and r.get("item") == "flint")[0]
	var res := {}
	_with(LT.trait_cfg(), "chance", 1.0, func() -> void:
		_with(LT.gather_cfg(), "max_chance", 1.0, func() -> void:
			_with(flint_row, "chance", 1.0, func() -> void:
				res["rock"] = st.apply("act.gather", 1, {"node_id": "temperate", "option": 0}, 2)
				res["dur"] = _tool_durability(st)
				res["home"] = st.apply("act.gather", 1, {"node_id": "home", "option": 0}, 3)
				res["bush"] = st.apply("act.gather", 1, {"node_id": "bush", "option": 0}, 4))))
	var rock: Dictionary = res["rock"].get("r", {})
	var after_rock: Dictionary = res["dur"]
	var after_bush := _tool_durability(st)
	ch = st.character(1)  # each committed op stores a fresh copy of the character
	inv = ch.inventory()
	var flint_uid := ""
	var traited_uids := 0
	for i in inv.slots.size():
		var it = inv.slots[i]
		if it and it.def_id == &"flint":
			flint_uid = ch.slot_uid(i)
		if it and it.def_id == &"stone" and LT.trait_cfg()["traits"].any(func(t): return it.attributes.get(str(t), false) == true) and ch.slot_uid(i) != "":
			traited_uids += it.count
	var minted: Dictionary = st.s["minted"]
	print("[t_gather] server act.gather: rock %s; tools start %s, after rock %s, after bush %s; flint uid '%s', minted flint %s; home rares %s" % [rock, start, after_rock, after_bush, flint_uid, minted.get("flint"), res["home"].get("r", {}).get("rares")])
	var stones := int(rock.get("gained", -1)) + int(res["home"].get("r", {}).get("gained", -1))
	_expect(bool(res["rock"].get("ok")) and (rock.get("traits", []) as Array).size() == int(rock.get("gained", -1)) and traited_uids == stones, "server: every gathered item takes the green trait (odds 1) and keeps a uid (%s; %d of %d stone traited with uids)" % [rock.get("traits"), traited_uids, stones])
	_expect(rock.get("rares") == ["flint"] and flint_uid != "" and int(minted.get("flint", 0)) == 1, "server: the flint find is minted with a uid, counted as minted and listed in r.rares (rares %s, uid '%s', minted %s)" % [rock.get("rares"), flint_uid, minted.get("flint")])
	_expect(int(after_rock["work_pick"]) == int(start["work_pick"]) - 1 and int(after_rock["stone_knife_work"]) == int(start["stone_knife_work"]), "server: the helper pick wears 1 on the rock, the knife not at all (%s -> %s)" % [start, after_rock])
	_expect(bool(res["home"].get("ok")) and (res["home"]["r"].get("rares", ["?"]) as Array).is_empty() and int(minted.get("flint", 0)) == 1, "server: a grassland rock yields no find (%s)" % [res["home"].get("r", res["home"])])
	_expect(int(after_bush["stone_knife_work"]) == int(after_rock["stone_knife_work"]) - 1, "server: the helper knife wears 1 on the bush (%s -> %s)" % [after_rock, after_bush])
	_finished += 1

## Durability of each tool in the server character's bag, by id.
func _tool_durability(st) -> Dictionary:
	var out := {}
	for it in st.character(1).inventory().slots:
		if it and it.def_id in [&"work_pick", &"stone_knife_work"]:
			out[str(it.def_id)] = it.durability
	return out

## The real HUD's _draw (hunt_hud.gd with the hooks hunk) at 844x390 with a survivor bound to it: a rare
## notice from a node the survivor has left is not drawn while a plain refusal is; with the gather radial
## open a rare notice keeps off its labels, title and hexes, the plates and the survivor with their ring
## (the radial's "Herb Leaf" label covered it); the same rare result twice is one "x2" notice.
func _test_hud_draw() -> void:
	current_scene = host
	var root := get_root()
	var keep := [root.size, root.content_scale_size]
	root.size = Vector2i(844, 390)
	root.content_scale_size = Vector2i(844, 390)
	var h = load("res://scripts/ui/hunt_hud.gd").new()
	host.add_child(h)
	h.remove_from_group("hud")  # GatherFeedback.notice keeps reaching the recording stand-in
	h.bind(player)
	var na = _planted("Bush", &"fibre_stalk", "grassland", &"none", Vector3(1.2, 0, 0))
	var nb = _planted("Bush", &"fibre_stalk", "grassland", &"none", Vector3(-3, 0, 0))
	player.gather_target = na
	h.notice("Rare find: Flint", GF.GOLD)
	player.gather_target = nb
	h.notice("Too far.")
	await _frames(3)
	var drawn := _drawn_notices(h)
	_expect(not drawn.has("Rare find: Flint") and drawn.has("Too far."), "the HUD skips a rare notice from a node the survivor left and draws a plain one (drawn %s)" % [drawn.keys()])
	player.gather_target = null
	await _frames(70)  # "Too far." fades out
	player._gather_radial.open(na, na.options(), player.inventory)
	await _frames(3)
	var text := "Rare trait: Low Vibration Fibre Stalk"
	h.notice(text, GF.GREEN)
	await _frames(3)
	drawn = _drawn_notices(h)
	var box: Rect2 = drawn.get(text, Rect2())
	var avoid := _must_avoid()
	var on: Array = avoid.filter(func(a: Rect2) -> bool: return a.intersects(box))
	# What the HUD alone would pick (its own blocks only): the set-up puts that on the radial or the survivor.
	var tw: float = h._font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 17).x
	var band: Rect2 = load("res://scripts/ui/hud_layout.gd").centre_band(h, Vector2(844, 390))
	var cx: float = band.get_center().x if band.has_area() else 422.0
	var old: Rect2 = load("res://scripts/ui/ui_tokens.gd").free_spot(Rect2(cx - tw * 0.5 - 12, 170.0, tw + 24, 30), h.taken_rects(PackedStringArray(["notice", "pill"])), Vector2(844, 390))
	var old_on: Array = avoid.filter(func(a: Rect2) -> bool: return a.intersects(old))
	print("[t_gather] HUD 844x390, radial open: rare notice %s, on %s; HUD-only spot %s on %s; radial labels %s title %s" % [box, on, old, old_on, player._gather_radial.label_rects, player._gather_radial.title_box])
	_expect(not player._gather_radial.label_rects.is_empty() and not old_on.is_empty(), "set-up: the radial is laid out and the HUD's own spot for the notice sits on it or the survivor (%s on %s)" % [old, old_on])
	_expect(box.has_area() and on.is_empty(), "with the radial open the rare notice is drawn clear of its labels, title, hexes, the plates and the survivor (%s on %s)" % [box, on])
	h.notice(text, GF.GREEN)
	var same: Array = h._events.notices.filter(func(n): return str(n.get("base", "")) == text)
	_expect(same.size() == 1 and str(same[0]["text"]) == text + "  x2", "the same rare result twice is one notice reading x2 (%s)" % [same.map(func(n): return n["text"])])
	player._gather_radial.close()
	# A rare notice whose spot falls on the survivor moves off them and the ring at their feet.
	var ring: Rect2 = GF.survivor_rect(player)
	var fresh := {"text": "r", "t": 1.0, "tint": GF.GREEN, "born": Time.get_ticks_msec()}
	var moved: Rect2 = GF.notice_box(fresh, player, Rect2(ring.get_center() - Vector2(150, 15), Vector2(300, 30)), [] as Array[Rect2], Vector2(844, 390))
	print("[t_gather] survivor and ring %s; a notice put on them moves to %s" % [ring, moved])
	_expect(ring.has_area() and moved.has_area() and not moved.intersects(ring), "a rare notice put on the survivor moves off them and their ring (%s vs %s)" % [moved, ring])
	# ...and off a creature plate (a "Pill" panel under Game.creature_ui; a notice ran into a pet's bar).
	var game := get_root().get_node("Game")
	var keep_plates = game.creature_ui
	var plates := CanvasLayer.new()
	var pill := Panel.new()
	pill.name = "Pill"
	pill.position = Vector2(560, 160)
	pill.size = Vector2(180, 40)
	plates.add_child(pill)
	host.add_child(plates)
	game.creature_ui = plates
	var plate := Rect2(pill.position, pill.size)
	var off_plate: Rect2 = GF.notice_box(fresh, player, Rect2(plate.position + Vector2(-60.0, 5.0), Vector2(300, 30)), [] as Array[Rect2], Vector2(844, 390))
	game.creature_ui = keep_plates
	plates.free()
	_expect(off_plate.has_area() and not off_plate.intersects(plate), "a rare notice put on a creature plate moves off it (%s vs %s)" % [off_plate, plate])
	# With no room in the centre column it goes to the screen's edge rather than waiting unseen.
	var column: Array[Rect2] = [Rect2(320, 0, 200, 390)]
	var edge: Rect2 = GF.notice_box(fresh, player, Rect2(272, 170, 300, 30), column, Vector2(844, 390))
	_expect(edge.has_area() and not edge.intersects(column[0]), "with the centre column full a rare notice goes to the edge (%s)" % edge)
	h.queue_free()
	na.free()
	nb.free()
	root.size = keep[0]
	root.content_scale_size = keep[1]
	await _frames(1)
	_finished += 1

## What a rare notice must keep off, listed here and not by GatherFeedback (a change there cannot hide
## itself): the open radial's labels, title and hexes, and the survivor with their ring.
func _must_avoid() -> Array[Rect2]:
	var gr = player._gather_radial
	var out: Array[Rect2] = []
	out.append_array(gr.label_rects)
	out.append(gr.title_box)
	for c in gr.get_children():
		if c is Control and c.visible:
			out.append(c.get_global_rect())
	out.append(GF.survivor_rect(player))
	return out

func _frames(n: int) -> void:
	for i in n:
		await process_frame

## Text -> drawn box of each notice the HUD drew last frame.
func _drawn_notices(h) -> Dictionary:
	var out := {}
	for k in h.drawn_blocks:
		if str(k).begins_with("notice"):
			var i := int(str(k).trim_prefix("notice"))
			if i < h._events.notices.size():
				out[str(h._events.notices[i]["text"])] = h.drawn_blocks[k]
	return out
