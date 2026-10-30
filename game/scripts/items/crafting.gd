class_name Crafting
extends RefCounted
## Flexible recipes: category slots, primary-slot attribute inheritance (PRD §9.1).

const STATION_RANGE := 2.0
## ASSUMPTION: a master cook (skill 60) burns a quarter as often as a novice.
const BURN_SKILL_CUT := 0.75

## data/world/rules.json's "crafting" block (spec 04, plan 3.3): curve scale, flawless chance, rare traits.
static func rules() -> Dictionary:
	if Data == null:
		return {}
	var cfg: Variant = Data.world_rules.get("crafting", {})
	return cfg as Dictionary if cfg is Dictionary else {}

## "Crafting Ability" of spec 04: base attributes, tools, specialization and food add to it, and the
## category level is the base. # ASSUMPTION: this build has no attribute/gear ability stat yet, so the
## base is the governing skill level, plus learned nodes' "craft_ability" abilities, plus food buffs.
static func crafting_ability(player: Player, rec: Dictionary) -> float:
	var base := float(skill_level_for(rec, player))
	var p := player
	if p == null:
		p = _player()
	if p == null:
		return base
	if p.skills:
		base += float(SkillRules.ability(p.skills, str(rules().get("ability_food_stat", "craft_ability"))))
	base += p.food_buffs.added("craft_ability")
	return base

## The ability a recipe asks for. A recipe without required_ability only has its category-level gate
## (min_level), so it always succeeds: "Success Rate 100 %" on the skewer (spec 25 §8).
static func required_ability(rec: Dictionary) -> float:
	return maxf(0.0, float(rec.get("required_ability", 0.0)))

## Spec 04's preserved curve: shortfall = max(0, required - actual); success = clamp(1-(shortfall/100)^2, 0, 1).
## 0 -> 1.0, 50 -> 0.75, 80 -> 0.36, 100 -> 0.0.
static func success_chance(rec: Dictionary, ability: float) -> float:
	var shortfall := maxf(0.0, required_ability(rec) - ability)
	var scale := maxf(1.0, float(rules().get("success_curve_scale", 100.0)))
	return clampf(1.0 - pow(shortfall / scale, 2.0), 0.0, 1.0)

static func success_for(rec: Dictionary, player: Player = null) -> float:
	return success_chance(rec, crafting_ability(player, rec))

## Flawless is a separate roll on a successful craft (spec 04), plan 3.3's 5 %.
static func flawless_chance() -> float:
	return clampf(float(rules().get("flawless_chance", 0.05)), 0.0, 1.0)

## The rare (green) material traits, rules.json crafting.rare_attributes (spec 04's list).
static func rare_attributes() -> Array:
	var rows: Variant = rules().get("rare_attributes", [])
	return rows as Array if rows is Array else []

static func is_rare_attribute(attr: StringName) -> bool:
	return str(attr) in rare_attributes()

## One craft's outcome. `rng` reproduces it (tests, server); a craft that cannot fall short
## (required_ability 0) never fails, and a failed craft is never flawless.
## Rare trait: the primary material's own rare attribute always carries (spec 04 "rare attributes
## may pass from a single eligible primary material"); otherwise `rare_attribute_chance` (rules.json,
## 5 %) rolls one.
static func roll_outcome(rec: Dictionary, player: Player, primary: ItemStack, rng: RandomNumberGenerator = null, ability: float = NAN) -> Dictionary:
	var ab := ability if not is_nan(ability) else crafting_ability(player, rec)
	return roll_outcome_for(rec, primary, ab, rng)

## The same roll from an ability the caller already knows: the server has a character, not a Player.
static func roll_outcome_for(rec: Dictionary, primary: ItemStack, ability: float, rng: RandomNumberGenerator = null) -> Dictionary:
	var ab := ability
	var rand := rng if rng else RandomNumberGenerator.new()
	if rng == null:
		rand.randomize()
	var success := rand.randf() < success_chance(rec, ab)
	var flawless := success and rand.randf() < flawless_chance()
	var rare := &""
	for attr: Variant in Inventory.traits(primary).keys():
		if is_rare_attribute(StringName(str(attr))):
			rare = StringName(str(attr))
			break
	if rare == &"" and rand.randf() < float(Data.world_rules.get("rare_attribute_chance", 0.05)):
		var pool := rare_attributes()
		if not pool.is_empty():
			rare = StringName(str(pool[rand.randi_range(0, pool.size() - 1)]))
	# BAGUI: a trait the primary carries keeps its own tier (build_output copies it); a rolled one rolls I-V.
	var tier := LootRoller.roll_tier(rand) if rare != &"" and not Inventory.traits(primary).has(str(rare)) else 1
	return {"success": success, "flawless": flawless, "rare": rare, "rare_tier": tier}

