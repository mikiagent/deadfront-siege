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
	World.note_craft(StringName(str(rec.get("id", ""))))
	return out
