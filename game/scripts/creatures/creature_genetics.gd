class_name CreatureGenetics
extends RefCounted
## Per-creature Pokemon-style potential. IVs are innate, level gains are random combat
## growth, and EVs are the late-game focusable layer. All three survive taming and saving.
## The individual's natural coloration (CreatureColoration) lives here too, next to the IVs, so
## it follows the same tame and save path.

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
## Natural colour variant of this individual. Never null after roll()/neutral()/from_dict() (a
## neutral profile is a no-op shift); a hand-built CreatureGenetics may leave it null, and
## PetRecord seeds it from the pet id on load.
var coloration: CreatureColoration
## GENETICS (owner 2026-10-28: "dinosaur size and color variation (heritable stats)"): body size, 1.0 =
## the species as authored. Rolled at spawn inside the species range (size_range_for), it scales the
## model, the collision capsule and, through size_factor(), the stats. Saved; an old save loads 1.0.
var size: float = 1.0
## ALPHAS (owner 2026-10-28): a rare, much bigger and stronger wild individual (make_alpha). Saved with
## the genes so a tame or a reload keeps it; an old save loads false.
var alpha: bool = false
## What a save may hold: anything outside is clamped (an alpha tops out at about 1.32).
const SIZE_LIMIT := Vector2(0.5, 1.6)
## ASSUMPTION: the size range when neither the species nor ai.json "genetics" gives one.
const DEFAULT_SIZE_RANGE := Vector2(0.85, 1.15)

## `coloration_block` is the species' `coloration` JSON block (CreatureDef.coloration). `colour_rng`
## rolls the colour profile separately from the stat IVs: a wild spawn seeds only the colours from
## its spawn point (so a reloaded animal looks the same), never its IVs, and a server op passes its
## own RNG for both.
static func roll(rng: RandomNumberGenerator = null, coloration_block: Dictionary = {}, colour_rng: RandomNumberGenerator = null) -> CreatureGenetics:
	var out := CreatureGenetics.new()
	var roller := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		roller.randomize()
	for stat in STATS:
		out.ivs[stat] = roller.randi_range(0, IV_MAX)
		out.evs[stat] = 0
		out.level_gains[stat] = 0
	out.coloration = CreatureColoration.roll(coloration_block, colour_rng if colour_rng != null else roller)
	return out

## The genome a fresh animal of this species is born with: IVs and colours as roll(), plus a body size
## inside the species' range. The size draws from `colour_rng` after the colours, so a spawn seeded off
## its spawn point keeps its size on a reload and the colour stream is unchanged.
static func for_species(def: CreatureDef, rng: RandomNumberGenerator = null, colour_rng: RandomNumberGenerator = null) -> CreatureGenetics:
	var out := roll(rng, def.coloration if def else {}, colour_rng)
	var r := size_range_for(def)
	# Snapped like to_dict, so a saved animal reloads with exactly the stats it had.
	out.size = snappedf(_roller(colour_rng if colour_rng != null else rng).randf_range(r.x, r.y), 0.0001)
	return out

static func _roller(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	if rng != null:
		return rng
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r

## ai.json through the Data autoload, looked up at run time: tests compile this class before the
## autoloads exist, so it must not name `Data` directly.
static func _ai() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var data: Node = tree.root.get_node_or_null("Data") if tree != null and tree.root != null else null
	var ai: Variant = data.get("creature_ai") if data != null else {}
	return ai if ai is Dictionary else {}

static func rules() -> Dictionary:
	var g: Variant = _ai().get("genetics", {})
	return g if g is Dictionary else {}

static func alpha_rules() -> Dictionary:
	var a: Variant = _ai().get("alpha", {})
	return a if a is Dictionary else {}

## [lo, hi] from a two-number array, else `fallback`.
static func _pair(v: Variant, fallback: Vector2) -> Vector2:
	if v is Array and (v as Array).size() >= 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int):
		return Vector2(minf(float(v[0]), float(v[1])), maxf(float(v[0]), float(v[1])))
	return fallback

## The species' size range: its JSON "genetics.size_range", else ai.json "genetics.size_range".
static func size_range_for(def: CreatureDef) -> Vector2:
	var base := _pair(rules().get("size_range"), DEFAULT_SIZE_RANGE)
	if def != null:
		base = _pair(def.genetics.get("size_range"), base)
	return Vector2(clampf(base.x, SIZE_LIMIT.x, SIZE_LIMIT.y), clampf(base.y, SIZE_LIMIT.x, SIZE_LIMIT.y))

## How size moves one stat: stat x (1 + k x (size - 1)), k from ai.json "genetics.size_stat_per"
## (bigger = more HP and damage, a bit slower). Stats it does not list are unchanged.
func size_factor(stat: StringName) -> float:
	var per: Variant = rules().get("size_stat_per", {})
	var k := float((per as Dictionary).get(str(stat), 0.0)) if per is Dictionary else 0.0
	return maxf(0.1, 1.0 + k * (size - 1.0))

