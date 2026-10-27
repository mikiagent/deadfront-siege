## Command-bus receipt-ledger tests: a command_id is consumed at most once.
##
## Covers the FND replay rule for both outcomes (committed and rejected), the
## fact that a replay returns the *same* receipt object, and the competing
## final-unit rule resolved by expected_source_revision.
extends RefCounted

const FIBER := &"fiber"
const STONE := &"stone"


class World:
	extends RefCounted
	var ledger: Ledger
	var bus: CommandBus
	var actor_id: EntityId
	var source_id: EntityId
	var target_id: EntityId

	func _init() -> void:
		ledger = Ledger.new()
		bus = CommandBus.new(ledger)
		actor_id = ledger.create_actor("human A").id
		source_id = ledger.create_inventory("source").id
		target_id = ledger.create_inventory("escrow").id
		ledger.add_lot(FIBER, 5, {"origin": "fixture-fiber"}, source_id)
		ledger.add_lot(STONE, 3, {"origin": "fixture-stone"}, source_id)

	func receipt_dict(command_id: StringName) -> Dictionary:
		var receipt: Receipt = bus.receipt_for(command_id)
		return receipt.to_dict() if receipt != null else {}

	func revision() -> int:
		return ledger.get_inventory(source_id).revision

	func cmd(command_id: StringName, fiber: int, stone: int = 0, revision_override: int = -1) -> TransferCommand:
		var rev: int = revision() if revision_override < 0 else revision_override
		var c: TransferCommand = TransferCommand.create(command_id, actor_id, source_id, target_id, rev)
		if fiber > 0:
			c.with_line(FIBER, fiber)
		if stone > 0:
			c.with_line(STONE, stone)
		return c


func run(t: TestCase) -> void:
	t.suite("idempotence")
	_test_same_command_id_different_payload_returns_first(t)
	_test_latest_payload_is_ignored(t)
	_test_rejected_receipt_is_also_sticky(t)
	_test_competing_commands_one_winner(t)
	_test_distinct_ids_both_apply(t)


## A repeated command_id with a DIFFERENT payload must still return the original
## receipt: the ID, not the payload, defines the transaction.
func _test_same_command_id_different_payload_returns_first(t: TestCase) -> void:
	var w: World = World.new()
	var first: Receipt = w.bus.execute(w.cmd(&"C1", 2, 1))
	var snapshot: Dictionary = w.ledger.debug_state()
	var different: Receipt = w.bus.execute(w.cmd(&"C1", 5, 3))
	t.ok(different == first, "reused command_id returns the original receipt object")
	t.ok(first.is_committed(), "the original command committed")
	t.dict_eq(w.ledger.debug_state(), snapshot, "the different payload applied nothing")
	t.eq(w.ledger.total_units(), 8, "no extra units moved")
	t.eq(w.bus.receipt_count(), 1, "one receipt for one command_id")


func _test_latest_payload_is_ignored(t: TestCase) -> void:
	var w: World = World.new()
	w.bus.execute(w.cmd(&"C2", 1))
	var receipt_before: Dictionary = w.receipt_dict(&"C2")
	var state_before: Dictionary = w.ledger.debug_state()
	for i: int in 5:
		w.bus.execute(w.cmd(&"C2", 1))
	t.dict_eq(w.receipt_dict(&"C2"), receipt_before, "five replays leave the receipt identical")
	t.dict_eq(w.ledger.debug_state(), state_before, "five replays leave the state identical")


func _test_rejected_receipt_is_also_sticky(t: TestCase) -> void:
	var w: World = World.new()
	var too_big: Receipt = w.bus.execute(w.cmd(&"C3", 99))
	t.eq(too_big.error, Receipt.ErrorCode.INSUFFICIENT_SUPPLY, "oversized command rejects first")
	var state_after_reject: Dictionary = w.ledger.debug_state()
	# Same ID, now a legal payload: still the stored rejection, nothing applied.
	var replay: Receipt = w.bus.execute(w.cmd(&"C3", 1))
	t.ok(replay == too_big, "rejected command_id stays rejected")
	t.dict_eq(w.ledger.debug_state(), state_after_reject, "rejected replay applied nothing")
	t.eq(w.bus.receipt_for(&"C3").error, Receipt.ErrorCode.INSUFFICIENT_SUPPLY, "stored receipt keeps its error")
	# A fresh ID with the same payload DOES apply: rejection is not a poison pill.
	var fresh: Receipt = w.bus.execute(w.cmd(&"C4", 1))
	t.ok(fresh.is_committed(), "a new command_id with a legal payload commits")
	t.eq(w.ledger.total_units(), 8, "total units still conserved")


func _test_competing_commands_one_winner(t: TestCase) -> void:
	var w: World = World.new()
	# Both commands are built against the same observed revision, so both are
	# "in flight" at the same logical moment; the bus is synchronous, so the
	# second must lose on the revision guard.
	var rev: int = w.revision()
	var a: TransferCommand = w.cmd(&"race-a", 3, 0, rev)
	var b: TransferCommand = w.cmd(&"race-b", 3, 0, rev)
	var ra: Receipt = w.bus.execute(a)
	var rb: Receipt = w.bus.execute(b)
	t.ok(ra.is_committed(), "first competing transfer wins")
	t.eq(rb.error, Receipt.ErrorCode.REVISION_MISMATCH, "second loses on the stale revision")
	t.eq(w.ledger.get_inventory(w.source_id).revision, rev + 1, "source revision advanced exactly once")
	t.eq(w.ledger.get_inventory(w.target_id).revision, rev + 1, "target revision advanced exactly once")
	t.eq(w.ledger.total_of(FIBER), 5, "fiber conserved across the race")
	t.eq(w.ledger.total_units(), 8, "total units conserved across the race")

	# Sweep: for every possible split of the remaining fiber, exactly one of two
	# symmetric competitors may win at each step.
	for step: int in 4:
		var world: World = World.new()
		var r0: int = world.revision()
		var c1: Receipt = world.bus.execute(world.cmd(StringName("s%d-1" % step), 5, 0, r0))
		var c2: Receipt = world.bus.execute(world.cmd(StringName("s%d-2" % step), 5, 0, r0))
		var wins: int = (1 if c1.is_committed() else 0) + (1 if c2.is_committed() else 0)
		t.eq(wins, 1, "sweep %d: exactly one winner" % step)
		t.eq(world.ledger.total_of(FIBER), 5, "sweep %d: fiber conserved" % step)


func _test_distinct_ids_both_apply(t: TestCase) -> void:
	var w: World = World.new()
	var r1: Receipt = w.bus.execute(w.cmd(&"D1", 1))
	var r2: Receipt = w.bus.execute(w.cmd(&"D2", 1))
	t.ok(r1.is_committed() and r2.is_committed(), "distinct command_ids both commit")
	t.eq(w.ledger.total_units(), 8, "two legal transfers conserve all 8 units")
	t.eq(w.ledger.get_inventory(w.target_id).revision, 2, "target revision advanced twice")
	t.eq(w.bus.receipt_count(), 2, "two receipts recorded")
