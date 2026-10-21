class_name BagCapacity
extends RefCounted
## The one capacity calculation (owner spec 31 §1, §6, §13; prompts 05:11). Every caller — the
## equipment container, the bag header, the inspect panel and the crafting preview — asks here, so
## the numbers can never drift apart.
##
##   total = base_slots (100) + Σ worn item's storage bonus
##   a bag's storage bonus = curve(level) + storage attributes inherited from its material + its
##   type's own storage_bonus
##   Pocket is 6 spaces per level (HISTORICAL, spec 31 §5) and comes only from an item's attribute,
##   never from its level.
## Cargo dinosaurs and boxes are separate inventories and never appear here (spec 31 §12).
## ASSUMPTION: the curves and storage_bonus values are data/bags.json's design values (spec 31 §15).

const BASE_SLOTS := 100

## Nothing a worn item adds to the bag.
static func empty_breakdown() -> Dictionary:
	return {"def_id": "", "bag_id": "", "level": 0, "base": 0, "pocket": 0, "capacity": 0, "storage": {}, "other": 0, "total": 0}

## The storage an item adds while worn, itemised: {"def_id", "bag_id", "level", "base", "pocket",
## "capacity", "storage" (other inherited keys), "other" (type bonus), "total"}.
## A bag type (ItemDef.bag_def) takes its base from data/bags.json's curve at the instance's level
## and may inherit only the storage attributes its type lists. Ordinary gear keeps the old rule
## (def.bag_slots plus any Pocket attribute), so clothing Pocket still adds spaces (spec 31 §7).
static func of_stack(s: ItemStack) -> Dictionary:
	var out := empty_breakdown()
	if s == null:
		return out
	var d := s.def()
	if d == null:
		return out
	out["def_id"] = str(s.def_id)
	out["level"] = s.level
	var bag_id: StringName = BagDef.id_of(d)
	out["bag_id"] = str(bag_id)
	var base := 0
	if bag_id != &"":
		base = BagDef.base_capacity(bag_id, s.level)
	else:
		base = maxi(0, d.bag_slots)
	out["base"] = base
	var total := base
	for key: Variant in s.attributes:
		var k := str(key)
		if k == "pocket":
			continue # its own line below
		if bag_id != &"" and not BagDef.can_inherit(bag_id, StringName(k)):
			continue # the material's trait stays on the material
		var per := BagDef.slots_per_point(k)
		if per <= 0:
			continue
		var points := _points(s.attributes[key])
		var added := points * per
		if added == 0:
			continue
		if k == "capacity":
			out["capacity"] = int(out["capacity"]) + added
		else:
			(out["storage"] as Dictionary)[k] = int((out["storage"] as Dictionary).get(k, 0)) + added
		total += added
	var pocket_lv := pocket_level(s)
	if bag_id == &"" or BagDef.can_inherit(bag_id, &"pocket"):
		out["pocket"] = pocket_lv * BagDef.slots_per_point("pocket")
		total += int(out["pocket"])
	if bag_id != &"":
		out["other"] = BagDef.storage_bonus(bag_id)
		total += int(out["other"])
	out["total"] = total
	return out

## A worn item's Pocket level: attributes.pocket, clamped to the configured maximum.
static func pocket_level(s: ItemStack) -> int:
	if s == null:
		return 0
	return clampi(_points(s.attributes.get("pocket", 0)), 0, BagDef.max_pocket_level())

## The whole inventory, itemised: {"base", "bag" (worn bags), "other" (clothing etc.),
## "bonus", "total", "worn": {slot: breakdown}}. count() is this function's "total".
static func inventory_total(inv: Inventory) -> Dictionary:
	var out := {"base": 0, "bag": 0, "other": 0, "bonus": 0, "total": 0, "worn": {}}
	if inv == null:
		return out
	out["base"] = maxi(0, inv.base_slots)
	var worn := {}
	for slot: String in inv.equipment:
		var v: Variant = inv.equipment[slot]
		if not v is ItemStack:
			continue
		var b := of_stack(v)
		var n := int(b.get("total", 0))
		if n == 0:
			continue
		worn[slot] = b
		if str(b.get("bag_id", "")) != "":
			out["bag"] = int(out["bag"]) + n
		else:
			out["other"] = int(out["other"]) + n
	out["bonus"] = int(out["bag"]) + int(out["other"])
	out["total"] = int(out["base"]) + int(out["bonus"])
	out["worn"] = worn
	return out

## The inventory's capacity. InventoryEquipment.capacity delegates here, so there is one formula.
static func count(inv: Inventory) -> int:
	return int(inventory_total(inv).get("total", 0))

## The bag type of an item id ("" for ordinary gear).
static func bag_id_of(def_id: StringName) -> StringName:
	return BagDef.id_of(Data.item(def_id) if Data else null)

static func is_bag(def_id: StringName) -> bool:
	return bag_id_of(def_id) != &""

## Spec 31 §4/§10: a crafted bag inherits the storage attributes of its chosen primary material,
## but only those its bag type lists as inheritable. Pocket comes only from a material that carries
## it. Every other attribute of the material stays on the material (it would be a false trait).
## ASSUMPTION: inheritance reads the primary (lead) instance the player picked, per spec 04's
## "only qualifying primary materials inherit attributes".
static func apply_inheritance(out: ItemStack, primary: ItemStack) -> void:
	if out == null or primary == null:
		return
	var bag_id := bag_id_of(out.def_id)
	if bag_id == &"":
		return
	for key: Variant in primary.attributes:
		var k := str(key)
		if not BagDef.can_inherit(bag_id, StringName(k)):
			out.attributes.erase(k)
			continue
		if BagDef.slots_per_point(k) <= 0 and k != "pocket":
			out.attributes.erase(k) # neither a storage attribute nor Pocket: keep the material's
			continue
		out.attributes[k] = primary.attributes[key]

## What the material would pass on, for the crafting preview: {key: points}.
static func inherited_attributes(out_def_id: StringName, primary: ItemStack) -> Dictionary:
	var out := {}
	var bag_id := bag_id_of(out_def_id)
	if bag_id == &"" or primary == null:
		return out
	for key: Variant in primary.attributes:
		var k := str(key)
		if BagDef.can_inherit(bag_id, StringName(k)) and _points(primary.attributes[key]) != 0:
			out[k] = primary.attributes[key]
	return out

## A JSON float for -1 points reads as "missing": negatives add nothing.
static func _points(v: Variant) -> int:
	if v is int or v is float:
		return maxi(0, int(v))
	return 0
