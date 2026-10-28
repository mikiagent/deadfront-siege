extends SceneTree
## Spec 35 package 1 (MATLOOK): natural wood appearance as its own data dimension.
## Checks: the species table (colours, families, grains, every tree kind mapped), a log gathered
## from a mapped tree carrying that species' look with a small per-log variation inside the species
## range, look never touching level/traits/value and traits never touching look, saves with and
## without look, the server gather path, and the economy gate's verdict.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.
## Run: Godot --headless --path game --script res://tests/t_matlook.gd -> "[t_matlook] PASS".

var _fails: PackedStringArray = []
var _started := false
var _seen_gap := false

var IS: GDScript
var INV: GDScript
var ML: GDScript
var NODE: PackedScene
## The Data autoload: reached through the tree, since a --script run compiles before singletons.
var DATA: Node

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_matlook] FAIL %s" % what)

func _run() -> void:
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	ML = load("res://scripts/items/material_look.gd")
	NODE = load("res://scenes/world/harvest_node.tscn")
	DATA = root.get_node("Data")
	_test_species_table()
	_test_tree_gather()
	_test_independence()
	_test_save()
	_test_save_fixture()
	_test_server_gather()
	_test_grouping()
	_test_econ_gate()
	if _fails.is_empty():
		print("[t_matlook] PASS%s" % (" (with the reported economy gap)" if _seen_gap else ""))
		quit(0)
	else:
		print("[t_matlook] FAIL count=%d" % _fails.size())
		quit(1)

# --- 1. data: species table and the tree-kind map ----------------------------------------

func _test_species_table() -> void:
	var table: Dictionary = ML.table()
	var rows: Dictionary = table.get("species", {})
	_expect(rows.size() >= 5, "wood_species.json defines the species our tree kinds have (%d)" % rows.size())
	var bad: PackedStringArray = []
	for id: Variant in rows:
		var row: Dictionary = rows[id]
		var hex := str(row.get("color", ""))
		var ok_hex := hex.length() == 7 and hex.begins_with("#") and hex.substr(1).is_valid_hex_number()
		var var_d: Dictionary = row.get("variation", {}) if row.get("variation") is Dictionary else {}
		var hue: Array = var_d.get("hue_deg", []) if var_d.get("hue_deg") is Array else []
		var val: Array = var_d.get("value", []) if var_d.get("value") is Array else []
		var ok_var := hue.size() == 2 and val.size() == 2 and float(hue[0]) < 0.0 and float(hue[1]) > 0.0 \
			and float(val[0]) < 0.0 and float(val[1]) > 0.0
		if not (ok_hex and str(row.get("family", "")) != "" and str(row.get("grain", "")) != "" and ok_var):
			bad.append(str(id))
	_expect(bad.is_empty(), "every species has a #rrggbb colour, a family, a grain and a signed variation range (%s)" % ", ".join(bad))
	_expect(not ML.species(ML.default_species()).is_empty(), "the default species exists (%s)" % ML.default_species())
	# Every tree kind the manifest has must map to a species (role tree or tree_dead).
	var unmapped: PackedStringArray = []
	var kinds := 0
	var families: Dictionary = DATA.get("nature_families")
	for fam: Variant in families:
		var row: Dictionary = families[fam]
		if not str(row.get("role", "")).begins_with("tree"):
			continue
		kinds += 1
		if ML.species_for(str(fam), "") == "":
			unmapped.append(str(fam))
	_expect(kinds > 0 and unmapped.is_empty(), "every tree kind in nature_manifest maps to a species (%d kinds, unmapped: %s)" % [kinds, ", ".join(unmapped)])
	# And the reverse: a mapped kind that the manifest does not have is dead weight (a stump is a
	# prop, not a tree, but it drops wood_log and is mapped on purpose).
	var ghosts: PackedStringArray = []
	for fam: Variant in ML.tree_kinds():
		if not (DATA.get("nature_families") as Dictionary).has(str(fam)):
			ghosts.append(str(fam))
	_expect(ghosts.is_empty(), "wood_species.json maps no tree kind the manifest lacks (%s)" % ", ".join(ghosts))
	print("[t_matlook] species=%d kinds=%d default=%s" % [rows.size(), kinds, ML.default_species()])