## The deterministic quality a recipe card advertises: the success and flawless chances, and the
## primary trait the result inherits. Never rolls anything, so a preview cannot disagree with itself.
static func preview_quality(rec: Dictionary, player: Player, primary: ItemStack = null) -> Dictionary:
	var inherited: Array[String] = []
	if primary:
		for attr: Variant in Inventory.traits(primary).keys():
			inherited.append(str(attr))
	return {
		"success": success_for(rec, player),
		"flawless": flawless_chance(),
		"required_ability": required_ability(rec),
		"ability": crafting_ability(player, rec),
		"inherited": inherited,
		"loses_materials": true,
	}

## Flawless (spec 04 "stat improvement"): the item keeps its level (so a previewed level can never
## disagree with the result) and gains the recipe's stat bump - durability plus the quality attribute
## that bag_inspect and the item tooltip already read. A recipe that allows it may also raise the
## level by rules.json crafting.flawless_level_bonus (# ASSUMPTION: none of today's recipes do).
static func apply_outcome(out: ItemStack, rec: Dictionary, outcome: Dictionary, player: Player = null) -> ItemStack:
	if out == null or outcome.is_empty():
		return out
	if bool(outcome.get("flawless", false)):
		var bonus := float(rules().get("flawless_stat_bonus", 0.1))
		out.attributes["quality"] = "flawless"
		out.attributes["flawless_bonus"] = bonus
		out.set_flag(&"flawless", true)
		if out.max_durability > 0:
			out.max_durability = maxi(out.max_durability, int(round(float(out.max_durability) * (1.0 + bonus))))
			out.durability = out.max_durability
		if bool(rec.get("flawless_level", false)):
			var bump := int(rules().get("flawless_level_bonus", 1))
			out.level = mini(int(rec.get("max_level", 60)), out.level + bump)
			out.apply_level_stats()
	# COOKROLES: a roled recipe takes a rare (green) trait only through a slot's inheritance rule
	# (spec 08 §3 "only if the recipe defines a compatible conversion"), never through spec 04's
	# "the primary's own rare attribute always carries" rule.
	if CookRoles.is_roled(rec):
		return out
	var rare := StringName(str(outcome.get("rare", "")))
	if rare != &"" and not out.attributes.has(str(rare)):
		# A rare trait the primary already carried keeps its own tier; a rolled one takes its rolled tier.
		out.attributes[str(rare)] = clampi(int(outcome.get("rare_tier", 1)), 1, 5)
	return out

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
		# Spec 25 §8: the skewer's Tool slot takes a stick or a leg bone, not any handle (a club).
		cands.append(inv.find_by_category(cats[-1]).filter(func(idx: int) -> bool: return not inv.slots[idx].is_locked() and _allowed(slot, inv.slots[idx])))
	var remaining: Dictionary = {}
	var plan: Array[Dictionary] = []
	var prefer := StringName(str(rec.get("input_id", "")))
	var pi := primary_index(rec)
	var out_id := StringName(str((rec.get("output", {}) as Dictionary).get("id", "")))
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
			# An explicit pick must obey the slot's own rules too: a club is a handle, but the
			# skewer's Tool slot lists branch/bone only, so naming the club must fail, not slip past.
			if lead < 0 or lead >= inv.slot_count or inv.slots[lead] == null or not inv.slots[lead].def().has_category(cat) or not _allowed(slot, inv.slots[lead]):
				return []
			if int(remaining.get(lead, inv.slots[lead].count)) <= 0:
				return []
		var keys := {}
		var candidates: Array[int] = []
		candidates.assign(cands[i])
		var first := -1 # the least valuable unit left: the lead when none is picked
		for idx in candidates:
			var spent := 1 if i == pi and processing_left(rec, inv.slots[idx]) == 0 else 0
			# A unit of the recipe's own output (the twine made a moment ago, a fibre by category) goes
			# last: gathered stalks now roll traits (HARVESTROLL), which made a plain twine the cheapest
			# fibre, so a second twine ate the first one.
			var own := 1 if inv.slots[idx].def_id == out_id else 0
			keys[idx] = [spent, own] + _pick_key(inv.slots[idx], preferred, cats, value_first) + [-int(remaining.get(idx, inv.slots[idx].count)), idx]
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

