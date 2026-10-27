## FND-001 driven from the checked-in fixture file.
##
## The fixture (tests/fixtures/fnd_001.json) is the M0 scenario from
## docs/specs/MILESTONES.md and QA-CONTRACT.md: human A owns 5 fiber + 3 stone;
## T1 moves 2 fiber + 1 stone to escrow; T1 replay does nothing; T2 asks for more
## fiber than remains and is rejected atomically.
##
## Reading the numbers from a file instead of hard-coding them in the test means
## a reviewer can diff the expectation without reading GDScript, and the
## persistence phase can hash the same state.
extends RefCounted

const FIXTURE_PATH := "res://tests/fixtures/fnd_001.json"


class Scenario:
	extends RefCounted
	var ledger: Ledger
	var bus: CommandBus
	var actor_id: EntityId
	var slots: Dictionary = {}  # slot name -> EntityId
	var inventory_objects: Dictionary = {}  # slot name -> Inventory

	func slot_id(name: String) -> EntityId:
		return slots[name]

	func revision() -> int:
		return (inventory_objects["source"] as Inventory).revision

	func command_from(spec: Dictionary, revision_override: int = -1) -> TransferCommand:
		var rev: int = revision() if revision_override < 0 else revision_override
		var cmd: TransferCommand = TransferCommand.create(
			StringName(spec["command_id"]),
			actor_id,
			slot_id(spec["from"]),
			slot_id(spec["to"]),
			rev
		)
		for line: Dictionary in spec["lines"]:
			cmd.with_line(StringName(line["def_id"]), int(line["quantity"]))
		return cmd


func run(t: TestCase) -> void:
	t.suite("fnd-001")
	var fixture: Dictionary = _load_fixture(t)
	if fixture.is_empty():
		return
	_scenario_matches_fixture(t, fixture)
	_replay_is_inert(t, fixture)
	_rejection_preserves_fixture_state(t, fixture)


func _load_fixture(t: TestCase) -> Dictionary:
	var file: FileAccess = FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if not t.ok(file != null, "FND-001 fixture file is readable"):
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not t.ok(parsed is Dictionary, "FND-001 fixture parses as an object"):
		return {}
	var fixture: Dictionary = parsed
	t.eq(fixture.get("fixture_id", ""), "FND-001", "fixture declares its catalog ID")
	return fixture


func _build(fixture: Dictionary) -> Scenario:
	var scenario: Scenario = Scenario.new()
	scenario.ledger = Ledger.new()
	scenario.bus = CommandBus.new(scenario.ledger)
	scenario.actor_id = scenario.ledger.create_actor(String(fixture["actor_label"])).id
	for spec: Dictionary in fixture["inventories"]:
		# Only the inventory the fixture marks owned belongs to the actor.
		var owner: EntityId = scenario.actor_id if bool(spec.get("owned_by_actor", false)) else null
		var inv: Inventory = scenario.ledger.create_inventory(String(spec["label"]), -1, owner)
		scenario.slots[String(spec["slot"])] = inv.id
		scenario.inventory_objects[String(spec["slot"])] = inv
	for lot_spec: Dictionary in fixture["initial_lots"]:
		scenario.ledger.add_lot(
			StringName(lot_spec["def_id"]),
			int(lot_spec["quantity"]),
			lot_spec["provenance"],
			scenario.slot_id(String(lot_spec["inventory"]))
		)
	return scenario


