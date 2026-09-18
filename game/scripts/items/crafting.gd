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
	for slot in rec.get("slots", []):
		if not slot is Dictionary:
			picks.append(-1)
			continue
		var need := int(slot.get("count", 1))
		var chosen := -1
		for idx in stacks_for_slot(inv, slot):
			var already: int = int(used.get(idx, 0))
			if inv.slots[idx].count - already >= need:
				chosen = idx
				used[idx] = already + need
				break
		picks.append(chosen)
	return picks

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

static func skill_level_for(rec: Dictionary) -> int:
	var _skill := StringName(str(rec.get("skill", "processing")))
	# ASSUMPTION: M8 owns real per-tree skill progression. Until then every crafting tree is level 60.
	return 60

static func crafted_level_for(rec: Dictionary, levels: Array[int]) -> int:
	if levels.is_empty():
		return 1
	var total := 0
	for lv in levels:
		total += lv
	var average := int(floor(float(total) / float(levels.size())))
	var cap := mini(skill_level_for(rec), int(rec.get("max_level", 60)))
	return clampi(average, 1, cap)

static func build_output(rec: Dictionary, primary: ItemStack, crafted_level: int) -> ItemStack:
	var out_row: Dictionary = rec.get("output", {})
	var out := ItemStack.make(StringName(str(out_row.get("id", ""))), int(out_row.get("count", 1)))
	out.attributes = primary.attributes.duplicate(true)
	out.level = crafted_level
	out.process_count = primary.process_count + int(rec.get("process_add", 1))
	out.apply_level_stats()
	return out

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
		var st := n as CraftStation
		if st == null or str(st.station_id) != sid:
			continue
		if player.global_position.distance_to(st.global_position) <= STATION_RANGE:
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
	var out := build_output(rec, primary, crafted_level_for(rec, levels))
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
	var out := build_output(rec, primary, crafted_level_for(rec, levels))
	var gained := out.count
	var left := player.inventory.add(out)
	if left > 0:
		print("[craft] bag full remainder=%d" % left)
		gained -= left
	print("[item] +%d %s" % [gained, out.def_id])
	print("[craft] level=%d from %s" % [out.level, levels])
	print("[craft] %s from primary=%s %s" % [out.def_id, primary.def_id, primary.attributes])
	World.note_craft(StringName(str(rec.get("id", ""))))
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
		_:
			return str(cat)
