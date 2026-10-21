class_name InventoryMigration
extends RefCounted
## Saved rows into an Inventory (W2-INV, owner 2026-10-20, prompts 05/08). A stacked row of a def
## that no longer stacks splits into one instance per unit; units with no free slot go to the
## overflow container (the player's home cargo), else the container grows. Nothing is deleted and
## every split is logged. A uid already held (home cargo, an earlier row) is reminted, so each
## instance keeps an identity of its own (spec 05:26 "Test duplicate IDs").

## A load never deletes, but a forged save must not allocate without bound.
## ASSUMPTION: 100k units is far above any legit legacy container (60 cargo rows x 999).
const MAX_LOAD_UNITS := 100000

## Rows keep their slot. The container first grows to the saved row count, so one that grew (home
## cargo past its 60, a bag with Pocket slots) reloads as it was and does not migrate again.
static func load_into(inv: Inventory, raw: Array, overflow: Inventory) -> void:
	inv.slots.fill(null)
	var last := -1
	for i in mini(raw.size(), MAX_LOAD_UNITS):
		if raw[i] is Dictionary:
			last = i
	inv.grow_to(last + 1)
	var seen := overflow.uids() if overflow != null and overflow != inv else {}
	var extra: Array[ItemStack] = []
	var units := 0
	for i in raw.size():
		var row: Variant = raw[i]
		if not row is Dictionary:
			continue
		var s := ItemStack.from_dict(row)
		if s.def_id == Inventory.LOCK:
			if i < inv.slot_count:
				inv.slots[i] = s
			continue
		if s.count <= 0:
			continue
		units += s.count
		if units > MAX_LOAD_UNITS:
			push_warning("[inv] load stopped at %d units; row %d onward is not loaded" % [MAX_LOAD_UNITS, i])
			break
		var keep := mini(s.count, s.def().stack_max) if s.def() else s.count
		for k in s.count - keep:
			var unit := s.duplicate_stack()
			unit.count = 1
			unit.uid = ""
			extra.append(unit)
		s.count = keep
		if seen.has(s.uid):
			s.remint_uid() # the first holder keeps the uid
		Inventory.mint(s)
		if s.uid != "":
			seen[s.uid] = true
		if i < inv.slot_count:
			inv.slots[i] = s
		else:
			extra.append(s)
	inv.load_uids = seen
	_clear_orphan_locks(inv)
	if not extra.is_empty():
		_place_extra(inv, extra, overflow)

static func _place_extra(inv: Inventory, extra: Array[ItemStack], overflow: Inventory) -> void:
	var dest := overflow if overflow != null and overflow != inv else inv
	var here := 0
	var moved := {} # id -> units sent to the overflow container, for the log
	var self_full := false
	var dest_full := dest == inv
	for s in extra:
		if not self_full:
			if inv.add(s) == 0:
				here += 1
				continue
			self_full = true # nothing more fits; the rest skips the O(n) scan
		if dest != inv:
			moved[str(s.def_id)] = int(moved.get(str(s.def_id), 0)) + s.count # what add() left over
		if not dest_full:
			if dest.add(s) == 0:
				continue
			dest_full = true
		_append(dest, s)
		if dest == inv:
			here += 1
	var parts := PackedStringArray()
	for id: String in moved:
		parts.append("%s x%d" % [id, moved[id]])
	var away := ", %d to home storage (%s)" % [extra.size() - here, ", ".join(parts)] if not parts.is_empty() else ""
	print("[inv] migration: %d more instances from split stacks, %d kept here%s; bag %d/%d" % [extra.size(), here, away, inv.used_slots(), inv.slot_count])

## Grow by the item's span and put it in the new tail slots.
static func _append(inv: Inventory, s: ItemStack) -> void:
	var span := maxi(1, s.slot_span())
	inv.grow_to(inv.slot_count + span)
	var c := s.duplicate_stack()
	s.count = 0
	Inventory.mint(c)
	if span > 1:
		inv.place_span(c, inv.slot_count - span)
	else:
		inv.slots[inv.slot_count - 1] = c

## A lock whose anchor is gone would block its slot forever.
static func _clear_orphan_locks(inv: Inventory) -> void:
	var slots := inv.slots
	for i in inv.slot_count:
		var s := slots[i]
		if s == null or s.def_id != Inventory.LOCK:
			continue
		var a := int(s.attributes.get("anchor", -1))
		if a < 0 or a >= i or slots[a] == null or slots[a].def_id == Inventory.LOCK or a + slots[a].slot_span() <= i:
			slots[i] = null