# --- 2. a gathered log carries its tree kind's look, with variation -----------------------

func _test_tree_gather() -> void:
	var node = NODE.instantiate()
	node.setup(&"t_pine", &"wood_log", 1, 2, {"level": 1, "climate": "tundra"}, &"axe", Color.GRAY, 1.2, 8.0, "PineTree")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 11
	var r2 := RandomNumberGenerator.new()
	r2.seed = 12
	var a = node.roll_yield(r1)
	var b = node.roll_yield(r2)
	_expect(a.def_id == &"wood_log" and a.look.get("species", "") == "pine", "a log from PineTree is pine (%s)" % str(a.look))
	_expect(ML.validate(a.look) == "" and ML.validate(b.look) == "", "a gathered look passes its species range (%s | %s)" % [ML.validate(a.look), ML.validate(b.look)])
	_expect(a.look.get("family", "") != "" and a.look.get("grain", "") != "", "the log carries its family and grain (%s / %s)" % [a.look.get("family", ""), a.look.get("grain", "")])
	_expect(str(a.look.get("color", "")) != str(b.look.get("color", "")), "two logs of one species differ slightly (%s vs %s)" % [a.look.get("color", ""), b.look.get("color", "")])
	# Variation is small: the same species, not a different wood (family/grain identical).
	_expect(a.look.get("family") == b.look.get("family") and a.look.get("grain") == b.look.get("grain"), "variation never changes the wood's family or grain")
	# Seeded: the same seed rolls the same log, so a replay draws the same colours.
	var r3 := RandomNumberGenerator.new()
	r3.seed = 11
	_expect(ML.look_for("PineTree", "tundra", 4242) == ML.look_for("PineTree", "tundra", 4242), "the per-log look is deterministic for a seed")
	# A snowy pine is its own species, and the same kind in another climate still resolves.
	var snow: Dictionary = ML.look_for("PineTree_Snow", "tundra", 7)
	_expect(snow.get("species", "") == "snow_pine" and ML.validate(snow) == "", "PineTree_Snow is snow pine (%s)" % str(snow))
	var unset: String = ML.species_for("Willow_Dead", "swamp")
	_expect(unset == "willow", "a dead tree keeps its kind's species (%s)" % unset)
	_expect(ML.species_for("tree_stump", "") == "oak", "a lone stump's wood_log gets the default wood (%s)" % ML.species_for("tree_stump", ""))
	node.free()
	# Only wood drops get a look: a bush's berries are not wood.
	var bush = NODE.instantiate()
	bush.setup(&"t_bush", &"berries", 1, 2, {"level": 1, "climate": "temperate"}, &"none", Color.GRAY, 1.2, 8.0, "BushBerries")
	var berry = bush.roll_yield(r1)
	_expect(berry.look.is_empty(), "a non-wood yield carries no look (%s)" % str(berry.look))
	bush.free()

# --- 3. appearance is a separate dimension ---------------------------------------------

func _test_independence() -> void:
	var plain = IS.make(&"wood_log", 1, {}, 5)
	var looked = IS.make(&"wood_log", 1, {}, 5)
	looked.look = ML.look_for_species("acacia", 3)
	_expect(plain.level == looked.level and plain.attributes == looked.attributes, "a look leaves level and attributes alone")
	_expect(plain.stat_multiplier() == looked.stat_multiplier() and plain.scaled_damage() == looked.scaled_damage(), "a look leaves the item's stats alone")
	_expect(INV.traits(plain).is_empty() and INV.traits(looked).is_empty(), "a look is not a trait (traits %s)" % str(INV.traits(looked)))
	_expect(INV.spend_key(plain) == INV.spend_key(looked), "a look does not change what a default pick spends (%s vs %s)" % [str(INV.spend_key(plain)), str(INV.spend_key(looked))])
	# Traits never change the look, and a rare trait is not a colour.
	var before: Dictionary = looked.look.duplicate(true)
	looked.attributes["black_sheen"] = true
	_expect(looked.look == before, "a trait leaves the look untouched")
	var attrs_before: Dictionary = looked.attributes.duplicate(true)
	looked.look = {}
	ML.stamp(looked, "PineTree", "tundra", 5)
	_expect(looked.attributes == attrs_before, "stamping a look writes into attributes (%s)" % str(looked.attributes))
	# A different look is a different unit: two species never merge; the same species may.
	var oak = IS.make(&"wood_log", 1, {})
	oak.look = ML.look_for_species("oak", 1)
	var oak2 = IS.make(&"wood_log", 1, {})
	oak2.look = ML.look_for_species("oak", 1)
	var birch = IS.make(&"wood_log", 1, {})
	birch.look = ML.look_for_species("birch", 3)
	_expect(not oak.can_merge_with(birch), "an oak log does not merge into a birch log")
	_expect(oak.can_merge_with(oak2), "two identical logs still merge")
	var bag = INV.new(8)
	bag.add(oak)
	bag.add(birch)
	_expect(bag.used_slots() == 2, "two species take two slots (%d)" % bag.used_slots())

