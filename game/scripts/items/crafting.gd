class_name Crafting
extends RefCounted
## Flexible recipes: category slots, primary-slot attribute inheritance (PRD §9.1).

const STATION_RANGE := 2.0
## ASSUMPTION: a master cook (skill 60) burns a quarter as often as a novice.
const BURN_SKILL_CUT := 0.75

static func recipe(id: StringName) -> Dictionary:
	return Data.recipes.get(id, {}) as Dictionary

static func all_recipes() -> Array:
	return Data.recipe_list

static func stacks_for_slot(inv: Inventory, slot: Dictionary) -> Array[int]:
	return inv.find_by_category(StringName(str(slot.get("category", ""))))

## Each recipe slot has a lead stack (for the primary item's attributes) and may draw
## its remaining units from other stacks. A plan row records exact bag indices/counts.
## Spec 05:23 (W2-INV): the recipe's own input (prefer_id) first, then the least valuable instance
## (Inventory.spend_key), then dedicated materials before dual-category ones, then the lead's def;
## a unit that a later slot still needs (a cheap reed is also the recipe's lashing) is left for it.
## When a slot still runs short, plan again with dedicated materials first (the order before W2-INV).
## A locked instance is spent only as the player's own pick (spec 13:229 "protect valuable items from
## ... crafting consumption"), never as a default lead or fill. An in-place primary with no processing
## left (W2-PROCESS) sorts last, so the card previews the instance a station will really use.
static func _plan(inv: Inventory, rec: Dictionary, picks: Array[int] = []) -> Array[Dictionary]:
	var plan := _plan_ordered(inv, rec, picks, true)
	return plan if not plan.is_empty() else _plan_ordered(inv, rec, picks, false)

static func _plan_ordered(inv: Inventory, rec: Dictionary, picks: Array[int], value_first: bool) -> Array[Dictionary]:
	var slots: Array = rec.get("slots", [])
	if inv == null or slots.is_empty() or (not picks.is_empty() and picks.size() != slots.size()):
		return []
	var cats: Array[StringName] = []
	var cands: Array = [] # per recipe slot: the bag slots of its category
	for slot: Variant in slots:
		if not slot is Dictionary:
			return []
		cats.append(StringName(str(slot.get("category", ""))))
		cands.append(inv.find_by_category(cats[-1]).filter(func(idx: int) -> bool: return not inv.slots[idx].is_locked()))
	var remaining: Dictionary = {}
	var plan: Array[Dictionary] = []
	var prefer := StringName(str(rec.get("input_id", "")))
	var pi := primary_index(rec)
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var cat := cats[i]
		var need := int(slot.get("count", 1))
		if need <= 0:
			return []
		var preferred := StringName(str(slot.get("prefer_id", prefer if i == 0 else "")))
		var lead := -1
		if not picks.is_empty():
			lead = picks[i]
			if lead < 0 or lead >= inv.slot_count or inv.slots[lead] == null or not inv.slots[lead].def().has_category(cat):
				return []
			if int(remaining.get(lead, inv.slots[lead].count)) <= 0:
				return []
		var keys := {}
		var candidates: Array[int] = []
		candidates.assign(cands[i])
		var first := -1 # the least valuable unit left: the lead when none is picked
		for idx in candidates:
			var spent := 1 if i == pi and processing_left(rec, inv.slots[idx]) == 0 else 0
			keys[idx] = [spent] + _pick_key(inv.slots[idx], preferred, cats, value_first) + [-int(remaining.get(idx, inv.slots[idx].count)), idx]
			if int(remaining.get(idx, inv.slots[idx].count)) > 0 and (first < 0 or keys[idx] < keys[first]):
				first = idx
		if first < 0:
			return []
		# Inside equal keys the lead's own def goes first, so a twine made a moment ago is not spent as
		# the fibre of the next twine while a raw stalk ties with it (W1-SRVDOM capture checks).
		var lead_def := inv.slots[lead if lead >= 0 else first].def_id
		for idx in candidates:
			(keys[idx] as Array).insert((keys[idx] as Array).size() - 2, 0 if inv.slots[idx].def_id == lead_def else 1)
		candidates.sort_custom(func(a: int, b: int) -> bool: return keys[a] < keys[b])
		var order: Array[int] = []
		if lead >= 0:
			order.append(lead)
		for idx in candidates:
			if idx != lead:
				order.append(idx)
		var parts: Array[Dictionary] = []
		for idx in order:
			var available := int(remaining.get(idx, inv.slots[idx].count))
			var take := mini(need, available)
			if value_first and idx != lead:
				take = mini(take, _spare_for_later(inv, slots, cands, remaining, i, idx))
			if take > 0:
				parts.append({"idx": idx, "count": take})
				remaining[idx] = available - take
				need -= take
			if need == 0:
				break
		if need > 0:
			return []
		plan.append({"lead": int(parts[0].idx), "parts": parts})
	return plan

