extends SceneTree
## COOKROLES acceptance (spec 08 §2-4): a cooking recipe's slots have roles (main / topping / sauce /
## broth / spice / support) and per-slot inheritance flags; the finished dish carries exactly what
## those flags allow from the exact ingredient INSTANCES it was cooked from.
##   roles        a spice cannot fill a main slot (the role's category list and its exclude list), and a
##                recipe without roles keeps today's category-only behaviour
##   inheritance  the main's flagged traits and in-place cooking history pass; the topping's do not; an
##                ingredient that opts out passes nothing; a second carrier does not add up or average
##   instances    two different meat instances make two different dishes, and the bag loses exactly the
##                instances the plan picked (the other instance of the same def stays)
##   cancel       a cancelled station craft leaves the bag untouched (inputs never leave before finish)
##   foodfx       the inherited trait moves the dish's real FOODFX bundle (energy, fullness) and the role
##                bonus grants its buff; the same attribute on a raw ingredient moves nothing
##   save         a dish's inherited record and its evaluated effects survive save sanitize -> reload
## Run: Godot --headless --path game --script res://tests/t_cookroles.gd -> "[t_cookroles] PASS", 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player: Node
var _world: Node
var IS: GDScript
var INV: GDScript
var CR: GDScript
var ROLES: GDScript
var FX: GDScript
var FOOD: GDScript
var SAN: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	print("[t_cookroles] %s %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_fails.append(what)

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	CR = load("res://scripts/items/crafting.gd")
	ROLES = load("res://scripts/items/cook_roles.gd")
	FX = load("res://scripts/items/food_effects.gd")
	FOOD = load("res://scripts/items/food.gd")
	SAN = load("res://scripts/core/save_sanitizer.gd")
	_host = Node3D.new()
	_host.name = "TCookRoles"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 30.0)
	_player = kit["player"]
	_world = root.get_node("World")
	_world.player_name = "Cook"
	_player.skills.trees["cooking"] = {"level": 40, "xp": 0.0, "unlocked": []}
	var grill: Node3D = load("res://scripts/world/craft_station.gd").make(&"stone_grill")
	grill.position = Vector3(1, 0, 1)
	_host.add_child(grill)
	var pot: Node3D = load("res://scripts/world/craft_station.gd").make(&"crock_pot")
	pot.position = Vector3(2, 0, 1)
	_host.add_child(pot)
	var fire: Node3D = load("res://scripts/world/bonfire.gd").make(&"bonfire")
	fire.position = Vector3(1, 0, 2)
	_host.add_child(fire)
	var bench: Node3D = load("res://scripts/world/craft_station.gd").make(&"workbench")
	bench.position = Vector3(-1, 0, 1)
	_host.add_child(bench)
	_player.global_position = Vector3(1, 1, 1.4)
	await process_frame
	await physics_frame
	_test_roles()
	_test_inheritance()
	_test_first_wins()
	_test_instances()
	_test_examples()
	_test_cancel()
	await _test_foodfx()
	_test_save()
	_finish()

