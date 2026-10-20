extends SceneTree
## W2-SKILLS checks: trees.json is a valid node graph on Durango's 1-60 scale, a new survivor's
## trees start at Lv. 1 with the Lv1 AUTO nodes learned, a tree cannot pass the character level,
## Animal Handling I-IV raise bonded capacity 3 -> 7, skill nodes gate recipes and abilities,
## refunds respect dependents, and rev-1 saves migrate without losing SP.
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
	var want := 8
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
	var by_status := {"functional": 0, "partial": 0, "defined": 0}
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
			by_status[st] = int(by_status.get(st, 0)) + 1
			var wired := false
			for e in n.get("effects", []):
				var kind := str(e.get("type", ""))
				wired = wired or WIRED.has(kind)
				if kind == "recipe":
					for rid in e.get("recipes", []):
						_expect(recipes.has(str(rid)), "%s/%s gates unknown recipe %s" % [tree, id, rid])
			_expect(st != "functional" or wired, "%s/%s is 'functional' with no effect the game reads" % [tree, id])
	var ref: Dictionary = root["reference"]
	var total := 0
	for c in ref["categories"]:
		total += int(ref["categories"][c][0])
	_expect(total == 918 and int(ref["total_nodes"]) == 918, "reference counts sum to 918 (got %d)" % total)
	for must in ["animal_management_1", "animal_management_4", "handicraft_5", "metalworking_4", "roll_duration_1", "barrage"]:
		_expect(ids.has(must), "catalog has %s" % must)
	print("[t_w2_skills] catalog %d of 918 nodes: functional %d, partial %d, defined %d" % [count, by_status.functional, by_status.partial, by_status.defined])
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
	_expect(not sk.refund("processing", "cordage") and sk.is_unlocked("processing", "cordage"), "an auto node cannot be refunded")
	_done_with(sk)
	_sections += 1

func _test_level_cap() -> void:
	var sk := _fresh()
	sk.add_xp("melee", 200.0, true) # mirrored: no World XP, so the character stays Lv. 1
	_expect(sk.level_of("melee") == 1, "melee cannot pass character Lv. 1 (got %d)" % sk.level_of("melee"))
	_expect(is_equal_approx(sk.xp_of("melee"), SkillStateS.xp_to_next(1)), "XP at the cap fills the bar and waits (xp %.0f)" % sk.xp_of("melee"))
	_expect(sk.sp_earned == 0, "no SP while the character is Lv. 1")
	_world().pioneer_level = 4 # character Lv. 5
	_world().pioneer_changed.emit(4)
	# Survival trained alongside (every gain also trains Survival), so it waited too.
	_expect(sk.level_of("melee") == 2 and sk.level_of("survival") == 2, "a character level-up releases the waiting levels (melee %d, survival %d)" % [sk.level_of("melee"), sk.level_of("survival")])
	_expect(sk.sp_earned == Rules.paid_for_level(sk, 5) and sk.sp_available == sk.sp_earned, "character Lv. 5 pays levels 2-5 (%d SP), the released tree levels pay nothing" % sk.sp_earned)
	sk.add_xp("melee", 2000.0, true)
	_expect(sk.level_of("melee") == 5, "melee climbs to the character level 5 and stops (got %d)" % sk.level_of("melee"))
	_done_with(sk)
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
	_expect(not Rules.can_bond(sk, 7) and Rules.can_bond(sk, 6), "7 / 7 refuses a new bond, 6 / 7 allows one")
	_expect(not sk.refund("survival", "animal_management_1"), "Animal Handling I stays while II needs it")
	for i in [4, 3, 2, 1]:
		sk.refund("survival", "animal_management_%d" % i)
	_expect(Rules.bonded_capacity(sk) == 3 and not Rules.can_bond(sk, 5), "after the reset: capacity 3, 5 kept pets block new bonds")
	_expect(not get_root().get_node("Data").is_survival_unlocked(&"animal_management_I"), "refund clears the Data mirror")
	sk.refund("survival", "capture_technique_1")
	_expect(not get_root().get_node("Data").has_capture_technique(1), "refunding Capture Technique I removes net capture tier 1")
	_done_with(sk)
	_sections += 1

func _test_recipe_gates_and_abilities() -> void:
	var sk := _fresh(59)
	_expect(Rules.recipe_block(sk, "rope") == "" and Rules.recipe_block(sk, "improvised_stone_knife") == "", "auto nodes leave rope and the stone knife open")
	_expect(Rules.recipe_block(sk, "workbench_kit") == "", "a recipe no node gates stays open")
	var block: String = Rules.recipe_block(sk, "charcoal")
	_expect(block.contains("Charcoal") and block.contains("10"), "charcoal is locked behind Charcoal (Processing Lv. 10): '%s'" % block)
	_expect(Rules.recipe_block(sk, "field_small").contains("Till Small Field"), "small field needs Till Small Field")
	_expect(not sk.unlock("processing", "charcoal"), "Charcoal cannot be bought at Processing 1")
	_grant(sk, "processing", 25)
	_expect(sk.unlock("processing", "charcoal") and Rules.recipe_block(sk, "charcoal") == "", "learning Charcoal opens the charcoal recipe")
	_expect(sk.refund("processing", "charcoal") and Rules.recipe_block(sk, "charcoal") != "", "refunding Charcoal locks it again")
	_expect(Rules.ability(sk, "handicraft") == 0, "Handicraft Ability 0 before Handicraft I")
	_expect(sk.unlock("processing", "handicraft_1") and sk.unlock("processing", "handicraft_2"), "buy Handicraft I and II")
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
	# A rev-1 save that bought more than its character level now pays for keeps every node, 0 SP left.
	var over := _fresh(0)
	over.from_dict({"sp_available": 50, "sp_spent": 0, "trees": {"survival": {"level": 40, "xp": 0.0, "unlocked": ["island_access_15", "belly_fat_1", "capture_technique_1", "animal_management_1"]}}})
	_expect((over.trees["survival"]["unlocked"] as Array).size() == 4 and over.sp_spent == 23 and over.sp_available == 0, "an over-budget migrated save keeps its 4 nodes with 0 SP (spent %d, available %d)" % [over.sp_spent, over.sp_available])
	_expect(get_root().get_node("Data").has_capture_technique(1), "the kept Capture Technique I still works")
	_done_with(over)
	_sections += 1
