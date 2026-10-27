## Synchronous command bus with a receipt ledger.
##
## One entry point: execute(). It first checks the ledger by command_id and, if
## the ID was seen before, returns the stored receipt untouched. Otherwise it
## validates the command, plans it without mutating, and only on a fully valid
## plan commits and records the receipt. A rejected command is also recorded, so
## a repeat of a rejected command_id returns the same rejection without a second
## attempt (and without a second mutation).
##
## The bus is synchronous and single-threaded by design for M0: two "competing"
## commands are simply executed in sequence, and the second sees the first's
## revision bump and loses. That is the compare-and-swap the spec asks for.
class_name CommandBus
extends RefCounted

var ledger: Ledger
var _receipts: Dictionary = {}  # String command_id -> Receipt


func _init(p_ledger: Ledger) -> void:
	ledger = p_ledger


func execute(cmd: TransferCommand) -> Receipt:
	if cmd == null:
		return Receipt.rejected(&"", Receipt.ErrorCode.INVALID_COMMAND)
	var key: String = String(cmd.command_id)
	if _receipts.has(key):
		return _receipts[key]

	if ledger.get_actor(cmd.actor_id) == null:
		var missing: Receipt = Receipt.rejected(cmd.command_id, Receipt.ErrorCode.INVALID_COMMAND)
		_receipts[key] = missing
		return missing

	var error_out: Array = []
	var accepted: TransferPlanner.Plan = TransferPlanner.plan(ledger, cmd, error_out)
	var receipt: Receipt
	if accepted == null:
		var code: int = int(Receipt.ErrorCode.INVALID_COMMAND)
		if not error_out.is_empty():
			code = int(error_out[0])
		receipt = Receipt.rejected(cmd.command_id, code)
	else:
		receipt = TransferPlanner.commit(ledger, accepted)

	_receipts[key] = receipt
	return receipt


func receipt_for(command_id: StringName) -> Receipt:
	return _receipts.get(String(command_id))


func receipt_count() -> int:
	return _receipts.size()


func applied_command_ids() -> Array[String]:
	var out: Array[String] = []
	for key: String in _receipts.keys():
		out.append(key)
	out.sort()
	return out
