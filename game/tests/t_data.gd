extends SceneTree
## W2-DATA: item and recipe data validator plus a progression walk.
## 1. Every id that recipes, factions, rules, statuses, climates, nature, butchering and farming
##    name exists; every item has market_category and rarity (and item_rarity.json mirrors it).
## 2. A walk from a fresh survivor (bare hands) over the real sources only: gathering on the islands
##    islands.json lists (their climate's vegetation x nature_manifest yields, with the same tool and
##    pick-tier gates as HarvestNode), butchering the species those islands spawn, farming, the
##    capture/taming systems and recipes (stations need their kit, min_level needs reachable material
##    levels). Faction crates are never a source. Any item or recipe it cannot reach fails, except items
##    that name the system they wait on in "source_pending". A second walk over the start island alone
##    proves the processed basics (twine, dried hide) come before anything needs them and no metal grows
##    there (world-design.md:66: the home grassland yields no ore).
## 3. Ladder, nets, armour bands and the real crafting planner agree with the walk. The ladder is
##    GAUNTLET's Stone -> Bone -> Flint -> Obsidian -> Copper -> Bronze -> Iron -> Steel: every rung has
##    tools, no rung costs less or unlocks earlier than the one below, each mined ore needs the pick of
##    the rung below it, and no recipe turns material above flint into gear below that rung's skill node.
##    At equal level nothing beats the steel item of its slot unless it is gated at least as high, and the
##    real planner shows each tier above the last and a level 5 tool clearly above level 1 (GAUNTLET).
## 4. Crafting.progression_block refuses a requires_node recipe until the node is learned and names the
##    node's tree and level (hook 6).
## 5. bot_survivor's CATEGORY_ITEMS covers every slot of the recipes it crafts (hook 13).
## Item scripts reference the Data autoload, so they load on the first frame after it exists.

const D := "res://data/"
const RUNGS := ["stone", "bone", "flint", "obsidian", "copper", "bronze", "iron", "steel"]
## Special families IslandScatter._scatter_special_tiles plants on every island.
const SPECIAL_FAMILIES := ["mud", "clay", "berry_bush", "tree_stump", "narcoberry_bush"]
## cleared_by entries in statuses.json that are actions or places, not items.
const STATUS_ACTIONS := ["cauterise", "residence", "struggle", "pet_aggro", "wash", "drink"]  # wash/drink: WaterAccess verbs (WATER)
## Seconds a capture or a taming takes, for the time log only (# ASSUMPTION).
const CAPTURE_SECONDS := 60.0
const TAME_SECONDS := 120.0
const BUTCHER_SECONDS := 1.6 ## corpse.gd: one radial hex per loot stack, 1.6 s each
## Gear slots and the top-rung (steel) item each is measured against; "weapon" is the weapon role.
const GEAR_SLOTS := {"armor_head": "steel_helm", "armor_body": "steel_cuirass", "armor_arms": "steel_bracers", "armor_legs": "steel_greaves", "weapon": "steel_sword"}

var fails: Array[String] = []
var _done := false
var items: Dictionary = {}     # id -> row
var recipes: Array = []        # non-staged rows
var all_recipes: Array = []
var nature: Dictionary = {}
var climates: Dictionary = {}
var trees_nodes: Dictionary = {} # node id -> tree id
var trees: Dictionary = {}       # trees.json "trees"
var factions: Dictionary = {}    # world/factions.json
var creatures: Dictionary = {}  # species -> row
var islands: Array = []          # islands.json rows
var PS: GDScript
var CR: GDScript
var INV: GDScript
var IS: GDScript
var opt_tools: Dictionary = {}
var opt_seconds: Dictionary = {}
# walk state
var cost: Dictionary = {}  # id -> seconds per unit from bare hands
var lvl: Dictionary = {}   # id -> highest reachable item level
var how: Dictionary = {}   # id -> first source found
var made: Dictionary = {}  # recipe id -> true
var pick_tier := -1        # best reachable pick tier index
var home_cost: Dictionary = {} # cost after a walk of the start island alone
var home_how: Dictionary = {}

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	PS = load("res://scripts/items/progression_scaling.gd")
	CR = load("res://scripts/items/crafting.gd")
	INV = load("res://scripts/items/inventory.gd")
	IS = load("res://scripts/items/item_stack.gd")
	var hn: Dictionary = (load("res://scripts/world/harvest_node.gd") as GDScript).get_script_constant_map()
	opt_tools = hn.get("OPTION_TOOLS", {})
	opt_seconds = hn.get("OPTION_SECONDS", {})
	_load_all()
	_check_items()
	_check_references()
	_check_processing_chain()
	_walk(true)
	home_cost = cost.duplicate()
	home_how = how.duplicate()
	cost.clear()
	lvl.clear()
	how.clear()
	made.clear()
	pick_tier = -1
	_check_home()
	_walk(false)
	_check_reachability()
	_check_ladder()
	_check_pick_chain()
	_check_ungated_gear()
	_check_top_rung()
	_check_nets()
	_check_armor()
	_check_no_multiplying_loops()
	_check_split_leaks()
	_check_structures()
	_check_planner()
	_check_tier_planner()
	_check_node_gate()
	_check_bot_map()
	if fails.is_empty():
		print("[t_data] PASS items=%d recipes=%d" % [items.size(), recipes.size()])
		quit(0)
	else:
		for f in fails:
			print("[t_data] FAIL %s" % f)
		quit(1)
	return true

func _expect(ok: bool, label: String) -> void:
	if not ok:
		fails.append(label)

func _json(path: String) -> Variant:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(D + path))
	_expect(v != null, "%s parses" % path)
	return v if v != null else {}

