## Validates and applies one transfer atomically.
##
## There is deliberately no public plan()/commit() pair: a caller cannot hold a
## plan across other mutations and commit it later. `execute()` is the single
## entry point and does validate-then-apply inside one synchronous call. As
## defence in depth the apply step re-checks every revision and every op against
## the live ledger before it mutates anything, so even an internally stale plan
## cannot partially commit.
##
## Line handling: caller lines are normalized to one op per source lot. Repeated
## lines for the same definition draw from the same lots and are merged, so a
## lot is either moved whole or split once — it can never be drained to a
## zero-quantity lot.
##
## Split semantics: the moved portion becomes a NEW lot id (stable IDs are never
## reused and a lot is never duplicated under two owners) carrying the source
## lot's provenance verbatim, so provenance survives the move.
class_name TransferPlanner
extends RefCounted

## Ops the apply phase understands.
enum Op { MOVE_WHOLE, SPLIT_OUT }


class Plan:
	extends RefCounted
	var command_id: StringName
	var actor_id: EntityId
	var source_id: EntityId
	var target_id: EntityId
	var ops: Array[Dictionary] = []
	var incoming_units: int = 0
	# Snapshots captured at validation time; re-checked before any mutation.
	var source_revision: int = -1
	var target_revision: int = -1
	var lot_quantities: Dictionary = {}   # lot key -> quantity at plan time
	var lot_locations: Dictionary = {}    # lot key -> location key at plan time


## Validates and applies a transfer. Returns a committed or rejected receipt and
## never partially applies. On rejection the ledger is untouched.
static func execute(ledger: Ledger, cmd: TransferCommand) -> Receipt:
	var error: Array[int] = []
	var plan: Plan = _plan(ledger, cmd, error)
	if plan == null:
		return Receipt.rejected(cmd.command_id if cmd != null else &"", error[0])
	return _apply(ledger, plan)


## Builds an ordered op list without mutating anything.
static func _plan(ledger: Ledger, cmd: TransferCommand, error: Array[int]) -> Plan:
	if cmd == null or cmd.actor_id == null or cmd.source_id == null or cmd.target_id == null:
		error.append(int(Receipt.ErrorCode.INVALID_COMMAND))
		return null
	var source: Inventory = ledger.get_inventory(cmd.source_id)
	var target: Inventory = ledger.get_inventory(cmd.target_id)
	if source == null:
		error.append(int(Receipt.ErrorCode.UNKNOWN_SOURCE))
		return null
	if target == null:
		error.append(int(Receipt.ErrorCode.UNKNOWN_TARGET))
		return null
	if source.id.equals(target.id):
		error.append(int(Receipt.ErrorCode.SOURCE_IS_TARGET))
		return null

	# Minimal fixture authorization: an actor may only move material out of an
	# inventory it owns. ASSUMPTION: M0 has no tribe/role/escrow policy, so
	# ownership of the SOURCE inventory is the whole rule and any inventory
	# without an owner is untouchable (default deny). Target ownership is not
	# checked because "put it in escrow" is explicitly allowed by FND-001.
	if source.owner_id == null or not source.owner_id.equals(cmd.actor_id):
		error.append(int(Receipt.ErrorCode.UNAUTHORIZED))
		return null

	if cmd.lines.is_empty():
		error.append(int(Receipt.ErrorCode.INVALID_QUANTITY))
		return null
	for line: Dictionary in cmd.lines:
		if int(line.get("quantity", 0)) <= 0 or String(line.get("def_id", "")).is_empty():
			error.append(int(Receipt.ErrorCode.INVALID_QUANTITY))
			return null
	if source.revision != cmd.expected_source_revision:
		error.append(int(Receipt.ErrorCode.REVISION_MISMATCH))
		return null

	# Normalize: per definition, sum every line that asks for it, keeping the
	# definition order of first appearance so the plan stays deterministic.
	var needed: Array[String] = []
	var need_by_def: Dictionary = {}
	for line: Dictionary in cmd.lines:
		var def_key: String = String(line["def_id"])
		if not need_by_def.has(def_key):
			needed.append(def_key)
			need_by_def[def_key] = 0
		need_by_def[def_key] = int(need_by_def[def_key]) + int(line["quantity"])

	var source_lots: Array[MaterialLot] = ledger.lots_of(source.id)
	var available: Dictionary = {}
	for lot: MaterialLot in source_lots:
		var def_key: String = String(lot.def_id)
		available[def_key] = int(available.get(def_key, 0)) + lot.quantity
	for def_key: String in needed:
		if int(available.get(def_key, 0)) < int(need_by_def[def_key]):
			error.append(int(Receipt.ErrorCode.INSUFFICIENT_SUPPLY))
			return null

	var result: Plan = Plan.new()
	result.command_id = cmd.command_id
	result.actor_id = cmd.actor_id
	result.source_id = source.id
	result.target_id = target.id
	result.source_revision = source.revision
	result.target_revision = target.revision
	var source_location_key: String = LocationRef.in_inventory(source.id).to_key()

	# Draw one op per lot: a lot is either moved whole or split exactly once.
	var carry: Dictionary = {}  # def key -> units still to take
	for def_key: String in needed:
		carry[def_key] = int(need_by_def[def_key])
	for lot: MaterialLot in source_lots:
		var def_key: String = String(lot.def_id)
		if int(carry.get(def_key, 0)) <= 0:
			continue
		var take: int = mini(lot.quantity, int(carry[def_key]))
		if take <= 0:
			continue
		carry[def_key] = int(carry[def_key]) - take
		result.ops.append({
			"op": Op.MOVE_WHOLE if take == lot.quantity else Op.SPLIT_OUT,
			"lot_id": lot.id.to_key(),
			"def_id": def_key,
			"quantity": take,
		})
		result.incoming_units += take
		result.lot_quantities[lot.id.to_key()] = lot.quantity
		result.lot_locations[lot.id.to_key()] = source_location_key
	for def_key: String in needed:
		if int(carry[def_key]) != 0:
			# Unreachable after the supply check; refuse rather than commit a
			# plan that does not move what was asked for.
			error.append(int(Receipt.ErrorCode.INSUFFICIENT_SUPPLY))
			return null

	if not target.has_capacity_for(ledger.used_units(target.id), result.incoming_units):
		error.append(int(Receipt.ErrorCode.CAPACITY_EXCEEDED))
		return null
	return result


