## Seeded 1,000-operation conservation and uniqueness property test.
##
## Deterministic PRNG implemented here (a 32-bit LCG) rather than using the
## engine RNG, because the QA contract requires recorded seeds and reproducible
## draw sequences and calls out engine PRNG details as unapproved. The generator
## is seeded per test; a failure message prints the seed and operation index.
extends RefCounted

const FIBER := &"fiber"
const STONE := &"stone"
const OPERATIONS := 1000
const SEED := 0x5EED0001
const FULL_CHECK_EVERY := 50


class Lcg:
	extends RefCounted
	var state: int

	func _init(p_seed: int) -> void:
		state = p_seed & 0xFFFF_FFFF

	func next_u32() -> int:
		# Numerical Recipes LCG constants; masked to stay within 32 bits.
		state = (state * 1664525 + 1013904223) & 0xFFFF_FFFF
		return state

	func below(bound: int) -> int:
		if bound <= 1:
			return 0
		# Use the high bits: an LCG's low bits have very short periods (the low
		# bit just alternates), which would make modulo draws predictable.
		return (next_u32() >> 16) % bound


func run(t: TestCase) -> void:
	t.suite("property")
	_conservation_over_1000_ops(t)
	_ids_stay_unique_across_ops(t)


func _conservation_over_1000_ops(t: TestCase) -> void:
	var rng: Lcg = Lcg.new(SEED)
	var ledger: Ledger = Ledger.new()
	var bus: CommandBus = CommandBus.new(ledger)
	var actor_id: EntityId = ledger.create_actor("property actor").id
	var inventories: Array[EntityId] = []
	# Ten inventories; two carry a HARNESS LIMIT capacity (named as such) so the
	# run also exercises atomic rejection, not only valid transfers.
	for i: int in 10:
		var capacity: int = -1
		if i == 7:
			capacity = 12  # HARNESS LIMIT, not game balance
		elif i == 8:
			capacity = 20  # HARNESS LIMIT, not game balance
		inventories.append(ledger.create_inventory("inv %d" % i, capacity).id)
	# Seed every inventory so the run mostly commits valid transfers and only
	# sometimes hits the deliberately illegal paths.
	for i: int in 10:
		ledger.add_lot(FIBER, 5, {"origin": "seed-fiber-%d" % i}, inventories[i])
		ledger.add_lot(STONE, 3, {"origin": "seed-stone-%d" % i}, inventories[(i + 1) % 10])

	var initial_fiber: int = ledger.total_of(FIBER)
	var initial_stone: int = ledger.total_of(STONE)
	var committed: int = 0
	var rejected: int = 0
	var reject_reasons: Dictionary = {}

	var op: int = 0
	while op < OPERATIONS:
		# Mostly draw from a non-empty inventory so the run exercises real
		# transfers; the rest stay random to hit insufficient-supply rejection.
		# Weighted modes so the run mostly commits real transfers but every
		# rejection guard is also exercised on purpose: 0 = valid random moves,
		# 1 = stale revision, 2 = over-capacity target, 3 = oversized quantity.
		var roll: int = rng.below(10)
		var mode: int = 0
		if roll >= 6:
			mode = 1  # 40% stale-revision attempts
		if roll == 8:
			mode = 2
		if roll == 9:
			mode = 3
		var src_idx: int = rng.below(inventories.size())
		if mode != 3:
			src_idx = _pick_non_empty(ledger, inventories, src_idx)
		var dst_idx: int = rng.below(inventories.size())
		if mode == 2:
			dst_idx = 7  # HARNESS LIMIT inventory (capacity 12)
		if dst_idx == src_idx:
			dst_idx = (dst_idx + 1) % inventories.size()
		var def_id: StringName = FIBER if rng.below(2) == 0 else STONE
		var qty: int = rng.below(4) + 1
		if mode == 3:
			qty = 1000  # deliberately larger than every fixture total
		var source: Inventory = ledger.get_inventory(inventories[src_idx])
		var expected_rev: int = source.revision
		if mode == 1:
			expected_rev = source.revision + 1
		var cmd: TransferCommand = TransferCommand.create(
			StringName("op-%04d" % op), actor_id, source.id, inventories[dst_idx], expected_rev
		).with_line(def_id, qty)
		var receipt: Receipt = bus.execute(cmd)
		if receipt.is_committed():
			committed += 1
		else:
			rejected += 1
			reject_reasons[receipt.error] = int(reject_reasons.get(receipt.error, 0)) + 1

		var label: String = "op %d (seed 0x%X)" % [op, SEED]
		# Cheap per-operation invariants: one pass over lots, no per-lot strings.
		var inv_used: Dictionary = {}
		var fiber_total: int = 0
		var stone_total: int = 0
		var units_total: int = 0
		var lot_ids: Dictionary = {}
		var duplicate_lot: bool = false
		var non_positive_lot: bool = false
		var homeless_lot: bool = false
		var lots: Array[MaterialLot] = ledger.lots_of_any()
		for lot: MaterialLot in lots:
			units_total += lot.quantity
			if lot.def_id == FIBER:
				fiber_total += lot.quantity
			elif lot.def_id == STONE:
				stone_total += lot.quantity
			if lot.quantity <= 0:
				non_positive_lot = true
			if lot.location == null or lot.location.is_consumed():
				homeless_lot = true
			elif lot.location.holder() != null:
				var holder_key: String = lot.location.holder().to_key()
				inv_used[holder_key] = int(inv_used.get(holder_key, 0)) + lot.quantity
			if lot_ids.has(lot.id.to_key()):
				duplicate_lot = true
			lot_ids[lot.id.to_key()] = true

		t.ok(fiber_total == initial_fiber, "fiber conserved at " + label)
		t.ok(stone_total == initial_stone, "stone conserved at " + label)
		t.ok(units_total == initial_fiber + initial_stone, "total units conserved at " + label)
		t.ok(not non_positive_lot, "no empty/negative lot at " + label)
		t.ok(not homeless_lot, "every live lot has one live location at " + label)
		t.ok(not duplicate_lot, "no lot ID appears twice at " + label)
		for inv_id: EntityId in inventories:
			var used: int = int(inv_used.get(inv_id.to_key(), 0))
			var inv: Inventory = ledger.get_inventory(inv_id)
			t.ok(used >= 0, "no negative inventory at " + label)
			if inv.capacity_units >= 0:
				t.ok(used <= inv.capacity_units, "harness capacity respected at " + label)
			t.ok(used == ledger.used_units(inv_id), "location-derived usage matches lookup at " + label)

		# Replaying the same command_id must not change state.
		var replay: Receipt = bus.execute(cmd)
		t.ok(replay == receipt, "replay returns original receipt at " + label)
		if op % FULL_CHECK_EVERY == 0:
			var snapshot: Dictionary = ledger.debug_state()
			bus.execute(cmd)
			t.dict_eq(ledger.debug_state(), snapshot, "replay mutates nothing at " + label)
		op += 1

	t.ok(committed > 0, "property run committed at least one transfer")
	t.ok(rejected > 0, "property run rejected at least one illegal transfer")
	t.eq(bus.receipt_count(), OPERATIONS, "one receipt per distinct command_id")
	print("  reject reasons: %s" % str(reject_reasons))
	print("  property: %d committed, %d rejected, %d lots, totals fiber=%d stone=%d" % [
		committed, rejected, ledger.lots_of_any().size(),
		ledger.total_of(FIBER), ledger.total_of(STONE)
	])


