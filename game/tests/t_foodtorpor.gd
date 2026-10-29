extends SceneTree
## FOODTORPOR acceptance (owner 2026-10-29):
##   food bag       food only, placement order kept, eating and auto-feed go in that order, save round trip
##   spoilage       meat -> Spoiled Meat, plant food -> Rot, spoiled lots leave the Food Bag, preserved never spoils
##   recipes        Spoiled Meat + Narcoberry -> Sedative; Rot composts into fertilizer
##   torpor         a blunt hit, a Sedative-coated hit and a Tranquilizer Dart each add torpor (dart > sedative > blunt)
##   knockout       only weak (stunned or <= 30 % HP) AND torpor past the threshold; then the net takes it
## Run: Godot --headless --path game --script res://tests/t_foodtorpor.gd -> "[t_foodtorpor] PASS".
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player
var DATA: Node
var IS: GDScript
var INV: GDScript
var SP: GDScript
var FT: GDScript
var CAP: GDScript
var CT: GDScript
var CR: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if ok:
		print("[t_foodtorpor] ok %s" % what)
	else:
		_fails.append(what)
		print("[t_foodtorpor] FAIL %s" % what)

func _run() -> void:
	DATA = root.get_node("Data")
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	SP = load("res://scripts/items/spoilage.gd")
	FT = load("res://scripts/pets/field_tame.gd")
	CAP = load("res://scripts/pets/capture_system.gd")
	CT = load("res://scripts/combat/combat_tuning.gd")
	CR = load("res://scripts/items/crafting.gd")
	_host = Node3D.new()
	_host.name = "TFoodTorpor"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 30.0)
	_player = kit["player"]
	await process_frame
	await physics_frame
	var guard := 0
	while _player.eat_session == null and guard < 240:
		await process_frame
		guard += 1
	_player.eat_session.set_process(false)
	_test_food_bag()
	_test_spoilage()
	await _test_eat_order()
	_test_food_bag_tab()
	_test_recipes()
	await _test_torpor()
	_finish()

func _finish() -> void:
	CT.reset_overrides()
	if _fails.is_empty():
		print("[t_foodtorpor] PASS")
		quit(0)
	else:
		print("[t_foodtorpor] FAIL count=%d" % _fails.size())
		quit(1)

func _idx(inv, id: StringName) -> int:
	return inv.find_first(id)

# ---------------------------------------------------------------- food bag

func _test_food_bag() -> void:
	var inv = INV.new(20)
	inv.add(IS.make(&"stone", 1))
	inv.add(IS.make(&"raw_meat", 1))
	inv.add(IS.make(&"berry", 1))
	inv.add(IS.make(&"mango", 1))
	_expect(not inv.food_bag_add(_idx(inv, &"stone")), "a stone cannot go in the Food Bag")
	_expect(inv.food_bag_add(_idx(inv, &"berry")) and inv.food_bag_add(_idx(inv, &"raw_meat")) and inv.food_bag_add(_idx(inv, &"mango")), "berry, raw meat and mango go in")
	_expect(not inv.food_bag_add(_idx(inv, &"berry")), "the same berry cannot go in twice")
	var order: Array = inv.food_bag_prune().map(func(i: int) -> StringName: return inv.slots[i].def_id)
	_expect(order == [&"berry", &"raw_meat", &"mango"], "the bag keeps placement order, not bag order (%s)" % [order])
	# Save: the uids, in order, through the extras dictionary and a JSON round trip; an old save has none.
	var back = INV.new(20)
	back.load_array(JSON.parse_string(JSON.stringify(inv.to_array())))
	back.extras_from_dict(JSON.parse_string(JSON.stringify(inv.extras_to_dict())))
	var back_order: Array = back.food_bag_prune().map(func(i: int) -> StringName: return back.slots[i].def_id)
	_expect(back_order == order, "save round trip keeps the Food Bag order (%s)" % [back_order])
	var old = INV.new(20)
	old.load_array(JSON.parse_string(JSON.stringify(inv.to_array())))
	var legacy: Dictionary = inv.extras_to_dict()
	legacy.erase("food_bag")
	old.extras_from_dict(legacy)
	_expect(old.food_bag.is_empty(), "a save without food_bag loads with an empty Food Bag")
	_expect(not INV.new(20).extras_to_dict().has("food_bag"), "an unused Food Bag writes no key (old saves unchanged)")
	inv.food_bag_remove(_idx(inv, &"raw_meat"))
	order = inv.food_bag_prune().map(func(i: int) -> StringName: return inv.slots[i].def_id)
	_expect(order == [&"berry", &"mango"], "taking raw meat out keeps the rest in order (%s)" % [order])
	var big = INV.new(60)
	for i in INV.FOOD_BAG_MAX + 3:
		big.add(IS.make(&"berry", 1))
	var added := 0
	for i in big.slot_count:
		if big.slots[i] != null and big.food_bag_add(i):
			added += 1
	_expect(added == INV.FOOD_BAG_MAX, "the Food Bag holds %d lots (took %d)" % [INV.FOOD_BAG_MAX, added])

