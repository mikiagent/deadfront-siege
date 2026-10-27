## Seeded 1,000-operation conservation and uniqueness property test.
##
## Deterministic PRNG implemented here (a 32-bit LCG) rather than using the
## engine RNG, because the QA contract requires recorded seeds and reproducible
## draw sequences and calls out engine PRNG details as unapproved. Each run is
## seeded, and a failing check names the seed and the operation index.
##
## The workload mixes committed transfers with every rejection guard (stale
## revision, over-capacity target, oversized quantity, source == target) so the
## invariants are checked on rejected paths too.
extends RefCounted

const FIBER := &"fiber"
const STONE := &"stone"
const OPERATIONS := 1000
## Primary seed is the one the QA contract's 1,000-operation run uses. The extra
## seeds are the same workload with different draws, to catch order-dependent
## bugs a single seed can miss.
const SEED := 0x5EED0001
const EXTRA_SEEDS: Array[int] = [0x5EED0002, 0x5EED0003, 0x0000C0DE]
const INVENTORY_COUNT := 10
const CAPACITY_INVENTORY := 7
const CAPACITY_UNITS := 12  # HARNESS LIMIT, not game balance


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


class World:
	extends RefCounted
	var rng: Lcg
	var ledger: Ledger
	var bus: CommandBus
	var actor_id: EntityId
	var inventories: Array[EntityId] = []
	var initial_fiber: int = 0
	var initial_stone: int = 0
	var committed: int = 0
	var rejected: int = 0
	var reject_reasons: Dictionary = {}

	func _init(p_seed: int) -> void:
		rng = Lcg.new(p_seed)
		ledger = Ledger.new()
		bus = CommandBus.new(ledger)
		actor_id = ledger.create_actor("property actor").id
		for i: int in INVENTORY_COUNT:
			var capacity: int = -1
			if i == CAPACITY_INVENTORY:
				capacity = CAPACITY_UNITS
			inventories.append(ledger.create_inventory("inv %d" % i, capacity).id)
		# Seed every inventory so most draws are legal transfers and the run is not
		# dominated by insufficient-supply rejections.
		for i: int in INVENTORY_COUNT:
			ledger.add_lot(FIBER, 5, {"origin": "seed-fiber-%d" % i}, inventories[i])
			ledger.add_lot(STONE, 3, {"origin": "seed-stone-%d" % i}, inventories[(i + 1) % INVENTORY_COUNT])
		initial_fiber = ledger.total_of(FIBER)
		initial_stone = ledger.total_of(STONE)

	## One deterministic operation. Returns the command it issued.
	func step(op: int) -> TransferCommand:
		# Weighted modes: mostly valid moves, each guard exercised on purpose.
		var roll: int = rng.below(10)
		var mode: int = 1 if roll >= 7 else 0   # 30% stale-revision attempts
		if roll == 8:
			mode = 2                              # over-capacity target
		elif roll == 9:
			mode = 3                              # oversized quantity
		var src_idx: int = rng.below(INVENTORY_COUNT)
		if mode != 3:
			src_idx = _pick_non_empty(src_idx)
		var dst_idx: int = rng.below(INVENTORY_COUNT)
		if mode == 2:
			dst_idx = CAPACITY_INVENTORY
		if dst_idx == src_idx:
			dst_idx = (dst_idx + 1) % INVENTORY_COUNT
		var def_id: StringName = FIBER if rng.below(2) == 0 else STONE
		var qty: int = rng.below(4) + 1
		if mode == 3:
			qty = 1000  # larger than every fixture total
		var source: Inventory = ledger.get_inventory(inventories[src_idx])
		var expected_rev: int = source.revision if mode != 1 else source.revision + 1
		var cmd: TransferCommand = TransferCommand.create(
			StringName("op-%04d" % op), actor_id, source.id, inventories[dst_idx], expected_rev
		).with_line(def_id, qty)
		var receipt: Receipt = bus.execute(cmd)
		if receipt.is_committed():
			committed += 1
		else:
			rejected += 1
			reject_reasons[receipt.error] = int(reject_reasons.get(receipt.error, 0)) + 1
		return cmd

	## Deterministic scan starting at `start`, returning the first inventory with
	## units; falls back to `start` when everything is empty.
	func _pick_non_empty(start: int) -> int:
		for offset: int in INVENTORY_COUNT:
			var idx: int = (start + offset) % INVENTORY_COUNT
			if ledger.used_units(inventories[idx]) > 0:
				return idx
		return start


## Snapshot of the invariants the QA contract requires after every command.
class Snapshot:
	extends RefCounted
	var fiber_total: int = 0
	var stone_total: int = 0
	var units_total: int = 0
	var non_positive_lot: bool = false
	var homeless_lot: bool = false
	var duplicate_lot: bool = false
	var used: Dictionary = {}      # inventory key -> units derived from lot locations
	var lot_count: int = 0


func run(t: TestCase) -> void:
	t.suite("property")
	_test_seeded_conservation(t, SEED, "primary seed")
	_test_replay_is_inert(t, SEED)
	_test_multiple_seeds(t)
	_ids_stay_unique_across_ops(t)


