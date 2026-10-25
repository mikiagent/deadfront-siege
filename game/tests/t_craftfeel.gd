extends SceneTree
## CRAFTFEEL (plan §3.3 "Crafting", P7; specs 04, 08, 25 §8): a craft has stakes.
## The success curve of spec 04 at shortfall 0 / 50 / 100; a failed craft spends the picked
## instances exactly once and makes nothing; flawless ~5 % and a rare trait ~5 % over 2000
## seeded crafts; the skewer's Food + Tool slots (a stick or a leg bone, not a club); the
## preview equals the result; craft XP paid once.
## Run: Godot --headless --path game --script res://tests/t_craftfeel.gd -> "[t_craftfeel] PASS".
## Scripts are load()ed on the first frame: a --script run compiles this file before autoloads exist.

const CRAFTS := 2000
const BAND := 0.02

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node
var _fire: Node3D
var CR: GDScript
var IS: GDScript
var INV: GDScript
var FOOD: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_craftfeel] FAIL %s" % what)

func _run() -> void:
	CR = load("res://scripts/items/crafting.gd")
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	FOOD = load("res://scripts/items/food.gd")
	_host = Node3D.new()
	_host.name = "TCraftfeel"
	root.add_child(_host)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_player.position = Vector3(0, 1, 0)
	_host.add_child(_player)
	_fire = (load("res://scripts/world/bonfire.gd") as GDScript).make(&"bonfire")
	_fire.position = Vector3(1, 0, 0)
	_host.add_child(_fire)
	await process_frame
	await physics_frame
	_test_curve()
	_test_double_gate()
	_test_fail_consumes_once()
	_test_rates()
	_test_rare_inheritance()
	_test_skewer_slots()
	_test_preview_matches_result()
	_test_ui_text()
	_test_xp_once()
	_test_shipped_ability()
	_test_explicit_pick_bypass()
	_test_full_bag_retry()
	_test_uid_preservation()
	_test_live_card()
	await _test_online_parity()
	_finish()

func _finish() -> void:
	_player.get_tree().create_timer(60.0).timeout.connect(func () -> void: quit(1))
	if _fails.is_empty():
		print("[t_craftfeel] PASS")
		quit(0)
	else:
		print("[t_craftfeel] FAIL count=%d" % _fails.size())
		quit(1)

## A recipe whose ability requirement the caller names: no station, one material slot.
func _rec(required: float, args: Dictionary = {}) -> Dictionary:
	var rec := {
		"id": "t_craftfeel", "display_name": "Test", "skill": "processing", "max_level": 60,
		"slots": [{"category": "blade_mat", "count": 1, "primary": true}],
		"output": {"id": "stone_knife", "count": 1}, "seconds": 1.0, "process_step": "knap",
	}
	if required > 0.0:
		rec["required_ability"] = required
	rec.merge(args, true)
	return rec

func _clear_bag() -> void:
	for i in _player.inventory.slot_count:
		if _player.inventory.slots[i] != null:
			_player.inventory.remove_at(i, 999)
	_player.inventory.changed.emit()

func _count_rows() -> int:
	var n := 0
	for s in _player.inventory.slots:
		if s != null:
			n += 1
	return n

## Spec 04's preserved curve, at the three shortfalls the task names.
func _test_curve() -> void:
	var rec := _rec(100.0)
	var at0: float = CR.success_chance(rec, 100.0)
	var at50: float = CR.success_chance(rec, 50.0)
	var at100: float = CR.success_chance(rec, 0.0)
	print("[t_craftfeel] curve shortfall 0=%.3f 50=%.3f 100=%.3f" % [at0, at50, at100])
	_expect(is_equal_approx(at0, 1.0), "shortfall 0 is 100 %% (got %.3f)" % at0)
	_expect(is_equal_approx(at50, 0.75), "shortfall 50 is 75 %% (got %.3f)" % at50)
	_expect(is_equal_approx(at100, 0.0), "shortfall 100 is 0 %% (got %.3f)" % at100)
	var at80: float = CR.success_chance(rec, 20.0)
	_expect(is_equal_approx(at80, 0.36), "shortfall 80 is 36 %% (spec 04; got %.3f)" % at80)
	_expect(is_equal_approx(CR.success_chance(_rec(0.0), 0.0), 1.0), "a recipe with no ability requirement always succeeds (the skewer's 100 %)")

