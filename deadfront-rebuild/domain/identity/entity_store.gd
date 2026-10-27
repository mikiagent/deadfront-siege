## Entity lookup plus the monotonic ID allocator.
##
## The store is the only place that mints IDs. Allocated sequence numbers are
## consumed even if the entity is never registered, which is what makes IDs
## non-recycled: a retired/consumed entity can never hand its ID to a new one.
##
## Domain logic lives here and in the inventory modules; nothing in this file
## touches a scene tree, Input, or rendering.
class_name EntityStore
extends RefCounted

var _next_seq: Dictionary = {}      # StringName -> int (last allocated seq)
var _entities: Dictionary = {}      # String (id key) -> Object
var _kinds: Dictionary = {}         # String (id key) -> StringName


func allocate(kind: StringName) -> EntityId:
	var next_seq: int = int(_next_seq.get(kind, 0)) + 1
	_next_seq[kind] = next_seq
	return EntityId.create(kind, next_seq)


## Registers an entity under an already allocated ID.
## Returns false (and changes nothing) if the ID is malformed or already taken.
func add(id: EntityId, entity: Object) -> bool:
	if id == null or entity == null:
		push_error("EntityStore.add: null id or entity")
		return false
	var key: String = id.to_key()
	if _entities.has(key):
		# Not an error to log: refusing a duplicate is a normal, tested outcome.
		return false
	if id.seq() > int(_next_seq.get(id.kind(), 0)):
		push_error("EntityStore.add: id %s was never allocated" % key)
		return false
	_entities[key] = entity
	_kinds[key] = id.kind()
	return true


func get_entity(id: EntityId) -> Object:
	if id == null:
		return null
	return _entities.get(id.to_key())


func has(id: EntityId) -> bool:
	if id == null:
		return false
	return _entities.has(id.to_key())


func size() -> int:
	return _entities.size()


## Sorted for deterministic iteration and serialization.
func ids_of_kind(kind: StringName) -> Array[String]:
	var out: Array[String] = []
	for key: String in _entities.keys():
		if _kinds[key] == kind:
			out.append(key)
	out.sort()
	return out


func all_keys() -> Array[String]:
	var out: Array[String] = []
	for key: String in _entities.keys():
		out.append(key)
	out.sort()
	return out


## Number of sequence values consumed for a kind; used by tests to prove
## allocation only moves forward.
func allocated_count(kind: StringName) -> int:
	return int(_next_seq.get(kind, 0))