# --- 4. saves: additive and optional ---------------------------------------------------

func _test_save() -> void:
	var wood = IS.make(&"wood_log", 1, {}, 7)
	wood.look = ML.look_for_species("willow", 9)
	wood.stamp_identity("gather", "Tess")
	var row: Dictionary = wood.to_dict()
	var back = IS.from_dict(JSON.parse_string(JSON.stringify(row)))
	_expect(back.look == wood.look and back.level == wood.level and back.uid == wood.uid, "a look round-trips through JSON with the rest of the instance (%s)" % str(back.look))
	# An old save: no look key, loads unchanged, writes the same shape back.
	var old_row: Dictionary = IS.make(&"wood_log", 1, {}, 3).to_dict()
	_expect(not old_row.has("look"), "a log without a look writes no look key: %s" % str(old_row.keys()))
	var old_back = IS.from_dict(old_row)
	_expect(old_back.look.is_empty() and old_back.level == 3, "an old save without look loads unchanged (look %s, level %d)" % [str(old_back.look), old_back.level])
	_expect(not old_back.to_dict().has("look"), "an old row rewrites without a look (nothing is auto-filled)")
	# Malformed looks are refused, never repaired into a different wood.
	var forged: Array[Dictionary] = [
		{"species": "ebony", "color": "#33201a", "family": "deep black-brown", "grain": "tight"},
		{"species": "pine", "color": "#00ff00", "family": "light yellow-brown", "grain": "wide soft"},
		{"species": "pine", "color": "#d7b268", "family": "reddish-brown", "grain": "wide soft"},
		{"species": "pine", "color": "#d7b268", "family": "light yellow-brown", "grain": "wide soft", "rarity": "legendary"},
		{"species": "pine", "color": "pale", "family": "light yellow-brown", "grain": "wide soft"},
		{"color": "#d7b268"},
	]
	for look in forged:
		var s = IS.from_dict({"id": "wood_log", "count": 1, "level": 1, "look": look})
		_expect(s.look.is_empty(), "a forged look is dropped, not repaired: %s" % str(look))
	_expect(ML.validate({"species": "pine", "color": "#d7b268", "family": "light yellow-brown", "grain": "wide soft"}) == "", "the honest pine look validates")
	print("[t_matlook] save: look round-trip ok; old row unchanged; %d forged looks refused" % forged.size())