## A slot's allowed_ids (recipes.json) narrow its category to listed item defs; no list = any.
## COOKROLES: a cooking slot that names a role (main/topping/sauce/broth/spice) also has to pass
## that role's category list, so a spice can never fill the main slot even when the slot's own
## category would let it through (spec 08 §3).
static func _allowed(slot: Dictionary, s: ItemStack) -> bool:
	if not CookRoles.role_accepts(slot, s):
		return false
	var ids: Variant = slot.get("allowed_ids", null)
	if not ids is Array or (ids as Array).is_empty() or s == null:
		return true
	return str(s.def_id) in (ids as Array).map(func(v: Variant) -> String: return str(v))

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
	var got := CookRoles.collect(rec, inv, plan_parts_flat(inv, rec, picks))
	return build_output(rec, primary, crafted_level_for(rec, levels), [], false, got)

## COOKROLES: a recipe's filled slots as Crafting.plan_parts rows, built from the bag's own plan.
## [] when the picks do not fit. Used by the preview paths, which never consume anything.
static func plan_parts_flat(inv: Inventory, rec: Dictionary, picks: Array[int]) -> Array[Dictionary]:
	var rows := _plan(inv, rec, picks)
	var out: Array[Dictionary] = []
	for i in rows.size():
		for part: Variant in rows[i]["parts"]:
			out.append({"slot": i, "idx": int((part as Dictionary)["idx"]), "count": int((part as Dictionary)["count"])})
	return out

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
## `roles` is CookRoles.collect()'s record of what the recipe's slots may pass (COOKROLES); {} keeps
## the old wholesale primary-attribute copy every earlier recipe relies on.
## OUTPUTS (design §7): the output row ({id, count}) that this slot-1 instance makes. A recipe's
## `outputs_by_primary` is keyed by the primary's declared tier (a `tier_<t>` category gives key `<t>`),
## then its item categories (in def order), then its computed material tier; no match, no key or no
## primary falls back to `output`. Every caller (build_output and so the preview, the offline craft and
## the server intent; the craft screens) reads the output through here.
static func output_for(rec: Dictionary, primary: ItemStack) -> Dictionary:
	var fallback: Dictionary = rec.get("output", {})
	var by: Variant = rec.get("outputs_by_primary", null)
	if primary == null or not by is Dictionary:
		return fallback
	var keys: Array[String] = []
	var pd := primary.def()
	if pd:
		for c in pd.categories:
			if str(c).begins_with("tier_"):
				keys.push_front(str(c).trim_prefix("tier_"))  # flint (categories stone, tier_flint) is flint
			else:
				keys.append(str(c))
	keys.append(str(ProgressionScaling.material_tier(primary.def_id, primary.attributes)))
	for k in keys:
		var row: Variant = (by as Dictionary).get(k, null)
		if row is Dictionary:
			return row
	return fallback

static func build_output(rec: Dictionary, primary: ItemStack, crafted_level: int, consumed: Array[ItemStack] = [], burnt: bool = false, roles: Dictionary = {}) -> ItemStack:
	var out_row := output_for(rec, primary)
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
		# Spec 31 §4/§10: a bag inherits only the storage attributes its type lists; Pocket comes
		# from the material, never from the bag's level.
		if BagCapacity.is_bag(out.def_id):
			BagCapacity.apply_inheritance(out, primary)
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
	# COOKROLES: a roled recipe keeps only what its slots' inheritance rules allow (the copy above
	# was the old every-attribute passthrough). `roles` was read from the instances before they left
	# the bag.
	CookRoles.apply_to_output(out, rec, roles)
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