# ---------------------------------------------------------------- spoilage

func _test_spoilage() -> void:
	var inv = INV.new(20)
	for id in [&"raw_meat", &"berry", &"dried_meat", &"grilled_meat", &"stone"]:
		inv.add(IS.make(id, 1))
	for id in [&"raw_meat", &"berry", &"grilled_meat"]:
		inv.food_bag_add(_idx(inv, id))
	var t0 := 1000000.0
	_expect(SP.tick(inv, t0) == 0, "the first tick only stamps")
	_expect(inv.slots[_idx(inv, &"raw_meat")].attributes.has(SP.ATTR) and not inv.slots[_idx(inv, &"dried_meat")].attributes.has(SP.ATTR), "raw meat is stamped, preserved meat is not")
	var meat_secs: float = SP.seconds_for(DATA.item(&"raw_meat"))
	var berry_secs: float = SP.seconds_for(DATA.item(&"berry"))
	_expect(meat_secs > 0.0 and berry_secs > meat_secs, "meat spoils sooner than berries (%.0f s < %.0f s)" % [meat_secs, berry_secs])
	SP.tick(inv, t0 + meat_secs + 1.0)
	_expect(_idx(inv, &"raw_meat") < 0 and _idx(inv, &"spoiled_meat") >= 0, "raw meat spoils into Spoiled Meat")
	_expect(_idx(inv, &"berry") >= 0, "the berry is still fresh")
	var order: Array = inv.food_bag_prune().map(func(i: int) -> StringName: return inv.slots[i].def_id)
	_expect(order == [&"berry", &"grilled_meat"], "spoiled meat left the Food Bag; the rest kept order (%s)" % [order])
	SP.tick(inv, t0 + berry_secs + 1.0)
	_expect(_idx(inv, &"berry") < 0 and _idx(inv, &"rot") >= 0, "the berry spoils into Rot")
	SP.tick(inv, t0 + 1.0e7)
	_expect(_idx(inv, &"dried_meat") >= 0 and _idx(inv, &"stone") >= 0, "preserved meat and non-food never spoil")
	_expect(_idx(inv, &"grilled_meat") < 0 and inv.count_of(&"spoiled_meat") == 2, "cooked meat spoils into Spoiled Meat too")
	_expect(inv.food_bag_prune().is_empty(), "nothing spoiled stays in the Food Bag")
	# The survivor's own clock: a lot past its time spoils on the next tick and stays in her bag.
	var p = _player
	p.inventory.add(IS.make(&"mango", 1))
	var mi: int = p.inventory.find_first(&"mango")
	p.inventory.food_bag_add(mi)
	p.inventory.slots[mi].attributes[SP.ATTR] = SP.now() - 1.0
	p.sim._spoil_cd = 0.0
	p.sim.tick_spoilage(0.1)
	_expect(p.inventory.find_first(&"mango") < 0 and p.inventory.find_first(&"rot") >= 0 and p.inventory.food_bag.is_empty(), "the player tick spoils the mango into Rot in her bag and drops it from the Food Bag")
	p.inventory.consume(&"rot", p.inventory.count_of(&"rot"))

# ---------------------------------------------------------------- eating order

