## A request to move real material from one inventory to another.
##
## command_id is the idempotence key: the command bus replays its stored receipt
## for a repeated command_id and never mutates twice. expected_source_revision
## is the compare-and-swap guard the caller saw; it is what makes two competing
## transfers for the same final unit resolve to exactly one winner.
##
## Immutable after construction.
class_name TransferCommand
extends RefCounted

var command_id: StringName
var actor_id: EntityId
var source_id: EntityId
var target_id: EntityId
var expected_source_revision: int
## Array of {"def_id": StringName, "quantity": int}, ordered by the caller.
var lines: Array[Dictionary] = []


static func create(
	p_command_id: StringName,
	p_actor_id: EntityId,
	p_source_id: EntityId,
	p_target_id: EntityId,
	p_expected_source_revision: int
) -> TransferCommand:
	if String(p_command_id).is_empty():
		push_error("TransferCommand.create: empty command_id")
		return null
	var cmd: TransferCommand = TransferCommand.new()
	cmd.command_id = p_command_id
	cmd.actor_id = p_actor_id
	cmd.source_id = p_source_id
	cmd.target_id = p_target_id
	cmd.expected_source_revision = p_expected_source_revision
	return cmd


## Fluent builder; returns self so callers can chain.
func with_line(def_id: StringName, quantity: int) -> TransferCommand:
	lines.append({"def_id": def_id, "quantity": quantity})
	return self


func to_dict() -> Dictionary:
	var line_dicts: Array = []
	for line: Dictionary in lines:
		line_dicts.append({"def_id": String(line["def_id"]), "quantity": int(line["quantity"])})
	return {
		"command_id": String(command_id),
		"actor_id": actor_id.to_key() if actor_id != null else "",
		"source_id": source_id.to_key() if source_id != null else "",
		"target_id": target_id.to_key() if target_id != null else "",
		"expected_source_revision": expected_source_revision,
		"lines": line_dicts,
	}