## RECIPETOOLS (docs/design/tools-durability-crafting.md §3.4): a recipe's `requires_tool`, as
## {"class", "min_tier", "min_level"}; {} when it needs none. The old string form ("hoe") is that class at
## any tier. # ASSUMPTION: tier is the material ladder (stone..steel), the same one the pick gates use.
static func tool_need(rec: Dictionary) -> Dictionary:
	var v: Variant = rec.get("requires_tool", null)
	if v is String and v != "":
		return {"class": v, "min_tier": "stone", "min_level": 0}
	if v is Dictionary and str((v as Dictionary).get("class", "")) != "":
		return {"class": str(v["class"]), "min_tier": str((v as Dictionary).get("min_tier", "stone")),
			"min_level": int((v as Dictionary).get("min_level", 0))}
	return {}

## The work tool a craft uses: the bag's best unbroken WORK tool of the class at or above the tier
## (Inventory._best_tool's order: highest gather power), never a combat weapon and never the worn weapon
## slot (a Stone Dagger never satisfies "needs a knife"). Null when the recipe needs none or none qualifies.
static func recipe_tool(inv: Inventory, rec: Dictionary) -> ItemStack:
	var need := tool_need(rec)
	if need.is_empty() or inv == null:
		return null
	var best: ItemStack = null
	for s in inv.slots:
		if s == null or s.is_broken() or s.def() == null or not s.def().is_work_tool or str(s.def().tool_class) != str(need["class"]):
			continue
		if ProgressionScaling.tier_index(s.material_tier()) < ProgressionScaling.tier_index(StringName(str(need["min_tier"]))) or s.level < int(need["min_level"]):
			continue
		if best == null or s.gather_power() > best.gather_power():
			best = s
	return best

## "" when the bag holds the recipe's tool, else the row's reason: "Needs work axe (flint)".
static func tool_block(inv: Inventory, rec: Dictionary) -> String:
	var need := tool_need(rec)
	if need.is_empty() or recipe_tool(inv, rec) != null:
		return ""
	var lv := " Lv %d" % int(need["min_level"]) if int(need["min_level"]) > 0 else ""
	var tool := str(need["class"]) if str(need["class"]) == "hoe" else "work " + str(need["class"])
	return "Needs %s (%s%s)" % [tool, need["min_tier"], lv]

## One craft run's wear on its tool: 1 durability, success or failure (§3.4). # ASSUMPTION: 1 per run.
static func wear_recipe_tool(inv: Inventory, rec: Dictionary) -> void:
	var t := recipe_tool(inv, rec)
	if t == null:
		return
	if not t.wear(1):
		print("[item] %s broke" % t.def_id)
	inv.changed.emit()

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
	if player != null:
		return tool_block(player.inventory, rec)
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

## The Crafting Ability of a survivor whose governing skill level, learned-node bonus and food bonus
## are known: offline and the server both build it here, so one outcome rule serves both.
static func ability_of(skill_level: int, node_bonus: float = 0.0, food_bonus: float = 0.0) -> float:
	return float(skill_level) + node_bonus + food_bonus

## One craft, decided once (spec 04, plan 3.3): the exact picked instances, the success/flaw/flare
## roll and the burn roll, and the output level. A caller that has to wait (a full bag, a time
## gate, a server op) keeps this plan and reuses it: it is never re-rolled, so a retry cannot turn
## a good craft into a burnt one or a failure into a success.
## {} when the picks do not fit the recipe (missing material, a disallowed instance, no processing left).
static func plan_craft(rec: Dictionary, inv: Inventory, picks: Array[int], ability: float, level: int, burn_skill: int = 0, rng: RandomNumberGenerator = null) -> Dictionary:
	if rec.is_empty() or inv == null or not picks_valid(inv, rec, picks):
		return {}
	var rows := _plan(inv, rec, picks)
	if rows.is_empty():
		return {}
	# Every unit the craft will take, not just one lead per recipe slot: a slot with count 2 can be
	# filled by a lead plus a supplemental stack, and a delayed retry must spend those same units with
	# their own level and attributes, never whatever the bag happens to hold when the work finishes.
	var parts: Array[Dictionary] = []
	var uids: Array[String] = []
	var defs: Array[String] = []
	for i in rows.size():
		var row: Dictionary = rows[i]
		var lead: int = int(row["lead"])
		var lead_stack: ItemStack = inv.slots[lead]
		uids.append(lead_stack.uid)
		defs.append(str(lead_stack.def_id))
		for part: Dictionary in row["parts"]:
			var at := int(part["idx"])
			var st: ItemStack = inv.slots[at]
			parts.append(_pinned_part(i, st, int(part["count"]), at))
	var primary: ItemStack = inv.slots[picks[primary_index(rec)]] if primary_index(rec) < picks.size() else null
	return {
		"recipe": str(rec.get("id", "")),
		"picks": picks.duplicate(),
		"uids": uids,
		"defs": defs,
		"parts": parts,
		"outcome": roll_outcome_for(rec, primary, ability, rng),
		"burnt": rolls_burn(rec, burn_skill, rng),
		"level": level,
	}