func _scenario_matches_fixture(t: TestCase, fixture: Dictionary) -> void:
	var scenario: Scenario = _build(fixture)
	var expected: Dictionary = fixture["expected"]

	for spec: Dictionary in fixture["commands"]:
		var cmd: TransferCommand = scenario.command_from(spec)
		if spec["command_id"] == "T2":
			# T2 is built after T1 has advanced the source revision; the fixture
			# describes intent, so read the current revision.
			cmd = scenario.command_from(spec)
		var receipt: Receipt = scenario.bus.execute(cmd)
		if spec["expect"] == "committed":
			t.ok(receipt.is_committed(), "%s commits" % spec["command_id"])
		else:
			t.ok(not receipt.is_committed(), "%s is rejected" % spec["command_id"])
			t.eq(
				_reason_name(receipt.error),
				String(spec["expect_error"]),
				"%s rejects with the fixture error" % spec["command_id"]
			)
		# Replay the same command_id immediately: identical receipt, no mutation.
		var before: Dictionary = scenario.ledger.debug_state()
		var replay: Receipt = scenario.bus.execute(cmd)
		t.ok(replay == receipt, "%s replay returns the stored receipt" % spec["command_id"])
		t.dict_eq(scenario.ledger.debug_state(), before, "%s replay changes no state" % spec["command_id"])

	_assert_inventory_matches(t, scenario, "source", expected["source"], fixture["expected_provenance"]["source"])
	_assert_inventory_matches(t, scenario, "escrow", expected["escrow"], fixture["expected_provenance"]["escrow"])
	for def_name: String in expected["totals"].keys():
		t.eq(
			scenario.ledger.total_of(StringName(def_name)),
			int(expected["totals"][def_name]),
			"total %s matches the fixture" % def_name
		)
	t.eq(scenario.ledger.total_units(), int(expected["total_units"]), "total units match the fixture")
	t.eq(scenario.bus.receipt_count(), int(expected["receipts"]), "one receipt per fixture command_id")


func _replay_is_inert(t: TestCase, fixture: Dictionary) -> void:
	var scenario: Scenario = _build(fixture)
	var t1_spec: Dictionary = fixture["commands"][0]
	var receipt: Receipt = scenario.bus.execute(scenario.command_from(t1_spec))
	t.eq(receipt.command_id, StringName("T1"), "first fixture command is T1")
	var snapshot: Dictionary = scenario.ledger.debug_state()
	for i: int in 3:
		var again: Receipt = scenario.bus.execute(scenario.command_from(t1_spec))
		t.ok(again == receipt, "T1 replay %d returns the original receipt" % i)
	t.dict_eq(scenario.ledger.debug_state(), snapshot, "three T1 replays leave state identical")


func _rejection_preserves_fixture_state(t: TestCase, fixture: Dictionary) -> void:
	var scenario: Scenario = _build(fixture)
	scenario.bus.execute(scenario.command_from(fixture["commands"][0]))
	var after_t1: Dictionary = scenario.ledger.debug_state()
	var t2_spec: Dictionary = fixture["commands"][1]
	var rejected: Receipt = scenario.bus.execute(scenario.command_from(t2_spec))
	t.ok(not rejected.is_committed(), "T2 rejects after T1")
	t.dict_eq(scenario.ledger.debug_state(), after_t1, "rejected T2 changed nothing")


func _assert_inventory_matches(
	t: TestCase, scenario: Scenario, slot: String, expected: Dictionary, provenance: Dictionary
) -> void:
	var inv_id: EntityId = scenario.slot_id(slot)
	t.eq(scenario.ledger.used_units(inv_id), int(expected["units"]), "%s unit total matches" % slot)
	for def_name: String in expected.keys():
		if def_name == "units":
			continue
		var def_id: StringName = StringName(def_name)
		var qty: int = 0
		for lot: MaterialLot in scenario.ledger.lots_of(inv_id):
			if lot.def_id == def_id:
				qty += lot.quantity
				t.dict_eq(
					lot.provenance,
					provenance[def_name],
					"%s %s lot keeps fixture provenance" % [slot, def_name]
				)
		t.eq(qty, int(expected[def_name]), "%s %s quantity matches the fixture" % [slot, def_name])


func _reason_name(code: int) -> String:
	match code:
		Receipt.ErrorCode.NONE:
			return "NONE"
		Receipt.ErrorCode.INVALID_COMMAND:
			return "INVALID_COMMAND"
		Receipt.ErrorCode.UNKNOWN_SOURCE:
			return "UNKNOWN_SOURCE"
		Receipt.ErrorCode.UNKNOWN_TARGET:
			return "UNKNOWN_TARGET"
		Receipt.ErrorCode.SOURCE_IS_TARGET:
			return "SOURCE_IS_TARGET"
		Receipt.ErrorCode.INVALID_QUANTITY:
			return "INVALID_QUANTITY"
		Receipt.ErrorCode.INSUFFICIENT_SUPPLY:
			return "INSUFFICIENT_SUPPLY"
		Receipt.ErrorCode.CAPACITY_EXCEEDED:
			return "CAPACITY_EXCEEDED"
		Receipt.ErrorCode.REVISION_MISMATCH:
			return "REVISION_MISMATCH"
	return "UNKNOWN(%d)" % code
