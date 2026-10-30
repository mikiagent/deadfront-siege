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

## HARVESTROLL: one gathered lot's own rolls (loot_tables.json "lot"): its level inside the node's band
## (max(1, S - width)..S, never above S) and one grey and maybe one gold trait from the item's category.
## Gathering and tool tier skew the level to the top of the band and raise the gold odds. Every pass
## calls this once with the caller's rng, so a seeded rng replays the same sequence.
## Returns {"level": int, trait_key: magnitude, ...}.
static func roll_lot(item: StringName, site_level: int, tool_tier: StringName, skill: int, rng: RandomNumberGenerator) -> Dictionary:
	var cfg := LootTables.lot_cfg()
	var tier_idx := ProgressionScaling.tier_index(tool_tier) if tool_tier != &"" else -1
	var skill_f := clampf(float(skill - 1) / 59.0, 0.0, 1.0)
	var tool_f := clampf(float(tier_idx) / float(ProgressionScaling.TOOL_TIERS.size() - 1), 0.0, 1.0)
	var gamma := float(cfg.get("gamma_novice", 1.0)) - float(cfg.get("gamma_skill_drop", 0.0)) * skill_f - float(cfg.get("gamma_tool_drop", 0.0)) * tool_f
	var hi := maxi(1, site_level)
	var lo := maxi(1, hi - int(cfg.get("width", 0)))
	var out := {"level": lo + mini(hi - lo, int(floor(float(hi - lo + 1) * pow(rng.randf(), maxf(0.1, gamma)))))}
	var def := Data.item(item)
	var rows: Dictionary = cfg.get("by_category", {})
	var row: Dictionary = {}
	if def:
		for c in def.categories:
			if rows.has(str(c)):
				row = rows[str(c)]
				break
	if row.is_empty():
		return out
	var mag := maxi(1, int(cfg.get("max_magnitude", 1)))
	var neg: Array = row.get("negative", [])
	if not neg.is_empty() and rng.randf() < float(cfg.get("negative_chance", 0.0)):
		out[str(neg[rng.randi() % neg.size()])] = 1 + rng.randi() % mag
	var pos: Array = row.get("positive", [])
	var pc := scaled_chance(float(cfg.get("positive_chance", 0.0)), tier_idx, skill, float(cfg.get("tool_tier_bonus", 0.0)),
			float(cfg.get("skill_bonus_per_level", 0.0)), float(cfg.get("max_positive_chance", 1.0)))
	if not pos.is_empty() and rng.randf() < pc:
		var g := str(pos[rng.randi() % pos.size()])
		var opp: Dictionary = cfg.get("opposites", {})
		# PERKCAP: never a trait and its opposite on one lot (Soft with Firm); the gold roll is lost.
		if not out.keys().any(func (k: Variant) -> bool: return str(opp.get(str(k), "")) == g):
			out[g] = 1 + rng.randi() % mag
	return out

## The green rare trait one gathered item rolls (world-design.md:55, PRD:541), or &"" for none.
## RAREATTR: the trait comes from the material's own list (spec 04:33, rare_trait.by_material), so a
## stone never rolls a timber trait; the shared six stay the fallback for an item with no list.
## ONEGATHER: tool_tier (&"" bare hands, stone the base) raises the odds by rare_trait.tool_tier_bonus per
## tier above stone, capped at max_chance; Gathering level never does (spec 12:42).
## `guaranteed` skips the chance (an alpha's parts always carry one).
static func roll_trait(rng: RandomNumberGenerator, material: StringName = &"", tool_tier: StringName = &"", guaranteed: bool = false) -> StringName:
	var cfg := LootTables.trait_cfg()
	var traits: Array = LootTables.material_traits(material) if material != &"" else (cfg.get("traits", []) as Array)
	if traits.is_empty() and guaranteed:
		traits = cfg.get("traits", []) as Array
	if traits.is_empty() or (not guaranteed and rng.randf() >= trait_chance(tool_tier)):
		return &""
	return StringName(str(traits[rng.randi() % traits.size()]))

## BAGUI: the tier (1-5, shown I-V) of a rare trait that just rolled. From I, each further step
## succeeds with rare_trait.tier_step, raised by the tool's tier above stone and by `skill` levels
## (loot_tables.json, ASSUMPTION values), so higher tiers are rarer and better tools shift the odds.
static func roll_tier(rng: RandomNumberGenerator, tool_tier: StringName = &"", skill: int = 0) -> int:
	var cfg := LootTables.trait_cfg()
	var tier_idx := ProgressionScaling.tier_index(tool_tier) if tool_tier != &"" else 0
	var step := clampf(float(cfg.get("tier_step", 0.35)) + float(cfg.get("tier_step_tool_bonus", 0.0)) * float(maxi(0, tier_idx))
			+ float(cfg.get("tier_step_skill_bonus", 0.0)) * float(maxi(0, skill)), 0.0, float(cfg.get("tier_step_max", 0.6)))
	var tier := 1
	while tier < 5 and rng.randf() < step:
		tier += 1
	return tier

