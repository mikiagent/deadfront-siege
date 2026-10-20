extends SceneTree
## W2-DATA: item and recipe data validator plus a progression walk.
## 1. Every id that recipes, factions, rules, statuses, climates, nature, butchering and farming
##    name exists; every item has market_category and rarity (and item_rarity.json mirrors it).
## 2. A walk from a fresh survivor (bare hands) over the real sources only: gathering (climate
##    vegetation x nature_manifest yields, with the same tool and pick-tier gates as HarvestNode),
##    butchering, farming, the capture/taming systems and recipes (stations need their kit, min_level
##    needs reachable material levels). Faction crates are never a source. Any item or recipe it cannot
##    reach fails, except items that name the system they wait on in "source_pending".
## 3. Ladder, nets, armour bands and the real crafting planner agree with the walk.
## Item scripts reference the Data autoload, so they load on the first frame after it exists.

const D := "res://data/"
const RUNGS := ["stone", "flint", "obsidian", "copper", "bronze", "iron", "steel"]
## Special families IslandScatter._scatter_special_tiles plants on every island.
const SPECIAL_FAMILIES := ["mud", "clay", "berry_bush", "tree_stump"]
## cleared_by entries in statuses.json that are actions or places, not items.
const STATUS_ACTIONS := ["cauterise", "residence", "struggle", "pet_aggro", "syringe"]
## Seconds a capture or a taming takes, for the time log only (# ASSUMPTION).
const CAPTURE_SECONDS := 60.0
const TAME_SECONDS := 120.0
const BUTCHER_SECONDS := 1.6 ## corpse.gd: one radial hex per loot stack, 1.6 s each

var fails: Array[String] = []
var _done := false
var items: Dictionary = {}     # id -> row
var recipes: Array = []        # non-staged rows
var all_recipes: Array = []
var nature: Dictionary = {}
var climates: Dictionary = {}
var trees_nodes: Dictionary = {} # node id -> tree id
var creatures: Dictionary = {}  # species -> row
var PS: GDScript
var opt_tools: Dictionary = {}
var opt_seconds: Dictionary = {}
# walk state
var cost: Dictionary = {}  # id -> seconds per unit from bare hands
var lvl: Dictionary = {}   # id -> highest reachable item level
var how: Dictionary = {}   # id -> first source found
var made: Dictionary = {}  # recipe id -> true
var pick_tier := -1        # best reachable pick tier index

func _process(_delta: float) -> bool:
	if _done:
		return true
	if get_root() == null or get_root().get_node_or_null("Data") == null:
		return false
	_done = true
	PS = load("res://scripts/items/progression_scaling.gd")
	var hn: Dictionary = (load("res://scripts/world/harvest_node.gd") as GDScript).get_script_constant_map()
	opt_tools = hn.get("OPTION_TOOLS", {})
	opt_seconds = hn.get("OPTION_SECONDS", {})
	_load_all()
	_check_items()
	_check_references()
	_walk()
	_check_reachability()
	_check_ladder()
	_check_nets()
	_check_armor()
	_check_no_multiplying_loops()
	_check_structures()
	_check_planner()
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
	var trees: Dictionary = _json("skills/trees.json").get("trees", {})
	for t in trees:
		for n in trees[t].get("nodes", []):
			_expect(not trees_nodes.has(n["id"]), "skill node id %s is unique across trees" % n["id"])
			trees_nodes[str(n["id"])] = t
	for f in DirAccess.get_files_at(D + "creatures"):
		var row: Variant = _json("creatures/" + f) if f.ends_with(".json") else null
		if row is Dictionary and (row as Dictionary).has("capture_tier"):
			creatures[f.get_basename()] = row

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
	for fk in _json("world/factions.json"):
		var f: Variant = _json("world/factions.json")[fk]
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

