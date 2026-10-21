class_name Inventory
extends RefCounted
## Fixed-slot bag of item instances plus the equipment container. Materials and food are one
## instance per slot (owner 2026-10-20, prompts 05/08); only data/inventory.json's
## stacking_categories merge. Slot-span items (captured animals) occupy consecutive empties.
## Loading saved rows, and the stacked-save migration, is InventoryMigration.

signal changed

## Spec 05:11 "base player inventory 100 spaces"; worn equipment adds to it (capacity()).
const BASE_SLOTS := 100
const LOCK := &"_slot_lock"

## Size before equipment bonuses.
var base_slots: int = BASE_SLOTS
var slot_count: int = BASE_SLOTS
var slots: Array[ItemStack] = []
## Equipped gather/work tool slot index, or -1 for auto (best gather_power).
var equipped_tool_index: int = -1
const EQUIP_SLOTS: Array[StringName] = [&"weapon", &"head", &"body", &"arms", &"legs", &"accessory1", &"accessory2"]
## Equipment by slot name. An ItemStack value is worn gear held here, out of the bag (equip-02).
## An int is a bag index whose item stays in the bag (the server's CharacterState keeps worn gear
## in its bag by uid); a String is the pre-W2-INV def-id form, resolved to the first bag match.
var equipment: Dictionary = {}
## Two quick-food def ids for the HUD food hexes + auto-feed.
var quick_food: Array = ["", ""]
## uids taken while loading (home cargo, then this bag): a worn row repeating one is reminted.
var load_uids: Dictionary = {}

func _init(p_slots: int = BASE_SLOTS) -> void:
	base_slots = p_slots
	slot_count = p_slots
	slots.resize(slot_count)

static func slot_for(def: ItemDef) -> StringName:
	if def == null:
		return &""
	if def.has_category(&"weapon") and def.damage > 0.0:
		return &"weapon"
	# Specific slots before the generic armor/clothing fallbacks (travel_sleeves is armor_arms + clothing).
	for pair in [[&"armor_head", &"head"], [&"helmet", &"head"], [&"armor_body", &"body"], [&"armor_arms", &"arms"], [&"gloves", &"arms"], [&"armor_legs", &"legs"], [&"armor", &"body"], [&"clothing", &"body"], [&"accessory", &"accessory1"], [&"bag", &"accessory1"]]:
		if def.has_category(pair[0]):
			return pair[1]
	return &""

# ---------------------------------------------------------------- equipment

## Wear the exact item at bag `index`. Whatever was worn in that slot swaps into the vacated bag
## slot, so equipping never needs a free slot.
func equip_at(index: int, slot: StringName = &"") -> bool:
	if index < 0 or index >= slot_count:
		return false
	var item := slots[index]
	if item == null or item.def_id == LOCK or item.is_locked() or item.count != 1:
		return false
	var want := slot_for(item.def())
	var target := slot if slot != &"" else want
	# Only into its own slot (a ring may take either accessory slot).
	if want == &"" or not (target == want or (want == &"accessory1" and target == &"accessory2")):
		return false
	if target == &"accessory1" and worn(&"accessory1") != null and worn(&"accessory2") == null:
		target = &"accessory2"
	var old := worn(target)
	slots[index] = old
	equipment[str(target)] = item
	# Spec 05:11: the bag grows or shrinks by the swap's bonus difference; a shrink that would cut
	# off occupied slots is refused and the swap undone.
	if not _resize(slot_count + bag_bonus(item) - bag_bonus(old)):
		slots[index] = item
		if old:
			equipment[str(target)] = old
		else:
			equipment.erase(str(target))
		return false
	if equipped_tool_index == index:
		equipped_tool_index = -1 # the held tool is the item just worn
	changed.emit()
	return true

## Def-id form for callers without a bag index: wears the highest-level match.
func equip(slot: StringName, def_id: StringName) -> bool:
	var best := -1
	for i in slot_count:
		var s := slots[i]
		if s and s.def_id == def_id and (best < 0 or s.level > slots[best].level):
			best = i
	return equip_at(best, slot) if best >= 0 else false

