## Plans and commits a transfer in two separate, explicit phases.
##
## plan() reads the ledger and builds an ordered list of primitive ops without
## mutating anything. commit() applies an accepted plan. Because validation
## happens entirely in plan(), a rejected transfer performs no mutation at all —
## no partial debit, no orphaned split, no revision bump.
##
## Split semantics: a line that takes fewer units than a lot holds splits the
## lot. The moved portion becomes a NEW lot id (stable IDs are never reused and a
## lot is never duplicated under two owners) that carries the source lot's
## provenance verbatim, so provenance survives the move.
class_name TransferPlanner
extends RefCounted

## Ops the commit phase understands.
enum Op { MOVE_WHOLE, SPLIT_OUT }


class Plan:
	extends RefCounted
	var command_id: StringName
	var actor_id: EntityId
	var source_id: EntityId
	var target_id: EntityId
	var ops: Array[Dictionary] = []
	var incoming_units: int = 0
	# Snapshot of expected revisions/quantities captured at plan time.
	var source_revision: int = -1
	var target_revision: int = -1


## Plans a transfer. Returns null and sets error_out when rejected.
static func plan(ledger: Ledger, cmd: TransferCommand, error_out: Array) -> Plan:
	error_out.clear()
	if cmd == null:
		error_out.append(int(Receipt.ErrorCode.INVALID_COMMAND))
		return null
	if cmd.actor_id == null or cmd.source_id == null or cmd.target_id == null:
		error_out.append(int(Receipt.ErrorCode.INVALID_COMMAND))
		return null
	# ASSUMPTION: M0 has no permission model yet, so any non-null actor_id may
	# move material between the two inventories it names. Authorization is an M1+
	# concern (ACTOR/tribe rules are not approved).
	var source: Inventory = ledger.get_inventory(cmd.source_id)
	var target: Inventory = ledger.get_inventory(cmd.target_id)
	if source == null:
		error_out.append(int(Receipt.ErrorCode.UNKNOWN_SOURCE))
		return null
	if target == null:
		error_out.append(int(Receipt.ErrorCode.UNKNOWN_TARGET))
		return null
	if source.id.equals(target.id):
		error_out.append(int(Receipt.ErrorCode.SOURCE_IS_TARGET))
		return null
	if cmd.lines.is_empty():
		error_out.append(int(Receipt.ErrorCode.INVALID_QUANTITY))
		return null
	for line: Dictionary in cmd.lines:
		if int(line.get("quantity", 0)) <= 0 or String(line.get("def_id", "")).is_empty():
			error_out.append(int(Receipt.ErrorCode.INVALID_QUANTITY))
			return null
	if source.revision != cmd.expected_source_revision:
		error_out.append(int(Receipt.ErrorCode.REVISION_MISMATCH))
		return null

	# Supply check first: per definition, against all source-held lots.
	var source_lots: Array[MaterialLot] = ledger.lots_of(source.id)
	var available: Dictionary = {}
	for lot: MaterialLot in source_lots:
		var key: String = String(lot.def_id)
		available[key] = int(available.get(key, 0)) + lot.quantity
	for line: Dictionary in cmd.lines:
		var key: String = String(line["def_id"])
		available[key] = int(available.get(key, 0)) - int(line["quantity"])
		if int(available[key]) < 0:
			error_out.append(int(Receipt.ErrorCode.INSUFFICIENT_SUPPLY))
			return null

	# Build ops against a per-lot remaining map so repeated lines draw in order.
	var remaining: Dictionary = {}  # lot key -> units left in that lot
	for lot: MaterialLot in source_lots:
		remaining[lot.id.to_key()] = lot.quantity

	var result: Plan = Plan.new()
	result.command_id = cmd.command_id
	result.actor_id = cmd.actor_id
	result.source_id = source.id
	result.target_id = target.id
	result.source_revision = source.revision
	result.target_revision = target.revision

	for line: Dictionary in cmd.lines:
		var need: int = int(line["quantity"])
		var def_id: StringName = line["def_id"]
		for lot: MaterialLot in source_lots:
			if need <= 0:
				break
			if lot.def_id != def_id:
				continue
			var lot_key: String = lot.id.to_key()
			var left: int = int(remaining[lot_key])
			if left <= 0:
				continue
			var take: int = mini(left, need)
			remaining[lot_key] = left - take
			need -= take
			if take == left and take == lot.quantity:
				result.ops.append({
					"op": Op.MOVE_WHOLE,
					"lot_id": lot_key,
					"def_id": String(def_id),
					"quantity": take,
				})
			else:
				result.ops.append({
					"op": Op.SPLIT_OUT,
					"lot_id": lot_key,
					"def_id": String(def_id),
					"quantity": take,
				})
			result.incoming_units += take
		if need > 0:
			# Supply map said enough; reaching here means the plan itself is
			# inconsistent. Refuse rather than commit a partial plan.
			error_out.append(int(Receipt.ErrorCode.INSUFFICIENT_SUPPLY))
			return null

	if not target.has_capacity_for(ledger.used_units(target.id), result.incoming_units):
		error_out.append(int(Receipt.ErrorCode.CAPACITY_EXCEEDED))
		return null
	return result


## Applies an accepted plan. The plan was validated against this exact ledger
## state, so every mutation here is unconditional bookkeeping.
static func commit(ledger: Ledger, accepted: Plan) -> Receipt:
	var receipt: Receipt = Receipt.committed(accepted.command_id)
	var source: Inventory = ledger.get_inventory(accepted.source_id)
	var target: Inventory = ledger.get_inventory(accepted.target_id)
	var target_location: LocationRef = LocationRef.in_inventory(target.id)

	for op: Dictionary in accepted.ops:
		var lot: MaterialLot = ledger.get_lot(_parse_id(ledger, op["lot_id"]))
		if lot == null:
			# Commit must never partially apply; treat as an internal error.
			push_error("TransferPlanner.commit: missing lot %s" % op["lot_id"])
			return Receipt.rejected(accepted.command_id, int(Receipt.ErrorCode.INVALID_COMMAND))
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


static func _parse_id(ledger: Ledger, key: String) -> EntityId:
	var parts: PackedStringArray = key.split(":")
	if parts.size() != 2:
		return null
	return EntityId.create(StringName(parts[0]), int(parts[1]))
