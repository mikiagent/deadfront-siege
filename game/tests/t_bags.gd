extends SceneTree
## Spec 31 §14 1-17 (bag types, bag levels, material-inherited storage, Pocket, inspect/compare,
## crafting preview). One _expect per requirement:
##  1 base capacity 100; 2 equipping a basic bag; 3 a high-level bag; 4 two same-level bags with
##  different material attributes; 5 Pocket Lv1 = +6; 6 Pocket Lv5 = +30; 7 multiple compatible
##  storage modifiers on one bag; 8 equip/unequip repeated; 9 no duplicate capacity bonus;
##  10 overflow handling (unequip refused, nothing lost); 11 crafting a bag from individually picked
##  materials; 12 the crafting preview equals the crafted result; 13/14 saving and loading an
##  equipped bag and its attributes; 15 the Bag header reads used / capacity and refreshes at once;
##  16 individual nonstacking items are preserved; 17 cargo dinosaur capacity stays separate.
## Run: Godot --headless --path game --script res://tests/t_bags.gd -> "[t_bags] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var _t0 := 0
var BD: GDScript  # bag_def.gd
var BC: GDScript  # bag_capacity.gd
var CR: GDScript  # crafting.gd
var IS: GDScript  # item_stack.gd
var INV: GDScript # inventory.gd

func _process(_delta: float) -> bool:
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		if _started == false:
			_started = true
			_t0 = int(Time.get_ticks_msec())
		elif int(Time.get_ticks_msec()) - _t0 > 60000:
			print("[t_bags] FAIL Data autoload never appeared")
			quit(1)
		return false
	if BD != null:
		return false
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_bags] FAIL %s" % what)

func _json(v: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(v))

## Save/load the way SaveGame does: bag rows then extras, both through JSON.
func _reload(inv):
	var back = INV.new(inv.base_slots)
	back.load_array(_json(inv.to_array()))
	back.extras_from_dict(_json(inv.extras_to_dict()))
	return back

func _run() -> void:
	BD = load("res://scripts/items/bag_def.gd")
	BC = load("res://scripts/items/bag_capacity.gd")
	CR = load("res://scripts/items/crafting.gd")
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	_test_base_capacity()
	_test_basic_bag()
	_test_high_level_bag()
	_test_same_level_diff()
	_test_pocket_levels()
	_test_multiple_mods()
	_test_equip_unequip_repeated()
	_test_no_duplicate()
	_test_overflow()
	_test_craft_picks()
	_test_preview_matches_result()
	_test_save_load()
	_test_header()
	_test_individual_items()
	_test_cargo_separate()
	_test_legacy_migration()
	if _fails.is_empty():
		print("[t_bags] PASS")
		quit(0)
	else:
		print("[t_bags] FAIL count=%d" % _fails.size())
		quit(1)

# ---------------------------------------------------------------- 1-3 capacity

## 1. A fresh survivor has 100 inventory spaces and no storage modifier adds to it.
func _test_base_capacity() -> void:
	var inv = INV.new()
	_expect(inv.capacity() == 100 and inv.slot_count == 100, "1: a fresh bag has 100 spaces (%d/%d)" % [inv.capacity(), inv.slot_count])
	var t: Dictionary = BC.inventory_total(inv)
	_expect(int(t.get("base", 0)) == 100 and int(t.get("bag", -1)) == 0 and int(t.get("other", -1)) == 0, "1: base 100, no bag, no modifiers (breakdown %s)" % t)

## 2. The basic bag, worn, adds its level-1 curve value.
func _test_basic_bag() -> void:
	var d: Dictionary = BD.def_for(&"basic_bag")
	_expect(not d.is_empty(), "2: basic_bag has a bag definition (data/bags.json)")
	if d.is_empty():
		return
	var inv = INV.new()
	inv.add(IS.make(&"basic_bag", 1, {}, 1))
	var idx: int = inv.find_first(&"basic_bag")
	var curve1: int = BD.base_capacity(&"basic_bag", 1)
	_expect(idx >= 0 and inv.equip_at(idx), "2: the basic bag (data item) can be worn")
	_expect(inv.capacity() == 100 + curve1 and inv.slot_count == inv.capacity(), "2: a level-1 basic bag adds %d spaces (%d)" % [curve1, inv.capacity()])
	var b: Dictionary = BC.of_stack(inv.worn(&"accessory1"))
	_expect(int(b.get("base", -1)) == curve1 and int(b.get("pocket", -1)) == 0, "2: the bag's breakdown is base %d, pocket 0 (%s)" % [curve1, b])

