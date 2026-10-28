class_name ItemDef
extends Resource
## Catalog row for an item. Loaded from data/items.json.

## Stacking categories and Pocket slots (spec 05), read once.
const RULES_PATH := "res://data/inventory.json"
static var _rules: Dictionary = {}

@export var id: StringName = &""
@export var display_name: String = ""
@export var categories: Array[StringName] = []
@export var stack_max: int = 1
## Units a saved row from before the no-stacking rule may hold (the save sanitizer's ceiling).
@export var legacy_stack_max: int = 1
## Bag slots this item adds while worn (spec 05:11 "equipment adds storage slots").
@export var bag_slots: int = 0
## Bag type id in data/bags.json (spec 31): its capacity curve and inheritable storage attributes.
## Empty for ordinary gear, whose bag_slots stays the whole storage rule.
@export var bag_def: StringName = &""
@export var tool_class: StringName = &"none"
@export var base_level: int = 1
@export var attack_rate: float = 0.0
@export var damage: float = 0.0
@export var range_m: float = 0.0
@export var ammo_id: StringName = &""
@export var bleed_every_hits: int = 0
@export var damage_type: StringName = &""
@export var is_work_tool: bool = false
@export var armor_value: float = 0.0
@export var health_bonus: float = 0.0
@export var food_energy: float = 0.0
@export var capture_tier: int = 0
@export var market_category: StringName = &""
@export var rarity: StringName = &"common"
@export var insulation: Dictionary = {} ## {"cold": points, "heat": points} against climate needs
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
## Survivor armor piece shown when equipped, "<kit>/<piece>" under assets/characters/survivor/armor.
@export var visual: String = ""

static func from_dict(d: Dictionary) -> ItemDef:
	var def := ItemDef.new()
	def.id = StringName(str(d.get("id", "")))
	def.display_name = str(d.get("display_name", def.id))
	def.categories = _names(d.get("categories", []))
	# Owner rule (2026-10-20, prompts 05/08): materials and food do not stack; each unit is its own
	# instance and slot. Only data/inventory.json's stacking_categories keep the data's stack_max.
	var stacks := false
	for cat: Variant in rules().get("stacking_categories", []):
		stacks = stacks or def.has_category(StringName(str(cat)))
	def.stack_max = maxi(1, int(d.get("stack_max", 1))) if stacks else 1
	# What one pre-W2-INV saved row could hold: the old rule (owner 2026-09-20) stacked everything to
	# 999 except durability tools and multi-slot animals, which kept the data value. load_array splits it.
	var old_data_cap := int(d.get("slot_span", 1)) > 1 or int(d.get("max_durability", 0)) > 0
	def.legacy_stack_max = maxi(1, int(d.get("stack_max", 1))) if old_data_cap else 999
	def.bag_slots = maxi(0, int(d.get("bag_slots", 0)))
	def.bag_def = StringName(str(d.get("bag_def", "")))
	def.tool_class = StringName(str(d.get("tool_class", "none")))
	def.base_level = int(d.get("base_level", 1))
	def.attack_rate = float(d.get("attack_rate", 0.0))
	def.damage = float(d.get("damage", 0.0))
	def.range_m = float(d.get("range_m", 0.0))
	def.ammo_id = StringName(str(d.get("ammo_id", "")))
	def.bleed_every_hits = int(d.get("bleed_every_hits", 0))
	def.damage_type = StringName(str(d.get("damage_type", "")))
	def.is_work_tool = bool(d.get("is_work_tool", false))
	def.armor_value = float(d.get("armor_value", 0.0))
	def.health_bonus = float(d.get("health_bonus", 0.0))
	def.food_energy = float(d.get("food_energy", 0.0))
	def.capture_tier = int(d.get("capture_tier", 0))
	def.market_category = StringName(str(d.get("market_category", "")))
	def.rarity = StringName(str(d.get("rarity", "common")))
	def.insulation = (d.get("insulation", {}) as Dictionary).duplicate()
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
	def.visual = str(d.get("visual", ""))
	return def

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		if not parsed is Dictionary:
			push_error("[items] %s is unreadable: nothing stacks" % RULES_PATH)
			parsed = {"stacking_categories": []}
		_rules = parsed
	return _rules

static func _names(raw: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if raw is Array:
		for v in raw:
			out.append(StringName(str(v)))
	return out

func has_category(cat: StringName) -> bool:
	return cat in categories

## Level scaling belongs to ItemStack (stat_multiplier). These two remain only because
## item_stack.gd still calls them; damage/armor/durability _at variants were dead and are gone.
func health_bonus_at(level: int) -> float:
	return _scaled(&"health_bonus", health_bonus, level)

func food_energy_at(level: int) -> float:
	return _scaled(&"food_energy", food_energy, level)

func _scaled(stat: StringName, base: float, level: int) -> float:
	var factor := 0.0
	if stats_per_level.has(stat):
		factor = float(stats_per_level[stat])
	elif stats_per_level.has(str(stat)):
		factor = float(stats_per_level[str(stat)])
	return base * (1.0 + factor * float(maxi(0, level)))
