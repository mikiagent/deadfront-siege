class_name Progression
## Pace knobs from data/progression.json: one cost multiplier per XP track (player level, skill
## trees, pets, tribe members) and the skill research timing. Read statically so headless tests
## without autoloads see them too.

static var _d: Dictionary = {}

static func _data() -> Dictionary:
	if _d.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
		_d = parsed if parsed is Dictionary else {"_missing": true}
	return _d

## The XP-cost multiplier for `key` (e.g. "player_xp_cost_mult"); 1.0 when missing.
static func mult(key: String) -> float:
	var v: Variant = _data().get(key, 1.0)
	return float(v) if v is float or v is int else 1.0

## A sub-table of progression.json (e.g. "skill_research"); {} when missing.
static func section(key: String) -> Dictionary:
	var v: Variant = _data().get(key, {})
	return v if v is Dictionary else {}
