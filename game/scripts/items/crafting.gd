class_name Crafting
extends RefCounted
## Flexible recipes: category slots, primary-slot attribute inheritance (PRD §9.1).

const STATION_RANGE := 2.0

static func recipe(id: StringName) -> Dictionary:
	return Data.recipes.get(id, {}) as Dictionary

static func all_recipes() -> Array:
	return Data.recipe_list

static func stacks_for_slot(inv: Inventory, slot: Dictionary) -> Array[int]:
	return inv.find_by_category(StringName(str(slot.get("category", ""))))

## Each recipe slot has a lead stack (for the primary item's attributes) and may draw
## its remaining units from other stacks. A plan row records exact bag indices/counts.
## Prefer dedicated materials over dual-category ones, so fibre stalk is spent before
## bark that might still be needed as lashing. Leads take the largest matching stack.
static func _plan(inv: Inventory, rec: Dictionary, picks: Array[int] = []) -> Array[Dictionary]:
	var slots: Array = rec.get("slots", [])
	if inv == null or slots.is_empty() or (not picks.is_empty() and picks.size() != slots.size()):
		return []
	var remaining: Dictionary = {}
	var plan: Array[Dictionary] = []
	var prefer := StringName(str(rec.get("input_id", "")))
	for i in slots.size():
		if not slots[i] is Dictionary:
			return []
		var slot: Dictionary = slots[i]
		var cat := StringName(str(slot.get("category", "")))
		var need := int(slot.get("count", 1))
		if need <= 0:
			return []
		var preferred := StringName(str(slot.get("prefer_id", prefer if i == 0 else "")))
		var candidates := inv.find_by_category(cat)
		candidates.sort_custom(func(a: int, b: int) -> bool:
			var sa := inv.slots[a]
			var sb := inv.slots[b]
			var pa := 1 if preferred != &"" and sa.def_id == preferred else 0
			var pb := 1 if preferred != &"" and sb.def_id == preferred else 0
			if pa != pb:
				return pa > pb
			var overlaps_a := 0
			var overlaps_b := 0
			for other in slots:
				var other_cat := StringName(str(other.get("category", "")))
				if sa.def().has_category(other_cat):
					overlaps_a += 1
				if sb.def().has_category(other_cat):
					overlaps_b += 1
			if overlaps_a != overlaps_b:
				return overlaps_a < overlaps_b
			var ca := int(remaining.get(a, sa.count))
			var cb := int(remaining.get(b, sb.count))
			return ca > cb if ca != cb else a < b)
		var lead := -1
		if not picks.is_empty():
			lead = picks[i]
			if lead < 0 or lead >= inv.slot_count or inv.slots[lead] == null or not inv.slots[lead].def().has_category(cat):
				return []
			if int(remaining.get(lead, inv.slots[lead].count)) <= 0:
				return []
		elif not candidates.is_empty():
			lead = candidates[0]
		if lead < 0:
			return []
		var parts: Array[Dictionary] = []
		var order: Array[int] = [lead]
		for idx in candidates:
			if idx != lead:
				order.append(idx)
		for idx in order:
			var available := int(remaining.get(idx, inv.slots[idx].count))
			var take := mini(need, available)
			if take > 0:
				parts.append({"idx": idx, "count": take})
				remaining[idx] = available - take
				need -= take
			if need == 0:
				break
		if need > 0:
			return []
		plan.append({"lead": lead, "parts": parts})
	return plan

static func default_picks(inv: Inventory, rec: Dictionary) -> Array[int]:
	var plan := _plan(inv, rec)
	if not plan.is_empty():
		var picks: Array[int] = []
		for row in plan:
			picks.append(int(row["lead"]))
		return picks
	var missing: Array[int] = []
	missing.resize(rec.get("slots", []).size())
	missing.fill(-1)
	return missing

static func picks_valid(inv: Inventory, rec: Dictionary, picks: Array[int]) -> bool:
	return not _plan(inv, rec, picks).is_empty()

