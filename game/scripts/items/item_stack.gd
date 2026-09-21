class_name ItemStack
extends RefCounted
## One inventory occupant. Merges only when def, level, attributes, flags and durability match (D7).

var def_id: StringName = &""
var count: int = 1
var level: int = 1
var process_count: int = 0
var attributes: Dictionary = {}
var flags: Array[StringName] = []
var durability: int = 0
var max_durability: int = 0

func duplicate_stack() -> ItemStack:
	var s := ItemStack.new()
	s.def_id = def_id
	s.count = count
	s.level = level
	s.process_count = process_count
	s.attributes = attributes.duplicate(true)
	s.flags = flags.duplicate()
	s.durability = durability
	s.max_durability = max_durability
	return s

func def() -> ItemDef:
	return Data.item(def_id)

func apply_level_stats() -> void:
	var d := def()
	if d == null:
		return
	if d.max_durability > 0:
		max_durability = d.max_durability_at(level)
		durability = max_durability

func scaled_damage() -> float:
	var d := def()
	return d.damage_at(level) if d else 0.0

func scaled_armor() -> float:
	var d := def()
	return d.armor_value_at(level) if d else 0.0

func scaled_food_energy() -> float:
	var d := def()
	return d.food_energy_at(level) if d else 0.0

func material_tier() -> StringName:
	return ProgressionScaling.material_tier(def_id, attributes)

func gather_power() -> float:
	return ProgressionScaling.tool_power(level, material_tier())

func slot_span() -> int:
	var d := def()
	return d.slot_span if d else 1

func is_locked() -> bool:
	return &"locked" in flags

func is_broken() -> bool:
	return max_durability > 0 and durability <= 0

func is_unstable() -> bool:
	return &"unstable" in flags

func set_flag(flag: StringName, on: bool) -> void:
	if on:
		if flag not in flags:
			flags.append(flag)
	else:
		flags.erase(flag)

func tint_color() -> Color:
	var t := str(attributes.get("tint", ""))
	if t.begins_with("#") and t.length() >= 7:
		return Color(t)
	return Color.WHITE

func wear(amount: int) -> bool:
	if max_durability <= 0:
		return true
	durability = maxi(0, durability - amount)
	return durability > 0

func can_merge_with(other: ItemStack) -> bool:
	if other == null:
		return false
	if def_id != other.def_id:
		return false
	if level != other.level:
		return false
	if process_count != other.process_count:
		return false
	if durability != other.durability or max_durability != other.max_durability:
		return false
	if not _attrs_equal(attributes, other.attributes):
		return false
	return _flags_equal(flags, other.flags)

func take_into(other: ItemStack) -> int:
	if not can_merge_with(other):
		return count
	var d := def()
	var cap: int = d.stack_max if d else 1
	var room: int = maxi(0, cap - other.count)
	var moved: int = mini(count, room)
	other.count += moved
	count -= moved
	return count

func tooltip() -> String:
	var d := def()
	var title := d.display_name if d else str(def_id)
	var lines: PackedStringArray = ["%s x%d" % [title, count], "lv %d  process %d" % [level, process_count]]
	if d and d.place_as != &"":
		lines.append("footprint %dx%d" % [d.footprint.x, d.footprint.y])
	if d and d.has_category(&"tool"):
		lines.append("%s tier · %.2fx gather power" % [str(material_tier()).capitalize(), gather_power()])
	if max_durability > 0:
		lines.append("dur %d/%d%s" % [durability, max_durability, " BROKEN" if is_broken() else ""])
	var dmg := scaled_damage()
	if dmg > 0.0:
		lines.append("dmg %.1f" % dmg)
	var armor := scaled_armor()
	if armor > 0.0:
		lines.append("armor %.1f" % armor)
	if Food.is_food(self):
		lines.append("energy %.1f" % Food.energy_restore(self))
		if Food.is_raw(self):
			lines.append("RAW")
		if Food.is_poisoned(self):
			lines.append("POISONED")
		var buffs := Food.buff_ids(self)
		if not buffs.is_empty():
			var bn: PackedStringArray = []
			for b in buffs:
				bn.append(str(b))
			lines.append("buffs %s" % ", ".join(bn))
	elif scaled_food_energy() != 0.0:
		lines.append("energy %.1f" % scaled_food_energy())
	if not attributes.is_empty():
		lines.append("attr %s" % str(attributes))
	if not flags.is_empty():
		var flag_s: PackedStringArray = []
		for f in flags:
			flag_s.append(str(f))
		lines.append("flags %s" % ", ".join(flag_s))
	return "\n".join(lines)

func to_dict() -> Dictionary:
	var flag_s: Array = []
	for f in flags:
		flag_s.append(str(f))
	return {
		"id": str(def_id),
		"count": count,
		"level": level,
		"process_count": process_count,
		"attributes": attributes.duplicate(true),
		"flags": flag_s,
		"durability": durability,
		"max_durability": max_durability,
	}

static func from_dict(d: Dictionary) -> ItemStack:
	var s := make(StringName(str(d.get("id", ""))), int(d.get("count", 1)), d.get("attributes", {}), int(d.get("level", 1)))
	s.process_count = int(d.get("process_count", 0))
	s.durability = int(d.get("durability", s.durability))
	s.max_durability = int(d.get("max_durability", s.max_durability))
	s.flags.clear()
	var raw: Variant = d.get("flags", [])
	if raw is Array:
		for f in raw:
			s.flags.append(StringName(str(f)))
	return s

static func make(id: StringName, amount: int = 1, attrs: Dictionary = {}, lvl: int = -1) -> ItemStack:
	var s := ItemStack.new()
	s.def_id = id
	s.count = amount
	# Negative means "use the catalog base level". An explicit level 1 must stay level 1;
	# the old lvl == 1 sentinel silently promoted starter-island resources to base levels.
	s.level = lvl
	var d := Data.item(id) if Data else null
	if d:
		s.attributes = d.default_attributes.duplicate(true)
		if lvl < 1:
			s.level = d.base_level
		s.apply_level_stats()
	for k in attrs:
		s.attributes[k] = attrs[k]
	return s

static func _attrs_equal(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if not b.has(k):
			return false
		if str(a[k]) != str(b[k]):
			return false
	return true

static func _flags_equal(a: Array[StringName], b: Array[StringName]) -> bool:
	if a.size() != b.size():
		return false
	var aa := a.duplicate()
	var bb := b.duplicate()
	aa.sort()
	bb.sort()
	for i in aa.size():
		if aa[i] != bb[i]:
			return false
	return true