## The default-pick sort key, ascending: the recipe's own input, then value (spend_key) and the
## number of the recipe's categories the item serves, in the order the plan pass asks for.
static func _pick_key(s: ItemStack, preferred: StringName, cats: Array[StringName], value_first: bool) -> Array:
	var pref := 0 if preferred != &"" and s.def_id == preferred else 1
	var overlaps := 0
	for c in cats:
		if s.def().has_category(c):
			overlaps += 1
	var value := Inventory.spend_key(s)
	return [pref] + value + [overlaps] if value_first else [pref, overlaps] + value

## Units of bag slot `idx` that recipe slot `i` may take while every later slot keeps enough
## candidates (spending a cheap reed as fibre must not leave the recipe's lashing short).
static func _spare_for_later(inv: Inventory, slots: Array, cands: Array, remaining: Dictionary, i: int, idx: int) -> int:
	var spare := 1 << 30
	for j in range(i + 1, slots.size()):
		if idx not in cands[j]:
			continue
		var supply := 0
		for c: int in cands[j]:
			supply += int(remaining.get(c, inv.slots[c].count))
		spare = mini(spare, supply - int(slots[j].get("count", 1)))
	return maxi(0, spare)

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
	if _plan(inv, rec, picks).is_empty():
		return false
	var pi := primary_index(rec)
	return pi >= picks.size() or picks[pi] < 0 or processing_left(rec, inv.slots[picks[pi]]) != 0

## In-place processing (spec 08 §2): drying, smoking, steaming... change the chosen instance itself
## and spend one of its processing opportunities. Which steps are in place is processing.json data.
static func is_in_place(rec: Dictionary) -> bool:
	var steps: Array = (ProcessStation.rules().get("in_place", {}) as Dictionary).get("steps", [])
	return str(rec.get("process_step", "")) in steps

## Opportunities an instance has left for an in-place recipe: -1 when the recipe is not in place.
## The steps already taken live in attributes.processed (the instance's processing history).
## # ASSUMPTION: 2 opportunities (spec 08: a reconstruction estimate, not a confirmed constant);
## the PRD's steam-steam question (open question 13) stays open, so steam spends one like any step.
static func processing_left(rec: Dictionary, stack: ItemStack) -> int:
	if stack == null or not is_in_place(rec):
		return -1
	var total := int((ProcessStation.rules().get("in_place", {}) as Dictionary).get("opportunities", 2))
	var done: Variant = stack.attributes.get("processed", [])
	return maxi(0, total - ((done as Array).size() if done is Array else 0))

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

## The crafting skill that clamps output level. A survivor's 0 is a real 0 (cap 1, sec-skill0-16);
## only a caller with no survivor at all (pure data checks) gets the recipe's own max.
static func skill_level_for(rec: Dictionary, player: Player = null) -> int:
	var skill := str(rec.get("skill", "processing"))
	var p := player
	if p == null:
		p = _player()
	if p and p.skills:
		return p.skills.level_of(skill)
	return int(rec.get("max_level", 60))

