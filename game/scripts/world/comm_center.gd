class_name CommCenter
extends RefCounted
## Spec 29 section 4 (Island progression / Personal Communications Center) and section 10: the
## contribution-driven Tamed Island upgrade track. The center is an ordinary BUILDFLOW structure
## (construction site -> exact-instance deposits -> work -> a finished CraftStation of kind
## `comm_center`); once it stands on the home island, the survivor hands it exact item instances and
## completes one step to raise the island's Pioneer rank. Rank milestones raise the plot CAPACITY
## (data/world/domains.json: 2 -> 17, 6 -> 23, 7 -> 30); a step never claims a cell - that stays the
## Domain screen's Declare/Expand (spec 29 section 4: "it does not instantly assign land").
##
## Every cost lives in data/world/comm_center.json and is # ASSUMPTION: spec 29 states the
## intervening ranks and costs are not established, so only the documented ranks have a step.
## Contributions are the instances themselves (spec 29 section 10): one unit leaves the bag and is
## held here, and completing a step consumes exactly those units once - never a clone, never twice.

const PATH := "res://data/world/comm_center.json"
## The blueprint id in data/blueprints.json; its finished station carries this as a station TAG on a
## workbench-kind station (spec 30 section 10), which is how it is found again after a save/load.
const KIND := &"comm_center"
const TAG := &"comm_center"
const START_RANK := 1
## The documented top rank (data/world/domains.json's last milestone). A rank above it is forged.
const MAX_RANK := 7

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data

## The build blueprint (BUILDFLOW), read straight from data/blueprints.json so the Build menu sees it
## in a fresh session (the Domain screen and this track never have to be opened first).
static func blueprint() -> Dictionary:
	return Blueprints.of(KIND)

## The BuildGrid kind (and the finished station's kind) the blueprint places: the workbench kind,
## which has a footprint in props_manifest and a kit, so the site and later the center restore.
static func grid_kind() -> StringName:
	var st: Variant = blueprint().get("station", {})
	return StringName(str((st as Dictionary).get("kind", "workbench")))

## Spec 29 section 4: the historical track "was associated with level-60 progression". That is a
## data fact about the building, never a mapping from the character level onto the island rank: the
## rank moves only when a contribution step is completed.
static func level_association() -> int:
	return maxi(0, int((data().get("level_association", {}) as Dictionary).get("player_level", 0)))

## Documented steps in rank order: [{rank, requires}].
static func steps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Variant in data().get("ranks", []):
		if row is Dictionary and int((row as Dictionary).get("rank", 0)) > START_RANK:
			out.append(row as Dictionary)
	out.sort_custom(func (a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) < int(b["rank"]))
	return out

static func step_for(rank: int) -> Dictionary:
	for row in steps():
		if int(row["rank"]) == rank:
			return row
	return {}

# ---------------------------------------------------------------- the saved record

## The record on World (spec 29 section 3/10): the island's current rank plus the instances handed
## to each unfinished step, keyed by the rank that step unlocks.
## The record, read-only: an untouched island has no record and reads as rank 1 with no held
## instances (so an old save with no center re-saves field for field exactly as it was).
static func record() -> Dictionary:
	var rec: Variant = World.home_comm_center
	if not rec is Dictionary or (rec as Dictionary).is_empty():
		return {"rank": START_RANK, "steps": {}}
	var out: Dictionary = rec as Dictionary
	if not out.get("steps", {}) is Dictionary:
		out["steps"] = {}
	return out

## The record, writable: created on first use so progress has somewhere to live.
static func _mutable() -> Dictionary:
	var rec := record()
	World.home_comm_center = rec
	return rec

## The Tamed Island's Pioneer rank from the center (character level may be higher; DomainRules takes
## whichever is higher).
static func rank() -> int:
	return clampi(int(record().get("rank", START_RANK)), START_RANK, MAX_RANK)

## The next documented step above the current rank, or {} when the track is finished for now.
static func next_step() -> Dictionary:
	for row in steps():
		if int(row["rank"]) > rank():
			return row
	return {}

static func target_rank() -> int:
	var row := next_step()
	return int(row.get("rank", 0)) if not row.is_empty() else 0

## True when the finished center stands on the current island (an upgrade needs the building).
static func built(rt: Node = null) -> bool:
	return station(rt) != null

## The finished center standing on this island (a placed station carrying the comm_center tag), or
## null. A construction site is not one: it has no station tags until it is completed.
static func station(rt: Node = null) -> Node:
	var runtime: Node = rt if rt != null else World.runtime
	if runtime == null or not is_instance_valid(runtime):
		return null
	for n in runtime.get_tree().get_nodes_in_group("placed_building"):
		if not n is Node or not runtime.is_ancestor_of(n) or (n as Node).is_queued_for_deletion():
			continue
		var tags: Variant = n.get("station_tags")
		if tags is Array and TAG in tags:
			return n as Node
	return null