## Deterministic scan starting at `start`, returning the first inventory with
## units; falls back to `start` when everything is empty.
func _pick_non_empty(ledger: Ledger, inventories: Array[EntityId], start: int) -> int:
	for offset: int in inventories.size():
		var idx: int = (start + offset) % inventories.size()
		if ledger.used_units(inventories[idx]) > 0:
			return idx
	return start


func _ids_stay_unique_across_ops(t: TestCase) -> void:
	var rng: Lcg = Lcg.new(SEED + 1)
	var ledger: Ledger = Ledger.new()
	var bus: CommandBus = CommandBus.new(ledger)
	var actor_id: EntityId = ledger.create_actor("id actor").id
	var a: EntityId = ledger.create_inventory("a").id
	var b: EntityId = ledger.create_inventory("b").id
	ledger.add_lot(FIBER, 5, {}, a)
	ledger.add_lot(STONE, 3, {}, a)
	var seen: Dictionary = {}
	var recycled: bool = false
	for i: int in 200:
		var cmd: TransferCommand = TransferCommand.create(
			StringName("id-op-%04d" % i), actor_id, a, b,
			ledger.get_inventory(a).revision
		).with_line(FIBER if rng.below(2) == 0 else STONE, rng.below(2) + 1)
		bus.execute(cmd)
		for lot: MaterialLot in ledger.lots_of_any():
			var key: String = lot.id.to_key()
			if seen.has(key) and seen[key] != lot:
				recycled = true
			seen[key] = lot
	t.ok(not recycled, "a lot ID never refers to a different lot across operations")
	t.eq(ledger.store.size(), ledger.store.all_keys().size(), "store keys and entries agree")
	t.eq(seen.size(), ledger.lots_of_any().size(), "no lot identity was recycled")