static func crafted_level_for(rec: Dictionary, levels: Array[int], player: Player = null) -> int:
	return ProgressionScaling.crafted_level(levels, int(rec.get("max_level", 60)), skill_level_for(rec, player))

## Burn odds for burn_on_fail recipes: the recipe's base chance, cut by the cooking skill.
static func burn_chance(rec: Dictionary, skill_level: int) -> float:
	if not bool(rec.get("burn_on_fail", false)):
		return 0.0
	var skill := clampf(float(skill_level) / 60.0, 0.0, 1.0)
	return float(rec.get("burn_chance", 0.2)) * (1.0 - BURN_SKILL_CUT * skill)

## One burn roll. Pass a seeded RNG to reproduce it (tests, server).
static func rolls_burn(rec: Dictionary, skill_level: int, rng: RandomNumberGenerator = null) -> bool:
	var chance := burn_chance(rec, skill_level)
	if chance <= 0.0:
		return false
	return (rng.randf() if rng else randf()) < chance

## The output stack. `burnt` comes from rolls_burn (decided by the caller so previews never burn).
static func build_output(rec: Dictionary, primary: ItemStack, crafted_level: int, consumed: Array[ItemStack] = [], burnt: bool = false) -> ItemStack:
	var out_row: Dictionary = rec.get("output", {})
	var out_id := StringName(str(out_row.get("id", "")))
	if bool(rec.get("keep_output_id", false)) and primary:
		var pd := primary.def()
		if pd and (pd.has_category(&"cooked") or primary.process_count >= 2):
			out_id = primary.def_id
	if burnt:
		out_id = StringName(str(rec.get("burn_output", "burnt_food")))
		print("[craft] burnt %s" % rec.get("id", ""))
	var out := ItemStack.make(out_id, int(out_row.get("count", 1)))
	if primary:
		out.attributes = primary.attributes.duplicate(true)
		# Gear quality follows the primary material; level follows the weighted material mean.
		var od := out.def()
		if od and (od.has_category(&"tool") or od.damage > 0.0 or od.armor_value > 0.0):
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
	if primary and is_in_place(rec):
		# Same instance, next state: identity, provenance and properties carry, one opportunity spent.
		var done: Variant = primary.attributes.get("processed", [])
		var hist: Array = (done as Array).duplicate() if done is Array else []
		hist.append(str(rec.get("process_step", "")))
		out.attributes["processed"] = hist
		# Spec 11 §8: "For in-place processing, use the existing item as the base; only change level
		# when the actual process rules require it." No rule here does, so a lv 31 meat stays lv 31.
		out.level = primary.level
		out.uid = primary.uid
		out.origin = primary.origin
		out.creator = primary.creator
		out.created_at = primary.created_at
		out.set_flag(&"raw", false)
	else:
		out.attributes.erase("processed")  # a new food starts with fresh opportunities
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
		return PlayerRegistry.local()
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
	# W2-SKILLS: a recipe a skill node gates (a node's recipe effect or the recipe's requires_node)
	# stays shown but locked, saying what to learn: "learn X (Tree Lv. N, SP)". It covers both kinds
	# of gate, so it is the only requires_node check here (W2-DATA's own check folds into it).
	if player != null and player.skills != null:
		var learn := SkillRules.recipe_block(player.skills, str(rec.get("id", "")))
		if learn != "":
			return learn
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

## Explicit tree wins, then the declared crafting skill; categories are legacy fallback.
static func tree_for_recipe(rec: Dictionary) -> String:
	if rec.has("tree"):
		return str(rec["tree"])
	if rec.has("skill") and str(rec["skill"]) != "":
		return str(rec["skill"])
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