## Save rows through the real load path (save sanitizer + Inventory.load_array), not just
## ItemStack alone: an old row loads unchanged, an honest look survives, a forged one is dropped.
func _test_save_fixture() -> void:
	var f := FileAccess.open("res://tests/fixtures/matlook_rows.json", FileAccess.READ)
	_expect(f != null, "the save-row fixture is readable")
	if f == null:
		return
	var rows: Dictionary = JSON.parse_string(f.get_as_text())
	var SS = load("res://scripts/core/save_sanitizer.gd")
	var clean: Array = SS.stacks([rows["legacy_wood"], rows["honest_wood"], rows["forged_wood"]])
	var bag = INV.new(6)
	bag.load_array(clean)
	var legacy = bag.slots[0]
	var honest = bag.slots[1]
	var forged = bag.slots[2]
	_expect(legacy != null and legacy.def_id == &"wood_log" and legacy.look.is_empty() and legacy.level == 4, "an old save row without look loads unchanged and stays unlooked")
	_expect(honest != null and honest.look == rows["honest_wood"]["look"], "an honest look survives the save load path (%s)" % str(honest.look if honest else null))
	_expect(forged != null and forged.def_id == &"wood_log" and forged.look.is_empty(), "a forged look is dropped on load, the log still loads (%s)" % str(forged.look if forged else null))
	# The whole bag round-trip: to_array -> JSON -> load_array keeps the look on its own row.
	var rows_out: Array = bag.to_array()
	var reloaded = INV.new(6)
	reloaded.load_array(JSON.parse_string(JSON.stringify(rows_out)))
	var again = reloaded.slots[1]
	_expect(again != null and again.look == rows["honest_wood"]["look"], "a look survives Inventory.to_array -> JSON -> load_array (%s)" % str(again.look if again else null))
	# The server's escrow path (Provenance.strip + from_dict, as act.deposit/char.receive use it)
	# keeps the look: a traded log can be re-read without losing its wood.
	var prov = load("res://scripts/server/provenance.gd")
	var stamped: Dictionary = prov.strip(prov.stamp(rows["honest_wood"].duplicate(true), "i7.0", "gather", 7))
	var escrowed = IS.from_dict(stamped)
	_expect(escrowed.look == rows["honest_wood"]["look"], "the server escrow path keeps a log's look (%s)" % str(escrowed.look))
	print("[t_matlook] fixture: legacy unlooked=%s honest=%s forged dropped=%s bag-roundtrip=%s escrow=%s" % [legacy != null and legacy.look.is_empty(), honest != null and honest.look.get("species", "") == "pine", forged != null and forged.look.is_empty(), again != null and again.look == rows["honest_wood"]["look"], escrowed.look == rows["honest_wood"]["look"]])

# --- 5. the server gather path ---------------------------------------------------------

func _test_server_gather() -> void:
	var wf = load("res://scripts/server/world_facade.gd").new()
	wf.add_node("tree", Vector3(0, 0, 0), [{"item": "wood_log", "tool": "none", "min": 1, "max": 1, "left": 20}], 1, "AcaciaTree")
	var CS := load("res://scripts/server/character_store.gd")
	var st = CS.new(wf, "", 4242)
	var made: Dictionary = st.apply("char.create", 1, {"name": "Woody"}, 1)
	_expect(bool(made.get("ok", false)), "a server character is created")
	var res: Dictionary = st.apply("act.gather", 1, {"node_id": "tree", "option": 0}, 2)
	_expect(bool(res.get("ok", false)), "act.gather on a tree succeeds (%s)" % str(res.get("err", "")))
	var uids: Array = res.get("r", {}).get("uids", []) if res.get("r") is Dictionary else []
	var ch = st.character(1)
	var i: int = ch.find_uid(str(uids[0])) if not uids.is_empty() else -1
	var row: Dictionary = ch.d.bag[i] if i >= 0 else {}
	var look: Variant = row.get("look")
	_expect(look is Dictionary and str((look as Dictionary).get("species", "")) == "acacia", "the server's gathered log is acacia: %s" % str(look))
	_expect(ML.validate(look) == "", "the server's look passes the range check (%s)" % ML.validate(look))
	_expect(st.invariants().is_empty(), "invariants hold with a look on the row: %s" % str(st.invariants()))
	# Same journal, same colours: two stores on the same seed agree.
	var wf2 = load("res://scripts/server/world_facade.gd").new()
	wf2.add_node("tree", Vector3(0, 0, 0), [{"item": "wood_log", "tool": "none", "min": 1, "max": 1, "left": 20}], 1, "AcaciaTree")
	var st2 = CS.new(wf2, "", 4242)
	st2.apply("char.create", 1, {"name": "Woody"}, 1)
	var res2: Dictionary = st2.apply("act.gather", 1, {"node_id": "tree", "option": 0}, 2)
	var ch2 = st2.character(1)
	var row2: Dictionary = {}
	for r: Variant in ch2.d.bag:
		if r is Dictionary and r.has("look"):
			row2 = r
	_expect(bool(res2.get("ok", false)) and row2.get("look") == look, "the same journal draws the same log colour (%s vs %s)" % [str(row2.get("look")), str(look)])
	# A hand-edited row with a malformed look is refused on the way in, not repaired.
	ch.d.bag[i]["look"] = {"species": "ebony", "color": "#101010", "family": "deep black-brown", "grain": "tight"}
	var loaded = ch.inventory()
	var got = loaded.slots[i]
	_expect(got != null and got.look.is_empty(), "a malformed look in a server row is dropped (%s)" % str(got.look if got else "no stack"))
	ch.d.bag[i].erase("look")
	print("[t_matlook] server look=%s replay=%s" % [str(look), row2.get("look") == look])