func _eat_out() -> void:
	var guard := 0
	while _player.eat_session.eating and guard < 2000:
		_player.eat_session.advance(0.1)
		guard += 1

func _test_eat_order() -> void:
	var p = _player
	p.vitals.energy = p.vitals.max_energy * 0.2
	for id in [&"berry", &"mango", &"berry"]:
		p.inventory.add(IS.make(id, 1))
	# Put in mango first, then a berry: bag order is berry, mango, berry.
	var mango: int = p.inventory.find_first(&"mango")
	var berry: int = p.inventory.find_first(&"berry")
	p.inventory.food_bag_add(mango)
	p.inventory.food_bag_add(berry)
	var first_uid: String = p.inventory.slots[mango].uid
	var second_uid: String = p.inventory.slots[berry].uid
	_expect(p.actions.eat_food_bag(), "Eat from the Food Bag starts the queue")
	_expect(p.eat_session._instance != null and p.eat_session._instance.uid == first_uid, "it eats the mango first (put in first)")
	var guard := 0
	while p.eat_session.eating and p.eat_session._instance.uid == first_uid and guard < 2000:
		p.eat_session.advance(0.1)
		guard += 1
	_expect(p.eat_session.eating and p.eat_session._instance.uid == second_uid, "then the queue moves on to the berry")
	var left_idx: Array[int] = p.inventory.food_bag_prune()
	_expect(left_idx.size() == 1 and p.inventory.slots[left_idx[0]].uid == second_uid, "the eaten mango left the Food Bag")
	_eat_out()
	_expect(p.inventory.food_bag_prune().is_empty() and p.inventory.count_of(&"berry") == 1, "the berry not in the Food Bag is still in the bag")
	# Auto-feed takes the Food Bag first, over a quick-food pick.
	p.inventory.add(IS.make(&"mango", 1))
	p.inventory.set_quick_food(0, &"berry")
	p.inventory.food_bag_add(p.inventory.find_first(&"mango"))
	var bag_uid: String = p.inventory.food_bag[0]
	p.vitals.energy = p.vitals.max_energy * 0.1
	p.sim._autofeed_cd = 0.0
	p.sim.tick_autofeed(0.1)
	_expect(p.eat_session.eating and p.eat_session._instance.uid == bag_uid, "auto-feed eats the Food Bag's mango before the quick-food berry")
	_eat_out()
	p.inventory.set_quick_food(0, &"")

# ---------------------------------------------------------------- the bag panel's tab

func _test_food_bag_tab() -> void:
	var p = _player
	var ui = p.ui
	var BG: GDScript = load("res://scripts/ui/bag_grid.gd")
	_expect(BG.FILTERS.has("food_bag") and str(BG.FILTER_LABELS.get("food_bag", "")) == "Food Bag", "the bag panel has a Food Bag tab")
	_expect(ui.find_child("Filter_food_bag", true, false) != null, "the filter rail shows the Food Bag tab button")
	for id in [&"stone", &"mango", &"raw_meat"]:
		p.inventory.add(IS.make(id, 1))
	ui.visible = true
	ui.rebuild()
	var meat: int = p.inventory.find_first(&"raw_meat")
	var mango: int = p.inventory.find_first(&"mango")
	var stone: int = p.inventory.find_first(&"stone")
	ui._select(meat)
	var btn: Button = ui.find_child("FoodBagButton", true, false)
	_expect(btn != null and btn.visible and btn.text == "To Food Bag", "a food's card offers To Food Bag")
	btn.pressed.emit()
	ui._select(mango)
	btn.pressed.emit()
	ui._select(stone)
	_expect(not btn.visible, "a stone's card has no Food Bag button")
	ui._set_filter("food_bag")
	var shown: Array = BG.view_order(p.inventory, ui._grid.sort_key, ui._grid.filter_id).map(func(i: int) -> StringName: return p.inventory.slots[i].def_id)
	_expect(shown == [&"raw_meat", &"mango"], "the Food Bag tab lists raw meat, then mango, as put in (%s)" % [shown])
	var eat_btn: Button = ui.find_child("EatOrderButton", true, false)
	_expect(eat_btn != null and eat_btn.visible and not eat_btn.disabled, "the Food Bag tab offers Eat in order")
	ui._select(p.inventory.find_first(&"raw_meat"))
	_expect(btn.text == "Out of Food Bag", "a bagged food's card offers Out of Food Bag")
	btn.pressed.emit()
	shown = BG.view_order(p.inventory, "", "food_bag").map(func(i: int) -> StringName: return p.inventory.slots[i].def_id)
	_expect(shown == [&"mango"], "Out of Food Bag takes it out (%s)" % [shown])
	ui._set_filter("")
	ui.hide_ui()
	p.inventory.food_bag.clear()
	for id in [&"stone", &"mango", &"raw_meat"]:
		p.inventory.consume(id, p.inventory.count_of(id))