## 3. A level-60 bag adds its own curve value, not 60 spaces.
func _test_high_level_bag() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"basic_bag", 1, {}, 60))
	inv.equip_at(inv.find_first(&"basic_bag"))
	var want: int = 100 + BD.base_capacity(&"basic_bag", 60)
	print("[t_bags] high level: capacity=%d want=%d curve60=%d" % [inv.capacity(), want, BD.base_capacity(&"basic_bag", 60)])
	_expect(inv.capacity() == want, "3: a level-60 basic bag adds the level-60 curve value (%d)" % inv.capacity())
	_expect(BD.base_capacity(&"basic_bag", 60) != 60, "3: bag level does not equal capacity bonus (level 60 gives %d)" % BD.base_capacity(&"basic_bag", 60))
	_expect(BD.base_capacity(&"basic_bag", 60) > BD.base_capacity(&"basic_bag", 1), "3: the curve rises with level")

## 4. Two level-30 bags, different materials: only the material attributes differ.
func _test_same_level_diff() -> void:
	var plain = IS.make(&"basic_bag", 1, {}, 30)
	var rich = IS.make(&"specialized_storage_bag", 1, {}, 30)
	rich.attributes["pocket"] = 3
	var a: int = BC.of_stack(plain).get("total", 0)
	var b: int = BC.of_stack(rich).get("total", 0)
	print("[t_bags] same level diff: plain=%d specialized=%d" % [a, b])
	_expect(a > 0 and b > a, "4: two level-30 bags differ by their material attributes (%d vs %d)" % [a, b])

# ---------------------------------------------------------------- 5-7 Pocket and mods

func _test_pocket_levels() -> void:
	var rules: Dictionary = BD.rules()
	var per := int(rules.get("pocket_slots_per_level", 6))
	var p1 = IS.make(&"basic_bag", 1, {"pocket": 1}, 1)
	var p5 = IS.make(&"basic_bag", 1, {"pocket": 5}, 1)
	var base: int = BD.base_capacity(&"basic_bag", 1)
	# 5. Pocket Lv 1 = +6 spaces.
	_expect(int(BC.of_stack(p1).get("pocket", 0)) == 6 and int(BC.of_stack(p1).get("total", 0)) == base + 6, "5: Pocket Lv1 adds 6 spaces (%s, poster=%d)" % [BC.of_stack(p1), per])
	# 6. Pocket Lv 5 = +30 spaces.
	_expect(int(BC.of_stack(p5).get("pocket", 0)) == 30 and int(BC.of_stack(p5).get("total", 0)) == base + 30, "6: Pocket Lv5 adds 30 spaces (%s)" % BC.of_stack(p5))
	var inv = INV.new()
	inv.add(p5)
	inv.equip_at(inv.find_first(&"basic_bag"))
	_expect(inv.capacity() == 100 + base + 30, "6: a worn Pocket Lv5 bag gives 100 + %d + 30 (%d)" % [base, inv.capacity()])
	# Pocket never appears from level alone.
	var lvl60 = IS.make(&"basic_bag", 1, {}, 60)
	_expect(int(BC.of_stack(lvl60).get("pocket", -1)) == 0, "5: a plain level-60 bag has no Pocket (level is not Pocket)")

