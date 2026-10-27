## The single authoritative owner/location reference for a persistent object.
##
## A lot has exactly one LocationRef at any time. The tagged union mirrors
## docs/specs/ARCHITECTURE.md: InventorySlot / EquipmentSocket / WorldPlacement /
## Transit / Prison / Consumed. M0 only exercises the InventorySlot case; the
## other tags exist so a later milestone does not have to invent a second field
## that would let a lot claim two owners.
##
## Immutable value object: build with a factory, never mutate in place.
class_name LocationRef
extends RefCounted

enum Kind {
	INVENTORY = 0,
	EQUIPMENT = 1,
	WORLD = 2,
	TRANSIT = 3,
	PRISON = 4,
	CONSUMED = 5,
}

var _kind: Kind
var _holder: EntityId  # null for CONSUMED


static func in_inventory(inventory_id: EntityId) -> LocationRef:
	return _make(Kind.INVENTORY, inventory_id)


static func in_equipment(socket_holder: EntityId) -> LocationRef:
	return _make(Kind.EQUIPMENT, socket_holder)


static func in_world(placement_id: EntityId) -> LocationRef:
	return _make(Kind.WORLD, placement_id)


static func in_transit(shipment_id: EntityId) -> LocationRef:
	return _make(Kind.TRANSIT, shipment_id)


static func in_prison(case_id: EntityId) -> LocationRef:
	return _make(Kind.PRISON, case_id)


static func consumed() -> LocationRef:
	var ref: LocationRef = LocationRef.new()
	ref._kind = Kind.CONSUMED
	ref._holder = null
	return ref


static func _make(kind: Kind, holder: EntityId) -> LocationRef:
	if holder == null:
		push_error("LocationRef: null holder for kind %d" % kind)
		return null
	var ref: LocationRef = LocationRef.new()
	ref._kind = kind
	ref._holder = holder
	return ref


func kind() -> Kind:
	return _kind


func holder() -> EntityId:
	return _holder


func is_consumed() -> bool:
	return _kind == Kind.CONSUMED


func equals(other: LocationRef) -> bool:
	if other == null:
		return false
	if _kind != other._kind:
		return false
	if _holder == null or other._holder == null:
		return _holder == null and other._holder == null
	return _holder.equals(other._holder)


func to_key() -> String:
	if _kind == Kind.CONSUMED:
		return "consumed"
	return "%d@%s" % [int(_kind), _holder.to_key()]


func _to_string() -> String:
	return to_key()
