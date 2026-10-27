## A named place that can hold lots. Membership is derived: a lot belongs to
## this inventory iff its (single) LocationRef points here, so there is no
## second copy of ownership to fall out of sync.
##
## owner_id is the minimal M0 authorization fixture: the actor allowed to move
## material OUT of this inventory. There is no role/tribe/permission model yet
## (that is M1+); an unowned inventory is nobody's to spend from (default deny).
##
## capacity_units is a HARNESS LIMIT used only to prove atomic rejection of an
## over-capacity transfer. It is not game balance and no gameplay code should
## read it as such. -1 means "unbounded (harness default)".
class_name Inventory
extends RefCounted

var id: EntityId
var label: String
var owner_id: EntityId
var capacity_units: int = -1
var revision: int = 0


static func create(
	p_id: EntityId,
	p_label: String,
	p_capacity_units: int = -1,
	p_owner_id: EntityId = null
) -> Inventory:
	if p_id == null:
		push_error("Inventory.create: null id")
		return null
	var inv: Inventory = Inventory.new()
	inv.id = p_id
	inv.label = p_label
	inv.capacity_units = p_capacity_units
	inv.owner_id = p_owner_id
	inv.revision = 0
	return inv


func is_owned_by(actor_id: EntityId) -> bool:
	if owner_id == null or actor_id == null:
		return false
	return owner_id.equals(actor_id)


func has_capacity_for(used_units: int, incoming_units: int) -> bool:
	if capacity_units < 0:
		return true
	return used_units + incoming_units <= capacity_units
