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
static func roll_gather_rares(family: String, role: String, climate: String, tool_tier: StringName, skill: int, rng: RandomNumberGenerator) -> Array[StringName]:
	var cfg := LootTables.gather_cfg()
	var tier_idx := ProgressionScaling.tier_index(tool_tier) if tool_tier != &"" else -1
	var out: Array[StringName] = []
	# A find is another material, never more of what the node yields itself (a "RARE Herb Leaf" off a herb).
	var own: Dictionary = Data.nature_families.get(family, {}).get("harvest", {})
	for row_v in LootTables.gather_rare_rows(family, role):
		# Typo or hostile data skips the row instead of aborting the gather (as roll_carcass does).
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		var climates: Variant = row.get("climates", [])
		# A climate's own materials only (world-design s4): no flint or copper off the home grassland.
		if not (climates is Array) or not (climate in (climates as Array)) or own.has(str(row.get("item", ""))):
			continue
		var need := StringName(str(row.get("min_tool_tier", "")))
		# An unknown tier name (a typo) skips the row: tier_index would read it as stone.
		if need != &"" and (tier_idx < 0 or need not in ProgressionScaling.TOOL_TIERS or tier_idx < ProgressionScaling.tier_index(need)):
			continue
		var c := scaled_chance(float(row.get("chance", 0.0)), tier_idx, skill,
				float(cfg.get("tool_tier_bonus", 0.0)), float(cfg.get("skill_bonus_per_level", 0.0)),
				float(cfg.get("max_chance", 0.5)))
		if rng.randf() < c:
			out.append(StringName(str(row.get("item", ""))))
	return out

## The green rare trait one gathered item rolls (world-design.md:55, PRD:541), or &"" for none.
## RAREATTR: the trait comes from the material's own list (spec 04:33, rare_trait.by_material), so a
## stone never rolls a timber trait; the shared six stay the fallback for an item with no list.
## `guaranteed` skips the chance (an alpha's parts always carry one).
static func roll_trait(rng: RandomNumberGenerator, material: StringName = &"", guaranteed: bool = false) -> StringName:
	var cfg := LootTables.trait_cfg()
	var traits: Array = LootTables.material_traits(material) if material != &"" else (cfg.get("traits", []) as Array)
	if traits.is_empty() and guaranteed:
		traits = cfg.get("traits", []) as Array
	if traits.is_empty() or (not guaranteed and rng.randf() >= float(cfg.get("chance", 0.0))):
		return &""
	return StringName(str(traits[rng.randi() % traits.size()]))

## BUTCHER (spec 12 §2): the odds one rare row of a chosen part hits on this cut. Same table as
## roll_carcass, so a rare part keeps the shipped odds; knife tier and skill still scale them.
static func part_rare_chance(row: Dictionary, knife_tier: StringName, skill: int) -> float:
	var cfg := LootTables.butcher_cfg()
	var tier_idx := ProgressionScaling.tier_index(knife_tier) if knife_tier != &"" else -1
	return scaled_chance(float(row.get("chance", cfg.get("default_rare_chance", 0.12))), tier_idx, skill,
			float(cfg.get("rare_tool_tier_bonus", 0.0)), float(cfg.get("rare_skill_bonus_per_level", 0.0)),
			float(cfg.get("max_rare_chance", 0.6)))

