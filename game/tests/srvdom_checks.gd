extends RefCounted
## No class_name: this is test code; tests/t_server_domain.gd loads it by path.
## W1-SRVDOM acceptance checks. tests/t_server_domain.gd loads this on the first frame, once
## the Data autoload exists (Crafting and friends cannot compile before it). Prints one
## "[srvdom] ..." evidence line per check; run() returns the failures.

const RECIPES := ["twine", "thread", "club", "fence_kit", "campfire_kit", "bonfire_kit", "stone_shot", "herbivore_feed", "capture_net_i", "sign_kit", "charcoal", "bandage", "work_axe", "stone_fire_pit_kit"]
const NODES := ["rock", "bush", "grass", "ore", "far", "bare", "nope"]
const KINDS := ["fence", "campfire", "bonfire", "sign", "workbench", "nope"]
const FOODS := ["berry", "herb_leaf", "raw_meat", "stone", "fibre_stalk"]
const FORGED := {"id": "raid_helm", "count": 5000, "level": 9999, "uid": "i1.0", "origin": "gather", "seq": 1}

## One hostile request per line: [op, args, the handler's literal refusal code]. Every op
## but char.get appears; the fixture is a fresh server character so nothing here can commit.
## ASSUMPTION: an op that answers a hostile input with server_error is a bug, so none may say so.
const HOSTILE := [
	["act.gather", {}, "bad_request"],
	["act.gather", {"node_id": 7}, "bad_request"],
	["act.gather", {"option": 0}, "bad_request"],
	["act.gather", {"node_id": "rock", "option": true}, "bad_request"],
	["act.gather", {"node_id": "rock", "option": 1.5}, "bad_request"],
	["act.gather", {"node_id": "rock", "option": -1}, "bad_request"],
	["act.gather", {"node_id": "rock", "option": 32}, "bad_request"],
	["act.gather", {"node_id": "rock", "option": "0"}, "bad_request"],
	["act.gather", {"node_id": "rock", "option": 1}, "bad_request"],
	["act.gather", {"node_id": {"a": 1}}, "bad_request"],
	["act.gather", {"node_id": ["rock"]}, "bad_request"],
	["act.gather", {"node_id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, "bad_request"],
	["act.gather", {"node_id": "nope"}, "not_found"],
	["act.gather", {"node_id": "bare"}, "depleted"],
	["act.gather", {"node_id": "ore"}, "missing_tool"],
	["act.gather", {"node_id": "far"}, "out_of_range"],
	["act.loot", {}, "bad_request"],
	["act.loot", {"corpse_id": 3}, "bad_request"],
	["act.loot", {"corpse_id": "carcass", "slot": -1}, "bad_request"],
	["act.loot", {"corpse_id": "carcass", "slot": 256}, "bad_request"],
	["act.loot", {"corpse_id": "carcass", "slot": 1.5}, "bad_request"],
	["act.loot", {"corpse_id": "carcass", "slot": 1}, "not_found"],
	["act.loot", {"corpse_id": "carcass", "slot": 9}, "not_found"],
	["act.loot", {"corpse_id": "carcass", "count": 0}, "bad_request"],
	["act.loot", {"corpse_id": "carcass", "count": -5}, "bad_request"],
	["act.loot", {"corpse_id": "nope", "slot": 0}, "not_found"],
	["act.loot", {"corpse_id": {"id": "carcass"}}, "bad_request"],
	["act.craft", {}, "bad_request"],
	["act.craft", {"recipe_id": 7}, "bad_request"],
	["act.craft", {"recipe_id": ["twine"]}, "bad_request"],
	["act.craft", {"recipe_id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, "bad_request"],
	["act.craft", {"recipe_id": "nope"}, "not_found"],
	["act.craft", {"recipe_id": "twine", "picks": []}, "bad_request"],
	["act.craft", {"recipe_id": "twine", "picks": "0"}, "bad_request"],
	["act.craft", {"recipe_id": "twine", "picks": {}}, "bad_request"],
	["act.craft", {"recipe_id": "twine", "picks": [0]}, "insufficient_items"],
	["act.craft", {"recipe_id": "twine", "picks": [1]}, "insufficient_items"],
	["act.craft", {"recipe_id": "twine", "picks": [-1]}, "insufficient_items"],
	["act.craft", {"recipe_id": "twine", "picks": [1.5]}, "insufficient_items"],
	["act.craft", {"recipe_id": "twine", "picks": [{"a": 1}]}, "insufficient_items"],
	["act.craft", {"recipe_id": "twine", "picks": [99]}, "insufficient_items"],
	["act.craft", {"recipe_id": "capture_net_i"}, "insufficient_items"],
	["act.place", {}, "bad_request"],
	["act.place", {"kind": "fence"}, "bad_request"],
	["act.place", {"kind": 7, "cell": [0, 0]}, "bad_request"],
	["act.place", {"kind": "fence", "cell": [0, 0], "rot": 4}, "bad_request"],
	["act.place", {"kind": "fence", "cell": [0, 0], "rot": -1}, "bad_request"],
	["act.place", {"kind": "fence", "cell": [0, 0], "rot": 1.5}, "bad_request"],
	["act.place", {"kind": "fence", "cell": [0, 0.5]}, "bad_request"],
	["act.place", {"kind": "fence", "cell": [0, 0, 0]}, "bad_request"],
	["act.place", {"kind": "fence", "cell": "0,0"}, "bad_request"],
	["act.place", {"kind": "fence", "cell": {"x": 0, "z": 0}}, "bad_request"],
	["act.place", {"kind": "fence", "cell": [200000, 0]}, "bad_request"],
	["act.place", {"kind": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "cell": [0, 0]}, "bad_request"],
	["act.place", {"kind": "fence", "cell": [0, 0]}, "insufficient_items"],
	["act.place", {"kind": "nope", "cell": [0, 0]}, "insufficient_items"],
	["act.equip", {}, "bad_request"],
	["act.equip", {"bag_slot": -1}, "bad_request"],
	["act.equip", {"bag_slot": 999}, "bad_request"],
	["act.equip", {"bag_slot": 1.5}, "bad_request"],
	["act.equip", {"bag_slot": "0"}, "bad_request"],
	["act.equip", {"clear": "yes"}, "bad_request"],
	["act.equip", {"clear": 1}, "bad_request"],
	["act.equip", {"clear": []}, "bad_request"],
	["act.equip", {"clear": true, "slot": "bogus"}, "bad_request"],
	["act.equip", {"clear": true, "slot": 7}, "bad_request"],
	["act.equip", {"clear": true, "slot": "xxxxxxxxxxxxxxxxx"}, "bad_request"],
	["act.equip", {"bag_slot": 50}, "not_found"], # W2-INV: stone no longer stacks, so slot 1 holds the second stone
	["act.equip", {"bag_slot": 0}, "bad_request"],
	["act.eat", {}, "bad_request"],
	["act.eat", {"bag_slot": -1}, "bad_request"],
	["act.eat", {"bag_slot": 999}, "bad_request"],
	["act.eat", {"bag_slot": 1.5}, "bad_request"],
	["act.eat", {"bag_slot": "0"}, "bad_request"],
	["act.eat", {"bag_slot": 50}, "not_found"],
	["act.eat", {"bag_slot": 0}, "bad_request"],
	["act.tame", {}, "bad_request"],
	["act.tame", {"net_id": "compy1"}, "bad_request"],
	["act.tame", {"food": "berry"}, "bad_request"],
	["act.tame", {"net_id": 5, "food": "berry"}, "bad_request"],
	["act.tame", {"net_id": "compy1", "food": 7}, "bad_request"],
	["act.tame", {"net_id": "compy1", "food": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, "bad_request"],
	["act.tame", {"net_id": "nope", "food": "berry"}, "not_found"],
	["act.tame", {"net_id": "compy1", "food": "berry"}, "not_ready"],
	["act.tame", {"net_id": ["compy1"], "food": "berry"}, "bad_request"],
	["act.capture", {}, "bad_request"],
	["act.capture", {"net_id": 5}, "bad_request"],
	["act.capture", {"net_id": {}}, "bad_request"],
	["act.capture", {"net_id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, "bad_request"],
	["act.capture", {"net_id": "nope"}, "not_found"],
	["act.capture", {"net_id": "compy1"}, "not_ready"],
	["act.attack", {}, "bad_request"],
	["act.attack", {"net_id": 5}, "bad_request"],
	["act.attack", {"net_id": [1]}, "bad_request"],
	["act.attack", {"net_id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, "bad_request"],
	["act.attack", {"net_id": "nope"}, "not_found"],
	["act.deposit", {}, "bad_request"],
	["act.deposit", {"bag_slot": -1}, "bad_request"],
	["act.deposit", {"bag_slot": 1.5}, "bad_request"],
	["act.deposit", {"bag_slot": 999}, "bad_request"],
	["act.deposit", {"bag_slot": 50}, "not_found"],
	["act.deposit", {"bag_slot": 0, "count": 0}, "bad_request"],
	["act.deposit", {"bag_slot": 0, "count": -3}, "bad_request"],
	["act.deposit", {"pet_uid": "p0.0"}, "not_found"],
	["act.deposit", {"pet_uid": 5}, "bad_request"],
	["act.deposit", {"slot_dict": {}}, "invalid_asset"],
	["act.deposit", {"item": {"id": "stone", "count": 1}}, "invalid_asset"],
	["act.deposit", {"save": "x"}, "invalid_asset"],
	["act.deposit", {"pets": []}, "invalid_asset"],
	["char.import", {}, "invalid_asset"],
	["char.import", {"save": {}}, "invalid_asset"],
	["char.import", {"save": [1, 2]}, "invalid_asset"],
	["char.import", {"save": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, "invalid_asset"],
	["char.create", {}, "bad_request"],
	["char.create", {"name": "ab"}, "bad_request"],
	["char.create", {"name": 7}, "bad_request"],
	["char.create", {"name": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, "bad_request"],
	["char.create", {"name": "bad!name"}, "bad_request"],
	["char.create", {"name": {"n": "abc"}}, "bad_request"],
	["char.create", {"name": true}, "bad_request"],
	["char.move", {}, "bad_request"],
	["char.move", {"p": "0,0,0"}, "bad_request"],
	["char.move", {"p": [0, 0]}, "bad_request"],
	["char.move", {"p": [0, 0, 0, 0]}, "bad_request"],
	["char.move", {"p": [NAN, 0, 0]}, "bad_request"],
	["char.move", {"p": [0, INF, 0]}, "bad_request"],
	["char.move", {"p": [0, 0, -INF]}, "bad_request"],
	["char.move", {"p": ["0", 0, 0]}, "bad_request"],
	["char.move", {"p": [1000000, 0, 0]}, "bad_request"],
	["char.move", {"p": [0, 0, 0], "reset": "yes"}, "bad_request"],
	["char.move", {"p": [0, 0, 0], "reset": 1}, "bad_request"],
	["char.move", {"p": [0, 0, 0], "reset": {}}, "bad_request"],
	["char.move", {"p": {}}, "bad_request"],
	["char.move", {"p": [[0], 0, 0]}, "bad_request"],
	["char.wallet", {}, "bad_request"],
	["char.wallet", {"wallet": -1}, "bad_request"],
	["char.wallet", {"wallet": 1.5}, "bad_request"],
	["char.wallet", {"wallet": "5"}, "bad_request"],
	["char.wallet", {"wallet": {}}, "bad_request"],
	["char.wallet", {"wallet": 9007199254740992}, "bad_request"],
	["char.receive", {}, "invalid_asset"],
	["char.receive", {"asset": "stone"}, "invalid_asset"],
	["char.receive", {"asset": []}, "invalid_asset"],
	["char.receive", {"asset": {}}, "invalid_asset"],
	["char.receive", {"asset": {"id": "stone", "count": 1}}, "invalid_asset"],
	["char.receive", {"asset": {"id": "stone", "count": 1, "uid": "i9.0", "origin": "gather", "seq": 1}}, "invalid_asset"],
	["char.receive", {"asset": {"species": "tyrannosaurus", "uid": "p99999.0", "origin": "tame", "seq": 1}}, "invalid_asset"],
	["char.settled", {}, "bad_request"],
	["char.settled", {"uid": 7}, "bad_request"],
	["char.settled", {"uid": ""}, "bad_request"],
	["char.settled", {"uid": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}, "bad_request"],
	["char.settled", {"uid": ["i1.0"]}, "bad_request"],
	["char.settled", {"uid": "i1.0"}, "not_found"],
]

var failures: Array[String] = []

func run(fuzz_ops: int = 10000) -> Array[String]:
	_gather_checks()
	_craft_checks()
	_tame_checks()
	_import_checks()
	_rid_checks()
	_move_checks()
	_receive_checks()
	_write_checks()
	_capture_checks()
	_hardening_checks()
	_hostile_arg_checks()
	_fuzz_and_replay(fuzz_ops, 20261018)
	_disk_checks()
	return failures

func expect(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond

# --- fixture -----------------------------------------------------------------------------

static func make_world() -> WorldFacade:
	var w := WorldFacade.new()
	w.add_node("rock", Vector3(1.5, 0, 0), [{"item": "stone", "tool": "none", "min": 2, "max": 4, "left": 400}], 1, "Rock")
	w.add_node("bush", Vector3(-1.5, 0, 0), [
		{"item": "berry", "tool": "none", "min": 1, "max": 2, "left": 400},
		{"item": "fibre_stalk", "tool": "none", "min": 1, "max": 3, "left": 400},
		{"item": "branch", "tool": "none", "min": 1, "max": 2, "left": 400},
	], 1, "bush")
	w.add_node("grass", Vector3(0, 0, 1.5), [
		{"item": "dry_grass", "tool": "none", "min": 1, "max": 2, "left": 400},
		{"item": "herb_leaf", "tool": "none", "min": 1, "max": 1, "left": 400},
		{"item": "bark_strip", "tool": "knife", "min": 1, "max": 1, "left": 400},
	], 1, "grass")
	w.add_node("ore", Vector3(0, 0, -1.5), [{"item": "copper_ore", "tool": "pick", "min": 1, "max": 1, "left": 50}], 1, "Rock_copper")
	w.add_node("far", Vector3(30, 0, 0), [{"item": "stone", "tool": "none", "min": 1, "max": 1, "left": 50}], 1, "Rock")
	w.add_node("bare", Vector3(1, 0, 1), [{"item": "stone", "tool": "none", "min": 1, "max": 1, "left": 0}], 1, "Rock")
	_refill_corpse(w)
	w.stations["workbench"] = [[0, 0, -1.8]]
	w.add_creature("compy1", "compsognathus", Vector3(1, 0, 1), 90.0)
	return w

static func _refill_corpse(w: WorldFacade) -> void:
	w.corpses["carcass"] = {"pos": [1, 0, -1], "slots": [ItemStack.make(&"raw_meat", 3).to_dict(), null, ItemStack.make(&"cloth", 2).to_dict()]}

func _store(seed: int, w: WorldFacade = null) -> CharacterStore:
	var st := CharacterStore.new(w if w else make_world(), "", seed)
	for acct in [1, 2, 3]:
		_ok(st.apply("char.create", acct, {"name": "Tester%d" % acct}, 1), "create %d" % acct)
	return st

func _ok(res: Dictionary, what: String) -> Dictionary:
	expect(bool(res.get("ok", false)), "%s failed: %s %s" % [what, res.get("err", ""), res.get("msg", "")])
	return res

static func _units(st: CharacterStore, acct: int) -> Dictionary:
	var out := {}
	for row: Variant in st.character(acct).d.bag:
		if row is Dictionary:
			out[str(row.id)] = int(out.get(str(row.id), 0)) + int(row.count)
	return out

static func _row_for(st: CharacterStore, acct: int, uid: String) -> Dictionary:
	var ch := st.character(acct)
	var i := ch.find_uid(uid)
	return ch.d.bag[i] if i >= 0 else {}

## Gathers until `n` units of `item` are in the bag (or `tries` passes are spent).
func _gather_until(st: CharacterStore, acct: int, node: String, option: int, item: String, n: int, ts: int) -> void:
	for _i in 40:
		if int(_units(st, acct).get(item, 0)) >= n:
			return
		st.apply("act.gather", acct, {"node_id": node, "option": option}, ts)

# --- acceptance checks -------------------------------------------------------------------

func _gather_checks() -> void:
	var w := make_world()
	var st := _store(3, w)
	var r := _ok(st.apply("act.gather", 1, {"node_id": "rock", "option": 0}, 2), "gather rock")
	if not r.ok:
		return
	var uid: String = r.r.uids[0] if not (r.r.uids as Array).is_empty() else ""
	var row := _row_for(st, 1, uid)
	expect(row.get("id") == "stone" and row.get("origin") == "gather" and int(row.get("seq", -1)) == int(r.r.seq) and int(r.r.seq) == int(st.s.seq), "gathered stack carries uid, origin=gather and the journal seq: %s" % row)
	var last: Dictionary = JSON.parse_string(st.lines[-1])
	expect(int(last.seq) == int(row.get("seq", -2)) and last.op == "act.gather", "journal line holds the gather at the stack's seq")
	expect(int(w.nodes.rock.options[0].left) == 399, "the node pool lost one unit")
	var refusals: PackedStringArray = []
	for case in [["far", "out_of_range"], ["bare", "depleted"], ["ore", "missing_tool"], ["nope", "not_found"]]:
		var h := st.state_hash()
		var lines := st.lines.size()
		var e := st.apply("act.gather", 1, {"node_id": case[0], "option": 0}, 3)
		var same := st.state_hash() == h and st.lines.size() == lines
		expect(not e.ok and e.get("err") == case[1] and same, "gather %s -> %s with state unchanged (got %s, unchanged=%s)" % [case[0], case[1], e.get("err", "ok"), same])
		refusals.append("%s:%s:unchanged=%s" % [case[0], e.get("err", "ok"), same])
	print("[srvdom] gather uid=%s origin=%s seq=%d count=%d; refusals %s" % [uid, row.get("origin"), int(row.get("seq", 0)), int(row.get("count", 0)), " ".join(refusals)])

func _craft_checks() -> void:
	var w := make_world()
	var st := _store(4, w)
	_gather_until(st, 1, "bush", 1, "fibre_stalk", 4, 2)
	_gather_until(st, 1, "bush", 2, "branch", 3, 3)
	var rec := Crafting.recipe(&"twine")
	var inv := st.character(1).inventory()
	var picks := Crafting.default_picks(inv, rec)
	var planned := {}
	for part in Crafting.slot_level_contributions(inv, rec, picks):
		planned[part.def_id] = int(planned.get(part.def_id, 0)) + int(part.count)
	var before := _units(st, 1)
	var r := _ok(st.apply("act.craft", 1, {"recipe_id": "twine", "picks": picks}, 4), "craft twine")
	if not r.ok:
		return
	var after := _units(st, 1)
	var exact := true
	for k in before:
		var used := int(before[k]) - int(after.get(k, 0))
		if used != int(planned.get(k, 0)):
			exact = false
	var row := _row_for(st, 1, r.r.uids[0] if not (r.r.uids as Array).is_empty() else "")
	expect(exact, "craft consumed exactly the planned inputs: planned %s before %s after %s" % [planned, before, after])
	expect(row.get("id") == "twine" and row.get("origin") == "craft" and int(row.get("seq", -1)) == int(r.r.seq) and int(after.get("twine", 0)) == 1, "crafted twine carries uid, origin=craft and seq: %s" % row)
	# A tool recipe: club = branch + twine, with durability and level from its inputs.
	var club := _ok(st.apply("act.craft", 1, {"recipe_id": "club"}, 5), "craft club")
	var club_row := _row_for(st, 1, club.r.uids[0] if club.ok and not (club.r.uids as Array).is_empty() else "")
	expect(club_row.get("id") == "club" and int(club_row.get("max_durability", 0)) > 0, "club output is a durable uid'd stack")
	# Refusals change nothing: missing inputs, a far station, a bad pick.
	var h := st.state_hash()
	var e1 := st.apply("act.craft", 1, {"recipe_id": "stone_fire_pit_kit"}, 6)
	var e2 := st.apply("act.craft", 1, {"recipe_id": "twine", "picks": [19]}, 6)
	w.stations.clear()
	var e3 := st.apply("act.craft", 1, {"recipe_id": "work_axe"}, 6)
	expect(e1.get("err") == "insufficient_items" and e2.get("err") == "insufficient_items" and e3.get("err") == "out_of_range" and st.state_hash() == h, "craft refusals insufficient_items/insufficient_items/out_of_range keep the state: %s %s %s" % [e1.get("err"), e2.get("err"), e3.get("err")])
	print("[srvdom] craft twine planned=%s used=%s output=%s origin=%s seq=%d; club dur=%d; refusals %s,%s,%s unchanged=%s" % [planned, _diff(before, after), row.get("uid"), row.get("origin"), int(row.get("seq", 0)), int(club_row.get("max_durability", 0)), e1.get("err"), e2.get("err"), e3.get("err"), st.state_hash() == h])

static func _diff(before: Dictionary, after: Dictionary) -> Dictionary:
	var out := {}
	for k in before:
		if int(before[k]) != int(after.get(k, 0)):
			out[k] = int(before[k]) - int(after.get(k, 0))
	return out

func _tame_once(seed: int) -> CharacterStore:
	var w := make_world()
	var st := _store(seed, w)
	_gather_until(st, 1, "bush", 0, "berry", 3, 2)
	var h := st.state_hash()
	var early := st.apply("act.tame", 1, {"net_id": "compy1", "food": "berry"}, 3)
	expect(early.get("err") == "not_ready" and st.state_hash() == h, "tame refuses a creature that is not knocked out below 30 %")
	w.creatures.compy1.hp = 20.0
	w.creatures.compy1.knocked = true
	w.creatures.compy1.torpor = 1.0  # FOODTORPOR: knocked out = weak + torpor past the threshold
	for i in 3:
		_ok(st.apply("act.tame", 1, {"net_id": "compy1", "food": "berry"}, 4 + i), "tame feed %d" % i)
	return st

func _tame_checks() -> void:
	var a := _tame_once(11)
	var b := _tame_once(11)
	var pa: Dictionary = a.character(1).d.pets
	var pb: Dictionary = b.character(1).d.pets
	if not expect(pa.size() == 1 and pb.size() == 1, "three berries tame the compy into one pet (got %d, %d)" % [pa.size(), pb.size()]):
		return
	var pet: Dictionary = pa.values()[0]
	var replayed := CharacterStore.new(WorldFacade.new(), "", 11)
	for line in a.lines:
		expect(replayed.replay_line(line) == "", "tame journal replays")
	var pr: Dictionary = replayed.character(1).d.pets
	var same := CharacterStore.canon(pet.genetics) == CharacterStore.canon((pb.values()[0] as Dictionary).genetics)
	var same_replay := pr.size() == 1 and CharacterStore.canon(pet.genetics) == CharacterStore.canon((pr.values()[0] as Dictionary).genetics)
	expect(same and same_replay, "same journal gives the same genetics (two runs %s, replay %s)" % [same, same_replay])
	expect(Provenance.is_server(pet) and pet.origin == "tame" and str(pet.uid).begins_with("p"), "pet carries uid, origin=tame and seq: %s %s %s" % [pet.get("uid"), pet.get("origin"), pet.get("seq")])
	print("[srvdom] tame pet=%s origin=%s seq=%d grade=%s genetics_equal_runs=%s genetics_equal_replay=%s ivs=%s" % [pet.uid, pet.origin, int(pet.seq), pet.grade, same, same_replay, CharacterStore.canon(pet.genetics.get("ivs", {}))])

func _import_checks() -> void:
	var st := _store(5)
	_gather_until(st, 1, "rock", 0, "stone", 1, 2)
	var save: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v2.json"))
	var h := st.state_hash()
	var codes: PackedStringArray = []
	for req in [["char.import", {"save": save}], ["act.deposit", {"slot_dict": FORGED, "count": 5000}], ["act.deposit", {"pet_dict": {"species": "tyrannosaurus", "hp": 999999}}], ["act.deposit", {"bag_slot": 0, "item": FORGED}]]:
		var e := st.apply(req[0], 1, req[1], 3)
		codes.append(str(e.get("err", "ok")))
		expect(e.get("err") == "invalid_asset", "%s with an offline dict returns invalid_asset (got %s)" % [req[0], e.get("err", "ok")])
	var unchanged := st.state_hash() == h
	expect(save is Dictionary and unchanged, "refused imports and dict deposits change nothing")
	# The real path: a bag slot of the server character leaves with its provenance.
	var d := _ok(st.apply("act.deposit", 1, {"bag_slot": 0, "count": 1}, 4), "deposit slot 0")
	var asset: Dictionary = d.r.get("asset", {}) if d.ok else {}
	expect(Provenance.is_server(asset) and int(asset.get("count", 0)) == 1, "a slot deposit hands over a stamped asset: %s" % asset)
	expect(st.invariants().is_empty(), "invariants hold after a deposit: %s" % [st.invariants()])
	print("[srvdom] offline import/deposit dicts -> %s unchanged=%s; slot deposit uid=%s origin=%s" % [",".join(codes), unchanged, asset.get("uid"), asset.get("origin")])

func _rid_checks() -> void:
	var st := _store(6)
	var first := _ok(st.apply("act.gather", 1, {"node_id": "rock", "rid": "r-1"}, 2), "rid gather")
	var seq := int(st.s.seq)
	var again := st.apply("act.gather", 1, {"node_id": "rock", "rid": "r-1"}, 3)
	var other := st.apply("act.eat", 1, {"bag_slot": 0, "rid": "r-1"}, 3)
	expect(bool(again.r.get("duplicate", false)) and int(st.s.seq) == seq and other.get("err") == "conflict", "a repeated rid applies once; reusing it for another op is a conflict")
	var h := st.state_hash()
	var long := st.apply("act.gather", 1, {"node_id": "rock", "rid": "r".repeat(65)}, 4)
	var typed := st.apply("act.gather", 1, {"node_id": "rock", "rid": 7}, 4)
	expect(long.get("err") == "bad_request" and typed.get("err") == "bad_request" and st.state_hash() == h, "a present but unusable rid (65 chars, an int) is bad_request with nothing applied")
	print("[srvdom] rid invalid long=%s int=%s unchanged=%s" % [long.get("err", "ok"), typed.get("err", "ok"), st.state_hash() == h])
	print("[srvdom] rid repeat duplicate=%s seq_unchanged=%s other_op=%s first_seq=%d" % [again.r.get("duplicate", false), int(st.s.seq) == seq, other.get("err"), int(first.r.get("seq", 0))])

## char.move shares one second's distance across every update in that second (contract §7).
func _move_checks() -> void:
	var st := _store(7)
	var bound := 1.6 * IntentHandlers.RUN_SPEED + 1.0
	var accepted := 0
	var x := 0.0
	for i in 10: # the reviewer's probe: ten 12 m hops inside one second
		if st.apply("char.move", 1, {"p": [x + 12.0, 0, 0]}, 2).ok:
			accepted += 1
			x += 12.0
	var small := 0
	for i in 20: # many small hops in the next second: refused once the sum passes the bound
		if st.apply("char.move", 1, {"p": [x + 1.0, 0, 0]}, 3).ok:
			small += 1
			x += 1.0
	var later: bool = st.apply("char.move", 1, {"p": [x + 12.0, 0, 0]}, 4).ok
	var travel: bool = st.apply("char.move", 1, {"p": [900, 0, 0], "reset": true}, 4).ok
	expect(accepted == 1 and small == int(bound) and later and travel, "move budget: one 12 m hop per second (got %d), %d of 20 1 m hops (expect %d), next second ok=%s, reset ok=%s" % [accepted, small, int(bound), later, travel])
	# The reviewer's probe: 999 s of silence must not bank 999 s of distance.
	var idle := st.apply("char.move", 1, {"p": [5900, 0, 0]}, 1003)
	var idle_ok: bool = st.apply("char.move", 1, {"p": [920, 0, 0]}, 2003).ok
	expect(idle.get("err") == "bad_request" and idle_ok, "idle time caps the budget: 5000 m after 999 s refused (%s), 20 m after 1000 s ok=%s" % [idle.get("err", "ok"), idle_ok])
	print("[srvdom] move budget bound=%.1f same_second_12m_accepted=%d/10 same_second_1m_accepted=%d/20 next_second=%s reset=%s teleport_after_idle=%s" % [bound, accepted, small, later, travel, idle.get("err", "ok")])

## char.receive: a deposited asset can come back once; forged or never-exported ones cannot.
func _receive_checks() -> void:
	var st := _store(8)
	_gather_until(st, 1, "rock", 0, "stone", 2, 2)
	var before := _units(st, 1)
	var d := _ok(st.apply("act.deposit", 1, {"bag_slot": 0, "count": 1}, 3), "deposit for receive")
	var asset: Dictionary = d.r.get("asset", {}) if d.ok else {}
	var back := _ok(st.apply("char.receive", 1, {"asset": asset}, 4), "receive the deposit")
	var restored := _units(st, 1) == before and int(st.s.exported.get("stone", 0)) == 0
	var twice := st.apply("char.receive", 1, {"asset": asset}, 5)
	var forged := st.apply("char.receive", 1, {"asset": FORGED}, 5)
	var bare := st.apply("char.receive", 1, {"asset": {"id": "stone", "count": 1}}, 5)
	expect(restored and st.invariants().is_empty(), "receive restores the deposited unit and the counters: %s vs %s, %s" % [before, _units(st, 1), st.invariants()])
	expect(twice.get("err") == "invalid_asset" and forged.get("err") == "invalid_asset" and bare.get("err") == "invalid_asset", "receive refuses a second return, a forged stamp and an unstamped dict: %s %s %s" % [twice.get("err"), forged.get("err"), bare.get("err")])
	var pt := _tame_once(12)
	var pet_uid: String = (pt.character(1).d.pets as Dictionary).keys()[0] if not (pt.character(1).d.pets as Dictionary).is_empty() else ""
	var pd := _ok(pt.apply("act.deposit", 1, {"pet_uid": pet_uid}, 10), "deposit pet")
	var pet: Dictionary = pd.r.get("asset", {}) if pd.ok else {}
	var pr := pt.apply("char.receive", 2, {"asset": pet}, 11)
	var pr2 := pt.apply("char.receive", 1, {"asset": pet}, 12)
	expect(pr.get("ok", false) and (pt.character(2).d.pets as Dictionary).has(pet_uid) and pr2.get("err") == "conflict" and pt.invariants().is_empty(), "a deposited pet comes back once (to account 2), a repeat is a conflict: %s %s" % [pr.get("err", "ok"), pr2.get("err", "ok")])
	# The reviewer's probes: with real units of the same def still exported, a repeat and an
	# edited body are refused; with a real pet exported, a forged pet with a fresh uid is too.
	_gather_until(st, 1, "rock", 0, "stone", 3, 6)
	var da := _ok(st.apply("act.deposit", 1, {"bag_slot": 0, "count": 1}, 7), "deposit A")
	var db := _ok(st.apply("act.deposit", 1, {"bag_slot": st.character(1).inventory().find_first(&"stone"), "count": 1}, 7), "deposit B") # W2-INV: one stone per slot
	var ua: Dictionary = da.r.get("asset", {}) if da.ok else {}
	var ub: Dictionary = db.r.get("asset", {}) if db.ok else {}
	var a1 := st.apply("char.receive", 1, {"asset": ua}, 8)
	var a2 := st.apply("char.receive", 1, {"asset": ua}, 8)
	var edited := ub.duplicate()
	edited["level"] = 9999
	var be := st.apply("char.receive", 1, {"asset": edited}, 8)
	var b1 := st.apply("char.receive", 1, {"asset": ub}, 8)
	expect(a1.get("ok", false) and a2.get("err") == "invalid_asset" and be.get("err") == "invalid_asset" and b1.get("ok", false) and st.invariants().is_empty(), "receive takes each exported body once, exactly: first=%s second=%s edited=%s real=%s" % [a1.get("err", "ok"), a2.get("err", "ok"), be.get("err", "ok"), b1.get("err", "ok")])
	var pd2 := _ok(pt.apply("act.deposit", 2, {"pet_uid": pet_uid}, 13), "deposit pet again")
	var fake := {"species": "tyrannosaurus", "hp": 999999, "uid": "p99999.0", "origin": "tame", "seq": 1}
	var pf := pt.apply("char.receive", 1, {"asset": fake}, 14)
	var pback := pt.apply("char.receive", 2, {"asset": pd2.r.get("asset", {}) if pd2.ok else {}}, 14)
	expect(pf.get("err") == "invalid_asset" and pback.get("ok", false) and pt.invariants().is_empty(), "a forged pet is refused and the real one still comes back: forged=%s real=%s" % [pf.get("err", "ok"), pback.get("err", "ok")])
	print("[srvdom] receive item=%s restored=%s twice=%s forged=%s unstamped=%s pet=%s pet_twice=%s same_def_first=%s same_def_second=%s edited_level=%s forged_pet=%s real_pet_back=%s" % [back.get("ok", false), restored, twice.get("err"), forged.get("err"), bare.get("err"), pr.get("err", "ok"), pr2.get("err", "ok"), a1.get("err", "ok"), a2.get("err", "ok"), be.get("err", "ok"), pf.get("err", "ok"), pback.get("err", "ok")])

## World writes are queued until the op commits: a handler that wrote and then failed (or hit
## an internal error) leaves the island as it was.
func _write_checks() -> void:
	var w := make_world()
	var st := _store(13, w)
	var left := int(w.nodes.rock.options[0].left)
	st.handlers.begin(st.s, int(st.s.seq) + 1, 2, 1, "act.gather", [], false)
	st.handlers._write("take_node_unit", ["rock", "stone"]) # as a handler does just before failing
	var queued_untouched := int(w.nodes.rock.options[0].left) == left
	var refused := st.apply("act.gather", 1, {"node_id": "far"}, 2) # next op starts with an empty queue
	var dropped: bool = int(w.nodes.rock.options[0].left) == left and st.handlers.writes.is_empty()
	_ok(st.apply("act.gather", 1, {"node_id": "rock"}, 3), "committed gather")
	var landed := int(w.nodes.rock.options[0].left) == left - 1
	expect(queued_untouched and refused.get("err") == "out_of_range" and dropped and landed, "world writes land only on commit: queued_untouched=%s dropped=%s landed=%s" % [queued_untouched, dropped, landed])
	print("[srvdom] world writes queued_untouched=%s uncommitted_dropped=%s committed_landed=%s" % [queued_untouched, dropped, landed])

## A scripted capture: craft a tier-1 net, knock the compy under 30 %, throw until it lands.
func _capture_checks() -> void:
	var w := make_world()
	var st := _store(14, w)
	_gather_until(st, 1, "bush", 1, "fibre_stalk", 4, 2)
	_gather_until(st, 1, "bush", 2, "branch", 1, 2)
	for i in 2: # explicit picks: twine is itself a fibre, so default picks could eat the first twine
		var fibre := st.character(1).inventory().find_first(&"fibre_stalk")
		_ok(st.apply("act.craft", 1, {"recipe_id": "twine", "picks": [fibre]}, 3), "twine %d" % i)
	_ok(st.apply("act.craft", 1, {"recipe_id": "capture_net_i"}, 4), "craft capture_net_i")
	var h := st.state_hash()
	var awake := st.apply("act.capture", 1, {"net_id": "compy1"}, 5)
	expect(awake.get("err") == "not_ready" and st.state_hash() == h, "capture refuses a creature that is not knocked out (%s)" % awake.get("err", "ok"))
	w.creatures.compy1.hp = 10.0
	var throws := 0
	var got := {}
	while throws < 30:
		w.creatures.compy1.knocked = true # a missed net wakes it; the fixture knocks it down again
		w.creatures.compy1.torpor = 1.0
		throws += 1
		got = _ok(st.apply("act.capture", 1, {"net_id": "compy1"}, 5 + throws), "capture throw %d" % throws)
		if not got.get("ok", false) or bool(got.r.get("captured", false)):
			break
	var captured := bool(got.get("r", {}).get("captured", false))
	var row := _row_for(st, 1, got.r.uids[0] if captured and not (got.r.uids as Array).is_empty() else "")
	var bagged: bool = row.get("id") == "captured_animal" and row.get("origin") == "tame" and Provenance.is_server(row)
	var spent: bool = int(_units(st, 1).get("capture_net_i", 0)) == 0 and not w.creatures.has("compy1")
	expect(captured and bagged and spent and st.invariants().is_empty(), "a capture lands: captured=%s bagged=%s net_spent_creature_gone=%s invariants=%s" % [captured, bagged, spent, st.invariants()])
	print("[srvdom] capture throws=%d captured=%s stack=%s origin=%s net_spent=%s awake_refused=%s" % [throws, captured, row.get("uid"), row.get("origin"), spent, awake.get("err", "ok")])

## Review round 3 probes: non-bool flags are refused (not a script error), keys an op does not
## read never reach the journal, char.settled drops an export record, and melee follows
## data/combat_tuning.json.
func _hardening_checks() -> void:
	var w := make_world()
	var st := _store(15, w)
	var h := st.state_hash()
	var codes: PackedStringArray = []
	for req in [["act.equip", {"slot": "weapon", "clear": "yes"}], ["act.equip", {"slot": "weapon", "clear": {"x": 1}}], ["char.move", {"p": [0, 0, 0], "reset": "yes"}]]:
		codes.append(str(st.apply(req[0], 1, req[1], 2).get("err", "ok")))
	var flags_ok := codes == PackedStringArray(["bad_request", "bad_request", "bad_request"]) and st.state_hash() == h
	expect(flags_ok, "non-bool clear/reset are bad_request with nothing changed: %s" % [codes])
	var g := _ok(st.apply("act.gather", 1, {"node_id": "rock", "option": 0, "junk": "x".repeat(200000)}, 3), "gather with junk")
	var junk_line := st.lines[-1].length()
	var last: Dictionary = JSON.parse_string(st.lines[-1])
	var trimmed: bool = g.ok and not (last.a as Dictionary).has("junk") and junk_line < 2000
	expect(trimmed, "junk args are dropped before the journal (line %d bytes, keys %s)" % [junk_line, (last.a as Dictionary).keys()])
	var d := _ok(st.apply("act.deposit", 1, {"bag_slot": 0, "count": 1}, 4), "deposit to settle")
	var asset: Dictionary = d.r.get("asset", {}) if d.ok else {}
	var uid := str(asset.get("uid", ""))
	var was_held := (st.s.exported_assets as Dictionary).has(uid)
	var settled := st.apply("char.settled", 1, {"uid": uid}, 5)
	var dropped: bool = settled.get("ok", false) and not (st.s.exported_assets as Dictionary).has(uid)
	var back := st.apply("char.receive", 1, {"asset": asset}, 6)
	var again := st.apply("char.settled", 1, {"uid": uid}, 6)
	expect(was_held and dropped and back.get("err") == "invalid_asset" and again.get("err") == "not_found" and st.invariants().is_empty(), "char.settled drops the record and the asset cannot come back: held=%s dropped=%s receive=%s again=%s" % [was_held, dropped, back.get("err", "ok"), again.get("err", "ok")])
	# Melee reads combat_tuning.json: a forced dodge always misses, and a changed unarmed_damage
	# changes the server's damage.
	w.creatures.compy1.dodge = 0.0
	CombatTuning.force_dodge = 1.0
	var miss := _ok(st.apply("act.attack", 1, {"net_id": "compy1"}, 7), "attack, forced dodge")
	CombatTuning.reset_overrides()
	var tune := CombatTuning.section("player_melee")
	tune["unarmed_damage"] = 20.0 # the cached section; dropped again below
	var hit := _ok(st.apply("act.attack", 1, {"net_id": "compy1"}, 8), "attack, unarmed 20")
	CombatTuning._data = {} # the next section() reloads the file
	# TACTICS: the basic attack has its own cooldown on the server too (basic_cooldown_s, 1/rate).
	var spam: Dictionary = st.apply("act.attack", 1, {"net_id": "compy1", "ms": 300}, 8)
	expect(spam.get("err") == "not_ready", "a second swing 300 ms later is refused on cooldown (%s)" % spam.get("err", "ok"))
	var base := maxf(20.0 * float(tune.min_damage_frac), 20.0 - 10.0 * float(tune.defense_factor)) * CombatCounters.multiplier(Data.creature(&"compsognathus").archetype, &"blunt")
	var want := base * (float(tune.crit_mult) if hit.r.get("kind") == "crit" else 1.0)
	var tuned: bool = miss.r.get("kind") == "dodge" and absf(float(hit.r.get("dealt", 0.0)) - want) < 0.001
	expect(tuned, "melee follows combat_tuning.json: forced dodge -> %s, unarmed 20 dealt %.3f (want %.3f)" % [miss.r.get("kind"), float(hit.r.get("dealt", 0.0)), want])
	print("[srvdom] hardening flags=%s junk_dropped=%s journal_line_bytes=%d settled=%s receive_after_settle=%s settle_twice=%s forced_dodge=%s unarmed20_dealt=%.2f want=%.2f" % [",".join(codes), trimmed, junk_line, dropped, back.get("err", "ok"), again.get("err", "ok"), miss.r.get("kind"), float(hit.r.get("dealt", 0.0)), want])

## Every op against hostile args: each HOSTILE row must be refused with its literal code and leave
## the hash, the journal and the error count alone. Then each op keeps only its allow-listed keys.
func _hostile_arg_checks() -> void:
	var w := make_world()
	var st := _store(16, w)
	_gather_until(st, 1, "rock", 0, "stone", 2, 2) # bag slot 0 holds stone for the bag-slot rows
	var start_errors := CharacterStore._errors.n
	var ops := {}
	var matched := 0
	var unchanged := true
	for i in HOSTILE.size():
		var row: Array = HOSTILE[i]
		var op := str(row[0])
		var args: Dictionary = row[1]
		var want := str(row[2])
		ops[op] = true
		var h := st.state_hash()
		var lines := st.lines.size()
		var errs := CharacterStore._errors.n
		var res := st.apply(op, 1, args, 3)
		var same := st.state_hash() == h and st.lines.size() == lines
		var hit: bool = not bool(res.get("ok", false)) and str(res.get("err", "")) == want
		# An engine error here means the handler hit a script error (apply() would have said server_error).
		var quiet := CharacterStore._errors.n == errs
		if hit:
			matched += 1
		unchanged = unchanged and same
		expect(hit and same and quiet, "HOSTILE[%d] %s %s -> want %s, got %s (%s), unchanged=%s errors=%d" % [i, op, args, want, res.get("err", "ok"), res.get("msg", ""), same, CharacterStore._errors.n - errs])
	var allowlist := 0
	for op: String in IntentHandlers.ARG_KEYS:
		var allowed: Array = (IntentHandlers.ARG_KEYS[op] as Array).duplicate()
		var a := {"rid": "r", "junk": 1}
		for k: String in allowed:
			a[k] = 1
		var got := IntentHandlers.known_args(op, a)
		var keys := got.keys()
		keys.sort()
		allowed.append("rid")
		allowed.sort()
		allowlist += 1
		expect(keys == allowed and not got.has("junk"), "allowlist %s keeps %s, want %s" % [op, keys, allowed])
	print("[srvdom] hostile rows=%d ops_covered=%d matched=%d script_errors=%d unchanged=%s allowlist_ops=%d" % [HOSTILE.size(), ops.size(), matched, CharacterStore._errors.n - start_errors, unchanged, allowlist])

# --- fuzz ----------------------------------------------------------------------------------

func _fuzz_and_replay(n: int, seed: int) -> void:
	var w := make_world()
	var st := _store(seed, w)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stats := {}
	var spawned := 1
	var t0 := Time.get_ticks_msec()
	for i in n:
		var acct := rng.randi_range(1, 3)
		var req := _random_op(rng, st, w, acct)
		var before := st.state_json()
		var res := st.apply(req[0], acct, req[1], 10 + i)
		var row: Array = stats.get(req[0], [0, 0])
		row[0 if res.get("ok", false) else 1] += 1
		stats[req[0]] = row
		if not res.get("ok", false) and st.state_json() != before:
			expect(false, "fuzz op %d %s %s failed (%s) but changed the state" % [i, req[0], req[1], res.get("err")])
			return
		var probs := st.invariants()
		if not probs.is_empty():
			expect(false, "fuzz op %d %s %s broke invariants: %s" % [i, req[0], req[1], probs])
			return
		spawned = _simulate(w, spawned)
	var ms := Time.get_ticks_msec() - t0
	var held := 0
	for acct in [1, 2, 3]:
		for k in _units(st, acct):
			held += int(_units(st, acct)[k])
	# act.capture's success path is _capture_checks()'s job: in the fuzz it lands about once in
	# 10,000 ops, so requiring it here would fail on any odds or tuning change.
	for op in ["act.gather", "act.craft", "act.loot", "act.equip", "act.eat", "act.attack", "act.tame", "act.place", "act.deposit", "char.move"]:
		expect(int(stats.get(op, [0, 0])[0]) > 0, "fuzz exercised a successful %s (stats %s)" % [op, stats.get(op)])
	print("[srvdom] fuzz ops=%d seq=%d ms=%d held_units=%d pets_minted=%d invariants=held_after_every_op stats=%s" % [n, int(st.s.seq), ms, held, int(st.s.pets_minted), CharacterStore.canon(stats)])
	# Replay from empty, with an empty island: the journal alone rebuilds the characters.
	var fresh := CharacterStore.new(WorldFacade.new(), "", seed)
	for line in st.lines:
		var why := fresh.replay_line(line)
		if why != "":
			expect(false, "replay stopped: %s" % why)
			return
	var a := st.state_json()
	var b := fresh.state_json()
	expect(a == b, "journal replay from empty reproduces byte-identical canonical JSON (%d vs %d bytes) live: %s replayed: %s" % [a.length(), b.length(), _around(a, b), _around(b, a)])
	print("[srvdom] replay lines=%d byte_identical=%s bytes=%d sha256=%s" % [st.lines.size(), a == b, a.length(), b.sha256_text().substr(0, 16)])

## The island moving on between ops: knockdowns, deaths and respawns, regrowth, new corpses.
static func _simulate(w: WorldFacade, spawned: int) -> int:
	for id: String in w.creatures.keys():
		var c: Dictionary = w.creatures[id]
		if float(c.hp) <= 0.0:
			w.creatures.erase(id)
		elif float(c.hp) < 0.3 * float(c.hp_max):
			c.knocked = true
			c.torpor = 1.0
	while w.creatures.size() < 3:
		spawned += 1
		var p := Vector3([0.8, -0.8, 0.0][spawned % 3], 0, [0.6, 0.6, -0.9][spawned % 3])
		w.add_creature("compy%d" % spawned, "compsognathus", p, 90.0)
	for id: String in w.nodes:
		for o: Dictionary in w.nodes[id].options:
			if int(o.left) <= 0 and id != "bare":
				o.left = 30
	var empty := true
	for s: Variant in w.corpses.carcass.slots:
		empty = empty and s == null
	if empty:
		_refill_corpse(w)
	return spawned

static func _pick(rng: RandomNumberGenerator, from: Array) -> Variant:
	return from[rng.randi_range(0, from.size() - 1)]

func _random_op(rng: RandomNumberGenerator, st: CharacterStore, w: WorldFacade, acct: int) -> Array:
	var roll := rng.randf()
	var ch := st.character(acct)
	if roll < 0.30:
		return ["act.gather", {"node_id": _pick(rng, NODES), "option": rng.randi_range(0, 3)}]
	if roll < 0.42:
		var rid: String = _pick(rng, RECIPES)
		var a := {"recipe_id": rid}
		if rng.randf() < 0.25:
			var picks := []
			for _k in rng.randi_range(1, 3):
				picks.append(rng.randi_range(-1, 20))
			a["picks"] = picks
		return ["act.craft", a]
	if roll < 0.50:
		var p := [rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-1.2, 1.2)]
		if rng.randf() < 0.05:
			p = [500.0, 0.0, 0.0] # a teleport: refused
		return ["char.move", {"p": p}]
	if roll < 0.55:
		var a := {"corpse_id": "carcass" if rng.randf() < 0.9 else "nope", "slot": rng.randi_range(0, 3)}
		if rng.randf() < 0.5:
			a["count"] = rng.randi_range(1, 3)
		return ["act.loot", a]
	if roll < 0.62:
		if rng.randf() < 0.2:
			return ["act.equip", {"slot": _pick(rng, ["weapon", "tool", "head", "bogus"]), "clear": true}]
		return ["act.equip", {"bag_slot": rng.randi_range(0, 20)}]
	if roll < 0.69:
		return ["act.eat", {"bag_slot": rng.randi_range(0, 20)}]
	var ids: Array = w.creatures.keys() + ["ghost"]
	if roll < 0.80:
		return ["act.attack", {"net_id": _pick(rng, ids)}]
	if roll < 0.85:
		return ["act.tame", {"net_id": _pick(rng, ids), "food": _pick(rng, FOODS)}]
	if roll < 0.88:
		return ["act.capture", {"net_id": _pick(rng, ids)}]
	if roll < 0.91:
		return ["act.place", {"kind": _pick(rng, KINDS), "cell": [rng.randi_range(-4, 4), rng.randi_range(-4, 4)], "rot": rng.randi_range(0, 4)}]
	if roll < 0.97:
		var pets: Array = (ch.d.pets as Dictionary).keys()
		var k := rng.randf()
		if k < 0.6:
			return ["act.deposit", {"bag_slot": rng.randi_range(0, 20), "count": rng.randi_range(1, 4)}]
		if k < 0.8:
			return ["act.deposit", {"pet_uid": _pick(rng, pets) if not pets.is_empty() and rng.randf() < 0.7 else "p0.0"}]
		return ["act.deposit", {"slot_dict": FORGED, "count": 1}]
	return [_pick(rng, ["char.import", "act.fly", "char.wallet"]), {"save": FORGED, "wallet": rng.randi_range(-1, 50)}]

# --- durability ----------------------------------------------------------------------------

func _disk_checks() -> void:
	var dir := "user://t_srvdom_store"
	_clear(dir)
	var w := make_world()
	var st := CharacterStore.new(w, dir, 9)
	st.snapshot_every_ops = 40
	expect(st.open() == "", "fresh store opens")
	for acct in [1, 2, 3]:
		st.apply("char.create", acct, {"name": "Disk%d" % acct}, 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var spawned := 1
	for i in 150:
		var acct := rng.randi_range(1, 3)
		var req := _random_op(rng, st, w, acct)
		st.apply(req[0], acct, req[1], 10 + i)
		spawned = _simulate(w, spawned)
	st._close_journal() # a crash: no shutdown snapshot, so boot must replay the journal
	var live := st.state_json()
	var journaled := FileAccess.get_file_as_string(dir.path_join("journal.jsonl")).count("\n")
	var b := CharacterStore.new(WorldFacade.new(), dir, 9)
	var why := b.open()
	var reopened := why == "" and b.state_json() == live and journaled > 0
	expect(reopened, "snapshot + journal boot reproduces the live state (%s, %d journal lines)" % [why, journaled])
	var shut := b.close()
	var snap_text := FileAccess.get_file_as_string(dir.path_join("snapshot.json"))
	var clean := shut == "" and FileAccess.get_file_as_string(dir.path_join("journal.jsonl")) == "" and snap_text.contains(CharacterStore.data_hash())
	expect(clean, "close() snapshots with the data hash and leaves an empty journal (%s)" % shut)
	var f := FileAccess.open(dir.path_join("journal.jsonl"), FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string('{"a":{"node_id":"TORN') # a write torn by a crash
	f.close()
	var c := CharacterStore.new(WorldFacade.new(), dir, 9)
	why = c.open()
	c.close()
	var torn := why == "" and c.state_json() == live and not FileAccess.get_file_as_string(dir.path_join("journal.jsonl")).contains("TORN")
	expect(torn, "a torn journal tail is cut and boot still matches (%s) first difference: %s" % [why, _around(c.state_json(), live)])
	# A deploy that changed the data files: boot flags it and re-snapshots under the new hash.
	var fs := FileAccess.open(dir.path_join("snapshot.json"), FileAccess.WRITE)
	fs.store_string(snap_text.replace(CharacterStore.data_hash(), "older-data"))
	fs.close()
	var e := CharacterStore.new(WorldFacade.new(), dir, 9)
	why = e.open()
	var flagged := why == "" and e.data_changed and e.state_json() == live and FileAccess.get_file_as_string(dir.path_join("snapshot.json")).contains(CharacterStore.data_hash())
	e.close()
	expect(flagged, "a snapshot from other data files sets data_changed and is re-snapshotted (%s)" % why)
	# The seed is on disk from genesis, so a boot with another seed is refused, not replayed.
	var wrong := CharacterStore.new(WorldFacade.new(), dir, 10).open()
	_clear(dir)
	var g := CharacterStore.new(WorldFacade.new(), dir, 9)
	var unopened := g.apply("char.create", 1, {"name": "Early"}, 1)
	var genesis_on_disk := g.open() == "" and FileAccess.file_exists(dir.path_join("snapshot.json"))
	g.apply("char.create", 1, {"name": "Early"}, 1)
	g._close_journal() # crash before any automatic snapshot
	var wrong_early := CharacterStore.new(WorldFacade.new(), dir, 11).open()
	DirAccess.remove_absolute(dir.path_join("snapshot.json"))
	var orphan := CharacterStore.new(WorldFacade.new(), dir, 9).open()
	expect(wrong != "" and wrong_early != "" and genesis_on_disk and unopened.get("err") == "server_error" and orphan != "", "seed and open guards: wrong_seed=%s wrong_seed_before_snapshot=%s genesis_on_disk=%s apply_before_open=%s orphan_journal=%s" % [wrong, wrong_early, genesis_on_disk, unopened.get("err", "ok"), orphan])
	print("[srvdom] disk seq=%d crash_replay_lines=%d reopen_equal=%s clean_close_snapshot=%s torn_tail_cut=%s data_change_flagged=%s wrong_seed_refused=%s early_wrong_seed_refused=%s apply_before_open=%s orphan_journal_refused=%s" % [int(st.s.seq), journaled, reopened, clean, torn, flagged, wrong != "", wrong_early != "", unopened.get("err", "ok"), orphan != ""])
	_clear(dir)

static func _around(a: String, b: String) -> String:
	var i := 0
	while i < mini(a.length(), b.length()) and a[i] == b[i]:
		i += 1
	return a.substr(maxi(0, i - 80), 160)

static func _clear(dir: String) -> void:
	for name in ["snapshot.json", "snapshot.json.tmp", "journal.jsonl"]:
		if FileAccess.file_exists(dir.path_join(name)):
			DirAccess.remove_absolute(dir.path_join(name))