static func craft(player: Player, rec: Dictionary, picks: Array[int], rng: RandomNumberGenerator = null) -> ItemStack:
	if not can_make(player, rec, picks):
		return null
	var burnt := rolls_burn(rec, skill_level_for(rec, player), rng)
	if not output_fits(player.inventory, rec, picks, burnt, player):
		refuse_full(player, rec)
		return null
	var consumed := consume_for_craft(player.inventory, rec, picks)
	return finish_craft(player, rec, consumed, burnt)

## Would the output still fit after the inputs leave the bag? Checked on a scratch copy so a
## full bag refuses before anything is consumed (sec-loss-08).
static func output_fits(inv: Inventory, rec: Dictionary, picks: Array[int], burnt: bool = false, player: Player = null) -> bool:
	if inv == null or not picks_valid(inv, rec, picks):
		return false
	var scratch := Inventory.new(inv.slot_count)
	for i in inv.slot_count:
		if inv.slots[i]:
			scratch.slots[i] = inv.slots[i].duplicate_stack()
	var primary := scratch.slots[picks[primary_index(rec)]].duplicate_stack()
	var out := build_output(rec, primary, crafted_level_for(rec, consumed_levels(scratch, rec, picks), player), [], burnt)
	consume_for_craft(scratch, rec, picks)
	return scratch.can_accept(out)

static func refuse_full(player: Player, rec: Dictionary) -> void:
	print("[craft] refused %s: bag full" % rec.get("id", ""))
	if player:
		player.notice("Bag is full: make room before crafting.")

static func recipe_seconds(rec: Dictionary) -> float:
	# ASSUMPTION: 3 s when recipes.json omits seconds.
	if rec.has("seconds"):
		return maxf(0.1, float(rec.get("seconds", 3.0)))
	return 3.0

## The time a recipe card shows: a process station's job time (processing.json) when the recipe runs on
## one, otherwise recipes.json's stand-and-craft time; a minute or more as m:ss ("10:00", "8.0s").
## recipe_seconds stays the stand-and-craft time: it also sets the XP (6 + seconds).
static func preview_time(rec: Dictionary) -> String:
	var secs := ProcessStation.job_seconds(StringName(station_id(rec)), StringName(str(rec.get("id", ""))))
	if secs <= 0.0:
		secs = recipe_seconds(rec)
	return ProcessStation.mmss(roundi(secs)) if secs >= 60.0 else "%.1fs" % secs

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

## -1 when the bag cannot make it: the UI must not advertise a level it cannot reach (craft-04).
static func preview_level(inv: Inventory, rec: Dictionary) -> int:
	var picks := default_picks(inv, rec)
	if not picks_valid(inv, rec, picks):
		return -1
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
		"cured_hide":
			return &"dried_hide"
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

## Units that do not fit go to `overflow`: the caller owns them and must put them back (StationCraft
## re-adds them after the craft). output_fits should make this unreachable: it is a last resort.
static func finish_craft(player: Player, rec: Dictionary, consumed: Array[ItemStack], burnt: bool = false, overflow: Array[ItemStack] = []) -> ItemStack:
	if rec.is_empty() or consumed.is_empty():
		return null
	var primary := consumed[0]
	var levels: Array[int] = []
	for s in consumed:
		if s:
			for _n in s.count:
				levels.append(s.level)
	var out := build_output(rec, primary, crafted_level_for(rec, levels, player), consumed, burnt)
	if not out.is_fungible() and out.uid == "":  # in-place output keeps its instance identity
		out.stamp_identity("craft", World.player_name)
	var gained := out.count
	var left := player.inventory.add(out)
	if left > 0:
		print("[craft] bag full remainder=%d" % left)
		var rest := out.duplicate_stack()
		rest.count = left
		overflow.append(rest)
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
		"cured_hide": # dried hide or straps; raw hide is dried first (PRD 8.3)
			return "dried_hide"
		"water":
			return "water_bucket"
		"spice":
			return "spice_herb"
		"bucket":
			return "empty_bucket"
		_:
			return str(cat)
