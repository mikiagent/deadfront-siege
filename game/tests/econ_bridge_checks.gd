extends RefCounted
## No class_name: test code; tests/t_econ.gd loads it by path once the Data autoload exists.
## VaultBridge acceptance: every asset that reaches the economy came out of a server character
## through act.deposit, comes back only through char.receive, and nothing is duplicated, lost
## or overdrawn, including when the process dies between the two stores' journals.

const DIR := "user://econ_bridge_tests"
const T0 := 1760000000
const DEFS := ["stone", "berry", "fibre_stalk", "branch"]

var failures: Array[String] = []
var _rid := 0
var _world: WorldFacade
var _rules: EconRules

func run() -> Array[String]:
	for test: Callable in [_test_deposit, _test_refusals, _test_sales, _test_pets_and_cages, _test_crash_recovery, _test_fuzz]:
		if test.call() != true:
			failures.append("%s stopped early (script error)" % test.get_method())
	return failures

func _expect(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond

# --- rig ---------------------------------------------------------------------------------

## Both stores and the bridge; the economy on disk (it is restarted in the crash tests), the
## characters in memory (their journal lines are kept for the replay check).
func _rig(name: String, budget: int = 0) -> VaultBridge:
	var dir := DIR + "/" + name
	_wipe(dir)
	_rules = EconRules.load_default()
	_rules.market.starting_wallet = 500
	_rules.market.settlers.daily_budget = budget
	var econ := _econ(dir)
	_world = (load("res://tests/srvdom_checks.gd") as GDScript).call("make_world")
	for n: Dictionary in _world.nodes.values():
		for o: Dictionary in n.options:
			o.left = 1000000
	var b := VaultBridge.new(econ, CharacterStore.new(_world, "", 7))
	for acct in [1, 2, 3]:
		_expect(b.hello(acct, "Trader%d" % acct, T0).ok, "hello %d" % acct)
	return b

func _econ(dir: String) -> EconStore:
	var econ := EconStore.new(MarketEngine.new(_rules, EconCatalog.from_data()), dir)
	econ.snapshot_every_ops = 0
	_expect(econ.open() == "", "economy store opens")
	return econ

## The process died: the economy reboots from its disk; the character store (journaled per
## op) keeps what it committed.
func _restart(b: VaultBridge, ts: int) -> VaultBridge:
	b.econ.close()
	var again := VaultBridge.new(_econ(b.econ.dir), b.chars)
	var why := again.recover(ts)
	_expect(why == "", "recover() after a restart: %s" % why)
	return again

func _wipe(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var da := DirAccess.open(dir)
	if da:
		for f in da.get_files():
			da.remove(f)

func _op(b: VaultBridge, op: String, acct: int, args: Dictionary, ts: int = T0) -> Dictionary:
	if op in VaultBridge.CLIENT_OPS and op not in MarketEngine.READ and not args.has("rid"):
		_rid += 1
		args = args.duplicate()
		args.rid = "b%d" % _rid
	var res := b.apply(op, acct, args, ts)
	var bad := _broken(b)
	_expect(bad.is_empty(), "%s left the stores inconsistent: %s" % [op, ", ".join(bad)])
	return res

func _ok(b: VaultBridge, op: String, acct: int, args: Dictionary, ts: int = T0) -> Dictionary:
	var res := _op(b, op, acct, args, ts)
	_expect(res.ok, "%s should succeed: %s" % [op, str(res)])
	return res.get("r", {})

func _gather(b: VaultBridge, acct: int, node: String, option: int, item: String, n: int) -> void:
	for _i in 60:
		if _units(b, acct).get(item, 0) >= n:
			return
		b.chars.apply("act.gather", acct, {"node_id": node, "option": option}, T0)

static func _units(b: VaultBridge, acct: int) -> Dictionary:
	var out := {}
	for row: Variant in b.chars.character(acct).d.bag:
		if row is Dictionary:
			out[str(row.id)] = int(out.get(str(row.id), 0)) + int(row.count)
	return out

static func _slot(b: VaultBridge, acct: int, item: String) -> int:
	var bag: Array = b.chars.character(acct).d.bag
	for i in bag.size():
		if bag[i] is Dictionary and str(bag[i].id) == item:
			return i
	return -1

func _hash(b: VaultBridge) -> String:
	return b.econ.engine.state_json().sha256_text() + b.chars.state_hash()

## Tames a knocked-out compy for `acct` (srvdom's fixture creature) and returns the pet uid.
func _tame(b: VaultBridge, acct: int, net_id: String) -> String:
	_gather(b, acct, "bush", 0, "berry", 3)
	_world.add_creature(net_id, "compsognathus", Vector3(1, 0, 1), 90.0, {"hp": 20.0, "knocked": true})
	var r := {}
	for i in 3:
		r = b.chars.apply("act.tame", acct, {"net_id": net_id, "food": "berry"}, T0 + i)
	_expect(r.get("ok", false) and r.r.has("pet_uid"), "tamed %s: %s" % [net_id, str(r)])
	return str(r.get("r", {}).get("pet_uid", ""))

## A captured_animal cage in `acct`'s bag (srvdom's capture steps); returns its bag slot.
func _capture(b: VaultBridge, acct: int, net_id: String) -> int:
	_gather(b, acct, "bush", 1, "fibre_stalk", 4)
	_gather(b, acct, "bush", 2, "branch", 1)
	for i in 2:
		var fibre := b.chars.character(acct).inventory().find_first(&"fibre_stalk")
		b.chars.apply("act.craft", acct, {"recipe_id": "twine", "picks": [fibre]}, T0)
	_expect(b.chars.apply("act.craft", acct, {"recipe_id": "capture_net_i"}, T0).ok, "craft a capture net")
	_world.add_creature(net_id, "compsognathus", Vector3(1, 0, 1), 90.0, {"hp": 10.0})
	for i in 40:
		_world.creatures[net_id].knocked = true
		var got := b.chars.apply("act.capture", acct, {"net_id": net_id}, T0 + i)
		if got.get("ok", false) and got.r.get("captured", false):
			break
		if _units(b, acct).get("capture_net_i", 0) == 0:
			b.chars.apply("act.craft", acct, {"recipe_id": "capture_net_i"}, T0)
	return _slot(b, acct, "captured_animal")

# --- the cross-store invariants ------------------------------------------------------------

## Every rule that must hold between ops, across both stores. Empty = all hold.
func _broken(b: VaultBridge) -> Array[String]:
	var s := b.econ.engine.state()
	var bad: Array[String] = EconInvariants.check(s)
	bad.append_array(b.chars.invariants())
	var cs := b.chars.s
	var defs := {}
	for d: Dictionary in [cs.exported, s.items_in, s.items_out]:
		for k in d:
			defs[k] = true
	for k in defs:
		var into := int(s.items_in.get(k, 0)) - int(s.items_out.get(k, 0))
		if int(cs.exported.get(k, 0)) != into:
			bad.append("%s: characters exported %d, the vaults took in %d net" % [k, int(cs.exported.get(k, 0)), into])
	if int(cs.pets_exported) != int(s.pets_in) - int(s.pets_out):
		bad.append("pets: exported %d, vaults net %d" % [int(cs.pets_exported), int(s.pets_in) - int(s.pets_out)])
	for key: String in cs.chars:
		if int(cs.chars[key].wallet) != int(s.accounts[key].wallet):
			bad.append("account %s: character wallet %d, ledger %d" % [key, int(cs.chars[key].wallet), int(s.accounts[key].wallet)])
	if not s.inflight.is_empty() or not s.retired.is_empty():
		bad.append("bridge left inflight %s retired %s" % [str(s.inflight), str(s.retired)])
	var bodies := {}
	for acct: Dictionary in s.accounts.values():
		bodies.merge(acct.vault_items)
		bodies.merge(acct.vault_pets)
	for l: Dictionary in s.listings.values():
		bodies[str(l.asset.uid)] = l.asset
	for uid: String in cs.exported_assets:
		if not s.src.has(uid):
			bad.append("export %s is in no vault" % uid)
		elif Ledger.canon(bodies[uid]) != str(cs.exported_assets[uid]):
			bad.append("%s is held in another shape than it was exported" % uid)
	for uid: String in s.src:
		if not cs.exported_assets.has(uid):
			bad.append("%s is held as exported but the character store has no export" % uid)
	return bad

# --- tests -------------------------------------------------------------------------------

func _test_deposit() -> bool:
	var b := _rig("deposit")
	_gather(b, 1, "rock", 0, "stone", 12)
	var slot := _slot(b, 1, "stone")
	var row: Dictionary = b.chars.character(1).d.bag[slot].duplicate(true)
	var r := _ok(b, "vault.deposit", 1, {"bag_slot": slot, "rid": "dep-a"})
	_expect(r.uid == row.uid and _units(b, 1).get("stone", 0) == 0 and b.econ.engine.L.acct(1).vault_items.has(row.uid), "a whole stack moves from the bag to the vault under its own uid")
	var h := _hash(b)
	var again := _op(b, "vault.deposit", 1, {"bag_slot": slot, "rid": "dep-a"})
	var same: bool = again.ok and _hash(b) == h and again.r.uid == r.uid
	_expect(same, "a repeated rid applies nothing in either store and answers the same")
	_gather(b, 1, "rock", 0, "stone", 8)
	slot = _slot(b, 1, "stone")
	var have: int = _units(b, 1).stone
	r = _ok(b, "vault.deposit", 1, {"bag_slot": slot, "count": 3})
	_expect(int(r.item.count) == 3 and _units(b, 1).stone == have - 3 and str(r.uid).ends_with(".0") and r.item.origin == "gather", "part of a stack leaves with a new uid and keeps its origin")
	print("[econ-bridge] deposit whole=%s part=%s repeat_same_and_unchanged=%s" % [row.uid, r.uid, same])
	return true

func _test_refusals() -> bool:
	var b := _rig("refusals")
	_gather(b, 1, "rock", 0, "stone", 8)
	var slot := _slot(b, 1, "stone")
	var h := _hash(b)
	var forged := {"id": "raid_helm", "count": 1, "level": 60, "uid": "i1.0", "origin": "craft", "seq": 1}
	var codes: Array = []
	for args: Dictionary in [{"slot_dict": forged}, {"pet_dict": {"species": "tyrannosaurus"}}, {"bag_slot": slot, "item": forged}, {"bag_slot": 19}, {"pet_uid": "p9.0"}, {"bag_slot": "x"}]:
		codes.append(str(_op(b, "vault.deposit", 1, args).get("err", "ok")))
	for op in MarketEngine.BRIDGE + ["bridge.begin", "bridge.end", "bridge.settled"]:
		codes.append(str(_op(b, op, 1, {"slot_dict": forged, "rid": "x"}).get("err", "ok")))
	_expect(_hash(b) == h and not "ok" in codes, "client dicts, empty slots and server-only ops change nothing: %s" % ", ".join(codes))
	_rules.limits.deposit_caps.stone = 2
	var capped := _op(b, "vault.deposit", 1, {"bag_slot": slot})
	_expect(capped.get("err") == "limit_reached" and _hash(b) == h, "a deposit the vault would refuse never leaves the bag (%s)" % capped.get("err", "ok"))
	_rules.limits.deposit_caps.stone = 2000
	var uid := str(_ok(b, "vault.deposit", 1, {"bag_slot": slot}).uid)
	# A body the character store would not take back (edited in flight) stays in the vault.
	var saved: String = b.chars.s.exported_assets[uid]
	b.chars.s.exported_assets[uid] = saved.replace('"count":', '"count":1')
	h = _hash(b)
	var refused := b.apply("vault.withdraw", 1, {"uid": uid, "rid": "w-bad"}, T0)
	_expect(not refused.ok and _hash(b) == h and b.econ.engine.L.acct(1).vault_items.has(uid), "a withdrawal char.receive refuses leaves the asset in the vault (%s)" % refused.get("err", "ok"))
	b.chars.s.exported_assets[uid] = saved
	var back := _ok(b, "vault.withdraw", 1, {"uid": uid})
	_expect(int(back.item.count) == int(_units(b, 1).stone) and not b.chars.s.exported_assets.has(uid), "the same withdrawal goes through once the body matches")
	var twice := _op(b, "vault.withdraw", 1, {"uid": uid})
	_expect(twice.get("err") == "not_found", "a second withdrawal finds nothing (%s)" % twice.get("err", "ok"))
	print("[econ-bridge] refusals codes=%s cap=%s edited_body=%s twice=%s" % [",".join(codes), capped.get("err", "ok"), refused.get("err", "ok"), twice.get("err", "ok")])
	return true

func _test_sales() -> bool:
	var b := _rig("sales")
	_gather(b, 1, "rock", 0, "stone", 10)
	var stack: Dictionary = b.chars.character(1).d.bag[_slot(b, 1, "stone")]
	var n := int(stack.count)
	var uid := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, "stone")}).uid)
	var lid := str(_ok(b, "market.list_fixed", 1, {"asset": {"uid": uid}, "unit_price": 7, "duration_h": 24}).listing.id)
	var bought := _ok(b, "market.buy", 2, {"listing_id": lid, "count": n})
	var got := _ok(b, "vault.withdraw", 2, {"uid": uid})
	_expect(_units(b, 2).get("stone", 0) == n and int(got.item.count) == n, "the buyer's character holds the %d stone it bought" % n)
	_expect(int(b.chars.character(1).d.wallet) == int(b.econ.engine.L.acct(1).wallet) and int(b.chars.character(2).d.wallet) == 500 - 7 * n, "both wallets are mirrored to the characters")
	var broke := _op(b, "market.buy", 3, {"listing_id": lid, "count": 1})
	_expect(not broke.ok, "a sold listing cannot be bought again")
	# A partial buy splits the exported body: the export is settled, the parts stay in the books.
	_gather(b, 1, "rock", 0, "stone", 9)
	var whole: int = _units(b, 1).stone
	var src := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, "stone")}).uid)
	lid = str(_ok(b, "market.list_fixed", 1, {"asset": {"uid": src}, "unit_price": 5, "duration_h": 24}).listing.id)
	var part := _ok(b, "market.buy", 3, {"listing_id": lid, "count": 2})
	_expect(not b.chars.s.exported_assets.has(src) and b.econ.engine.state().retired.is_empty(), "a split export is settled in the character store")
	var stuck := _op(b, "vault.withdraw", 3, {"uid": str(part.asset.uid)})
	_ok(b, "market.cancel", 1, {"listing_id": lid})
	var rest := _op(b, "vault.withdraw", 1, {"uid": src})
	var held := int(b.econ.engine.L.acct(1).vault_items[src].count) + int(b.econ.engine.L.acct(3).vault_items[str(part.asset.uid)].count)
	_expect(stuck.get("err") == "not_withdrawable" and rest.get("err") == "not_withdrawable" and held == whole, "both parts stay in the vaults, none lost (%d of %d)" % [held, whole])
	var poor := _op(b, "market.buy", 3, {"listing_id": lid, "count": 1})
	_expect(not poor.ok, "a cancelled listing cannot be bought")
	print("[econ-bridge] sale whole=%d stone paid=%d wallets_mirrored=%s split_settled=%s parts=%s,%s" % [n, int(bought.paid), int(b.chars.character(1).d.wallet) == int(b.econ.engine.L.acct(1).wallet), not b.chars.s.exported_assets.has(src), stuck.get("err", "ok"), rest.get("err", "ok")])
	return true