## 7. A bag can carry several compatible storage modifiers at once, each once.
func _test_multiple_mods() -> void:
	var s = IS.make(&"specialized_storage_bag", 1, {"pocket": 2, "capacity": 10, "fluffy": 4}, 20)
	var b: Dictionary = BC.of_stack(s)
	var base: int = BD.base_capacity(&"specialized_storage_bag", 20)
	print("[t_bags] multi mods: %s base=%d" % [b, base])
	_expect(int(b.get("base", 0)) == base, "7: the base curve value is counted once (%s)" % b)
	_expect(int(b.get("pocket", 0)) == 12, "7: Pocket Lv2 adds 12 (%s)" % b)
	_expect(int(b.get("capacity", 0)) == 10, "7: the capacity attribute adds 10 (%s)" % b)
	_expect(int(b.get("other", 0)) > 0, "7: the bag definition's own storage modifier counts (%s)" % b)
	_expect(int(b.get("total", 0)) == base + 12 + 10 + int(b.get("other", 0)), "7: the modifiers add without overlap (%d)" % int(b.get("total", 0)))
	_expect(b.get("fluffy") == null and not str(b).contains("fluffy"), "7: an incompatible attribute (fluffy) adds nothing (%s)" % b)
	var inv = INV.new()
	inv.add(s)
	inv.equip_at(inv.find_first(&"specialized_storage_bag"))
	_expect(inv.capacity() == 100 + int(b.get("total", 0)), "7: a worn multi-mod bag gives 100 + %d (%d)" % [int(b.get("total", 0)), inv.capacity()])

# ---------------------------------------------------------------- 8-10 equipment and overflow

func _test_equip_unequip_repeated() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"basic_bag", 1, {"pocket": 2}, 15))
	var idx: int = inv.find_first(&"basic_bag")
	var with_bag := -1
	var stable := true
	for i in 10:
		stable = stable and inv.equip_at(idx)
		if with_bag < 0:
			with_bag = inv.capacity()
		stable = stable and inv.capacity() == with_bag
		var w = inv.worn(&"accessory1")
		stable = stable and inv.unequip(&"accessory1") and inv.capacity() == 100
		idx = inv.find_first(&"basic_bag")
		_expect(w != null and w.def_id == &"basic_bag", "8: the bag comes back into the bag each time") if i == 0 else null
	_expect(stable, "8: ten equip/unequip rounds return to the same capacities (%d)" % with_bag)

## 9. The same modifier is never applied twice: two bags in the two ring slots each count once.
func _test_no_duplicate() -> void:
	var two = INV.new()
	two.add(IS.make(&"basic_bag", 1, {}, 10))
	two.add(IS.make(&"basic_bag", 1, {}, 10))
	two.equip_at(two.find_first(&"basic_bag"), &"accessory1")
	var one: int = two.capacity()
	two.equip_at(two.find_first(&"basic_bag"), &"accessory2")
	_expect(two.capacity() == 100 + 2 * BD.base_capacity(&"basic_bag", 10), "9: two bags add twice, not four times (%d)" % two.capacity())
	_expect(two.capacity() > one and int(BC.inventory_total(two).get("bag", 0)) == 2 * BD.base_capacity(&"basic_bag", 10), "9: the total counts each worn bag's bonus once (%s)" % BC.inventory_total(two))

func _test_overflow() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"basic_bag", 1, {}, 1))
	inv.equip_at(inv.find_first(&"basic_bag"))
	var cap: int = inv.slot_count
	while inv.used_slots() < cap:
		inv.add(IS.make(&"stone", 1))
	var uids: Dictionary = inv.uids()
	_expect(not inv.unequip(&"accessory1"), "10: an unequip that would overflow is refused")
	_expect(inv.worn(&"accessory1") != null and inv.slot_count == cap and inv.used_slots() == cap, "10: the refused bag stays worn and nothing moves (%d/%d)" % [inv.used_slots(), inv.slot_count])
	var lost := 0
	var after: Dictionary = inv.uids()
	for k in uids:
		lost += 0 if after.has(k) else 1
	_expect(lost == 0 and inv.count_of(&"stone") == cap, "10: no item is lost by the refusal (%d stones, lost %d)" % [inv.count_of(&"stone"), lost])

# ---------------------------------------------------------------- 11-12 crafting

