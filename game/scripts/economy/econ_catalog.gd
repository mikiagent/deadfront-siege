class_name EconCatalog
extends RefCounted
## Read-only view of the game catalogs the economy validates against. Built once from Data,
## so the engine never reaches into autoloads mid-op and replay sees the same tables.

var items: Dictionary = {} ## def_id String -> ItemDef
var creatures: Dictionary = {} ## species String -> CreatureDef
var objective_rewards: Array[int] = [] ## objective index -> T-stones
var spend_costs: Dictionary = {} ## wallet.spend reason -> Array of legal amounts
var market: Dictionary = {} ## data/world/market.json (Settlers demand)

static func from_data() -> EconCatalog:
	var c := EconCatalog.new()
	for id in Data.items:
		c.items[str(id)] = Data.items[id]
	for id in Data.creatures:
		c.creatures[str(id)] = Data.creatures[id]
	for step in Data.world_objectives:
		c.objective_rewards.append(int((step as Dictionary).get("t_stones", 0)) if step is Dictionary else 0)
	c.spend_costs = {
		"travel": _sail_costs(),
		"cargo_warp": [World.CARGO_FEE],
		# ASSUMPTION: the only T-stone priced claim in v1 is opening a crater (rules.json).
		"claim": [int(Data.world_rules.get("craters", {}).get("open_cost_tstones", 50))],
	}
	c.market = Ledger.norm(EconRules.read_json("res://data/world/market.json"))
	return c

func item(def_id: String) -> ItemDef:
	return items.get(def_id) as ItemDef

func creature(species: String) -> CreatureDef:
	return creatures.get(species) as CreatureDef

## Every distinct non-zero sail cost, the way World merges islands.json with data/islands.
static func _sail_costs() -> Array:
	var islands: Dictionary = {}
	for id in Data.world_islands:
		if Data.world_islands[id] is Dictionary:
			islands[str(id)] = (Data.world_islands[id] as Dictionary).duplicate()
	var da := DirAccess.open("res://data/islands")
	if da:
		for fname in da.get_files():
			if fname.ends_with(".json"):
				var row := EconRules.read_json("res://data/islands/%s" % fname)
				var id := str(row.get("id", fname.get_basename()))
				var base: Dictionary = islands.get(id, {})
				base.merge(row, true)
				islands[id] = base
	var costs: Array = []
	for id in islands:
		var cost := int((islands[id] as Dictionary).get("sail_cost", 5)) # World's default
		if cost > 0 and cost not in costs:
			costs.append(cost)
	costs.sort()
	return costs
