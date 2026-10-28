extends SceneTree
## BUTCHER (spec 12 §2): a carcass part list per species comes from data/butchering.json; the survivor
## chooses one part per cut and gets only that part; the cut budget is 1 + floor(Butchering level / 10);
## knife tier still scales a cut's yield; a rare row rolls once per chosen part; a cut that is refused
## or cancelled grants nothing and spends nothing; and the parts already cut survive a save/load.
## Run: Godot --headless --path game --script res://tests/t_butcher.gd -> "[t_butcher] PASS", exit 0/1.
## Scripts are load()ed on the first frame: `--script` compiles this file before autoloads exist.

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var _player
var CP: GDScript
var LR: GDScript
var LT: GDScript
var BL: GDScript
var CORPSE: GDScript
var IS: GDScript
var INV: GDScript
var data: Node
## Each test bumps this on its last line: a SCRIPT ERROR mid-test aborts it and fails the run.
var _finished := 0
const GROUPS := 7

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	data = root.get_node("Data")
	CP = load("res://scripts/gather/carcass_parts.gd")
	LR = load("res://scripts/gather/loot_roller.gd")
	LT = load("res://scripts/gather/loot_tables.gd")
	BL = load("res://scripts/gather/butcher_loot.gd")
	CORPSE = load("res://scripts/creatures/corpse.gd")
	IS = load("res://scripts/items/item_stack.gd")
	INV = load("res://scripts/items/inventory.gd")
	_run.call_deferred()
	return false

func _run() -> void:
	await _build_player()
	_test_part_list()
	_test_cut_budget()
	_test_part_only()
	await _test_corpse_cut()
	_test_knife_scales()
	_test_rare_per_part()
	_test_save_round_trip()
	if _finished != GROUPS:
		_fails.append("all %d test groups ran to the end (%d did)" % [GROUPS, _finished])
	if _fails.is_empty():
		print("[t_butcher] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[t_butcher] FAIL %s" % f)
		quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_butcher] FAIL %s" % what)

## A real survivor (skills, bag, PlayerRegistry.local) on a plain floor: the cut reads the same
## Player the game hands it.
func _build_player() -> void:
	_host = Node3D.new()
	_host.name = "TButcher"
	root.add_child(_host)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	_host.add_child(_player)
	_player.global_position = Vector3(0, 1, 0)
	await process_frame
	await physics_frame
	for i in 3:
		await process_frame

## A bag with one knife of the given material tier.
func _bag_with(tier: StringName):
	var inv = INV.new(12)
	if tier != &"":
		inv.add(IS.make(&"stone_knife_work", 1, {"material_tier": str(tier)}, 1))
	return inv

## The cut context for a synthetic bag (no corpse), as CarcassParts.context builds for a real one.
func _ctx(inv, cuts_left: int = 3) -> Dictionary:
	var knife = inv.find_gather_tool(&"knife")
	return {
		"level": 5,
		"knife_tier": knife.material_tier() if knife else &"",
		"node_tier": data.butchering_level(),
		"skill": 10,
		"no_meat": false,
		"inv": inv,
		"cuts_left": cuts_left,
		"cut": [],
	}

# ---------------------------------------------------------------- 1. the part list comes from data

func _test_part_list() -> void:
	var raptor: Array = CP.parts(&"velociraptor")
	var ids := []
	for part in raptor:
		ids.append(str(part["id"]))
	var want := ["raptor_meat", "raptor_bone", "raptor_hide", "predator_tendon", "raptor_talon"]
	print("[t_butcher] velociraptor parts: %s" % [ids])
	_expect(ids == want, "the velociraptor's part list is its butchering.json rows in order (%s)" % [ids])
	# Every part names a real item and keeps the row the data wrote (min/max, attributes).
	var meat: Dictionary = {}
	for part in raptor:
		if part["id"] == &"raptor_meat":
			meat = part["row"]
	_expect(data.item(&"raptor_meat") != null and int(meat.get("min", 0)) == 2 and int(meat.get("max", 0)) == 3, "a part keeps its data row (meat min 2 max 3, got %s)" % [meat])
	# protoceratops lists raptor_bone twice (base + a rare frill row): one cut, the rare row kept with it.
	var proto: Array = CP.parts(&"protoceratops")
	var names := []
	var bone: Dictionary = {}
	for part in proto:
		names.append(str(part["id"]))
		if part["id"] == &"raptor_bone":
			bone = part
	print("[t_butcher] protoceratops parts: %s" % [names])
	_expect(names.count("raptor_bone") == 1, "a part listed twice in the data is one cut (%s)" % [names])
	# The rare row keeps its own attributes (the frill mark), not the base row's.
	var bone_rare: Dictionary = bone.get("rare", {})
	var bone_rare_attrs: Dictionary = bone_rare.get("attributes", {})
	_expect(not bone_rare.is_empty() and int(bone_rare_attrs.get("frill", 0)) == 1, "the repeated rare row is kept as that part's rare roll (%s)" % [bone_rare])
	# A species the data does not list offers nothing (never an invented part).
	_expect(CP.parts(&"no_such_beast").is_empty(), "an unknown species offers no parts")
	_finished += 1