## The bag recipe whose output is `id` (data/recipes.json).
func _recipe_for(id: StringName) -> Dictionary:
	var data: Node = get_root().get_node("Data")
	for r in data.recipe_list:
		if r is Dictionary and str(r.get("output", {}).get("id", "")) == str(id):
			return r
	return {}

## 11. A bag crafted from individually picked materials: primary attributes are inherited, level
## follows the material rule, Pocket comes only from the material.
func _test_craft_picks() -> void:
	var rec := _recipe_for(&"basic_bag")
	_expect(not rec.is_empty(), "11: basic_bag has a recipe")
	if rec.is_empty():
		return
	var inv = INV.new()
	var hide_idx: int = inv.used_slots()
	inv.add(IS.make(&"raw_hide", 1, {"pocket": 3}, 12))
	inv.add(IS.make(&"raw_hide", 1, {}, 12))
	inv.add(IS.make(&"fibre_stalk", 1, {}, 12))
	inv.add(IS.make(&"fibre_stalk", 1, {}, 12))
	inv.add(IS.make(&"fibre_stalk", 1, {}, 12))
	inv.add(IS.make(&"twine", 1, {}, 12))
	var picks: Array[int] = []
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		var want := StringName(str(slots[i].get("category", "")))
		var pick := -1
		for idx in inv.find_by_category(want):
			if want == &"green_hide" and idx == hide_idx:
				pick = idx
			elif want == &"fibre" and pick < 0:
				pick = idx
			elif want == &"lashing" and pick < 0:
				pick = idx
		picks.append(pick)
	_expect(CR.picks_valid(inv, rec, picks), "11: the picked material instances satisfy the recipe (%s)" % [picks])
	var out = CR.preview(inv, rec, picks)
	_expect(out != null and out.def_id == &"basic_bag", "11: the recipe makes a basic bag (%s)" % (out.def_id if out else "none"))
	if out == null:
		return
	_expect(int(out.attributes.get("pocket", 0)) == 3, "11: the selected hide's Pocket 3 is inherited (%s)" % out.attributes)
	_expect(out.level == 12, "11: the bag level follows the primary material level (level %d)" % out.level)
	_expect(int(BC.of_stack(out).get("pocket", 0)) == 18, "11: the crafted bag's Pocket 3 is worth 18 spaces (%s)" % BC.of_stack(out))
	_expect(int(BC.of_stack(out).get("base", 0)) == BD.base_capacity(&"basic_bag", 12), "11: the crafted bag's base follows its level (%s)" % BC.of_stack(out))
	# A bag from other materials at the same level has less: material choice matters.
	var plain = CR.build_output(rec, IS.make(&"raw_hide", 1, {}, 12), 12)
	_expect(plain != null and int(BC.of_stack(plain).get("total", 0)) < int(BC.of_stack(out).get("total", 0)), "11: a plain bag of the same level stores less (%d vs %d)" % [int(BC.of_stack(plain).get("total", 0)), int(BC.of_stack(out).get("total", 0))])