func _finish() -> void:
	if _fails.is_empty():
		print("[t_cookroles] PASS")
		quit(0)
	else:
		print("[t_cookroles] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- helpers

func _clear_bag() -> void:
	for i in _player.inventory.slot_count:
		_player.inventory.slots[i] = null
	_player.inventory.changed.emit()

## A fresh bag holding exactly these instances. Each row: [def_id, level, attributes, flags].
## Returns the instances as the BAG holds them (Inventory.add places copies and spends the caller's).
func _bag(rows: Array) -> Array:
	_clear_bag()
	var made: Array = []
	for row in rows:
		var attrs: Dictionary = row[2] if row.size() > 2 else {}
		var s = IS.make(StringName(str(row[0])), 1, attrs, int(row[1]))
		if row.size() > 3:
			for f: Variant in row[3]:
				s.set_flag(StringName(str(f)), true)
		s.stamp_identity("loot", "tester")
		var uid: String = s.uid
		_player.inventory.add(s)
		var placed = null
		for i in _player.inventory.slot_count:
			var held = _player.inventory.slots[i]
			if held != null and held.uid == uid:
				placed = held
				break
		made.append(placed)
	return made

func _index_of(stack) -> int:
	for i in _player.inventory.slot_count:
		if _player.inventory.slots[i] == stack:
			return i
	return -1

## Bag indices as the typed array Crafting takes (an untyped literal is refused by its signature).
func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in values:
		out.append(int(v))
	return out

## A roled recipe's default picks, as bag indices.
func _picks(rid: StringName) -> Array[int]:
	var rec: Dictionary = CR.recipe(rid)
	var out: Array = CR.default_picks(_player.inventory, rec)
	var typed: Array[int] = []
	for v: Variant in out:
		typed.append(int(v))
	return typed

# ---------------------------------------------------------------- 1. roles

func _test_roles() -> void:
	print("[t_cookroles] -- roles")
	var stew: Dictionary = CR.recipe(&"roled_spiced_stew")
	var grill: Dictionary = CR.recipe(&"roled_grilled_meat")
	_expect(not stew.is_empty() and not grill.is_empty(), "the roled recipes load from data (spiced stew, grilled cut)")
	_expect(ROLES.is_roled(grill) and not ROLES.is_roled(CR.recipe(&"camp_stew")), "a roled recipe is recognised; an older recipe is not roled")
	# A spice_herb is a herb and a spice: the main role must refuse it either way.
	var spice = IS.make(&"spice_herb", 1)
	var meat = IS.make(&"raw_meat", 1)
	var main_slot: Dictionary = grill["slots"][0]
	_expect(str(ROLES.slot_role(main_slot)) == "main", "the grill's first slot declares the main role")
	_expect(not ROLES.role_accepts(main_slot, spice), "a spice cannot fill a main slot")
	_expect(ROLES.role_accepts(main_slot, meat), "raw meat fills the main slot")
	_expect(not ROLES.role_accepts(stew["slots"][1], meat), "meat cannot fill a spice slot")
	var roast_slots: Array = CR.recipe(&"roled_herb_roast")["slots"]
	_expect(not ROLES.role_accepts(roast_slots[1], spice), "a topping slot refuses a spice-category herb")
	_expect(ROLES.role_accepts(roast_slots[2], IS.make(&"branch", 1)), "the support slot takes the stick")
	# Through the real planner: only a spice and water in the bag -> no valid plan for the stew.
	_bag([["spice_herb", 1], ["water_bucket", 1]])
	var picks := _picks(&"roled_spiced_stew")
	_expect(not CR.picks_valid(_player.inventory, stew, picks), "the stew cannot be planned with no main ingredient")
	var forced: Array[int] = [0, 0, 1]
	var out = CR.craft(_player, stew, forced)
	_expect(out == null, "naming the spice as the main ingredient makes nothing")
	# A recipe without roles is unchanged: its category alone decides.
	var old: Dictionary = CR.recipe(&"camp_stew")
	var old_slots: Array = old["slots"]
	_expect(ROLES.role_accepts(old_slots[0], IS.make(&"raw_meat", 1)), "a recipe without roles keeps its category-only slots")

# ---------------------------------------------------------------- 2. inheritance

func _test_inheritance() -> void:
	print("[t_cookroles] -- inheritance")
	var rec: Dictionary = CR.recipe(&"roled_grilled_meat")
	# A rich cut passes; the same meat with a trait the main role refuses for rare keys stays out.
	var rich = _bag([["raw_meat", 10, {"rich_cut": 2, "black_sheen": 1}]])[0]
	_player.global_position = Vector3(1, 1, 1.4)
	var dish = CR.craft(_player, rec, _ints([0]))
	_expect(dish != null, "the grilled cut cooks from a rich meat instance")
	if dish == null:
		return
	_expect(int(dish.attributes.get("rich_cut", 0)) == 2, "the main's rich_cut trait passes into the dish (lv 2)")
	var refused: Dictionary = FX.evaluate(dish).get("discarded", {}) as Dictionary
	_expect(refused.has("black_sheen"), "the bundle reports the refused rare trait as discarded")
	_expect(not dish.attributes.has("black_sheen"), "a rare trait not opted into stays out of the dish")
	var role_rows: Array = dish.attributes.get("cooked_roles", [])
	_expect(role_rows.size() == 1 and str((role_rows[0] as Dictionary).get("role", "")) == "main", "the dish records the slot it inherited from")
	_expect((role_rows[0] as Dictionary).get("traits", {}).has("rich_cut"), "the record names the inherited trait")
	_expect((role_rows[0] as Dictionary).get("dropped", {}).has("black_sheen"), "the record names the refused rare trait")
	# The player sees it: the food card names what came in and what was kept out (spec 08 §8).
	var card: String = FOOD.inspector_text(dish)
	_expect(card.find("Rich Cut 2") >= 0, "the food card names the inherited trait: %s" % card.replace("\n", " | ").left(220))
	_expect(card.find("kept out") >= 0, "and the trait the recipe refused")
	# In-place history passes (and is what fuels the drying/smoking properties).
	var dried = _bag([["dried_meat", 12, {}, []]])[0]
	dried.attributes["processed"] = ["dry"]
	var from_dried = CR.craft(_player, rec, _ints([0]))
	_expect(from_dried != null and (from_dried.attributes.get("processed", []) as Array).has("dry"), "the main's in-place cooking history passes into the dish")
	# A topping inherits nothing but grants its own bonus.
	var glazed: Dictionary = CR.recipe(&"roled_berry_glazed_meat")
	_bag([["raw_meat", 10, {"rich_cut": 1}], ["berry", 30, {"sweet_tooth": 3}]])
	var glaze_dish = CR.craft(_player, glazed, _ints([0, 1]))
	_expect(glaze_dish != null, "the berry-glazed cut cooks")
	if glaze_dish:
		_expect(int(glaze_dish.attributes.get("rich_cut", 0)) == 1, "the main still passes its own trait")
		_expect(not glaze_dish.attributes.has("sweet_tooth"), "the topping's own trait does not pass")
		_expect((glaze_dish.attributes.get("cooked_buffs", []) as Array).has("fruit_glaze"), "the fruit topping adds its role bonus")
	# A slot that opts out of inheritance passes nothing, though the recipe does inherit.
	var soup: Dictionary = CR.recipe(&"roled_broth_soup")
	_bag([["raw_meat", 10, {"rich_cut": 3}], ["water_bucket", 1]])
	var soup_dish = CR.craft(_player, soup, _ints([0, 1]))
	_expect(soup_dish != null, "the broth soup cooks")
	if soup_dish:
		_expect(not soup_dish.attributes.has("rich_cut"), "a main slot that opts out passes no trait")
		_expect((soup_dish.attributes.get("cooked_roles", []) as Array).size() == 2, "both slots are recorded, inherited or not")
	# A recipe that opts out at the top level passes nothing at all.
	var salad: Dictionary = CR.recipe(&"roled_salad")
	_player.global_position = Vector3(-1, 1, 1.6)  # the salad's workbench
	_bag([["berry", 40, {"sweet_tooth": 5}], ["herb_leaf", 1]])
	var salad_dish = CR.craft(_player, salad, _ints([0, 1]))
	_expect(salad_dish != null and not salad_dish.attributes.has("sweet_tooth"), "a recipe that does not inherit keeps the rare berry's trait out")
	_expect(salad_dish != null and (salad_dish.attributes.get("cooked_buffs", []) as Array).has("fruit_glaze"), "without inheritance the topping still adds its bonus (spec 08 s3)")

# ---------------------------------------------------------------- 3. no averaging, no stacking

func _test_first_wins() -> void:
	print("[t_cookroles] -- first wins")
	# A synthetic two-count main slot: the rule is per slot, so a recipe that ever had one must not
	# average two levels or add two values.
	var rec := {
		"id": "cookroles_probe", "display_name": "Probe", "skill": "cooking", "max_level": 60,
		"inherit": true,
		"slots": [
			{"category": "meat", "count": 2, "primary": true, "role": "main"},
		],
		"output": {"id": "grilled_meat", "count": 1},
		"seconds": 1.0, "process_step": "grill", "process_add": 1,
	}
	_bag([["raw_meat", 10, {"rich_cut": 1}], ["raw_meat", 10, {"rich_cut": 4}]])
	var parts: Array[Dictionary] = CR.plan_parts_flat(_player.inventory, rec, _ints([0]))
	var got: Dictionary = ROLES.collect(rec, _player.inventory, parts)
	_expect(int((got["traits"] as Dictionary).get("rich_cut", 0)) == 1, "two carriers of one trait keep the first instance's level, not the sum or mean")
	var rows: Array = got["roles"]
	_expect(rows.size() == 2 and (rows[1] as Dictionary).get("dropped", {}).has("rich_cut"), "the second carrier is recorded as dropped")

# ---------------------------------------------------------------- 4. exact instances

func _test_instances() -> void:
	print("[t_cookroles] -- instances")
	_player.global_position = Vector3(1, 1, 1.4)
	var rec: Dictionary = CR.recipe(&"roled_grilled_meat")
	var made := _bag([["raw_meat", 10, {"rich_cut": 2}], ["raw_meat", 10, {}]])
	var rich = made[0]
	var plain = made[1]
	var plain_dish = CR.craft(_player, rec, _ints([1]))
	var plain_bundle: Dictionary = FX.evaluate(plain_dish)
	var rich_dish = CR.craft(_player, rec, _ints([0]))
	var rich_bundle: Dictionary = FX.evaluate(rich_dish)
	_expect(plain_dish != null and rich_dish != null, "both dishes cook")
	if plain_dish == null or rich_dish == null:
		return
	_expect(rich_dish.attributes.has("rich_cut") and not plain_dish.attributes.has("rich_cut"), "two meat instances make two differently-inherited dishes")
	_expect(float(rich_bundle["latent_energy"]) > float(plain_bundle["latent_energy"]), "the rich dish carries more Energy (%.2f vs %.2f)" % [float(rich_bundle["latent_energy"]), float(plain_bundle["latent_energy"])])
	_expect(float(rich_bundle["fullness"]) > float(plain_bundle["fullness"]), "and more Fullness (%.2f vs %.2f)" % [float(rich_bundle["fullness"]), float(plain_bundle["fullness"])])
	_expect(float(rich_dish.level) == float(plain_dish.level), "the difference is the trait, not the level")
	# The bundle the panel and the eat share names both sides (spec 08 §8: inherited AND discarded).
	_expect(int((rich_bundle.get("inherited", {}) as Dictionary).get("rich_cut", 0)) == 2, "the bundle reports the inherited trait")
	_expect((plain_bundle.get("inherited", {}) as Dictionary).is_empty(), "a plain dish reports nothing inherited")
	# Consumption: exactly the picked instances leave the bag.
	_bag([["raw_meat", 10, {"rich_cut": 1}], ["raw_meat", 10, {"gamey_cut": 1}]])
	var first = _player.inventory.slots[0]
	var second = _player.inventory.slots[1]
	var before: int = _player.inventory.count_of(&"raw_meat")
	var dish = CR.craft(_player, rec, _ints([1]))
	_expect(dish != null and int(dish.attributes.get("gamey_cut", 0)) == 1, "the dish inherits from the instance that was picked, not the other one")
	_expect(_player.inventory.count_of(&"raw_meat") == before - 1, "cooking spends exactly one unit")
	var left = _player.inventory.slots[0]
	_expect(left == first and second.uid != left.uid, "the instance left in the bag is the one the plan did not pick")

# ---------------------------------------------------------------- 4b. the example recipes

## Spec 08 §3/§6: the example dishes are data, each listed at the station its slots name, each
## spending exactly the instances picked and no more.
func _test_examples() -> void:
	print("[t_cookroles] -- example recipes")
	var rows := [
		["roled_grilled_meat", "stone_grill"], ["roled_berry_glazed_meat", "stone_grill"],
		["roled_broth_soup", "crock_pot"], ["roled_spiced_stew", "crock_pot"],
		["roled_herb_roast", "bonfire"], ["roled_salad", "workbench"],
	]
	var at := {"stone_grill": Vector3(1, 1, 1.4), "crock_pot": Vector3(2, 1, 1.4),
		"bonfire": Vector3(1, 1, 2.4), "workbench": Vector3(-1, 1, 1.6)}
	for row: Array in rows:
		var rid := StringName(str(row[0]))
		var rec: Dictionary = CR.recipe(rid)
		_expect(not rec.is_empty() and CR.station_id(rec) == str(row[1]), "%s is a cooking recipe at %s" % [rid, row[1]])
		var listed := false
		for listed_rec: Variant in CR.recipes_for_station(StringName(str(row[1]))):
			if str((listed_rec as Dictionary).get("id", "")) == str(rid):
				listed = true
		_expect(listed, "%s appears on its station's recipe list" % rid)
		var roles_found: Array = []
		for slot: Variant in rec.get("slots", []):
			roles_found.append(ROLES.slot_role(slot as Dictionary))
		_expect(not roles_found.has(""), "%s gives every slot a role (%s)" % [rid, str(roles_found)])
	# The stew: one meat, one spice, one water — and exactly those three units leave the bag.
	_player.global_position = at["crock_pot"]
	_bag([["raw_meat", 15, {"rich_cut": 1}], ["spice_herb", 1], ["water_bucket", 1]])
	var stew: Dictionary = CR.recipe(&"roled_spiced_stew")
	var picks := _picks(&"roled_spiced_stew")
	_expect(picks.size() == 3 and CR.picks_valid(_player.inventory, stew, picks), "the spiced stew plans from meat, spice and water")
	var stew_dish = CR.craft(_player, stew, picks)
	_expect(stew_dish != null, "the spiced stew cooks")
	if stew_dish:
		_expect(int(stew_dish.attributes.get("rich_cut", 0)) == 1, "the stew inherits the main's trait")
		_expect((stew_dish.attributes.get("cooked_buffs", []) as Array).has("spice_warmth"), "the spice adds its own bonus")
		_expect(_player.inventory.count_of(&"raw_meat") == 0 and _player.inventory.count_of(&"spice_herb") == 0 and _player.inventory.count_of(&"water_bucket") == 0, "cooking spent exactly the three picked instances")
		_expect(_player.inventory.count_of(&"camp_stew") == 1, "and made the stew")
	# A topping instance the player did not pick survives (spec 08 §1/§8: exact selection).
	_player.global_position = at["stone_grill"]
	_bag([["raw_meat", 12, {}], ["berry", 42, {"sweet_tooth": 2}], ["berry", 5, {}]])
	var glazed: Dictionary = CR.recipe(&"roled_berry_glazed_meat")
	var gp := _picks(&"roled_berry_glazed_meat")
	_expect(gp.size() == 2 and CR.picks_valid(_player.inventory, glazed, gp), "the berry-glazed cut plans")
	# Name the ordinary berry as the topping: the rare one must stay.
	var chosen := -1
	for i in _player.inventory.slot_count:
		var st = _player.inventory.slots[i]
		if st != null and st.def_id == &"berry" and int(st.level) == 5:
			chosen = i
	if chosen >= 0:
		gp[1] = chosen
	var dish = CR.craft(_player, glazed, gp)
	_expect(dish != null, "the glazed cut cooks with the chosen topping")
	var rare_left := false
	for st2 in _player.inventory.slots:
		if st2 != null and st2.def_id == &"berry" and int(st2.level) == 42:
			rare_left = true
	_expect(rare_left, "the rare berry the player did not pick is still in the bag")

# ---------------------------------------------------------------- 5. cancel refunds all

func _test_cancel() -> void:
	print("[t_cookroles] -- cancel")
	_bag([["raw_meat", 10, {"rich_cut": 1}], ["herb_leaf", 5], ["branch", 1]])
	var before: Array = []
	for s in _player.inventory.slots:
		before.append("%s/%d/%s" % [str(s.def_id), s.level, str(s.attributes)] if s else "-")
	var sc = _player.station_craft
	_expect(sc != null, "the survivor has the station craft layer")
	if sc == null:
		return
	_player.global_position = Vector3(1, 1, 2.4)  # beside the bonfire
	var started: bool = sc.begin(&"roled_herb_roast")
	_expect(started, "the herb roast starts at the bonfire")
	sc._start_craft_cycle()
	_expect(bool(sc.crafting), "the station craft is running")
	sc.cancel_and_refund()
	var after: Array = []
	for s in _player.inventory.slots:
		after.append("%s/%d/%s" % [str(s.def_id), s.level, str(s.attributes)] if s else "-")
	_expect(str(before) == str(after), "a cancelled cook leaves the bag exactly as it was")
	_expect(not bool(sc.crafting), "the cancel ends the craft")

# ---------------------------------------------------------------- 6. FOODFX when eaten

func _test_foodfx() -> void:
	print("[t_cookroles] -- food effects")
	_player.global_position = Vector3(1, 1, 1.4)
	# A raw ingredient that merely carries the attribute changes nothing.
	var raw_plain = IS.make(&"raw_meat", 1)
	var raw_rich = IS.make(&"raw_meat", 1, {"rich_cut": 3})
	_expect(is_equal_approx(float(FX.evaluate(raw_plain)["latent_energy"]), float(FX.evaluate(raw_rich)["latent_energy"])), "a raw ingredient's trait alone moves no FOODFX number")
	# The eaten dish: the inherited trait's Energy split and the role bonus buff.
	_bag([["raw_meat", 20, {"rich_cut": 2}]])
	var dish = CR.craft(_player, CR.recipe(&"roled_grilled_meat"), _ints([0]))
	_expect(dish != null, "a rich grill cooks for the eat")
	if dish == null:
		return
	var bundle: Dictionary = FX.preview(dish, _player)
	_player.statuses.clear_id(&"full")
	_player.vitals.energy = 10.0
	var before: float = _player.vitals.energy
	# The bag holds its own copy of the crafted dish; find the instance that is really there.
	var idx: int = _player.inventory.find_first(dish.def_id)
	var started: bool = _player.begin_eat_slot(idx)
	var guard := 0
	while _player.eat_session.eating and guard < 400:
		_player.eat_session.advance(0.1)
		guard += 1
	var gained: float = _player.vitals.energy - before
	_expect(started and guard < 400, "the dish is eaten through the real EatSession")
	_expect(absf(gained - float(bundle["instant_energy"])) < 0.05, "the eat pays the dish's evaluated instant Energy (%.2f vs %.2f)" % [gained, float(bundle["instant_energy"])])
	_expect(float(bundle["digested_energy"]) > 0.0, "the rest is scheduled as digestion")
	# Two dishes of the same level: the inherited one pays more.
	_bag([["raw_meat", 20, {"rich_cut": 2}], ["raw_meat", 20, {}]])
	var rich_dish = CR.craft(_player, CR.recipe(&"roled_grilled_meat"), _ints([0]))
	var plain_dish = CR.craft(_player, CR.recipe(&"roled_grilled_meat"), _ints([1]))
	_expect(rich_dish != null and plain_dish != null, "one rich and one plain dish cook")
	if rich_dish and plain_dish:
		var rich_total := float(FX.evaluate(rich_dish)["latent_energy"])
		var plain_total := float(FX.evaluate(plain_dish)["latent_energy"])
		_expect(rich_total > plain_total, "the inherited trait raises the dish's Energy when it is evaluated for eating (%.2f vs %.2f)" % [rich_total, plain_total])
	# The role bonus reaches the buff bundle, in its own group.
	_bag([["raw_meat", 20, {}], ["berry", 20, {}]])
	var glazed = CR.craft(_player, CR.recipe(&"roled_berry_glazed_meat"), _ints([0, 1]))
	var gb: Dictionary = FX.evaluate(glazed)
	var ids: Array = []
	for row: Variant in gb["buffs"]:
		ids.append(str((row as Dictionary).get("id", "")))
	_expect("fruit_glaze" in ids, "the topping's role bonus is a buff on the dish's bundle (%s)" % str(ids))
	var plain_b: Dictionary = FX.evaluate(CR.build_output(CR.recipe(&"roled_grilled_meat"), IS.make(&"grilled_meat"), 1))
	_expect(not "fruit_glaze" in _buff_ids(plain_b), "a dish without the topping has no fruit bonus")

func _buff_ids(bundle: Dictionary) -> Array:
	var out: Array = []
	for row: Variant in bundle.get("buffs", []):
		out.append(str((row as Dictionary).get("id", "")))
	return out

# ---------------------------------------------------------------- 7. save / load

func _test_save() -> void:
	print("[t_cookroles] -- save")
	_player.global_position = Vector3(1, 1, 1.4)
	_bag([["raw_meat", 25, {"rich_cut": 2, "gamey_cut": 1}]])
	var dish = CR.craft(_player, CR.recipe(&"roled_grilled_meat"), _ints([0]))
	_expect(dish != null, "a dish is cooked for the save round trip")
	if dish == null:
		return
	var before_bundle: Dictionary = FX.evaluate(dish)
	var bag = INV.new(6)
	bag.add(dish)
	var rows: Array = bag.to_array()
	# The real save path: JSON, then the sanitizer, then a fresh bag.
	var payload: Dictionary = JSON.parse_string(JSON.stringify({"player": {"inventory": rows}}))
	var cleaned: Dictionary = SAN.clean(payload)
	var restored = INV.new(6)
	restored.load_array((cleaned["player"] as Dictionary).get("inventory", []))
	var back = null
	for s in restored.slots:
		if s != null and s.def_id == dish.def_id:
			back = s
	_expect(back != null, "the dish survives the save and reload")
	if back == null:
		return
	_expect(int(back.attributes.get("rich_cut", 0)) == 2 and int(back.attributes.get("gamey_cut", 0)) == 1, "the dish's inherited traits survive the save (%s)" % str(back.attributes.get("cooked_roles", [])))
	_expect((back.attributes.get("cooked_roles", []) as Array).size() == 1, "and its inheritance record does too")
	var after_bundle: Dictionary = FX.evaluate(back)
	_expect(absf(float(after_bundle["latent_energy"]) - float(before_bundle["latent_energy"])) < 0.01, "the reloaded dish evaluates to the same Energy (%.2f vs %.2f)" % [float(after_bundle["latent_energy"]), float(before_bundle["latent_energy"])])
	_expect(absf(float(after_bundle["fullness"]) - float(before_bundle["fullness"])) < 0.01, "and the same Fullness")
	_expect((after_bundle.get("inherited", {}) as Dictionary).has("rich_cut"), "the reloaded dish still reports its inherited trait to FOODFX")
	# A forged save row: a trait with a silly level, a non-numeric trait, an unknown bonus, a huge slot.
	var forged: Dictionary = {"player": {"inventory": [{
		"id": str(dish.def_id), "count": 1, "level": 30, "process_count": 1,
		"attributes": {"cooked_roles": [
			{"slot": 99, "role": "main", "def_id": "raw_meat", "level": 999,
				"traits": {"rich_cut": 999, "not_a_trait": "x"}, "dropped": {}, "processed": ["dry", 5], "flags": [], "bonus": "no_such_buff"},
		], "cooked_buffs": ["fruit_glaze", "made_up_buff"]},
		"flags": [], "durability": 0, "max_durability": 0}]}}
	var cleaned2: Dictionary = SAN.clean(forged.duplicate(true))
	var forged_bag = INV.new(4)
	forged_bag.load_array(cleaned2["player"]["inventory"])
	var forged_stack = forged_bag.slots[0]
	var forged_rows: Array = forged_stack.attributes.get("cooked_roles", []) if forged_stack else []
	_expect(forged_rows.size() == 1, "a forged dish still loads")
	if forged_rows.size() == 1:
		var fr: Dictionary = forged_rows[0]
		_expect(int(fr.get("slot", -1)) <= 15, "the forged slot index is clamped")
		_expect(int((fr.get("traits", {}) as Dictionary).get("rich_cut", 0)) <= 60, "the forged trait level is clamped")
		_expect(not (fr.get("traits", {}) as Dictionary).has("not_a_trait"), "a non-numeric trait is dropped")
		_expect(str(fr.get("bonus", "")) == "", "an unknown role bonus is dropped")
		_expect(fr.get("processed", []) == ["dry"], "a non-string processing step is dropped")
	_expect((forged_stack.attributes.get("cooked_buffs", []) as Array) == ["fruit_glaze"], "an unknown role buff is dropped, the real one stays")