func _load_all() -> void:
	for row in _json("items.json").get("items", []):
		_expect(not items.has(row["id"]), "duplicate item id %s" % row["id"])
		items[str(row["id"])] = row
	var rdoc: Dictionary = _json("recipes.json")
	var seen := {}
	for row in rdoc.get("recipes", []):
		_expect(not seen.has(row["id"]), "duplicate recipe id %s" % row["id"])
		seen[row["id"]] = true
		all_recipes.append(row)
		if str(row.get("implementation_status", "")) != "staged":
			recipes.append(row)
	nature = _json("nature_manifest.json").get("families", {})
	var cdoc: Dictionary = _json("world/climates.json")
	for k in cdoc:
		if not str(k).begins_with("_"):
			climates[k] = cdoc[k]
	trees = _json("skills/trees.json").get("trees", {})
	factions = _json("world/factions.json")
	for t in trees:
		for n in trees[t].get("nodes", []):
			_expect(not trees_nodes.has(n["id"]), "skill node id %s is unique across trees" % n["id"])
			trees_nodes[str(n["id"])] = t
	for f in DirAccess.get_files_at(D + "creatures"):
		var row: Variant = _json("creatures/" + f) if f.ends_with(".json") else null
		if row is Dictionary and (row as Dictionary).has("capture_tier"):
			creatures[f.get_basename()] = row
	var idoc: Dictionary = _json("world/islands.json")
	for k in idoc:
		if idoc[k] is Dictionary and climates.has(str(idoc[k].get("climate", ""))):
			islands.append(idoc[k])

func _has_cat(id: String, cat: String) -> bool:
	return items.has(id) and cat in items[id].get("categories", [])

func _ids_with_cat(cat: String) -> Array:
	return items.keys().filter(func(id: String) -> bool: return _has_cat(id, cat))

func _station_kits(station: String) -> Array:
	return items.keys().filter(func(id: String) -> bool: return str(items[id].get("place_as", "")) == station)

# ---- 1. item fields and references ---------------------------------------------------------

func _check_items() -> void:
	var market: Dictionary = _json("world/market.json").get("base_price_tstones", {})
	var rdoc: Dictionary = _json("item_rarity.json")
	var order: Array = rdoc.get("order", [])
	var mirror: Dictionary = rdoc.get("items", {})
	for id: String in items:
		var row: Dictionary = items[id]
		_expect(market.has(str(row.get("market_category", ""))), "%s market_category '%s' is a market.json category" % [id, row.get("market_category", "")])
		_expect(order.has(str(row.get("rarity", ""))), "%s rarity '%s' is a known tier" % [id, row.get("rarity", "")])
		_expect(str(mirror.get(id, "")) == str(row.get("rarity", "")), "item_rarity.json mirrors %s rarity" % id)
		var cats: Array = row.get("categories", [])
		_expect(not cats.is_empty(), "%s has categories" % id)
		if cats.any(func(c: String) -> bool: return c.begins_with("armor_")):
			var ins: Variant = row.get("insulation", null)
			_expect(ins is Dictionary and (ins as Dictionary).has("cold") and (ins as Dictionary).has("heat"), "%s has insulation {cold, heat}" % id)
	for id in mirror:
		_expect(items.has(id), "item_rarity.json lists unknown item %s" % id)
	# Armour with no render of its own borrows an armour picture of its slot, never a material's (raw hide).
	var icons: Dictionary = _json("icons_manifest.json")
	var rendered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/icons/render/manifest.json")).get("items", {})
	for id: String in items:
		var alias := str(icons.get("aliases", {}).get(id, ""))
		for slot in ["armor_head", "armor_body", "armor_arms", "armor_legs"]:
			if _has_cat(id, slot) and not rendered.has(id) and alias != "":
				_expect((alias == slot.replace("armor_", "armour_") or _has_cat(alias, slot)) and icons.get("icons", {}).has(alias), "unrendered %s borrows the %s icon, not an %s picture" % [id, alias, slot])

