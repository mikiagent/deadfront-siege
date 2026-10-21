class_name GearPresets
extends RefCounted
## Numbered gear loadouts (spec 13 s14, Character -> Gear's "1 2 [lock] [lock]"). A preset remembers
## the uid worn in each equipment slot and the held tool; switching puts those exact instances on
## through the same PlayerActions commands the screens use, so stats change once, by the real rules.
## Stored on Inventory.presets = {"active": int, "sets": [{slot: uid}, ...]}; only saved once used.
## Presets unlock by character level (data/inv_ui.json presets.unlock_levels): never one not earned.

const TOOL := "tool"

static func _data() -> Dictionary:
	return InvView.data().get("presets", {})

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

static func active(inv: Inventory) -> int:
	return int(_p(inv).get("active", 0))

## Whether preset `k` has been saved (an unsaved one is null; an empty loadout is {}).
static func has_set(inv: Inventory, k: int) -> bool:
	var sets: Array = _p(inv).get("sets", [])
	return k < sets.size() and sets[k] is Dictionary

## Remember what is worn now (and the held tool) as preset `k`, and make it the active one.
static func capture(inv: Inventory, k: int) -> void:
	var set_k := {}
	for slot in Inventory.EQUIP_SLOTS:
		var s := inv.equipped_in(slot)
		if s and s.uid != "":
			set_k[str(slot)] = s.uid
	var held := inv.slots[inv.equipped_tool_index] if inv.equipped_tool_index >= 0 and inv.equipped_tool_index < inv.slot_count else null
	if held and held.uid != "":
		set_k[TOOL] = held.uid
	var sets: Array = _p(inv).get("sets", [])
	while sets.size() <= k:
		sets.append(null)
	sets[k] = set_k
	inv.set("presets", {"active": k, "sets": sets})

## Put preset `k` on. Returns "" when done, else why not (locked preset, bag full, or the locked
## pieces left in the bag: the rest still goes on). Gear it names that is no longer in the bag is skipped. # ASSUMPTION: worn gear the preset does not name comes off.
static func apply(player: Player, k: int) -> String:
	var inv := player.inventory
	if k < 0 or k >= count():
		return "No such preset."
	if k >= unlocked_count(LevelDisplay.player_level()):
		return "Preset %d unlocks at %s." % [k + 1, LevelDisplay.label(unlock_level(k))]
	if not has_set(inv, k):
		return "Preset %d is empty." % (k + 1)
	var want: Dictionary = (_p(inv).sets as Array)[k]
	# Gear coming off with nothing replacing it needs a free bag slot each: refuse the whole switch first.
	var off := 0
	for slot in Inventory.EQUIP_SLOTS:
		var cur := inv.equipped_in(slot)
		if cur and str(want.get(str(slot), "")) != cur.uid and _index(inv, str(want.get(str(slot), ""))) < 0:
			off += 1
	if off > inv.slot_count - inv.used_slots():
		return "Bag is full."
	var pa = player.actions # untyped: equip_at / unequip / hold_tool come from the INVUI hooks patch
	var kept: PackedStringArray = [] # pieces a lock keeps in the bag (equip_at refuses them)
	for slot in Inventory.EQUIP_SLOTS:
		var uid := str(want.get(str(slot), ""))
		var cur := inv.equipped_in(slot)
		if cur and cur.uid == uid:
			continue
		var at := _index(inv, uid)
		if at >= 0:
			var piece := inv.slots[at]
			if not pa.equip_at(at, slot) and piece.is_locked(): # swaps with what is worn
				kept.append(_name(piece))
		elif cur:
			pa.unequip(slot)
	var tool_at := _index(inv, str(want.get(TOOL, "")))
	if tool_at >= 0 and tool_at != inv.equipped_tool_index:
		var tool := inv.slots[tool_at]
		if not pa.hold_tool(tool_at) and tool.is_locked():
			kept.append(_name(tool))
	var p := _p(inv).duplicate(true)
	p["active"] = k
	inv.set("presets", p)
	return "" if kept.is_empty() else "Locked: %s %s in the bag." % [", ".join(kept), "stays" if kept.size() == 1 else "stay"]

static func _name(s: ItemStack) -> String:
	var d := s.def()
	return ("%s %s" % [d.display_name if d and d.display_name != "" else str(s.def_id), LevelDisplay.label(s.level)]).strip_edges()

## The Gear tab's tap on preset `k`: the active preset first keeps what is worn now, then `k` goes on
## (an unsaved `k` starts as a copy of the current gear).
static func switch(player: Player, k: int) -> String:
	var inv := player.inventory
	if k >= unlocked_count(LevelDisplay.player_level()):
		return apply(player, k) # the refusal
	if _p(inv).is_empty() or k != active(inv):
		capture(inv, active(inv))
	if not has_set(inv, k):
		capture(inv, k)
		inv.changed.emit()
		return ""
	var why := apply(player, k)
	inv.changed.emit()
	return why

## A save's presets, cleaned: slots from EQUIP_SLOTS + "tool", uids in the bag's uid form, at most
## count() sets, active in range. Anything else is dropped (a forged save cannot inject data).
static func sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not (raw as Dictionary).get("sets") is Array:
		return {}
	var names: Array = Inventory.EQUIP_SLOTS.map(func(s: StringName) -> String: return str(s)) + [TOOL]
	var sets := []
	for row: Variant in (raw.sets as Array).slice(0, count()):
		if not row is Dictionary:
			sets.append(null)
			continue
		var clean := {}
		for slot: Variant in row:
			var uid: Variant = row[slot]
			if str(slot) in names and uid is String and (uid as String).length() <= 64:
				clean[str(slot)] = uid
		sets.append(clean)
	if sets.is_empty():
		return {}
	var a: Variant = raw.get("active", 0)
	return {"active": clampi(int(a), 0, sets.size() - 1) if (a is int or a is float) else 0, "sets": sets}

## Inventory.presets (the INVUI hooks patch adds the field; {} without it).
static func _p(inv: Inventory) -> Dictionary:
	var v: Variant = inv.get("presets")
	return v if v is Dictionary else {}

static func _index(inv: Inventory, uid: String) -> int:
	if uid == "":
		return -1
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].uid == uid:
			return i
	return -1
