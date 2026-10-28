class_name RollRules
extends RefCounted
## The survivor's Roll: how far it carries her, how long the opening window keeps hits off her,
## what it costs and how soon she may roll again. The numbers live only in
## data/combat_tuning.json "roll". PlayerSim (the live dash) and IntentHandlers (the server's
## act.roll op and its hit check) both time the window through invulnerable_at(), so the two
## paths cannot drift apart.
# ASSUMPTION: spec 07 §2 asks for a timed Roll with stamina/cooldown and "a small amount" of
# invulnerability but fixes no numbers; every value is ours and data-tunable.

const SECTION := "roll"

static func tune(key: String, fallback: float) -> float:
	return CombatTuning.num(SECTION, key, fallback)

static func seconds() -> float:
	return maxf(0.1, tune("seconds", 0.56))

## Seconds from the press during which a creature hit that would land is dodged.
static func iframes_s() -> float:
	return clampf(tune("iframes_s", 0.32), 0.0, seconds())

static func stamina() -> float:
	return maxf(0.0, tune("stamina", 12.0))

## Seconds after the dash ends before another roll is allowed.
static func cooldown_s() -> float:
	return maxf(0.0, tune("cooldown_s", 0.9))

## Seconds a press made while another roll is in flight waits for it.
static func buffer_s() -> float:
	return maxf(0.0, tune("buffer_s", 0.2))

static func defense_xp() -> int:
	return maxi(0, int(tune("defense_xp", 1)))

static func top_speed() -> float:
	return maxf(0.1, tune("speed_mps", 26.0))

static func end_speed_frac() -> float:
	return clampf(tune("end_speed_frac", 0.5), 0.0, 1.0)

## Front-loaded speed curve: top speed at the press, end_speed_frac of it as the dash ends.
static func speed_at(elapsed: float) -> float:
	var t := clampf(elapsed / seconds(), 0.0, 1.0)
	return top_speed() * lerpf(1.0, end_speed_frac(), t)

## Ground a roll covers on open ground: the integral of speed_at over its length.
static func distance() -> float:
	return top_speed() * seconds() * (1.0 + end_speed_frac()) * 0.5

## The one rule both paths call: a hit landing `elapsed` seconds after the roll began is dodged
## while that time is inside the opening window.
static func invulnerable_at(elapsed: float) -> bool:
	return elapsed >= 0.0 and elapsed < iframes_s()
