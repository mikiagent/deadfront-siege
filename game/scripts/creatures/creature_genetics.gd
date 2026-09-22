class_name CreatureGenetics
extends RefCounted
## Per-creature Pokemon-style potential. IVs are innate, level gains are random combat
## growth, and EVs are the late-game focusable layer. All three survive taming and saving.

const STATS: Array[StringName] = [
	&"health", &"melee_defense", &"ranged_defense", &"melee_attack",
	&"ranged_attack", &"accuracy", &"speed",
]
const IV_MAX := 31
const EV_MAX_PER_STAT := 100
const EV_TOTAL_MAX := 300

var ivs: Dictionary = {}
var evs: Dictionary = {}
var level_gains: Dictionary = {}

static func roll(rng: RandomNumberGenerator = null) -> CreatureGenetics:
	var out := CreatureGenetics.new()
	var roller := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		roller.randomize()
	for stat in STATS:
		out.ivs[stat] = roller.randi_range(0, IV_MAX)
		out.evs[stat] = 0
		out.level_gains[stat] = 0
	return out

static func neutral() -> CreatureGenetics:
	var out := CreatureGenetics.new()
	for stat in STATS:
		out.ivs[stat] = 16
		out.evs[stat] = 0
		out.level_gains[stat] = 0
	return out

func add_level(roller: RandomNumberGenerator = null) -> Dictionary:
	var rng := roller if roller != null else RandomNumberGenerator.new()
	if roller == null:
		rng.randomize()
	# Three random combat increases per level. A stat can be picked more than once.
	var gained: Dictionary = {}
	for _i in 3:
		var stat: StringName = STATS[rng.randi_range(0, STATS.size() - 1)]
		level_gains[stat] = int(level_gains.get(stat, 0)) + 1
		gained[stat] = int(gained.get(stat, 0)) + 1
	return gained

func train(stat: StringName, amount: int = 1) -> int:
	if stat not in STATS or amount <= 0:
		return 0
	var used := 0
	for value in evs.values():
		used += int(value)
	var room := mini(EV_MAX_PER_STAT - int(evs.get(stat, 0)), EV_TOTAL_MAX - used)
	var added := clampi(amount, 0, maxi(0, room))
	evs[stat] = int(evs.get(stat, 0)) + added
	return added

func multiplier(stat: StringName) -> float:
	# IV range is 85-115 % of species baseline. Growth is deliberately smaller:
	# +1 % per random level point and +0.2 % per focused EV.
	return (0.85 + 0.30 * float(int(ivs.get(stat, 16))) / float(IV_MAX)
		+ 0.01 * float(int(level_gains.get(stat, 0)))
		+ 0.002 * float(int(evs.get(stat, 0))))

func tier_for(stat: StringName) -> StringName:
	return tier_for_iv(int(ivs.get(stat, 16)))

func overall_tier() -> StringName:
	var total := 0
	for stat in STATS:
		total += int(ivs.get(stat, 16))
	return tier_for_iv(int(round(float(total) / float(STATS.size()))))

static func tier_for_iv(iv: int) -> StringName:
	# Every possible IV has a stable identifying label, from D- through S+.
	const LABELS: Array[StringName] = [
		&"D-", &"D", &"D+", &"C-", &"C", &"C+", &"B-", &"B",
		&"B+", &"A-", &"A", &"A+", &"S-", &"S", &"S+",
	]
	var idx := mini(LABELS.size() - 1, int(floor(float(clampi(iv, 0, IV_MAX)) * float(LABELS.size()) / float(IV_MAX + 1))))
	return LABELS[idx]

func to_dict() -> Dictionary:
	return {"ivs": _string_keys(ivs), "evs": _string_keys(evs), "level_gains": _string_keys(level_gains)}

static func from_dict(data: Dictionary) -> CreatureGenetics:
	var out := neutral()
	for stat in STATS:
		var key := str(stat)
		out.ivs[stat] = clampi(int(data.get("ivs", {}).get(key, out.ivs[stat])), 0, IV_MAX)
		out.evs[stat] = clampi(int(data.get("evs", {}).get(key, 0)), 0, EV_MAX_PER_STAT)
		out.level_gains[stat] = maxi(0, int(data.get("level_gains", {}).get(key, 0)))
	return out

static func _string_keys(source: Dictionary) -> Dictionary:
	var out := {}
	for stat in STATS:
		out[str(stat)] = int(source.get(stat, 0))
	return out