## One planned unit: its identity plus, for a fungible (uid-less) stack, the value fingerprint that
## makes it a different good from any other stack of the same def (ItemStack.can_merge_with's rule).
static func _pinned_part(slot_i: int, st: ItemStack, count: int, at: int) -> Dictionary:
	return {
		"slot": slot_i, "uid": st.uid, "def": str(st.def_id), "count": count, "at": at,
		"level": st.level, "process_count": st.process_count,
		"attributes": st.attributes.duplicate(true),
		"flags": _flag_strings(st.flags),
		"durability": st.durability, "max_durability": st.max_durability,
	}

static func _flag_strings(flags: Array) -> Array:
	var out: Array = []
	for f: Variant in flags:
		out.append(str(f))
	return out

## Is `st` the same good as the planned fungible unit? Def, level, process, attributes (climate aside),
## flags and durability all count, exactly as a merge would: a same-def stack with another level or
## another trait is a different unit, not a valid stand-in.
static func _same_good(row: Dictionary, st: ItemStack) -> bool:
	if st == null or str(st.def_id) != str(row.get("def", "")):
		return false
	if st.uid != "":
		return false
	if int(st.level) != int(row.get("level", 1)) or int(st.process_count) != int(row.get("process_count", 0)):
		return false
	if int(st.durability) != int(row.get("durability", 0)) or int(st.max_durability) != int(row.get("max_durability", 0)):
		return false
	if str(_flag_strings(st.flags)) != str(row.get("flags", [])):
		return false
	var want: Dictionary = row.get("attributes", {}) as Dictionary
	var got: Dictionary = {}
	var want_plain: Dictionary = {}
	for k: Variant in st.attributes:
		if str(k) not in ItemStack.MERGE_IGNORED_ATTRS:
			got[str(k)] = st.attributes[k]
	for k: Variant in want:
		if str(k) not in ItemStack.MERGE_IGNORED_ATTRS:
			want_plain[str(k)] = want[k]
	return str(got) == str(want_plain)

## The plan's exact units resolved against the bag as it is now, keyed by the recipe slot they fill.
## [] when any planned unit (or part of its count) has left the bag: a caller then stops the craft
## untouched instead of spending a different instance of the same def (spec 08:98).
static func plan_parts(inv: Inventory, rec: Dictionary, plan: Dictionary) -> Array[Dictionary]:
	if inv == null or rec.is_empty() or plan.is_empty():
		return []
	var rows: Array = plan.get("parts", [])
	var slots: Array = rec.get("slots", [])
	if rows.is_empty() or slots.is_empty():
		return []
	# One pass over the bag: uid -> slot, def -> slots. Resolution stays O(bag + parts).
	var by_uid: Dictionary = {}
	var by_def: Dictionary = {}
	for j in inv.slot_count:
		var s: ItemStack = inv.slots[j]
		if s == null:
			continue
		if s.uid != "":
			by_uid[s.uid] = j
		var d := str(s.def_id)
		if not by_def.has(d):
			by_def[d] = []
		(by_def[d] as Array).append(j)
	var out: Array[Dictionary] = []
	var taken: Dictionary = {}
	var per_slot: Dictionary = {}
	for row: Variant in rows:
		if not row is Dictionary:
			return []
		var slot_i := int((row as Dictionary).get("slot", -1))
		if slot_i < 0 or slot_i >= slots.size() or not slots[slot_i] is Dictionary:
			return []
		var def_id := str((row as Dictionary).get("def", ""))
		var count := int((row as Dictionary).get("count", 0))
		if count <= 0:
			return []
		var uid := str((row as Dictionary).get("uid", ""))
		var idx := int(by_uid.get(uid, -1))
		if uid != "" and idx < 0:
			# An identified instance that left the bag is not replaced by another of the same def.
			return []
		if idx < 0:
			# A fungible stack has no identity, but it does have a value: the same def at another level,
			# process, attributes, flags or durability is a different unit. Take the stack it was planned
			# in only if it still holds that same value, else another equivalent one, else stop.
			var at := int((row as Dictionary).get("at", -1))
			if at >= 0 and at < inv.slot_count and _same_good(row as Dictionary, inv.slots[at]):
				idx = at
			elif by_def.has(def_id):
				for cand: int in (by_def[def_id] as Array):
					if _same_good(row as Dictionary, inv.slots[cand]):
						idx = cand
						break
			if idx < 0:
				return []
		if idx < 0 or inv.slots[idx] == null or str(inv.slots[idx].def_id) != def_id:
			return []
		var slot_def: Dictionary = slots[slot_i]
		var cat := StringName(str(slot_def.get("category", "")))
		if not inv.slots[idx].def().has_category(cat) or not _allowed(slot_def, inv.slots[idx]):
			return []
		var used := int(taken.get(idx, 0))
		if inv.slots[idx].count - used < count:
			return []
		taken[idx] = used + count
		per_slot[slot_i] = int(per_slot.get(slot_i, 0)) + count
		out.append({"slot": slot_i, "idx": idx, "count": count})
	for i in slots.size():
		if int(per_slot.get(i, 0)) < int((slots[i] as Dictionary).get("count", 1)):
			return []
	return out

