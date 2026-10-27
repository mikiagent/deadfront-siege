## FND-001 and atomic-transfer contract tests.
##
## Fixture values are exactly the M0 ones from MILESTONES/QA (5 fiber, 3 stone,
## transfer 2 fiber + 1 stone). Test-only capacity is a harness limit to prove
## rejection; it is never read as game balance.
extends RefCounted

const FIBER := &"fiber"
const STONE := &"stone"


## The documented M0 scenario: human A owns 5 fiber + 3 stone.
class Fnd001World:
	extends RefCounted
	var ledger: Ledger
	var bus: CommandBus
	var actor_id: EntityId
	var source_id: EntityId
	var escrow_id: EntityId
	var fiber_lot: MaterialLot
	var stone_lot: MaterialLot

	func _init() -> void:
		ledger = Ledger.new()
		bus = CommandBus.new(ledger)
		var actor: Actor = ledger.create_actor("human A")
		actor_id = actor.id
		source_id = ledger.create_inventory("human A bag").id
		escrow_id = ledger.create_inventory("escrow").id
		fiber_lot = ledger.add_lot(FIBER, 5, {"origin": "fixture-fiber"}, source_id)
		stone_lot = ledger.add_lot(STONE, 3, {"origin": "fixture-stone"}, source_id)

	func t1() -> TransferCommand:
		var source: Inventory = ledger.get_inventory(source_id)
		return TransferCommand.create(&"T1", actor_id, source_id, escrow_id, source.revision) \
			.with_line(FIBER, 2) \
			.with_line(STONE, 1)


func run(t: TestCase) -> void:
	t.suite("transfer")
	_test_fnd_001(t)
	_test_fnd_001_replay(t)
	_test_oversized_rejects_atomically(t)
	_test_capacity_rejects_atomically(t)
	_test_stale_revision_rejects(t)
	_test_competing_final_unit(t)
	_test_one_authoritative_location(t)
	_test_invalid_commands_reject_atomically(t)
	_test_fnd_001_receipt_shape(t)
	_test_provenance_survives_chained_splits(t)


