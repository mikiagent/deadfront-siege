class_name SkillRules
extends RefCounted
## Read-only answers from learned skill nodes (trees.json "effects"): which recipe a node gates,
## ability totals (Handicraft, Metal Processing, Slaughter, Stealth), bonded companion capacity.
## SkillState owns the state; this file only reads it, so every consumer asks one place.

## recipe id -> [tree, node] for every node whose effects gate a recipe.
static func recipe_gates(sk: SkillState) -> Dictionary:
	var out := {}
	for tree in SkillState.ORDER:
		for n in sk.nodes(tree):
			for e in n.get("effects", []):
				if e is Dictionary and str(e.get("type", "")) == "recipe":
					for rid in e.get("recipes", []):
						out[str(rid)] = [tree, n]
	return out

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

## Spec 09: 3 bonded companions + 1 per learned Animal Handling node (I-IV), at most 7.
## Data.bonded_cap() (hook H2) is the one cap every bond path asks; it reads this for the local player.
static func bonded_capacity(sk: SkillState) -> int:
	var cap := int(sk.config.get("bonded_base", 3))
	for n in sk.nodes("survival"):
		if sk.is_unlocked("survival", str(n.get("id", ""))):
			for e in n.get("effects", []):
				if e is Dictionary and str(e.get("type", "")) == "bonded_slots":
					cap += int(e.get("amount", 0))
	return mini(cap, int(sk.config.get("bonded_max", 7)))

## Spec 09 reset rule: existing bonds are kept, a new bond needs count < capacity.
static func can_bond(sk: SkillState, bonded_count: int) -> bool:
	return bonded_count < bonded_capacity(sk)

## SP a character at `level` has earned (spec 03): sp_budget for levels 2..level; Lv. 1 pays nothing.
static func paid_for_level(sk: SkillState, level: int) -> int:
	var total := 0
	for l in range(SkillState.MIN_LEVEL + 1, level + 1):
		total += sk.sp_for_level(l)
	return total

## Spec 12:215 "do not implement a decorative but inert" tree: SP buy only what the game enforces
## (status functional) and the prerequisite chain a functional node needs; the rest show locked.
static func buyable(sk: SkillState, tree: String, node_id: String) -> bool:
	var by_id := {}
	for n in sk.nodes(tree):
		by_id[str(n.get("id", ""))] = n
	for n in sk.nodes(tree):
		if str(n.get("status", "functional")) != "functional":
			continue
		var cur: Variant = n
		while cur is Dictionary:
			if str(cur.get("id", "")) == node_id:
				return true
			cur = by_id.get(str(cur.get("requires", "")))
	return false

## Node ids in `tree` that list `node_id` as their prerequisite and are learned.
static func learned_dependents(sk: SkillState, tree: String, node_id: String) -> Array:
	var out: Array = []
	for n in sk.nodes(tree):
		if str(n.get("requires", "")) == node_id and sk.is_unlocked(tree, str(n.get("id", ""))):
			out.append(str(n.get("id", "")))
	return out
