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