func _test_pets_and_cages() -> bool:
	var b := _rig("pets")
	var pid := _tame(b, 1, "compy_a")
	var pet: Dictionary = b.chars.character(1).d.pets[pid].duplicate(true)
	_ok(b, "vault.deposit", 1, {"pet_uid": pid})
	_expect(not b.chars.character(1).d.pets.has(pid), "the deposited pet left the character")
	var lid := str(_ok(b, "market.list_fixed", 1, {"asset": {"uid": pid}, "unit_price": 90, "duration_h": 24}).listing.id)
	var found := _ok(b, "market.search", 2, {"asset": "pet", "species": "compsognathus"})
	_expect(int(found.total) == 1 and found.results[0].asset.uid == pid and found.results[0].asset.has("genetics"), "the caged pet is listed with its uid and genetics")
	_ok(b, "market.buy", 2, {"listing_id": lid, "count": 1})
	_ok(b, "vault.withdraw", 2, {"uid": pid})
	var got: Dictionary = b.chars.character(2).d.pets.get(pid, {})
	_expect(CharacterStore.canon(got) == CharacterStore.canon(CharacterStore.wire(pet)), "the buyer's character holds the same bonded pet: uid, origin, lineage, stats (no re-taming)")
	var slot := _capture(b, 1, "compy_b")
	_expect(slot >= 0, "a capture put a cage in the bag")
	if slot < 0:
		return true
	var cage: Dictionary = b.chars.character(1).d.bag[slot].duplicate(true)
	var cid := str(_ok(b, "vault.deposit", 1, {"bag_slot": slot}).uid)
	lid = str(_ok(b, "market.list_auction", 1, {"asset": {"uid": cid}, "start_bid": 30, "buyout": 80, "duration_h": 24}).listing.id)
	_ok(b, "market.bid", 3, {"listing_id": lid, "amount": 30})
	_ok(b, "market.buyout", 2, {"listing_id": lid})
	_ok(b, "vault.withdraw", 2, {"uid": cid})
	var row: Dictionary = b.chars.character(2).d.bag[_slot(b, 2, "captured_animal")]
	_expect(row.attributes.species == "compsognathus" and CharacterStore.canon(row.attributes) == CharacterStore.canon(CharacterStore.wire(cage.attributes)), "the buyer gets the untamed cage with its species and genetics")
	_expect(int(b.chars.character(3).d.wallet) == 500 and int(b.econ.engine.L.acct(3).wallet) == 500, "the outbid bidder's hold came back, mirrored")
	print("[econ-bridge] pet uid=%s origin=%s to_buyer=%s cage=%s species=%s outbid_refunded=%s" % [pid, pet.origin, b.chars.character(2).d.pets.has(pid), cid, row.attributes.species, int(b.chars.character(3).d.wallet) == 500])
	return true

