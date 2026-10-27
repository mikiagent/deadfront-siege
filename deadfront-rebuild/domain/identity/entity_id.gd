## Stable, typed, non-recycled entity identifier.
##
## Format: "<kind>:<seq>" where <seq> is a monotonically increasing integer
## allocated by EntityStore. Sequence numbers are never reused, so an ID can
## never refer to a different entity later (only EntityStore.allocate creates
## them, and it only counts forward).
##
## Typed GDScript, no scene nodes.
class_name EntityId
extends RefCounted

const SEPARATOR := ":"

var _kind: StringName
var _seq: int


static func create(kind: StringName, seq: int) -> EntityId:
	# ASSUMPTION: sequence 0 is reserved; allocation starts at 1 so an empty or
	# default-typed ID is never a valid entity reference.
	if kind.is_empty() or seq <= 0:
		push_error("EntityId.create: invalid kind/seq (%s, %d)" % [kind, seq])
		return null
	var id: EntityId = EntityId.new()
	id._kind = kind
	id._seq = seq
	return id


func kind() -> StringName:
	return _kind


func seq() -> int:
	return _seq


func to_key() -> String:
	return "%s%s%d" % [String(_kind), SEPARATOR, _seq]


func equals(other: EntityId) -> bool:
	if other == null:
		return false
	return _kind == other._kind and _seq == other._seq


func duplicate_id() -> EntityId:
	return EntityId.create(_kind, _seq)


func _to_string() -> String:
	return to_key()