## 12. The preview and the crafted result use the same numbers.
func _test_preview_matches_result() -> void:
	var rec := _recipe_for(&"basic_bag")
	if rec.is_empty():
		_expect(false, "12: no bag recipe to preview")
		return
	var inv = INV.new()
	inv.add(IS.make(&"raw_hide", 1, {"pocket": 2}, 25))
	inv.add(IS.make(&"raw_hide", 1, {}, 25))
	inv.add(IS.make(&"fibre_stalk", 1, {}, 25))
	inv.add(IS.make(&"fibre_stalk", 1, {}, 25))
	inv.add(IS.make(&"fibre_stalk", 1, {}, 25))
	inv.add(IS.make(&"twine", 1, {}, 25))
	var picks: Array[int] = []
	for i in (rec.get("slots", []) as Array).size():
		var want := StringName(str(rec["slots"][i].get("category", "")))
		picks.append(inv.find_by_category(want)[0])
	# The preview must be shown for the survivor who will craft: their crafting skill sets the level.
	var p: Node = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_root().add_child(p)
	p.inventory = inv
	var prev: Dictionary = CR.bag_preview(inv, rec, picks, p)
	_expect(not prev.is_empty(), "12: a bag preview is available")
	if prev.is_empty():
		return
	var out = CR.preview(inv, rec, picks)
	var real: Dictionary = BC.of_stack(out)
	_expect(int(prev.get("level", -1)) == out.level, "12: previewed level %d equals the result's %d" % [int(prev.get("level", -1)), out.level])
	_expect(int(prev.get("base", -1)) == int(real.get("base", -2)) and int(prev.get("pocket", -1)) == int(real.get("pocket", -2)), "12: previewed base and Pocket equal the result's (%s vs %s)" % [prev, real])
	_expect(int(prev.get("bonus", -1)) == int(real.get("total", -2)), "12: previewed bag bonus %d equals the result's %d" % [int(prev.get("bonus", -1)), int(real.get("total", -2))])
	# And the result, worn, gives exactly the previewed total.
	var inv2 = INV.new()
	inv2.add(out)
	inv2.equip_at(0)
	_expect(inv2.capacity() == int(prev.get("total_capacity", -1)), "12: after crafting, the worn bag gives the previewed capacity %d (%d)" % [int(prev.get("total_capacity", -1)), inv2.capacity()])
	# Craft for real through Crafting.craft (same picks, same function) and compare with the preview.
	var made = CR.craft(p, rec, picks)
	_expect(made != null and made.def_id == &"basic_bag", "12: Crafting.craft makes the previewed bag (%s)" % (made.def_id if made else "none"))
	if made != null:
		var crafted: Dictionary = BC.of_stack(made)
		_expect(int(crafted.get("total", -1)) == int(prev.get("bonus", -2)) and int(crafted.get("base", -1)) == int(prev.get("base", -2)) and int(crafted.get("pocket", -1)) == int(prev.get("pocket", -2)), "12: the crafted bag's storage equals the preview (%s vs %s)" % [crafted, prev])
		var inv3 = INV.new()
		inv3.add(made)
		_expect(inv3.equip_at(0) and inv3.capacity() == int(prev.get("total_capacity", -1)), "12: the crafted bag worn gives the previewed capacity %d (%d)" % [int(prev.get("total_capacity", -1)), inv3.capacity()])
	p.queue_free()

# ---------------------------------------------------------------- 13-14 save/load

func _test_save_load() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"basic_bag", 1, {"pocket": 2}, 40))
	inv.equip_at(inv.find_first(&"basic_bag"))
	for k in 6:
		inv.add(IS.make(&"raptor_bone", 1, {}, 1 + k))
	var before: Dictionary = inv.uids()
	var back = _reload(inv)
	var worn = back.worn(&"accessory1")
	_expect(worn != null and worn.def_id == &"basic_bag", "13: the worn bag comes back worn")
	_expect(back.capacity() == inv.capacity(), "13: save/load keeps the bag capacity (%d -> %d)" % [inv.capacity(), back.capacity()])
	_expect(worn != null and worn.level == 40 and int(worn.attributes.get("pocket", 0)) == 2, "14: the bag's level and Pocket attribute survive the save (level %s, pocket %s)" % [worn.level if worn else -1, worn.attributes if worn else {}])
	_expect(back.uids() == before, "14: every instance id survives the save (%d)" % back.uids().size())
	var b1: Dictionary = BC.inventory_total(inv)
	var b2: Dictionary = BC.inventory_total(back)
	_expect(int(b1.get("bag", -1)) == int(b2.get("bag", -2)) and int(b1.get("total", -1)) == int(b2.get("total", -2)), "13: the breakdown is identical after a reload (%s vs %s)" % [b1, b2])

# ---------------------------------------------------------------- 15-17 UI and separation