## Back into the bag, which loses the slots this item added (spec 05:11). Refused (the gear stays
## worn) when what the bag holds plus this item would not fit: never drop gear.
func unequip(slot: StringName) -> bool:
	var v: Variant = equipment.get(str(slot))
	if v is ItemStack:
		var cap := slot_count - bag_bonus(v)
		if used_slots() + 1 > cap or not _resize(cap):
			return false
		equipment.erase(str(slot))
		add(v)
	else:
		equipment.erase(str(slot))
	changed.emit()
	return true

## The gear worn in `slot` (container form only).
func worn(slot: StringName) -> ItemStack:
	var v: Variant = equipment.get(str(slot))
	return v if v is ItemStack else null

## Spec 05:11: the slots a worn item adds, its def's bag_slots plus its pocket attribute level x
## pocket_slots_per_level. # ASSUMPTION: an instance's Pocket is attributes.pocket = its level.
static func bag_bonus(s: ItemStack) -> int:
	if s == null or s.def() == null:
		return 0
	var r := ItemDef.rules()
	var p: Variant = s.attributes.get("pocket", 0)
	var lv := clampi(int(p), 0, int(r.get("max_pocket_level", 60))) if (p is int or p is float) else 0
	return s.def().bag_slots + lv * int(r.get("pocket_slots_per_level", 6))

## Base slots plus every worn item's bonus, counted from what is worn now (so nothing adds twice).
## The server keeps worn gear in its bag by index (int form), which adds nothing.
func capacity() -> int:
	var n := base_slots
	for slot: String in equipment:
		if equipment[slot] is ItemStack:
			n += bag_bonus(equipment[slot])
	return n

## Resize to `cap`. A smaller bag first moves single items out of the cut tail into free slots below
## it, and refuses (changing nothing) when they do not fit or a multi-slot item is in the tail.
func _resize(cap: int) -> bool:
	if cap >= slot_count:
		grow_to(cap)
		return true
	var tail: Array[int] = []
	for i in range(cap, slot_count):
		if slots[i] != null:
			if slots[i].def_id == LOCK or slots[i].slot_span() > 1:
				return false
			tail.append(i)
	var free: Array[int] = []
	for i in cap:
		if slots[i] == null and free.size() < tail.size():
			free.append(i)
	if free.size() < tail.size():
		return false
	for k in tail.size():
		slots[free[k]] = slots[tail[k]]
		if equipped_tool_index == tail[k]:
			equipped_tool_index = free[k]
	slot_count = cap
	slots.resize(cap)
	return true

func grow_to(n: int) -> void:
	if n > slot_count:
		slot_count = n
		slots.resize(n)

func equipped_in(slot: StringName) -> ItemStack:
	var v: Variant = equipment.get(str(slot))
	if v is ItemStack:
		return v
	if v is int:
		return slots[v] if v >= 0 and v < slot_count else null
	if v is String and v != "":
		var idx := find_first(StringName(v))
		return slots[idx] if idx >= 0 else null
	return null

func equipped_armor() -> float:
	var value := 0.0
	for slot in [&"head", &"body", &"arms", &"legs"]:
		var item := equipped_in(slot)
		if item and not item.is_broken():
			value += item.scaled_armor()
	return value

func has_raid_protection() -> bool:
	for pair in [[&"head", &"raid_helm"], [&"body", &"raid_cuirass"], [&"legs", &"raid_greaves"]]:
		var item := equipped_in(pair[0])
		if item == null or item.def_id != pair[1] or item.level < 55 or item.is_broken():
			return false
	return true

func equipped_health_bonus() -> float:
	var value := 0.0
	for slot in [&"head", &"body", &"arms", &"legs"]:
		var item := equipped_in(slot)
		if item and not item.is_broken() and item.def():
			value += item.def().health_bonus_at(item.level)
	return value

func set_quick_food(i: int, def_id: StringName) -> void:
	if i < 0 or i > 1:
		return
	quick_food[i] = str(def_id)
	changed.emit()

## Worn gear saves whole under "worn": it is no longer in the bag rows.
func extras_to_dict() -> Dictionary:
	var w := {}
	for slot in equipment:
		if equipment[slot] is ItemStack:
			w[slot] = (equipment[slot] as ItemStack).to_dict()
	return {"worn": w, "quick_food": quick_food.duplicate(), "tool_index": equipped_tool_index}

