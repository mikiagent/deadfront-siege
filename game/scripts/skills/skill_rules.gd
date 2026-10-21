class_name SkillRules
extends RefCounted
## Read-only answers from learned skill nodes (trees.json "effects"): which recipe a node gates,
## ability totals (Handicraft, Metal Processing, Slaughter, Stealth), bonded companion capacity.
## SkillState owns the state; this file only reads it, so every consumer asks one place.

## recipe id -> [tree, node] for every node whose effects gate a recipe, and for every loaded recipe
## that names a node in requires_node (W2-DATA's gate), so every skill-gated recipe reads alike (spec 12:197).
static func recipe_gates(sk: SkillState) -> Dictionary:
	return _index(sk)["gates"]

## The lookups every craft row and sheet row asks: trees.json and Data.recipes do not change in play,
## so they are built once per SkillState instead of walking every recipe per row (W2-DATA adds hundreds).
## Learning or refunding a node changes none of them. A changed recipe count (a test injecting one)
## rebuilds them. shortcut: a same-size swap of recipes is not seen; key on a Data revision if one appears.
static func _index(sk: SkillState) -> Dictionary:
	if int(sk._rules_cache.get("recipes", -1)) == Data.recipes.size():
		return sk._rules_cache
	var gates := {}
	var by_id := {}
	for tree in SkillState.ORDER:
		for n in sk.nodes(tree):
			by_id[str(n.get("id", ""))] = [tree, n]
			for e in n.get("effects", []):
				if e is Dictionary and str(e.get("type", "")) == "recipe":
					for rid in e.get("recipes", []):
						gates[str(rid)] = [tree, n]
	for rid in Data.recipes:
		var need := str((Data.recipes[rid] as Dictionary).get("requires_node", ""))
		if need != "" and by_id.has(need) and not gates.has(str(rid)):
			gates[str(rid)] = by_id[need]
	# Buyable: functional or recipe-gating nodes plus the prerequisite chain each needs (see buyable).
	var gating := recipe_nodes()
	var buy := {}
	for tree in SkillState.ORDER:
		var in_tree := {}
		for n in sk.nodes(tree):
			in_tree[str(n.get("id", ""))] = n
		var ids := {}
		for n in sk.nodes(tree):
			# A node is for sale when the game runs its effect: a recipe it gates (its own recipe list or a
			# recipe's requires_node), or an effect type some system reads (ON SALE below; spec 12:215).
			if not has_effect(n) and not str(n.get("id", "")) in gating:
				continue
			var cur: Variant = n
			while cur is Dictionary and not ids.has(str(cur.get("id", ""))):
				ids[str(cur.get("id", ""))] = true
				cur = in_tree.get(str(cur.get("requires", "")))
		buy[tree] = ids
	sk._rules_cache = {"recipes": Data.recipes.size(), "gates": gates, "buyable": buy}
	return sk._rules_cache

## "" when the recipe is not gated or its node is learned, else what to learn
## ("learn Charcoal (Processing Lv. 10, 1 SP)"), so the craft card can show it locked.
static func recipe_block(sk: SkillState, recipe_id: String) -> String:
	var gate: Variant = recipe_gates(sk).get(recipe_id)
	if gate == null:
		return ""
	var tree: String = gate[0]
	var n: Dictionary = gate[1]
	if sk.is_unlocked(tree, str(n.get("id", ""))):
		return ""
	var cost := int(n.get("sp", 0))
	var msg := "learn %s (%s %s, %d SP)" % [str(n.get("name", n.get("id", ""))), SkillState.NAMES.get(tree, tree), LevelDisplay.label(int(n.get("level", 1))), cost]
	# A Lv. 1 survivor has 0 SP (spec 03: SP come from character levels), so say where the SP come from.
	var lv: int = sk.character_level()
	if sk.sp_available < cost and lv < SkillState.MAX_LEVEL:
		msg += "; you have %d SP, reach %s for +%d SP" % [sk.sp_available, LevelDisplay.label(lv + 1), sk.sp_for_level(lv + 1)]
	return msg

## Sum of {"type": "ability", "ability": name, "amount": n} over learned nodes.
static func ability(sk: SkillState, name: String) -> int:
	var total := 0
	for tree in SkillState.ORDER:
		for n in sk.nodes(tree):
			if not sk.is_unlocked(tree, str(n.get("id", ""))):
				continue
			for e in n.get("effects", []):
				if e is Dictionary and str(e.get("type", "")) == "ability" and str(e.get("ability", "")) == name:
					total += int(e.get("amount", 0))
	return total

## Spec 09: 3 bonded companions + 1 per learned Animal Handling node (I-IV), at most 7. A new bond
## needs bonded count < this; existing bonds are kept. Every client bond path asks Data.bonded_cap()
## (hook H2), which reads this for the local player.
static func bonded_capacity(sk: SkillState) -> int:
	var cap := int(sk.config.get("bonded_base", 3))
	for n in sk.nodes("survival"):
		if sk.is_unlocked("survival", str(n.get("id", ""))):
			for e in n.get("effects", []):
				if e is Dictionary and str(e.get("type", "")) == "bonded_slots":
					cap += int(e.get("amount", 0))
	return mini(cap, int(sk.config.get("bonded_max", 7)))