## 15. The Bag header reads "used / capacity" and refreshes the moment a bag is worn or taken off.
func _test_header() -> void:
	var inv = INV.new()
	var ui = load("res://scenes/ui/inventory.tscn").instantiate()
	root.add_child(ui)
	ui.bind(inv, null)
	_expect(ui._cap_label != null and ui._cap_label.text == "0 / 100", "15: the Bag header reads 0 / 100 (%s)" % (ui._cap_label.text if ui._cap_label else "no label"))
	inv.add(IS.make(&"basic_bag", 1, {}, 1))
	var cap1: int = 100 + BD.base_capacity(&"basic_bag", 1)
	inv.equip_at(inv.find_first(&"basic_bag"))
	_expect(ui._cap_label.text == "0 / %d" % cap1, "15: wearing a bag refreshes the header at once (%s)" % ui._cap_label.text)
	inv.add(IS.make(&"stone", 1))
	_expect(ui._cap_label.text == "1 / %d" % cap1, "15: the header's used count follows the bag (%s)" % ui._cap_label.text)
	inv.unequip(&"accessory1")
	_expect(ui._cap_label.text == "2 / 100", "15: taking the bag off shrinks the header at once (%s)" % ui._cap_label.text)
	ui.queue_free()

## 16. A bigger bag adds spaces; it never merges individually stored resources.
func _test_individual_items() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"basic_bag", 1, {}, 1))
	inv.equip_at(inv.find_first(&"basic_bag"))
	for k in 5:
		inv.add(IS.make(&"raptor_bone", 1, {}, 1 + k))
	_expect(inv.used_slots() == 5 and inv.count_of(&"raptor_bone") == 5, "16: five bones take five spaces in the bigger bag (%d)" % inv.used_slots())
	var levels: Dictionary = {}
	for s in inv.slots:
		if s != null and s.def_id == &"raptor_bone":
			levels[s.level] = true
	_expect(levels.size() == 5, "16: each bone keeps its own level (%d levels)" % levels.size())

## 17. Cargo dinosaur and box capacities are separate inventories, never added to the bag.
func _test_cargo_separate() -> void:
	var inv = INV.new()
	inv.add(IS.make(&"basic_bag", 1, {}, 1))
	inv.equip_at(inv.find_first(&"basic_bag"))
	var personal: int = inv.capacity()
	var cargo = INV.new(200)
	cargo.add(IS.make(&"stone", 1))
	_expect(cargo.capacity() == 200 and inv.capacity() == personal, "17: a 200-slot cargo dinosaur leaves the personal bag at %d (%d)" % [personal, inv.capacity()])
	var t: Dictionary = BC.inventory_total(inv)
	_expect(int(t.get("total", -1)) == personal and int(t.get("total", 0)) < personal + 200, "17: the personal breakdown never includes cargo (%s)" % t)

## Spec 31 §2: the old woven_bag stand-in is a Basic Bag now. A saved row loads as the same bag at
## the same level and with the same Pocket; its storage comes from the Basic Bag curve, not from the
## flat bag_slots it used to carry.
func _test_legacy_migration() -> void:
	var row := {"id": "woven_bag", "count": 1, "level": 7, "attributes": {"pocket": 1}, "flags": [], "durability": 0, "max_durability": 0}
	var s = IS.from_dict(row)
	var d: Variant = get_root().get_node("Data").item(s.def_id)
	_expect(d != null and StringName(str(d.bag_def)) == &"basic_bag", "migration: a saved woven_bag row is a Basic Bag (%s)" % (d.bag_def if d else "missing"))
	_expect(s.level == 7 and int(s.attributes.get("pocket", 0)) == 1, "migration: the bag keeps its level and Pocket (level %d, %s)" % [s.level, s.attributes])
	var b: Dictionary = BC.of_stack(s)
	_expect(int(b.get("base", -1)) == BD.base_capacity(&"basic_bag", 7) and int(b.get("pocket", -1)) == 6, "migration: the old bag's storage follows the Basic Bag curve plus Pocket 1 (%s)" % b)
	var inv = INV.new()
	inv.add(s)
	inv.equip_at(inv.find_first(s.def_id))
	_expect(inv.capacity() == 100 + int(b.get("total", 0)), "migration: the migrated bag can be worn at its curve value (%d)" % inv.capacity())