## Call after load_array. A pre-W2-INV save names worn gear by def id with the item still in the
## bag: that item (highest level) moves out of the bag into its slot. Then the bag takes the
## capacity the worn gear gives (a shrink that would cut off items is skipped: never delete).
func extras_from_dict(d: Dictionary) -> void:
	equipment.clear()
	var seen := load_uids.merged(uids())
	load_uids = {}
	equipped_tool_index = int(d.get("tool_index", -1))
	if equipped_tool_index < -1 or equipped_tool_index >= slot_count:
		equipped_tool_index = -1
	var w: Variant = d.get("worn", null)
	if w is Dictionary:
		for slot: Variant in w:
			var row: Variant = w[slot]
			if not row is Dictionary or StringName(str(slot)) not in EQUIP_SLOTS:
				continue
			var s := ItemStack.from_dict(row)
			var want := slot_for(s.def())
			# Trust boundary: a known wearable def in its own slot, one unit, a reachable level.
			if want == &"" or not (want == StringName(str(slot)) or (want == &"accessory1" and str(slot) == "accessory2")):
				continue
			s.count = 1
			s.level = clampi(s.level, 1, 60)
			if seen.has(s.uid):
				s.remint_uid() # spec 05:26 duplicate IDs: the bag (or cargo) copy keeps it
			mint(s)
			seen[s.uid] = true
			equipment[str(slot)] = s
	else:
		var legacy: Variant = d.get("equipment", {})
		if legacy is Dictionary:
			for slot: Variant in legacy:
				equip(StringName(str(slot)), StringName(str(legacy[slot])))
	var q: Variant = d.get("quick_food", [])
	if q is Array and (q as Array).size() >= 2:
		quick_food = [str(q[0]), str(q[1])]
	_resize(capacity())
	changed.emit()

# ---------------------------------------------------------------- tools

func set_equipped_tool_index(idx: int) -> void:
	equipped_tool_index = idx
	changed.emit()

## The chosen tool, else the best gather tool of any class.
func equipped_gather_tool() -> ItemStack:
	var held := _held_tool()
	return held if held else _best_tool(&"")

func gather_tools_in_bag() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in slot_count:
		if _is_tool(slots[i], &""):
			out.append({"index": i, "stack": slots[i]})
	return out

## The chosen tool when it is of class `tool`, else the best of that class (worn weapon included).
func find_gather_tool(tool: StringName) -> ItemStack:
	if tool == &"" or tool == &"none":
		return null
	var held := _held_tool()
	if held and held.def().tool_class == tool:
		return held
	return _best_tool(tool)

func has_tool_class(tool: StringName) -> bool:
	if tool == &"" or tool == &"none":
		return true
	return find_gather_tool(tool) != null

func wear_gather_tool(tool: StringName) -> bool:
	var s := find_gather_tool(tool)
	if s == null:
		return false
	var d := s.def()
	# ASSUMPTION: work tools lose 1 durability per gather; combat weapons used as tools lose 3.
	var cost := 1
	if d and not d.is_work_tool:
		cost = 3
	var intact := s.wear(cost)
	if not intact:
		print("[item] %s broke" % s.def_id)
	changed.emit()
	return intact

func _held_tool() -> ItemStack:
	if equipped_tool_index >= 0 and equipped_tool_index < slot_count and _is_tool(slots[equipped_tool_index], &""):
		return slots[equipped_tool_index]
	return null

## Work tools before weapons (weapons stay sheathed unless they are the only match), then the
## highest gather_power (tool-01: a flint pick beats a stone pick); ties keep bag order.
func _best_tool(tool: StringName) -> ItemStack:
	var pool: Array[ItemStack] = []
	pool.append_array(slots)
	pool.append(worn(&"weapon"))
	var best: ItemStack = null
	for s in pool:
		if not _is_tool(s, tool):
			continue
		if best == null:
			best = s
			continue
		var w := s.def().is_work_tool
		var bw := best.def().is_work_tool
		if (w and not bw) or (w == bw and s.gather_power() > best.gather_power()):
			best = s
	return best

func _is_tool(s: ItemStack, tool: StringName) -> bool:
	if s == null or s.is_locked() or s.is_broken():
		return false
	var d := s.def()
	if d == null or d.tool_class == &"" or d.tool_class == &"none":
		return false
	return tool == &"" or d.tool_class == tool

