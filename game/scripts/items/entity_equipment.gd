class_name EntityEquipment
extends RefCounted
## SADDLES: the gear one entity other than the survivor wears (a tame now, a tribe member once one
## exists in code). A small {slot: ItemStack} dict; a worn item lives here, out of every bag, and
## saves with its owner's row. Equip moves the exact instance from a bag, unequip puts it back; the
## owner's own fit rule (a saddle's size class) is passed in, so this stays species-agnostic.

signal changed

## A tame's slots. Room for "armor" and "bag" later: add the slot here and a category in slot_of.
const TAME_SLOTS: Array[StringName] = [&"saddle"]
## A tribe member would wear the survivor's own seven slots (Inventory.EQUIP_SLOTS).
## TRIBE M1: TribeRecord.equipment uses these seven.
const HUMAN_SLOTS: Array[StringName] = [&"weapon", &"head", &"body", &"arms", &"legs", &"accessory1", &"accessory2"]

var allowed: Array[StringName] = []
var slots: Dictionary = {}  # slot name (String) -> ItemStack

func _init(p_allowed: Array[StringName] = TAME_SLOTS) -> void:
	allowed = p_allowed.duplicate()

## The slot an item goes in: saddles in "saddle", everything else where the survivor would wear it.
static func slot_of(def: ItemDef) -> StringName:
	if def == null:
		return &""
	if def.has_category(&"saddle"):
		return &"saddle"
	# TRIBE M1 ASSUMPTION: a member's work tool (pick, axe, knife, hoe) is held in the weapon hand, the
	# one hand slot a human entity has; the survivor keeps tools in her bag (Inventory.slot_for is unchanged).
	if def.has_category(&"tool") and def.tool_class != &"none" and def.tool_class != &"":
		return &"weapon"
	return Inventory.slot_for(def)

func worn(slot: StringName) -> ItemStack:
	return slots.get(str(slot), null)

func is_empty() -> bool:
	return slots.is_empty()

## Put `stack` in `slot` with no bag involved (loading, labs). Returns what was there.
func put(slot: StringName, stack: ItemStack) -> ItemStack:
	var old := worn(slot)
	if stack == null:
		slots.erase(str(slot))
	else:
		slots[str(slot)] = stack
	changed.emit()
	return old

## Why the bag item at `index` cannot be worn here, or "" when it can. `fits` is the owner's rule:
## (stack) -> String, "" = fits.
func equip_refusal(inv: Inventory, index: int, fits: Callable = Callable()) -> String:
	if inv == null or index < 0 or index >= inv.slot_count or inv.slots[index] == null:
		return "Nothing there"
	var s := inv.slots[index]
	if s.def_id == Inventory.LOCK or s.count != 1:
		return "Cannot wear that"
	if s.is_locked():
		return "It is locked"
	var slot := slot_of(s.def())
	if slot == &"" or not (slot in allowed):
		return "Cannot wear that"
	return str(fits.call(s)) if fits.is_valid() else ""

## Wear the exact instance at bag `index`; whatever was in that slot goes back into the same bag cell,
## so equipping never needs a free slot. Returns "" or the refusal.
func equip_from(inv: Inventory, index: int, fits: Callable = Callable()) -> String:
	var why := equip_refusal(inv, index, fits)
	if why != "":
		return why
	var s := inv.slots[index]
	var slot := slot_of(s.def())
	inv.slots[index] = worn(slot)
	slots[str(slot)] = s
	inv.changed.emit()
	changed.emit()
	return ""

## Back into `inv`. Refused (the item stays worn) when the bag has no free slot: never drop gear.
func unequip_to(inv: Inventory, slot: StringName) -> String:
	var s := worn(slot)
	if s == null:
		return "Nothing worn there"
	if inv == null or inv.add(s.duplicate_stack()) > 0:
		return "Bag is full"
	slots.erase(str(slot))
	changed.emit()
	return ""

func to_dict() -> Dictionary:
	var out := {}
	for k in slots:
		out[k] = (slots[k] as ItemStack).to_dict()
	return out

## Unknown slots and rows that are not item instances are dropped; an old save has none ({}).
static func from_dict(d: Variant, p_allowed: Array[StringName] = TAME_SLOTS) -> EntityEquipment:
	var e := EntityEquipment.new(p_allowed)
	if not d is Dictionary:
		return e
	for k in d:
		var row: Variant = d[k]
		if StringName(str(k)) in e.allowed and row is Dictionary:
			var s := ItemStack.from_dict(row)
			if s != null and s.def() != null and slot_of(s.def()) == StringName(str(k)):
				e.slots[str(k)] = s
	return e