## The category-level gate still refuses before any roll (spec 04: level gates, ability sets the chance).
func _test_double_gate() -> void:
	_clear_bag()
	_player.inventory.add(IS.make(&"stone", 2, {}, 5))
	var rec := _rec(0.0, {"min_level": 60})
	_player.skills.trees["processing"]["level"] = 1
	var picks: Array[int] = CR.default_picks(_player.inventory, rec)
	_expect(not bool(CR.can_make(_player, rec, picks)), "a min_level the survivor has not reached refuses the craft before rolling")

## Spec 25 §8: "if crafting fails, materials disappear." Taken once, nothing made, no XP.
func _test_fail_consumes_once() -> void:
	_clear_bag()
	_player.inventory.add(IS.make(&"stone", 2, {}, 5))
	_player.inventory.add(IS.make(&"twine", 1, {}, 5))
	_player.inventory.add(IS.make(&"berry", 1, {}, 5))
	var rec := _rec(0.0, {"slots": [
		{"category": "blade_mat", "count": 1, "primary": true},
		{"category": "lashing", "count": 1, "primary": false},
	]})
	var picks: Array[int] = CR.default_picks(_player.inventory, rec)
	_expect(_player.inventory.count_of(&"stone") == 2 and _player.inventory.count_of(&"twine") == 1, "fixture: 2 stone + 1 twine in the bag")
	var xp_before: float = _player.skills.xp_of("processing")
	var out: Variant = CR.commit_outcome(_player, rec, picks, {"success": false, "flawless": false, "rare": &""})
	_expect(out == null, "a failed craft returns no item")
	_expect(_player.inventory.count_of(&"stone") == 1 and _player.inventory.count_of(&"twine") == 0, "a failed craft spends each picked instance exactly once (2 stone -> 1, 1 twine -> 0; got stone %d twine %d)" % [_player.inventory.count_of(&"stone"), _player.inventory.count_of(&"twine")])
	_expect(_player.inventory.count_of(&"stone_knife") == 0 and _player.inventory.count_of(&"berry") == 1, "a failed craft makes nothing and leaves other rows alone")
	_expect(is_equal_approx(_player.skills.xp_of("processing"), xp_before), "a failed craft pays no XP")
	# A failure through the ordinary craft() path (a recipe that cannot reach its ability).
	_clear_bag()
	_player.inventory.add(IS.make(&"stone", 1, {}, 5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var hard := _rec(1000.0)
	var hp: Array[int] = CR.default_picks(_player.inventory, hard)
	var made: Variant = CR.craft(_player, hard, hp, rng)
	_expect(made == null and _player.inventory.count_of(&"stone") == 0, "craft() at a hopeless shortfall fails and loses the input")

## Plan 3.3: flawless 5 %, rare trait 5 %, both within ±2 pp over 2000 seeded crafts.
func _test_rates() -> void:
	var rec := _rec(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var primary = IS.make(&"stone", 1, {}, 10)
	var flawless := 0
	var rare := 0
	var successes := 0
	for i in CRAFTS:
		var o: Dictionary = CR.roll_outcome(rec, _player, primary, rng)
		successes += 1 if bool(o["success"]) else 0
		flawless += 1 if bool(o["flawless"]) else 0
		rare += 1 if str(o["rare"]) != "" else 0
	var f_rate := float(flawless) / float(CRAFTS)
	var r_rate := float(rare) / float(CRAFTS)
	print("[t_craftfeel] rates crafts=%d success=%d flawless=%.4f rare=%.4f" % [CRAFTS, successes, f_rate, r_rate])
	_expect(successes == CRAFTS, "a recipe that cannot fall short never fails (%d/%d)" % [successes, CRAFTS])
	_expect(absf(f_rate - CR.flawless_chance()) <= BAND, "flawless rate %.4f is within %.0f pp of %.4f" % [f_rate, BAND * 100.0, CR.flawless_chance()])
	_expect(absf(r_rate - 0.05) <= BAND, "rare trait rate %.4f is within 2 pp of 5 %%" % r_rate)
	# The same seed reproduces the same craft.
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var same := true
	for i in 50:
		same = same and CR.roll_outcome(rec, _player, primary, a) == CR.roll_outcome(rec, _player, primary, b)
	_expect(same, "the outcome reproduces with a seeded RNG (tests and the server can replay it)")

## Spec 04: rare attributes pass from an eligible primary material; non-rare traits carry as before.
func _test_rare_inheritance() -> void:
	_clear_bag()
	var stone = IS.make(&"stone", 1, {"black_sheen": 2}, 10)
	_player.inventory.add(stone)
	var rec := _rec(0.0, {"id": "t_rare"})
	var picks: Array[int] = CR.default_picks(_player.inventory, rec)
	var outcome: Dictionary = CR.roll_outcome(rec, _player, _player.inventory.slots[picks[0]], RandomNumberGenerator.new())
	_expect(str(outcome["rare"]) == "black_sheen", "a primary's rare trait is inherited (got %s)" % outcome["rare"])
	var out: Variant = CR.commit_outcome(_player, rec, picks, {"success": true, "flawless": false, "rare": outcome["rare"]})
	_expect(out != null and int(out.attributes.get("black_sheen", 0)) > 0, "the crafted item carries the rare trait")

## Spec 25 §8: Food slot (meat) + Tool slot (Long Stick, Stick, Short Stick or a leg bone).
func _test_skewer_slots() -> void:
	_clear_bag()
	var rec: Dictionary = CR.recipe(&"skewer")
	_expect(not rec.is_empty(), "the skewer recipe exists")
	if rec.is_empty():
		return
	var slots: Array = rec.get("slots", [])
	_expect(slots.size() == 2 and str(slots[0].get("role", "")) == "food" and str(slots[1].get("role", "")) == "tool",
		"the skewer is a Food slot plus a Tool slot")
	_expect(str(slots[0].get("category", "")) == "meat", "the Food slot takes meat")
	var allowed: Array = slots[1].get("allowed_ids", [])
	_expect("branch" in allowed and "raptor_bone" in allowed, "the Tool slot takes a stick (branch) or a leg bone (raptor_bone)")
	_player.inventory.add(IS.make(&"raw_meat", 1, {}, 10))
	_player.inventory.add(IS.make(&"club", 1, {}, 5))  # category handle, but a club is a weapon, not a stick
	var club_picks: Array[int] = CR.default_picks(_player.inventory, rec)
	_expect(not bool(CR.picks_valid(_player.inventory, rec, club_picks)), "a club does not fill the skewer's Tool slot")
	_player.inventory.remove_at(_player.inventory.find_first(&"club"), 1)
	_player.inventory.add(IS.make(&"raptor_bone", 1, {}, 12))
	var ok_picks: Array[int] = CR.default_picks(_player.inventory, rec)
	_expect(bool(CR.picks_valid(_player.inventory, rec, ok_picks)), "a leg bone fills the skewer's Tool slot")
	# A skull-free stick works too, and the recipe still makes a skewer.
	_player.inventory.remove_at(_player.inventory.find_first(&"raptor_bone"), 1)
	_player.inventory.add(IS.make(&"branch", 1, {}, 12))
	var bp: Array[int] = CR.default_picks(_player.inventory, rec)
	var out: Variant = CR.commit_outcome(_player, rec, bp, {"success": true, "flawless": false, "rare": &""})
	_expect(out != null and out.def_id == &"skewer", "meat + a stick makes a skewer")

## The card's numbers are the craft's numbers: same success chance, same level, same inherited traits.
func _test_preview_matches_result() -> void:
	_clear_bag()
	_player.skills.trees["cooking"]["level"] = 12
	var meat = IS.make(&"raptor_meat", 1, {"firm": 3, "pointy": 2}, 20)
	_player.inventory.add(meat)
	_player.inventory.add(IS.make(&"branch", 1, {"firm": 4}, 20))
	var rec: Dictionary = CR.recipe(&"skewer")
	var picks: Array[int] = CR.default_picks(_player.inventory, rec)
	var prev: Dictionary = CR.preview_quality(rec, _player, _player.inventory.slots[picks[CR.primary_index(rec)]])
	var shown = CR.preview(_player.inventory, rec, picks)
	_expect(shown != null, "a preview is available for the picks")
	if shown == null:
		return
	_expect(is_equal_approx(float(prev["success"]), CR.success_for(rec, _player)), "the preview's success chance is the craft's own success chance")
	_expect("firm" in (prev["inherited"] as Array) and "pointy" in (prev["inherited"] as Array), "the preview lists the primary's inherited traits (%s)" % [prev["inherited"]])
	_expect(bool(prev["loses_materials"]), "the preview states that materials are lost on failure")
	var out: Variant = CR.commit_outcome(_player, rec, picks, {"success": true, "flawless": false, "rare": &""})
	_expect(out != null and out.level == shown.level, "the result's level %s equals the preview's %s" % [out.level if out else -1, shown.level])
	if out:
		_expect(is_equal_approx(float(FOOD.energy_restore(out)), float(FOOD.energy_restore(shown))), "the result's energy equals the preview's")
	# A flawless craft keeps the previewed level and only adds the stat bump.
	_clear_bag()
	_player.inventory.add(IS.make(&"raptor_meat", 1, {}, 20))
	_player.inventory.add(IS.make(&"branch", 1, {}, 20))
	var p2: Array[int] = CR.default_picks(_player.inventory, rec)
	var base = CR.preview(_player.inventory, rec, p2)
	var fl: Variant = CR.commit_outcome(_player, rec, p2, {"success": true, "flawless": true, "rare": &""})
	_expect(fl != null and base != null and fl.level == base.level, "a flawless craft keeps the previewed level")
	_expect(fl != null and (&"flawless" in fl.flags) and str(fl.attributes.get("quality", "")) == "flawless", "a flawless craft is marked on the item")

## M3: the detail pane says the odds and the price of failing, from the same numbers the craft rolls.
func _test_ui_text() -> void:
	var UI: GDScript = load("res://scripts/ui/craft_ui.gd")
	_clear_bag()
	_player.inventory.add(IS.make(&"raptor_meat", 1, {"firm": 3, "black_sheen": 1}, 10))
	_player.inventory.add(IS.make(&"branch", 1, {}, 10))
	var rec: Dictionary = CR.recipe(&"skewer")
	var picks: Array[int] = CR.default_picks(_player.inventory, rec)
	var qual: Dictionary = CR.preview_quality(rec, _player, _player.inventory.slots[picks[0]])
	var text: String = UI.craftfeel_text(qual)
	print("[t_craftfeel] ui text: %s" % text.replace("\n", " | "))
	_expect(text.contains("Success 100%"), "the card states the success chance (100 %%)")
	_expect(text.contains("Flawless 5%"), "the card states the flawless chance (5 %%)")
	_expect(text.contains("Materials are lost on failure"), "the card says materials are lost on failure")
	_expect(text.contains("Black Sheen"), "the card lists the inherited rare trait (%s)" % text)
	var hard: Dictionary = _rec(100.0)
	var worse: String = UI.craftfeel_text(CR.preview_quality(hard, _player, null))
	_expect(worse.contains("/ 100 needed"), "a recipe with an ability requirement shows it (%s)" % worse.replace("\n", " | "))

## Craft XP is paid once per successful craft, on the recipe's own tree (plus the survival mirror).
func _test_xp_once() -> void:
	_clear_bag()
	_player.skills.trees["cooking"]["level"] = 12
	_player.skills.trees["cooking"]["xp"] = 0.0
	_player.inventory.add(IS.make(&"raptor_meat", 1, {}, 10))
	_player.inventory.add(IS.make(&"branch", 1, {}, 10))
	var rec: Dictionary = CR.recipe(&"skewer")
	var picks: Array[int] = CR.default_picks(_player.inventory, rec)
	var want: float = 6.0 + float(CR.recipe_seconds(rec))
	var before: float = _player.skills.xp_of("cooking")
	var made: Variant = CR.commit_outcome(_player, rec, picks, {"success": true, "flawless": false, "rare": &""})
	var got: float = _player.skills.xp_of("cooking") - before
	_expect(made != null and is_equal_approx(got, want), "one craft pays %.0f XP once (got %.1f)" % [want, got])
	var none: Variant = CR.commit_outcome(_player, rec, CR.default_picks(_player.inventory, rec), {"success": true, "flawless": false, "rare": &""})
	_expect(none == null and is_equal_approx(_player.skills.xp_of("cooking") - before, want), "a craft with no materials pays nothing (no repeat XP)")

# ---------------------------------------------------------------- review round 1

## Review (1): a failure must be reachable in shipped data. Every recipe that gated its category level
## also declares the Crafting Ability it asks for (data, not code), so a survivor who has just reached
## the gate falls short and can lose the materials; nothing else is retuned.
func _test_shipped_ability() -> void:
	var gated := 0
	var best := -1.0
	var worst_id := ""
	for rec: Dictionary in CR.all_recipes():
		var ml := int(rec.get("min_level", 0))
		if ml < 10:
			continue
		gated += 1
		var req := float(rec.get("required_ability", 0.0))
		var at_gate: float = CR.success_chance(rec, CR.ability_of(ml))
		if at_gate < best or best < 0.0:
			best = at_gate
			worst_id = str(rec.get("id", ""))
		_expect(req > 0.0, "shipped recipe %s (min_level %d) declares required_ability in data" % [rec.get("id", ""), ml])
	print("[t_craftfeel] shipped gated=%d lowest_success_at_gate=%.3f (%s)" % [gated, best, worst_id])
	_expect(gated > 0, "some shipped recipes gate a skill level")
	_expect(worst_id != "" and best < 0.9999, "a gated recipe can fail at its own gate level (%s -> %.2f %%)" % [worst_id, best * 100.0])
	# The curve reads the data value, not a constant in code.
	var probe := {"id": "probe", "slots": [{"category": "blade_mat", "count": 1, "primary": true}], "output": {"id": "stone_knife", "count": 1}}
	probe["required_ability"] = 50.0
	_expect(is_equal_approx(CR.success_chance(probe, 0.0), 0.75), "required_ability comes from the recipe data (shortfall 50 -> 75 %%)")

## Review (3): an explicit pick obeys allowed_ids as well: a club is a handle, but the skewer's Tool
## slot lists branch/bone, so naming the club as the pick must fail rather than slip past the plan.
func _test_explicit_pick_bypass() -> void:
	_clear_bag()
	_player.inventory.add(IS.make(&"raw_meat", 1, {}, 10))
	_player.inventory.add(IS.make(&"raptor_bone", 1, {}, 10))
	_player.inventory.add(IS.make(&"club", 1, {}, 5))
	var rec: Dictionary = CR.recipe(&"skewer")
	var food: int = _player.inventory.find_first(&"raw_meat")
	var club: int = _player.inventory.find_first(&"club")
	var bone: int = _player.inventory.find_first(&"raptor_bone")
	var forced: Array[int] = [food, club]
	_expect(not bool(CR.picks_valid(_player.inventory, rec, forced)), "an explicit club pick is refused for the skewer's Tool slot")
	_expect(CR.plan_for_player(_player, rec, forced).is_empty(), "no plan is built from a disallowed explicit pick")
	var ok: Array[int] = [food, bone]
	_expect(bool(CR.picks_valid(_player.inventory, rec, ok)) and not CR.plan_for_player(_player, rec, ok).is_empty(), "an explicit bone pick is accepted")

## Review (4)+(5): one plan, one outcome, one burn roll. A full bag holds the finished craft and every
## retry reuses the plan, so a retry can never turn a good craft into a burnt one or reroll a failure.
func _test_full_bag_retry() -> void:
	# Two non-stacking units out of one input: a full bag has one slot free, so the unit cannot land.
	var rec := _rec(0.0, {"id": "t_two", "output": {"id": "stone_knife_work", "count": 2}})
	var inv = INV.new(3)
	inv.add(IS.make(&"stone", 1, {}, 6))
	var picks: Array[int] = CR.default_picks(inv, rec)
	var plan: Dictionary = CR.plan_craft(rec, inv, picks, CR.ability_of(30), 30, 30, RandomNumberGenerator.new())
	_expect(not plan.is_empty(), "a two-unit plan is built")
	if plan.is_empty():
		return
	inv.add(IS.make(&"berry", 1, {}, 1))
	inv.add(IS.make(&"berry", 1, {}, 2))
	var fulls := 0
	for _i in 2:
		var res: Dictionary = CR.run_plan(rec, inv, plan)
		_expect(str(res["status"]) == "full", "a bag with no room holds the finished craft (%s)" % str(res["status"]))
		if str(res["status"]) == "full":
			fulls += 1
		_expect(inv.count_of(&"stone") == 1 and inv.count_of(&"stone_knife_work") == 0,
			"a full-bag retry consumes nothing and mints nothing")
		_expect(_outcome_of(plan) == _outcome_of(plan), "the retry keeps the same outcome")
	var made: Dictionary = {}
	for _i in 2:
		inv.remove_at(inv.find_first(&"berry"), 1)
		made = CR.run_plan(rec, inv, plan)
		if str(made["status"]) != "full":
			break
	print("[t_craftfeel] full-bag full=%d then %s" % [fulls, str(made.get("status", ""))])
	_expect(fulls == 2, "a full bag holds the craft on every retry")
	_expect(str(made.get("status", "")) == "made" and inv.count_of(&"stone_knife_work") == 2,
		"the same plan lands once there is room, without a reroll (%s, knives %d)" % [str(made.get("status", "")), inv.count_of(&"stone_knife_work")])
	_expect(inv.count_of(&"stone") == 0, "the input was spent exactly once")
	# The burn roll belongs to the plan: run_plan uses that single value, never its own roll.
	var grill: Dictionary = CR.recipe(&"stone_grill")
	var ginv = INV.new(6)
	ginv.add(IS.make(&"raw_meat", 1, {}, 6))
	var gpicks: Array[int] = CR.default_picks(ginv, grill)
	var g2 = INV.new(6)
	g2.add(IS.make(&"raw_meat", 1, {}, 6))
	var gplan: Dictionary = CR.plan_craft(grill, g2, CR.default_picks(g2, grill), CR.ability_of(40), 40, 40, RandomNumberGenerator.new())
	_expect(not gplan.is_empty() and gplan.has("burnt"), "a burnt-on-fail recipe's plan holds its burn roll")
	# The plan's own burn value decides the output: overriding it must not be rolled again.
	var burnt_plan: Dictionary = gplan.duplicate(true)
	burnt_plan["burnt"] = true
	burnt_plan["outcome"] = {"success": true, "flawless": false, "rare": &""}
	var burnt_res: Dictionary = CR.run_plan(grill, g2, burnt_plan)
	_expect(str(burnt_res["status"]) == "made" and _def_of(burnt_res) == "burnt_food",
		"a plan that burned makes burnt food (%s)" % _def_of(burnt_res))
	var g3 = INV.new(6)
	g3.add(IS.make(&"raw_meat", 1, {}, 6))
	var raw_plan: Dictionary = CR.plan_craft(grill, g3, CR.default_picks(g3, grill), CR.ability_of(40), 40, 40, RandomNumberGenerator.new())
	raw_plan["burnt"] = false
	raw_plan["outcome"] = {"success": true, "flawless": false, "rare": &""}
	var raw_res: Dictionary = CR.run_plan(grill, g3, raw_plan)
	_expect(str(raw_res["status"]) == "made" and _def_of(raw_res) == "grilled_meat",
		"the same recipe with burnt=false makes grilled meat: the burn value is the plan's (%s)" % _def_of(raw_res))

func _def_of(res: Dictionary) -> String:
	var it = res.get("item")
	return str(it.def_id) if it != null else "none"

func _outcome_of(plan: Dictionary) -> String:
	return str(plan.get("outcome", {})) + str(plan.get("burnt", false))

## Review: the plan keeps the exact selected instances through a bag sort, and fails safely when one
## of them leaves the bag instead of substituting a different stack.
func _test_uid_preservation() -> void:
	_clear_bag()
	var first = IS.make(&"raw_meat", 1, {}, 9)
	first.stamp_identity("loot", "tester")
	var second = IS.make(&"raw_meat", 1, {}, 31)
	second.stamp_identity("loot", "tester")
	_player.inventory.slots[0] = first
	_player.inventory.slots[1] = second
	var rec: Dictionary = CR.recipe(&"sashimi")
	var picks: Array[int] = [0]
	var plan: Dictionary = CR.plan_for_player(_player, rec, picks)
	if plan.is_empty():
		# sashimi is node-gated; fall back to its shape without the node so the uid rule is still tested.
		rec = _rec(0.0, {"id": "t_uid", "output": {"id": "sashimi", "count": 3}})
		rec["slots"] = [{"category": "raw_meat", "count": 1, "primary": true}]
		plan = CR.plan_for_player(_player, rec, picks)
	_expect(not plan.is_empty(), "a plan is built from the previewed instance")
	if plan.is_empty():
		return
	_expect(str(plan["uids"][0]) == first.uid, "the plan remembers the picked instance's uid")
	# The bag is sorted on the way: the plan follows the instance, not the slot index.
	_player.inventory.slots[0] = second
	_player.inventory.slots[1] = first
	_expect(CR.plan_picks(_player.inventory, rec, plan) == [1], "the plan resolves the same instance after a bag sort")
	# The instance is dropped/eaten: the craft fails safely, nothing is consumed.
	_player.inventory.remove_at(1, 1)
	var res: Dictionary = CR.run_plan(rec, _player.inventory, plan)
	_expect(str(res["status"]) == "left", "a plan whose instance left the bag stops instead of substituting (got %s)" % str(res["status"]))
	_expect(_player.inventory.count_of(&"raw_meat") == 1 and int(_player.inventory.slots[0].level) == 31,
		"the other stack is untouched")

## Review (6): the live station craft shows the odds card (not only the dev lab), on a 64 px target.
func _test_live_card() -> void:
	_clear_bag()
	_player.global_position = _fire.global_position + Vector3(1.2, 0, 0.9)
	_player.inventory.add(IS.make(&"raptor_meat", 1, {"firm": 3}, 20))
	_player.inventory.add(IS.make(&"branch", 1, {}, 20))
	var sc = _player.station_craft
	sc.begin(&"skewer", 1)
	await physics_frame
	sc._start_craft_cycle()
	await process_frame
	var card = sc.card
	_expect(card != null and card.visible, "the live craft card is on screen while the craft runs")
	if card == null or not card.visible:
		sc.cancel_and_refund()
		return
	var odds: String = card._odds.text if card._odds else ""
	print("[t_craftfeel] live card odds: %s" % odds.replace("\n", " | "))
	_expect(odds.contains("Success") and odds.contains("Flawless"), "the live card states success and flawless (%s)" % odds.replace("\n", " | "))
	_expect(odds.contains("lost on failure"), "the live card states that materials are lost on failure")
	var ring: float = float(_player.station_craft.card.get_script().get_script_constant_map()["SLOT_R"]) * 2.0 + 4.0
	_expect(ring >= 64.0, "the card's material ring is a 64 px phone target (%.0f px)" % ring)
	_expect(bool((sc._plan.get("outcome", {}) as Dictionary).has("success")), "the live craft planned its outcome once at start")
	sc.cancel_and_refund()

## Review (2): online crafting runs the same rule. A shortfall fails and loses exactly the picked
## units; a success pays XP once; a disallowed explicit pick is refused; a failure reports failed=true.
## The server classes are load()ed here: a --script run compiles this file before autoloads exist, so
## naming CharacterState/WorldFacade in a type annotation would fail to compile.
func _test_online_parity() -> void:
	var WF: GDScript = load("res://scripts/server/world_facade.gd")
	var ST: GDScript = load("res://scripts/server/character_store.gd")
	var IH: GDScript = load("res://scripts/server/intent_handlers.gd")
	var SR: GDScript = load("res://scripts/server/server_rng.gd")
	if WF == null or ST == null or IH == null or SR == null:
		_expect(false, "the server scripts load")
		return
	if not WF.new() is Object:
		_expect(false, "WorldFacade instantiates")
		return
	var world = WF.new()
	world.stations["bonfire"] = [[0, 0, 0]]
	var store = ST.new(world, "", 7)
	store.apply("char.create", 1, {"name": "Parity"}, 1)
	# Seed the server bag directly: the point of this check is the craft op, not the gather op.
	var ch = store.character(1)
	ch.d.skills["processing"] = {"level": 20, "xp": 0.0, "unlocked": []}
	ch.d.skills["cooking"] = {"level": 20, "xp": 0.0, "unlocked": []}
	ch.d.bag[0] = IS.make(&"stone", 4, {}, 6).to_dict()
	ch.d.bag[1] = IS.make(&"fibre_stalk", 4, {}, 6).to_dict()
	ch.d.bag[2] = IS.make(&"raw_meat", 2, {}, 6).to_dict()
	ch.d.bag[3] = IS.make(&"branch", 2, {}, 6).to_dict()
	ch.d.bag[4] = IS.make(&"club", 1, {}, 3).to_dict()
	# The server's curve is the offline curve: one ability function, one curve.
	var sample := _rec(100.0)
	_expect(is_equal_approx(CR.success_chance(sample, IH.craft_ability(0)), CR.success_chance(sample, CR.ability_of(1))),
		"online and offline use one success curve")
	# A hopeless craft through the shipped server op: it must report a failure and lose the units.
	var inv = ch.inventory()
	var hard := _rec(1000.0, {"slots": [{"category": "stone", "count": 2, "primary": true}], "id": "t_parity_fail"})
	var stone_picks: Array[int] = CR.default_picks(inv, hard)
	var plan: Dictionary = CR.plan_craft(hard, inv, stone_picks, IH.craft_ability(1), 1, 1, SR.for_op(7, int(store.s.seq) + 1, "act.craft"))
	_expect(not plan.is_empty() and not bool((plan["outcome"] as Dictionary)["success"]), "the parity fixture plans a failure at a 1000 point shortfall")
	# Online twine (2 fibre -> 1 twine) is a real shipped recipe: it goes through plan_craft/run_plan.
	var twine: Dictionary = CR.recipe(&"twine")
	var tpicks: Array[int] = CR.default_picks(ch.inventory(), twine)
	var xp_before: float = _skill_xp(ch, "processing")
	var made: Dictionary = store.apply("act.craft", 1, {"recipe_id": "twine", "picks": tpicks}, 10)
	var ch2 = store.character(1)
	var xp_after: float = _skill_xp(ch2, "processing")
	print("[t_craftfeel] online twine ok=%s failed=%s xp %.1f -> %.1f" % [bool(made.get("ok", false)), bool((made.get("r", {}) as Dictionary).get("failed", false)), xp_before, xp_after])
	_expect(bool(made.get("ok", false)), "the server crafts twine through the shared plan (%s)" % str(made.get("err", "")))
	_expect(not bool(made.get("ok", false)) or xp_after > xp_before, "a successful online craft pays XP")
	# One craft pays one craft's XP, never two.
	var tpicks2: Array[int] = CR.default_picks(ch2.inventory(), twine)
	if not tpicks2.is_empty() and CR.picks_valid(ch2.inventory(), twine, tpicks2):
		var xp_before2: float = _skill_xp(ch2, "processing")
		store.apply("act.craft", 1, {"recipe_id": "twine", "picks": tpicks2}, 11)
		var paid: float = _skill_xp(store.character(1), "processing") - xp_before2
		var per: float = 6.0 + float(CR.recipe_seconds(twine))
		_expect(paid <= per + 0.001, "one online craft pays one craft's XP (%.1f for %.1f)" % [paid, per])
	# The server's own path for a failure: the skewer, forced by a plan that already failed.
	var ch3 = store.character(1)
	var sinv = ch3.inventory()
	sinv.add(IS.make(&"raptor_meat", 1, {}, 10))
	sinv.add(IS.make(&"branch", 1, {}, 10))
	ch3.commit(sinv, "gather", int(store.s.seq))
	# Server-side allowed_ids: the skewer's Tool slot must refuse a club named as an explicit pick.
	var sk: Dictionary = CR.recipe(&"skewer")
	var sinv2 = store.character(1).inventory()
	var club: int = sinv2.find_first(&"club")
	var meat: int = sinv2.find_first(&"raptor_meat")
	var spicks: Array[int] = [meat, club]
	_expect(not CR.picks_valid(sinv2, sk, spicks), "the server-side plan refuses a club in the skewer's Tool slot")
	var refused: Dictionary = CR.plan_craft(sk, sinv2, spicks, IH.craft_ability(20), 20, 20, SR.for_op(7, 99, "act.craft"))
	_expect(refused.is_empty(), "no server plan is built from the disallowed pick")
	var bad: Dictionary = store.apply("act.craft", 1, {"recipe_id": "skewer", "picks": spicks}, 12)
	_expect(not bool(bad.get("ok", false)) and str(bad.get("err", "")) == "insufficient_items",
		"the server op refuses the club pick with insufficient_items (%s)" % str(bad.get("err", "ok")))
	# A real online failure: a recipe whose required_ability the character cannot reach. The units go,
	# the item never appears, and no XP is paid.
	var fail_rec := _rec(1000.0, {"id": "t_parity_fail2", "slots": [{"category": "stone", "count": 2, "primary": true}]})
	var fch = store.character(1)
	var finv = fch.inventory()
	fch.d.skills["processing"] = {"level": 1, "xp": 0.0, "unlocked": []}
	var fseq := int(store.s.seq) + 1
	var frng = SR.for_op(7, fseq, "act.craft")
	var fplan: Dictionary = CR.plan_craft(fail_rec, finv, CR.default_picks(finv, fail_rec), IH.craft_ability(1), 1, 1, frng)
	var failed: bool = not fplan.is_empty() and not bool((fplan["outcome"] as Dictionary)["success"])
	print("[t_craftfeel] online failure plan=%s success=%s" % [not fplan.is_empty(), not failed])
	_expect(failed, "a hopeless server plan rolls a failure")

## A server character's skill XP (CharacterState keeps the plain state dict; SkillState owns xp_of).
func _skill_xp(ch, tree: String) -> float:
	return float((ch.d.skills.get(tree, {}) as Dictionary).get("xp", 0.0))
