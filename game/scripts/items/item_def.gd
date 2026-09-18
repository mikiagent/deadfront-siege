class_name ItemDef
extends Resource
## Catalog row for a stackable or unique item. Loaded from data/items.json.

@export var id: StringName = &""
@export var display_name: String = ""
@export var categories: Array[StringName] = []
@export var stack_max: int = 1
@export var tool_class: StringName = &"none"
@export var base_level: int = 1
@export var attack_rate: float = 0.0
@export var damage: float = 0.0
@export var damage_type: StringName = &""
@export var is_work_tool: bool = false
@export var armor_value: float = 0.0
@export var food_energy: float = 0.0
@export var capture_tier: int = 0
@export var slot_span: int = 1
@export var clears: Array[StringName] = []
@export var diet: StringName = &""
@export var max_durability: int = 0
@export var default_attributes: Dictionary = {}
@export var place_as: StringName = &""
@export var footprint: Vector2i = Vector2i.ONE
@export var stats_per_level: Dictionary = {}
@export var raw: bool = false
@export var poison_chance: float = 0.0
@export var tastes_bad_chance: float = 0.0
@export var food_buff: StringName = &""

static func from_dict(d: Dictionary) -> ItemDef:
	var def := ItemDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.display_name = str(d.get("display_name", def.id))
	def.categories = _names(d.get("categories", []))
	def.stack_max = int(d.get("stack_max", 1))
	def.tool_class = StringName(str(d.get("tool_class", "none")))
	def.base_level = int(d.get("base_level", 1))
	def.attack_rate = float(d.get("attack_rate", 0.0))
	def.damage = float(d.get("damage", 0.0))
	def.damage_type = StringName(str(d.get("damage_type", "")))
	def.is_work_tool = bool(d.get("is_work_tool", false))
	def.armor_value = float(d.get("armor_value", 0.0))
	def.food_energy = float(d.get("food_energy", 0.0))
	def.capture_tier = int(d.get("capture_tier", 0))
	def.slot_span = int(d.get("slot_span", 1))
	def.clears = _names(d.get("clears", []))
	def.diet = StringName(str(d.get("diet", "")))
	def.max_durability = int(d.get("max_durability", 0))
	var attrs: Variant = d.get("default_attributes", {})
	if attrs is Dictionary:
		def.default_attributes = (attrs as Dictionary).duplicate(true)
	def.place_as = StringName(str(d.get("place_as", "")))
	var fp: Variant = d.get("footprint", [])
	if fp is Array and (fp as Array).size() >= 2:
		def.footprint = Vector2i(maxi(1, int(fp[0])), maxi(1, int(fp[1])))
	var spl: Variant = d.get("stats_per_level", {})
	if spl is Dictionary:
		def.stats_per_level = (spl as Dictionary).duplicate(true)
	def.raw = bool(d.get("raw", false))
	def.poison_chance = float(d.get("poison_chance", 0.0))
	def.tastes_bad_chance = float(d.get("tastes_bad_chance", 0.0))
	def.food_buff = StringName(str(d.get("food_buff", "")))
	return def

static func _names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array:
		for v in raw:
			out.append(StringName(str(v)))
	return out

func has_category(cat: StringName) -> bool:
	return cat in categories

func damage_at(level: int) -> float:
	return _scaled(&"damage", damage, level)

func max_durability_at(level: int) -> int:
	return maxi(0, int(round(_scaled(&"max_durability", float(max_durability), level))))

func armor_value_at(level: int) -> float:
	return _scaled(&"armor_value", armor_value, level)

func food_energy_at(level: int) -> float:
	return _scaled(&"food_energy", food_energy, level)

func _scaled(stat: StringName, base: float, level: int) -> float:
	var factor := 0.0
	if stats_per_level.has(stat):
		factor = float(stats_per_level[stat])
	elif stats_per_level.has(str(stat)):
		factor = float(stats_per_level[str(stat)])
	return base * (1.0 + factor * float(maxi(0, level)))
