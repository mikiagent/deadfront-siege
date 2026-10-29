class_name Spoilage
extends RefCounted
## FOODTORPOR (owner 2026-10-29): food spoils. A perishable lot is stamped with the unix time it spoils
## at (attribute "spoil_at") the first time the survivor's bag ticks it, so offline time counts. At
## that time it becomes Spoiled Meat (meat) or Rot (any other food), one for one. Lengths and the
## meat/plant split are data: foods.json "spoilage". Spec 08 forbade a freshness timer the design did
## not ask for; the owner asked for this one.

const ATTR := "spoil_at"
const SPOILED_MEAT := &"spoiled_meat"
const ROT := &"rot"

static func _rules() -> Dictionary:
	var r: Variant = FoodEffects.doc().get("spoilage", {})
	return r as Dictionary if r is Dictionary else {}

## Real seconds a fresh lot of `def` keeps; 0 = never spoils.
static func seconds_for(def: ItemDef) -> float:
	if def == null or not def.has_category(&"food"):
		return 0.0
	for row: Variant in _rules().get("seconds_by_category", []):
		if row is Array and (row as Array).size() >= 2 and def.has_category(StringName(str(row[0]))):
			return float(row[1])
	return 0.0

static func spoils_into(def: ItemDef) -> StringName:
	for cat: Variant in _rules().get("meat_categories", ["meat"]):
		if def.has_category(StringName(str(cat))):
			return SPOILED_MEAT
	return ROT

static func now() -> float:
	return Time.get_unix_time_from_system()

## Seconds left before `s` spoils; INF when it never does or is not stamped yet.
static func seconds_left(s: ItemStack, at: float = -1.0) -> float:
	if s == null or not s.attributes.has(ATTR):
		return INF
	return float(s.attributes[ATTR]) - (now() if at < 0.0 else at)

## Stamps fresh perishable lots and turns spoiled ones over. Spoiled lots in `inv` become the spoiled
## item in place; with `out` (the Food Bag ticking into the main bag) they leave `inv` for `out`
## instead. Returns how many lots spoiled.
static func tick(inv: Inventory, at: float = -1.0, out: Inventory = null) -> int:
	if inv == null:
		return 0
	if at < 0.0:
		at = now()
	var spoiled := 0
	for i in inv.slot_count:
		var s := inv.slots[i]
		if s == null or s.is_locked():
			continue
		var secs := seconds_for(s.def())
		if secs <= 0.0:
			continue
		if not s.attributes.has(ATTR):
			s.attributes[ATTR] = at + secs
			continue
		if float(s.attributes[ATTR]) > at:
			continue
		var rotten := ItemStack.make(spoils_into(s.def()), s.count)
		print("[spoil] %s x%d -> %s" % [s.def_id, s.count, rotten.def_id])
		spoiled += 1
		if out == null:
			Inventory.mint(rotten)
			inv.slots[i] = rotten
			continue
		inv.slots[i] = null
		var left := out.add(rotten)
		if left > 0:
			# shortcut: a full main bag loses the overflow rot; a ground drop would keep it.
			print("[spoil] bag full, %d %s lost" % [left, rotten.def_id])
	if spoiled > 0:
		inv.changed.emit()
	return spoiled
