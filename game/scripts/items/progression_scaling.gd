class_name ProgressionScaling
extends RefCounted
## Shared progression math. Five zone levels should be a clear difficulty step without hard gates.

const LEVEL_STAT_RATE := 0.08
const LEVEL_GATHER_RATE := 0.10
const SKILL_RATE := 0.025
const ZONE_MISMATCH_RATE := 0.12
const TOOL_TIERS: Array[StringName] = [&"stone", &"bone", &"flint", &"obsidian", &"copper", &"bronze", &"iron", &"steel"]
const TIER_POWER: Array[float] = [1.0, 1.12, 1.25, 1.42, 1.62, 1.85, 2.12, 2.45]
const HARDNESS_TIERS := {2: &"bone", 3: &"flint", 4: &"copper", 5: &"bronze", 6: &"iron", 7: &"steel"}

static func level_multiplier(level: int, rate: float = LEVEL_STAT_RATE) -> float:
	return 1.0 + float(maxi(0, level - 1)) * rate

static func tier_index(tier: StringName) -> int:
	var idx := TOOL_TIERS.find(tier)
	return maxi(0, idx)

static func tier_multiplier(tier: StringName) -> float:
	return TIER_POWER[tier_index(tier)]

static func material_tier(item_id: StringName, attrs: Dictionary = {}) -> StringName:
	var explicit := StringName(str(attrs.get("material_tier", "")))
	if explicit in TOOL_TIERS:
		return explicit
	var key := str(item_id).to_lower()
	for tier in TOOL_TIERS:
		if key.contains(str(tier)):
			return tier
	# ASSUMPTION: untagged materials map hardness onto the ladder the tagged ones already use
	# (copper_ingot 4, bronze 5, iron 6, steel 7), so metal shards and talons are not "stone".
	return StringName(HARDNESS_TIERS.get(int(attrs.get("hardness", 0)), &"stone"))

## Damage, armour and durability of a finished item: level and material tier both count.
static func stat_multiplier(level: int, tier: StringName) -> float:
	return level_multiplier(level, LEVEL_STAT_RATE) * tier_multiplier(tier)

static func tool_power(tool_level: int, tier: StringName) -> float:
	return level_multiplier(tool_level, LEVEL_GATHER_RATE) * tier_multiplier(tier)

static func specialist_multiplier(skill_level: int) -> float:
	return level_multiplier(skill_level, SKILL_RATE)

static func zone_pressure(zone_level: int, skill_level: int) -> float:
	return 1.0 + float(maxi(0, zone_level - maxi(1, skill_level))) * ZONE_MISMATCH_RATE

## Fatigue multiplier from the gap between the island's level and the survivor's level.
## Over-levelled islands tire you faster, under-levelled ones slower. Values in rules.json.
static func fatigue_level_factor(zone_level: int, character_level: int, cfg: Dictionary = {}) -> float:
	var gap := zone_level - maxi(1, character_level)
	var rate := float(cfg.get("gap_up_rate", 0.06)) if gap > 0 else float(cfg.get("gap_down_rate", 0.04))
	return clampf(1.0 + float(gap) * rate, float(cfg.get("gap_min", 0.5)), float(cfg.get("gap_max", 2.0)))

static func gather_seconds(base_seconds: float, zone_level: int, tool_level: int, tier: StringName, skill_level: int) -> float:
	var effort := zone_pressure(zone_level, skill_level)
	var ability := tool_power(tool_level, tier) * specialist_multiplier(skill_level)
	return maxf(0.25, base_seconds * effort / maxf(0.1, ability))

static func crafted_level(levels: Array[int], max_level: int = 60, skill_level: int = 60) -> int:
	if levels.is_empty():
		return 1
	var total := 0
	for level in levels:
		total += level
	var average := int(floor(float(total) / float(levels.size())))
	# PRD 8.4: clamped by the crafting skill. Skill 0 caps at 1 like skill 1 (no free 60).
	return clampi(average, 1, maxi(1, mini(max_level, skill_level)))

static func resolved_item_level(requested_level: int, catalog_level: int) -> int:
	return maxi(1, catalog_level) if requested_level < 1 else requested_level

static func resolved_spawn_level(species_tier: int, island: Dictionary, cap: int = 60) -> int:
	var override := int(island.get("level_override", 0))
	return clampi(override, 1, cap) if override > 0 else species_tier