func _check_references() -> void:
	var tool_classes := {}
	for id in items:
		tool_classes[str(items[id].get("tool_class", "none"))] = true
	for r: Dictionary in all_recipes:
		var rid := str(r["id"])
		_expect(items.has(str(r.get("output", {}).get("id", ""))), "recipe %s output exists" % rid)
		for k in ["input_id", "burn_output"]:
			if r.has(k):
				_expect(items.has(str(r[k])), "recipe %s %s %s exists" % [rid, k, r[k]])
		if r.has("requires_tool"):
			_expect(tool_classes.has(str(r["requires_tool"])), "recipe %s requires_tool %s is some item's tool_class" % [rid, r["requires_tool"]])
		if r.has("requires_node"):
			_expect(trees_nodes.has(str(r["requires_node"])), "recipe %s requires_node %s is a trees.json node" % [rid, r["requires_node"]])
		var st := _station(r)
		_expect(st == "" or not _station_kits(st).is_empty(), "recipe %s station %s has a kit (place_as)" % [rid, st])
		var prim := 0
		for s: Dictionary in r.get("slots", []):
			_expect(not _ids_with_cat(str(s.get("category", ""))).is_empty(), "recipe %s slot category %s matches an item" % [rid, s.get("category", "")])
			_expect(int(s.get("count", 0)) > 0, "recipe %s slot count > 0" % rid)
			prim += 1 if bool(s.get("primary", false)) else 0
		_expect(prim == 1, "recipe %s has exactly one primary slot" % rid)
	for rep: Dictionary in _json("recipes.json").get("repairs", []):
		_expect(PS.TOOL_TIERS.has(StringName(str(rep.get("tier", "")))), "repair tier %s is a tool tier" % rep.get("tier", ""))
		_expect(not _station_kits(str(rep.get("station", ""))).is_empty(), "repair %s station has a kit" % rep.get("tier", ""))
		for s: Dictionary in rep.get("slots", []):
			_expect(not _ids_with_cat(str(s.get("category", ""))).is_empty(), "repair %s slot %s matches an item" % [rep.get("tier", ""), s.get("category", "")])
	var repaired: Array = _json("recipes.json").get("repairs", []).map(func(x: Dictionary) -> String: return str(x.get("tier", "")))
	for t in PS.TOOL_TIERS:
		_expect(repaired.has(str(t)), "a repair row covers tier %s" % t)
	for fname in climates:
		for fam in climates[fname].get("vegetation", []):
			_expect(nature.has(fam), "climate %s vegetation %s is a nature family" % [fname, fam])
		for m in climates[fname].get("materials", []):
			_expect(items.has(str(m.get("id", ""))), "climate %s material %s exists" % [fname, m.get("id", "")])
		# A wild crop grows only where its manifest says, and as a find (a fixed count), not the 24-plant floor.
		for fam in climates[fname].get("vegetation", []):
			var row: Dictionary = nature.get(fam, {})
			if str(row.get("role", "")) == "crop":
				_expect(fname in row.get("climates", []) and int(row.get("count", 0)) > 0, "wild crop %s on %s is in its manifest climates %s with a count (%d)" % [fam, fname, row.get("climates", []), int(row.get("count", 0))])
	for fam in nature:
		for k in nature[fam].get("harvest", {}):
			_expect(items.has(k), "nature %s yields unknown item %s" % [fam, k])
		for k in nature[fam].get("min_pick_tier", {}):
			_expect(PS.TOOL_TIERS.has(StringName(str(nature[fam]["min_pick_tier"][k]))), "nature %s pick tier for %s is a tool tier" % [fam, k])
	for sp in _json("butchering.json").get("species", {}):
		_expect(creatures.has(sp), "butchering species %s has a creature file" % sp)
		var t: Dictionary = _json("butchering.json")["species"][sp]
		for row in t.get("base", []) + t.get("rare", []):
			_expect(items.has(str(row.get("id", ""))), "butchering %s drops unknown %s" % [sp, row.get("id", "")])
	var crops: Dictionary = _json("farming.json").get("crops", {})
	for c in crops:
		_expect(items.has(str(crops[c].get("seed", ""))) and items.has(str(crops[c].get("output", ""))), "farming crop %s seed and output exist" % c)
	for fk in factions:
		var f: Variant = factions[fk]
		if f is Dictionary:
			var bands: Dictionary = (f as Dictionary).get("crate_bands", {})
			for b in bands:
				for id in bands[b]:
					_expect(items.has(str(id)), "faction %s crate %s item %s exists" % [fk, b, id])
	for id in _json("world/rules.json").get("warp_ruin", {}).get("loot", []):
		_expect(items.has(str(id)), "rules.json warp_ruin loot %s exists" % id)
	for s: Dictionary in _json("statuses.json").get("statuses", []):
		for id in s.get("cleared_by", []):
			_expect(items.has(str(id)) or STATUS_ACTIONS.has(str(id)), "status %s cleared_by %s is an item or a listed action" % [s.get("id", ""), id])

func _station(r: Dictionary) -> String:
	var v: Variant = r.get("station", null)
	return "" if v == null or str(v) == "null" else str(v)

# ---- 2. the walk -------------------------------------------------------------------------

func _offer(id: String, c: float, level: int, why: String) -> bool:
	if not items.has(id):
		return false
	var better := false
	if not cost.has(id) or c < float(cost[id]) - 0.001:
		cost[id] = c
		better = true
	if not lvl.has(id) or level > int(lvl[id]):
		lvl[id] = level
		better = true
	if not how.has(id):
		how[id] = why
	return better

func _has_tool(cls: String) -> bool:
	if cls == "" or cls == "none":
		return true
	for id in cost:
		if str(items[id].get("tool_class", "none")) == cls:
			return true
	return false

func _tier_of(id: String) -> int:
	return PS.TOOL_TIERS.find(PS.material_tier(StringName(id), {}))