## The lead slot of each recipe slot in the plan, resolved. [] when a planned unit has left.
static func plan_picks(inv: Inventory, rec: Dictionary, plan: Dictionary) -> Array[int]:
	var parts := plan_parts(inv, rec, plan)
	if parts.is_empty():
		return []
	var slots: Array = rec.get("slots", [])
	var picks: Array[int] = []
	picks.resize(slots.size())
	picks.fill(-1)
	for part in parts:
		var i := int(part["slot"])
		if picks[i] < 0:
			picks[i] = int(part["idx"])
	if picks.has(-1):
		return []
	return picks

## Consume exactly the resolved parts (primary slot first, for output attribute/process inheritance).
static func consume_parts(inv: Inventory, rec: Dictionary, parts: Array[Dictionary]) -> Array[ItemStack]:
	var refund: Array[ItemStack] = []
	var pi := primary_index(rec)
	var order: Array = parts.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := 0 if int(a["slot"]) == pi else 1
		var bp := 0 if int(b["slot"]) == pi else 1
		return ap < bp)
	for part: Variant in order:
		var taken := inv.remove_at(int((part as Dictionary)["idx"]), int((part as Dictionary)["count"]))
		if taken:
			refund.append(taken)
	return refund

## Does the planned output still fit once the plan's own units leave the bag? Checked on a scratch bag
## with the plan's burn result and level, so a retry never re-rolls either and never frees a different
## slot than run_plan will.
static func plan_fits(inv: Inventory, rec: Dictionary, plan: Dictionary) -> bool:
	if inv == null or rec.is_empty() or plan.is_empty():
		return false
	var parts := plan_parts(inv, rec, plan)
	if parts.is_empty():
		return false
	var scratch := Inventory.new(inv.slot_count)
	for i in inv.slot_count:
		if inv.slots[i]:
			scratch.slots[i] = inv.slots[i].duplicate_stack()
	var pi := primary_index(rec)
	var primary_idx := -1
	for part in parts:
		if int(part["slot"]) == pi:
			primary_idx = int(part["idx"])
			break
	var primary: ItemStack = scratch.slots[primary_idx].duplicate_stack() if primary_idx >= 0 else null
	var got := CookRoles.collect(rec, scratch, parts)
	var out := build_output(rec, primary, int(plan.get("level", 1)), [], bool(plan.get("burnt", false)), got)
	consume_parts(scratch, rec, parts)
	return scratch.can_accept(out)