# ---------------------------------------------------------------- recipes

func _test_recipes() -> void:
	var p = _player
	var rec: Dictionary = DATA.recipes.get(&"sedative", {})
	_expect(not rec.is_empty(), "the Sedative recipe exists")
	p.inventory.add(IS.make(&"spoiled_meat", 1))
	p.inventory.add(IS.make(&"narcoberry", 2))
	var picks: Array[int] = CR.default_picks(p.inventory, rec)
	var out = CR.commit_outcome(p, rec, picks, {"success": true, "flawless": false, "rare": &""})
	_expect(out != null and p.inventory.count_of(&"sedative") == 1 and p.inventory.count_of(&"spoiled_meat") == 0 and p.inventory.count_of(&"narcoberry") == 0, "Spoiled Meat + 2 Narcoberry make a Sedative and are spent")
	var dart: Dictionary = DATA.recipes.get(&"tranquilizer_dart", {})
	p.inventory.add(IS.make(&"bone", 1))
	var dpicks: Array[int] = CR.default_picks(p.inventory, dart)
	CR.commit_outcome(p, dart, dpicks, {"success": true, "flawless": false, "rare": &""})
	_expect(p.inventory.count_of(&"tranquilizer_dart") == 3 and p.inventory.count_of(&"sedative") == 0, "a Sedative and a bone make 3 Tranquilizer Darts")
	var compost: Dictionary = DATA.recipes.get(&"rot_compost", {})
	var slot0: Dictionary = (compost.get("slots", [{}]) as Array)[0]
	_expect(str(compost.get("output", {}).get("id", "")) == "fruit_fertilizer" and str(slot0.get("category", "")) == "rot", "Rot composts into the Fruit Fertilizer field plots take")
	_expect(DATA.nature_families.has("narcoberry_bush") and (DATA.nature_families["narcoberry_bush"].get("harvest", {}) as Dictionary).has("narcoberry"), "a narcoberry bush yields Narcoberry")

# ---------------------------------------------------------------- torpor

func _spawn(species: StringName, hp_frac: float, at: Vector3):
	var c = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	c.position = at
	_host.add_child(c)
	c.spawn(DATA.creature(species))
	c.brain.process_mode = Node.PROCESS_MODE_DISABLED
	c.health.hp = c.health.max_hp * hp_frac
	return c