func _walk(home_only: bool) -> void:
	var butch: Dictionary = _json("butchering.json").get("species", {})
	var crops: Dictionary = _json("farming.json").get("crops", {})
	var walked := islands.filter(func(i: Dictionary) -> bool: return not home_only or bool(climates[str(i["climate"])].get("home", false)))
	var spawned := {}
	for isl: Dictionary in walked:
		for ring in isl.get("spawns", {}).values():
			for g: Dictionary in ring:
				spawned[str(g.get("species", ""))] = true
	for _pass in 60:
		var changed := false
		# Gathering: what each island's climate vegetation (plus the special tiles) yields, tool-gated.
		for isl: Dictionary in walked:
			var cname := str(isl["climate"])
			var top := int(isl.get("tier", 1))
			for fam in climates[cname].get("vegetation", []) + SPECIAL_FAMILIES:
				var harvest: Dictionary = nature.get(fam, {}).get("harvest", {})
				for k: String in harvest:
					var need := str(nature[fam].get("min_pick_tier", {}).get(k, ""))
					var cls := "pick" if need != "" else str(opt_tools.get(k, "none"))
					if need != "" and pick_tier < PS.TOOL_TIERS.find(StringName(need)):
						continue
					if need == "" and not _has_tool(cls):
						continue
					var pair: Array = harvest[k] if harvest[k] is Array else [harvest[k], harvest[k]]
					var per := maxf(0.5, (float(pair[0]) + float(pair[1])) * 0.5)
					var secs := float(opt_seconds.get(k, 3.0 if cls != "none" else 1.6))
					changed = _offer(k, secs / per, top, "gather %s (%s)" % [fam, cname]) or changed
		# Butchering a kill needs a knife; only species the walked islands spawn; the corpse level follows the species tier.
		if _has_tool("knife"):
			for sp in butch:
				if not spawned.has(sp):
					continue
				var tier := int(creatures.get(sp, {}).get("tier", 1))
				for row in butch[sp].get("base", []) + butch[sp].get("rare", []):
					var per := maxf(0.5, (float(row.get("min", 1)) + float(row.get("max", row.get("min", 1)))) * 0.5)
					changed = _offer(str(row["id"]), BUTCHER_SECONDS / per, tier, "butcher %s" % sp) or changed
				# ALPHAS: any spawned species can roll an alpha, whose carcass adds ai.json alpha.loot.trophy.
				var trophy := str(_json("creatures/ai.json").get("alpha", {}).get("loot", {}).get("trophy", ""))
				if trophy != "":
					changed = _offer(trophy, BUTCHER_SECONDS / 0.08, tier, "alpha %s" % sp) or changed
		# Farming: a seed in a field; output level is capped by the Farming skill (60).
		if cost.has("field_small_kit"):
			for c in crops:
				var seed := str(crops[c].get("seed", ""))
				if cost.has(seed):
					var y := maxf(1.0, float(crops[c].get("base_yield", 1)))
					changed = _offer(str(crops[c]["output"]), (float(crops[c].get("growth_seconds", 120)) + float(cost[seed])) / y, 60, "farm %s" % c) or changed
		# FOODTORPOR: food left to spoil (Spoilage) turns into Spoiled Meat or Rot; one spoil per lot.
		for id in cost.keys():
			if _has_cat(id, "food") and _has_cat(id, "meat"):
				changed = _offer("spoiled_meat", float(cost[id]), int(lvl[id]), "spoil %s" % id) or changed
			elif _has_cat(id, "fruit"):
				changed = _offer("rot", float(cost[id]), int(lvl[id]), "spoil %s" % id) or changed
		# Capture (CaptureSystem) and taming (taming pen) are systems, not recipes.
		var nets := cost.keys().filter(func(id: String) -> bool: return int(items[id].get("capture_tier", 0)) > 0)
		if not nets.is_empty():
			changed = _offer("captured_animal", CAPTURE_SECONDS + float(cost[nets[0]]), 60, "capture with %s" % nets[0]) or changed
		if cost.has("captured_animal") and cost.has("makeshift_taming_pen"):
			changed = _offer("tamed_animal", TAME_SECONDS + float(cost["captured_animal"]), 60, "tame in a pen") or changed
		for r: Dictionary in recipes:
			changed = _try_recipe(r) or changed
		if not changed:
			return
	_expect(false, "walk converges within 60 passes")

func _try_recipe(r: Dictionary) -> bool:
	var st := _station(r)
	if st != "" and _station_kits(st).filter(func(k: String) -> bool: return cost.has(k)).is_empty():
		return false
	if r.has("requires_tool") and not _has_tool(str(r["requires_tool"])):
		return false
	var total := float(r.get("seconds", 3.0))
	var lvl_sum := 0
	var n := 0
	var prim_tier := -1
	for s: Dictionary in r.get("slots", []):
		var cat := str(s.get("category", ""))
		var count := int(s.get("count", 1))
		var best_c := INF
		var best_l := 0
		for id in cost:
			if _has_cat(id, cat):
				best_c = minf(best_c, float(cost[id]))
				best_l = maxi(best_l, int(lvl[id]))
				if bool(s.get("primary", false)):
					prim_tier = maxi(prim_tier, _tier_of(id))
		if best_c == INF:
			return false
		total += best_c * count
		lvl_sum += best_l * count
		n += count
	var out_level := mini(int(floor(float(lvl_sum) / float(maxi(1, n)))), int(r.get("max_level", 60)))
	if out_level < int(r.get("min_level", 0)):
		return false
	made[str(r["id"])] = true
	var out := str(r.get("output", {}).get("id", ""))
	var per := total / maxf(1.0, float(r.get("output", {}).get("count", 1)))
	var changed := _offer(out, per, out_level, "recipe %s" % r["id"])
	if bool(r.get("burn_on_fail", false)):
		changed = _offer(str(r.get("burn_output", "burnt_food")), per, out_level, "burnt %s" % r["id"]) or changed
	if str(items.get(out, {}).get("tool_class", "")) == "pick" and prim_tier > pick_tier:
		pick_tier = prim_tier
		changed = true
	return changed

func _check_reachability() -> void:
	var pending := []
	for id in items:
		if cost.has(id):
			continue
		if items[id].has("source_pending") or _staged_output(id):
			pending.append(id)
			continue
		_expect(false, "item %s is unreachable from a fresh survivor" % id)
	for r: Dictionary in recipes:
		_expect(made.has(str(r["id"])), "recipe %s can never be crafted (missing station, tool, input or material level %d)" % [r["id"], int(r.get("min_level", 0))])
	# A pending item must never be the only way to fill a slot, and never a crate reward.
	for r: Dictionary in recipes:
		for s: Dictionary in r.get("slots", []):
			var cat := str(s.get("category", ""))
			_expect(not _ids_with_cat(cat).filter(func(id: String) -> bool: return cost.has(id)).is_empty(), "recipe %s slot %s has a reachable item" % [r["id"], cat])
	for fk in factions:
		var f: Variant = factions[fk]
		if f is Dictionary:
			var bands: Dictionary = (f as Dictionary).get("crate_bands", {})
			for b in bands:
				for id in bands[b]:
					_expect(cost.has(str(id)), "crate item %s (%s %s) also has a gameplay source" % [id, fk, b])
	print("[t_data] reachable=%d/%d pending=%s best_pick=%s" % [cost.size(), items.size(), pending, PS.TOOL_TIERS[maxi(0, pick_tier)]])

