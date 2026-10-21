extends SceneTree
## W2-SKILLS checks: trees.json is a valid node graph on Durango's 1-60 scale, a new survivor's
## trees start at Lv. 1 with the Lv1 AUTO nodes learned, a tree cannot pass the character level,
## Animal Handling I-IV raise bonded capacity 3 -> 7, skill nodes gate recipes and abilities,
## refunds respect dependents and the daily limit, rev-1 saves migrate keeping every node but no more SP than
## the character level pays, the
## taming pen and the field tame refuse a bond at the cap without losing the animal or the food, the
## skills sheet opens a tree on rows the player can act on, the level-up banner shows the SP SkillState
## holds, and the craft card says what unlocks a gated recipe.
## Usage: godot --headless --path game --script res://tests/t_w2_skills.gd

const WIRED := ["recipe", "ability", "bonded_slots", "capture_tier", "climate"]
const STATUSES := ["functional", "partial", "defined"]

var failures: Array[String] = []
var _done := false
var _sections := 0
var SkillStateS: GDScript
var Rules: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_done = true
	SkillStateS = load("res://scripts/skills/skill_state.gd")
	Rules = load("res://scripts/skills/skill_rules.gd")
	_test_catalog()
	_test_new_survivor()
	_test_level_cap()
	_test_animal_handling()
	_test_recipe_gates_and_abilities()
	_test_migration()
	_test_occupation()
	_test_sp_from_character_level()
	_test_sanitizer_budget()
	_test_pen_cap()
	_test_refund_limit()
	_test_field_tame_cap()
	_test_sheet_rows()
	_test_levelup_banner()
	_test_craft_card_lock()
	var want := 15
	if _sections != want:
		failures.append("only %d of %d test sections completed (a runtime error aborted the rest)" % [_sections, want])
	if failures.is_empty():
		print("[t_w2_skills] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_w2_skills] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _world() -> Node:
	return get_root().get_node("World")

## A fresh SkillState at character level `stored + 1` (World.pioneer_level is stored from 0).
func _fresh(stored_pioneer: int = 0) -> Node:
	_world().pioneer_level = stored_pioneer
	_world().pioneer_xp = 0
	var sk: Node = SkillStateS.new()
	get_root().add_child(sk)
	return sk

func _done_with(sk: Node) -> void:
	get_root().remove_child(sk)
	sk.free()
	_world().pioneer_level = 0
	_world().pioneer_xp = 0

## Stands in for the HUD Player.notice writes to; `said` holds every notice.
func _hud_stub() -> Node:
	var hud_src := GDScript.new()
	hud_src.source_code = "extends Node\nvar said: Array = []\nfunc notice(text: String) -> void:\n\tsaid.append(text)\n"
	hud_src.reload()
	var hud: Node = hud_src.new()
	hud.add_to_group("hud")
	get_root().add_child(hud)
	return hud

func _player() -> Node:
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(p)
	return p

func _node(sk: Node, tree: String, id: String) -> Dictionary:
	for n in sk.nodes(tree):
		if str(n.get("id", "")) == id:
			return n
	return {}

## Give `sk` a tree level (SP come from the character level `_fresh` set, not from this).
func _grant(sk: Node, tree: String, level: int) -> void:
	sk.trees[tree]["level"] = level
	sk._learn_autos(tree)
	sk._recount_sp()

func _test_catalog() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/trees.json"))
	var recipes := {}
	for r in (JSON.parse_string(FileAccess.get_file_as_string("res://data/recipes.json")) as Dictionary).get("recipes", []):
		recipes[str(r.get("id", ""))] = true
	var count := 0
	var sp_total := 0
	var by_status := {"functional": 0, "partial": 0, "defined": 0}
	# A node a loaded recipe names in requires_node (W2-DATA) gates real recipes: trees.json must say
	# functional, so the data's report is accurate (spec 12:207, 12:215).
	var gating: Dictionary = Rules.recipe_nodes()
	var ids := {}
	for tree in SkillStateS.ORDER:
		var seen := {}
		for n in (root["trees"][tree] as Dictionary)["nodes"]:
			count += 1
			var id := str(n.get("id", ""))
			_expect(not seen.has(id), "%s: duplicate node id %s" % [tree, id])
			var req: Variant = n.get("requires", null)
			# Requires-before-dependent in file order also rules out cycles (save_sanitizer walks in this order).
			_expect(req == null or seen.has(str(req)), "%s/%s: prerequisite %s missing or listed after it" % [tree, id, req])
			seen[id] = true
			ids[id] = true
			var lv := int(n.get("level", 0))
			_expect(lv >= 1 and lv <= 60, "%s/%s: level %d outside 1-60" % [tree, id, lv])
			_expect(int(n.get("sp", -1)) >= 0 and (not bool(n.get("auto", false)) or int(n.get("sp", 0)) == 0), "%s/%s: SP must be >= 0, and 0 for auto nodes" % [tree, id])
			var st := str(n.get("status", ""))
			_expect(STATUSES.has(st), "%s/%s: status '%s'" % [tree, id, st])
			_expect(st == "functional" or not gating.has(id), "%s/%s gates recipes through requires_node, so it must be functional (it is '%s')" % [tree, id, st])
			by_status[st] = int(by_status.get(st, 0)) + 1
			sp_total += int(n.get("sp", 0))
			var wired := gating.has(id)
			for e in n.get("effects", []):
				var kind := str(e.get("type", ""))
				wired = wired or WIRED.has(kind)
				if kind == "recipe":
					# SP buy only functional nodes, so a gate on anything else would lock its recipe for good.
					_expect(st == "functional", "%s/%s gates a recipe, so it must be functional (it is '%s')" % [tree, id, st])
					for rid in e.get("recipes", []):
						_expect(recipes.has(str(rid)), "%s/%s gates unknown recipe %s" % [tree, id, rid])
			_expect(st != "functional" or wired, "%s/%s is 'functional' with no effect the game reads" % [tree, id])
	var ref: Dictionary = root["reference"]
	var total := 0
	for c in ref["categories"]:
		total += int(ref["categories"][c][0])
	_expect(total == 918 and int(ref["total_nodes"]) == 918, "reference counts sum to 918 (got %d)" % total)
	_expect(int(root["_totals"]["all_trees_sp"]) == sp_total and str(root["_totals"]["note"]).contains(str(sp_total)), "_totals says what the trees cost (%d, it says %s)" % [sp_total, root["_totals"]])
	# Spec 12:35 "Boulder appears early" was missed once: every spec node name is in the catalog.
	for must in ["animal_management_1", "animal_management_4", "handicraft_5", "metalworking_4", "roll_duration_1", "barrage", "boulder"]:
		_expect(ids.has(must), "catalog has %s" % must)
	# One list mixes Durango and PRD names, so all read in Title Case ("Split Wood", not "Split wood").
	var lower: Array = []
	for tree in SkillStateS.ORDER:
		for n in (root["trees"][tree] as Dictionary)["nodes"]:
			for w in str(n.get("name", "")).split(" ", false):
				if w.left(1) != w.left(1).to_upper():
					lower.append(str(n.get("name", "")))
	_expect(lower.is_empty(), "every node name is in Title Case (not: %s)" % [lower.slice(0, 6)])
	print("[t_w2_skills] catalog %d of 918 nodes: functional %d (%d of them through requires_node), partial %d, defined %d" % [count, by_status.functional, gating.size(), by_status.partial, by_status.defined])
	_sections += 1

func _test_new_survivor() -> void:
	var sk := _fresh()
	var lowest := 99
	for tree in SkillStateS.ORDER:
		lowest = mini(lowest, sk.level_of(tree))
	_expect(lowest == 1, "every tree of a new survivor is Lv. 1 (lowest %d)" % lowest)
	for pair in [["processing", "cordage"], ["weapon_tools", "improvised_tools"], ["gathering", "forage_1"], ["defense", "roll"], ["tailoring", "leaf_outfit"], ["farming", "corn"]]:
		_expect(sk.is_unlocked(pair[0], pair[1]), "Lv1 AUTO %s/%s is learned at creation" % pair)
	_expect(not sk.is_unlocked("farming", "small_field"), "Till Small Field (Lv1, 1 SP) is a purchase, not auto")
	_expect(sk.sp_available == 0 and sk.sp_spent == 0 and sk.sp_earned == 0, "a new survivor has 0 SP and auto nodes cost nothing (avail %d spent %d)" % [sk.sp_available, sk.sp_spent])
	_expect(sk.character_level() == 1, "character level of a new survivor is 1 (got %d)" % sk.character_level())
	var field: String = Rules.recipe_block(sk, "field_small")
	_expect(field.contains("Till Small Field") and field.contains("you have 0 SP, reach Lv. 2 for +10 SP"), "a Lv. 1 survivor's field kit lock says where the SP come from: '%s'" % field)
	_expect(not sk.refund("processing", "cordage") and sk.is_unlocked("processing", "cordage"), "an auto node cannot be refunded")
	_done_with(sk)
	_sections += 1

func _test_level_cap() -> void:
	var sk := _fresh()
	sk.add_xp("melee", 200.0, true) # mirrored: no World XP, so the character stays Lv. 1
	_expect(sk.level_of("melee") == 1, "melee cannot pass character Lv. 1 (got %d)" % sk.level_of("melee"))
	# Spec 03:7 "even when the player has lots of category XP": XP at the cap is kept, not dropped
	# (W2-DATA's t_build checks that a build still pays construction XP after earlier builds filled the bar).
	_expect(is_equal_approx(sk.xp_of("melee"), 200.0), "XP at the cap is banked, not dropped (xp %.0f of 200)" % sk.xp_of("melee"))
	_expect(sk.sp_earned == 0, "no SP while the character is Lv. 1")
	_world().pioneer_level = 4 # character Lv. 5
	_world().pioneer_changed.emit(4)
	# Survival trained alongside (every gain also trains Survival), so it banked too. 200 XP pays
	# levels 2-5 (28 + 36 + 44 + 52 = 160) and 40 stay banked at the new cap.
	_expect(sk.level_of("melee") == 5 and sk.level_of("survival") == 5 and is_equal_approx(sk.xp_of("melee"), 40.0), "a character level-up spends the banked XP (melee %d, survival %d, %.0f XP left)" % [sk.level_of("melee"), sk.level_of("survival"), sk.xp_of("melee")])
	_expect(sk.sp_earned == Rules.paid_for_level(sk, 5) and sk.sp_available == sk.sp_earned, "character Lv. 5 pays levels 2-5 (%d SP), the released tree levels pay nothing" % sk.sp_earned)
	sk.add_xp("melee", 99999.0, true)
	_expect(sk.level_of("melee") == 5, "melee stays at the character level 5 (got %d)" % sk.level_of("melee"))
	_expect(is_equal_approx(sk.xp_of("melee"), SkillStateS.xp_to_max(5)), "the bank holds what melee can still use up to Lv. 60, no more (%.0f, want %.0f)" % [sk.xp_of("melee"), SkillStateS.xp_to_max(5)])
	_done_with(sk)
	# Pacing probe (an open owner decision, so nothing is asserted): gathers at 2 XP each (player_actions)
	# to reach Survival 10 (first sail route, World.route_level) and 15 (next route, Capture Technique I).
	# Before: trees from Lv. 0, no cap. Now: from Lv. 1, and the tree waits for the character level.
	for target in [10, 15]:
		var before := 0.0
		for l in target:
			before += SkillStateS.xp_to_next(l)
		var tree_xp := 0.0
		for l in range(1, target):
			tree_xp += SkillStateS.xp_to_next(l)
		var char_xp := 0
		for l in target - 1:
			char_xp += _world().xp_for_level(l)
		print("[t_w2_skills] pacing: Survival %d took %d gathers before the cap, now %d (character Lv. %d needs %d XP)" % [target, ceili(before / 2.0), ceili(maxf(tree_xp, float(char_xp)) / 2.0), target, char_xp])
	_sections += 1

func _test_animal_handling() -> void:
	var sk := _fresh(59)
	_grant(sk, "survival", 34)
	var want := [[35, 4], [45, 5], [55, 5], [60, 6]]
	for i in 4:
		var n := _node(sk, "survival", "animal_management_%d" % (i + 1))
		_expect(str(n.get("name", "")) == "Animal Handling %s" % ["I", "II", "III", "IV"][i] and int(n.get("level", 0)) == want[i][0] and int(n.get("sp", 0)) == want[i][1], "Animal Handling %d is Survival %d / %d SP (got %s)" % [i + 1, want[i][0], want[i][1], n])
	for pre in ["island_access_15", "belly_fat_1", "capture_technique_1"]:
		_expect(sk.unlock("survival", pre), "buy %s on the way to Animal Taming" % pre)
	_expect(Rules.bonded_capacity(sk) == 3, "base bonded capacity 3")
	_expect(not sk.unlock("survival", "animal_management_1"), "Animal Handling I is locked at Survival 34")
	_expect(not sk.unlock("survival", "animal_management_2"), "Animal Handling II needs I")
	_grant(sk, "survival", 60)
	var caps: Array = []
	for i in 4:
		_expect(sk.unlock("survival", "animal_management_%d" % (i + 1)), "buy Animal Handling %d" % (i + 1))
		caps.append(Rules.bonded_capacity(sk))
	_expect(caps == [4, 5, 6, 7], "capacity 4, 5, 6, 7 (got %s)" % [caps])
	_expect(not sk.refund("survival", "animal_management_1"), "Animal Handling I stays while II needs it")
	for i in [4, 3, 2, 1]:
		sk.refund("survival", "animal_management_%d" % i)
	_expect(Rules.bonded_capacity(sk) == 3, "after the reset: capacity 3 (kept pets stay; a new bond needs count < 3)")
	_expect(not get_root().get_node("Data").is_survival_unlocked(&"animal_management_I"), "refund clears the Data mirror")
	sk.refund("survival", "capture_technique_1")
	_expect(not get_root().get_node("Data").has_capture_technique(1), "refunding Capture Technique I removes net capture tier 1")
	_done_with(sk)
	_sections += 1

func _test_recipe_gates_and_abilities() -> void:
	var sk := _fresh(59)
	_expect(Rules.recipe_block(sk, "rope") == "" and Rules.recipe_block(sk, "improvised_stone_knife") == "", "auto nodes leave rope and the stone knife open")
	# Every craft row and sheet row asks these: the map is built once per SkillState, not per call.
	var gates: Dictionary = Rules.recipe_gates(sk)
	_expect(is_same(gates, Rules.recipe_gates(sk)), "the recipe gate map is built once, not on every recipe_block / buyable call")
	_expect(Rules.recipe_block(sk, "workbench_kit") == "", "a recipe no node gates stays open")
	var block: String = Rules.recipe_block(sk, "charcoal")
	_expect(block.contains("Charcoal") and block.contains("10"), "charcoal is locked behind Charcoal (Processing Lv. 10): '%s'" % block)
	_expect(Rules.recipe_block(sk, "field_small").contains("Till Small Field"), "small field needs Till Small Field")
	_expect(not sk.unlock("processing", "charcoal"), "Charcoal cannot be bought at Processing 1")
	_grant(sk, "processing", 25)
	_expect(sk.unlock("processing", "charcoal") and Rules.recipe_block(sk, "charcoal") == "", "learning Charcoal opens the charcoal recipe")
	_expect(is_same(gates, Rules.recipe_gates(sk)), "learning a node keeps the gate map (it does not depend on what is learned)")
	_expect(sk.refund("processing", "charcoal") and Rules.recipe_block(sk, "charcoal") != "", "refunding Charcoal locks it again")
	_expect(Rules.ability(sk, "handicraft") == 0, "Handicraft Ability 0 before Handicraft I")
	# Handicraft is partial (no system reads it until W2-PROCESS): not for sale, so set it as a save would.
	_expect(not sk.unlock("processing", "handicraft_1") and sk.node_state("processing", _node(sk, "processing", "handicraft_1"))[1] == "not in the game yet", "a partial node cannot be bought: Handicraft I says 'not in the game yet'")
	_expect(not sk.unlock("survival", "obsidian") and sk.node_state("survival", _node(sk, "survival", "obsidian"))[1] == "not in the game yet", "a defined node no functional node needs cannot be bought (Obsidian)")
	_expect(Rules.buyable(sk, "survival", "island_access_15") and Rules.buyable(sk, "survival", "belly_fat_1"), "defined prerequisites of Capture Technique I stay buyable")
	# W2-DATA gates recipes with requires_node (crafting.gd progression_block). A node a recipe
	# names must be buyable, prerequisites included, or that recipe is locked for good.
	var data: Node = get_root().get_node("Data")
	if not Rules.recipe_nodes().has("work_pick"): # W2-DATA's recipes gate it once they land
		_expect(not Rules.buyable(sk, "weapon_tools", "work_pick"), "Work Pick (defined) is not for sale while no recipe needs it")
	data.recipes[&"t_w2_probe"] = {"id": "t_w2_probe", "requires_node": "work_pick"}
	_expect(Rules.buyable(sk, "weapon_tools", "work_pick") and Rules.buyable(sk, "weapon_tools", "improvised_tools"), "a defined node a recipe names in requires_node is buyable with its prerequisite (work_pick)")
	var pick_lock: String = Rules.recipe_block(sk, "t_w2_probe")
	_expect(pick_lock.begins_with("learn Work Pick (Weapon / Tools Lv. 5, 6 SP)"), "a requires_node recipe reads like every skill gate (spec 12:197): '%s'" % pick_lock)
	data.recipes.erase(&"t_w2_probe")
	var tree_of := {}
	for t in SkillStateS.ORDER:
		for n in sk.nodes(t):
			tree_of[str(n.get("id", ""))] = t
	var gated := 0
	for rid in data.recipes:
		var need := str((data.recipes[rid] as Dictionary).get("requires_node", ""))
		if need != "":
			gated += 1
			_expect(tree_of.has(need) and Rules.buyable(sk, str(tree_of.get(need, "")), need), "recipe %s requires_node %s: a trees.json node SP can buy" % [rid, need])
	print("[t_w2_skills] recipes gated by requires_node: %d" % gated)
	(sk.trees["processing"]["unlocked"] as Array).append_array(["handicraft_1", "handicraft_2"])
	_expect(Rules.ability(sk, "handicraft") == 8 and Rules.ability(sk, "metal_processing") == 0, "Handicraft I + II = +8 Handicraft, no Metal Processing (got %d)" % Rules.ability(sk, "handicraft"))
	_done_with(sk)
	_sections += 1

func _test_migration() -> void:
	var sk := _fresh(39) # character Lv. 40
	var old_spent := 5 + 6 + 8 + 34 # island_access_15, belly_fat_1, capture_technique_1, animal_management_1 at rev-1 prices
	var rev1 := {"occupation": "", "sp_available": 7, "sp_spent": old_spent, "trees": {
		"butchering": {"level": 0, "xp": 15.0, "unlocked": []},
		"survival": {"level": 40, "xp": 0.0, "unlocked": ["island_access_15", "belly_fat_1", "capture_technique_1", "animal_management_1"]}}}
	sk.from_dict(rev1)
	var paid: int = Rules.paid_for_level(sk, 40)
	_expect(sk.level_of("butchering") == 1 and is_equal_approx(sk.xp_of("butchering"), 15.0), "a rev-1 tree at 0 loads as Lv. 1 with its XP")
	_expect(sk.level_of("gathering") == 1, "a tree missing from a rev-1 save loads as Lv. 1")
	_expect(sk.sp_earned == paid and sk.sp_spent == 5 + 6 + 8 + 4 and sk.sp_available == paid - 23, "rev-1 SP from character Lv. 40: earned %d (want %d), spent %d at today's prices, available %d" % [sk.sp_earned, paid, sk.sp_spent, sk.sp_available])
	_expect(sk.is_unlocked("processing", "cordage"), "auto nodes are learned on load")
	var d: Dictionary = sk.to_dict()
	_expect(int(d.get("rev", 0)) == 2 and int(d["trees"]["butchering"]["level"]) == 1, "saves are rev 2 with Lv. 1 floors")
	var copy: Node = SkillStateS.new()
	get_root().add_child(copy)
	copy.from_dict(JSON.parse_string(JSON.stringify(d)))
	var again := JSON.stringify(JSON.parse_string(JSON.stringify(copy.to_dict())))
	var first := JSON.stringify(JSON.parse_string(JSON.stringify(d)))
	_expect(again == first, "rev 2 round-trips unchanged:\n%s\n%s" % [again, first])
	d["sp_earned"] = 99999
	copy.from_dict(d)
	_expect(copy.sp_earned == paid and copy.sp_available == paid - 23, "a forged sp_earned is ignored: SP follow the character level (%d)" % copy.sp_earned)
	get_root().remove_child(copy)
	copy.free()
	_done_with(sk)
	# A rev-1 mid-game save (character Lv. 23, 848 SP unspent under the old per-tree award) could buy
	# every node in the game. It now holds what a new Lv. 23 holds beyond the nodes it keeps, says so
	# once on screen, and at Lv. 60 cannot afford every node (spec 03:14, PRD 7.3).
	_world().pioneer_level = 22
	var p := _player()
	var hud := _hud_stub()
	var levels := {}
	for tree in SkillStateS.ORDER:
		levels[tree] = {"level": 23, "xp": 0.0, "unlocked": []}
	levels["survival"]["unlocked"] = ["island_access_15", "belly_fat_1", "capture_technique_1", "stealth_1"]
	p.skills.from_dict({"sp_available": 848, "sp_spent": 277, "trees": levels})
	var mid: Node = p.skills
	var p23: int = Rules.paid_for_level(mid, 23)
	_expect(mid.sp_spent > 0 and mid.sp_earned == maxi(p23, mid.sp_spent) and mid.sp_available == maxi(0, p23 - mid.sp_spent), "a migrated Lv. 23 drops its 848 unspent SP: earned %d, available %d (a new Lv. 23 earns %d, these nodes cost %d)" % [mid.sp_earned, mid.sp_available, p23, mid.sp_spent])
	_expect(hud.said.size() == 1 and str(hud.said[0]).begins_with("Skill points now come from your character level") and str(hud.said[0]).contains("%d SP to spend" % mid.sp_available), "the first load says once that SP were recomputed: %s" % [hud.said])
	mid.from_dict(mid.to_dict())
	_expect(hud.said.size() == 1, "a rev-2 load shows no migration notice (%d notices)" % hud.said.size())
	_world().pioneer_level = 59
	_world().pioneer_changed.emit(59)
	var buyable_sp := 0
	for tree in SkillStateS.ORDER:
		for n in mid.nodes(tree):
			if not bool(n.get("auto", false)) and Rules.buyable(mid, tree, str(n.get("id", ""))):
				buyable_sp += int(n.get("sp", 0))
	_expect(mid.sp_earned == Rules.paid_for_level(mid, 60) and mid.sp_earned < buyable_sp, "at Lv. 60 it has earned %d SP like any Lv. 60 and cannot buy all %d SP of nodes" % [mid.sp_earned, buyable_sp])
	print("[t_w2_skills] migrated Lv. 23: earned %d, available %d; at Lv. 60 earned %d of %d SP of buyable nodes" % [maxi(p23, mid.sp_spent), maxi(0, p23 - mid.sp_spent), mid.sp_earned, buyable_sp])
	for n in [hud, p]:
		get_root().remove_child(n)
		n.free()
	_world().pioneer_level = 0
	_sections += 1

func _test_occupation() -> void:
	var sk := _fresh()
	sk.apply_occupation("student")
	_expect(sk.level_of("gathering") == 20 and sk.level_cap("gathering") == 20 and sk.level_cap("melee") == 1, "the occupation's Lv. 20 holds at character Lv. 1; other trees cap at 1")
	_expect(sk.sp_earned == 0 and sk.sp_available == 0, "the head start grants levels, not SP (%d SP at character Lv. 1)" % sk.sp_earned)
	_expect(sk.is_unlocked("gathering", "branch"), "the head start learns Gathering's auto nodes")
	_done_with(sk)
	_sections += 1

## Spec 03: SP come from character levels. The old per-tree award paid every tree level-up (12 trees
## x ~13 SP), so tree XP alone must pay nothing and a character level-up alone must pay its SP.
func _test_sp_from_character_level() -> void:
	var sk := _fresh(9) # character Lv. 10
	var at10: int = sk.sp_earned
	_expect(at10 == Rules.paid_for_level(sk, 10) and at10 == 9 * sk.sp_for_level(2), "character Lv. 10 has earned levels 2-10 (%d SP)" % at10)
	for tree in ["melee", "gathering", "cooking"]:
		sk.add_xp(tree, 5000.0, true)
	_expect(sk.level_of("melee") == 10 and sk.level_of("cooking") == 10 and sk.sp_earned == at10 and sk.sp_available == at10, "three trees at Lv. 10 pay no SP of their own (earned %d, want %d)" % [sk.sp_earned, at10])
	_world().pioneer_level = 19
	_world().pioneer_changed.emit(19)
	_expect(sk.sp_earned == Rules.paid_for_level(sk, 20) and sk.sp_available == sk.sp_earned, "character Lv. 20 pays its SP with no tree XP (%d)" % sk.sp_earned)
	_done_with(sk)
	# A rev-1 save that bought more than its character level now pays for keeps every node but not its
	# 50 unspent SP (spec 03:14 "cannot afford all nodes simultaneously"): sp_extra is the 23 SP of
	# nodes Lv. 1 has not paid for, and the next levels pay that off before they add SP.
	var over := _fresh(0)
	over.from_dict({"sp_available": 50, "sp_spent": 0, "trees": {"survival": {"level": 40, "xp": 0.0, "unlocked": ["island_access_15", "belly_fat_1", "capture_technique_1", "animal_management_1"]}}})
	_expect((over.trees["survival"]["unlocked"] as Array).size() == 4 and over.sp_spent == 23 and over.sp_available == 0 and over.sp_extra == 23, "an over-budget migrated save keeps its 4 nodes, drops its 50 unspent SP (spent %d, available %d, extra %d)" % [over.sp_spent, over.sp_available, over.sp_extra])
	var saved: Dictionary = over.to_dict()
	over.from_dict(saved)
	_expect(over.sp_available == 0 and over.sp_extra == 23, "the cover survives a rev-2 save and load (available %d, extra %d)" % [over.sp_available, over.sp_extra])
	_world().pioneer_level = 1 # character Lv. 2 pays 10: 13 still owed
	_world().pioneer_changed.emit(1)
	_expect(over.sp_available == 0 and over.sp_extra == 13, "Lv. 2's 10 SP pay off the kept nodes first (available %d, extra %d)" % [over.sp_available, over.sp_extra])
	_world().pioneer_level = 3 # character Lv. 4 pays 30: 7 to spend, like a new Lv. 4 that bought the same
	_world().pioneer_changed.emit(3)
	_expect(over.sp_available == 7 and over.sp_extra == 0 and over.sp_earned == Rules.paid_for_level(over, 4), "Lv. 4 pays the nodes off and leaves 7 SP (available %d, extra %d, earned %d)" % [over.sp_available, over.sp_extra, over.sp_earned])
	_expect(get_root().get_node("Data").has_capture_technique(1), "the kept Capture Technique I still works")
	_done_with(over)
	_sections += 1

## docs/design/skills.md:9 "5 free unlearns a day" (trees.json refund; no Warp Gems yet): the next
## refund that day is refused with a reason and keeps the node; the count survives a save and load,
## a save without the optional fields starts at 0, and a new day gives the free refunds back.
func _test_refund_limit() -> void:
	var sk := _fresh(59)
	_grant(sk, "processing", 25)
	var free := int((sk.config["refund"] as Dictionary)["free_per_day"])
	for i in free:
		_expect(sk.unlock("processing", "charcoal") and sk.refund("processing", "charcoal"), "free refund %d of %d" % [i + 1, free])
	_expect(sk.unlock("processing", "charcoal"), "Charcoal can be bought again after the refunds")
	_expect(not sk.refund("processing", "charcoal") and sk.is_unlocked("processing", "charcoal") and sk.refund_reason("processing", "charcoal").contains("%d free refunds" % free), "refund %d of the day is refused with a reason and keeps the node: '%s'" % [free + 1, sk.refund_reason("processing", "charcoal")])
	var copy: Node = SkillStateS.new()
	get_root().add_child(copy)
	copy.from_dict(JSON.parse_string(JSON.stringify(sk.to_dict())))
	_expect(not copy.refund("processing", "charcoal") and copy.is_unlocked("processing", "charcoal"), "the day's refund count survives a save and load")
	copy.refund_day -= 1
	_expect(copy.refund("processing", "charcoal") and copy.refunds_today == 1, "a new day gives the free refunds back")
	var older: Dictionary = sk.to_dict()
	older.erase("refund_day")
	older.erase("refunds_today")
	copy.from_dict(older)
	_expect(copy.refunds_today == 0 and copy.refund("processing", "charcoal"), "a save without the optional refund fields loads with none used")
	# refund_block() only asks (a sheet may call it to grey a button): a new day reads as free
	# without the counter being reset; refund() does the roll-over.
	copy.refund_day = 0
	copy.refunds_today = free
	_expect(copy.refund_block() == "" and copy.refund_day == 0 and copy.refunds_today == free, "refund_block() is a query: it leaves the day's counter alone (day %d, used %d)" % [copy.refund_day, copy.refunds_today])
	get_root().remove_child(copy)
	copy.free()
	_done_with(sk)
	# SP stay derived after unlock and refund (no hand-kept sum): refunding a node a migrated save
	# holds over budget gives back no SP the character level never paid.
	var over := _fresh(0)
	_grant(over, "processing", 25)
	(over.trees["processing"]["unlocked"] as Array).append("charcoal")
	over._recount_sp()
	_expect(over.refund("processing", "charcoal") and over.sp_available == 0 and over.sp_spent == 0, "refunding an over-budget node gives back no SP the character level never paid (available %d)" % over.sp_available)
	_done_with(over)
	_sections += 1

## Hook H6 (save_sanitizer._skills): node budget by character level, sp_extra capped at what the kept
## nodes cost beyond that level's SP.
func _test_sanitizer_budget() -> void:
	var San: GDScript = load("res://scripts/core/save_sanitizer.gd")
	var bought := ["island_access_15", "belly_fat_1", "capture_technique_1", "animal_management_1"] # 23 SP
	var poor := {"rev": 2, "trees": {"survival": {"level": 40, "xp": 0, "unlocked": bought.duplicate()}}}
	San._skills(poor, 0) # character Lv. 1 paid 0 SP
	_expect((poor["trees"]["survival"]["unlocked"] as Array).is_empty() and int(poor["sp_spent"]) == 0, "H6: a rev-2 save at character Lv. 1 cannot hold 23 SP of nodes (kept %s)" % [poor["trees"]["survival"]["unlocked"]])
	var rich := {"rev": 2, "sp_available": 99999, "trees": {"survival": {"level": 40, "xp": 0, "unlocked": bought.duplicate()}}}
	San._skills(rich, 39) # character Lv. 40
	var paid := 0
	for l in range(2, 41):
		paid += 10 if l <= 20 else 12
	_expect((rich["trees"]["survival"]["unlocked"] as Array).size() == 4 and int(rich["sp_available"]) == paid - 23, "H6: character Lv. 40 keeps the 4 nodes and clamps SP to %d (got %s)" % [paid - 23, rich["sp_available"]])
	var legacy := {"sp_available": 50, "trees": {"survival": {"level": 40, "xp": 0, "unlocked": bought.duplicate()}}}
	San._skills(legacy, 0)
	_expect((legacy["trees"]["survival"]["unlocked"] as Array).size() == 4 and int(legacy["sp_available"]) == 0 and int(legacy["sp_extra"]) == 23, "H6: a rev-1 save keeps every node it bought under the old award, not its 50 unspent SP (available %s, extra %s)" % [legacy["sp_available"], legacy["sp_extra"]])
	# sp_extra is capped at what the kept nodes cost beyond the character level's SP (the review's (b)).
	for lv in [[0, 23], [39, 0]]:
		var forged := {"rev": 2, "sp_extra": 99999, "trees": {"survival": {"level": 40, "xp": 0, "unlocked": bought.duplicate()}}}
		San._skills(forged, lv[0])
		_expect(int(forged["sp_extra"]) == lv[1] and (forged["trees"]["survival"]["unlocked"] as Array).size() == 4, "H6: at character Lv. %d a rev-2 sp_extra of 99999 is cut to the 23 SP of nodes beyond the level's SP (%d, got %s)" % [lv[0] + 1, lv[1], forged["sp_extra"]])
	# The cap never trims a real save: a migrated save that levelled past its nodes keeps its new SP
	# through save, sanitize and load (a fixed sp_extra checked against the new level would lose them).
	var moved := _fresh(0)
	moved.from_dict(legacy.duplicate(true))
	_world().pioneer_level = 3 # Lv. 4 pays 30, the nodes cost 23
	_world().pioneer_changed.emit(3)
	var mdict: Dictionary = JSON.parse_string(JSON.stringify(moved.to_dict()))
	San._skills(mdict, 3)
	moved.from_dict(mdict)
	_expect(moved.sp_available == 7 and (moved.trees["survival"]["unlocked"] as Array).size() == 4, "H6: a migrated save at Lv. 4 keeps its 4 nodes and 7 SP through sanitize and load (got %d)" % moved.sp_available)
	_done_with(moved)
	# XP banked at the character-level cap (SkillState._resolve) survives a load; only what the tree
	# cannot use up to Lv. 60 is cut.
	var banked := {"rev": 2, "trees": {"melee": {"level": 5, "xp": 500.0, "unlocked": []}, "ranged": {"level": 5, "xp": 1e12, "unlocked": []}}}
	San._skills(banked, 4)
	_expect(is_equal_approx(float(banked["trees"]["melee"]["xp"]), 500.0) and is_equal_approx(float(banked["trees"]["ranged"]["xp"]), SkillStateS.xp_to_max(5)), "H6: banked XP loads (500, got %s) and is bounded by what Lv. 5 can still use (%.0f, got %s)" % [banked["trees"]["melee"]["xp"], SkillStateS.xp_to_max(5), banked["trees"]["ranged"]["xp"]])
	var hostile := {"rev": 2, "refund_day": [1], "refunds_today": "x", "trees": {}}
	San._skills(hostile, 0)
	_expect(hostile["refund_day"] is int and hostile["refunds_today"] is int, "H6: the optional refund counter loads as numbers (got %s)" % [hostile])
	# A hand-edited rev must read the same in the sanitizer and in SkillState.from_dict: it falls
	# back to rev 1, so the save migrates with its nodes (an array crashed from_dict and left fresh
	# trees; "2" read as rev 2 dropped the nodes over the character level's SP).
	for bad in [[2], "2", -3]:
		var odd := {"rev": bad, "sp_available": 50, "trees": {"survival": {"level": 40, "xp": 0, "unlocked": bought.duplicate()}}}
		San._skills(odd, 0)
		var sk := _fresh(0)
		sk.from_dict(odd)
		_expect(odd["rev"] is int and sk.is_unlocked("survival", "animal_management_1") and sk.sp_available == 0 and sk.sp_extra == 23, "H6: rev %s loads as rev %s with its 4 nodes, 0 SP, extra 23 (got %d SP, extra %d)" % [JSON.stringify(bad), odd["rev"], sk.sp_available, sk.sp_extra])
		_done_with(sk)
	_sections += 1

## Spec 09 grant: the pen bonds through Data.bonded_cap() (hook H2). At the cap the finished animal
## waits in the pen (no roll, no loss, meat refused); a new Animal Handling slot bonds it.
func _test_pen_cap() -> void:
	var data: Node = get_root().get_node("Data")
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(p)
	var def: Resource = data.creature(&"velociraptor")
	var PetRecordS: GDScript = load("res://scripts/pets/pet_record.gd")
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	for i in 3:
		p.bonded.append(PetRecordS.from_def(def))
	var pen: Node = (load("res://scripts/world/taming_pen.gd") as GDScript).new()
	pen.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(pen)
	pen.occupant = IS.make(&"captured_animal", 1, {"species": "velociraptor", "level": 7})
	pen.running = true
	pen.remaining = 0.0
	pen.force_result = 1
	pen._process(0.0)
	_expect(data.bonded_cap() == 3 and p.bonded.size() == 3 and pen.occupant != null and pen.running and pen._told_full, "3 / 3 bonded: the pen keeps the animal and says why (bonded %d, occupant %s)" % [p.bonded.size(), pen.occupant])
	p.inventory.add(IS.make(&"raptor_meat", 1))
	_expect(not pen.feed(p) and p.inventory.count_of(&"raptor_meat") == 1, "meat is refused while the finished animal waits")
	(p.skills.trees["survival"]["unlocked"] as Array).append("animal_management_1")
	pen._process(0.0)
	var rec: Variant = p.bonded[-1]
	_expect(data.bonded_cap() == 4 and p.bonded.size() == 4 and pen.occupant == null and rec.origin == &"capture" and rec.level == 7, "Animal Handling I (cap 4) bonds the waiting Lv. 7 raptor (bonded %d)" % p.bonded.size())
	p.inventory.add(IS.make(&"tamed_animal", 1, {"species": "velociraptor"}))
	pen.running = false
	_expect(pen.try_insert(p) and p.inventory.count_of(&"tamed_animal") == 1 and p.bonded.size() == 4, "4 / 4: a tamed animal in the bag stays there")
	get_root().remove_child(pen)
	pen.free()
	get_root().remove_child(p)
	p.free()
	_sections += 1

## Spec 09 at the bonded cap, field tame (hooks H2 + H9): the plate says the roster is full instead
## of "Tame", the feed is refused with an on-screen notice that names Animal Handling, and the food
## is kept. The pets screen shows bonded / cap (H10, spec 09:50 "e.g. 3 / 4").
func _test_field_tame_cap() -> void:
	var data: Node = get_root().get_node("Data")
	var FT: GDScript = load("res://scripts/pets/field_tame.gd")
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	var PetRecordS: GDScript = load("res://scripts/pets/pet_record.gd")
	var p := _player()
	var hud := _hud_stub()
	var def: Resource = data.creature(&"compsognathus")
	for i in 3:
		p.bonded.append(PetRecordS.from_def(def))
	var c: Node = (load("res://scripts/creatures/creature.gd") as GDScript).new()
	c.def = def
	c.health = (load("res://scripts/combat/health.gd") as GDScript).new()
	c.health.setup(def.hp)
	c.add_child(c.health)
	c.statuses = (load("res://scripts/combat/status_effects.gd") as GDScript).new()
	c.add_child(c.statuses)
	c.health.hp = def.hp * 0.2
	c.statuses.apply(&"knockdown")
	var food: StringName = def.preferred_food[0]
	p.inventory.add(IS.make(food, 2))
	var hint: Dictionary = FT.plate_hint(c, p.inventory)
	_expect(str(hint.get("kind", "")) == "need" and str(hint.get("text", "")) == "Bonded roster full (3 / 3)", "3 / 3 bonded: the plate says the roster is full, not Tame (got %s '%s')" % [hint.get("kind", ""), hint.get("text", "")])
	var fed: bool = FT.apply_feed(p, c, food)
	_expect(not fed and p.inventory.count_of(food) == 2 and is_zero_approx(float(c.tame_feeds)), "3 / 3 bonded: the feed is refused and the %s is kept (fed %s, %d left)" % [food, fed, p.inventory.count_of(food)])
	var said := ", ".join(hud.said)
	_expect(said.contains("Bonded roster full (3 / 3)") and said.contains("Animal Handling"), "3 / 3 bonded: the refusal is on screen and names Animal Handling (notices '%s')" % said)
	var pets: Control = (load("res://scripts/ui/animal_screen.gd") as GDScript).new()
	get_root().add_child(pets)
	pets.open(p)
	_expect(str(pets._title.text).contains("3 / 3"), "the pets screen shows bonded / cap (title '%s')" % pets._title.text)
	_expect(str(pets._summon.text).contains("ACTIVE 0 / "), "the equip button names its counter, so it cannot be read as the bonded cap ('%s')" % pets._summon.text)
	# Each survivor's cap comes from its own skills (Data.bonded_cap(player)), not the local survivor's.
	var p2 := _player()
	for i in 3:
		p2.bonded.append(PetRecordS.from_def(def))
	(p2.skills.trees["survival"]["unlocked"] as Array).append("animal_management_1")
	_expect(FT.roster_full(p2) == "" and FT.roster_full(p) != "", "a second survivor with Animal Handling I has room at 3 bonded while the local one is full ('%s' / '%s')" % [FT.roster_full(p2), FT.roster_full(p)])
	get_root().remove_child(p2)
	p2.free()
	(p.skills.trees["survival"]["unlocked"] as Array).append("animal_management_1")
	hint = FT.plate_hint(c, p.inventory)
	_expect(str(hint.get("kind", "")) == "tame", "Animal Handling I (cap 4) offers the tame again (got %s '%s')" % [hint.get("kind", ""), hint.get("text", "")])
	pets.open(p)
	_expect(str(pets._title.text).contains("3 / 4"), "the pets screen follows the cap (title '%s')" % pets._title.text)
	for n in [pets, hud, p]:
		get_root().remove_child(n)
		n.free()
	c.free()
	_sections += 1

## A fresh survivor's tree opens on rows to act on (hook H8, skills_sheet.gd): learned AUTO nodes
## share one name line, and every node the game reads nothing from yet stays listed (spec 12 10.6:
## level, SP, lock reason) as a muted row with no button after the rest (spec 12:215: nothing to buy).
## A refund the day's limit blocks is greyed with its reason before the tap.
func _test_sheet_rows() -> void:
	var sk := _fresh()
	var sheet: Control = (load("res://scripts/ui/skills_sheet.gd") as GDScript).new()
	get_root().add_child(sheet)
	for tree in ["gathering", "processing"]:
		sheet.open(sk, tree)
		var later := 0
		for n in sk.nodes(tree):
			if sk.node_state(tree, n)[1] == SkillStateS.NOT_IN_GAME:
				later += 1
		var inert := 0
		var rows := 0
		var bad: Array[String] = []
		var autos := ""
		for row in sheet._box.get_children():
			for b in row.find_children("*", "Button", true, false):
				inert += 1 if (b as Button).text == SkillStateS.NOT_IN_GAME else 0
			if str(row.name).begins_with("SkillsLater_"):
				rows += 1
				var t := str(row.get("text"))
				# Spec 12 10.6: what the node unlocks and its prerequisite stay on the muted row too.
				var n := _node(sk, tree, str(row.name).trim_prefix("SkillsLater_"))
				var unlocks := str(n.get("unlocks", ""))
				var req := str(n.get("requires", "")) if n.get("requires") != null else ""
				var detail_ok := (unlocks == "" or unlocks.to_lower() == str(n.get("name", "")).to_lower() or t.contains(unlocks)) \
						and (req == "" or t.contains("needs " + str(_node(sk, tree, req).get("name", req))))
				if row is Button or not row.find_children("*", "Button", true, false).is_empty() or not (t.contains(SkillStateS.NOT_IN_GAME) and t.contains(" SP") and t.contains("Lv. ") and detail_ok):
					bad.append(t)
			elif row.name == "SkillsLearnedAuto":
				autos = row.text
		_expect(later > 0 and rows == later and inert == 0 and bad.is_empty(), "%s at Lv. 1: each of the %d nodes not in the game yet is a row with its level, SP, reason, unlocks and prerequisite and no button (rows %d, buttons %d, bad %s)" % [tree, later, rows, inert, bad])
		_expect(autos.begins_with("Learned automatically: "), "%s at Lv. 1: the learned AUTO nodes share one line ('%s')" % [tree, autos])
	# XP banked at the cap shows as a full bar, like Durango's skill screen, not "200 / 28 XP".
	sk.add_xp("melee", 200.0, true)
	sheet.open(sk)
	var melee: Node = sheet._box.find_child("Skill_melee", true, false)
	var xp_text := ""
	for l in (melee.find_children("*", "Label", true, false) if melee else []):
		xp_text = (l as Label).text if (l as Label).text.ends_with(" XP") else xp_text
	_expect(xp_text == "28 / 28 XP", "melee at the cap with 200 XP banked reads a full bar ('%s')" % xp_text)
	_done_with(sk)
	sk = _fresh(59)
	_grant(sk, "processing", 25)
	sk.unlock("processing", "charcoal")
	for used in [0, int((sk.config["refund"] as Dictionary)["free_per_day"])]:
		sk.refund_day = SkillStateS._today()
		sk.refunds_today = used
		sheet.open(sk, "processing")
		var row: Node = sheet._box.get_node_or_null("SkillsNode_charcoal")
		var btn: Button = row.find_children("*", "Button", true, false)[0] if row else null
		var why: Label = row.find_child("RefundBlock", true, false) if row else null
		if used == 0:
			_expect(btn != null and btn.text == "Refund" and not btn.disabled and why == null, "a free refund leaves Charcoal's Refund active (button %s)" % [btn])
		else:
			_expect(btn != null and btn.text == "Refund" and btn.disabled and why != null and why.text.contains("free refunds"), "the day's %d refunds used: Charcoal's Refund is greyed and says why before the tap (disabled %s, reason '%s')" % [used, btn.disabled if btn else null, why.text if why else ""])
	get_root().remove_child(sheet)
	sheet.free()
	_done_with(sk)
	_sections += 1

## Spec 03:40 "test SP accounting and UI vs authoritative state": the level-up banner, where character
## levels pay their SP, shows SkillState's SP (hook H11, hunt_hud.gd), not the old survival-node count.
## The HUD joins the tree before the player, so its pioneer_changed handler runs before SkillState's.
func _test_levelup_banner() -> void:
	var hud: Node = (load("res://scripts/ui/hunt_hud.gd") as GDScript).new()
	get_root().add_child(hud)
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(p)
	hud.bind(p)
	for stored in [1, 2, 5]:
		_world().pioneer_level = stored
		_world().pioneer_changed.emit(stored)
		var want: int = Rules.paid_for_level(p.skills, stored + 1)
		var banner := str(hud.get("_levelup_summary"))
		var lines := ", ".join((hud.get("_levelup_lines") as Array).map(func (l: Array) -> String: return str(l[0])))
		_expect(p.skills.sp_available == want and banner.ends_with("Skill points %d" % want) and lines.contains("Available Skill Points: %d" % want), "character Lv. %d: the level-up banner shows the %d SP SkillState holds (%d): '%s' | %s" % [stored + 1, want, p.skills.sp_available, banner, lines])
	for n in [hud, p]:
		get_root().remove_child(n)
		n.free()
	_world().pioneer_level = 0
	_sections += 1

## Hooks H1 + H7: a recipe a skill node gates stays listed, and its craft card says what unlocks it
## above the ingredients (a landscape phone shows the top of the detail column without scrolling).
func _test_craft_card_lock() -> void:
	_world().pioneer_level = 0
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	p.process_mode = Node.PROCESS_MODE_DISABLED
	get_root().add_child(p)
	var ui: Control = (load("res://scripts/ui/craft_ui.gd") as GDScript).new()
	get_root().add_child(ui)
	ui.bind(p)
	ui.show_ui()
	ui._choose_recipe("charcoal")
	var lock: Label = ui._detail.find_child("DetailLock", true, false)
	var text := lock.text if lock else ""
	var ingredients := -1
	for c in ui._detail.get_children():
		if c is Label and (c as Label).text == "INGREDIENTS":
			ingredients = c.get_index()
	var above := lock != null and lock.get_index() < ingredients
	_expect(text.begins_with("Learn Charcoal (Processing Lv. 10, 1 SP); you have 0 SP") and above, "the charcoal craft card says what unlocks it, above the ingredients: '%s'" % text)
	for n in [ui, p]:
		get_root().remove_child(n)
		n.free()
	_sections += 1
