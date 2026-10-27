## A named place that can hold lots. Membership is derived: a lot belongs to
## this inventory iff its (single) LocationRef points here, so there is no
## second copy of ownership to fall out of sync.
##
## capacity_units is a HARNESS LIMIT used only to prove atomic rejection of an
## over-capacity transfer. It is not game balance and no gameplay code should
## read it as such. -1 means "unbounded (harness default)".
class_name Inventory
extends RefCounted

var id: EntityId
var label: String
var capacity_units: int = -1
var revision: int = 0


static func create(p_id: EntityId, p_label: String, p_capacity_units: int = -1) -> Inventory:
	if p_id == null:
		push_error("Inventory.create: null id")
		return null
	var inv: Inventory = Inventory.new()
	inv.id = p_id
	inv.label = p_label
	inv.capacity_units = p_capacity_units
	inv.revision = 0
	return inv


func has_capacity_for(used_units: int, incoming_units: int) -> bool:
	if capacity_units < 0:
		return true
	return used_units + incoming_units <= capacity_units