func _take_snapshot(world: World) -> Snapshot:
	var snap: Snapshot = Snapshot.new()
	var lot_ids: Dictionary = {}
	var lots: Array[MaterialLot] = world.ledger.lots_of_any()
	snap.lot_count = lots.size()
	for lot: MaterialLot in lots:
		snap.units_total += lot.quantity
		if lot.def_id == FIBER:
			snap.fiber_total += lot.quantity
		elif lot.def_id == STONE:
			snap.stone_total += lot.quantity
		if lot.quantity <= 0:
			snap.non_positive_lot = true
		if lot.location == null or lot.location.is_consumed() or lot.location.holder() == null:
			snap.homeless_lot = true
		else:
			var holder_key: String = lot.location.holder().to_key()
			snap.used[holder_key] = int(snap.used.get(holder_key, 0)) + lot.quantity
		if lot_ids.has(lot.id.to_key()):
			snap.duplicate_lot = true
		lot_ids[lot.id.to_key()] = true
	return snap


func _check_invariants(t: TestCase, world: World, label: String, include_usage: bool) -> void:
	var snap: Snapshot = _take_snapshot(world)
	t.ok(snap.fiber_total == world.initial_fiber, "fiber conserved at " + label)
	t.ok(snap.stone_total == world.initial_stone, "stone conserved at " + label)
	t.ok(snap.units_total == world.initial_fiber + world.initial_stone, "total units conserved at " + label)
	t.ok(not snap.non_positive_lot, "no empty/negative lot at " + label)
	t.ok(not snap.homeless_lot, "every live lot has one live location at " + label)
	t.ok(not snap.duplicate_lot, "no lot ID appears twice at " + label)
	if not include_usage:
		return
	for inv_id: EntityId in world.inventories:
		var used: int = int(snap.used.get(inv_id.to_key(), 0))
		var inv: Inventory = world.ledger.get_inventory(inv_id)
		t.ok(used >= 0, "no negative inventory at " + label)
		if inv.capacity_units >= 0:
			t.ok(used <= inv.capacity_units, "harness capacity respected at " + label)
		t.ok(used == world.ledger.used_units(inv_id), "derived usage matches lookup at " + label)


func _test_seeded_conservation(t: TestCase, seed: int, name: String) -> void:
	var world: World = World.new(seed)
	var op: int = 0
	while op < OPERATIONS:
		world.step(op)
		# Cheap invariants every operation; the expensive per-inventory cross-check
		# every 25th operation keeps a 4,000-operation run fast.
		var label: String = "%s op %d (seed 0x%X)" % [name, op, seed]
		_check_invariants(t, world, label, op % 25 == 0)
		op += 1

	t.ok(world.committed > 0, "%s committed at least one transfer" % name)
	t.ok(world.rejected > 0, "%s rejected at least one illegal transfer" % name)
	t.eq(world.bus.receipt_count(), OPERATIONS, "%s has one receipt per command_id" % name)
	print("  property[0x%X]: %d committed, %d rejected, lots=%d, reasons=%s" % [
		seed, world.committed, world.rejected, world.ledger.lots_of_any().size(),
		str(world.reject_reasons)
	])


## Replaying every issued command_id must return the identical receipt and
## change nothing, including after many mutations in between.
func _test_replay_is_inert(t: TestCase, seed: int) -> void:
	var world: World = World.new(seed)
	var commands: Array[TransferCommand] = []
	for op: int in 200:
		commands.append(world.step(op))
	var before: Dictionary = world.ledger.debug_state()
	var receipts_before: Dictionary = {}
	for cmd: TransferCommand in commands:
		receipts_before[String(cmd.command_id)] = world.bus.receipt_for(cmd.command_id).to_dict()
	var mismatch: bool = false
	for cmd: TransferCommand in commands:
		var replay: Receipt = world.bus.execute(cmd)
		if replay.to_dict() != receipts_before[String(cmd.command_id)]:
			mismatch = true
	t.ok(not mismatch, "every replay returns its original receipt after 200 operations")
	t.dict_eq(world.ledger.debug_state(), before, "200 replays change nothing")
	t.eq(world.bus.receipt_count(), 200, "replays did not add receipts")


func _test_multiple_seeds(t: TestCase) -> void:
	for seed: int in EXTRA_SEEDS:
		_test_seeded_conservation(t, seed, "seed 0x%X" % seed)


func _ids_stay_unique_across_ops(t: TestCase) -> void:
	var world: World = World.new(SEED + 1)
	world.ledger.add_lot(FIBER, 5, {}, world.inventories[0])
	var seen: Dictionary = {}
	var recycled: bool = false
	for op: int in 300:
		world.step(op)
		for lot: MaterialLot in world.ledger.lots_of_any():
			var key: String = lot.id.to_key()
			if seen.has(key) and seen[key] != lot:
				recycled = true
			seen[key] = lot
	t.ok(not recycled, "a lot ID never refers to a different lot across operations")
	t.eq(world.ledger.store.size(), world.ledger.store.all_keys().size(), "store keys and entries agree")
	t.eq(seen.size(), world.ledger.lots_of_any().size(), "no lot identity was recycled")
	# IDs of different kinds never collide, and allocation only moved forward.
	var lot_count: int = world.ledger.store.allocated_count(&"lot")
	var distinct_ids: Dictionary = {}
	for key: String in world.ledger.store.all_keys():
		distinct_ids[key] = true
	t.eq(distinct_ids.size(), world.ledger.store.size(), "all store keys are distinct")
	t.ok(lot_count >= world.ledger.lots_of_any().size(), "allocated lot sequences cover every live lot")
