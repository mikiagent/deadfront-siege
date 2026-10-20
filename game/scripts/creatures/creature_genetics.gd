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

## Growth per random level-up point and per trained EV, as a fraction of the species base.
## Small on purpose: PetStats adds these to per-level growth and the sum must keep a perfect
## Lv60 pet inside its tier (see PetStats).
const GAIN_STEP := 0.0008
const EV_STEP := 0.001

## Innate quality: 85-115 % of the species baseline.
func iv_multiplier(stat: StringName) -> float:
	return 0.85 + 0.30 * float(int(ivs.get(stat, 16))) / float(IV_MAX)

## Additive growth from level gains and EVs (0 for a wild animal).
func growth(stat: StringName) -> float:
	return GAIN_STEP * float(int(level_gains.get(stat, 0))) + EV_STEP * float(int(evs.get(stat, 0)))

## Level-1 stat factor; PetStats.compute(def, self, 1) == base * multiplier(stat).
func multiplier(stat: StringName) -> float:
	return iv_multiplier(stat) * (1.0 + growth(stat))

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
	# Each table is untrusted: a save holding "ivs": 5 or [] would raise on .get() and abort the load.
	var ivs_in := _table(data.get("ivs"))
	var evs_in := _table(data.get("evs"))
	var gains_in := _table(data.get("level_gains"))
	for stat in STATS:
		var key := str(stat)
		out.ivs[stat] = clampi(int(ivs_in.get(key, out.ivs[stat])), 0, IV_MAX)
		out.evs[stat] = clampi(int(evs_in.get(key, 0)), 0, EV_MAX_PER_STAT)
		out.level_gains[stat] = maxi(0, int(gains_in.get(key, 0)))
	_cap_total(out.evs, EV_TOTAL_MAX)
	return out

## A saved stat table, or {} when the row is any other type.
static func _table(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}

## Level gains can never exceed what levelling grants (3 per level-up); the owner clamps with
## its level since genetics alone do not know it.
func clamp_level_gains(level: int) -> void:
	_cap_total(level_gains, 3 * maxi(0, level - 1))

## Trims a stat->points table to `total` points, keeping stats in STATS order (stored data is
## not trusted: a hand-edited save could hold any number).
static func _cap_total(table: Dictionary, total: int) -> void:
	var room := total
	for stat in STATS:
		var v := mini(int(table.get(stat, 0)), room)
		table[stat] = v
		room -= v

static func _string_keys(source: Dictionary) -> Dictionary:
	var out := {}
	for stat in STATS:
		out[str(stat)] = int(source.get(stat, 0))
	return out