## Give the finished station a nameboard, so the world says what it is: the center shares the
## workbench grid kind and model (data/props_manifest.json for a center of its own is not in this
## job's files), and nothing in the HUD names it. Idempotent: one board per station.
static func label_station(rt: Node = null) -> void:
	var st: Node = station(rt)
	if st == null or not st is Node3D:
		return
	var host := st as Node3D
	if host.get_node_or_null("CenterName") != null:
		return
	var l := Label3D.new()
	l.name = "CenterName"
	l.text = "COMMUNICATIONS CENTER"
	l.font_size = 48
	l.pixel_size = 0.004
	l.outline_size = 8
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.modulate = Color(0.98, 0.9, 0.6)
	l.position = Vector3(0.0, 2.6, 0.0)  # above the HUD name pill (1.55 m)
	host.add_child(l)

# ---------------------------------------------------------------- contributions (exact instances)

## One Array[ItemStack] per required slot of `rank`'s step (empty when there is no such step).
static func columns(rank_id: int) -> Array:
	var row := step_for(rank_id)
	if row.is_empty():
		return []
	var key := str(rank_id)
	var want := (row.get("requires", []) as Array).size()
	var rec := _mutable()
	var steps_row: Dictionary = rec["steps"]
	var rows: Array = steps_row.get(key, [])
	while rows.size() < want:
		rows.append([])
	steps_row[key] = rows
	return rows

static func required(rank_id: int, slot: int) -> Dictionary:
	var req: Array = step_for(rank_id).get("requires", [])
	return req[slot] as Dictionary if slot >= 0 and slot < req.size() else {}

static func needed(rank_id: int, slot: int) -> int:
	return maxi(0, int(required(rank_id, slot).get("quantity", 0)))

## The held rows as they are (READ ONLY: never creates a record for a step nobody contributed to,
## so an island that never used the center re-saves without it).
static func held_rows(rank_id: int) -> Array:
	var rec: Variant = World.home_comm_center
	if not rec is Dictionary:
		return []
	var all: Variant = (rec as Dictionary).get("steps", {})
	if not all is Dictionary:
		return []
	var rows: Variant = (all as Dictionary).get(str(rank_id), [])
	return rows as Array if rows is Array else []

## Units handed to `slot`, counted from the instances themselves.
static func deposited(rank_id: int, slot: int) -> int:
	var rows := held_rows(rank_id)
	if slot < 0 or slot >= rows.size():
		return 0
	var n := 0
	for s: ItemStack in rows[slot]:
		n += s.count
	return n

static func slot_counts(rank_id: int) -> Array[int]:
	var out: Array[int] = []
	for i in (step_for(rank_id).get("requires", []) as Array).size():
		out.append(deposited(rank_id, i))
	return out

## Whether an instance satisfies a slot's accepted tags and minimum level (the blueprint rule, so
## the UI and the model can never disagree).
static func fits(slot: Dictionary, s: ItemStack) -> bool:
	return Blueprints.fits(slot, s)

## Why `slot` cannot take another unit now ("" when it can): the step is done, the slot is full, or
## the survivor is short of that item.
static func deposit_reason(rank_id: int, slot: int) -> String:
	if rank_id <= rank():
		return "That step is already complete"
	if step_for(rank_id).is_empty():
		return "No upgrade step at rank %d" % rank_id
	if slot < 0 or slot >= (step_for(rank_id).get("requires", []) as Array).size():
		return "No such slot"
	if deposited(rank_id, slot) >= needed(rank_id, slot):
		return "That part is full"
	return ""

## Move up to one exact unit of the required item from the bag into the step's slot. The instance
## leaves the bag and is held here (never duplicated); false when nothing moved.
static func deposit(rank_id: int, slot: int, inv: Inventory = null) -> bool:
	if deposit_reason(rank_id, slot) != "":
		return false
	var bag: Inventory = inv if inv != null else _bag()
	if bag == null:
		return false
	var want := required(rank_id, slot)
	for i in bag.slot_count:
		var s: ItemStack = bag.slots[i]
		if s == null or s.def_id == Inventory.LOCK or s.is_locked():
			continue
		if not fits(want, s):
			continue
		var taken: ItemStack = bag.remove_at(i, 1)
		if taken == null:
			return false
		if taken.count > 1:  # a stack split: only the one unit is the contribution
			taken.count = 1
		if taken.creator == "":
			taken.creator = World.player_name
		(columns(rank_id)[slot] as Array).append(taken)
		print("[comm_center] deposited %s into rank %d slot %s (%d/%d)" % [taken.def_id, rank_id, str(want.get("slot_id", slot)), deposited(rank_id, slot), needed(rank_id, slot)])
		return true
	return false