func _test_crash_recovery() -> bool:
	var b := _rig("crash")
	_gather(b, 1, "rock", 0, "stone", 12)
	# 1. Died after act.deposit, before the vault: boot puts the asset in the vault.
	b.econ.apply("bridge.begin", 1, {"rid": "crash-1"}, T0)
	var out := b.chars.apply("act.deposit", 1, {"bag_slot": _slot(b, 1, "stone"), "count": 4}, T0)
	var uid := str(out.r.asset.uid)
	b = _restart(b, T0 + 1)
	_expect(b.econ.engine.L.acct(1).vault_items.has(uid) and _broken(b).is_empty(), "a deposit cut after act.deposit lands in the vault at boot: %s" % ", ".join(_broken(b)))
	var h := _hash(b)
	var repeat := _op(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, "stone"), "rid": "crash-1"})
	_expect(repeat.ok and _hash(b) == h, "the client's retry of that rid applies nothing")
	# 2. Died after bridge.begin only: nothing moved, the mark is dropped.
	b.econ.apply("bridge.begin", 1, {"rid": "crash-2"}, T0)
	b = _restart(b, T0 + 2)
	_expect(_hash(b) != "" and _broken(b).is_empty() and b.econ.engine.L.acct(1).vault_items.size() == 1, "a deposit cut before act.deposit is dropped at boot")
	# 3. Died after char.receive (which runs first), before the vault let go: boot finishes it.
	b.chars.apply("char.receive", 1, {"asset": b.econ.engine.L.acct(1).vault_items[uid]}, T0)
	b = _restart(b, T0 + 3)
	_expect(not b.econ.engine.L.acct(1).vault_items.has(uid) and _broken(b).is_empty(), "a withdrawal cut after char.receive leaves the vault at boot (no duplicate): %s" % ", ".join(_broken(b)))
	# 4. Died after a partial buy and a wallet move, before settle and mirror.
	var src := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, "stone")}).uid)
	var lid := str(_ok(b, "market.list_fixed", 1, {"asset": {"uid": src}, "unit_price": 3, "duration_h": 24}).listing.id)
	b.econ.apply("market.buy", 2, {"listing_id": lid, "count": 1, "rid": "crash-4"}, T0)
	b = _restart(b, T0 + 4)
	_expect(_broken(b).is_empty() and not b.chars.s.exported_assets.has(src), "boot settles the split export and mirrors the wallets: %s" % ", ".join(_broken(b)))
	print("[econ-bridge] crash deposit_after_export=landed deposit_before_export=dropped withdraw_after_receive=finished split_before_settle=settled consistent=%s" % _broken(b).is_empty())
	return true

