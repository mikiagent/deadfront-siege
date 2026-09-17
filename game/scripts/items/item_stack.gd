class_name ItemStack
extends RefCounted
## One inventory occupant. Merges only when def, level, attributes and flags match (D7).

var def_id: StringName = &""
var count: int = 1
var level: int = 1
var process_count: int = 0
var attributes: Dictionary = {}
var flags: Array[StringName] = []

func duplicate_stack() -> ItemStack:
	var s := ItemStack.new()
	s.def_id = def_id
	s.count = count
	s.level = level
	s.process_count = process_count
	s.attributes = attributes.duplicate(true)
	s.flags = flags.duplicate()
	return s

func def() -> ItemDef:
	return Data.item(def_id)

func slot_span() -> int:
	var d := def()
	return d.slot_span if d else 1

func can_merge_with(other: ItemStack) -> bool:
	if other == null:
		return false
	if def_id != other.def_id:
		return false
	if level != other.level:
		return false
	if process_count != other.process_count:
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
	if not attributes.is_empty():
		lines.append("attr %s" % str(attributes))
	if not flags.is_empty():
		var flag_s: PackedStringArray = []
		for f in flags:
			flag_s.append(str(f))
		lines.append("flags %s" % ", ".join(flag_s))
	return "\n".join(lines)

static func make(id: StringName, amount: int = 1, attrs: Dictionary = {}, lvl: int = 1) -> ItemStack:
	var s := ItemStack.new()
	s.def_id = id
	s.count = amount
	s.level = lvl
	s.attributes = attrs.duplicate(true)
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
