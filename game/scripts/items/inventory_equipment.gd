class_name InventoryEquipment
extends RefCounted
## The equipment container and bag capacity of an Inventory (W2-INV, equip-02, spec 05:11). Worn
## gear lives in Inventory.equipment, out of the bag rows; each worn item's bag bonus adds slots.
## Inventory delegates equip_at, unequip, bag_bonus and capacity here.

## Wear the exact item at bag `index`. Whatever was worn in that slot swaps into the vacated bag
## slot, so equipping never needs a free slot.
static func equip_at(inv: Inventory, index: int, slot: StringName) -> bool:
	if index < 0 or index >= inv.slot_count:
		return false
	var item := inv.slots[index]
	if item == null or item.def_id == Inventory.LOCK or item.is_locked() or item.count != 1:
		return false
	var want := Inventory.slot_for(item.def())
	var target := slot if slot != &"" else want
	# Only into its own slot (a ring may take either accessory slot).
	if want == &"" or not (target == want or (want == &"accessory1" and target == &"accessory2")):
		return false
	if target == &"accessory1" and inv.worn(&"accessory1") != null and inv.worn(&"accessory2") == null:
		target = &"accessory2"
	var old := inv.worn(target)
	inv.slots[index] = old
	inv.equipment[str(target)] = item
	# Spec 05:11: the bag grows or shrinks by the swap's bonus difference; a shrink that would cut
	# off occupied slots is refused and the swap undone.
	if not resize(inv, inv.slot_count + bag_bonus(item) - bag_bonus(old)):
		inv.slots[index] = item
		if old:
			inv.equipment[str(target)] = old
		else:
			inv.equipment.erase(str(target))
		return false
	if inv.equipped_tool_index == index:
		inv.equipped_tool_index = -1 # the held tool is the item just worn
	inv.changed.emit()
	return true

## Back into the bag, which loses the slots this item added (spec 05:11). Refused (the gear stays
## worn) when what the bag holds plus this item would not fit: never drop gear.
static func unequip(inv: Inventory, slot: StringName) -> bool:
	var v: Variant = inv.equipment.get(str(slot))
	if v is ItemStack:
		var cap := inv.slot_count - bag_bonus(v)
		if inv.used_slots() + 1 > cap or not resize(inv, cap):
			return false
		inv.equipment.erase(str(slot))
		inv.add(v)
	else:
		inv.equipment.erase(str(slot))
	inv.changed.emit()
	return true

## Spec 05:11 / spec 31 §6: the slots a worn item adds. One formula for the whole game: the bag
## type's capacity curve at the instance's level plus the storage attributes it inherited plus the
## item's Pocket x 6 (BagCapacity). Ordinary gear keeps its def's bag_slots.
static func bag_bonus(s: ItemStack) -> int:
	return int(BagCapacity.of_stack(s).get("total", 0))

## Base slots plus every worn item's bonus, counted from what is worn now (so nothing adds twice).
## The server keeps worn gear in its bag by index (int form), which adds nothing.
static func capacity(inv: Inventory) -> int:
	return BagCapacity.count(inv)

## Resize to `cap`. A smaller bag first moves single items out of the cut tail into free slots below
## it, and refuses (changing nothing) when they do not fit or a multi-slot item is in the tail.
static func resize(inv: Inventory, cap: int) -> bool:
	if cap >= inv.slot_count:
		inv.grow_to(cap)
		return true
	var tail: Array[int] = []
	for i in range(cap, inv.slot_count):
		if inv.slots[i] != null:
			if inv.slots[i].def_id == Inventory.LOCK or inv.slots[i].slot_span() > 1:
				return false
			tail.append(i)
	var free: Array[int] = []
	for i in cap:
		if inv.slots[i] == null and free.size() < tail.size():
			free.append(i)
	if free.size() < tail.size():
		return false
	for k in tail.size():
		inv.slots[free[k]] = inv.slots[tail[k]]
		if inv.equipped_tool_index == tail[k]:
			inv.equipped_tool_index = free[k]
	inv.slot_count = cap
	inv.slots.resize(cap)
	return true

## Saved worn gear (extras "worn"), or the pre-W2-INV def-id "equipment" form: that item (highest
## level) moves out of the bag into its slot. Then the bag takes the capacity the worn gear gives
## (a shrink that would cut off items is skipped: never delete). `seen` holds the uids already
## loaded (home cargo, the bag): a worn row repeating one is reminted. A real item that can no
## longer be worn where it was saved (its def's slot changed) goes to the bag and is logged.
static func load_worn(inv: Inventory, d: Dictionary, seen: Dictionary) -> void:
	var w: Variant = d.get("worn", null)
	var unworn: Array[ItemStack] = []
	if w is Dictionary:
		for slot: Variant in w:
			var row: Variant = w[slot]
			if not row is Dictionary:
				continue
			var s := ItemStack.from_dict(row)
			if s.def() == null:
				continue # not an item of this build (the lock marker, an unknown id)
			# Trust boundary: one unit at a reachable level, a uid of its own.
			s.count = 1
			s.level = clampi(s.level, 1, 60)
			if seen.has(s.uid):
				s.remint_uid() # spec 05:26 duplicate IDs: the bag (or cargo) copy keeps it
			Inventory.mint(s)
			seen[s.uid] = true
			var want := Inventory.slot_for(s.def())
			if StringName(str(slot)) in Inventory.EQUIP_SLOTS and want != &"" and (want == StringName(str(slot)) or (want == &"accessory1" and str(slot) == "accessory2")):
				inv.equipment[str(slot)] = s
			else:
				unworn.append(s)
	else:
		var legacy: Variant = d.get("equipment", {})
		if legacy is Dictionary:
			for slot: Variant in legacy:
				inv.equip(StringName(str(slot)), StringName(str(legacy[slot])))
	resize(inv, capacity(inv))
	for s in unworn:
		print("[inv] load: worn %s L%d cannot be worn there any more; moved to the bag" % [s.def_id, s.level])
		inv.add_growing(s) # spec 05:11 never delete: a full bag grows rather than drop it