## Seeded random traffic through the bridge (and a few cut-in-half moves with a restart),
## with every cross-store invariant after every op; then both journals replay byte for byte.
func _test_fuzz() -> bool:
	var b := _rig("fuzz", 2000)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261020
	for acct in [1, 2, 3]:
		for i in 2:
			_tame(b, acct, "compy_%d_%d" % [acct, i])
	var ts := T0 + 10
	var tally := {}
	var crashes := 0
	var last := {}
	for i in 3000:
		ts += rng.randi_range(0, 900)
		var who := rng.randi_range(1, 3)
		if rng.randf() < 0.004:
			crashes += 1
			b = _half_move(b, rng, who, ts)
			continue
		var pick := _fuzz_op(b, rng, who)
		var op: String = pick[0]
		var args: Dictionary = pick[1]
		var before := _hash(b)
		var repeat: bool = args.has("rid") and rng.randf() < 0.03 and last.has(who)
		if repeat:
			op = last[who][0]
			args = last[who][1]
		# A rid the books still hold is a double submit; an evicted one applies again (contract 5.3).
		var dup: bool = repeat and b.econ.engine.L.acct(who).rid_cache.has(str(args.rid))
		var res: Dictionary = b.chars.apply(op, who, args, ts) if op.begins_with("act.") else b.apply(op, 0 if op == "sys.tick" else who, args, ts)
		var bad := _broken(b)
		if res.get("err") == "server_error":
			bad.append("server_error %s" % res.get("msg", ""))
		if not bad.is_empty():
			_expect(false, "fuzz op %d %s %s broke: %s" % [i, op, str(args), ", ".join(bad)])
			return true
		if (not res.ok or dup) and _hash(b) != before and not op.begins_with("act."):
			_expect(false, "fuzz op %d %s changed state although it %s: %s" % [i, op, "failed" if not res.ok else "repeated a rid", str(res)])
			return true
		if res.ok and args.has("rid") and not repeat:
			last[who] = [op, args]
		var row: Array = tally.get(op, [0, 0])
		row[0 if res.ok else 1] += 1
		tally[op] = row
	var parts: PackedStringArray = []
	for op: String in tally:
		parts.append("%s %d/%d" % [op, tally[op][0], tally[op][0] + tally[op][1]])
	print("[econ-bridge] fuzz 3000 ops, %d restarts mid-move, invariants of both stores after every op: %s" % [crashes, ", ".join(parts)])
	for op in ["vault.deposit", "vault.withdraw", "market.list_fixed", "market.buy", "market.sell_to_order", "market.bid"]:
		_expect(int(tally.get(op, [0, 0])[0]) > 0, "fuzz exercised a successful %s" % op)
	_expect(crashes > 0, "fuzz restarted mid-move at least once")
	b.econ.close()
	var fresh := MarketEngine.new(_rules, EconCatalog.from_data())
	var store := EconStore.new(fresh, b.econ.dir)
	var why := store.replay_file(b.econ.journal_path())
	_expect(why == "" and fresh.state_json() == b.econ.engine.state_json(), "the economy journal replays from empty byte for byte (%s)" % why)
	var chars := CharacterStore.new(WorldFacade.new(), "", 7)
	for line in b.chars.lines:
		why = chars.replay_line(line)
		if why != "":
			break
	_expect(why == "" and chars.state_json() == b.chars.state_json(), "the character journal replays byte for byte (%s)" % why)
	return true

