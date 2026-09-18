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

static func default_picks(inv: Inventory, rec: Dictionary) -> Array[int]:
	var picks: Array[int] = []
	var used: Dictionary = {}
	var prefer := StringName(str(rec.get("input_id", "")))
	for slot in rec.get("slots", []):
		if not slot is Dictionary:
			picks.append(-1)
			continue
		var need := int(slot.get("count", 1))
		var chosen := -1
		var prefer_slot := StringName(str((slot as Dictionary).get("prefer_id", prefer if picks.is_empty() else "")))
		if prefer_slot != &"":
			for idx in inv.find_all(prefer_slot) if inv.has_method("find_all") else _find_all(inv, prefer_slot):
				var already: int = int(used.get(idx, 0))
				if inv.slots[idx] and inv.slots[idx].count - already >= need:
					chosen = idx
					used[idx] = already + need
					break
		if chosen < 0:
			for idx in stacks_for_slot(inv, slot):
				var already2: int = int(used.get(idx, 0))
				if inv.slots[idx].count - already2 >= need:
					chosen = idx
					used[idx] = already2 + need
					break
		picks.append(chosen)
	return picks

static func _find_all(inv: Inventory, id: StringName) -> Array[int]:
	var out: Array[int] = []
	for i in inv.slot_count:
		var s := inv.slots[i]
		if s and s.def_id == id:
			out.append(i)
	return out

static func picks_valid(inv: Inventory, rec: Dictionary, picks: Array[int]) -> bool:
	var slots: Array = rec.get("slots", [])
	if picks.size() != slots.size():
		return false
	var used: Dictionary = {}
	for i in slots.size():
		var idx := picks[i]
		if idx < 0 or idx >= inv.slot_count or inv.slots[idx] == null:
			return false
		var slot: Dictionary = slots[i]
		var cat := StringName(str(slot.get("category", "")))
		var need := int(slot.get("count", 1))
		var d := inv.slots[idx].def()
		if d == null or not d.has_category(cat):
			return false
		var already: int = int(used.get(idx, 0))
		if inv.slots[idx].count - already < need:
			return false
		used[idx] = already + need
	return true

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
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		if i >= picks.size():
			continue
		var idx := picks[i]
		if idx < 0 or idx >= inv.slot_count:
			continue
		var stack := inv.slots[idx]
		if stack == null:
			continue
		var count := int(slots[i].get("count", 1))
		for _n in count:
			out.append(stack.level)
	return out

static func slot_level_contributions(inv: Inventory, rec: Dictionary, picks: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		if i >= picks.size() or not slots[i] is Dictionary:
			continue
		var idx := picks[i]
		if idx < 0 or idx >= inv.slot_count:
			continue
		var stack := inv.slots[idx]
		if stack == null:
			continue
		var count := int((slots[i] as Dictionary).get("count", 1))
		out.append({
			"slot": i,
			"level": stack.level,
			"count": count,
			"def_id": str(stack.def_id),
		})
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
	if levels.is_empty():
		return 1
	var total := 0
	for lv in levels:
		total += lv
	var average := int(floor(float(total) / float(levels.size())))
	var cap := mini(skill_level_for(rec, player), int(rec.get("max_level", 60)))
	return clampi(average, 1, cap)

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

static func station_nearby(player: Player, rec: Dictionary) -> bool:
	var sid := station_id(rec)
	if sid == "":
		return true
	if player == null or not is_instance_valid(player):
		return false
	for n in player.get_tree().get_nodes_in_group("craft_station"):
		var id := ""
		if n is CraftStation:
			id = str((n as CraftStation).station_id)
		elif n is Bonfire:
			id = "bonfire"
		elif n.get("station_id") != null:
			id = str(n.get("station_id"))
		elif n.get("kind") != null:
			id = str(n.get("kind"))
		if id != sid:
			continue
		if n is Node3D and player.global_position.distance_to((n as Node3D).global_position) <= STATION_RANGE:
			return true
	return false

static func can_make(player: Player, rec: Dictionary, picks: Array[int]) -> bool:
	if rec.is_empty():
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

static func grant_craft_xp(player: Player, rec: Dictionary) -> void:
	if player and player.skills:
		player.skills.add_xp(tree_for_recipe(rec), 6)

static func craft(player: Player, rec: Dictionary, picks: Array[int]) -> ItemStack:
	if not can_make(player, rec, picks):
		return null
	var pidx := primary_index(rec)
	var primary := player.inventory.slots[picks[pidx]].duplicate_stack()
	var levels := consumed_levels(player.inventory, rec, picks)
	var slots: Array = rec.get("slots", [])
	var used: Dictionary = {}
	for i in slots.size():
		var idx := picks[i]
		var need := int(slots[i].get("count", 1))
		used[idx] = int(used.get(idx, 0)) + need
	var keys: Array = used.keys()
	keys.sort()
	keys.reverse()
	for idx in keys:
		player.inventory.remove_at(int(idx), int(used[idx]))
	var out := build_output(rec, primary, crafted_level_for(rec, levels, player))
	var left := player.inventory.add(out)
	if left > 0:
		print("[craft] bag full remainder=%d" % left)
	print("[craft] level=%d from %s" % [out.level, levels])
	print("[craft] %s from primary=%s %s" % [out.def_id, primary.def_id, primary.attributes])
	grant_craft_xp(player, rec)
	World.note_craft(StringName(str(rec.get("id", ""))))
	return out

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
	var picks := default_picks(inv, rec)
	var slots: Array = rec.get("slots", [])
	for i in slots.size():
		if not slots[i] is Dictionary:
			continue
		var cat := StringName(str((slots[i] as Dictionary).get("category", "")))
		var need := int((slots[i] as Dictionary).get("count", 1))
		if i >= picks.size() or picks[i] < 0:
			return _category_hint(cat)
		var stack := inv.slots[picks[i]]
		if stack == null or stack.count < need:
			return _category_hint(cat)
	return ""

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
		"meat":
			return &"raw_meat"
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
	if not picks_valid(inv, rec, picks):
		return refund
	var slots: Array = rec.get("slots", [])
	# Consume in pick order so refund[0] stays the primary ingredient.
	var plan: Array[Dictionary] = []
	for i in slots.size():
		plan.append({"idx": picks[i], "need": int(slots[i].get("count", 1)), "ord": i})
	# Remove high indices first so earlier picks stay valid.
	var sorted_plan := plan.duplicate()
	sorted_plan.sort_custom(func (a: Dictionary, b: Dictionary) -> bool: return int(a["idx"]) > int(b["idx"]))
	var taken_by_ord: Dictionary = {}
	for row in sorted_plan:
		var taken := inv.remove_at(int(row["idx"]), int(row["need"]))
		taken_by_ord[int(row["ord"])] = taken
	for i in slots.size():
		var t: ItemStack = taken_by_ord.get(i, null) as ItemStack
		if t:
			refund.append(t)
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
		"meat":
			return "raw_meat"
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
