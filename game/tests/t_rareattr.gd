extends SceneTree
## RAREATTR: rare material attributes rolled at gather and carried into crafts (world-design.md:55 "5% chance
## of a rare extra (green pip)", PRD:541, spec 04:11's six green traits, spec 04:33 "rare attributes may pass
## from a single eligible primary material").
## Over 20000 seeded gathers the rate is 5% +-0.5% and every trait is from the gathered material's own list
## (loot_tables.json rare_trait.by_material); the same list covers every gatherable id. An instance's rare
## attribute survives save -> sanitizer -> load with its uid. A craft carries a rare attribute into its result
## from the primary slot (1) only, never from a secondary one. The inspect data shows it as a green (rare) pip,
## on the gathered instance and on the item crafted from it.
## Run: Godot --headless --path game --script res://tests/t_rareattr.gd -> "[t_rareattr] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const ROLLS := 20000
const BAND := 0.005  ## the task's 5% +- 0.5 pp

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _data: Node
var _player: Node
var IS: GDScript
var INV: GDScript
var GS: GDScript
var LR: GDScript
var LT: GDScript
var CR: GDScript
var SS: GDScript
var IA: GDScript
var CARD: GDScript

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_rareattr] FAIL %s" % what)

func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	GS = load("res://scripts/gather/gather_service.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	LT = load("res://scripts/gather/loot_tables.gd")
	CR = load("res://scripts/items/crafting.gd")
	SS = load("res://scripts/core/save_sanitizer.gd")
	IA = load("res://scripts/ui/inv_attributes.gd")
	CARD = load("res://scripts/ui/item_inspect_panel.gd")
	_data = root.get_node("Data")
	_host = Node3D.new()
	_host.name = "TRareattr"
	root.add_child(_host)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_player.position = Vector3(0, 1, 0)
	_host.add_child(_player)
	await process_frame
	await physics_frame
	_test_pools()
	_test_roll_rate()
	_test_save_load()
	_test_craft_carry()
	_test_inspect()
	_finish()

## Every gatherable material has its own list, and it is a subset of spec 04:11's six.
func _test_pools() -> void:
	var pools: Dictionary = LT.trait_materials()
	var six: Array = LT.trait_cfg().get("traits", [])
	_expect(six.size() == 6, "the shared rare pool is spec 04:11's six (got %s)" % [six])
	var gatherables := {}
	for fam: Variant in _data.nature_families.values():
		var harvest: Variant = (fam as Dictionary).get("harvest", {})
		if harvest is Dictionary:
			for id: Variant in (harvest as Dictionary).keys():
				gatherables[str(id)] = true
	for grp in ["by_role", "by_family"]:
		for rows: Variant in (LT.gather_cfg().get(grp, {}) as Dictionary).values():
			for row: Variant in (rows as Array):
				if row is Dictionary:
					gatherables[str((row as Dictionary).get("item", ""))] = true
	var missing: Array[String] = []
	var unknown: Array[String] = []
	var stray: Array[String] = []
	for id: Variant in pools.keys():
		if _data.item(StringName(str(id))) == null:
			unknown.append(str(id))
		var own: Array = pools[id]
		if own.is_empty():
			stray.append("%s has no list" % id)
		for t: Variant in own:
			if str(t) not in six:
				stray.append("%s rolls %s, not one of the six" % [id, t])
	for id: String in gatherables.keys():
		if not pools.has(id):
			missing.append(id)
	print("[t_rareattr] pools %d materials, %d gatherables, missing %d, stray %d" % [pools.size(), gatherables.size(), missing.size(), stray.size()])
	_expect(not pools.is_empty(), "loot_tables.json rare_trait.by_material holds the per-material lists")
	_expect(unknown.is_empty(), "every material list is a real item (%s)" % [unknown])
	_expect(stray.is_empty(), "every listed attribute is one of the six (%s)" % [stray])
	_expect(missing.is_empty(), "every gatherable material has its own rare list (%s)" % [missing])
	# The fallback stays: an item with no list of its own rolls the shared six.
	_expect((LT.material_traits(&"no_such_material") as Array) == six, "an item without its own list falls back to the six")
	var rng := _seeded(5)
	var from_fallback := true
	for i in 200:
		var t: StringName = LR.roll_trait(rng, &"no_such_material")
		from_fallback = from_fallback and (t == &"" or str(t) in six)
	_expect(from_fallback, "the fallback roll only yields the six")

## world-design.md:55: 5% of gathered items, each from its own material's list, through the real gather path
## (GatherService.stamp_traits on a real bag), over ROLLS seeded rolls.
func _test_roll_rate() -> void:
	var pools: Dictionary = LT.trait_materials()
	var ids: Array = pools.keys()
	ids.sort()  # a stable order for the seed
	var inv = INV.new(1)
	var rng := _seeded(20261028)
	var hits := 0
	var off_list := 0
	var twice := 0
	var per_material := {}
	for i in ROLLS:
		var id := StringName(str(ids[i % ids.size()]))
		inv.slots[0] = null
		var st = IS.make(id, 1, {"level": 1, "climate": "grassland"}, 1)
		inv.add(st)
		var got: Array = GS.stamp_traits(inv, {}, st, 1, rng)
		var mine = inv.slots[0]
		var n := 0
		for t: Variant in pools[str(id)]:
			if mine != null and mine.attributes.get(str(t), false) == true:
				n += 1
		if n > 0:
			hits += 1
			per_material[str(id)] = int(per_material.get(str(id), 0)) + 1
		if n > 1:
			twice += 1
		# A trait on anything other than this material's list: the one failure mode of a shared pool.
		if mine != null:
			for k: Variant in mine.attributes.keys():
				if str(k) in (LT.trait_cfg().get("traits", []) as Array) and str(k) not in (pools[str(id)] as Array):
					off_list += 1
		if got.size() != n and got.size() > 0:
			off_list += 1
	var rate := float(hits) / float(ROLLS)
	print("[t_rareattr] roll rate %.4f over %d gathers (%d hits, %d traited materials, off-list %d, two-trait %d)" % [rate, ROLLS, hits, per_material.size(), off_list, twice])
	var want := float(LT.trait_cfg().get("chance", 0.0))
	_expect(is_equal_approx(want, 0.05), "the data chance is 5%% (got %s)" % want)
	_expect(absf(rate - want) <= BAND, "the gathered rare rate is 5%% +-0.5 pp (got %.4f over %d)" % [rate, ROLLS])
	_expect(off_list == 0, "every gathered rare attribute is from that material's own list (%d off-list)" % off_list)
	_expect(twice == 0, "an instance never carries two rare attributes (%d did)" % twice)
	_expect(per_material.size() >= ids.size() / 2, "the rolls spread over the materials (%d of %d got one)" % [per_material.size(), ids.size()])

## An instance's rare attribute survives the save path (to_array -> sanitizer -> JSON -> load_array), with its uid.
## The instances are stamped by the real gather path at odds 1 (the odds themselves are measured above).
func _test_save_load() -> void:
	var inv = INV.new(8)
	var plain = IS.make(&"stone", 1, {"level": 3, "climate": "temperate"}, 3)
	var branch = IS.make(&"branch", 1, {"level": 2, "climate": "temperate"}, 2)
	var cfg_saved: Dictionary = LT.trait_cfg().duplicate(true)
	var forced: Dictionary = cfg_saved.duplicate(true)
	forced["chance"] = 1.0
	LT._loot["rare_trait"] = forced
	inv.add(plain)
	GS.stamp_traits(inv, {}, plain, 1, _seeded(41))
	inv.add(branch)
	GS.stamp_traits(inv, {}, branch, 1, _seeded(42))
	LT._loot["rare_trait"] = cfg_saved
	var stone_rare := _rare_of(inv.slots[0], &"stone")
	var stick_rare := _rare_of(inv.slots[1], &"branch")
	var uid: String = inv.slots[0].uid
	var raw: Variant = JSON.parse_string(JSON.stringify(inv.to_array()))
	var clean: Dictionary = SS.clean({"player": {"inventory": raw}, "player_name": "Rare"})
	var back = INV.new(8)
	back.load_array(clean.get("player", {}).get("inventory", []))
	var stone = back.slots[0]
	var stick = back.slots[1]
	print("[t_rareattr] save/load stone=%s uid '%s' (was '%s'), branch=%s" % [
		stone.attributes if stone else null, stone.uid if stone else "", uid, stick.attributes if stick else null])
	_expect(stone_rare != "" and stick_rare != "", "the gather path stamped a rare attribute on each (stone %s, branch %s)" % [stone_rare, stick_rare])
	_expect(stone != null and stone.def_id == &"stone" and _rare_of(stone, &"stone") == stone_rare,
		"a saved stone keeps its own rare attribute (%s)" % (stone.attributes if stone else null))
	_expect(stone != null and stone.uid == uid and uid != "", "the loaded instance keeps its own uid ('%s' of '%s')" % [stone.uid if stone else "", uid])
	_expect(stick != null and _rare_of(stick, &"branch") == stick_rare, "a saved branch keeps its own rare attribute (%s)" % (stick.attributes if stick else null))
	_expect(stone != null and IA.has_rare(stone), "the loaded stone still reads as rare")

## The one rare attribute `st` carries from `id`'s own list ("" for none).
func _rare_of(st: Variant, id: StringName) -> String:
	if st == null:
		return ""
	var attrs: Dictionary = st.attributes
	for t: Variant in LT.material_traits(id):
		if attrs.get(str(t), false) == true:
			return str(t)
	return ""

## Spec 04:33: a rare attribute passes from a single eligible PRIMARY material; a secondary one never
## transfers. The craft's own rare roll is forced to none, so only the source instance can supply it.
## Runs on the shipped three-slot recipe (stone blade = primary, branch handle, reed lashing), so slot 1,
## slot 2 and slot 3 are all exercised.
func _test_craft_carry() -> void:
	var rec: Dictionary = _data.recipes.get(&"improvised_stone_knife", {})
	_expect(not rec.is_empty() and CR.primary_index(rec) == 0 and (rec.get("slots", []) as Array).size() == 3,
		"the shipped knife recipe has three slots with slot 1 as its primary")
	if rec.is_empty():
		return
	# Slot 1 (primary) carries it.
	var picks := _bag_for("black_sheen", "", "")
	var out = CR.commit_outcome(_player, rec, picks, {"success": true, "flawless": false, "rare": &""})
	print("[t_rareattr] slot1 craft: picks %s -> %s %s" % [picks, out.def_id if out else "<none>", out.attributes if out else {}])
	_expect(out != null and out.def_id == &"stone_knife_work", "a craft with the rare blade in slot 1 makes its item (%s)" % (out.def_id if out else "<none>"))
	_expect(out != null and out.attributes.get("black_sheen", false) == true, "the slot-1 rare attribute carries into the crafted item (%s)" % (out.attributes if out else {}))
	_expect(out != null and IA.class_of("black_sheen") == "rare" and IA.has_rare(out), "the crafted item's carried attribute is a rare (green) trait")
	# Slot 2 (handle) does not.
	picks = _bag_for("", "black_sheen", "")
	var out2 = CR.commit_outcome(_player, rec, picks, {"success": true, "flawless": false, "rare": &""})
	print("[t_rareattr] slot2 craft: picks %s -> %s %s" % [picks, out2.def_id if out2 else "<none>", out2.attributes if out2 else {}])
	_expect(out2 != null and out2.def_id == &"stone_knife_work", "the same craft with the rare handle in slot 2 makes its item")
	_expect(out2 != null and out2.attributes.get("black_sheen", false) != true, "a rare attribute in slot 2 does not carry into the result (%s)" % (out2.attributes if out2 else {}))
	# Slot 3 (lashing) does not either.
	picks = _bag_for("", "", "black_sheen")
	var out3 = CR.commit_outcome(_player, rec, picks, {"success": true, "flawless": false, "rare": &""})
	print("[t_rareattr] slot3 craft: picks %s -> %s %s" % [picks, out3.def_id if out3 else "<none>", out3.attributes if out3 else {}])
	_expect(out3 != null and out3.def_id == &"stone_knife_work", "the same craft with the rare lashing in slot 3 makes its item")
	_expect(out3 != null and out3.attributes.get("black_sheen", false) != true, "a rare attribute in slot 3 does not carry into the result (%s)" % (out3.attributes if out3 else {}))
	# The preview of the same craft says it inherits the slot-1 attribute, so a preview cannot disagree.
	var p3 := _bag_for("wide_serration", "", "")
	var prev: Dictionary = CR.preview_quality(rec, _player, _player.inventory.slots[p3[0]])
	_expect("wide_serration" in (prev.get("inherited", []) as Array), "the preview lists the slot-1 rare attribute it will inherit (%s)" % str(prev.get("inherited")))
	# And the preview of the secondary case lists nothing from the handle.
	var p4 := _bag_for("", "wide_serration", "")
	var prev4: Dictionary = CR.preview_quality(rec, _player, _player.inventory.slots[p4[0]])
	_expect(not ("wide_serration" in (prev4.get("inherited", []) as Array)), "the preview of a rare secondary inherits nothing from it (%s)" % str(prev4.get("inherited")))

## The player's own bag, emptied and refilled for the shipped knife recipe: a stone (slot 1), a branch
## (slot 2) and a reed (slot 3), the given one carrying a rare attribute (a key set true). commit_outcome
## reads the player's bag, so the craft runs on exactly the instances its picks name.
func _bag_for(primary: String, secondary: String, tertiary: String) -> Array[int]:
	var bag = _player.inventory
	for i in bag.slot_count:
		bag.slots[i] = null
	var rows := [[&"stone", primary], [&"branch", secondary], [&"reed", tertiary]]
	for pair: Array in rows:
		var st = IS.make(pair[0], 1, {"level": 5, "climate": "grassland"}, 5)
		if str(pair[1]) != "":
			st.attributes[str(pair[1])] = true
		bag.add(st)
	_expect(bag.slots[0] != null and bag.slots[1] != null and bag.slots[2] != null, "the bag holds the blade, handle and lashing a slot needs")
	var rec: Dictionary = _data.recipes.get(&"improvised_stone_knife", {})
	return CR.default_picks(bag, rec)

## The card, the grid and the pip read InvAttributes: a gathered instance's rare attribute is a green (rare)
## row with INVUI's green, and the item crafted from it keeps that row.
func _test_inspect() -> void:
	var st = IS.make(&"stone", 1, {"level": 1, "climate": "temperate"}, 1)
	var plain = IS.make(&"stone", 1, {"level": 1, "climate": "temperate"}, 1)
	var cfg_saved: Dictionary = LT.trait_cfg().duplicate(true)
	var forced: Dictionary = cfg_saved.duplicate(true)
	forced["chance"] = 1.0
	LT._loot["rare_trait"] = forced
	var bag = INV.new(8)
	bag.add(st)
	GS.stamp_traits(bag, {}, st, 1, _seeded(7))
	LT._loot["rare_trait"] = cfg_saved
	var gathered = bag.slots[0]
	var key := _rare_of(gathered, &"stone")
	_expect(key != "", "the gathered stone carries a rare attribute (%s)" % (gathered.attributes if gathered else null))
	_check_pip(gathered, key, "the gathered instance")
	_expect(not IA.has_rare(plain) and _rare_rows(plain) == 0, "a plain gathered instance shows no rare pip")
	_expect(not (LT.material_traits(&"stone") as Array).has("wide_serration"), "the stone's list excludes a timber trait")
	# The crafted item keeps the pip.
	var rec: Dictionary = _data.recipes.get(&"improvised_stone_knife", {})
	for i in _player.inventory.slot_count:
		_player.inventory.slots[i] = null
	_player.inventory.add(gathered)
	_player.inventory.add(IS.make(&"branch", 1, {"level": 5}, 5))
	_player.inventory.add(IS.make(&"reed", 1, {"level": 5}, 5))
	var out = CR.commit_outcome(_player, rec, CR.default_picks(_player.inventory, rec), {"success": true, "flawless": false, "rare": &""})
	_expect(out != null and _rare_of(out, &"stone") == key, "the crafted item keeps the gathered instance's rare attribute")
	_check_pip(out, key, "the crafted item")

## The inspect data, the card rows and the grid's rare mark for `st`'s rare attribute `key`.
func _check_pip(st: Variant, key: String, what: String) -> void:
	if st == null:
		_expect(false, "%s is null" % what)
		return
	var rare: Array = IA.sections(st).get("rare", [])
	var keys: Array[String] = []
	for row: Variant in rare:
		keys.append(str((row as Dictionary).get("key", "")))
	var green: Color = CARD.color_of("rare")
	print("[t_rareattr] %s: rare %s, green %s, rows %s" % [what, keys, green.to_html(false), CARD.rows_for(st)])
	_expect(key in keys and keys.size() == 1, "%s's inspect data has its rare attribute in the rare section and no other (%s)" % [what, keys])
	_expect(_rare_rows(st) == 1, "%s's card shows exactly one rare (green) row (%s)" % [what, CARD.rows_for(st)])
	_expect(IA.has_rare(st), "%s carries the grid's rare mark" % what)
	# Spec 13:50/291's green, INVUI's InvTheme.RARE.
	_expect(green == IA.COLORS["rare"] and green.g > green.r and green.g > green.b and green == Color("#67B84E"),
		"the rare class draws INVUI's green #67B84E (%s)" % green.to_html(false))

## Rows of `st`'s card with the rare class.
func _rare_rows(st: Variant) -> int:
	var n := 0
	for row: Variant in CARD.rows_for(st):
		if row is Dictionary and str((row as Dictionary).get("cls", "")) == "rare":
			n += 1
	return n

func _finish() -> void:
	if _fails.is_empty():
		print("[t_rareattr] PASS")
	else:
		for f in _fails:
			print("[t_rareattr] FAILED: %s" % f)
	quit(0 if _fails.is_empty() else 1)