## BUTCHER (spec 12 §2): one chosen part's stack from its own row, with the shipped count scaling
## (knife tier and Butchering level raise the yield, bare hands cut less), the node gate and the
## spoiled-meat rule. null when the row cannot yield (a locked node, a tiny roll, an unknown item).
static func roll_part(row: Dictionary, level: int, knife_tier: StringName, node_tier: int, skill: int, no_meat: bool, rng: RandomNumberGenerator) -> ItemStack:
	var cfg := LootTables.butcher_cfg()
	if node_tier < int(row.get("skill", 0)):
		return null
	var item_id := StringName(str(row.get("id", "")))
	var item_def := Data.item(item_id)
	if item_def == null:
		return null
	if no_meat and item_def.has_category(&"meat"):
		return null
	if not Data.butcher_row_open(str(item_id)):
		return null
	var tier_idx := ProgressionScaling.tier_index(knife_tier) if knife_tier != &"" else -1
	var count_mult := 1.0 + float(cfg.get("count_bonus_per_tier", 0.0)) * float(maxi(0, tier_idx)) \
			+ float(cfg.get("count_bonus_per_skill_level", 0.0)) * float(maxi(0, skill))
	if tier_idx < 0:
		count_mult *= float(cfg.get("no_knife_count_mult", 1.0))
	var lo := int(row.get("min", 1))
	var n := rng.randi_range(lo, maxi(lo, int(row.get("max", lo))))
	var scaled := float(n) * count_mult
	n = int(floor(scaled))
	if rng.randf() < scaled - floor(scaled):
		n += 1
	# ASSUMPTION (kept from roll_carcass): a chosen base part always cuts at least one unit, however
	# bare the hands; the row's own max is the ceiling of what that part is.
	n = maxi(1, n)
	var attrs: Dictionary = {}
	var raw_attrs: Variant = row.get("attributes", {})
	if raw_attrs is Dictionary:
		attrs = (raw_attrs as Dictionary).duplicate(true)
	attrs["level"] = level  # the carcass's level, not the catalogue base
	return ItemStack.make(item_id, n, attrs, level)

## Carcass loot from butchering.json base and rare rows (rare rows roll their "chance"). knife_tier &"" = no knife.
## node_tier is Data.butchering_level() (unlocked Butchering nodes gate skill rows);
## skill is the Butchering category level (scales counts and rare odds).
## Returns {"stacks": Array[ItemStack], "rares": Array[StringName]}.
## `rares_guaranteed` (an alpha's carcass) skips the rare rows' odds; their skill-node gates still apply.
static func roll_carcass(base_rows: Array, rare_rows: Array, level: int, knife_tier: StringName, node_tier: int, skill: int, no_meat: bool, rng: RandomNumberGenerator, rares_guaranteed: bool = false) -> Dictionary:
	var cfg := LootTables.butcher_cfg()
	var tier_idx := ProgressionScaling.tier_index(knife_tier) if knife_tier != &"" else -1
	var count_mult := 1.0 + float(cfg.get("count_bonus_per_tier", 0.0)) * float(maxi(0, tier_idx)) \
			+ float(cfg.get("count_bonus_per_skill_level", 0.0)) * float(maxi(0, skill))
	if tier_idx < 0:
		count_mult *= float(cfg.get("no_knife_count_mult", 1.0))  # bare hands cut less than any knife
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
		# A Butchering skill node that opens this part (Organs, Scutes, Bone II...): the row waits until it is learned.
		if not Data.butcher_row_open(str(item_id)):
			continue
		var is_rare := i >= base_rows.size()
		if is_rare:
			var c := scaled_chance(float(row.get("chance", cfg.get("default_rare_chance", 0.12))), tier_idx, skill,
					float(cfg.get("rare_tool_tier_bonus", 0.0)), float(cfg.get("rare_skill_bonus_per_level", 0.0)),
					float(cfg.get("max_rare_chance", 0.6)))
			if not rares_guaranteed and rng.randf() >= c:
				continue
		var lo := int(row.get("min", 1))
		var n := rng.randi_range(lo, maxi(lo, int(row.get("max", lo))))
		if not is_rare:
			var scaled := float(n) * count_mult
			n = int(floor(scaled))
			if rng.randf() < scaled - floor(scaled):
				n += 1
			# ASSUMPTION: a base part still falls on every kill (canon's guarantee, e.g. the poisoned raptor's
			# bone and tendon); the no-knife cut can shrink a count but never to nothing.
			n = maxi(1, n)
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