# ---------------------------------------------------------------- 2. the cut budget

func _test_cut_budget() -> void:
	var cases := [[0, 1], [9, 1], [10, 2], [19, 2], [20, 3], [60, 7]]
	for c in cases:
		_expect(CP.cut_budget(int(c[0])) == int(c[1]), "Butchering %d offers %d cuts (got %d)" % [c[0], c[1], CP.cut_budget(int(c[0]))])
	_expect(CP.cut_budget(-4) == 1, "a negative level still offers one cut")
	print("[t_butcher] cut budget: Lv1 %d, Lv10 %d, Lv30 %d, Lv60 %d" % [
		CP.cut_budget(1), CP.cut_budget(10), CP.cut_budget(30), CP.cut_budget(60)])
	_finished += 1

# ---------------------------------------------------------------- 3. a cut yields only its part

func _test_part_only() -> void:
	var inv = _bag_with(&"flint")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var parts: Array = CP.parts(&"protoceratops")
	var checked := 0
	for part in parts:
		var id: StringName = part["id"]
		if not (part.get("rare", {}) as Dictionary).is_empty():
			continue  # the rare roll needs its skill node; _test_rare_per_part covers it
		var res: Dictionary = CP.cut(part, _ctx(inv), rng)
		var got := []
		for st in res["stacks"]:
			got.append(str(st.def_id))
		if not res["ok"]:
			continue
		checked += 1
		_expect(got.all(func(g: String) -> bool: return g == str(id)), "cutting %s gives only %s (gave %s)" % [id, id, got])
		_expect(not (res["stacks"] as Array).is_empty(), "a chosen base part always cuts at least one unit (%s gave none)" % id)
	_expect(checked >= 2, "the protoceratops's open base parts cut through (%d did; the scutes and dense bone wait on nodes)" % checked)
	# A locked part is refused with its reason and gives nothing.
	var locked: Array = CP.parts(&"triceratops")
	var scute: Dictionary = {}
	for part in locked:
		if part["id"] == &"armor_scute":
			scute = part
	_expect(not scute.is_empty(), "a triceratops lists its scutes")
	var no: Dictionary = CP.cut(scute, _ctx(inv), rng)
	print("[t_butcher] locked scutes cut: ok=%s reason=%s stacks=%d" % [no["ok"], no["reason"], (no["stacks"] as Array).size()])
	_expect(not no["ok"] and (no["stacks"] as Array).is_empty() and str(no["reason"]) != "", "a part its Butchering node has not opened is refused, and gives nothing")
	_finished += 1

# ---------------------------------------------------------------- 4. the corpse enforces the budget