func _walk() -> void:
	var butch: Dictionary = _json("butchering.json").get("species", {})
	var crops: Dictionary = _json("farming.json").get("crops", {})
	for _pass in 60:
		var changed := false
		# Gathering: what each climate's vegetation (plus the special tiles) yields, tool-gated.
		for cname in climates:
			var top := 1
			for t in climates[cname].get("tiers", [1]):
				top = maxi(top, int(t))
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
		# Butchering a kill needs a knife; the corpse level follows the species tier.
		if _has_tool("knife"):
			for sp in butch:
				var tier := int(creatures.get(sp, {}).get("tier", 1))
				for row in butch[sp].get("base", []) + butch[sp].get("rare", []):
					var per := maxf(0.5, (float(row.get("min", 1)) + float(row.get("max", row.get("min", 1)))) * 0.5)
					changed = _offer(str(row["id"]), BUTCHER_SECONDS / per, tier, "butcher %s" % sp) or changed
		# Farming: a seed in a field; output level is capped by the Farming skill (60).
		if cost.has("field_small_kit"):
			for c in crops:
				var seed := str(crops[c].get("seed", ""))
				if cost.has(seed):
					var y := maxf(1.0, float(crops[c].get("base_yield", 1)))
					changed = _offer(str(crops[c]["output"]), (float(crops[c].get("growth_seconds", 120)) + float(cost[seed])) / y, 60, "farm %s" % c) or changed
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
	for fk in _json("world/factions.json"):
		var f: Variant = _json("world/factions.json")[fk]
		if f is Dictionary:
			var bands: Dictionary = (f as Dictionary).get("crate_bands", {})
			for b in bands:
				for id in bands[b]:
					_expect(cost.has(str(id)), "crate item %s (%s %s) also has a gameplay source" % [id, fk, b])
	print("[t_data] reachable=%d/%d pending=%s best_pick=%s" % [cost.size(), items.size(), pending, PS.TOOL_TIERS[maxi(0, pick_tier)]])

## Staged designs (implementation_status) stay in recipes.json but Data does not load them.
func _staged_output(id: String) -> bool:
	return all_recipes.any(func(r: Dictionary) -> bool: return str(r.get("implementation_status", "")) == "staged" and str(r.get("output", {}).get("id", "")) == id)

# ---- 3. ladder, nets, armour, loops, planner -------------------------------------------------

func _rung_tools(tier: String) -> Array:
	if tier == "stone":
		return ["stone_knife_work", "work_axe", "work_pick", "stone_knife"]
	var wpn := "spear" if tier in ["flint", "obsidian"] else "sword"
	return ["%s_knife" % tier, "%s_axe" % tier, "%s_pick" % tier, "%s_%s" % [tier, wpn]]

func _check_ladder() -> void:
	for tier: String in RUNGS:
		var worst := 0.0
		for id: String in _rung_tools(tier):
			_expect(cost.has(id), "rung %s tool %s is reachable" % [tier, id])
			if tier != "stone":
				_expect(str(PS.material_tier(StringName(id), {})) == tier, "%s reads as tier %s" % [id, tier])
			worst = maxf(worst, float(cost.get(id, 0.0)))
		print("[t_data] rung %-8s %s  ~%d s of gathering+crafting per tool (stations excluded)" % [tier, ", ".join(_rung_tools(tier)), int(worst)])
	_expect(pick_tier == PS.TOOL_TIERS.find(&"steel"), "a steel pick is reachable (best %d)" % pick_tier)
	for id in ["tin_ore", "tin_ingot", "copper_ingot", "bronze_ingot", "iron_ingot", "steel_ingot", "forge_kit", "anvil_kit", "steamer_kit", "hoe"]:
		_expect(cost.has(id), "%s is reachable" % id)

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

## The real crafting planner (Crafting.preview) accepts the walk's materials for every rung tool and
## the forge/anvil chain, and the output carries the rung's material tier.
func _check_planner() -> void:
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	var INV: GDScript = load("res://scripts/items/inventory.gd")
	var CR: GDScript = load("res://scripts/items/crafting.gd")
	var ids: Array = ["smelt_tin", "smelt_copper", "alloy_bronze", "smelt_iron", "refine_steel", "capture_net_v", "steel_cuirass"]
	for tier: String in RUNGS:
		ids.append_array(_rung_tools(tier).map(func(id: String) -> String: return id if tier != "stone" or id != "stone_knife_work" else "improvised_stone_knife"))
	for rid: String in ids:
		var r: Dictionary = CR.recipe(StringName(rid))
		_expect(not r.is_empty(), "Data.recipes has %s" % rid)
		if r.is_empty():
			continue
		var inv = INV.new(40)
		for s: Dictionary in r.get("slots", []):
			var cat := str(s.get("category", ""))
			var pick := ""
			for id in cost:
				if _has_cat(id, cat) and (pick == "" or _tier_of(id) > _tier_of(pick) and bool(s.get("primary", false))):
					pick = id
			if pick != "":
				inv.add(IS.make(StringName(pick), int(s.get("count", 1)), {}, 60))
		var out = CR.preview(inv, r, CR.default_picks(inv, r))
		_expect(out != null and str(out.def_id) == str(r["output"]["id"]), "planner crafts %s from walked materials" % rid)
		if out != null and out.def() != null and out.def().tool_class == &"pick":
			var want := str(rid).get_slice("_", 0) if rid != "work_pick" else ""
			if want in RUNGS:
				_expect(str(out.material_tier()) == want, "%s comes out %s tier (got %s)" % [rid, want, out.material_tier()])