static func primary_index(rec: Dictionary) -> int:
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		if slots[i] is Dictionary and bool(slots[i].get("primary", false)):
			return i
	return 0

static func preview(inv: Inventory, rec: Dictionary, picks: Array[int]) -> ItemStack:
	if not picks_valid(inv, rec, picks):
		return null
	var pidx := primary_index(rec)
	var primary := inv.slots[picks[pidx]]
	var levels := consumed_levels(inv, rec, picks)
	return build_output(rec, primary, crafted_level_for(rec, levels))

static func consumed_levels(inv: Inventory, rec: Dictionary, picks: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for row in _plan(inv, rec, picks):
		for part in row["parts"]:
			var stack := inv.slots[int(part["idx"])]
			for _n in int(part["count"]):
				out.append(stack.level)
	return out

static func slot_level_contributions(inv: Inventory, rec: Dictionary, picks: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var plan := _plan(inv, rec, picks)
	for i in plan.size():
		for part in plan[i]["parts"]:
			var stack := inv.slots[int(part["idx"])]
			out.append({"slot": i, "level": stack.level, "count": int(part["count"]), "def_id": str(stack.def_id)})
	return out

static func skill_level_for(rec: Dictionary, player: Player = null) -> int:
	var skill := str(rec.get("skill", "processing"))
	var p := player
	if p == null:
		p = _player()
	if p and p.skills:
		var lvl := p.skills.level_of(skill)
		# Lab / early game: if the tree is still 0, fall back so recipes remain testable.
		# ASSUMPTION: skill 0 means "not started"; use recipe max as soft unlock until SP spent.
		if lvl > 0:
			return lvl
	return 60

static func crafted_level_for(rec: Dictionary, levels: Array[int], player: Player = null) -> int:
	return ProgressionScaling.crafted_level(levels, int(rec.get("max_level", 60)), skill_level_for(rec, player))

static func build_output(rec: Dictionary, primary: ItemStack, crafted_level: int, consumed: Array[ItemStack] = []) -> ItemStack:
	var out_row: Dictionary = rec.get("output", {})
	var out_id := StringName(str(out_row.get("id", "")))
	if bool(rec.get("keep_output_id", false)) and primary:
		var pd := primary.def()
		if pd and (pd.has_category(&"cooked") or primary.process_count >= 2):
			out_id = primary.def_id
	if bool(rec.get("burn_on_fail", false)):
		var chance := float(rec.get("burn_chance", 0.2))
		if randf() < chance:
			out_id = StringName(str(rec.get("burn_output", "burnt_food")))
			print("[craft] burnt %s" % rec.get("id", ""))
	var out := ItemStack.make(out_id, int(out_row.get("count", 1)))
	if primary:
		out.attributes = primary.attributes.duplicate(true)
		# Tool quality follows the primary material; level follows the weighted material mean.
		if out.def() and out.def().has_category(&"tool"):
			out.attributes["material_tier"] = str(ProgressionScaling.material_tier(primary.def_id, primary.attributes))
		# Poison persists through cooking (PRD §9.3 MAY keep).
		if &"poisoned" in primary.flags:
			out.set_flag(&"poisoned", true)
	out.level = crafted_level
	if rec.has("force_process_count"):
		out.process_count = int(rec.get("force_process_count", 0))
	elif primary:
		out.process_count = primary.process_count + int(rec.get("process_add", 1))
	else:
		out.process_count = int(rec.get("process_add", 1))
	var buff := str(rec.get("buff_id", ""))
	if buff != "":
		out.attributes["food_buff"] = buff
	# Boil uprank is the mean-of-materials rule (already in crafted_level).
	out.apply_level_stats()
	# Clear raw flag on cooked outputs.
	if out.def() and out.def().has_category(&"cooked"):
		out.set_flag(&"raw", false)
	return out

static func _player() -> Player:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return (tree as SceneTree).get_first_node_in_group("player") as Player
	return null

static func station_id(rec: Dictionary) -> String:
	var v: Variant = rec.get("station", null)
	if v == null:
		return ""
	var s := str(v)
	if s == "" or s == "<null>" or s == "null":
		return ""
	return s

static func node_station_id(n: Node) -> String:
	if n is CraftStation:
		return str((n as CraftStation).station_id)
	if n is Bonfire:
		return "bonfire"
	if n.get("station_id") != null:
		return str(n.get("station_id"))
	if n.get("kind") != null:
		return str(n.get("kind"))
	return ""

## Closest station of this kind on the island, or null when none is built.
static func nearest_station(player: Player, sid: StringName) -> Node3D:
	if player == null or not is_instance_valid(player) or sid == &"":
		return null
	var best: Node3D = null
	var best_d := INF
	for n in player.get_tree().get_nodes_in_group("craft_station"):
		if not (n is Node3D) or node_station_id(n) != str(sid):
			continue
		var d := player.global_position.distance_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node3D
	return best

static func station_nearby(player: Player, rec: Dictionary) -> bool:
	var sid := station_id(rec)
	if sid == "":
		return true
	var n := nearest_station(player, StringName(sid))
	return n != null and player.global_position.distance_to(n.global_position) <= STATION_RANGE

## Optional endgame gates. Existing recipes are unchanged.
static func progression_block(player: Player, rec: Dictionary) -> String:
	var survival := int(rec.get("required_survival", 0))
	if survival > 0 and (player == null or player.skills == null or player.skills.level_of("survival") < survival):
		return "needs Survival %d" % survival
	var minimum := int(rec.get("min_level", 0))
	if minimum > 0:
		if player.skills == null or player.skills.level_of(str(rec.get("skill", "processing"))) < minimum:
			return "needs %s %d" % [str(rec.get("skill", "processing")), minimum]
		var levels := consumed_levels(player.inventory, rec, default_picks(player.inventory, rec))
		if levels.is_empty() or crafted_level_for(rec, levels, player) < minimum:
			return "needs materials and crafting skill for level %d" % minimum
	return ""

static func can_make(player: Player, rec: Dictionary, picks: Array[int]) -> bool:
	if rec.is_empty():
		return false
	if progression_block(player, rec) != "":
		return false
	if not station_nearby(player, rec):
		return false
	return picks_valid(player.inventory, rec, picks)

## Which skill tree a recipe trains, from its output categories. ASSUMPTION mapping.
static func tree_for_recipe(rec: Dictionary) -> String:
	if rec.has("tree"):
		return str(rec["tree"])
	var out_row: Dictionary = rec.get("output", {})
	var def := Data.item(StringName(str(out_row.get("id", ""))))
	if def:
		for c in def.categories:
			var cs := str(c)
			if cs == "food":
				return "cooking"
			if cs == "tool" or cs == "weapon":
				return "weapon_tools"
			if cs == "clothing" or cs == "bag" or cs == "armor":
				return "tailoring"
			if cs == "building" or cs == "building_kit":
				return "construction"
	return "processing"

## Crafting trains the recipe's tree and pays pioneer XP (gathering pays 1/unit, kills pay by tier).
static func grant_craft_xp(player: Player, rec: Dictionary) -> void:
	if player and player.skills:
		player.skills.add_xp(tree_for_recipe(rec), 6 + int(recipe_seconds(rec)))
	else:
		World.add_xp(6 + int(recipe_seconds(rec)))

static func craft(player: Player, rec: Dictionary, picks: Array[int]) -> ItemStack:
	if not can_make(player, rec, picks):
		return null
	var consumed := consume_for_craft(player.inventory, rec, picks)
	return finish_craft(player, rec, consumed)

static func recipe_seconds(rec: Dictionary) -> float:
	# ASSUMPTION: 3 s when recipes.json omits seconds.
	if rec.has("seconds"):
		return maxf(0.1, float(rec.get("seconds", 3.0)))
	return 3.0

static func recipes_for_station(sid: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var want := str(sid)
	for row in Data.recipe_list:
		if not row is Dictionary:
			continue
		if station_id(row as Dictionary) == want:
			out.append(row as Dictionary)
	return out

static func missing_ingredient_name(inv: Inventory, rec: Dictionary) -> String:
	if inv == null or rec.is_empty():
		return "?"
	if not _plan(inv, rec).is_empty():
		return ""
	# For a failed recipe, show the first genuinely short category. Totals are
	# guidance only: dual-category units must still be allocated by _plan.
	for slot in rec.get("slots", []):
		if not slot is Dictionary:
			continue
		var cat := StringName(str(slot.get("category", "")))
		var available := 0
		for idx in inv.find_by_category(cat):
			available += inv.slots[idx].count
		if available < int(slot.get("count", 1)):
			return _category_hint(cat)
	return "materials"

static func preview_level(inv: Inventory, rec: Dictionary) -> int:
	var picks := default_picks(inv, rec)
	if not picks_valid(inv, rec, picks):
		return int(rec.get("max_level", 1)) if rec.has("max_level") else 1
	return crafted_level_for(rec, consumed_levels(inv, rec, picks))

static func sample_def_for_category(inv: Inventory, cat: StringName) -> StringName:
	for idx in inv.find_by_category(cat):
		var s := inv.slots[idx]
		if s:
			return s.def_id
	# Fallback representative ids for UI when bag is empty.
	match str(cat):
		"meat", "raw_meat":
			return &"raw_meat"
		"pot_clay":
			return &"clay"
		"wood", "handle", "burnable":
			return &"branch"
		"water":
			return &"water_bucket"
		"spice":
			return &"spice_herb"
		"herb":
			return &"herb_leaf"
		"seed":
			return &"flax_seed"
		"fertilizer":
			return &"fruit_fertilizer"
		"fruit":
			return &"berry"
		"stalk":
			return &"fibre_stalk"
		"bucket":
			return &"empty_bucket"
		_:
			return cat

static func consume_for_craft(inv: Inventory, rec: Dictionary, picks: Array[int]) -> Array[ItemStack]:
	var refund: Array[ItemStack] = []
	var plan := _plan(inv, rec, picks)
	if plan.is_empty():
		return refund
	# Take each part exactly once. Inventory.remove_at does not shift indices.
	# The primary slot goes first for output attribute/process inheritance; each
	# remaining part retains its own level/attributes for weighted level and refund.
	var order: Array[int] = [primary_index(rec)]
	for i in plan.size():
		if i != order[0]:
			order.append(i)
	for i in order:
		for part in plan[i]["parts"]:
			var taken := inv.remove_at(int(part["idx"]), int(part["count"]))
			if taken: refund.append(taken)
	return refund

static func finish_craft(player: Player, rec: Dictionary, consumed: Array[ItemStack]) -> ItemStack:
	if rec.is_empty() or consumed.is_empty():
		return null
	var primary := consumed[0]
	var levels: Array[int] = []
	for s in consumed:
		if s:
			for _n in s.count:
				levels.append(s.level)
	var out := build_output(rec, primary, crafted_level_for(rec, levels, player), consumed)
	var gained := out.count
	var left := player.inventory.add(out)
	if left > 0:
		print("[craft] bag full remainder=%d" % left)
		gained -= left
	print("[item] +%d %s" % [gained, out.def_id])
	print("[craft] level=%d from %s" % [out.level, levels])
	print("[craft] %s from primary=%s %s process=%d" % [out.def_id, primary.def_id, primary.attributes, out.process_count])
	World.note_craft(StringName(str(rec.get("id", ""))))
	grant_craft_xp(player, rec)
	# Restore count for callers (toast) since add() empties a fully-accepted stack.
	out.count = gained
	return out if gained > 0 else null

static func _category_hint(cat: StringName) -> String:
	match str(cat):
		"meat", "raw_meat":
			return "raw_meat"
		"pot_clay":
			return "clay"
		"wood", "handle", "burnable":
			return "branch"
		"blade_mat":
			return "stone"
		"lashing":
			return "twine"
		"water":
			return "water_bucket"
		"spice":
			return "spice_herb"
		"bucket":
			return "empty_bucket"
		_:
			return str(cat)