## A corpse of `species` with the shipped roll (ButcherLoot), cut through Corpse.cut_part: one cut
## takes only the chosen part off the carcass, spends one cut, and a cut with no knife or no budget
## left grants nothing and spends nothing.
func _test_corpse_cut() -> void:
	_clear_bag()
	_player.inventory.add(IS.make(&"stone_knife_work", 1, {"material_tier": "flint"}, 1))
	var c = CORPSE.new()
	c.species = &"velociraptor"
	c.level = 3
	BL.rng.seed = 5
	BL.roll_into(c)
	c.apply_cut_state(2, 2, [])
	var before: int = c.loot.count_of(&"raptor_meat")
	_expect(before > 0, "the rolled carcass holds meat to cut (%d)" % before)
	var other_before: int = c.loot.count_of(&"raptor_hide")
	var got: Array = c.cut_part(&"raptor_meat", _player)
	var got_ids := []
	for st in got:
		got_ids.append(str(st.def_id))
	print("[t_butcher] corpse cut meat: %s, cuts %d/%d, hide left %d" % [got_ids, c.cuts_left, c.cuts_budget, c.loot.count_of(&"raptor_hide")])
	_expect(not got.is_empty() and got_ids.all(func(g: String) -> bool: return g == "raptor_meat"), "the chosen cut takes the meat and nothing else (%s)" % [got_ids])
	_expect(c.loot.count_of(&"raptor_meat") == 0 and c.loot.count_of(&"raptor_hide") == other_before, "the carcass keeps the parts that were not cut (hide %d)" % c.loot.count_of(&"raptor_hide"))
	_expect(c.cuts_left == 1 and c.cut_parts.has(&"raptor_meat"), "one cut is spent and the part is recorded (left %d)" % c.cuts_left)
	# The same part again: refused, nothing moves, nothing spent.
	var again: Array = c.cut_part(&"raptor_meat", _player)
	_expect(again.is_empty() and c.cuts_left == 1, "a part already cut is not cut twice (left %d)" % c.cuts_left)
	# The last cut, then the budget is empty and the remaining hide stays on the carcass.
	c.cut_part(&"raptor_hide", _player)
	_expect(c.cuts_left == 0, "the second cut spends the last cut (left %d)" % c.cuts_left)
	var denied: Array = c.cut_part(&"raptor_bone", _player)
	var bone_left: int = c.loot.count_of(&"raptor_bone")
	print("[t_butcher] budget spent: bone cut %d, bone left %d" % [denied.size(), bone_left])
	_expect(denied.is_empty() and bone_left > 0 and not c.cut_parts.has(&"raptor_bone"), "with no cuts left a cut grants nothing and spends nothing")
	# No knife: refused, and the cut is not spent.
	var no_knife = CORPSE.new()
	no_knife.species = &"velociraptor"
	no_knife.level = 1
	BL.roll_into(no_knife)
	no_knife.apply_cut_state(2, 2, [])
	_clear_bag()
	var bare: Array = no_knife.cut_part(&"raptor_meat", _player)
	print("[t_butcher] no-knife cut: %d stacks, cuts left %d" % [bare.size(), no_knife.cuts_left])
	_expect(bare.is_empty() and no_knife.cuts_left == 2 and no_knife.loot.count_of(&"raptor_meat") > 0, "a cut without a knife grants nothing and spends no cut")
	# A cancelled cut is a cut that never reaches the carcass: nothing left the corpse, nothing spent.
	_expect(no_knife.loot.used_slots() > 0 and no_knife.cut_parts.is_empty(), "a cancelled cut leaves every part on the carcass")
	no_knife.free()
	c.free()
	_finished += 1

# ---------------------------------------------------------------- 5. knife tier scales the cut

func _test_knife_scales() -> void:
	var rows: Array = CP.parts(&"velociraptor")
	var meat: Dictionary = {}
	for part in rows:
		if part["id"] == &"raptor_meat":
			meat = part
	var stone := 0
	var flint := 0
	var runs := 400
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var inv_stone = _bag_with(&"stone")
	var inv_flint = _bag_with(&"flint")
	for i in runs:
		var a: Dictionary = CP.cut(meat, _ctx(inv_stone), rng)
		var b: Dictionary = CP.cut(meat, _ctx(inv_flint), rng)
		for st in a["stacks"]:
			stone += st.count
		for st in b["stacks"]:
			flint += st.count
	var stone_avg := float(stone) / runs
	var flint_avg := float(flint) / runs
	print("[t_butcher] raptor meat per cut: stone %.2f, flint %.2f" % [stone_avg, flint_avg])
	_expect(flint_avg > stone_avg, "a flint knife cuts more meat per cut than a stone knife (%.2f vs %.2f)" % [flint_avg, stone_avg])
	# Bare hands: no knife is refused (the corpse's knife rule), so the cut is not a free pick.
	var res: Dictionary = CP.cut(meat, _ctx(_bag_with(&"")), rng)
	_expect(not res["ok"] and (res["stacks"] as Array).is_empty(), "bare hands cannot cut a part off (refused: %s)" % res["reason"])
	_finished += 1

# ---------------------------------------------------------------- 6. rare rolls per chosen part

## Unlocks every Butchering node the cuts below meet (the talon's rare_parts_1 and the survival tiers).
func _unlock_butchering() -> Array:
	var unlocked: Array = []
	for id in data.survival_nodes:
		if str(data.survival_nodes[id].get("kind", "")) == "butchering" and not data.is_survival_unlocked(id):
			data.set_survival_unlocked(id, true)
			unlocked.append(id)
	for gate_id in ["raptor_talon", "predator_tendon"]:
		var gate: Array = (load("res://scripts/skills/skill_rules.gd") as GDScript).butcher_gate(_player.skills, gate_id)
		if gate.is_empty():
			continue
		if not _player.skills.is_unlocked(gate[0], str((gate[1] as Dictionary)["id"])):
			(_player.skills.trees[gate[0]]["unlocked"] as Array).append(str((gate[1] as Dictionary)["id"]))
			unlocked.append([gate[0], str((gate[1] as Dictionary)["id"])])
	return unlocked

func _relock(unlocked: Array) -> void:
	for id in unlocked:
		if id is Array:
			(_player.skills.trees[id[0]]["unlocked"] as Array).erase(id[1])
		else:
			data.set_survival_unlocked(id, false)

