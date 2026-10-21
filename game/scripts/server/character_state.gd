class_name CharacterState
extends RefCounted
## One server-owned character (contract v2 §0.1): bag, equipment, wallet mirror, pets, skills,
## position. Wraps the plain dict that lives inside CharacterStore's state, so a snapshot is
## the state. Handlers never edit the bag dict directly: they get an Inventory built from it,
## run the normal domain code on that, and commit() writes it back and stamps new stacks.

const BAG_SLOTS := Inventory.BASE_SLOTS
const LOCK := &"_slot_lock"

var d: Dictionary
var _prov := {} ## ItemStack instance -> its stamp, for the Inventory handed out last

func _init(p_dict: Dictionary) -> void:
	d = p_dict

# ASSUMPTION: online characters start with an empty bag and level-0 skills; nothing is imported.
static func fresh(id: int, name: String, ts: int) -> Dictionary:
	var bag: Array = []
	bag.resize(BAG_SLOTS)
	return {
		"id": id, "name": name, "created": ts, "bag": bag, "equipment": {}, "tool": "",
		"wallet": 0, "pets": {}, "skills": {}, "pos": [0, 0, 0], "pos_ts": ts, "rids": {},
	}

## W2-INV migration (owner 2026-10-20, prompts 05/08): a character stored before items stopped
## stacking. Each unit over the def's stack_max becomes its own row with the stack's origin and
## seq; the first unit keeps the stack's uid and the k-th more gets "<uid>.<k>" (deterministic, so
## every boot and replay agrees; minted uids never hold two dots). The bag grows to BAG_SLOTS;
## units with no free slot go to d.storage (home storage). Nothing is deleted. Returns
## {split: rows made, stored: {id: units}}, or {} when the character needed nothing.
static func split_stacks(d: Dictionary) -> Dictionary:
	var bag: Array = d.bag
	var grew := bag.size() < BAG_SLOTS
	if grew:
		bag.resize(BAG_SLOTS)
	var extra: Array = []
	for row: Variant in bag:
		if not row is Dictionary or str(row.get("id", "")) == str(LOCK):
			continue
		var def := Data.item(StringName(str(row.id)))
		var cap: int = def.stack_max if def else int(row.count)
		var left := int(row.count) - cap
		# A row without a uid would give every such row the units ".1", ".2"; invariants() already
		# flags it, so it stays as stored (nothing deleted) until an operator looks.
		if left <= 0 or str(row.get("uid", "")) == "":
			continue
		row.count = cap
		var k := 0
		while left > 0:
			k += 1
			var unit: Dictionary = (row as Dictionary).duplicate(true)
			unit.count = mini(cap, left)
			unit.uid = "%s.%d" % [str(row.get("uid", "")), k]
			left -= unit.count
			extra.append(unit)
	if extra.is_empty():
		return {"split": 0, "stored": {}} if grew else {}
	var stored := {}
	var storage: Array = d.get("storage", [])
	var free := 0
	for unit: Dictionary in extra:
		while free < bag.size() and bag[free] != null:
			free += 1
		if free < bag.size():
			bag[free] = unit
		else:
			storage.append(unit)
			stored[str(unit.id)] = int(stored.get(str(unit.id), 0)) + int(unit.count)
	if not storage.is_empty():
		d["storage"] = storage # ASSUMPTION: the server's home storage; W3 adds the ops that take from it
	return {"split": extra.size(), "stored": stored}

## A fresh Inventory over a deep copy of the bag (so a refused op cannot have touched state),
## with equipment and the chosen gather tool mapped from uids to what Inventory expects.
func inventory() -> Inventory:
	var bag: Array = d.bag
	var inv := Inventory.new(bag.size())
	_prov.clear()
	for i in bag.size():
		var row: Variant = bag[i]
		if not row is Dictionary:
			continue
		var stack := ItemStack.from_dict(Provenance.strip(row))
		inv.slots[i] = stack
		if row.has("uid"):
			_prov[stack] = {"uid": row.uid, "origin": row.origin, "seq": row.seq}
	for slot: String in d.equipment:
		var i := find_uid(str(d.equipment[slot]))
		if i >= 0:
			inv.equipment[slot] = i # the exact worn item by bag index: two same-id items no longer share a stack
	inv.equipped_tool_index = find_uid(str(d.tool))
	return inv

## Writes `inv` back. Stacks that were in the bag keep their stamp (a merge adds units to an
## existing container); every new stack gets a uid, `origin` and `seq`. Returns the new uids.
func commit(inv: Inventory, origin: String, seq: int) -> Array[String]:
	var bag: Array = []
	var minted: Array[String] = []
	for stack in inv.slots:
		if stack == null:
			bag.append(null)
			continue
		var row := stack.to_dict()
		if stack.def_id == LOCK:
			bag.append(row)
			continue
		var old: Variant = _prov.get(stack)
		if old is Dictionary:
			row.merge(old, true)
		else:
			var uid := Provenance.item_uid(seq, minted.size())
			Provenance.stamp(row, uid, origin, seq)
			minted.append(uid)
		bag.append(row)
	d.bag = bag
	_prov.clear()
	# Equipment points at uids; anything that left the bag is unequipped.
	for slot: String in (d.equipment as Dictionary).keys():
		if find_uid(str(d.equipment[slot])) < 0:
			d.equipment.erase(slot)
	if find_uid(str(d.tool)) < 0:
		d.tool = ""
	return minted

func find_uid(uid: String) -> int:
	if uid == "":
		return -1
	var bag: Array = d.bag
	for i in bag.size():
		if bag[i] is Dictionary and str(bag[i].get("uid", "")) == uid:
			return i
	return -1

func slot_uid(i: int) -> String:
	var bag: Array = d.bag
	return str(bag[i].get("uid", "")) if i >= 0 and i < bag.size() and bag[i] is Dictionary else ""

func pos() -> Vector3:
	return WorldFacade.v3(d.pos)

func level_of(tree: String) -> int:
	return int((d.skills.get(tree, {}) as Dictionary).get("level", 0))

## SkillState.add_xp's rules on plain data: every gain also trains Survival.
# shortcut: skill points and unlocked nodes stay client-side; they move here with W3-SRVACT.
func add_xp(tree: String, amount: float, mirrored: bool = false) -> void:
	if tree not in SkillState.ORDER or amount <= 0.0:
		return
	if not mirrored and tree != "survival":
		add_xp("survival", amount, true)
	var t: Dictionary = d.skills.get(tree, {"level": 0, "xp": 0})
	d.skills[tree] = t
	if int(t.level) >= SkillState.MAX_LEVEL:
		return
	t.xp = float(t.xp) + amount
	while int(t.level) < SkillState.MAX_LEVEL and float(t.xp) >= SkillState.xp_to_next(int(t.level)):
		t.xp = float(t.xp) - SkillState.xp_to_next(int(t.level))
		t.level = int(t.level) + 1

## The client's cache of this character (the char_delta payload).
func view() -> Dictionary:
	var out := d.duplicate(true)
	out.erase("rids")
	return out