## PRD 8.3 "Stalks / reeds -> twine -> rope", "Hide -> dried hide -> straps": raw hide only feeds the
## drying step, and rope is twisted from twine alone.
func _check_processing_chain() -> void:
	for r: Dictionary in all_recipes:
		var out := str(r.get("output", {}).get("id", ""))
		for s: Dictionary in r.get("slots", []):
			var takes := _ids_with_cat(str(s.get("category", "")))
			for id: String in takes:
				_expect(not _has_cat(id, "green_hide") or out == "dried_hide", "recipe %s slot %s takes raw %s; raw hide is dried first (Hide -> dried hide -> straps)" % [r["id"], s.get("category", ""), id])
			if out == "rope":
				_expect(takes == ["twine"], "recipe %s slot %s takes %s; rope is twisted from twine only" % [r["id"], s.get("category", ""), takes])

## The start island alone: twine and dried hide (and the straps and rope made from them) are reachable,
## and no ore or metal is (world-design.md:66; metal starts with desert copper_ore and volcanic black_iron).
func _check_home() -> void:
	# Static: whatever pick it needs, nothing growing or listed on a home climate is ore or metal.
	for cname in climates:
		if not bool(climates[cname].get("home", false)):
			continue
		for fam in climates[cname].get("vegetation", []) + SPECIAL_FAMILIES:
			for k: String in nature.get(fam, {}).get("harvest", {}):
				_expect(not (_has_cat(k, "ore") or _has_cat(k, "metal")), "home climate %s grows no metal, but %s yields %s" % [cname, fam, k])
		for m in climates[cname].get("materials", []):
			var mid := str(m.get("id", ""))
			_expect(not (_has_cat(mid, "ore") or _has_cat(mid, "metal")), "home climate %s lists no metal material, but lists %s" % [cname, mid])
	# Warp-ruin courier boxes (world-design.md:106) carry no ore or metal, wherever a ruin spawns.
	for id in _json("world/rules.json").get("warp_ruin", {}).get("loot", []):
		_expect(not (_has_cat(str(id), "ore") or _has_cat(str(id), "metal")), "warp ruin loot %s is not ore or metal" % id)
	for id in ["twine", "dried_hide", "hide_strap", "rope", "tent_kit"]:
		_expect(home_cost.has(id), "%s is obtainable on the start island" % id)
	var metal := home_cost.keys().filter(func(id: String) -> bool: return _has_cat(id, "ore") or _has_cat(id, "metal"))
	for id: String in metal:
		_expect(false, "start island yields no metal, but %s comes from %s" % [id, home_how.get(id, "?")])
	print("[t_data] start island: reachable=%d twine ~%.1f s dried_hide ~%.1f s hide_strap ~%.1f s rope ~%.1f s, metal %s" % [home_cost.size(), float(home_cost.get("twine", -1.0)), float(home_cost.get("dried_hide", -1.0)), float(home_cost.get("hide_strap", -1.0)), float(home_cost.get("rope", -1.0)), metal])

## Staged designs (implementation_status) stay in recipes.json but Data does not load them.
func _staged_output(id: String) -> bool:
	return all_recipes.any(func(r: Dictionary) -> bool: return str(r.get("implementation_status", "")) == "staged" and str(r.get("output", {}).get("id", "")) == id)

# ---- 3. ladder, nets, armour, loops, planner -------------------------------------------------

func _rung_tools(tier: String) -> Array:
	if tier == "stone":
		return ["stone_knife_work", "work_axe", "work_pick", "stone_knife"]
	var wpn := "spear" if tier in ["bone", "flint", "obsidian"] else "sword"
	return ["%s_knife" % tier, "%s_axe" % tier, "%s_pick" % tier, "%s_%s" % [tier, wpn]]

func _check_ladder() -> void:
	var prev_worst := 0.0
	var prev_gate := 0
	for tier: String in RUNGS:
		var worst := 0.0
		var gate := 0
		for id: String in _rung_tools(tier):
			_expect(cost.has(id), "rung %s tool %s is reachable" % [tier, id])
			if tier != "stone":
				_expect(str(PS.material_tier(StringName(id), {})) == tier, "%s reads as tier %s" % [id, tier])
			worst = maxf(worst, float(cost.get(id, 0.0)))
			gate = maxi(gate, _gate_level(id))
		print("[t_data] rung %-8s %s  ~%.1f s of gathering+crafting per tool (stations excluded), skill gate Lv %d" % [tier, ", ".join(_rung_tools(tier)), worst, gate])
		# A later rung never costs less time or unlocks at a lower skill level than the rung below it.
		_expect(worst >= prev_worst, "rung %s tools (~%.1f s) cost at least the rung below (~%.1f s)" % [tier, worst, prev_worst])
		_expect(gate >= prev_gate, "rung %s skill gate Lv %d is not below the rung below (Lv %d)" % [tier, gate, prev_gate])
		prev_worst = worst
		prev_gate = gate
	_expect(pick_tier == PS.TOOL_TIERS.find(&"steel"), "a steel pick is reachable (best %d)" % pick_tier)
	for id in ["tin_ore", "tin_ingot", "copper_ingot", "bronze_ingot", "iron_ingot", "steel_ingot", "forge_kit", "anvil_kit", "steamer_kit", "hoe"]:
		_expect(cost.has(id), "%s is reachable" % id)

## Level of the trees.json node a recipe for `out` requires (0 when ungated).
func _gate_level(out: String) -> int:
	var lv := 0
	for r: Dictionary in recipes:
		if str(r.get("output", {}).get("id", "")) == out:
			lv = maxi(lv, _node_level(r))
	return lv

