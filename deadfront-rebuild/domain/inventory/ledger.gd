## Holds every inventory and every material lot in one place, with a shared
## EntityStore for ID allocation/lookup. This is not a god-object: it owns
## collections and lookups only. Rules (what a valid transfer is, what a command
## may do) live in TransferPlanner and CommandBus.
class_name Ledger
extends RefCounted

var store: EntityStore
var _inventories: Dictionary = {}  # String key -> Inventory
var _lots: Dictionary = {}         # String key -> MaterialLot
var _actors: Dictionary = {}       # String key -> Actor


func _init() -> void:
	store = EntityStore.new()


func create_actor(label: String) -> Actor:
	var actor: Actor = Actor.create(store.allocate(&"actor"), label)
	_actors[actor.id.to_key()] = actor
	store.add(actor.id, actor)
	return actor


func get_actor(id: EntityId) -> Actor:
	if id == null:
		return null
	return _actors.get(id.to_key())


func create_inventory(label: String, capacity_units: int = -1, owner_id: EntityId = null) -> Inventory:
	var inv: Inventory = Inventory.create(store.allocate(&"inv"), label, capacity_units, owner_id)
	_inventories[inv.id.to_key()] = inv
	store.add(inv.id, inv)
	return inv


func add_lot(
	def_id: StringName,
	quantity: int,
	provenance: Dictionary,
	inventory_id: EntityId
) -> MaterialLot:
	var lot: MaterialLot = MaterialLot.create(
		store.allocate(&"lot"),
		def_id,
		quantity,
		provenance,
		LocationRef.in_inventory(inventory_id)
	)
	if lot == null:
		return null
	_lots[lot.id.to_key()] = lot
	store.add(lot.id, lot)
	return lot


## Allocates and registers a lot with an explicit location (used by splits).
func register_lot(
	def_id: StringName,
	quantity: int,
	provenance: Dictionary,
	location: LocationRef
) -> MaterialLot:
	if location == null:
		return null
	var lot: MaterialLot = MaterialLot.create(
		store.allocate(&"lot"), def_id, quantity, provenance, location
	)
	if lot == null:
		return null
	_lots[lot.id.to_key()] = lot
	store.add(lot.id, lot)
	return lot


func get_inventory(id: EntityId) -> Inventory:
	if id == null:
		return null
	return _inventories.get(id.to_key())


func get_lot(id: EntityId) -> MaterialLot:
	if id == null:
		return null
	return _lots.get(id.to_key())


func lots_of(inventory_id: EntityId) -> Array[MaterialLot]:
	var out: Array[MaterialLot] = []
	var inv_key: String = inventory_id.to_key() if inventory_id != null else ""
	var keys: Array = _lots.keys()
	keys.sort()
	for key: String in keys:
		var lot: MaterialLot = _lots[key]
		if not lot.location.is_consumed() and lot.location.holder() != null \
				and lot.location.holder().to_key() == inv_key:
			out.append(lot)
	return out


## Units held by an inventory, summed over the lots whose single location is it.
func used_units(inventory_id: EntityId) -> int:
	var total: int = 0
	for lot: MaterialLot in lots_of(inventory_id):
		total += lot.quantity
	return total


## Total quantity of one definition across every live lot.
func total_of(def_id: StringName) -> int:
	var total: int = 0
	for key: String in _lots.keys():
		var lot: MaterialLot = _lots[key]
		if lot.def_id == def_id:
			total += lot.quantity
	return total


func total_units() -> int:
	var total: int = 0
	for key: String in _lots.keys():
		total += (_lots[key] as MaterialLot).quantity
	return total


## Deterministic canonical dump for equality checks in tests.
func debug_state() -> Dictionary:
	var invs: Array = []
	var inv_keys: Array = _inventories.keys()
	inv_keys.sort()
	for key: String in inv_keys:
		var inv: Inventory = _inventories[key]
		invs.append({
			"id": inv.id.to_key(),
			"label": inv.label,
			"revision": inv.revision,
			"used_units": used_units(inv.id),
		})
	var lots: Array = []
	for lot: MaterialLot in lots_of_any():
		lots.append({
			"id": lot.id.to_key(),
			"def_id": String(lot.def_id),
			"quantity": lot.quantity,
			"location": lot.location.to_key(),
			"revision": lot.revision,
		})
	return {"inventories": invs, "lots": lots}


## Every live lot, in stable ID order (sorted numerically by kind then seq).
func lots_of_any() -> Array[MaterialLot]:
	var out: Array[MaterialLot] = []
	var keys: Array = _lots.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _lot_sort_key(a) < _lot_sort_key(b))
	for key: String in keys:
		out.append(_lots[key])
	return out


func _lot_sort_key(key: String) -> String:
	# Zero-padded so "lot:10" sorts after "lot:9".
	var parts: PackedStringArray = key.split(":")
	return "%s:%010d" % [parts[0], int(parts[1])]
