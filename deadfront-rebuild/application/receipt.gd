## The immutable outcome of one command. Stored by the command bus under the
## command_id and returned verbatim on replay.
class_name Receipt
extends RefCounted

enum Status { COMMITTED = 0, REJECTED = 1 }

enum ErrorCode {
	NONE = 0,
	INVALID_COMMAND = 1,
	UNKNOWN_SOURCE = 2,
	UNKNOWN_TARGET = 3,
	SOURCE_IS_TARGET = 4,
	INVALID_QUANTITY = 5,
	INSUFFICIENT_SUPPLY = 6,
	CAPACITY_EXCEEDED = 7,
	REVISION_MISMATCH = 8,
	UNAUTHORIZED = 9,
}

var command_id: StringName
var status: Status
var error: int
## Per-line applied moves, in commit order:
## {"lot_id": String, "def_id": String, "quantity": int, "to": String}
var moves: Array[Dictionary] = []
var source_revision_after: int = -1
var target_revision_after: int = -1
var source_used_after: int = -1
var target_used_after: int = -1


static func committed(p_command_id: StringName) -> Receipt:
	var r: Receipt = Receipt.new()
	r.command_id = p_command_id
	r.status = Status.COMMITTED
	r.error = ErrorCode.NONE
	return r


static func rejected(p_command_id: StringName, p_error: int) -> Receipt:
	var r: Receipt = Receipt.new()
	r.command_id = p_command_id
	r.status = Status.REJECTED
	r.error = p_error
	return r


func is_committed() -> bool:
	return status == Status.COMMITTED


## Canonical, comparable form. Tests compare these directly to prove a replay
## returns the original receipt rather than a fresh one.
func to_dict() -> Dictionary:
	var move_dicts: Array = []
	for move: Dictionary in moves:
		move_dicts.append(move.duplicate(true))
	return {
		"command_id": String(command_id),
		"status": int(status),
		"error": int(error),
		"moves": move_dicts,
		"source_revision_after": source_revision_after,
		"target_revision_after": target_revision_after,
		"source_used_after": source_used_after,
		"target_used_after": target_used_after,
	}


func _to_string() -> String:
	return "Receipt(%s, status=%d, error=%d)" % [String(command_id), int(status), int(error)]
