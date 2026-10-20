class_name PetStats
extends RefCounted
## The one pet stat formula (tames, saves, and later the server and the market validator):
##   stat = species base x IV quality x (1 + level growth + level-up points + trained EVs)
## Growth terms add; nothing compounds per level (the old x1.08 per level gave x93.8 HP at Lv60).

const MAX_LEVEL := 60
## Fraction of the species base gained per level above 1. Accuracy and speed only move with
## level-up points and EVs. ASSUMPTION: tuned so that with perfect genetics (IV 31, every level
## point and 100 EVs in one stat) Lv60 HP <= 3.0x Lv1 and attack <= 2.5x, and the hardest-hitting
## tame (Tarbosaurus, 700 attack) stays under the wild Tyrannosaurus (1100). That last ceiling is
## why attack growth is small; HP carries most of the levelling.
const LEVEL_GROWTH := {
	&"health": 0.028,
	&"melee_defense": 0.006,
	&"ranged_defense": 0.006,
	&"melee_attack": 0.002,
	&"ranged_attack": 0.002,
	&"accuracy": 0.0,
	&"speed": 0.0,
}

static func base(def: CreatureDef, stat: StringName) -> float:
	match stat:
		&"health": return def.hp
		&"melee_defense", &"ranged_defense": return def.defense
		&"melee_attack", &"ranged_attack": return def.attack
		&"accuracy": return 100.0
		&"speed": return def.speed
	return 0.0

## `growth_factor` is PetGrowth.stat_factor(): maturity and imprint of a bred baby (1.0 for every adult tame).
static func value(def: CreatureDef, genetics: CreatureGenetics, level: int, stat: StringName, growth_factor: float = 1.0) -> float:
	var lv := clampi(level, 1, MAX_LEVEL)
	var grow := float(LEVEL_GROWTH.get(stat, 0.0)) * float(lv - 1) + genetics.growth(stat)
	return base(def, stat) * genetics.iv_multiplier(stat) * (1.0 + grow) * growth_factor

## {stat: value} for every CreatureGenetics stat.
static func compute(def: CreatureDef, genetics: CreatureGenetics, level: int, growth_factor: float = 1.0) -> Dictionary:
	var out := {}
	for stat in CreatureGenetics.STATS:
		out[stat] = value(def, genetics, level, stat, growth_factor)
	return out

## XP rate and hunger efficiency both follow the displayed grade (one grade, from genetics).
## ASSUMPTION: D grades share C's rate; the old table only had S/A/B/C.
static func grade_rate(grade: StringName) -> float:
	match str(grade).left(1):
		"S": return 1.3
		"A": return 1.1
		"B": return 1.0
	return 0.85
