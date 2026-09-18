class_name CreatureDef
extends Resource

@export var id: StringName = &""
@export var species: String = ""
@export var clade: String = ""
@export var period: String = ""
@export var real_length_m: float = 1.0
@export var height_meters: float = 1.0
@export var rig: StringName = &"biped"
@export var tier: int = 1
@export var climate: StringName = &""
@export var archetype: StringName = &""
@export var tameable: bool = false
@export var capture_tier: int = 1
@export var verb: String = ""
@export var status_applied: Array[StringName] = []
@export var hp: float = 100.0
@export var attack: float = 10.0
@export var defense: float = 10.0
@export var speed: float = 400.0
@export var bag_slots: int = 0
@export var tamed_role: Array[StringName] = []
@export var variants: Array[StringName] = []
@export var clips: Dictionary = {}
@export var pipeline: Dictionary = {}
@export var preferred_food: Array[StringName] = []
@export var accepted_food: Array[StringName] = []
@export var feeds_needed: float = 3.0
@export var tame_window_seconds: float = 45.0
@export var requires_pen: bool = false

## ASSUMPTION: Durango-scale speed 400–700 maps to metres per second as speed / 100.
var move_speed_mps: float:
	get:
		return speed / 100.0

static func from_dict(d: Dictionary, file_id: StringName) -> CreatureDef:
	var c := CreatureDef.new()
	c.id = file_id
	c.species = str(d.get("species", file_id))
	c.clade = str(d.get("clade", ""))
	c.period = str(d.get("period", ""))
	c.real_length_m = float(d.get("real_length_m", 1.0))
	c.height_meters = float(d.get("height_meters", 1.0))
	c.rig = StringName(str(d.get("rig", "biped")))
	c.tier = int(d.get("tier", 1))
	c.climate = StringName(str(d.get("climate", "")))
	c.archetype = StringName(str(d.get("archetype", "")))
	c.tameable = bool(d.get("tameable", false))
	c.capture_tier = int(d.get("capture_tier", 1))
	c.verb = str(d.get("verb", ""))
	c.status_applied = ItemDef._names(d.get("status_applied", []))
	var stats: Dictionary = d.get("stats", {})
	c.hp = float(stats.get("hp", 100.0))
	c.attack = float(stats.get("attack", 10.0))
	c.defense = float(stats.get("defense", 10.0))
	c.speed = float(stats.get("speed", 400.0))
	c.bag_slots = int(stats.get("bag_slots", 0))
	c.tamed_role = ItemDef._names(d.get("tamed_role", []))
	c.variants = ItemDef._names(d.get("variants", []))
	c.clips = d.get("clips", {})
	c.pipeline = d.get("pipeline", {})
	c._apply_taming(d)
	return c

func mapped_archetype() -> StringName:
	# ASSUMPTION: JSON uses pack_raptor / pack_flanker / apex_raptor; SCHEMA lists raptor_pack.
	match archetype:
		&"pack_raptor", &"pack_flanker", &"apex_raptor", &"raptor_pack":
			return &"raptor_pack"
		_:
			return archetype

func is_herbivore_diet() -> bool:
	# Keep in sync with game/data/creatures/ai.json herbivore archetypes.
	match archetype:
		&"pack_mule", &"spiked_tail", &"runner", &"antlered", &"club_tail", &"horned_charger", &"titan":
			return true
		_:
			return false

func _apply_taming(d: Dictionary) -> void:
	var raw: Variant = d.get("taming", {})
	var block: Dictionary = raw if raw is Dictionary else {}
	# ASSUMPTION: herbivores prefer berry/herb_leaf; carnivores prefer raw_meat (fish accepted);
	# animals with real_length_m > 5 need 6 feeds and pen-only completion.
	var herb := is_herbivore_diet()
	var big := real_length_m > 5.0
	if block.is_empty():
		if herb:
			preferred_food = [&"berry", &"herb_leaf"]
			accepted_food = [&"fibre_stalk"]
		else:
			preferred_food = [&"raw_meat"]
			accepted_food = [&"fish", &"raptor_meat"]
		feeds_needed = 6.0 if big else 3.0
		tame_window_seconds = 45.0
		requires_pen = big
		return
	preferred_food = ItemDef._names(block.get("preferred_food", []))
	accepted_food = ItemDef._names(block.get("accepted_food", []))
	feeds_needed = float(block.get("feeds_needed", 6.0 if big else 3.0))
	tame_window_seconds = float(block.get("window_seconds", 45.0))
	if block.has("requires_pen"):
		requires_pen = bool(block.get("requires_pen"))
	else:
		requires_pen = big
	if preferred_food.is_empty():
		preferred_food = [&"berry", &"herb_leaf"] if herb else [&"raw_meat"]
	if accepted_food.is_empty():
		accepted_food = [&"fibre_stalk"] if herb else [&"fish", &"raptor_meat"]