func _fuzz_op(b: VaultBridge, rng: RandomNumberGenerator, who: int) -> Array:
	var e := b.econ.engine
	var acct := e.L.acct(who)
	var mine: Array = acct.vault_items.keys() + acct.vault_pets.keys()
	var listings: Array = e.state().listings.keys()
	var orders: Array = e.state().orders.keys()
	var ch := b.chars.character(who)
	var roll := rng.randi_range(0, 99)
	if roll < 18:
		var node: String = ["rock", "bush", "bush", "bush"][rng.randi_range(0, 3)]
		return ["act.gather", {"node_id": node, "option": 0 if node == "rock" else rng.randi_range(0, 2)}]
	if roll < 32:
		if not ch.d.pets.is_empty() and rng.randf() < 0.15:
			return ["vault.deposit", {"rid": _next(), "pet_uid": ch.d.pets.keys()[0]}]
		return ["vault.deposit", {"rid": _next(), "bag_slot": rng.randi_range(0, 19), "count": rng.randi_range(1, 12)}]
	if roll < 40:
		return ["vault.withdraw", {"rid": _next(), "uid": _any(rng, mine)}]
	if roll < 52:
		return ["market.list_fixed", {"rid": _next(), "asset": {"uid": _any(rng, mine), "count": rng.randi_range(1, 6)}, "unit_price": rng.randi_range(1, 30), "duration_h": [12, 24][rng.randi_range(0, 1)]}]
	if roll < 56:
		return ["market.list_auction", {"rid": _next(), "asset": {"uid": _any(rng, mine)}, "start_bid": rng.randi_range(1, 40), "buyout": [0, rng.randi_range(41, 120)][rng.randi_range(0, 1)], "duration_h": 12}]
	if roll < 68:
		return ["market.buy", {"rid": _next(), "listing_id": _any(rng, listings), "count": rng.randi_range(1, 4)}]
	if roll < 73:
		var lid := _any(rng, listings)
		var price := MarketBook.price_of(e.state().listings[lid]) if e.state().listings.has(lid) else 1
		return ["market.bid", {"rid": _next(), "listing_id": lid, "amount": price + rng.randi_range(0, 10)}]
	if roll < 75:
		return ["market.buyout", {"rid": _next(), "listing_id": _any(rng, listings)}]
	if roll < 79:
		return ["market.cancel", {"rid": _next(), "listing_id": _any(rng, listings)}]
	if roll < 83:
		return ["market.order_create", {"rid": _next(), "def_id": DEFS[rng.randi_range(0, DEFS.size() - 1)], "min_level": 1, "qty": rng.randi_range(1, 10), "unit_price": rng.randi_range(1, 8), "duration_h": 24}]
	if roll < 91:
		var oid := _any(rng, orders)
		var want := str(e.state().orders[oid].def_id) if e.state().orders.has(oid) else ""
		var fits: Array = acct.vault_items.keys().filter(func (u: String) -> bool: return str(acct.vault_items[u].id) == want)
		return ["market.sell_to_order", {"rid": _next(), "order_id": oid, "uid": _any(rng, fits if not fits.is_empty() else acct.vault_items.keys()), "count": rng.randi_range(1, 5)}]
	if roll < 93:
		return ["market.order_cancel", {"rid": _next(), "order_id": _any(rng, orders)}]
	if roll < 95:
		return ["vault.deposit", {"rid": _next(), "slot_dict": {"id": "stone", "count": 50, "uid": "i1.0", "origin": "gather", "seq": 1}}]
	return ["sys.tick", {}]

