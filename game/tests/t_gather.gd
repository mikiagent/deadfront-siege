extends SceneTree
## W2-GATHER: role tools speed hand-pickable nodes, tier raises yields, rare finds roll their
## data odds (and only with the right tool), carcass parts scale with knife and skill, the XP
## sink contract. Then live, on a real survivor: after_unit reads the node's island climate and
## keeps to free slots, the corpse hook uses the survivor's knife and pays rare XP at the take,
## two finds announced in one frame both reach the screen, and the run quits with a sink set.
## Game classes load after the Data and World autoloads exist (first frame).

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
var BL: GDScript
var GF: GDScript
var CORPSE: GDScript
var host: Node3D
var player
var hud

func _process(_delta: float) -> bool:
	if _done:
		return false  # the live half awaits frames; it quits itself
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	GS = load("res://scripts/gather/gather_service.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	LT = load("res://scripts/gather/loot_tables.gd")
	GX = load("res://scripts/gather/gather_xp.gd")
	NODE = load("res://scenes/world/harvest_node.tscn")
	BL = load("res://scripts/gather/butcher_loot.gd")
	GF = load("res://scripts/gather/gather_feedback.gd")
	CORPSE = load("res://scripts/creatures/corpse.gd")
	_test_data_ids()
	_test_tools()
	_test_gather_rares()
	_test_carcass()
	_test_xp_sink()
	_run_live.call_deferred()
	return false

func _run_live() -> void:
	_build_world()
	_test_after_unit_climate()
	_test_full_bag()
	_test_butcher_hook()
	_test_rare_take_xp()
	await _test_two_finds_one_frame()
	# Quit with a sink still set (W2-SKILLS keeps one for the whole session): must exit 0, no abort.
	GX.set_sink(_recorder(true))
	_expect(_finished == 10, "all 10 test groups ran to the end (%d did)" % _finished)
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
				# world-design s4: a climate gives its own materials, so a find is one of them.
				for c in cl:
					var mats: Array = (data.world_climates.get(c, {}) as Dictionary).get("materials", [])
					_expect(mats.any(func(m): return m is Dictionary and str(m.get("id", "")) == str(row["item"])), "%s/%s is in %s's materials (climates.json)" % [k, row["item"], c])
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
	_expect(_rate("Bush", "bush", &"", &"berries", 20000, 5, "grassland") > 0.0, "the home grassland still has a find: berries on a bush")
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
	# Typo or hostile rows are skipped, not a SCRIPT ERROR that aborts the unit (and its popup):
	# with them in the table every seed rolls exactly what it rolled without them.
	var rock_rows: Array = LT.gather_cfg()["by_role"]["rock"]
	var kept := rock_rows.duplicate()
	var ref: Array = []
	for sd in 200:
		ref.append(LR.roll_gather_rares("Rock", "rock", "temperate", &"obsidian", 1, _seeded(sd)))
	rock_rows.push_front("oops")
	rock_rows.append({"item": "pearl", "chance": 1.0, "climates": "temperate"})  # a String, not a list
	var diff := 0
	for sd in 200:
		if LR.roll_gather_rares("Rock", "rock", "temperate", &"obsidian", 1, _seeded(sd)) != ref[sd]:
			diff += 1
	rock_rows.assign(kept)
	_expect(diff == 0 and ref.any(func(r): return not r.is_empty()), "bad rare rows are skipped and the good rows still roll (%d of 200 seeds differ)" % diff)
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

## A sink object that records award_gather_xp calls (a Node in the scene when in_tree).
func _recorder(in_tree: bool = false) -> Object:
	var gd := GDScript.new()
	gd.source_code = "extends %s\nvar got: Array = []\nfunc award_gather_xp(_pl, cat: String, amt: float, src: Dictionary) -> void:\n\tgot.append([cat, amt, src.get(\"verb\"), src.get(\"item\")])\n" % ("Node" if in_tree else "RefCounted")
	gd.reload()
	var o: Object = gd.new()
	if in_tree:
		host.add_child(o)
	return o

func _test_xp_sink() -> void:
	var rec = _recorder()
	GX.set_sink(rec)
	# A null player is refused before the sink (no XP for nobody).
	GX.award(null, "gathering", 5.0, {"verb": "gather"})
	_expect(rec.got.is_empty(), "no XP without a player")
	var fake := CharacterBody3D.new()
	fake.set_script(load("res://scripts/player/player.gd"))
	GX.award(fake, "gathering", 5.0, {"verb": "gather", "item": "flint", "rare": true, "node_level": 1})
	_expect(rec.got.size() == 1 and rec.got[0][0] == "gathering" and is_equal_approx(rec.got[0][1], 5.0) and rec.got[0][2] == "gather", "GatherXp routes to the W2-SKILLS sink when set (got %s)" % [rec.got])
	# Held weakly: a dropped sink is gone without a set_sink(null), and XP takes the default path.
	rec = null
	GX.award(fake, "gathering", 5.0, {"verb": "gather"})
	GX.set_sink(null)
	fake.free()
	_finished += 1

# --- live: a real survivor (player.tscn), a HUD stand-in that records toasts and notices ---------

func _build_world() -> void:
	host = Node3D.new()
	host.name = "TGather"
	get_root().add_child(host)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var gd := GDScript.new()
	gd.source_code = "extends Control\nvar notices: Array = []\nvar toasts: Array = []\nfunc notice(text: String, gold: bool = false) -> void:\n\tnotices.append([text, gold])\nfunc toast(id: StringName, n: int) -> void:\n\ttoasts.append([id, n])\n"
	gd.reload()
	hud = gd.new()
	hud.add_to_group("hud")
	host.add_child(hud)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)

