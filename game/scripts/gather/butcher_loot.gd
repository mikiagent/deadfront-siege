class_name ButcherLoot
extends RefCounted
## Fills a fresh carcass from butchering.json: counts scale with the hunter's best knife tier
## and Butchering level, premium parts need a good enough knife (loot_tables.json part_min_tier),
## and "rare" rows roll their odds instead of always dropping. Rare parts are announced when the
## animal falls and pay their XP to whoever takes them.
## Corpse._roll_loot calls roll_into, Corpse._on_take_from_loot calls on_take (integrator hooks).

static var rng: RandomNumberGenerator = _new_rng()
## Corpse meta: the rare parts still on the carcass whose take XP is unpaid.
const RARE_META := &"w2_rare_parts"

static func _new_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r

# ASSUMPTION: the local survivor is the butcher, rolled when the animal falls (single player;
# the server rolls for the credited killer in W3). A knife picked up later does not re-roll.
static func roll_into(corpse: Corpse, body: Node3D = null) -> Array[StringName]:
	var p := PlayerRegistry.local()
	var knife: ItemStack = p.inventory.find_gather_tool(&"knife") if p else null
	var skill := maxi(0, p.skills.level_of("butchering")) if p and p.skills else 0
	var table: Dictionary = Data.butcher_tables.get(str(corpse.species), {})
	var res := LootRoller.roll_carcass(table.get("base", []), table.get("rare", []), corpse.level,
			knife.material_tier() if knife else &"", Data.butchering_level(), skill, corpse.poison_spoiled, rng)
	for st in res["stacks"]:
		corpse.loot.add(st)
	var rares: Array[StringName] = []
	for id in res["rares"]:
		rares.append(id)
	corpse.set_meta(RARE_META, rares.duplicate())
	if p and not rares.is_empty():
		var at := (body.global_position if body and body.is_inside_tree() else p.global_position) + Vector3(0, 1.4, 0)
		GatherFeedback.announce_rares(p, at, rares, " on the %s" % corpse.species_display_name().to_lower())
	return rares

## After a take from the carcass: each rare part pays its butchering XP once, to the taker, when
## the last of it has left the carcass (not when the animal fell).
static func on_take(corpse: Corpse, taker: Player) -> void:
	var unpaid: Array = corpse.get_meta(RARE_META, [])
	var left: Array[StringName] = []
	var xp := float(LootTables.rules().get("xp", {}).get("rare_butcher_bonus", 0))
	for id in unpaid:
		if corpse.loot.count_of(id) > 0:
			left.append(id)
			continue
		GatherXp.award(taker, "butchering", xp, {"verb": "butcher", "item": str(id), "rare": true, "node_level": corpse.level})
	corpse.set_meta(RARE_META, left)