## Execute a plan: consume its exact instances and add the result. No XP and no notices (the callers
## own those, offline and online alike). Status:
##   "made"    the item was added (item set)
##   "failed"  spec 25 §8: the picked instances are gone and nothing was made,
##   "full"    no room; nothing consumed, the plan is still good,
##   "left"    a planned instance is no longer in the bag; nothing consumed, no substitution.
static func run_plan(rec: Dictionary, inv: Inventory, plan: Dictionary, overflow: Array[ItemStack] = [], tools: Inventory = null) -> Dictionary:
	if rec.is_empty() or inv == null or plan.is_empty():
		return {"status": "left", "item": null}
	var parts := plan_parts(inv, rec, plan)
	if parts.is_empty():
		return {"status": "left", "item": null}
	# RECIPETOOLS: the tool comes from `tools` (a tribe member's hands) or the crafting bag; every
	# path (survivor, server intent, tribe order) refuses here without it and wears it once per run.
	if tools == null:
		tools = inv
	if tool_block(tools, rec) != "":
		print("[craft] refused %s: %s" % [rec.get("id", ""), tool_block(tools, rec)])
		return {"status": "tool", "item": null, "why": tool_block(tools, rec)}
	var outcome: Dictionary = plan.get("outcome", {})
	if not bool(outcome.get("success", true)):
		wear_recipe_tool(tools, rec)
		var lost := consume_parts(inv, rec, parts)
		var names: PackedStringArray = []
		for s in lost:
			names.append("%s x%d" % [str(s.def_id), s.count])
		print("[craft] failed %s: lost %s" % [rec.get("id", ""), ", ".join(names)])
		return {"status": "failed", "item": null}
	if not plan_fits(inv, rec, plan):
		print("[craft] refused %s: bag full" % rec.get("id", ""))
		return {"status": "full", "item": null}
	# Read what the slots inherit from the exact instances BEFORE they leave the bag (COOKROLES).
	var got := CookRoles.collect(rec, inv, parts)
	var consumed := consume_parts(inv, rec, parts)
	if consumed.is_empty():
		return {"status": "left", "item": null}
	wear_recipe_tool(tools, rec)
	var out := build_output(rec, consumed[0], int(plan.get("level", 1)), consumed, bool(plan.get("burnt", false)), got)
	apply_outcome(out, rec, outcome)
	if not out.is_fungible() and out.uid == "":  # in-place output keeps its instance identity
		out.stamp_identity("craft", World.player_name)
	var gained := out.count
	var left := inv.add(out)
	if left > 0:
		print("[craft] bag full remainder=%d" % left)
		var rest := out.duplicate_stack()
		rest.count = left
		overflow.append(rest)
		gained -= left
	print("[item] +%d %s" % [gained, out.def_id])
	print("[craft] %s level=%d burnt=%s" % [out.def_id, out.level, bool(plan.get("burnt", false))])
	out.count = gained
	return {"status": "made", "item": out if gained > 0 else null}

## The player-facing half of a finished plan: the notice a phone needs, and the once-per-success XP.
static func report_plan(player: Player, rec: Dictionary, res: Dictionary) -> void:
	match str(res.get("status", "")):
		"failed":
			if player:
				player.notice("Crafting failed: the materials are lost.")
			return
		"full":
			refuse_full(player, rec)
			return
		"left":
			if player:
				player.notice("Craft stopped: its materials left the bag.")
			return
		"tool":
			if player:
				player.notice("Craft stopped: %s." % str(res.get("why", "")).to_lower())
			return
	if str(res.get("status", "")) != "made":
		return
	World.note_craft(StringName(str(rec.get("id", ""))))
	grant_craft_xp(player, rec)

## The ability, output level and burn skill of a local survivor for a recipe's picks.
static func _plan_ability(player: Player, rec: Dictionary) -> float:
	return crafting_ability(player, rec)

static func plan_for_player(player: Player, rec: Dictionary, picks: Array[int], rng: RandomNumberGenerator = null) -> Dictionary:
	if player == null or not can_make(player, rec, picks):
		return {}
	var level := crafted_level_for(rec, consumed_levels(player.inventory, rec, picks), player)
	return plan_craft(rec, player.inventory, picks, _plan_ability(player, rec), level, skill_level_for(rec, player), rng)

## One craft (spec 04, plan 3.3): plan it once, then run the plan. A failed craft spends the picked
## instances exactly once and makes nothing; a successful one makes the previewed item, plus the
## flawless stat bump or the inherited rare trait. XP is paid once, on success.
static func craft(player: Player, rec: Dictionary, picks: Array[int], rng: RandomNumberGenerator = null) -> ItemStack:
	var plan := plan_for_player(player, rec, picks, rng)
	if plan.is_empty():
		return null
	return commit_plan(player, rec, plan)

