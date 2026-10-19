class_name ServerDomainChecks
extends RefCounted
## W1-SRVDOM acceptance checks. tests/t_server_domain.gd loads this on the first frame, once
## the Data autoload exists (Crafting and friends cannot compile before it). Prints one
## "[srvdom] ..." evidence line per check; run() returns the failures.

const RECIPES := ["twine", "thread", "club", "fence_kit", "campfire_kit", "bonfire_kit", "stone_shot", "herbivore_feed", "capture_net_i", "sign_kit", "charcoal", "bandage", "work_axe", "stone_fire_pit_kit"]
const NODES := ["rock", "bush", "grass", "ore", "far", "bare", "nope"]
const KINDS := ["fence", "campfire", "bonfire", "sign", "workbench", "nope"]
const FOODS := ["berry", "herb_leaf", "raw_meat", "stone", "fibre_stalk"]
const FORGED := {"id": "raid_helm", "count": 5000, "level": 9999, "uid": "i1.0", "origin": "gather", "seq": 1}

var failures: Array[String] = []

func run(fuzz_ops: int = 10000) -> Array[String]:
	_gather_checks()
	_craft_checks()
	_tame_checks()
	_import_checks()
	_rid_checks()
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
	print("[srvdom] rid repeat duplicate=%s seq_unchanged=%s other_op=%s first_seq=%d" % [again.r.get("duplicate", false), int(st.s.seq) == seq, other.get("err"), int(first.r.get("seq", 0))])

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
	for op in ["act.gather", "act.craft", "act.loot", "act.equip", "act.eat", "act.attack", "act.tame", "act.capture", "act.place", "act.deposit", "char.move"]:
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
	expect(a == b, "journal replay from empty reproduces byte-identical canonical JSON (%d vs %d bytes)" % [a.length(), b.length()])
	print("[srvdom] replay lines=%d byte_identical=%s bytes=%d sha256=%s" % [st.lines.size(), a == b, a.length(), b.sha256_text().substr(0, 16)])

## The island moving on between ops: knockdowns, deaths and respawns, regrowth, new corpses.
static func _simulate(w: WorldFacade, spawned: int) -> int:
	for id: String in w.creatures.keys():
		var c: Dictionary = w.creatures[id]
		if float(c.hp) <= 0.0:
			w.creatures.erase(id)
		elif float(c.hp) < 0.3 * float(c.hp_max):
			c.knocked = true
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
	st.close()
	var live := st.state_json()
	var b := CharacterStore.new(WorldFacade.new(), dir, 9)
	var why := b.open()
	b.close()
	var reopened := why == "" and b.state_json() == live
	expect(reopened, "snapshot + journal boot reproduces the live state (%s)" % why)
	var f := FileAccess.open(dir.path_join("journal.jsonl"), FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string('{"a":{"node_id":"TORN') # a write torn by a crash
	f.close()
	var c := CharacterStore.new(WorldFacade.new(), dir, 9)
	why = c.open()
	c.close()
	var torn := why == "" and c.state_json() == live and not FileAccess.get_file_as_string(dir.path_join("journal.jsonl")).contains("TORN")
	expect(torn, "a torn journal tail is cut and boot still matches (%s)" % why)
	print("[srvdom] disk seq=%d snapshot=%s reopen_equal=%s torn_tail_cut=%s" % [int(st.s.seq), FileAccess.file_exists(dir.path_join("snapshot.json")), reopened, torn])
	_clear(dir)

static func _clear(dir: String) -> void:
	for name in ["snapshot.json", "snapshot.json.tmp", "journal.jsonl"]:
		if FileAccess.file_exists(dir.path_join(name)):
			DirAccess.remove_absolute(dir.path_join(name))