## Level of the recipe's requires_node (0 when it has none).
func _node_level(r: Dictionary) -> int:
	var node := str(r.get("requires_node", ""))
	for n in trees.get(str(trees_nodes.get(node, "")), {}).get("nodes", []):
		if str(n.get("id", "")) == node:
			return int(n.get("level", 0))
	return 0

func _is_gear(id: String) -> bool:
	var row: Dictionary = items.get(id, {})
	return str(row.get("tool_class", "none")) != "none" or float(row.get("damage", 0)) > 0.0 or float(row.get("armor_value", 0)) > 0.0

func _out(r: Dictionary) -> String:
	return str(r.get("output", {}).get("id", ""))

## Highest ladder tier the recipe's primary slot accepts (only walked items when `reachable`).
func _primary_tier(r: Dictionary, reachable: bool) -> int:
	var t := -1
	for s: Dictionary in r.get("slots", []):
		if bool(s.get("primary", false)):
			for id: String in _ids_with_cat(str(s.get("category", ""))):
				if not reachable or cost.has(id):
					t = maxi(t, _ladder_tier(id))
	return t

## Ladder tier index of an item from its id and default attributes (stone = 0).
func _ladder_tier(id: String) -> int:
	return PS.TOOL_TIERS.find(PS.material_tier(StringName(id), items.get(id, {}).get("default_attributes", {})))

## Each mined rung needs the pick of the rung right below it, so no rung can be skipped
## (bone is butchered: flint opens with a bone pick; bronze is alloyed: iron opens with a bronze pick).
func _check_pick_chain() -> void:
	for fam in nature:
		var gates: Dictionary = nature[fam].get("min_pick_tier", {})
		for k in gates:
			var t := _ladder_tier(str(k))
			if t >= 1:
				_expect(PS.TOOL_TIERS.find(StringName(str(gates[k]))) == t - 1, "%s %s needs a %s pick, the rung below it (has %s)" % [fam, k, PS.TOOL_TIERS[t - 1], gates[k]])

## Gear takes its material tier from the primary input, so a gear recipe whose primary accepts anything
## above flint needs a requires_node at least as high as the lowest node the ladder's own tier_<t> gear
## recipes carry. Survival or min_level gates do not count: they skip the rung's node (a work pick of steel,
## or a raid cuirass of any ingot, made steel-tier gear with no iron_weapons or scute_armor).
func _check_ungated_gear() -> void:
	var cap: int = PS.TOOL_TIERS.find(&"flint") ## metal_shard and raptor_talon read as flint by hardness
	var rung_gate := {}
	for r: Dictionary in recipes:
		for s: Dictionary in r.get("slots", []):
			var cat := str(s.get("category", ""))
			if bool(s.get("primary", false)) and cat.begins_with("tier_") and _is_gear(_out(r)):
				var t: int = PS.TOOL_TIERS.find(StringName(cat.trim_prefix("tier_")))
				rung_gate[t] = mini(int(rung_gate.get(t, 999)), _node_level(r))
	for r: Dictionary in recipes:
		var t := _primary_tier(r, false)
		if _is_gear(_out(r)) and t > cap:
			_expect(_node_level(r) >= int(rung_gate.get(t, 999)), "recipe %s takes %s-tier material as its primary with skill gate Lv %d, below the ladder's %s gear gate Lv %d" % [r["id"], PS.TOOL_TIERS[t], _node_level(r), PS.TOOL_TIERS[t], int(rung_gate.get(t, 999))])

## Damage or armour at equal level: armour value, or damage per second for a weapon (attack_rate 0
## swings once a second, hunt.gd), times the material tier.
func _power(id: String, tier: int) -> float:
	var row: Dictionary = items[id]
	var base := float(row.get("armor_value", 0.0))
	if base <= 0.0:
		var rate := float(row.get("attack_rate", 0.0))
		base = float(row.get("damage", 0.0)) * (rate if rate > 0.0 else 1.0)
	return base * float(PS.TIER_POWER[maxi(0, tier)])

func _gear_slot(id: String) -> String:
	for slot: String in GEAR_SLOTS:
		if _has_cat(id, slot) and (slot != "weapon" or float(items[id].get("damage", 0)) > 0.0):
			return slot
	return ""

## GAUNTLET "higher-tier gear clearly better": at equal level no reachable recipe output in an armour slot
## or the weapon role beats the steel item of that slot unless its recipe's skill node is at least as high.
func _check_top_rung() -> void:
	var steel: int = PS.TOOL_TIERS.find(&"steel")
	for slot: String in GEAR_SLOTS:
		var top: String = GEAR_SLOTS[slot]
		var top_power := _power(top, steel)
		var top_gate := _gate_level(top)
		for r: Dictionary in recipes:
			var out := _out(r)
			if out == top or _gear_slot(out) != slot or not made.has(str(r["id"])):
				continue
			var t := _primary_tier(r, true)
			var p := _power(out, t)
			if p <= top_power + 0.001:
				continue
			print("[t_data] above %s (%.0f, gate Lv %d): %s %.0f at %s tier, gate %s Lv %d" % [top, top_power, top_gate, r["id"], p, PS.TOOL_TIERS[maxi(0, t)], r.get("requires_node", "none"), _node_level(r)])
			_expect(_node_level(r) >= top_gate, "%s (%.0f at %s tier) beats %s (%.0f at steel) at equal level with skill gate Lv %d < Lv %d" % [r["id"], p, PS.TOOL_TIERS[maxi(0, t)], top, top_power, _node_level(r), top_gate])