## Run an already-decided plan for a local survivor (the bag-full retry path reuses the same one).
static func commit_plan(player: Player, rec: Dictionary, plan: Dictionary) -> ItemStack:
	if player == null or plan.is_empty():
		return null
	var res := run_plan(rec, player.inventory, plan)
	report_plan(player, rec, res)
	return res.get("item", null)

## A craft whose outcome the caller already decided (tests, labs, a replay): the plan is built from
## the given outcome, so the same validated consume/build path runs as in play.
static func commit_outcome(player: Player, rec: Dictionary, picks: Array[int], outcome: Dictionary, rng: RandomNumberGenerator = null, overflow: Array[ItemStack] = []) -> ItemStack:
	if player == null or not can_make(player, rec, picks) or picks.is_empty():
		return null
	var plan := plan_craft(rec, player.inventory, picks, _plan_ability(player, rec), crafted_level_for(rec, consumed_levels(player.inventory, rec, picks), player), skill_level_for(rec, player), rng)
	if plan.is_empty():
		return null
	plan["outcome"] = outcome
	var res := run_plan(rec, player.inventory, plan, overflow)
	report_plan(player, rec, res)
	return res.get("item", null)

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
	var got := CookRoles.collect(rec, scratch, plan_parts_flat(scratch, rec, picks))
	var out := build_output(rec, primary, crafted_level_for(rec, consumed_levels(scratch, rec, picks), player), [], burnt, got)
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

## "Craft into...": every recipe with a slot this item's tags satisfy (its categories, through
## ItemDef.has_category, the one tag check; allowed_ids still narrow a slot). A large leg bone tagged
## thick_pillar lists Plank, like split wood.
static func recipes_accepting(def_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var probe := ItemStack.make(def_id, 1)
	var d := probe.def() if probe else null
	if d == null:
		return out
	for row in Data.recipe_list:
		if not row is Dictionary:
			continue
		for slot: Variant in (row as Dictionary).get("slots", []):
			if slot is Dictionary and ItemTags.has_tag(def_id, StringName(str((slot as Dictionary).get("category", "")))) and _allowed(slot, probe): # the one tag API
				out.append(row as Dictionary)
				break
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

## Spec 31 §10: the bag crafting preview. It builds the would-be result through build_output (so
## the preview and the crafted item can never disagree) and itemises it with BagCapacity: the
## expected level, base capacity, inherited storage attributes, Pocket bonus, the bag's total bonus
## and the inventory capacity the survivor would have wearing it. {} when the recipe makes no bag
## or the picks do not fit.
static func bag_preview(inv: Inventory, rec: Dictionary, picks: Array[int], player: Player = null) -> Dictionary:
	if inv == null or rec.is_empty() or not picks_valid(inv, rec, picks):
		return {}
	var primary: ItemStack = inv.slots[picks[primary_index(rec)]]
	var out_id := StringName(str(output_for(rec, primary).get("id", "")))
	if not BagCapacity.is_bag(out_id):
		return {}
	var level := crafted_level_for(rec, consumed_levels(inv, rec, picks), player)
	var out := build_output(rec, primary, level)
	var b := BagCapacity.of_stack(out)
	var worn_now: int = BagCapacity.count(inv)
	var replaced: int = 0
	var slot := BagDef.slot(BagCapacity.bag_id_of(out_id))
	for s: String in inv.equipment:
		var v: Variant = inv.equipment[s]
		if v is ItemStack and BagCapacity.bag_id_of((v as ItemStack).def_id) != &"":
			replaced = int(BagCapacity.of_stack(v).get("total", 0))
			break
	return {
		"id": str(out_id), "bag_id": str(BagCapacity.bag_id_of(out_id)), "level": level,
		"base": int(b.get("base", 0)), "pocket": int(b.get("pocket", 0)),
		"pocket_level": BagCapacity.pocket_level(out), "capacity": int(b.get("capacity", 0)),
		"storage": b.get("storage", {}), "other": int(b.get("other", 0)),
		"bonus": int(b.get("total", 0)), "inherited": BagCapacity.inherited_attributes(out_id, primary),
		"total_capacity": worn_now - replaced + int(b.get("total", 0)),
		# Spec 04 / plan 3.3: the card's success and flawless chances come from the same functions
		# the craft rolls, so the preview can never advertise a chance the result does not use.
		"slot": str(slot), "success": success_for(rec, player), "flawless": flawless_chance(),
	}

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