## SP a character at `level` has earned (spec 03): sp_budget for levels 2..level; Lv. 1 pays nothing.
static func paid_for_level(sk: SkillState, level: int) -> int:
	var total := 0
	for l in range(SkillState.MIN_LEVEL + 1, level + 1):
		total += sk.sp_for_level(l)
	return total

## Effect types a system reads today (skill_rules' own readers below and the hooks that call them):
## "recipe" (no recipe list -> the recipe's requires_node names the node), "ability" (SkillRules.ability ->
## Defense's Max Health into Player/PlayerActions), "bonded_slots" (Data.bonded_cap), "capture_tier"
## (SkillState's Data mirror -> Data.has_capture_technique), "climate" (Player.climate_resistance).
## A node with any other effect, or none, stays "not in the game yet".
const READ_EFFECTS := ["recipe", "bonded_slots", "capture_tier", "climate", "gather", "butcher"]
## Abilities a system adds up today: Max Health and Max Energy go into Vitals (Player.refresh_equipment_vitals).
## Handicraft, Metal Processing, Slaughter and Stealth are read by SkillRules.ability only, so their nodes
## stay "not in the game yet" until W2-PROCESS/W2-BUTCHER/W3-SRVACT use them.
const READ_ABILITIES := ["max_health", "max_energy"]

## True when some system reads this node's effect (an empty "recipe" entry reads a recipe's requires_node).
static func has_effect(n: Dictionary) -> bool:
	for e in n.get("effects", []):
		if not e is Dictionary:
			continue
		var kind := str(e.get("type", ""))
		if READ_EFFECTS.has(kind) or (kind == "ability" and READ_ABILITIES.has(str(e.get("ability", "")))):
			return true
	return false

## Spec 12:215 "do not implement a decorative but inert" tree: SP buy only what the game enforces
## (status functional, or named by a recipe's requires_node) and the prerequisite chain such a
## node needs; the rest show locked.
static func buyable(sk: SkillState, tree: String, node_id: String) -> bool:
	return ((_index(sk)["buyable"] as Dictionary).get(tree, {}) as Dictionary).has(node_id)

## The gathering node that opens the gather item `item`, as [tree, node] ([] when no node gates it).
## An effect with an empty item list marks its node, not a material (Thickets: cutting thickets with a knife).
static func gather_gate(sk: SkillState, item: String) -> Array:
	return _item_gate(sk, "gathering", "gather", item)

## The butchering node that opens the drop `item`, as [tree, node].
static func butcher_gate(sk: SkillState, item: String) -> Array:
	return _item_gate(sk, "butchering", "butcher", item)

static func _item_gate(sk: SkillState, tree: String, kind: String, item: String) -> Array:
	for n in sk.nodes(tree):
		for e in n.get("effects", []):
			if e is Dictionary and str(e.get("type", "")) == kind and (e.get("items", []) as Array).has(item):
				return [tree, n]
	return []

## "" when the gather item is open (no node gates it, or its node is learned), else why it is locked
## ("Needs Mining 1 (Gathering Lv. 10, 8 SP)"). harvest_node.can_gather puts it on screen.
static func gather_block(sk: SkillState, item: String) -> String:
	if sk == null:
		return ""
	var gate := gather_gate(sk, item)
	if gate.is_empty() or sk.is_unlocked(gate[0], str((gate[1] as Dictionary).get("id", ""))):
		return ""
	return "Needs %s" % _learn_text(sk, gate)

## "" when the butcher drop may roll in, else why not (corpse._roll_loot skips the row).
static func butcher_block(sk: SkillState, item: String) -> String:
	if sk == null:
		return ""
	var gate := butcher_gate(sk, item)
	if gate.is_empty() or sk.is_unlocked(gate[0], str((gate[1] as Dictionary).get("id", ""))):
		return ""
	return "Needs %s" % _learn_text(sk, gate)

## "Mining 1 (Gathering Lv. 10, 8 SP)" for a [tree, node] gate.
static func _learn_text(sk: SkillState, gate: Array) -> String:
	var tree: String = gate[0]
	var n: Dictionary = gate[1]
	return "%s (%s %s, %d SP)" % [str(n.get("name", n.get("id", ""))), SkillState.NAMES.get(tree, tree), LevelDisplay.label(int(n.get("level", 1))), int(n.get("sp", 0))]

## Node ids that a loaded recipe names in requires_node (W2-DATA's crafting gate). Learning one
## opens a recipe, so it is not inert whatever its trees.json status says.
static func recipe_nodes() -> Dictionary:
	var out := {}
	for rec in Data.recipes.values():
		var node := str((rec as Dictionary).get("requires_node", ""))
		if node != "":
			out[node] = true
	return out

## Node ids in `tree` that list `node_id` as their prerequisite and are learned.
static func learned_dependents(sk: SkillState, tree: String, node_id: String) -> Array:
	var out: Array = []
	for n in sk.nodes(tree):
		if str(n.get("requires", "")) == node_id and sk.is_unlocked(tree, str(n.get("id", ""))):
			out.append(str(n.get("id", "")))
	return out
