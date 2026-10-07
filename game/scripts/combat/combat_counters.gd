class_name CombatCounters
extends RefCounted
## One creature-only type chart. Player injury statuses retain their own fixed damage.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_counters.json"))
		if parsed is Dictionary: _data = parsed
	return _data

static func channel(token: StringName) -> String:
	return "cut" if token == &"slashing" else str(token)

static func family(archetype: StringName) -> String:
	return str(data().get("archetype_family", {}).get(str(archetype), "neutral"))

static func multiplier(archetype: StringName, token: StringName) -> float:
	var row: Dictionary = data().get("families", {}).get(family(archetype), {})
	return float(row.get(channel(token), 1.0))

static func dot_fraction(archetype: StringName, status_id: StringName) -> float:
	var row: Dictionary = data().get("creature_dot", {}).get(str(status_id), {})
	if row.is_empty(): return 0.0
	return float(row.get("fraction_per_second", 0.0)) * multiplier(archetype, StringName(str(row.get("channel", ""))))

static func dot_duration(status_id: StringName, fallback: float) -> float:
	return float(data().get("creature_dot", {}).get(str(status_id), {}).get("duration", fallback))

static func dot_dps(archetype: StringName, status_id: StringName, max_health: float, stacks: int = 1) -> float:
	var row: Dictionary = data().get("creature_dot", {}).get(str(status_id), {})
	if row.is_empty(): return 0.0
	var n := clampi(stacks, 1, int(row.get("max_stacks", 1)))
	# Bleed is fixed damage with escalating stacks, never a health percentage.
	var fixed := float(row.get("fixed_dps", 0.0)) * n * (n + 1) * 0.5
	var percent := float(row.get("fraction_per_second", 0.0)) * max_health
	return (fixed + percent) * multiplier(archetype, StringName(str(row.get("channel", ""))))

static func max_stacks(status_id: StringName, fallback: int) -> int:
	return int(data().get("creature_dot", {}).get(str(status_id), {}).get("max_stacks", fallback))