## The green rare-trait odds per gathered unit with a tool of `tool_tier` (&"" = bare hands).
static func trait_chance(tool_tier: StringName = &"") -> float:
	var cfg := LootTables.trait_cfg()
	var base := float(cfg.get("chance", 0.0))
	var tier_idx := ProgressionScaling.tier_index(tool_tier) if tool_tier != &"" else -1
	return scaled_chance(base, tier_idx, 0, float(cfg.get("tool_tier_bonus", 0.0)), 0.0, maxf(base, float(cfg.get("max_chance", base))))

## BUTCHER (spec 12 §2): the odds one rare row of a chosen part hits on this cut. Same table as
## roll_carcass, so a rare part keeps the shipped odds; knife tier and skill still scale them.
static func part_rare_chance(row: Dictionary, knife_tier: StringName, skill: int) -> float:
	var cfg := LootTables.butcher_cfg()
	var tier_idx := ProgressionScaling.tier_index(knife_tier) if knife_tier != &"" else -1
	return scaled_chance(float(row.get("chance", cfg.get("default_rare_chance", 0.12))), tier_idx, skill,
			float(cfg.get("rare_tool_tier_bonus", 0.0)), float(cfg.get("rare_skill_bonus_per_level", 0.0)),
			float(cfg.get("max_rare_chance", 0.6)))

## BUTCHER (spec 12 §2): one chosen part's stack from its own row: always ONE instance (owner rule
## 2026-10-28, one per harvest: knife and Butchering change a cut's speed and quality, never the count),
## the node gate and the spoiled-meat rule. null when the row cannot yield (a locked node, an unknown item).
static func roll_part(row: Dictionary, level: int, _knife_tier: StringName, node_tier: int, _skill: int, no_meat: bool, _rng: RandomNumberGenerator) -> ItemStack:
	if node_tier < int(row.get("skill", 0)):
		return null
	var item_id := StringName(str(row.get("id", "")))
	var item_def := Data.item(item_id)
	if item_def == null:
		return null
	if no_meat and item_def.has_category(&"raw_meat"): # raw cuts only: an edible tendon (tagged meat) is a counter material and stays
		return null
	if not Data.butcher_row_open(str(item_id)):
		return null
	var attrs: Dictionary = {}
	var raw_attrs: Variant = row.get("attributes", {})
	if raw_attrs is Dictionary:
		attrs = (raw_attrs as Dictionary).duplicate(true)
	attrs["level"] = level  # the carcass's level, not the catalogue base
	return ItemStack.make(item_id, 1, attrs, level)

## ALPHATAG: one alpha-only pool's stacks (loot_tables.json "alpha", LootTables.alpha_pool). Each row
## drops between its own min and max, every unit ONE instance, at the carcass's level. A row naming an
## unknown item is skipped, as every other loot row is. Pure, so the server and tests can run it.
static func roll_alpha_pool(species: StringName, level: int, rng: RandomNumberGenerator) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for row_v in LootTables.alpha_pool(species):
		if not (row_v is Dictionary):
			continue
		var row := row_v as Dictionary
		var item_id := StringName(str(row.get("id", "")))
		if item_id == &"" or Data.item(item_id) == null:
			continue
		var lo := maxi(1, int(row.get("min", 1)))
		var hi := maxi(lo, int(row.get("max", lo)))
		for _i in rng.randi_range(lo, hi):
			out.append(ItemStack.make(item_id, 1, {"level": level}, level))
	return out

## Carcass loot from butchering.json base and rare rows (rare rows roll their "chance"). knife_tier &"" = no knife.
## node_tier is Data.butchering_level() (unlocked Butchering nodes gate skill rows);
## skill is the Butchering category level (scales the rare odds). Every part is ONE instance (owner rule
## 2026-10-28: one per harvest; knife and skill change speed and quality, never the count).
## Returns {"stacks": Array[ItemStack], "rares": Array[StringName]}.
## `rares_guaranteed` (an alpha's carcass) skips the rare rows' odds; their skill-node gates still apply.
static func roll_carcass(base_rows: Array, rare_rows: Array, level: int, knife_tier: StringName, node_tier: int, skill: int, no_meat: bool, rng: RandomNumberGenerator, rares_guaranteed: bool = false) -> Dictionary:
	var cfg := LootTables.butcher_cfg()
	var tier_idx := ProgressionScaling.tier_index(knife_tier) if knife_tier != &"" else -1
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
		if no_meat and item_def.has_category(&"raw_meat"):
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
		var attrs: Dictionary = {}
		var raw_attrs: Variant = row.get("attributes", {})
		if raw_attrs is Dictionary:
			attrs = (raw_attrs as Dictionary).duplicate(true)
		# The carcass's level, not the catalogue base (an earned corpse keeps its quality).
		attrs["level"] = level
		stacks.append(ItemStack.make(item_id, 1, attrs, level))
		if is_rare:
			rares.append(item_id)
	return {"stacks": stacks, "rares": rares}
