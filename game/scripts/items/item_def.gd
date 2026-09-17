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
@export var capture_tier: int = 0
@export var slot_span: int = 1
@export var clears: Array[StringName] = []
@export var diet: StringName = &""

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
	def.capture_tier = int(d.get("capture_tier", 0))
	def.slot_span = int(d.get("slot_span", 1))
	def.clears = _names(d.get("clears", []))
	def.diet = StringName(str(d.get("diet", "")))
	return def

static func _names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array:
		for v in raw:
			out.append(StringName(str(v)))
	return out

func has_category(cat: StringName) -> bool:
	return cat in categories
