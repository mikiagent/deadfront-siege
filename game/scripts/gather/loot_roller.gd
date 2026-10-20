class_name LootRoller
extends RefCounted
## Pure roll math for gather rares and carcass loot. No nodes, RNG injected, so the server
## (W3-SRVACT) and tests run the same code as the client.

## Chance after tool tier and skill bonuses. tier_idx -1 = bare hands (no tier bonus).
static func scaled_chance(base: float, tier_idx: int, skill: int, per_tier: float, per_skill: float, cap: float) -> float:
	var mult := 1.0 + per_tier * float(maxi(0, tier_idx)) + per_skill * float(maxi(0, skill))
	return clampf(base * mult, 0.0, cap)

## Rare extras for one gathered unit on a node of `climate` (its island's). tool_tier &"" = bare hands.
## Returns item ids (each one unit) that hit their odds.
static func roll_gather_rares(family: String, role: String, climate: String, tool_tier: StringName, skill: int, rng: RandomNumberGenerator, luck: float = 1.0) -> Array[StringName]:
	var cfg := LootTables.gather_cfg()
	var tier_idx := ProgressionScaling.tier_index(tool_tier) if tool_tier != &"" else -1
	var out: Array[StringName] = []
	for row_v in LootTables.gather_rare_rows(family, role):
		var row := row_v as Dictionary
		# A climate's own materials only (world-design s4): no flint or copper off the home grassland.
		if not (climate in (row.get("climates", []) as Array)):
			continue
		var need := StringName(str(row.get("min_tool_tier", "")))
		if need != &"" and (tier_idx < 0 or tier_idx < ProgressionScaling.tier_index(need)):
			continue
		var c := scaled_chance(float(row.get("chance", 0.0)), tier_idx, skill,
				float(cfg.get("tool_tier_bonus", 0.0)), float(cfg.get("skill_bonus_per_level", 0.0)),
				float(cfg.get("max_chance", 0.5))) * luck
		if rng.randf() < c:
			out.append(StringName(str(row.get("item", ""))))
	return out

## Carcass loot from butchering.json base and rare rows (rare rows roll their "chance"). knife_tier &"" = no knife.
## node_tier is Data.butchering_level() (unlocked Butchering nodes gate skill rows);
## skill is the Butchering category level (scales counts and rare odds).
## Returns {"stacks": Array[ItemStack], "rares": Array[StringName]}.
static func roll_carcass(base_rows: Array, rare_rows: Array, level: int, knife_tier: StringName, node_tier: int, skill: int, no_meat: bool, rng: RandomNumberGenerator) -> Dictionary:
	var cfg := LootTables.butcher_cfg()
	var tier_idx := ProgressionScaling.tier_index(knife_tier) if knife_tier != &"" else -1
	var gates: Dictionary = cfg.get("part_min_tier", {})
	var count_mult := 1.0 + float(cfg.get("count_bonus_per_tier", 0.0)) * float(maxi(0, tier_idx)) \
			+ float(cfg.get("count_bonus_per_skill_level", 0.0)) * float(maxi(0, skill))
	var stacks: Array[ItemStack] = []
	var rares: Array[StringName] = []
	var rows: Array = []
	rows.append_array(base_rows)
	rows.append_array(rare_rows)
	for i in rows.size():
		var row_v: Variant = rows[i]
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		if node_tier < int(row.get("skill", 0)):
			continue
		var item_id := StringName(str(row.get("id", "")))
		var item_def := Data.item(item_id)
		if item_def == null:
			continue
		if no_meat and item_def.has_category(&"meat"):
			continue
		if gates.has(str(item_id)) and tier_idx < ProgressionScaling.tier_index(StringName(str(gates[str(item_id)]))):
			continue
		var is_rare := i >= base_rows.size()
		if is_rare:
			var c := scaled_chance(float(row.get("chance", cfg.get("default_rare_chance", 0.12))), tier_idx, skill,
					float(cfg.get("rare_tool_tier_bonus", 0.0)), float(cfg.get("rare_skill_bonus_per_level", 0.0)),
					float(cfg.get("max_rare_chance", 0.6)))
			if rng.randf() >= c:
				continue
		var lo := int(row.get("min", 1))
		var n := rng.randi_range(lo, maxi(lo, int(row.get("max", lo))))
		if not is_rare:
			var scaled := float(n) * count_mult
			n = int(floor(scaled))
			if rng.randf() < scaled - floor(scaled):
				n += 1
		if n <= 0:
			continue
		var attrs: Dictionary = {}
		var raw_attrs: Variant = row.get("attributes", {})
		if raw_attrs is Dictionary:
			attrs = (raw_attrs as Dictionary).duplicate(true)
		# The carcass's level, not the catalogue base (an earned corpse keeps its quality).
		attrs["level"] = level
		stacks.append(ItemStack.make(item_id, n, attrs, level))
		if is_rare:
			rares.append(item_id)
	return {"stacks": stacks, "rares": rares}
