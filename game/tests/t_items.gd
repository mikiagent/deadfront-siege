extends SceneTree
## W1-ITEMS: item identity, tier and level scaling, tool-gated gathering, no lost items.
## Item scripts reference the Data autoload, so they load on the first frame after it exists
## (a --script run compiles this file before singletons).

var failures: Array[String] = []
var _done := false
var IS: GDScript
var INV: GDScript
var CR: GDScript
var SC: GDScript
var FOOD: GDScript
var NODE: PackedScene

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	CR = load("res://scripts/items/crafting.gd")
	SC = load("res://scripts/items/station_craft.gd")
	FOOD = load("res://scripts/items/food.gd")
	NODE = load("res://scenes/world/harvest_node.tscn")
	_test_identity()
	_test_merging()
	_test_scaling()
	_test_pick_gates()
	_test_regen_blocked_by_occupant()
	_test_yields()
	_test_crafted_level()
	_test_burn()
	_test_no_lost_items()
	_test_eat_cancel()
	if failures.is_empty():
		print("[t_items] PASS")
		quit(0)
	else:
		for f in failures:
			print("[t_items] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _test_identity() -> void:
	var a = IS.make(&"stone_knife_work", 1, {}, 5)
	a.stamp_identity("craft", "tester")
	var twin = a.duplicate_stack()
	twin.uid = "l-twin"
	_expect(a.uid.begins_with("l") and a.origin == "craft" and a.created_at > 0, "stamp_identity sets uid, origin, created_at")
	_expect(not a.can_merge_with(twin) and not twin.can_merge_with(a), "uid'd stacks never merge, even when identical")
	_expect(not IS.make(&"stone_knife_work", 1, {}, 5).can_merge_with(a), "plain stack does not merge into a uid'd one")
	var back = IS.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	_expect(back.uid == a.uid and back.origin == "craft" and back.creator == "tester" and back.created_at == a.created_at, "uid/origin/creator/created_at round-trip through JSON")
	var bag = INV.new(4)
	var s1 = IS.make(&"stone_shot", 3, {}, 1) # W2-INV: only stacking categories (ammunition) can share a slot
	s1.stamp_identity("loot")
	var s2 = IS.make(&"stone_shot", 3, {}, 1)
	s2.stamp_identity("loot")
	bag.add(s1)
	bag.add(s2)
	_expect(bag.used_slots() == 2, "uid'd stackable stacks keep separate slots")
	var old_row := {"id": "stone", "count": 4, "level": 1, "process_count": 0, "attributes": {"tint": "#8a8a8a", "material_tier": "stone"}, "flags": [], "durability": 0, "max_durability": 0}
	var reloaded: Dictionary = IS.from_dict(old_row).to_dict()
	_expect(reloaded.keys().size() == old_row.keys().size() and not reloaded.has("uid"), "old fungible save rows keep their exact shape")
	var hostile = IS.from_dict({"id": "stone_knife_work", "count": 1, "uid": 12345, "origin": null, "creator": null, "created_at": "soon"})
	var forged = IS.from_dict({"id": "stone_knife_work", "count": 1, "uid": "l1x", "origin": "admin_spawn", "created_at": -5})
	print("[t_items] hostile provenance uid='%s' origin='%s' creator='%s' created=%d; forged origin='%s' created=%d" % [hostile.uid, hostile.origin, hostile.creator, hostile.created_at, forged.origin, forged.created_at])
	_expect(hostile.origin == "" and hostile.creator == "" and hostile.created_at == 0, "null provenance loads as empty, never '<null>'")
	_expect(forged.origin == "" and forged.created_at == 0, "an origin outside the whitelist is blanked")
	_expect(hostile.uid == "" and forged.uid == "", "a non-string or non-format uid is blanked (got '%s', '%s')" % [hostile.uid, forged.uid])
	var future = IS.from_dict({"id": "stone_knife_work", "count": 1, "uid": "l1a", "origin": "craft", "created_at": 1e300})
	var shape = IS.from_dict({"id": "stone_knife_work", "count": 1, "uid": {"a": 1}, "created_at": null})
	print("[t_items] future created_at loads as %d (now %d), dict uid as '%s'" % [future.created_at, int(Time.get_unix_time_from_system()), shape.uid])
	_expect(future.created_at <= int(Time.get_unix_time_from_system()) + 86400, "created_at 1e300 clamps to now + slack (got %d)" % future.created_at)
	_expect(shape.uid == "", "a dict uid is not stringified into a fake one (got '%s')" % shape.uid)
	var newline = IS.from_dict({"id": "stone_knife_work", "count": 1, "uid": "i12\n"})
	_expect(newline.uid == "", "a uid with a trailing newline is blanked (got %s)" % var_to_str(newline.uid))
	# Splitting a uid'd stack must not leave both halves sharing one identity.
	var share = INV.new(4)
	var whole = IS.make(&"stone_shot", 4, {}, 1)
	whole.stamp_identity("loot")
	share.add(whole)
	var half = share.remove_at(0, 2)
	var moved: bool = half != null and share.slots[0] != null and half.uid != "" and half.uid != share.slots[0].uid and half.count == 2 and share.slots[0].count == 2
	print("[t_items] split uid kept='%s' taken='%s' shares=%s" % [share.slots[0].uid if share.slots[0] else "-", half.uid if half else "-", half != null and share.slots[0] != null and half.uid == share.slots[0].uid])
	_expect(moved, "splitting a uid'd stack re-mints the taken half's uid")

func _test_merging() -> void:
	var bag = INV.new(5)
	bag.add(IS.make(&"stone_shot", 3, {}, 1))
	bag.add(IS.make(&"stone_shot", 4, {}, 1))
	_expect(bag.used_slots() == 1 and bag.count_of(&"stone_shot") == 7, "fungible ammunition stacks still merge")
	var stone = INV.new(10)
	stone.add(IS.make(&"stone", 3, {}, 1))
	_expect(stone.used_slots() == 3, "stone no longer stacks: three units, three slots (owner 2026-10-20)")
	var fibre = INV.new(5)
	fibre.add(IS.make(&"stone_shot", 2, {"climate": "temperate", "level": 1}, 1))
	fibre.add(IS.make(&"stone_shot", 3, {"climate": "tropical", "level": 1}, 1))
	fibre.add(IS.make(&"stone_shot", 1, {"level": 1}, 1))
	_expect(fibre.used_slots() == 1 and fibre.count_of(&"stone_shot") == 6, "same-level temperate, tropical and fresh ammunition merge")
	var lv2 = IS.make(&"stone_shot", 1, {"climate": "tropical", "level": 2}, 2)
	_expect(not fibre.slots[0].can_merge_with(lv2), "a different level still keeps its own stack")

func _test_scaling() -> void:
	var l1 = IS.make(&"work_axe", 1, {}, 1)
	var l5 = IS.make(&"work_axe", 1, {}, 5)
	var ratio: float = l5.scaled_damage() / l1.scaled_damage()
	print("[t_items] work_axe L5/L1 = %.3f (dmg %.2f -> %.2f)" % [ratio, l1.scaled_damage(), l5.scaled_damage()])
	_expect(ratio >= 1.30, "work_axe L5/L1 >= 1.30 (got %.3f)" % ratio)
	var stone_k = IS.make(&"stone_knife", 1, {"material_tier": "stone"}, 10)
	var copper_k = IS.make(&"stone_knife", 1, {"material_tier": "copper"}, 10)
	var want := ProgressionScaling.tier_multiplier(&"copper") / ProgressionScaling.tier_multiplier(&"stone")
	var tier_ratio: float = copper_k.scaled_damage() / stone_k.scaled_damage()
	print("[t_items] copper/stone knife L10 = %.3f (tier ratio %.3f)" % [tier_ratio, want])
	_expect(absf(tier_ratio - want) < 0.001 and copper_k.scaled_damage() > stone_k.scaled_damage(), "copper knife out-damages stone knife by the tier ratio")
	var helm = IS.make(&"raid_helm", 1, {}, 10)
	_expect(is_equal_approx(helm.scaled_armor(), 300.0 * ProgressionScaling.level_multiplier(10)), "armor follows level x tier")
	var flint_pick = IS.make(&"work_pick", 1, {"material_tier": "flint"}, 1)
	var stone_pick = IS.make(&"work_pick", 1, {"material_tier": "stone"}, 1)
	_expect(flint_pick.max_durability > stone_pick.max_durability and flint_pick.durability == flint_pick.max_durability, "durability follows material tier")
	_expect(ProgressionScaling.material_tier(&"metal_shard", {"hardness": 3.0}) == &"flint", "untagged hardness maps onto the ladder")

## phys-node-01: a depleted node does not regrow under a body (the collider would wrap around it),
## and refills once the body steps away. A standalone node has no runtime parent, so it is added
## to the tree here; its _process is called directly in fixed steps.
func _test_regen_blocked_by_occupant() -> void:
	var rock = _node("Rock", &"stone")
	get_root().add_child(rock)
	rock.regen_seconds = 1.0
	var keep: int = rock.pool_units_left()
	rock.mark_gathered()
	rock.mark_gathered()
	while rock.pool_units_left() > 0:
		rock.mark_gathered()
	var empty: bool = rock.depleted and rock.pool_units_left() == 0
	var body := Node3D.new()
	body.add_to_group("player")
	get_root().add_child(body)
	body.global_position = rock.global_position
	for i in 40:
		rock._process(0.1)  # 4 s at regen 1 s: would have refilled twice without the occupancy rule
	var stayed: bool = rock.depleted and rock.pool_units_left() == 0
	body.global_position = rock.global_position + Vector3(6.0, 0.0, 0.0)
	for i in 50:
		rock._process(0.1)
	var refilled: bool = rock.pool_units_left() > 0
	print("[t_items] occupied regen: emptied=%s under body stayed=%s after body left refilled=%s (%d units)" % [empty, stayed, refilled, rock.pool_units_left()])
	_expect(empty, "a gathered-out node is depleted")
	_expect(stayed, "a depleted node does not regrow while a body stands on it")
	_expect(refilled, "a depleted node refills once the body moves away")
	body.free()
	rock.free()

## A harvest node of `family` with `item` as the active option.
func _node(family: String, item: StringName):
	var n = NODE.instantiate()
	n.setup(StringName("t_" + family), item, 1, 1, {"level": 1, "climate": "temperate"}, &"pick", Color.GRAY, 1.2, 8.0, family)
	var opts: Array = n.options()
	for i in opts.size():
		if str(opts[i]["item"]) == str(item):
			n.select_option(i)
	return n

func _bag_with_pick(tier: String):
	var bag = INV.new(20)
	if tier != "":
		bag.add(IS.make(&"work_pick", 1, {"material_tier": tier}, 1))
	return bag

func _test_pick_gates() -> void:
	var bare = INV.new(20)
	var copper = _node("CopperOreNode", &"copper_ore")
	var iron = _node("BlackIronNode", &"black_iron")
	var copper_why: String = copper.can_gather(bare)
	var iron_why: String = iron.can_gather(bare)
	print("[t_items] bare hands: copper_ore='%s' black_iron='%s'" % [copper_why, iron_why])
	_expect(copper_why == "needs obsidian pick", "copper_ore refuses bare hands with 'needs obsidian pick' (got '%s')" % copper_why)
	_expect(iron_why == "needs copper pick", "black_iron refuses bare hands with 'needs copper pick' (got '%s')" % iron_why)
	_expect(copper.can_gather(_bag_with_pick("flint")) == "needs obsidian pick", "a flint pick is below copper's tier")
	_expect(copper.can_gather(_bag_with_pick("obsidian")) == "", "an obsidian pick mines copper")
	var mixed = INV.new(20)
	mixed.add(IS.make(&"work_pick", 1, {"material_tier": "stone"}, 1))
	mixed.add(IS.make(&"work_pick", 1, {"material_tier": "copper"}, 1))
	_expect(iron.can_gather(mixed) == "" and mixed.equipped_gather_tool().material_tier() == &"copper", "the qualifying pick is the one in use (W2-INV: auto picks the best)")
	var spare = INV.new(20)
	spare.add(IS.make(&"work_pick", 1, {"material_tier": "copper"}, 1))
	spare.add(IS.make(&"work_pick", 1, {"material_tier": "obsidian"}, 1))
	spare.set_equipped_tool_index(1)
	var spare_why: String = copper.can_gather(spare)
	print("[t_items] copper node with obsidian pick held, copper pick in bag: why='%s' held=%s" % [spare_why, spare.slots[spare.equipped_tool_index].material_tier()])
	_expect(spare_why == "" and spare.equipped_tool_index == 1, "a held pick that meets the minimum tier is not swapped for a better one")
	var rock = _node("Rock", &"stone")
	_expect(rock.can_gather(bare) == "", "loose stone still gathers bare-handed")
	var copper_stone = _node("CopperOreNode", &"stone")
	_expect(copper_stone.can_gather(bare) == "", "stone at an ore node stays bare-handed")
	var picked = _bag_with_pick("flint")
	_expect(rock.can_gather(picked) == "" and rock.gather_seconds < rock._base_seconds, "a held pick works loose stone faster")
	var flint = _node("FlintNode", &"flint")
	_expect(flint.can_gather(bare) == "needs stone pick", "flint needs at least a stone pick")
	var at_min: float = flint.seconds_for(_bag_with_pick("stone"))
	var flint_s: float = flint.seconds_for(_bag_with_pick("flint"))
	print("[t_items] flint node seconds: stone pick (minimum tier) %.2f, flint pick %.2f, base %.2f" % [at_min, flint_s, flint._base_seconds])
	_expect(flint_s < at_min and at_min <= flint._base_seconds, "a flint pick gathers flint faster than the minimum tier")
	_expect(flint._collision_size().y <= 1.3, "rock collider height comes from the manifest span")
	for n in [copper, iron, rock, copper_stone, flint]:
		n.free()

func _test_yields() -> void:
	var rock = _node("Rock", &"stone")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var total := 0
	var in_range := true
	var climate_free := true
	for i in 200:
		var s = rock.roll_yield(rng)
		total += s.count
		in_range = in_range and s.count >= 2 and s.count <= 4
		climate_free = climate_free and not s.attributes.has("climate")
	var mean := float(total) / 200.0
	print("[t_items] 200 Rock rolls mean=%.2f in_range=%s" % [mean, in_range])
	_expect(in_range and mean > 2.4, "Rock stone rolls stay in [2,4] with mean > 2.4 (mean %.2f)" % mean)
	_expect(climate_free, "gathered stacks carry no climate stamp")
	rock.free()

func _test_crafted_level() -> void:
	var mats: Array[int] = [40, 40, 40]
	var at0 := ProgressionScaling.crafted_level(mats, 60, 0)
	var at1 := ProgressionScaling.crafted_level(mats, 60, 1)
	print("[t_items] crafted level mats40 skill0=%d skill1=%d skill20=%d skill60=%d" % [at0, at1, ProgressionScaling.crafted_level(mats, 60, 20), ProgressionScaling.crafted_level(mats, 60, 60)])
	_expect(at0 <= at1 and at0 == 1, "crafted_level at skill 0 <= skill 1 (no 60 fallback)")
	var prev := 0
	var monotonic := true
	for skill in 61:
		var lvl := ProgressionScaling.crafted_level(mats, 60, skill)
		monotonic = monotonic and lvl >= prev
		prev = lvl
	_expect(monotonic and prev == 40, "crafted level cap rises monotonically with skill")
	var knife: Dictionary = CR.recipe(&"improvised_stone_knife")
	_expect(CR.preview_level(INV.new(20), knife) == -1, "preview_level is -1 for invalid picks")

func _test_burn() -> void:
	var grill: Dictionary = CR.recipe(&"stone_grill")
	var prev := 2.0
	var falling := true
	for skill in 61:
		var c: float = CR.burn_chance(grill, skill)
		falling = falling and c < prev
		prev = c
	print("[t_items] burn chance skill0=%.3f skill60=%.3f" % [CR.burn_chance(grill, 0), CR.burn_chance(grill, 60)])
	_expect(falling and CR.burn_chance(grill, 0) > CR.burn_chance(grill, 60), "burn chance falls monotonically from cooking 0 to 60")
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	var same := true
	var burns := 0
	for i in 200:
		var x: bool = CR.rolls_burn(grill, 0, a)
		same = same and x == CR.rolls_burn(grill, 0, b)
		burns += 1 if x else 0
	_expect(same and burns > 0 and burns < 200, "burn rolls reproduce with a seeded RNG")
	_expect(CR.burn_chance(CR.recipe(&"skewer"), 0) == 0.0, "recipes without burn_on_fail never burn")

## A 20-slot bag whose every slot is taken: knife inputs (2 each) plus distinct berries.
func _full_bag():
	var bag = INV.new(20)
	bag.add(IS.make(&"stone", 2, {}, 1))
	bag.add(IS.make(&"branch", 2, {}, 1))
	bag.add(IS.make(&"twine", 2, {}, 1))
	var lvl := 1
	while bag.used_slots() < 20:
		bag.add(IS.make(&"berry", 1, {}, lvl))
		lvl += 1
	return bag

func _test_no_lost_items() -> void:
	var knife: Dictionary = CR.recipe(&"improvised_stone_knife")
	var bag = _full_bag()
	var before: Array = bag.to_array()
	var picks: Array[int] = CR.default_picks(bag, knife)
	_expect(CR.picks_valid(bag, knife, picks), "full-bag fixture can otherwise make the knife")
	# W2-INV: inputs are one instance per slot, so spending them frees the slot a 1-slot output needs.
	_expect(CR.output_fits(bag, knife, picks), "a full bag crafts: the consumed instances free a slot")
	_expect(bag.to_array() == before, "the fit check leaves the bag untouched")
	# A full bag still refuses when the output needs more slots than the inputs free: sashimi makes
	# 3 instances from 1 meat (sec-loss-08; on the hand path output_fits is the only loss guard).
	var sashimi: Dictionary = CR.recipe(&"sashimi")
	var meat = INV.new(20)
	meat.add(IS.make(&"raw_meat", 1, {}, 1))
	var lvl := 1
	while meat.used_slots() < 20:
		meat.add(IS.make(&"berry", 1, {}, lvl))
		lvl += 1
	var meat_before: Array = meat.to_array()
	var mp: Array[int] = CR.default_picks(meat, sashimi)
	_expect(CR.picks_valid(meat, sashimi, mp) and not CR.output_fits(meat, sashimi, mp), "a full bag refuses sashimi (3 out, 1 slot freed) before consuming")
	_expect(meat.to_array() == meat_before, "the refused fit check leaves the bag untouched")
	meat.remove_at(19, 1)
	_expect(not CR.output_fits(meat, sashimi, CR.default_picks(meat, sashimi)), "one free slot is still one short for sashimi")
	meat.remove_at(18, 1)
	_expect(CR.output_fits(meat, sashimi, CR.default_picks(meat, sashimi)), "two free slots and the meat's own let sashimi through")
	# StationCraft no longer parks refunds anywhere: no meta store may come back.
	var methods: Array = SC.get_script_method_list().map(func(m: Dictionary) -> String: return str(m["name"]))
	_expect(not "collect_held" in methods and not "HELD_META" in SC.get_script_constant_map(), "no volatile held-item store remains")

## A poisoned raw meal always hits, so the outcome (not just "a roll happened") is checked.
func _test_eat_cancel() -> void:
	var ES: GDScript = load("res://scripts/items/eat_session.gd")
	var out := {}
	for at in [0.6, 0.4]:
		var meal = IS.make(&"raw_meat", 1)
		meal.set_flag(&"poisoned", true)
		var es = ES.new()
		es._stack_snapshot = meal
		es.eating = true
		es.progress = at
		es._cancel_with_full()
		out[at] = es.last_risk
		es.free()
	print("[t_items] poisoned raw meal cancelled: at 60%% risk='%s', at 40%% risk='%s'" % [out[0.6], out[0.4]])
	_expect(out[0.6] == &"stomachache", "cancelling a poisoned raw meal at 60% gives a stomachache")
	_expect(out[0.4] == &"", "cancelling before half gives nothing")
