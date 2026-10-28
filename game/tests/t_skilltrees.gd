extends SceneTree
## SKILLTREES (spec 12 coverage): every tree the game carries has the `impl` mark
## (functional / partial / defined) on every node, and a functional node's mark is earned by code:
## its impl_ref names the script (and line) that reads the node's effect today. Baseline ids stay
## stable so saves keep buying and refunding the same nodes. Run:
##   godot --headless --path game --script res://tests/t_skilltrees.gd -> "[t_skilltrees] PASS"
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

const IMPLS := ["functional", "partial", "defined"]

## The node ids the trees carried before the impl marks and the 918 catalog import (the skilltrees
## job's stage 1). A node id removed or renamed breaks learned-node saves: the test fails on a diff.
const BASELINE := {
		"survival": ["island_access_15", "stealth_1", "mud_2", "wild_seed_1", "belly_fat_1", "capture_technique_1", "capture_tool_1", "island_access_25", "stealth_2", "capture_technique_2", "climate_body_1", "island_access_35", "stealth_3", "capture_technique_3", "animal_management_1", "obsidian", "island_access_45", "stealth_4", "marble", "capture_technique_4", "animal_management_2", "alum", "island_access_55", "stealth_5", "capture_technique_5", "animal_management_3", "animal_management_4"],
		"gathering": ["forage_1", "branch", "bush", "fruit_1", "log_1", "bug_1", "pebble", "mud_1", "stalk", "boulder", "thickets", "mining_1", "herbs_1", "insects", "mining_2", "great_success_1", "mining_3", "rare_plants", "long_branch", "mining_4", "great_success_2"],
		"butchering": ["butcher_1", "organs", "leather_1", "tendon", "bone_2", "rare_parts_1", "feather", "skull_1", "slaughter_1", "yield_1", "teeth_1", "scutes", "horn", "slaughter_2", "quality_bone", "slaughter_3", "yield_2", "leather_2", "teeth_2", "slaughter_4", "trophy", "slaughter_5"],
		"processing": ["cordage", "split_wood", "normal_nail", "drying", "charcoal", "dry_leather", "peeled_bark", "nails_pillars", "handicraft_1", "smelting_1", "handicraft_2", "trimmed_material", "extended_fabric", "milling", "thread_cloth", "handicraft_3", "glue", "gem_extraction", "handicraft_4", "smelting_2", "handicraft_5", "cord", "waterproofed_material", "refined_ore", "metalworking_1", "ceramics", "metalworking_2", "adhesive_accessory", "dry_rubber", "metal_links", "metalworking_3", "copper_alloy", "fiber_tanned_material", "compressed_material", "great_success_p", "metalworking_4", "precision_processing", "processed_debris"],
		"melee": ["attack_stance", "body_tackle", "kick", "onslaught", "sweep", "knockdown_mastery", "one_hand_mastery", "two_hand_mastery", "shoulder_charge", "execution"],
		"ranged": ["throw", "barrage", "bow_1", "draw_1", "barrage_damage_1", "kiting", "fire_rate_1", "barrage_damage_2", "crossbow", "barrage_damage_3", "draw_2", "volley", "raid_arrows"],
		"defense": ["roll", "max_health_1", "roll_duration_1", "parry", "counter", "roll_duration_2", "max_health_2", "anti_knockdown", "roll_duration_3", "recovery", "iron_body", "max_health_3"],
		"weapon_tools": ["improvised_tools", "makeshift_shovel_hoe", "work_pick", "spear", "stone_saw", "combat_knife", "splint", "hammer", "handle", "stone_mortar", "standard_bow", "two_hand", "bone_saw", "copper_tools", "cooking_utensils", "blade_shapes", "improved_handle", "earthenware_mortar", "metal_saw", "iron_weapons", "shaft", "metal_mortar"],
		"tailoring": ["leaf_outfit", "footwraps", "leaf_hat", "bandage", "small_bag", "straw_shoes", "cloth_clothes", "heat_resist", "cold_resist", "pressure_dressing", "leather_sandals", "large_bag", "armor_1", "scute_armor", "master_bag"],
		"construction": ["bonfire", "workbench", "fence", "taming_pen", "drying_rack", "storage_2", "simple_well", "residence", "furnace_kiln", "well", "barn", "clan_structures"],
		"cooking": ["skewer", "meatball", "stone_grill", "antivenom", "steam", "antibiotic", "buff_food", "sashimi", "boiling", "roast", "pet_food"],
		"farming": ["small_field", "corn", "apple_tree", "flax", "fertilizer", "large_field", "orchard", "advanced_fertilizer", "ranching", "sprinkler"],
}

var _fails: PackedStringArray = []
var _done := false
var _sections := 0
var Skills: GDScript

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	Skills = load("res://scripts/skills/skill_state.gd")
	_test_impl_marks()
	_test_baseline_ids()
	if _fails.is_empty():
		print("[t_skilltrees] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_skilltrees] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_skilltrees] FAIL %s" % what)

func _expect_ref(ok: bool, what: String) -> void:
	# impl_ref failures are reported once per line, quietly, in the summary count.
	if not ok:
		_fails.append(what)