## Hand the last instance of `slot` back to the bag (Untouched if the bag cannot take it).
static func withdraw(rank_id: int, slot: int, inv: Inventory = null) -> bool:
	var rows := held_rows(rank_id)
	if slot < 0 or slot >= rows.size() or (rows[slot] as Array).is_empty():
		return false
	var bag: Inventory = inv if inv != null else _bag()
	if bag == null:
		return false
	var col: Array = rows[slot]
	var s: ItemStack = col[col.size() - 1]
	if bag.add(s.duplicate_stack()) > 0:
		return false
	col.remove_at(col.size() - 1)
	return true

static func ready(rank_id: int) -> bool:
	if rank_id <= rank() or step_for(rank_id).is_empty():
		return false
	for i in (step_for(rank_id).get("requires", []) as Array).size():
		if deposited(rank_id, i) < needed(rank_id, i):
			return false
	return true

## Complete the step whose target rank is `rank_id` (default: the next documented one). Consumes the
## held instances exactly once, raises the island rank and nothing else: no cell is claimed, no land
## changes, and the plot cap follows the new rank from data. Answers
## {ok, reason, rank_before, rank_after, cap_before, cap_after, consumed}.
static func complete(rt: Node = null, rank_id: int = 0) -> Dictionary:
	var out := {"ok": false, "reason": "", "rank_before": rank(), "rank_after": rank(), "cap_before": DomainRules.cap(), "cap_after": DomainRules.cap(), "consumed": 0}
	var target := rank_id if rank_id > 0 else target_rank()
	out["reason"] = "No upgrade step left" if target <= 0 else complete_reason(target, rt)
	if str(out["reason"]) != "":
		return out
	var before_rank := rank()
	var before_cap := DomainRules.cap()
	# Consume exactly the held instances, once: the step's rows are dropped (not returned anywhere),
	# and the rank moves past them so a second call cannot spend them again.
	var rows := columns(target)
	var consumed := 0
	for col: Array in rows:
		for s: ItemStack in col:
			consumed += s.count
		(col as Array).clear()
	var rec := _mutable()
	(rec["steps"] as Dictionary).erase(str(target))
	rec["rank"] = maxi(before_rank, target)
	var rt_now: Node = rt if rt != null else World.runtime
	if rt_now != null and rt_now.get("domain") is Dictionary:
		IslandClaims.sync_cap(rt_now)  # capacity only; the cells stay exactly as they were
	out["ok"] = true
	out["rank_after"] = rank()
	out["cap_after"] = DomainRules.cap()
	out["consumed"] = consumed
	print("[comm_center] rank %d -> %d, cap %d -> %d, %d instance(s) consumed" % [before_rank, rank(), before_cap, DomainRules.cap(), consumed])
	return out

## Why the step cannot be completed now ("" when it can). The center must stand and every slot must
## be full.
static func complete_reason(rank_id: int, rt: Node = null) -> String:
	if rank_id <= rank():
		return "Rank %d is already reached" % rank_id
	if step_for(rank_id).is_empty():
		return "No upgrade step at rank %d" % rank_id
	if not built(rt):
		return "Build the Personal Communications Center first"
	if not ready(rank_id):
		return "The center still needs contributions"
	return ""

# ---------------------------------------------------------------- save / load

## The record as JSON-safe rows (exact instances keep their uids, attributes and levels).
static func to_save() -> Dictionary:
	var rec := record()
	var steps_out: Dictionary = {}
	for key in (rec.get("steps", {}) as Dictionary):
		var any := false
		for col: Array in (rec["steps"][key] as Array):
			if not col.is_empty():
				any = true
		if not any:
			continue  # a step nobody contributed to is not progress worth saving
		var cols_out: Array = []
		for col: Array in (rec["steps"][key] as Array):
			var rows: Array = []
			for s: ItemStack in col:
				rows.append(s.to_dict())
			cols_out.append(rows)
		steps_out[str(key)] = cols_out
	return {"rank": rank(), "steps": steps_out}

static func from_save(row: Variant) -> void:
	if not row is Dictionary or (row as Dictionary).is_empty():
		World.home_comm_center = {}  # a save from before the center: no record at all
		return
	var src := row as Dictionary
	var steps_in: Dictionary = {}
	var raw: Variant = src.get("steps", {})
	if raw is Dictionary:
		for key in raw:
			var cols_in: Array = []
			var stored: Variant = raw[key]
			if stored is Array:
				for col: Variant in stored:
					var col_out: Array = []
					if col is Array:
						for row_i: Variant in (col as Array):
							if not row_i is Dictionary:
								continue
							var s := ItemStack.from_dict(row_i as Dictionary)
							if s.def() != null and s.count > 0:
								col_out.append(s)
					cols_in.append(col_out)
			steps_in[str(key)] = cols_in
	World.home_comm_center = {"rank": clampi(int(src.get("rank", START_RANK)), START_RANK, MAX_RANK), "steps": steps_in}

static func _bag() -> Inventory:
	var p := PlayerRegistry.local()
	return p.inventory if p != null else null