# --- 6. grouping keeps species apart ---------------------------------------------------

func _test_grouping() -> void:
	var bag = INV.new(12)
	for sp in ["oak", "oak", "birch"]:
		var s = IS.make(&"wood_log", 1, {}, 4)
		s.look = ML.look_for_species(str(sp), 1)
		bag.add(s)
	bag.add(IS.make(&"wood_log", 1, {}, 4))  # a legacy log with no look
	# A fourth log: another oak, different jitter — same species, so it belongs to the oak group.
	var oak2 = IS.make(&"wood_log", 1, {}, 4)
	oak2.look = ML.look_for_species("oak", 99)
	bag.add(oak2)
	var groups: Array = bag.groups()
	var species_seen: PackedStringArray = []
	var legacy := 0
	var oak_units := 0
	for g: Dictionary in groups:
		var sp := str(g.get("species", ""))
		if sp == "oak":
			oak_units = int(g.get("units", 0))
		if sp == "":
			legacy += 1
		elif sp not in species_seen:
			species_seen.append(sp)
	_expect(oak_units == 3, "the group key is the species, not the exact colour: 3 oak logs (one a different jitter) are one group (%d)" % oak_units)
	_expect(groups.size() == 3 and legacy == 1 and oak_units == 3, "the bag view keeps oak, birch and an unlooked log apart (%d groups, legacy %d)" % [groups.size(), legacy])
	_expect("oak" in species_seen and "birch" in species_seen, "each wood group names its species (%s)" % ", ".join(species_seen))
	print("[t_matlook] groups=%d species=%s" % [groups.size(), ", ".join(species_seen)])

# --- 7. the store/economy gates ---------------------------------------------------------

## The server character store is this job's in-scope gate: a row's look is validated through
## ItemStack.from_dict, so a well-formed look is kept and a forged one is refused. The economy
## vault's own whitelist (data/economy/limits.json + scripts/economy/asset_validator.gd) is
## OUTSIDE this job's scope regex; its verdict is measured and printed, not asserted, so the gap
## reaches the report instead of failing a check this job may not fix.
func _test_econ_gate() -> void:
	var good: Dictionary = IS.make(&"wood_log", 1, {}, 5).to_dict()
	good.look = ML.look_for_species("oak", 5)
	var kept = IS.from_dict(good)
	_expect(kept.look == good.look, "the store keeps a well-formed look (item gate)")
	var bad: Dictionary = good.duplicate(true)
	bad.look = {"species": "ebony", "color": "#101010", "family": "deep black-brown", "grain": "tight"}
	_expect(IS.from_dict(bad).look.is_empty(), "the store refuses a forged look (item gate)")
	var ER = load("res://scripts/economy/econ_rules.gd")
	var EC = load("res://scripts/economy/econ_catalog.gd")
	var AV = load("res://scripts/economy/asset_validator.gd")
	var validator = AV.new(EC.from_data(), ER.load_default())
	var good_verdict := str(validator.item(good))
	var bad_verdict := str(validator.item(bad))
	_expect(bad_verdict != "", "the vault refuses a forged look (%s)" % bad_verdict)
	# Appearance is not value: two logs of different species, same def and level, quote the same.
	var other: Dictionary = IS.make(&"wood_log", 1, {}, 5).to_dict()
	other.look = ML.look_for_species("birch", 5)
	other.uid = "i8.0"
	_expect(str(validator.item(other)) == str(validator.item(good)), "one species is not worth more than another at the vault gate (%s vs %s)" % [str(validator.item(good)), str(validator.item(other))])
	if good_verdict != "":
		_seen_gap = true
		print("[t_matlook] GAP vault.item(valid look) = \"%s\": data/economy/limits.json and scripts/economy/asset_validator.gd are outside this job's scope; the integrator must whitelist look there" % good_verdict)
	else:
		print("[t_matlook] vault keeps a valid look; forged = \"%s\"" % bad_verdict)
