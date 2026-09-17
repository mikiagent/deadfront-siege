class_name StatusDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
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
@export var evasion_add: float = 0.0
@export var weakness_rank: int = 1
@export var cleared_by: Array[StringName] = []
@export var fx: StringName = &"none"
@export var on_untreated_expire: StringName = &""
@export var on_untreated_chance: float = 0.0

static func from_dict(d: Dictionary) -> StatusDef:
	var s := StatusDef.new()
	s.id = StringName(str(d.get("id", "")))
	s.display_name = str(d.get("display_name", s.id))
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
	s.evasion_add = float(d.get("evasion_add", 0.0))
	s.weakness_rank = int(d.get("weakness_rank", 1))
	s.cleared_by = ItemDef._names(d.get("cleared_by", []))
	s.fx = StringName(str(d.get("fx", "none")))
	s.on_untreated_expire = StringName(str(d.get("on_untreated_expire", "")))
	s.on_untreated_chance = float(d.get("on_untreated_chance", 0.0))
	return s

func has_flag(flag: StringName) -> bool:
	return flag in flags