func _test_fnd_001(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	var receipt: Receipt = world.bus.execute(world.t1())
	t.ok(receipt.is_committed(), "T1 commits")
	# 5 fiber + 3 stone in, 2 fiber + 1 stone out => source keeps 3 fiber + 2 stone.
	t.eq(world.ledger.used_units(world.source_id), 5, "source holds 5 units (3 fiber + 2 stone) after T1")
	t.eq(world.ledger.used_units(world.escrow_id), 3, "escrow holds 3 units after T1")
	t.eq(_qty_of_def(world.ledger, world.source_id, FIBER), 3, "source fiber = 3")
	t.eq(_qty_of_def(world.ledger, world.source_id, STONE), 2, "source stone = 2")
	t.eq(_qty_of_def(world.ledger, world.escrow_id, FIBER), 2, "escrow fiber = 2")
	t.eq(_qty_of_def(world.ledger, world.escrow_id, STONE), 1, "escrow stone = 1")
	t.eq(world.ledger.total_of(FIBER), 5, "fiber conserved through the split")
	t.eq(world.ledger.total_of(STONE), 3, "stone conserved through the split")

	# Provenance travels with the moved material.
	var escrow_fiber: Array[MaterialLot] = _lots_of_def(world.ledger, world.escrow_id, FIBER)
	t.eq(escrow_fiber.size(), 1, "escrow fiber is one split lot")
	t.dict_eq(escrow_fiber[0].provenance, {"origin": "fixture-fiber"}, "escrow lot keeps provenance")
	t.ok(not escrow_fiber[0].id.equals(world.fiber_lot.id), "split lot has a new stable ID")
	t.eq(world.fiber_lot.quantity, 3, "source lot shrank, not duplicated")
	t.dict_eq(world.fiber_lot.provenance, {"origin": "fixture-fiber"}, "source lot keeps provenance")
	# The 1-stone line splits the 3-stone lot: a new ID in escrow, the source lot
	# keeps its own ID with the remaining 2 units.
	var escrow_stone: Array[MaterialLot] = _lots_of_def(world.ledger, world.escrow_id, STONE)
	t.eq(escrow_stone.size(), 1, "escrow stone is one split lot")
	t.ok(not escrow_stone[0].id.equals(world.stone_lot.id), "split stone lot has a new stable ID")
	t.dict_eq(escrow_stone[0].provenance, {"origin": "fixture-stone"}, "escrow stone keeps provenance")
	t.eq(world.stone_lot.quantity, 2, "source stone lot shrank to 2")
	t.eq(receipt.source_revision_after, 1, "source revision bumped once")
	t.eq(receipt.target_revision_after, 1, "target revision bumped once")


func _test_fnd_001_replay(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	var first: Receipt = world.bus.execute(world.t1())
	var before: Dictionary = world.ledger.debug_state()
	var replay: Receipt = world.bus.execute(world.t1())
	t.ok(replay == first, "replay returns the identical receipt object")
	t.dict_eq(replay.to_dict(), first.to_dict(), "replay receipt matches the original")
	t.dict_eq(world.ledger.debug_state(), before, "replay changed no state")
	t.eq(world.bus.receipt_count(), 1, "one receipt recorded for one command")
	t.eq(world.ledger.total_units(), 8, "total units unchanged by replay")


func _test_oversized_rejects_atomically(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	world.bus.execute(world.t1())
	var before: Dictionary = world.ledger.debug_state()
	var source: Inventory = world.ledger.get_inventory(world.source_id)
	# 4 fiber is more than the 3 left; the stone line must not apply either.
	var t2: TransferCommand = TransferCommand.create(&"T2", world.actor_id, world.source_id, world.escrow_id, source.revision) \
		.with_line(FIBER, 4) \
		.with_line(STONE, 1)
	var receipt: Receipt = world.bus.execute(t2)
	t.ok(not receipt.is_committed(), "T2 is rejected")
	t.eq(receipt.error, Receipt.ErrorCode.INSUFFICIENT_SUPPLY, "T2 rejects for insufficient supply")
	t.dict_eq(world.ledger.debug_state(), before, "rejected T2 changed nothing at all")
	# Replaying the rejected ID also changes nothing and returns the same receipt.
	var replay: Receipt = world.bus.execute(t2)
	t.ok(replay == receipt, "rejected command replay returns the stored receipt")
	t.dict_eq(world.ledger.debug_state(), before, "rejected replay still changed nothing")


func _test_capacity_rejects_atomically(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	# HARNESS LIMIT: a 1-unit escrow capacity exists only to prove rejection.
	var tight_escrow: Inventory = world.ledger.create_inventory("tight escrow (harness limit)", 1)
	var source: Inventory = world.ledger.get_inventory(world.source_id)
	var before: Dictionary = world.ledger.debug_state()
	var cmd: TransferCommand = TransferCommand.create(&"T-cap", world.actor_id, world.source_id, tight_escrow.id, source.revision) \
		.with_line(FIBER, 2)
	var receipt: Receipt = world.bus.execute(cmd)
	t.eq(receipt.error, Receipt.ErrorCode.CAPACITY_EXCEEDED, "over-capacity transfer rejects")
	t.dict_eq(world.ledger.debug_state(), before, "capacity rejection changed nothing")
	t.eq(world.ledger.total_units(), 8, "no units lost or created on rejection")


func _test_stale_revision_rejects(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	var stale: int = world.ledger.get_inventory(world.source_id).revision
	world.bus.execute(world.t1())
	var before: Dictionary = world.ledger.debug_state()
	var stale_cmd: TransferCommand = TransferCommand.create(&"T-stale", world.actor_id, world.source_id, world.escrow_id, stale) \
		.with_line(STONE, 1)
	var receipt: Receipt = world.bus.execute(stale_cmd)
	t.eq(receipt.error, Receipt.ErrorCode.REVISION_MISMATCH, "stale expected_revision rejects")
	t.dict_eq(world.ledger.debug_state(), before, "revision rejection changed nothing")


func _test_competing_final_unit(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	world.bus.execute(world.t1())
	# Both competitors saw source revision 1; only one may take the last fiber.
	var source: Inventory = world.ledger.get_inventory(world.source_id)
	t.eq(world.ledger.used_units(world.source_id), 5, "source holds 5 units before the race")
	var other_target: Inventory = world.ledger.create_inventory("competitor escrow")
	var rev: int = source.revision
	var first: TransferCommand = TransferCommand.create(&"T-a", world.actor_id, world.source_id, world.escrow_id, rev) \
		.with_line(FIBER, 3)
	var second: TransferCommand = TransferCommand.create(&"T-b", world.actor_id, world.source_id, other_target.id, rev) \
		.with_line(FIBER, 3)
	var r1: Receipt = world.bus.execute(first)
	var r2: Receipt = world.bus.execute(second)
	var winners: int = 0
	if r1.is_committed():
		winners += 1
	if r2.is_committed():
		winners += 1
	t.eq(winners, 1, "exactly one competing transfer wins")
	t.eq(r2.error, Receipt.ErrorCode.REVISION_MISMATCH, "the loser fails on the stale revision")
	t.eq(world.ledger.total_of(FIBER), 5, "fiber conserved across the race")
	t.eq(world.ledger.total_of(FIBER), 5, "fiber total stable after the race")
	t.eq(_qty_of_def(world.ledger, world.source_id, FIBER), 0, "source fiber fully moved by the winner")
	t.eq(_qty_of_def(world.ledger, world.escrow_id, FIBER), 5, "winner's escrow holds all fiber")

	# A second race where both are valid on revision but only one unit exists.
	var world2: Fnd001World = Fnd001World.new()
	var one_unit_victim: Inventory = world2.ledger.create_inventory("single unit source")
	var one_unit_dest: Inventory = world2.ledger.create_inventory("single unit dest")
	world2.ledger.add_lot(STONE, 1, {"origin": "last-unit"}, one_unit_victim.id)
	var rev2: int = one_unit_victim.revision
	var c1: TransferCommand = TransferCommand.create(&"T-c", world2.actor_id, one_unit_victim.id, one_unit_dest.id, rev2) \
		.with_line(STONE, 1)
	var c2: TransferCommand = TransferCommand.create(&"T-d", world2.actor_id, one_unit_victim.id, one_unit_dest.id, rev2) \
		.with_line(STONE, 1)
	var cr1: Receipt = world2.bus.execute(c1)
	var cr2: Receipt = world2.bus.execute(c2)
	t.ok(cr1.is_committed() and not cr2.is_committed(), "last-unit race has exactly one winner")
	t.eq(world2.ledger.used_units(one_unit_victim.id), 0, "the loser's source lot was not partially spent")
	t.eq(world2.ledger.total_of(STONE), 4, "stone conserved across the last-unit race (3 fixture + 1)")
	t.eq(world2.ledger.used_units(one_unit_dest.id), 1, "last unit exists once in the destination")


func _test_one_authoritative_location(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	world.bus.execute(world.t1())
	# Every live lot names exactly one location, and each inventory's used_units is
	# exactly the sum of lots pointing at it: no second ownership field exists.
	var counted: int = 0
	var by_id: Dictionary = {}
	for lot: MaterialLot in world.ledger.lots_of_any():
		t.ok(not by_id.has(lot.id.to_key()), "lot %s appears once" % lot.id.to_key())
		by_id[lot.id.to_key()] = true
		t.ok(lot.location != null and not lot.location.is_consumed(), "lot has a live location")
		counted += lot.quantity
	t.eq(counted, 8, "per-lot quantities sum to the conserved total")


## FND-001's receipt is a fixture: exact moves, quantity and revisions.
func _test_fnd_001_receipt_shape(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	var receipt: Receipt = world.bus.execute(world.t1())
	t.dict_eq(receipt.to_dict(), {
		"command_id": "T1",
		"status": int(Receipt.Status.COMMITTED),
		"error": int(Receipt.ErrorCode.NONE),
		"moves": [
			{
				"lot_id": "lot:3",
				"source_lot_id": "lot:1",
				"def_id": "fiber",
				"quantity": 2,
				"to": "inv:2",
				"split": true,
			},
			{
				"lot_id": "lot:4",
				"source_lot_id": "lot:2",
				"def_id": "stone",
				"quantity": 1,
				"to": "inv:2",
				"split": true,
			},
		],
		"source_revision_after": 1,
		"target_revision_after": 1,
		"source_used_after": 5,
		"target_used_after": 3,
	}, "FND-001 receipt matches the fixture exactly")


## Splitting an already-split lot must keep the original provenance, not drop it.
func _test_provenance_survives_chained_splits(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	world.bus.execute(world.t1())
	var third: Inventory = world.ledger.create_inventory("third hop")
	var escrow: Inventory = world.ledger.get_inventory(world.escrow_id)
	var cmd: TransferCommand = TransferCommand.create(&"T-hop2", world.actor_id, world.escrow_id, third.id, escrow.revision) \
		.with_line(FIBER, 1)
	var receipt: Receipt = world.bus.execute(cmd)
	t.ok(receipt.is_committed(), "second hop commits")
	var hopped: Array[MaterialLot] = _lots_of_def(world.ledger, third.id, FIBER)
	t.eq(hopped.size(), 1, "third inventory holds one fiber lot")
	t.dict_eq(hopped[0].provenance, {"origin": "fixture-fiber"}, "chained split keeps origin provenance")
	t.eq(hopped[0].quantity, 1, "chained split quantity is 1")
	t.eq(_qty_of_def(world.ledger, world.escrow_id, FIBER), 1, "escrow keeps the remaining 1 fiber")
	t.eq(world.ledger.total_of(FIBER), 5, "fiber still conserved after two hops")


## Every invalid command shape must reject and leave state untouched.
func _test_invalid_commands_reject_atomically(t: TestCase) -> void:
	var world: Fnd001World = Fnd001World.new()
	var source: Inventory = world.ledger.get_inventory(world.source_id)
	var before: Dictionary = world.ledger.debug_state()
	var ghost: EntityId = EntityId.create(&"inv", 999)

	var unknown_source: TransferCommand = TransferCommand.create(&"T-x1", world.actor_id, ghost, world.escrow_id, 0) \
		.with_line(FIBER, 1)
	t.eq(world.bus.execute(unknown_source).error, Receipt.ErrorCode.UNKNOWN_SOURCE,
		"unknown source inventory rejects")

	var unknown_target: TransferCommand = TransferCommand.create(&"T-x2", world.actor_id, world.source_id, ghost, source.revision) \
		.with_line(FIBER, 1)
	t.eq(world.bus.execute(unknown_target).error, Receipt.ErrorCode.UNKNOWN_TARGET,
		"unknown target inventory rejects")

	var same_place: TransferCommand = TransferCommand.create(&"T-x3", world.actor_id, world.source_id, world.source_id, source.revision) \
		.with_line(FIBER, 1)
	t.eq(world.bus.execute(same_place).error, Receipt.ErrorCode.SOURCE_IS_TARGET,
		"source == target rejects")

	var no_lines: TransferCommand = TransferCommand.create(&"T-x4", world.actor_id, world.source_id, world.escrow_id, source.revision)
	t.eq(world.bus.execute(no_lines).error, Receipt.ErrorCode.INVALID_QUANTITY,
		"command with no lines rejects")

	var zero_line: TransferCommand = TransferCommand.create(&"T-x5", world.actor_id, world.source_id, world.escrow_id, source.revision) \
		.with_line(FIBER, 0)
	t.eq(world.bus.execute(zero_line).error, Receipt.ErrorCode.INVALID_QUANTITY,
		"zero-quantity line rejects")

	var null_actor: TransferCommand = TransferCommand.create(&"T-x6", null, world.source_id, world.escrow_id, source.revision) \
		.with_line(FIBER, 1)
	t.eq(world.bus.execute(null_actor).error, Receipt.ErrorCode.INVALID_COMMAND,
		"command without a resolvable actor rejects")

	t.dict_eq(world.ledger.debug_state(), before, "no invalid command mutated the ledger")
	t.eq(world.ledger.total_units(), 8, "all 8 fixture units still present")
	t.eq(world.bus.receipt_count(), 6, "each rejected command_id got one receipt")


func _qty_of_def(ledger: Ledger, inventory_id: EntityId, def_id: StringName) -> int:
	var total: int = 0
	for lot: MaterialLot in ledger.lots_of(inventory_id):
		if lot.def_id == def_id:
			total += lot.quantity
	return total


func _lots_of_def(ledger: Ledger, inventory_id: EntityId, def_id: StringName) -> Array[MaterialLot]:
	var out: Array[MaterialLot] = []
	for lot: MaterialLot in ledger.lots_of(inventory_id):
		if lot.def_id == def_id:
			out.append(lot)
	return out