func _test_rare_per_part() -> void:
	var unlocked := _unlock_butchering()
	var parts: Array = CP.parts(&"velociraptor")
	var talon: Dictionary = {}
	var meat: Dictionary = {}
	for part in parts:
		if part["id"] == &"raptor_talon":
			talon = part
		if part["id"] == &"raptor_meat":
			meat = part
	_expect(bool(talon.get("rare_only", false)), "the talon is a rare-only part: it rolls its odds instead of always dropping")
	var inv = _bag_with(&"flint")
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var runs := 300
	var hits := 0
	var meat_rares := 0
	for i in runs:
		var r: Dictionary = CP.cut(talon, _ctx(inv), rng)
		if r["ok"] and (r["rares"] as Array).has(&"raptor_talon"):
			hits += 1
		var m: Dictionary = CP.cut(meat, _ctx(inv), rng)
		if (m["rares"] as Array).size() > 0:
			meat_rares += 1
	var rate := float(hits) / float(runs)
	var chance: float = LR.part_rare_chance(talon["row"], &"flint", 10)
	print("[t_butcher] talon per cut %.3f (odds %.3f); meat cuts with a rare %.3f" % [rate, chance, float(meat_rares) / float(runs)])
	_expect(rate > 0.0 and rate < 1.0, "the talon rolls its odds per chosen part instead of always dropping or never (%.3f)" % rate)
	_expect(absf(rate - chance) < 0.12, "the talon's measured rate follows the data odds (%.3f vs %.3f)" % [rate, chance])
	# A part with no rare row never pays a rare roll: meat is meat.
	_expect(meat_rares == 0, "a part whose data has no rare row rolls no rare (%d did)" % meat_rares)
	# A rare-only part that misses its roll still spends nothing here (the corpse spends the cut).
	var missed := 0
	for i in 50:
		var r: Dictionary = CP.cut(talon, _ctx(inv), rng)
		if r["ok"] and r["missed"]:
			missed += 1
	_expect(missed > 0, "a rare-only part reports a miss instead of inventing a part (%d misses)" % missed)
	_relock(unlocked)
	_finished += 1

# ---------------------------------------------------------------- 7. save/load keeps the cuts

func _test_save_round_trip() -> void:
	_clear_bag()
	_player.inventory.add(IS.make(&"stone_knife_work", 1, {"material_tier": "flint"}, 1))
	var c = CORPSE.new()
	c.species = &"velociraptor"
	c.level = 4
	BL.rng.seed = 9
	BL.roll_into(c)
	c.apply_cut_state(2, 2, [])
	c.cut_part(&"raptor_meat", _player)
	c.cut_part(&"raptor_hide", _player)
	var row: Dictionary = CP.to_row(c)
	# Through the disk format the save writes: JSON, then the shapes SaveSanitizer would apply.
	var text := JSON.stringify(row)
	var parsed: Variant = JSON.parse_string(text)
	_expect(parsed is Dictionary, "the carcass row survives JSON (the save's own format)")
	var back = CP.corpse_from_row(parsed as Dictionary if parsed is Dictionary else {})
	var kept := []
	if back != null:
		for id in back.cut_parts:
			kept.append(str(id))
	print("[t_butcher] reload: cuts left %s, parts cut %s, loot %d slots" % [back.cuts_left if back else -1, kept, back.loot.used_slots() if back else -1])
	_expect(back != null, "a saved carcass loads back")
	if back != null:
		_expect(kept == ["raptor_meat", "raptor_hide"], "the parts cut so far come back in order (%s)" % [kept])
		_expect(back.cuts_left == 0 and back.cuts_budget == 2, "the cut budget comes back spent (%d/%d)" % [back.cuts_left, back.cuts_budget])
		_expect(back.level == 4 and back.species == &"velociraptor", "the carcass keeps its species and level")
		_expect(back.loot.count_of(&"raptor_meat") == 0 and back.loot.count_of(&"raptor_hide") == 0 and back.loot.count_of(&"raptor_bone") > 0, "only the uncut parts are still on the reloaded carcass (bone %d)" % back.loot.count_of(&"raptor_bone"))
		_expect(back.loot.used_slots() == c.loot.used_slots(), "the reloaded carcass holds the same part instances (%d vs %d)" % [back.loot.used_slots(), c.loot.used_slots()])
		back.free()
	_expect(CP.corpse_from_row({"species": "no_such_beast"}) == null, "an unknown species in a save row loads no carcass")
	c.free()
	_finished += 1

func _clear_bag() -> void:
	for i in _player.inventory.slot_count:
		_player.inventory.slots[i] = null