func _clear_bag() -> void:
	for i in player.inventory.slot_count:
		player.inventory.slots[i] = null

## A rock as IslandScatter.plant_at makes one: in the scene, climate and level in its yield attributes.
func _rock(climate: String):
	var n = NODE.instantiate()
	host.add_child(n)
	n.setup(StringName("t_rock_" + climate), &"stone", 2, 4, {"climate": climate, "level": 1}, &"pick", Color.GRAY, 1.2, 8.0, "Rock")
	return n

func _gather_units(node, units: int) -> int:
	var landed := 0
	for i in units:
		landed += GS.after_unit(player, node, &"stone", 1).size()
	return landed

func _test_after_unit_climate() -> void:
	_clear_bag()
	player.inventory.add(IS.make(&"work_pick", 1, {"material_tier": "obsidian"}, 1))
	GS.rng.seed = 21
	var home = _rock("grassland")
	_gather_units(home, 800)
	var f_home: int = player.inventory.count_of(&"flint")
	var c_home: int = player.inventory.count_of(&"copper_ore")
	_expect(f_home == 0 and c_home == 0, "after_unit on a home-grassland rock (obsidian pick, 800 units) finds no flint (%d) or copper (%d)" % [f_home, c_home])
	var temperate = _rock("temperate")
	var got := _gather_units(temperate, 800)
	var f_temp: int = player.inventory.count_of(&"flint")
	print("[t_gather] after_unit 800 units: grassland rock flint %d copper %d; temperate rock flint %d" % [f_home, c_home, f_temp])
	_expect(f_temp > 0 and got == f_temp, "after_unit on a temperate rock finds flint (%d landed, %d in the bag)" % [got, f_temp])
	var i: int = player.inventory.find_first(&"flint")
	var st = player.inventory.slots[i] if i >= 0 else null
	_expect(st != null and str(st.attributes.get("climate", "")) == "temperate" and st.level == 1, "a find is stamped with the node's climate and level (%s)" % [st.attributes if st else {}])
	_expect(hud.notices.is_empty() or hud.notices.all(func(n): return n[1] == true), "every rare notice is gold")
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

## Rare part XP is paid when the part is taken, once, to the taker; not when the animal falls.
func _test_rare_take_xp() -> void:
	var data := get_root().get_node("Data")
	var unlocked: Array = []
	for id in data.survival_nodes:
		if str(data.survival_nodes[id].get("kind", "")) == "butchering" and not data.is_survival_unlocked(id):
			data.set_survival_unlocked(id, true)
			unlocked.append(id)
	var rec = _recorder()
	GX.set_sink(rec)
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
		_expect(rec.got.is_empty(), "no rare XP when the animal falls (got %s)" % [rec.got])
		_expect(hud.notices.any(func(n): return str(n[0]).contains("Raptor Talon") and n[1]), "the talon is announced in gold")
		var before: int = c.loot.count_of(&"raw_hide")
		BL.on_take(c, player)
		_expect(rec.got.is_empty(), "taking nothing rare pays no rare XP")
		c.loot.remove_at(c.loot.find_first(&"raptor_talon"), 1)
		BL.on_take(c, player)
		BL.on_take(c, player)
		_expect(rec.got.size() == 1 and rec.got[0][0] == "butchering" and rec.got[0][3] == "raptor_talon", "the talon pays its XP once, at the take (got %s)" % [rec.got])
		_expect(c.loot.count_of(&"raw_hide") == before, "on_take moves no loot")
		c.free()
	GX.set_sink(null)
	for id in unlocked:
		data.set_survival_unlocked(id, false)
	_finished += 1

## Two finds announced in the same frame (a unit landing as a pet kills a raptor): both reach the
## screen, as a gold stack or a gold notice. The old shared callable failed to connect and lost both.
func _test_two_finds_one_frame() -> void:
	hud.notices.clear()
	_clear_bag()
	current_scene = host  # GatherFeedback draws its stacks under the current scene (none before: no popups)
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
		if n[1]:
			shown.append(n[0])
	print("[t_gather] two finds in one frame: %s" % [shown])
	for nm in ["Pearl", "Raptor Talon"]:
		_expect(shown.any(func(t): return str(t).contains(nm)), "%s announced (stack or gold notice) when two finds share a frame" % nm)
	# A drawn stack cut short (replaced within SHOWN_MS) hands its find to the gold notice.
	hud.notices.clear()
	var first = GF.popup(player, Vector3(-1, 1, 0), [["RARE  Resin", GF.GOLD, true]], func() -> void: hud.notice("Rare find: Resin", true))
	for i in 2:
		await process_frame
	var drawn: bool = is_instance_valid(first) and first.visible
	GF.announce_rares(player, Vector3(1, 1, 0), [&"flint"] as Array[StringName])
	_expect(drawn and hud.notices.any(func(n): return str(n[0]).contains("Resin") and n[1]), "a rare stack replaced before it was read is announced by the gold notice (drawn %s, notices %s)" % [drawn, hud.notices])
	_finished += 1
