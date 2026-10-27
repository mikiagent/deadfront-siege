## Identity contract tests: typed, stable, non-recycled IDs with unique lookup.
extends RefCounted


func run(t: TestCase) -> void:
	t.suite("identity")
	_test_typed_and_unique(t)
	_test_never_recycled(t)
	_test_lookup(t)
	_test_allocation_order(t)


func _test_typed_and_unique(t: TestCase) -> void:
	var store: EntityStore = EntityStore.new()
	var seen: Dictionary = {}
	var kinds: Array[StringName] = [&"lot", &"inv", &"actor"]
	for kind: StringName in kinds:
		for i: int in 100:
			var id: EntityId = store.allocate(kind)
			t.ok(not seen.has(id.to_key()), "ID %s must be globally unique" % id.to_key())
			seen[id.to_key()] = true
			t.eq(String(id.kind()), String(kind), "ID keeps its kind prefix")
	t.eq(store.allocated_count(&"lot"), 100, "100 lot sequences consumed")
	t.eq(store.allocated_count(&"inv"), 100, "100 inv sequences consumed")


func _test_never_recycled(t: TestCase) -> void:
	var store: EntityStore = EntityStore.new()
	var a: EntityId = store.allocate(&"lot")
	# Allocating for another kind must not reuse lot:1.
	var b: EntityId = store.allocate(&"inv")
	t.ok(not a.equals(b), "different kinds never share a key")
	# Consuming/forgetting an entity must not free its sequence.
	var lot_a: MaterialLot = MaterialLot.create(a, &"fiber", 5, {}, LocationRef.in_inventory(b))
	store.add(a, lot_a)
	var c: EntityId = store.allocate(&"lot")
	t.eq(c.seq(), 2, "lot allocation continues past a live lot")
	t.ok(not c.equals(a), "new lot ID differs from the earlier lot")


func _test_lookup(t: TestCase) -> void:
	var store: EntityStore = EntityStore.new()
	var id: EntityId = store.allocate(&"lot")
	var lot: MaterialLot = MaterialLot.create(id, &"stone", 3, {"origin": "fixture"}, LocationRef.in_inventory(store.allocate(&"inv")))
	t.ok(store.add(id, lot), "first registration succeeds")
	t.ok(store.get_entity(id) == lot, "lookup returns the registered entity")
	t.ok(not store.add(id, lot), "duplicate registration is refused")
	t.eq(store.size(), 1, "refused duplicate did not grow the store")
	t.ok(store.get_entity(null) == null, "null ID lookup returns null")
	t.ok(store.get_entity(EntityId.create(&"lot", 999)) == null, "unknown ID lookup returns null")


func _test_allocation_order(t: TestCase) -> void:
	var ledger: Ledger = Ledger.new()
	var owner: EntityId = ledger.create_actor("owner").id
	var inv: Inventory = ledger.create_inventory("source", -1, owner)
	var lot: MaterialLot = ledger.add_lot(&"fiber", 5, {}, inv.id)
	t.eq(lot.id.to_key(), "lot:1", "first lot is lot:1")
	t.eq(ledger.get_lot(lot.id), lot, "ledger lookup finds the lot")
	t.eq(ledger.store.allocated_count(&"lot"), 1, "one lot sequence consumed")
