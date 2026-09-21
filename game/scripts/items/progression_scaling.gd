class_name ProgressionScaling
extends RefCounted
## Shared progression math. Five zone levels should be a clear difficulty step without hard gates.

const LEVEL_STAT_RATE := 0.08
const LEVEL_GATHER_RATE := 0.10
const SKILL_RATE := 0.025
const ZONE_MISMATCH_RATE := 0.12
const TOOL_TIERS: Array[StringName] = [&"stone", &"bone", &"flint", &"obsidian", &"copper", &"bronze", &"iron", &"steel"]
const TIER_POWER: Array[float] = [1.0, 1.12, 1.25, 1.42, 1.62, 1.85, 2.12, 2.45]

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
	if int(attrs.get("hardness", 0)) == 2:
		return &"bone"
	return &"stone"

static func tool_power(tool_level: int, tier: StringName) -> float:
	return level_multiplier(tool_level, LEVEL_GATHER_RATE) * tier_multiplier(tier)

static func specialist_multiplier(skill_level: int) -> float:
	return level_multiplier(skill_level, SKILL_RATE)

static func zone_pressure(zone_level: int, skill_level: int) -> float:
	return 1.0 + float(maxi(0, zone_level - maxi(1, skill_level))) * ZONE_MISMATCH_RATE

static func gather_seconds(base_seconds: float, zone_level: int, tool_level: int, tier: StringName, skill_level: int) -> float:
	var effort := zone_pressure(zone_level, skill_level)
	var ability := tool_power(tool_level, tier) * specialist_multiplier(skill_level)
	return maxf(0.25, base_seconds * effort / maxf(0.1, ability))

static func gather_yield_multiplier(zone_level: int, tool_level: int, tier: StringName, skill_level: int) -> float:
	var ability := tool_power(tool_level, tier) * specialist_multiplier(skill_level)
	return clampf(ability / zone_pressure(zone_level, skill_level), 1.0, 4.0)