## ALPHAS: turn this genome into an alpha's. Bigger than any normal roll (alpha.size_range), darker and
## richer colours inside the natural limits (CreatureColoration.alpha_tone). Stat buffs are not stored:
## Creature applies alpha.stats while the animal is wild.
func make_alpha(rng: RandomNumberGenerator = null) -> void:
	var a := alpha_rules()
	alpha = true
	var r := _pair(a.get("size_range"), Vector2(1.24, 1.32))
	size = snappedf(clampf(maxf(size, _roller(rng).randf_range(r.x, r.y)), SIZE_LIMIT.x, SIZE_LIMIT.y), 0.0001)
	if coloration == null:
		coloration = CreatureColoration.new()
	coloration.alpha_tone(float(a.get("val_mult", 0.78)), float(a.get("sat_mult", 1.2)), float(a.get("pattern_mult", 1.3)))

## ALPHAS: one roll per spawn group (a pack, or a lone animal). The index of the member that is the
## alpha, or -1. ASSUMPTION: at most one alpha per group, and it is the first member.
static func alpha_pick(group_size: int, rng: RandomNumberGenerator) -> int:
	if group_size <= 0:
		return -1
	var chance := clampf(float(alpha_rules().get("chance_per_group", 0.08)), 0.0, 1.0)
	return 0 if _roller(rng).randf() < chance else -1

## GENETICS: a child of `a` and `b`. Each gene lands between the two parents' values (a random blend),
## then moves by at most ai.json "genetics.mutation" for that gene; IVs stay 0..31, size inside
## SIZE_LIMIT, colours inside the natural limits. EVs and level gains are earned, never inherited, and
## alpha is not heritable (ASSUMPTION). Breeding itself is not built: this is the rule it will call.
static func inherit(a: CreatureGenetics, b: CreatureGenetics, rng: RandomNumberGenerator) -> CreatureGenetics:
	var r := _roller(rng)
	var m: Variant = rules().get("mutation", {})
	var mut: Dictionary = m if m is Dictionary else {}
	var out := neutral()
	var miv := int(mut.get("iv", 2))
	for stat in STATS:
		var lo := mini(int(a.ivs.get(stat, 16)), int(b.ivs.get(stat, 16)))
		var hi := maxi(int(a.ivs.get(stat, 16)), int(b.ivs.get(stat, 16)))
		out.ivs[stat] = clampi(r.randi_range(lo, hi) + r.randi_range(-miv, miv), 0, IV_MAX)
	out.size = snappedf(clampf(_blend(a.size, b.size, float(mut.get("size", 0.03)), r), SIZE_LIMIT.x, SIZE_LIMIT.y), 0.0001)
	var ca := a.coloration if a.coloration != null else CreatureColoration.new()
	var cb := b.coloration if b.coloration != null else CreatureColoration.new()
	out.coloration = CreatureColoration.blend(ca, cb, mut, r)
	return out

## A value between p and q, then moved by at most `mutation`.
static func _blend(p: float, q: float, mutation: float, r: RandomNumberGenerator) -> float:
	return lerpf(p, q, r.randf()) + r.randf_range(-absf(mutation), absf(mutation))

static func neutral() -> CreatureGenetics:
	var out := CreatureGenetics.new()
	for stat in STATS:
		out.ivs[stat] = 16
		out.evs[stat] = 0
		out.level_gains[stat] = 0
	out.coloration = CreatureColoration.new()
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
	return iv_multiplier(stat) * (1.0 + growth(stat)) * size_factor(stat)

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
	return {
		"ivs": _string_keys(ivs), "evs": _string_keys(evs), "level_gains": _string_keys(level_gains),
		"coloration": (coloration if coloration != null else CreatureColoration.new()).to_dict(),
		"size": snappedf(size, 0.0001), "alpha": alpha,
	}

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
	# GENETICS / ALPHAS: optional fields; a save from before them loads a 1.0x non-alpha.
	out.size = clampf(CreatureColoration._finite(data.get("size", 1.0), 1.0), SIZE_LIMIT.x, SIZE_LIMIT.y)
	out.alpha = data.get("alpha", false) is bool and data.get("alpha") == true
	# A save without a coloration (or with the sanitizer's empty shape sample) keeps it null, so
	# PetRecord can derive a stable one from the pet id instead of painting every old pet neutral.
	out.coloration = null # neutral() above carries a no-op profile; a saved one below replaces it
	if data.get("coloration") is Dictionary and not (data.get("coloration") as Dictionary).is_empty():
		out.coloration = CreatureColoration.from_dict(data.get("coloration"))
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