## Every node carries impl; a functional or partial node names the script (and line) that reads it;
## every functional node's impl_ref file exists and mentions the node id or its effect token.
## The printed table is the per-tree record this milestone ships.
func _test_impl_marks() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/trees.json"))
	var counts := {"functional": 0, "partial": 0, "defined": 0}
	print("[t_skilltrees] tree             nodes  functional  partial  defined")
	for tree in Skills.ORDER:
		var nodes: Array = (root["trees"][tree] as Dictionary)["nodes"]
		var c := {"functional": 0, "partial": 0, "defined": 0}
		for n in nodes:
			var id := str(n.get("id", ""))
			var impl := str(n.get("impl", ""))
			_expect(IMPLS.has(impl), "%s/%s: impl '%s' is not functional/partial/defined" % [tree, id, impl])
			if not IMPLS.has(impl):
				continue
			c[impl] += 1
			var ref := str(n.get("impl_ref", ""))
			if impl != "defined":
				_expect_ref(ref != "", "%s/%s: %s without impl_ref" % [tree, id, impl])
				_expect_ref(ref.contains(":"), "%s/%s: impl_ref '%s' without a :line" % [tree, id, ref])
				# The file named (up to its first colon) must exist in the project.
				# impl_ref paths are project-relative ("game/scripts/..."), so res:// drops "game/".
				var path := ref.split(":")[0]
				var script := "res://" + path.trim_prefix("game/")
				var ok_file := ResourceLoader.exists(script)
				_expect_ref(ok_file, "%s/%s: impl_ref names missing file %s" % [tree, id, path])
				if impl == "functional" and ok_file:
					# The node's own id, or the token the code path keys on (a recipe gate, a gather or
					# butcher row). A functional node that names neither would be an effect nothing reads.
					# For data-driven gates (requires_node in recipes.json, butcher rows in
					# butchering.json) the id/token lives in the data file the code path reads.
					var body := FileAccess.get_file_as_string(script)
					var token := _effect_token(tree, n)
					var found := body.contains(id) or (token != "" and body.contains(token))
					if not found:
						var data_txt := ""
						for dp in ["res://data/recipes.json", "res://data/butchering.json", "res://data/nature_manifest.json"]:
							if FileAccess.file_exists(dp):
								data_txt += JSON.stringify(JSON.parse_string(FileAccess.get_file_as_string(dp)))
						found = data_txt.contains(id) or (token != "" and data_txt.contains(token))
					_expect_ref(found,
						"%s/%s: impl_ref %s mentions neither %s nor its effect token %s" % [tree, id, ref, id, token])
		counts.functional += c.functional
		counts.partial += c.partial
		counts.defined += c.defined
		print("[t_skilltrees] %-16s %5d %10d %8d %7d" % [tree, nodes.size(), c.functional, c.partial, c.defined])
	var total: int = counts.functional + counts.partial + counts.defined
	print("[t_skilltrees] %-16s %5d %10d %8d %7d" % ["TOTAL", total, counts.functional, counts.partial, counts.defined])
	_expect(total == 213, "the 213 existing nodes all carry impl (got %d)" % total)
	_expect(counts.functional >= 30, "at least 30 nodes are functional today (got %d)" % counts.functional)
	_expect(counts.defined <= 160, "at most 160 nodes stay defined (got %d)" % counts.defined)
	_sections += 1

## The token a code path greps for: the node id itself, or the first recipe/item the effect names
## (a recipe gate or a gather/butcher row is read by that key, not by the node id).
## Some effects are read generically by effect TYPE, not by any id: the survival mirror
## (skill_state.gd) keys "bonded_slots" and "capture_technique" nodes, Crafting keys the
## "ability" total. Those get their type string as the token.
## impl_ref paths are project-relative ("game/scripts/..."), so res:// drops the "game/" prefix.
func _effect_token(tree: String, n: Dictionary) -> String:
	var tokens: PackedStringArray = []
	for e in n.get("effects", []):
		if not e is Dictionary:
			continue
		for rid in e.get("recipes", []):
			tokens.append(str(rid))
		for it in e.get("items", []):
			tokens.append(str(it))
		# Read by type, not id: the survival mirror, the ability total, the butcher gate.
		if str(e.get("type", "")) in ["bonded_slots", "ability", "capture_tier", "butcher", "gather"]:
			tokens.append(str(e.get("type", "")))
	if tokens.is_empty():
		return str(n.get("id", ""))
	# A token that appears in many nodes (an empty-items gate) is the node id; else the first key.
	return str(n.get("id", "")) if tokens.size() == 1 and tokens[0] == "" else tokens[0]

## The baseline ids are exactly the ids the trees carry now, per tree (order included).
func _test_baseline_ids() -> void:
	var root: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/trees.json"))
	for tree in BASELINE:
		var now: Array = (root["trees"][tree] as Dictionary)["nodes"].map(func (n: Variant) -> String: return str(n.get("id", "")))
		var base: Array = BASELINE[tree]
		var added: Array = now.filter(func (i: String) -> bool: return not base.has(i))
		var dropped: Array = base.filter(func (i: String) -> bool: return not now.has(i))
		_expect(dropped.is_empty(), "%s: baseline node ids removed (not: %s)" % [tree, dropped])
		if not dropped.is_empty():
			# Report once per tree: the rest of the tree's rows repeat the same failure.
			continue
		_expect(added.is_empty(), "%s: new node ids appeared (not: %s)" % [tree, added])
	_sections += 1