# ---------------------------------------------------------------- bag

func used_slots() -> int:
	var n := 0
	for i in slot_count:
		if slots[i] != null:
			n += 1
	return n

## Every instance uid in the bag, as a set.
func uids() -> Dictionary:
	var out := {}
	for s in slots:
		if s != null and s.uid != "":
			out[s.uid] = true
	return out

## Whether add(stack) would place every unit. Check it before consuming anything for an output.
func can_accept(stack: ItemStack) -> bool:
	if stack == null or stack.count <= 0:
		return false
	var span := stack.slot_span()
	if span > 1:
		return _find_span(span) >= 0
	var cap := stack.def().stack_max if stack.def() else 1
	var left := stack.count
	for s in slots:
		if left <= 0:
			break
		if s == null:
			left -= cap
		elif stack.can_merge_with(s):
			left -= maxi(0, cap - s.count)
	return left <= 0

## For containers sized by their contents (corpse loot): grows rather than refuse a unit.
func add_growing(stack: ItemStack) -> void:
	while add(stack) > 0:
		grow_to(slot_count + maxi(1, stack.slot_span()))

## Returns the units that did not fit. Each placed unit of a non-stacking def is its own instance.
func add(stack: ItemStack) -> int:
	if stack == null or stack.count <= 0:
		return 0
	var span := stack.slot_span()
	if span <= 1:
		for s in slots:
			if s != null and stack.can_merge_with(s):
				stack.take_into(s)
				if stack.count <= 0:
					changed.emit()
					return 0
		var d := stack.def()
		var cap: int = d.stack_max if d else 1
		var first := true
		for i in slot_count:
			if slots[i] == null:
				var copy := stack.duplicate_stack()
				copy.count = mini(stack.count, cap)
				if not first:
					copy.remint_uid() # the source's uid stays with its first unit only
				first = false
				mint(copy)
				slots[i] = copy
				stack.count -= copy.count
				if stack.count <= 0:
					changed.emit()
					return 0
		changed.emit()
		return stack.count
	var start := _find_span(span)
	if start < 0:
		return stack.count
	place_span(stack.duplicate_stack(), start)
	stack.count = 0
	changed.emit()
	return 0

func remove_at(index: int, amount: int = 1) -> ItemStack:
	if amount <= 0 or index < 0 or index >= slot_count or slots[index] == null:
		return null
	var s := slots[index]
	if s.def_id == LOCK:
		return null
	var span := s.slot_span()
	var taken := s.duplicate_stack()
	taken.count = mini(amount, s.count)
	s.count -= taken.count
	if s.count > 0:
		taken.remint_uid()  # a split makes a second instance; uid is unique per stack
	if s.count <= 0:
		slots[index] = null
		for k in range(1, span):
			if index + k < slot_count:
				slots[index + k] = null
		if equipped_tool_index == index:
			equipped_tool_index = -1 # else the index would silently point at the next item put there
	changed.emit()
	return taken

## Move only the units the destination accepts. Rejected units stay in their source slot.
func transfer_to(destination: Inventory, index: int) -> int:
	if destination == null or destination == self or index < 0 or index >= slot_count:
		return 0
	var source := slots[index]
	if source == null or source.is_locked() or source.def_id == LOCK:
		return 0
	var copy := source.duplicate_stack()
	var count := copy.count
	var left := destination.add(copy)
	var moved := count - left
	if moved > 0: remove_at(index, moved)
	return moved

## Visual grouping only (prompt 05: "12 Large Leg Bones" expands to 12 instances): bag slots by
## item id, in bag order. Nothing is merged; each entry lists the slots of its instances.
func groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var at := {}
	for i in slot_count:
		var s := slots[i]
		if s == null or s.def_id == LOCK:
			continue
		if not at.has(s.def_id):
			at[s.def_id] = out.size()
			out.append({"def_id": s.def_id, "slots": [] as Array[int], "units": 0})
		var g: Dictionary = out[at[s.def_id]]
		(g.slots as Array[int]).append(i)
		g.units = int(g.units) + s.count
	return out

