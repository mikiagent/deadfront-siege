class_name GatherService
extends RefCounted
## Gather glue between PlayerActions and the world node: which tool works a node (the role's
## tool helps even on hand-pickable nodes, bare hands are slower), seconds and yield per unit,
## and what happens after a unit lands (yield popup, rare roll, rare XP).
## PlayerActions calls unit_seconds / yield_multiplier / after_unit (integrator hook).

## Rolls for rare finds. Labs and tests seed it; the server will inject its own (W3-SRVACT).
static var rng: RandomNumberGenerator = _new_rng()

static func _new_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r

static func role_of(node: HarvestNode) -> String:
	return str(Data.nature_families.get(node.family, {}).get("role", ""))

## The tool that works this node from the bag, or null for bare hands: the node's required
## class, the best pick on rock, else the role's affinity tool (axe on trees, knife on bushes).
static func effective_tool(inv: Inventory, node: HarvestNode) -> ItemStack:
	var need := node.required_tool_class
	if need != &"" and need != &"none":
		return inv.find_gather_tool(need)
	if role_of(node) == "rock":
		return HarvestNode.best_pick(inv)
	var aff := LootTables.affinity_tool(role_of(node))
	return inv.find_gather_tool(aff) if aff != &"" else null

static func _skill(p: Player) -> int:
	return maxi(1, p.skills.level_of("gathering")) if p and p.skills else 1

## Seconds per unit for this player on this node (what the work ring waits).
static func unit_seconds(p: Player, node: HarvestNode) -> float:
	return unit_seconds_for(p.inventory, node, _skill(p))

static func unit_seconds_for(inv: Inventory, node: HarvestNode, skill: int) -> float:
	var tool := effective_tool(inv, node)
	# _base_seconds: can_gather() pre-divides gather_seconds by a held pick; start from the raw value.
	var base := node._base_seconds
	if tool == null:
		base *= float(LootTables.rules().get("bare_hands_seconds_mult", 1.0))
	var zone := int(node.yield_attributes.get("level", 1))
	return ProgressionScaling.gather_seconds(base, zone, tool.level if tool else 1, tool.material_tier() if tool else &"stone", maxi(1, skill))

## Units per pass multiplier (fraction = chance of one extra unit).
static func yield_multiplier(p: Player, node: HarvestNode) -> float:
	return yield_multiplier_for(p.inventory, node, _skill(p))

static func yield_multiplier_for(inv: Inventory, node: HarvestNode, skill: int) -> float:
	var tool := effective_tool(inv, node)
	var zone := int(node.yield_attributes.get("level", 1))
	return ProgressionScaling.gather_yield_multiplier(zone, tool.level if tool else 1, tool.material_tier() if tool else &"stone", maxi(1, skill))

## After a gathered unit reached the bag: the rare roll, then "+n Item" (and any find) over the node.
## Returns the rare item ids that landed in the bag.
static func after_unit(p: Player, node: HarvestNode, item_id: StringName, gained: int, luck: float = 1.0) -> Array[StringName]:
	var at := node.global_position + Vector3(0.0, node.top_of_node() + 0.3, 0.0)  # the gather ring's anchor
	var tool := effective_tool(p.inventory, node)
	var tier: StringName = tool.material_tier() if tool else &""
	var landed: Array[StringName] = []
	# Same downrank as the main yield (rules.json gathering_downrank, floor 5).
	var level := mini(int(node.yield_attributes.get("level", 1)), maxi(_skill(p), 5))
	for id in LootRoller.roll_gather_rares(node.family, role_of(node), str(node.yield_attributes.get("climate", "")), tier, _skill(p), rng, luck):
		# A find only rolls into a free slot: never mint an item the bag would drop (sec-loss-08).
		if Data.item(id) == null or p.inventory.used_slots() >= p.inventory.slot_count:
			continue
		var attrs := {"level": level}
		var left := p.inventory.add(ItemStack.make(id, 1, attrs, level))
		if left > 0:
			continue
		landed.append(id)
		p.toast(id, 1)
		var xp := float(LootTables.rules().get("xp", {}).get("rare_gather_bonus", 0))
		GatherXp.award(p, "gathering", xp, {"verb": "gather", "item": str(id), "rare": true, "node_level": level})
	GatherFeedback.show_yield(p, at, item_id, gained, landed)
	return landed
