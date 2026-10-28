class_name PetGear
extends RefCounted
## SADDLES: the survivor puts gear on and off one of her tames, bag <-> PetRecord.gear. The fit rule is
## the record's (saddle size class). Taking the saddle off the tame she is riding dismounts her first,
## through the normal dismount path, so she lands beside it instead of floating in the air.

## Wear the bag item at `index` on `rec`. Returns "" or the refusal (also shown as a notice).
static func equip(p: Player, rec: PetRecord, index: int) -> String:
	var why := rec.gear.equip_from(p.inventory, index, rec.saddle_fit)
	if why != "":
		p.notice(why)
	else:
		print("[saddle] equipped %s on %s" % [rec.saddle().def_id if rec.saddle() else &"?", rec.species])
	return why

static func unequip(p: Player, rec: PetRecord, slot: StringName = &"saddle") -> String:
	if rec.gear.worn(slot) == null:
		return "Nothing worn there"
	if not p.inventory.can_accept(rec.gear.worn(slot)):
		p.notice("Bag is full")
		return "Bag is full"
	if slot == &"saddle" and p.mounted_on and is_instance_valid(p.mounted_on) and p.mounted_on.pet_record == rec:
		p.dismount()
	var why := rec.gear.unequip_to(p.inventory, slot)
	if why != "":
		p.notice(why)
	else:
		print("[saddle] unequipped %s from %s" % [slot, rec.species])
	return why

## Every bag index holding a saddle, fitting ones first (the Gear screen's list).
static func bag_saddles(inv: Inventory, rec: PetRecord) -> Array[int]:
	var fit: Array[int] = []
	var other: Array[int] = []
	for i in inv.slot_count:
		var s := inv.slots[i]
		if s and s.def() and s.def().has_category(&"saddle"):
			(fit if rec.saddle_fit(s) == "" else other).append(i)
	fit.append_array(other)
	return fit