func _check_nets() -> void:
	var techniques := {}
	for n in _json("skills/survival.json").get("nodes", []):
		if str(n.get("kind", "")) == "capture_technique":
			techniques[int(n.get("unlocks_capture_tier", 0))] = true
	for tier in range(1, 6):
		var ids := items.keys().filter(func(id: String) -> bool: return int(items[id].get("capture_tier", 0)) == tier)
		_expect(ids.size() == 1 and cost.has(ids[0]), "capture net tier %d exists and is craftable" % tier)
	var n_ok := 0
	for sp in creatures:
		var c: Dictionary = creatures[sp]
		if not bool(c.get("tameable", false)):
			continue
		var need := int(c.get("capture_tier", 1))
		var ok := need <= 0 or (techniques.has(need) and cost.keys().any(func(id: String) -> bool: return int(items[id].get("capture_tier", 0)) >= need))
		_expect(ok, "tameable %s (capture tier %d) has a reachable net and technique" % [sp, need])
		n_ok += 1 if ok else 0
	print("[t_data] tameable species with a reachable net: %d" % n_ok)

## Armour in every 5-10 level band, 1 to 60: per slot the reachable recipe levels start <= 10,
## step at most 10 and reach 50.
func _check_armor() -> void:
	for slot in ["armor_head", "armor_body", "armor_arms", "armor_legs"]:
		var levels := {}
		for r: Dictionary in recipes:
			var out := str(r.get("output", {}).get("id", ""))
			if _has_cat(out, slot) and made.has(str(r["id"])):
				levels[maxi(1, int(r.get("min_level", 1)))] = true
		var ls := levels.keys()
		ls.sort()
		_expect(not ls.is_empty() and int(ls[0]) <= 10 and int(ls[-1]) >= 50, "%s armour spans 10..50+ (%s)" % [slot, ls])
		for i in range(1, ls.size()):
			_expect(int(ls[i]) - int(ls[i - 1]) <= 10, "%s armour gap %d -> %d is at most 10" % [slot, ls[i - 1], ls[i]])
		print("[t_data] %s levels %s" % [slot, ls])

## A recipe that makes more than one unit must not accept its own output (an endless multiplier).
func _check_no_multiplying_loops() -> void:
	for r: Dictionary in recipes:
		var out := str(r.get("output", {}).get("id", ""))
		if int(r.get("output", {}).get("count", 1)) <= 1:
			continue
		for s: Dictionary in r.get("slots", []):
			_expect(not _has_cat(out, str(s.get("category", ""))), "recipe %s output %s feeds its own %s slot" % [r["id"], out, s.get("category", "")])

## A split (one input unit -> several outputs) must not yield more units of a category gear recipes take
## than it consumes: two straps cut from one dried hide filled two armour hide units.
func _check_split_leaks() -> void:
	var gear_cats := {}
	for r: Dictionary in recipes:
		if _is_gear(_out(r)):
			for s: Dictionary in r.get("slots", []):
				gear_cats[str(s.get("category", ""))] = true
	for r: Dictionary in recipes:
		var n := int(r.get("output", {}).get("count", 1))
		for cat: String in gear_cats:
			if n <= 1 or not _has_cat(_out(r), cat):
				continue
			var units := 0
			for s: Dictionary in r.get("slots", []):
				if _ids_with_cat(str(s.get("category", ""))).any(func(id: String) -> bool: return _has_cat(id, cat)):
					units += int(s.get("count", 1))
			_expect(units == 0 or n <= units, "recipe %s turns %d %s unit(s) into %d %s" % [r["id"], units, cat, n, _out(r)])

## W2-BUILDSYS pieces consume material_slots directly (spec 10 construction sites), so they need no
## kit recipe here; every item a piece tier or placed kind spends must be reachable.
func _check_structures() -> void:
	if not FileAccess.file_exists(D + "structures.json"):
		return
	var doc: Dictionary = _json("structures.json")
	var used := {}
	_collect_items(doc.get("piece_tiers", {}), used)
	_collect_items(doc.get("placed_kinds", {}), used)
	for id in used:
		_expect(cost.has(id), "structures.json spends %s, which is reachable" % id)
	print("[t_data] structures.json items reachable: %d" % used.size())

func _collect_items(v: Variant, out: Dictionary) -> void:
	if v is Dictionary:
		for k in v:
			if str(k) == "item":
				out[str(v[k])] = true
			_collect_items(v[k], out)
	elif v is Array:
		for e in v:
			_collect_items(e, out)

## Crafting.preview of `rid` from walked materials at `level` (the highest tier for the primary slot);
## `primary` forces the primary item. null when the recipe refuses the materials.
func _craft(rid: String, level: int, primary: String = "") -> Variant:
	var r: Dictionary = CR.recipe(StringName(rid))
	_expect(not r.is_empty(), "Data.recipes has %s" % rid)
	if r.is_empty():
		return null
	var inv = INV.new(40)
	for s: Dictionary in r.get("slots", []):
		var cat := str(s.get("category", ""))
		var prim := bool(s.get("primary", false))
		var pick := primary if prim else ""
		if pick == "":
			for id in cost:
				if _has_cat(id, cat) and (pick == "" or _tier_of(id) > _tier_of(pick) and prim):
					pick = id
		if pick != "":
			inv.add(IS.make(StringName(pick), int(s.get("count", 1)), {}, level))
	return CR.preview(inv, r, CR.default_picks(inv, r))