## Re-checks an accepted plan against the live ledger. Nothing is mutated here,
## so a stale plan (another command ran in between) is rejected cleanly.
static func _still_valid(ledger: Ledger, plan: Plan, error: Array[int]) -> bool:
	var source: Inventory = ledger.get_inventory(plan.source_id)
	var target: Inventory = ledger.get_inventory(plan.target_id)
	if source == null or target == null:
		error.append(int(Receipt.ErrorCode.INVALID_COMMAND))
		return false
	if source.revision != plan.source_revision or target.revision != plan.target_revision:
		error.append(int(Receipt.ErrorCode.REVISION_MISMATCH))
		return false
	for op: Dictionary in plan.ops:
		var lot: MaterialLot = ledger.get_lot(_parse_id(op["lot_id"]))
		var lot_key: String = op["lot_id"]
		if lot == null or lot.location == null:
			error.append(int(Receipt.ErrorCode.INVALID_COMMAND))
			return false
		if int(plan.lot_quantities.get(lot_key, -1)) != lot.quantity \
				or String(plan.lot_locations.get(lot_key, "")) != lot.location.to_key():
			error.append(int(Receipt.ErrorCode.REVISION_MISMATCH))
			return false
		if int(op["quantity"]) <= 0 or int(op["quantity"]) > lot.quantity:
			error.append(int(Receipt.ErrorCode.INVALID_QUANTITY))
			return false
	if not target.has_capacity_for(ledger.used_units(target.id), plan.incoming_units):
		error.append(int(Receipt.ErrorCode.CAPACITY_EXCEEDED))
		return false
	return true


## Applies a plan, re-checking it against the live ledger first. `execute()` is
## the only caller, and it is the only path to mutation, so this is where a plan
## held across another mutation is caught. Nothing is mutated before the check
## passes.
static func _apply(ledger: Ledger, plan: Plan) -> Receipt:
	var stale: Array[int] = []
	if not _still_valid(ledger, plan, stale):
		return Receipt.rejected(plan.command_id, stale[0])
	var receipt: Receipt = Receipt.committed(plan.command_id)
	var source: Inventory = ledger.get_inventory(plan.source_id)
	var target: Inventory = ledger.get_inventory(plan.target_id)
	var target_location: LocationRef = LocationRef.in_inventory(target.id)

	for op: Dictionary in plan.ops:
		var lot: MaterialLot = ledger.get_lot(_parse_id(op["lot_id"]))
		var qty: int = int(op["quantity"])
		if int(op["op"]) == Op.MOVE_WHOLE:
			lot.location = target_location
			lot.revision += 1
			receipt.moves.append({
				"lot_id": lot.id.to_key(),
				"def_id": String(lot.def_id),
				"quantity": qty,
				"to": target.id.to_key(),
				"split": false,
			})
		else:
			# Split: shrink the source lot, register a new lot in the target with
			# the source's provenance. The source lot keeps its ID and history.
			lot.quantity -= qty
			lot.revision += 1
			var moved: MaterialLot = ledger.register_lot(
				lot.def_id, qty, lot.provenance, target_location
			)
			receipt.moves.append({
				"lot_id": moved.id.to_key(),
				"source_lot_id": lot.id.to_key(),
				"def_id": String(lot.def_id),
				"quantity": qty,
				"to": target.id.to_key(),
				"split": true,
			})

	source.revision += 1
	target.revision += 1
	receipt.source_revision_after = source.revision
	receipt.target_revision_after = target.revision
	receipt.source_used_after = ledger.used_units(source.id)
	receipt.target_used_after = ledger.used_units(target.id)
	return receipt


static func _parse_id(key: String) -> EntityId:
	var parts: PackedStringArray = key.split(":")
	if parts.size() != 2:
		return null
	return EntityId.create(StringName(parts[0]), int(parts[1]))