## Attribute keys that are bookkeeping, not traits. ASSUMPTION: no per-instance trait list exists
## in data yet, so any other key (hardness, food_buff, genetics, ...) that differs from the def's
## default_attributes marks an instance as special.
const PLAIN_ATTRS := ["level", "climate", "processed", "material_tier"]

## An instance's traits: attributes that are neither bookkeeping nor the def's own
## default_attributes (a stone's tint is not a trait).
static func traits(s: ItemStack) -> Dictionary:
	var d := s.def()
	var base: Dictionary = d.default_attributes if d else {}
	var out := {}
	for k: Variant in s.attributes:
		if str(k) not in PLAIN_ATTRS and s.attributes[k] != base.get(k):
			out[k] = s.attributes[k]
	return out

## Spec 05:23: default picks spend the least valuable instance first, so a rare or higher-level one
## goes only when the player picks it. Ascending key: has traits, then level, then age (oldest first).
static func spend_key(s: ItemStack) -> Array:
	return [0 if traits(s).is_empty() else 1, s.level, s.created_at]

func find_by_category(cat: StringName) -> Array[int]:
	var hits: Array[int] = []
	for i in slot_count:
		var s := slots[i]
		if s == null:
			continue
		var d := s.def()
		if d and d.has_category(cat):
			hits.append(i)
	return hits

func find_first(def_id: StringName) -> int:
	for i in slot_count:
		if slots[i] and slots[i].def_id == def_id and slots[i].def_id != LOCK:
			return i
	return -1

func count_of(def_id: StringName) -> int:
	var n := 0
	for s in slots:
		if s and s.def_id == def_id:
			n += s.count
	return n

func consume(def_id: StringName, amount: int) -> bool:
	if amount <= 0 or count_of(def_id) < amount:
		return false
	var left := amount
	for i in slot_count:
		if left <= 0:
			break
		var s := slots[i]
		if s == null or s.def_id != def_id:
			continue
		var take := mini(left, s.count)
		remove_at(i, take)
		left -= take
	return true

func consume_by_category(cat: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	var have := 0
	for i in find_by_category(cat):
		have += slots[i].count
	if have < amount:
		return false
	var left := amount
	for i in find_by_category(cat):
		if left <= 0:
			break
		var take := mini(left, slots[i].count)
		remove_at(i, take)
		left -= take
	return true

func equipped_weapon() -> ItemStack:
	var chosen := equipped_in(&"weapon")
	if chosen:
		return chosen
	for s in slots:
		if s == null:
			continue
		var d := s.def()
		if d and d.has_category(&"weapon") and d.damage > 0.0:
			return s
	return null

func best_capture_net() -> ItemStack:
	var best: ItemStack = null
	var best_tier := 0
	for s in slots:
		if s == null:
			continue
		var d := s.def()
		if d and d.capture_tier > best_tier:
			best = s
			best_tier = d.capture_tier
	return best

# ---------------------------------------------------------------- save

func to_array() -> Array:
	var out: Array = []
	for s in slots:
		if s == null:
			out.append(null)
		else:
			out.append(s.to_dict())
	return out

## Saved rows back in their slots; stacked rows of a def that no longer stacks split into
## instances, and what no slot holds goes to `overflow` (home cargo). See InventoryMigration.
func load_array(raw: Array, overflow: Inventory = null) -> void:
	InventoryMigration.load_into(self, raw, overflow)
	changed.emit()

## A non-stacking unit without an identity gets a local one (prompt 05: every instance has an id).
## Only the uid: a wall-clock created_at would make the server's journal replay non-deterministic
## (CharacterState.commit replaces the uid with the server's own).
static func mint(s: ItemStack) -> void:
	if s.uid == "" and not s.is_fungible():
		s.uid = "l" + Crypto.new().generate_random_bytes(8).hex_encode()

func place_span(s: ItemStack, start: int) -> void:
	slots[start] = s
	for k in range(1, s.slot_span()):
		var lock := ItemStack.make(LOCK, 1)
		lock.attributes = {"anchor": start}
		slots[start + k] = lock

func _find_span(span: int) -> int:
	var i := 0
	while i <= slot_count - span:
		var ok := true
		for k in span:
			if slots[i + k] != null:
				ok = false
				break
		if ok:
			return i
		i += 1
	return -1
