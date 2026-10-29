class_name CombatTuning
extends RefCounted
## data/combat_tuning.json plus the one RNG every combat roll uses (seedable for tests, and
## the server's own RNG once combat runs there).

const PATH := "res://data/combat_tuning.json"

static var rng := RandomNumberGenerator.new()
## Test hooks: >= 0 replaces the rolled chance (forced dodge 1.0, forced miss 0.0).
static var force_dodge: float = -1.0
static var force_accuracy: float = -1.0
static var _data: Dictionary = {}

static func section(name: String) -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"_load_failed": true}
		if not parsed is Dictionary:
			push_error("[combat] %s did not parse" % PATH)
	var v: Variant = _data.get(name, {})
	return v if v is Dictionary else {}

static func num(sect: String, key: String, fallback: float) -> float:
	return float(section(sect).get(key, fallback))

static func top(key: String, fallback: float) -> float:
	section("")
	return float(_data.get(key, fallback))

static func roll(chance: float) -> bool:
	return rng.randf() < chance

## Chance that a swing from an attacker with this accuracy lands on a target with this dodge.
static func hit_chance(accuracy: float, dodge: float) -> float:
	var acc := force_accuracy if force_accuracy >= 0.0 else accuracy
	var dg := force_dodge if force_dodge >= 0.0 else dodge
	return clampf(acc, 0.0, 1.0) * (1.0 - clampf(dg, 0.0, 1.0))

## One swing roll with the same odds and the same single draw as roll(hit_chance(...)), telling a miss
## from a dodge for the floating text: &"" hit, &"dodge" (the defender's dodge took it), &"miss" (the
## attacker's own accuracy failed).
static func swing_outcome(accuracy: float, dodge: float) -> StringName:
	var acc := clampf(force_accuracy if force_accuracy >= 0.0 else accuracy, 0.0, 1.0)
	var r := rng.randf()
	if r < hit_chance(accuracy, dodge):
		return &""
	return &"dodge" if r < acc else &"miss"

static func reset_overrides() -> void:
	force_dodge = -1.0
	force_accuracy = -1.0
