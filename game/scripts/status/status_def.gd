class_name StatusDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## HUDRULES (owner 2026-10-28): "effect" = an affliction, shown only as a box beside the survivor
## (StatusFx); "buff" / "boon" / "debuff" = a timed modifier, shown only in the chip row under the vitals.
@export var kind: StringName = &"effect"
## One short factual line for the chip row's tooltip.
@export var desc: String = ""
@export var dps: float = 0.0
@export var dps_max_hp_frac: float = 0.0
@export var duration: float = 1.0
@export var max_stacks: int = 1
@export var flags: Array[StringName] = []
@export var move_mult: float = 1.0
@export var defense_mult: float = 1.0
@export var accuracy_mult: float = 1.0
@export var attack_mult: float = 1.0
@export var max_health_mult: float = 1.0
@export var fatigue_per_min: float = 0.0
## Multiplies every fatigue gain while active (PRD 6.4: Dirty 1.2, Clean 0.8); heat_ only heat fatigue.
@export var fatigue_mult: float = 1.0
@export var heat_fatigue_mult: float = 1.0
## WEATHER: Wet makes the cold bite harder (PRD :284) and resting recover slower.
@export var cold_fatigue_mult: float = 1.0
@export var rest_mult: float = 1.0
@export var evasion_add: float = 0.0
@export var weakness_rank: int = 1
@export var cleared_by: Array[StringName] = []
## The old body hint ("drip_darken", "limp"...): fx.body in statuses.json, or a bare string there.
@export var fx: StringName = &"none"
## STATUSFX: how the status shows on the survivor (StatusFx), all from its statuses.json fx block:
## the box tint, the white icon id in the box, the particle preset (drip, bubbles, embers, water, cough, tint, none)
## and whether its ticks pulse a red screen edge.
@export var fx_color: Color = Color(0.604, 0.651, 0.678)
@export var fx_icon: StringName = &""
@export var fx_particles: StringName = &"none"
@export var fx_vignette: bool = false
@export var on_untreated_expire: StringName = &""
@export var on_untreated_chance: float = 0.0
## Owner 2026-10-28 ("starving and poison cant directly kill you but they can get you to 1HP"): its damage
## over time stops at 1 Health on the survivor. Hits and lethal DoTs at 1 HP still kill.
@export var nonlethal: bool = false

static func from_dict(d: Dictionary) -> StatusDef:
	var s := StatusDef.new()
	s.id = StringName(str(d.get("id", "")))
	s.display_name = str(d.get("display_name", s.id))
	s.kind = StringName(str(d.get("kind", "effect")))
	s.desc = str(d.get("desc", ""))
	s.dps = float(d.get("dps", 0.0))
	s.dps_max_hp_frac = float(d.get("dps_max_hp_frac", 0.0))
	s.duration = float(d.get("duration", 1.0))
	s.max_stacks = int(d.get("max_stacks", 1))
	s.flags = ItemDef._names(d.get("flags", []))
	s.move_mult = float(d.get("move_mult", 1.0))
	s.defense_mult = float(d.get("defense_mult", 1.0))
	s.accuracy_mult = float(d.get("accuracy_mult", 1.0))
	s.attack_mult = float(d.get("attack_mult", 1.0))
	s.max_health_mult = float(d.get("max_health_mult", 1.0))
	s.fatigue_per_min = float(d.get("fatigue_per_min", 0.0))
	s.fatigue_mult = float(d.get("fatigue_mult", 1.0))
	s.heat_fatigue_mult = float(d.get("heat_fatigue_mult", 1.0))
	s.cold_fatigue_mult = float(d.get("cold_fatigue_mult", 1.0))
	s.rest_mult = float(d.get("rest_mult", 1.0))
	s.evasion_add = float(d.get("evasion_add", 0.0))
	s.weakness_rank = int(d.get("weakness_rank", 1))
	s.cleared_by = ItemDef._names(d.get("cleared_by", []))
	var fx: Variant = d.get("fx", "none")
	if fx is Dictionary:
		s.fx = StringName(str(fx.get("body", "none")))
		s.fx_color = Color.from_string(str(fx.get("color", "")), s.fx_color)
		s.fx_icon = StringName(str(fx.get("icon", "")))
		s.fx_particles = StringName(str(fx.get("particles", "none")))
		s.fx_vignette = bool(fx.get("vignette", false))
	else:
		s.fx = StringName(str(fx))
	if s.fx_icon == &"":
		s.fx_icon = s.id
	s.on_untreated_expire = StringName(str(d.get("on_untreated_expire", "")))
	s.on_untreated_chance = float(d.get("on_untreated_chance", 0.0))
	s.nonlethal = bool(d.get("nonlethal", false))
	return s

## True for a timed modifier (buff, boon, debuff) the chip row shows; false for an affliction.
func is_modifier() -> bool:
	return kind != &"effect"

func has_flag(flag: StringName) -> bool:
	return flag in flags
