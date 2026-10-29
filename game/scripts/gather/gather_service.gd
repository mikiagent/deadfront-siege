class_name GatherService
extends RefCounted
## Gather glue between PlayerActions and the world node: which tool works a node (the role's
## tool helps even on hand-pickable nodes, bare hands are slower), seconds per unit, and what happens
## after a unit lands (tool wear, green rare traits, finds, yield popup). Rare results pay no bonus XP:
## PlayerActions' base +2 Gathering is the whole award (W2-SKILLS paces XP).
## ONEGATHER (owner 2026-10-28): every pass gives exactly ONE instance. A better tool or Gathering level
## makes a pass faster (unit_seconds) and a better tool tier raises each unit's rare-trait odds
## (quality, loot_tables.json rare_trait.tool_tier_bonus); nothing raises the count.
## PlayerActions calls unit_seconds / after_unit (integrator hook).

## Rolls for rare finds. Labs and tests seed it; the server will inject its own (W3-SRVACT).
static var rng: RandomNumberGenerator = _new_rng()

static func _new_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r

static func role_of_family(family: String) -> String:
	return str(Data.nature_families.get(family, {}).get("role", ""))

## The tool that works this node from the bag, or null for bare hands: the node's required
## class, the best pick on rock, else the role's affinity tool (axe on trees, knife on bushes).
static func effective_tool(inv: Inventory, node: HarvestNode) -> ItemStack:
	return tool_for(inv, node.required_tool_class, node.family)

## effective_tool from a node's required tool class and family (the server only has those).
static func tool_for(inv: Inventory, need: StringName, family: String) -> ItemStack:
	var role := role_of_family(family)
	if role == "rock":
		return HarvestNode.best_pick(inv)  # every rock is worked by the best pick (HarvestNode.can_gather)
	if need != &"" and need != &"none":
		return inv.find_gather_tool(need)
	var aff := LootTables.affinity_tool(role)
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

## The material tier of the tool that works this node, &"" for bare hands (the quality roll's input).
static func tool_tier(inv: Inventory, need: StringName, family: String) -> StringName:
	var tool := tool_for(inv, need, family)
	return tool.material_tier() if tool else &""

## After a gathered unit reached the bag (`landed` is the stack PlayerActions added, `gained` of it
## landed, `had` the bag's Inventory.uids() before that add): the helper tool wears, each item rolls
## the green rare trait, the pass rolls its finds, and "+n Item" (with any trait or find) rises over the node.
## Returns the find item ids that landed in the bag.
static func after_unit(p: Player, node: HarvestNode, landed: ItemStack, gained: int, had: Dictionary) -> Array[StringName]:
	var at := node.global_position + Vector3(0.0, node.top_of_node() + 0.3, 0.0)  # the gather ring's anchor
	# Same downrank as the main yield (rules.json gathering_downrank, floor 5).
	var level := mini(int(node.yield_attributes.get("level", 1)), maxi(_skill(p), 5))
	# The node's island climate picks the rows and is stamped on the find (world-design.md:55: always climate and level).
	var climate := str(node.yield_attributes.get("climate", ""))
	Tasks.note(&"gather", gained)  # TASKSCREEN: daily / weekly gather counts
	if landed.level >= 60 and role_of_family(node.family) == "rock":
		Tasks.note(&"mineral60", gained)  # achievement Gather Level-60 Minerals (DW-T0137)
	wear_role_tool(p.inventory, node.required_tool_class, node.family)
	var traits := stamp_traits(p.inventory, had, landed, gained, rng, tool_tier(p.inventory, node.required_tool_class, node.family))
	var finds := add_finds(p.inventory, node.family, node.required_tool_class, climate, level, _skill(p), rng)
	for id in finds:
		p.toast(id, 1)
	GatherFeedback.show_yield(p, at, landed.def_id, gained, finds, traits)
	return finds

## A helper tool wears like a required one (spec 12:44 "Tool wear ... integrate directly"): a knife on a
## bush, a pick on loose stone. A node that requires its tool already wore it in PlayerActions.
static func wear_role_tool(inv: Inventory, need: StringName, family: String) -> void:
	if need != &"" and need != &"none":
		return
	var tool := tool_for(inv, need, family)
	if tool:
		inv.wear_tool(tool)

## Each of the `gained` items that just landed rolls the green rare trait (world-design.md:55, PRD:541).
## Every gathered item is its own instance (W2-INV), so a hit marks the unit that landed, in place: the
## landed units are the `landed.def_id` instances whose uid is not in `had` (the bag's Inventory.uids()
## before the add), never one the bag already held. Client and server (act.gather) share it.
## `tier` is the working tool's material tier (&"" bare hands): ONEGATHER's quality lever.
## Returns the traits stamped.
static func stamp_traits(inv: Inventory, had: Dictionary, landed: ItemStack, gained: int, r: RandomNumberGenerator, tier: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	# shortcut: a stacking-category item (inventory.json) has no uid to find, so it rolls no trait; no nature node yields one today.
	var fresh := inv.slots.filter(func(s: ItemStack) -> bool: return s != null and s.def_id == landed.def_id and s.uid != "" and not had.has(s.uid))
	for s: ItemStack in fresh.slice(0, gained):
		# The roll comes from that material's own list (RAREATTR), not one pool for everything.
		var t := LootRoller.roll_trait(r, s.def_id, tier)
		if t != &"":
			s.attributes[str(t)] = true
			out.append(t)
	if not out.is_empty():
		inv.changed.emit()
	return out

## Rolls one unit's rare finds on a node (family, required tool class, island climate) and adds each
## to `inv`. Client and server (act.gather) share it. Returns the ids that landed.
static func add_finds(inv: Inventory, family: String, need: StringName, climate: String, level: int, skill: int, r: RandomNumberGenerator) -> Array[StringName]:
	var tool := tool_for(inv, need, family)
	var tier: StringName = tool.material_tier() if tool else &""
	var landed: Array[StringName] = []
	for id in LootRoller.roll_gather_rares(family, role_of_family(family), climate, tier, skill, r):
		# A find only rolls into a free slot: never mint an item the bag would drop (sec-loss-08).
		if Data.item(id) == null or inv.used_slots() >= inv.slot_count:
			continue
		if inv.add(ItemStack.make(id, 1, {"climate": climate, "level": level}, level)) > 0:
			continue
		landed.append(id)
	return landed
