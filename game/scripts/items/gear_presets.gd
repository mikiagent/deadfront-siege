class_name GearPresets
extends RefCounted
## Numbered gear loadouts (spec 13 s14, Character -> Gear's "1 2 [lock] [lock]"). Ported from INVUI.
## A preset remembers the uid worn in each equipment slot and the held tool; switching puts those
## exact instances on through Inventory's own equip rules, so stats change once, by the real rules.
## Stored on Inventory.presets = {"active": int, "sets": [{slot: uid}, ...]}; saved in
## player.inventory_extras only once used (an old save has none and loads with {}).
## Presets unlock by shown player level (data/inv_ui.json presets.unlock_levels): never one not earned.

const TOOL := "tool"

static func _data() -> Dictionary:
	return InvAttributes.data().get("presets", {})

static func count() -> int:
	return int(_data().get("count", 4))

## Level preset `k` (0-based) opens at.
static func unlock_level(k: int) -> int:
	var levels: Array = _data().get("unlock_levels", [1])
	return int(levels[k]) if k < levels.size() else 999

## How many presets a survivor at shown `level` has earned.
static func unlocked_count(level: int) -> int:
	var n := 0
	for k in count():
		n += 1 if level >= unlock_level(k) else 0
	return n

## The active preset, never one not yet earned (a forged save can name a locked one).
static func active(inv: Inventory, level: int = -1) -> int:
	var lv := level if level > 0 else LevelDisplay.player_level()
	return clampi(int(inv.presets.get("active", 0)), 0, maxi(0, unlocked_count(lv) - 1))

## Whether preset `k` has been saved (an unsaved one is null; an empty loadout is {}).
static func has_set(inv: Inventory, k: int) -> bool:
	var sets: Array = inv.presets.get("sets", [])
	return k < sets.size() and sets[k] is Dictionary

## Remember what is worn now (and the held tool) as preset `k`, and make it the active one.
static func capture(inv: Inventory, k: int) -> void:
	var set_k := {}
	for slot in Inventory.EQUIP_SLOTS:
		var s := inv.worn(slot)
		if s and s.uid != "":
			set_k[str(slot)] = s.uid
	var held := inv.slots[inv.equipped_tool_index] if inv.equipped_tool_index >= 0 and inv.equipped_tool_index < inv.slot_count else null
	if held and held.uid != "":
		set_k[TOOL] = held.uid
	var sets: Array = (inv.presets.get("sets", []) as Array).duplicate(true)
	while sets.size() <= k:
		sets.append(null)
	sets[k] = set_k
	inv.presets = {"active": k, "sets": sets}

## Put preset `k` on. Returns "" when done, else why not. Gear it names that is no longer in the bag
## is skipped; a locked piece stays in the bag (InventoryEquipment.equip_at refuses locked items) and
## the reason names it.
## ASSUMPTION (INVUI's): worn gear the preset does not name comes off.
static func apply(inv: Inventory, k: int, level: int = -1) -> String:
	var lv := level if level > 0 else LevelDisplay.player_level()
	if k < 0 or k >= count():
		return "No such preset."
	if k >= unlocked_count(lv):
		return "Preset %d unlocks at %s." % [k + 1, LevelDisplay.label(unlock_level(k))]
	if not has_set(inv, k):
		return "Preset %d is empty." % (k + 1)
	var want: Dictionary = (inv.presets.sets as Array)[k]
	# Gear coming off with nothing replacing it needs a free bag slot each: refuse the whole switch first.
	var off := 0
	for slot in Inventory.EQUIP_SLOTS:
		var cur := inv.worn(slot)
		if cur and str(want.get(str(slot), "")) != cur.uid and index_of(inv, str(want.get(str(slot), ""))) < 0:
			off += 1
	if off > inv.slot_count - inv.used_slots():
		return "Bag is full."
	var kept: PackedStringArray = []
	for slot in Inventory.EQUIP_SLOTS:
		var uid := str(want.get(str(slot), ""))
		var cur := inv.worn(slot)
		if cur and cur.uid == uid:
			continue
		var at := index_of(inv, uid)
		if at >= 0:
			var piece := inv.slots[at]
			if not inv.equip_at(at, slot) and piece.is_locked(): # swaps with what is worn
				kept.append(_name(piece))
		elif cur:
			inv.unequip(slot)
	var tool_at := index_of(inv, str(want.get(TOOL, "")))
	if tool_at >= 0 and tool_at != inv.equipped_tool_index:
		inv.set_equipped_tool_index(tool_at)
	var p := inv.presets.duplicate(true)
	p["active"] = k
	inv.presets = p
	return "" if kept.is_empty() else "Locked: %s %s in the bag." % [", ".join(kept), "stays" if kept.size() == 1 else "stay"]

static func _name(s: ItemStack) -> String:
	var d := s.def()
	return ("%s %s" % [d.display_name if d and d.display_name != "" else str(s.def_id), LevelDisplay.label(s.level)]).strip_edges()

## The Gear tab's tap on preset `k`: the active preset first keeps what is worn now, then `k` goes on
## (an unsaved `k` starts as a copy of the current gear).
static func switch(inv: Inventory, k: int, level: int = -1) -> String:
	var lv := level if level > 0 else LevelDisplay.player_level()
	if k >= unlocked_count(lv):
		return apply(inv, k, lv) # the refusal
	if inv.presets.is_empty() or k != active(inv, lv):
		capture(inv, active(inv, lv))
	if not has_set(inv, k):
		capture(inv, k)
		inv.changed.emit()
		return ""
	var why := apply(inv, k, lv)
	inv.changed.emit()
	return why

## A save's presets, cleaned: slots from EQUIP_SLOTS + "tool", uids in the loader's uid form, at most
## count() sets, active in range. Anything else is dropped (a forged save cannot inject data).
static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not (raw as Dictionary).get("sets") is Array:
		return {}
	var names: Array = []
	for s in Inventory.EQUIP_SLOTS:
		names.append(str(s))
	names.append(TOOL)
	var uid_re := RegEx.create_from_string("^[il][0-9a-f]+$")
	var sets := []
	for row: Variant in ((raw as Dictionary).sets as Array).slice(0, count()):
		if not row is Dictionary:
			sets.append(null)
			continue
		var clean := {}
		for slot: Variant in row:
			var uid: Variant = row[slot]
			if str(slot) in names and uid is String and (uid as String).length() <= 64 and uid_re.search(uid) != null:
				clean[str(slot)] = uid
		sets.append(clean)
	if sets.is_empty():
		return {}
	var a: Variant = (raw as Dictionary).get("active", 0)
	return {"active": clampi(int(a), 0, sets.size() - 1) if (a is int or a is float) else 0, "sets": sets}

static func index_of(inv: Inventory, uid: String) -> int:
	if uid == "":
		return -1
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].uid == uid:
			return i
	return -1
