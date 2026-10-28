class_name TamingOdds
extends RefCounted
## Taming odds: one S-curve on (survival level - creature level) with a bonus for lower remaining
## health and a small bonus per net tier, clamped. The plate SHOWS odds_for() and CaptureSystem.attempt
## ROLLS odds_for(); the shown number is the rolled number. Roadmap: docs/design/durango-informed-
## improvements.md 5 ("Success = S-curve on (Survival level - creature level), times a bonus for lower
## remaining health. Starting point: 50% at an even level gap, 85% when 10 levels ahead, 10% when 10
## levels behind"). Numbers live in data/taming_odds.json; nothing here is a balance decision.
##
## The curve works in LOG-ODDS: the level gap reproduces the doc's anchors exactly at the capture
## threshold, and health / net tier shift that logit up or down, so the whole thing stays one logistic.

const PATH := "res://data/taming_odds.json"
## ASSUMPTION: an unreadable data file must not make the net unrollable; same numbers as the JSON.
const FALLBACK := {
	"capture_health_frac": 0.30,
	"level_even": 0.50,
	"level_ahead_10": 0.85,
	"level_behind_10": 0.10,
	"hp_logit_per_hp": 1.5,
	"tier_logit_per_tier": 0.25,
	"min": 0.05,
	"max": 0.95,
	"bait_iv_bonus": 6,
}
static var _knobs: Dictionary = {}

static func knobs() -> Dictionary:
	if _knobs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_knobs = parsed if parsed is Dictionary else FALLBACK.duplicate()
		for k in FALLBACK:
			if not _knobs.has(k):
				_knobs[k] = FALLBACK[k]
	return _knobs

static func min_odds() -> float:
	return float(knobs()["min"])

static func max_odds() -> float:
	return float(knobs()["max"])

## The capture-open threshold the health half is measured against. READ from FieldTame, never
## re-defined here: the copy in data/taming_odds.json is only a sanity check (the test compares them).
static func capture_frac() -> float:
	return FieldTame.CAPTURE_HEALTH_FRAC

static func logit(p: float) -> float:
	var q := clampf(p, 0.001, 0.999)
	return log(q / (1.0 - q))

static func logistic(z: float) -> float:
	return 1.0 / (1.0 + exp(-clampf(z, -30.0, 30.0)))

## The level-gap slope on each side of an even gap. The doc's anchors are not symmetric in log-odds
## (85 % at +10 is +1.73, 10 % at -10 is -2.20), so each side gets its own slope and the curve passes
## through all three anchors.
static func _k_ahead() -> float:
	return logit(float(knobs()["level_ahead_10"])) / 10.0

static func _k_behind() -> float:
	return -logit(float(knobs()["level_behind_10"])) / 10.0  # positive: z = -k_behind * |gap|

## The level gap alone (survival level - creature level) in log-odds; gap 0 is the doc's even 50 %.
static func level_z(gap: float) -> float:
	if gap >= 0.0:
		return _k_ahead() * gap
	return -_k_behind() * -gap

## The level half of the curve on its own, 0..1: the doc's anchors are read here.
static func level_odds(gap: float) -> float:
	return logistic(level_z(gap))

## Remaining health in log-odds: 0 at the capture threshold (so the level anchors hold there) and
## positive below it (weakening further keeps paying), negative above it.
static func health_z(hp_frac: float) -> float:
	var hp := clampf(hp_frac, 0.02, 1.0)  # a dead animal has no odds; floored, never infinite
	return float(knobs()["hp_logit_per_hp"]) * (capture_frac() - hp)

## A better net helps: one step per tier above the first.
static func tier_z(net_tier: int) -> float:
	return float(knobs()["tier_logit_per_tier"]) * float(maxi(0, net_tier - 1))

## The survivor's Survival level (the taming level). 0 with no survivor: an even-gap baseline.
static func taming_level(player) -> int:
	if player == null:
		return 0
	var sk = player.get("skills")
	if sk == null or not sk.has_method("level_of"):
		return 0
	return int(sk.level_of("survival"))

## The one curve. `target` is a Creature (anything with `level` and `health.fraction()`); `player` may
## be null (server callers, labs); `net_tier` 1 when the caller has no net.
static func odds_for(target, player = null, net_tier: int = 1) -> float:
	if target == null:
		return 0.0
	var health = target.get("health")
	if health == null:
		return 0.0
	return odds_for_values(int(target.get("level")), health.fraction(), taming_level(player), net_tier)

## The same curve for callers holding numbers instead of nodes (server intents, labs).
static func odds_for_values(creature_level: int, hp_frac: float, level: int, net_tier: int = 1) -> float:
	return clampf(raw_odds(creature_level, hp_frac, level, net_tier), min_odds(), max_odds())

## The raw (unclamped) probability, for tests and tuning readouts.
static func raw_odds(creature_level: int, hp_frac: float, level: int, net_tier: int = 1) -> float:
	return logistic(level_z(float(level - creature_level)) + health_z(hp_frac) + tier_z(net_tier))

## One roll at `p`. A seeded RandomNumberGenerator makes the same inputs repeat (tests, replays);
## with none the global generator is used, as before.
static func succeeds(p: float, rng: RandomNumberGenerator = null) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	if rng == null:
		return randf() < p
	return rng.randf() < p

## IV points a consumed bait adds to every stat of the tamed pet (data; 0 turns preparation off).
static func prep_iv_bonus() -> int:
	return int(knobs()["bait_iv_bonus"])

## The plate's caption: "Tame 64%".
static func caption(odds: float) -> String:
	return "Tame %d%%" % roundi(clampf(odds, 0.0, 1.0) * 100.0)