## One deposit or withdrawal cut between the two stores, then a restart and recover().
func _half_move(b: VaultBridge, rng: RandomNumberGenerator, who: int, ts: int) -> VaultBridge:
	var acct := b.econ.engine.L.acct(who)
	var src: Array = acct.vault_items.keys().filter(func (u: String) -> bool: return b.econ.engine.state().src.has(u))
	if rng.randf() < 0.5 and not src.is_empty():
		var uid: String = src[0]
		b.chars.apply("char.receive", who, {"asset": acct.vault_items[uid]}, ts)
	else:
		b.econ.apply("bridge.begin", who, {"rid": _next()}, ts)
		var slot := _slot(b, who, "stone")
		if slot >= 0 and rng.randf() < 0.7:
			b.chars.apply("act.deposit", who, {"bag_slot": slot, "count": 2}, ts)
	b = _restart(b, ts)
	var bad := _broken(b)
	_expect(bad.is_empty(), "restart mid-move left: %s" % ", ".join(bad))
	return b

func _next() -> String:
	_rid += 1
	return "z%d" % _rid

static func _any(rng: RandomNumberGenerator, pool: Array) -> String:
	if pool.is_empty() or rng.randf() < 0.05:
		return "i1"
	return str(pool[rng.randi_range(0, pool.size() - 1)])