## The real crafting planner (Crafting.preview) accepts the walk's materials for every rung tool and
## the forge/anvil chain, and the output carries the rung's material tier.
func _check_planner() -> void:
	var ids: Array = ["smelt_tin", "smelt_copper", "alloy_bronze", "smelt_iron", "refine_steel", "capture_net_v", "steel_cuirass"]
	for tier: String in RUNGS:
		ids.append_array(_rung_tools(tier).map(func(id: String) -> String: return id if tier != "stone" or id != "stone_knife_work" else "improvised_stone_knife"))
	for rid: String in ids:
		var out: Variant = _craft(rid, 60)
		_expect(out != null and str(out.def_id) == str(CR.recipe(StringName(rid)).get("output", {}).get("id", "")), "planner crafts %s from walked materials" % rid)
		if out != null and out.def() != null and out.def().tool_class == &"pick":
			var want := str(rid).get_slice("_", 0) if rid != "work_pick" else ""
			if want in RUNGS:
				_expect(str(out.material_tier()) == want, "%s comes out %s tier (got %s)" % [rid, want, out.material_tier()])

## GAUNTLET through the real planner, every input level 55: each metal tier's cuirass and sword beat the
## tier below, the raid kit (steel plus Survival 50) sits on top and refuses shards or copper, and a level 5
## pick is clearly better than a level 1 pick.
func _check_tier_planner() -> void:
	for row: Array in [["armor_body", ["copper_cuirass", "bronze_cuirass", "iron_cuirass", "steel_cuirass", "raid_cuirass"]], ["weapon", ["copper_sword", "bronze_sword", "iron_sword", "steel_sword", "raid_maul"]]]:
		var parts: Array[String] = []
		var prev := 0.0
		for rid: String in row[1]:
			var out: Variant = _craft(rid, 55)
			var v: float = 0.0 if out == null else (out.scaled_armor() if row[0] == "armor_body" else out.scaled_damage() * maxf(1.0, out.def().attack_rate))
			parts.append("%s %.0f (%s)" % [rid, v, "-" if out == null else str(out.material_tier())])
			_expect(v > prev or rid.begins_with("raid") and v >= prev, "%s at L55 (%.0f) beats the tier below (%.0f)" % [rid, v, prev])
			prev = v
		print("[t_data] L55 %s via planner: %s" % [row[0], ", ".join(parts)])
	for mat: String in ["metal_shard", "copper_ingot"]:
		_expect(_craft("raid_cuirass", 55, mat) == null and _craft("raid_maul", 55, mat) == null, "raid gear refuses %s as its primary" % mat)
	var p1: Variant = _craft("flint_pick", 1)
	var p5: Variant = _craft("flint_pick", 5)
	var s1: Variant = _craft("flint_spear", 1)
	var s5: Variant = _craft("flint_spear", 5)
	if p1 != null and p5 != null and s1 != null and s5 != null:
		var g: float = p5.gather_power() / p1.gather_power()
		var dmg: float = s5.scaled_damage() / s1.scaled_damage()
		print("[t_data] level %d -> %d from the planner: flint_pick gather power x%.2f, flint_spear damage x%.2f" % [p1.level, p5.level, g, dmg])
		_expect(p1.level == 1 and p5.level == 5 and g >= 1.3 and dmg >= 1.3, "a level 5 tool is clearly better than level 1 (gather x%.2f, damage x%.2f)" % [g, dmg])
	else:
		_expect(false, "planner crafts flint_pick and flint_spear at levels 1 and 5")

## Hook 6: Crafting.progression_block names the missing node and opens once it is learned.
func _check_node_gate() -> void:
	var p: Node = (load("res://scripts/player/player.gd") as GDScript).new()
	var sk: Node = (load("res://scripts/skills/skill_state.gd") as GDScript).new()
	sk.call("_load")
	p.set("skills", sk)
	var rec: Dictionary = CR.recipe(&"smelt_copper")
	var locked := str(CR.progression_block(p, rec))
	var node := str(rec.get("requires_node", ""))
	(sk.get("trees")[str(trees_nodes.get(node, ""))]["unlocked"] as Array).append(node)
	var open := str(CR.progression_block(p, rec))
	print("[t_data] smelt_copper gate: before '%s', after learning %s '%s'" % [locked, node, open])
	_expect(locked != "" and open == "", "progression_block refuses smelt_copper until %s is learned (before '%s', after '%s')" % [node, locked, open])
	# The refusal tells the player which tree to raise, not the raw node id.
	var tree := str(trees_nodes.get(node, ""))
	var tname := str(sk.get_script().get_script_constant_map().get("NAMES", {}).get(tree, tree))
	_expect(locked.contains(tname) and locked.contains(str(_node_level(rec))), "smelt_copper's refusal '%s' names its tree %s and level %d" % [locked, tname, _node_level(rec)])
	sk.free()
	p.free()

## bot_survivor (W1-QA, hook 13) gathers by CATEGORY_ITEMS: every slot of a recipe it crafts needs an entry
## (without one _acquire_for gives up before it tries a sub-recipe), and every item listed must fill it.
func _check_bot_map() -> void:
	var consts: Dictionary = (load("res://scripts/dev/bot_survivor.gd") as GDScript).get_script_constant_map()
	var cmap: Dictionary = consts.get("CATEGORY_ITEMS", {})
	var crafts: Array = ["twine", "rope"] ## its _grind list; charcoal and plank are skipped on base already
	for step: Dictionary in consts.get("LADDER", []):
		if step.has("craft"):
			crafts.append(str(step["craft"]))
	for rid: String in crafts:
		for r: Dictionary in recipes:
			if str(r["id"]) != rid:
				continue
			for sl: Dictionary in r.get("slots", []):
				var cat := str(sl.get("category", ""))
				_expect(cmap.has(cat), "bot_survivor maps %s's slot category %s" % [rid, cat])
				for id in cmap.get(cat, []):
					_expect(_has_cat(str(id), cat), "bot_survivor gathers %s for %s, which it does not fill" % [id, cat])