func _test_torpor() -> void:
	var p = _player
	CT.force_accuracy = 1.0
	CT.force_dodge = 0.0
	await physics_frame
	var raptor = _spawn(&"velociraptor", 0.9, p.global_position + Vector3(0, 0, -1.5))
	await physics_frame
	var club = IS.make(&"club", 1)
	# 1. a plain blunt hit
	raptor.health.hp = raptor.health.max_hp * 0.9
	p.hunt.land_hit(raptor, club)
	var blunt: float = raptor.torpor
	# 2. a Sedative-coated hit (blunt + the sedative charge)
	raptor.torpor = 0.0
	club.attributes["sedative_hits"] = 3
	raptor.health.hp = raptor.health.max_hp * 0.9
	p.hunt.land_hit(raptor, club)
	var sedated: float = raptor.torpor - blunt
	_expect(int(club.attributes.get("sedative_hits", 0)) == 2, "a landed hit spends one Sedative charge")
	# 3. a Tranquilizer Dart from the slingshot
	raptor.torpor = 0.0
	raptor.health.hp = raptor.health.max_hp * 0.9
	var shot = (load("res://scripts/combat/stone_projectile.gd") as GDScript).new()
	shot.source = p
	shot.weapon = IS.make(&"slingshot", 1)
	shot.damage = 10.0
	shot.torpor = CT.num("torpor", "dart", 30.0)
	_host.add_child(shot)
	shot.impact(raptor)
	var dart: float = raptor.torpor
	shot.queue_free()
	print("[t_foodtorpor] torpor per dose blunt=%.1f sedative=%.1f dart=%.1f" % [blunt, sedated, dart])
	_expect(blunt > 0.0 and sedated > blunt and dart > sedated, "dart > sedative > blunt (%.1f > %.1f > %.1f)" % [dart, sedated, blunt])
	# Coating with the context action spends a Sedative and arms 3 charges.
	p.inventory.add(IS.make(&"sedative", 1))
	p.inventory.add(club.duplicate_stack())
	var ci: int = p.inventory.find_first(&"club")
	p.inventory.slots[ci].attributes.erase("sedative_hits")
	p.inventory.equip_at(ci)
	p.hunt.stop()
	p.vitals.in_combat = false
	p.anim._busy = false  # the test swings above left the attack clip running
	var coated: bool = p.actions.coat_weapon(&"sedative")
	print("[t_foodtorpor] coat=%s weapon=%s hits=%s sedatives=%d" % [coated, p.inventory.equipped_weapon(), p.inventory.equipped_weapon().attributes if p.inventory.equipped_weapon() else {}, p.inventory.count_of(&"sedative")])
	_expect(coated and int(p.inventory.equipped_weapon().attributes.get("sedative_hits", 0)) == 3 and p.inventory.count_of(&"sedative") == 0, "Sedate coats the weapon for 3 hits")

	# Knockout: past the threshold at 90 % HP is not enough; weak + past the threshold is.
	raptor.torpor = 0.0
	raptor.health.hp = raptor.health.max_hp * 0.9
	raptor.add_torpor(raptor.torpor_max())
	_expect(not raptor.statuses.has(&"knockdown") and not FT.capture_window(raptor), "full torpor at 90 %% HP does not knock it out")
	raptor.torpor = 0.0
	raptor.health.hp = raptor.health.max_hp * 0.25
	raptor.add_torpor(raptor.torpor_max() * 0.4)
	_expect(not raptor.statuses.has(&"knockdown") and not FT.capture_window(raptor), "weak at 25 %% HP with 40 %% torpor is not knocked out")
	raptor.add_torpor(raptor.torpor_max() * 0.25)
	_expect(raptor.statuses.has(&"knockdown") and FT.capture_window(raptor), "weak + torpor past %.0f %% knocks it out (torpor %.0f)" % [100.0 * FT.torpor_ko_frac(), raptor.torpor])
	# Torpor holds while it is down, then drains once it is up and left alone.
	var held: float = raptor.torpor
	raptor.tick_torpor(30.0)
	_expect(is_equal_approx(raptor.torpor, held), "torpor holds while the animal is knocked out")
	# The server applies the same rule.
	_expect(FT.window_open(20.0, 100.0, false, 0.7) and not FT.window_open(20.0, 100.0, false, 0.5) and not FT.window_open(80.0, 100.0, false, 1.0), "server window_open: weak + torpor, both needed")
	# Capture after knockout (the net, then the pen flow takes over from the captured_animal stack).
	DATA.set_survival_unlocked(&"capture_technique_II", true)
	p.inventory.add(IS.make(&"capture_net_ii", 1))
	_expect(CAP.attempt(p, raptor, 1), "the net takes the knocked-out raptor")
	_expect(p.inventory.find_first(&"captured_animal") >= 0, "a captured_animal goes into the bag for the pen")
	DATA.set_survival_unlocked(&"capture_technique_II", false)
	var awake = _spawn(&"velociraptor", 0.9, p.global_position + Vector3(2, 0, -1.5))
	await physics_frame
	awake.torpor = awake.torpor_max()
	awake.tick_torpor(CT.num("torpor", "decay_delay_s", 6.0) + 2.0)
	_expect(awake.torpor < awake.torpor_max(), "torpor drains after the quiet delay (%.1f)" % awake.torpor)
	awake.queue_free()
