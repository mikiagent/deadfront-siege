## One material lot: a discrete, uniquely identified quantity of one definition
## with provenance and exactly one authoritative location.
##
## M0 models no traits, quality or spoilage (those are MAT/FOD, not approved).
## provenance is opaque fixture data carried verbatim across splits/transfers so
## a test can prove the moved quantity is the same sourced material, not a clone.
class_name MaterialLot
extends RefCounted

var id: EntityId
var def_id: StringName
var quantity: int
var provenance: Dictionary  # opaque origin data, never reinterpreted here
var location: LocationRef
var revision: int = 0


static func create(
	p_id: EntityId,
	p_def_id: StringName,
	p_quantity: int,
	p_provenance: Dictionary,
	p_location: LocationRef
) -> MaterialLot:
	if p_id == null or p_location == null:
		push_error("MaterialLot.create: null id/location")
		return null
	if p_quantity <= 0:
		push_error("MaterialLot.create: non-positive quantity %d" % p_quantity)
		return null
	var lot: MaterialLot = MaterialLot.new()
	lot.id = p_id
	lot.def_id = p_def_id
	lot.quantity = p_quantity
	lot.provenance = p_provenance.duplicate(true)
	lot.location = p_location
	lot.revision = 0
	return lot


## Copies everything except id/location/quantity/revision. Used when a lot
## splits: the new lot keeps the source lot's provenance and def_id.
func provenance_copy() -> Dictionary:
	return provenance.duplicate(true)
