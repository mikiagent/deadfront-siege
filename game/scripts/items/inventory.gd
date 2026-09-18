class_name Inventory
extends RefCounted
## Fixed-slot bag. Slot-span items (captured animals) occupy consecutive empties.

signal changed

var slot_count: int = 20
var slots: Array[ItemStack] = []

func _init(p_slots: int = 20) -> void:
	slot_count = p_slots
	slots.resize(slot_count)

func used_slots() -> int:
	var n := 0
	for i in slot_count:
		if slots[i] != null:
			n += 1
	return n

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
		for i in slot_count:
			if slots[i] == null:
				var d := stack.def()
				var cap: int = d.stack_max if d else 1
				var place := mini(stack.count, cap)
				var copy := stack.duplicate_stack()
				copy.count = place
				slots[i] = copy
				stack.count -= place
				if stack.count <= 0:
					changed.emit()
					return 0
		changed.emit()
		return stack.count
	var start := _find_span(span)
	if start < 0:
		return stack.count
	var copy := stack.duplicate_stack()
	slots[start] = copy
	for k in range(1, span):
		var lock := ItemStack.make(&"_slot_lock", 1)
		lock.attributes = {"anchor": start}
		slots[start + k] = lock
	stack.count = 0
	changed.emit()
	return 0

func remove_at(index: int, amount: int = 1) -> ItemStack:
	if index < 0 or index >= slot_count or slots[index] == null:
		return null
	var s := slots[index]
	if str(s.def_id) == "_slot_lock":
		return null
	var span := s.slot_span()
	var taken := s.duplicate_stack()
	taken.count = mini(amount, s.count)
	s.count -= taken.count
	if s.count <= 0:
		slots[index] = null
		for k in range(1, span):
			if index + k < slot_count:
				slots[index + k] = null
	changed.emit()
	return taken

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
		if slots[i] and slots[i].def_id == def_id and str(slots[i].def_id) != "_slot_lock":
			return i
	return -1

func count_of(def_id: StringName) -> int:
	var n := 0
	for s in slots:
		if s and s.def_id == def_id:
			n += s.count
	return n

func consume(def_id: StringName, amount: int) -> bool:
	if count_of(def_id) < amount:
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

func find_gather_tool(tool: StringName) -> ItemStack:
	if tool == &"" or tool == &"none":
		return null
	var best: ItemStack = null
	for s in slots:
		if s == null:
			continue
		if s.is_locked() or s.is_broken():
			continue
		var d := s.def()
		if d == null or d.tool_class != tool:
			continue
		if best == null:
			best = s
			continue
		var bd := best.def()
		# Prefer work tools so combat weapons stay sheathed unless they are the only match.
		if d.is_work_tool and bd and not bd.is_work_tool:
			best = s
	return best

func has_tool_class(tool: StringName) -> bool:
	if tool == &"" or tool == &"none":
		return true
	return find_gather_tool(tool) != null

func wear_gather_tool(tool: StringName) -> void:
	var s := find_gather_tool(tool)
	if s == null:
		return
	var d := s.def()
	# ASSUMPTION: work tools lose 1 durability per gather; combat weapons used as tools lose 3.
	var cost := 1
	if d and not d.is_work_tool:
		cost = 3
	if not s.wear(cost):
		print("[item] %s broke" % s.def_id)
	changed.emit()

func to_array() -> Array:
	var out: Array = []
	for s in slots:
		if s == null:
			out.append(null)
		else:
			out.append(s.to_dict())
	return out

func load_array(raw: Array) -> void:
	for i in slot_count:
		slots[i] = null
	for i in mini(slot_count, raw.size()):
		var row: Variant = raw[i]
		if row is Dictionary:
			slots[i] = ItemStack.from_dict(row)
	changed.emit()

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
