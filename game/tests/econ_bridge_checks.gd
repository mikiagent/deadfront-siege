extends RefCounted
## No class_name: test code; tests/t_econ.gd loads it by path once the Data autoload exists.
## VaultBridge acceptance: every asset that reaches the economy came out of a server character
## through act.deposit, comes back only through char.receive or char.grant, and nothing is
## duplicated, lost or overdrawn, including when the process dies between the two stores'
## journals or a store faults part-way through a move.

const DIR := "user://econ_bridge_tests"
const T0 := 1760000000
const DEFS := ["stone", "berry", "fibre_stalk", "branch"]
## The books split only stacks, and under W2-INV gathered materials and food are single
## instances; ammunition still stacks, so the split tests use it (the "crate" fixture node).
const SPLIT := "stone_shot"

var failures: Array[String] = []
var _rid := 0
var _world: WorldFacade
var _rules: EconRules

func run() -> Array[String]:
	for test: Callable in [_test_deposit, _test_refusals, _test_client_gate, _test_sales, _test_processed, _test_pets_and_cages, _test_bonded_cap, _test_crash_recovery, _test_strays, _test_recover_any_time, _test_fuzz]:
		if test.call() != true:
			failures.append("%s stopped early (script error)" % test.get_method())
	return failures

func _expect(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond

# --- rig ---------------------------------------------------------------------------------

## A MarketEngine that hits an internal error on chosen ops for one uid, as a bug or an engine
## fault would: the op answers server_error and EconStore reloads the books from disk (the
## reload replays other uids' ops, so only `target` faults).
class FlakyEngine extends MarketEngine:
	var fail := {} ## op -> how many more times it errors
	var target := ""
	var on_fail := Callable()

	func _init(r: EconRules, c: EconCatalog) -> void:
		super(r, c)

	func _dispatch(op: String, me: int, a: EconArgs) -> Dictionary:
		var body: Variant = a.a.get("slot_dict")
		var uid := str(body.get("uid", "")) if body is Dictionary else str(a.a.get("uid", ""))
		if int(fail.get(op, 0)) > 0 and uid == target:
			fail[op] = int(fail[op]) - 1
			if on_fail.is_valid():
				on_fail.call()
			push_error("[econ-bridge] deliberate fault in %s" % op)
			return {}
		return super._dispatch(op, me, a)

## Collects push_warning text, to see that a refused client op was logged.
class Warnings extends Logger:
	var lines: PackedStringArray = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			lines.append("%s %s" % [code, rationale])

## Both stores and the bridge; the economy on disk (it is restarted in the crash tests), the
## characters in memory (their journal lines are kept for the replay check).
func _rig(name: String, budget: int = 0, flaky: bool = false) -> VaultBridge:
	var dir := DIR + "/" + name
	_wipe(dir)
	_rules = EconRules.load_default()
	_rules.market.starting_wallet = 500
	_rules.market.trade_lock_s = 0
	_rules.market.settlers.daily_budget = budget
	var econ := _econ(dir, FlakyEngine.new(_rules, EconCatalog.from_data()) if flaky else null)
	_world = (load("res://tests/srvdom_checks.gd") as GDScript).call("make_world")
	_world.add_node("crate", Vector3(0, 0, -1), [{"item": SPLIT, "tool": "none", "min": 2, "max": 4, "left": 400}], 1, "Rock")
	for n: Dictionary in _world.nodes.values():
		for o: Dictionary in n.options:
			o.left = 1000000
	var b := VaultBridge.new(econ, CharacterStore.new(_world, "", 7))
	for acct in [1, 2, 3]:
		_expect(b.hello(acct, "Trader%d" % acct, T0).ok, "hello %d" % acct)
	return b

func _econ(dir: String, engine: MarketEngine = null) -> EconStore:
	var econ := EconStore.new(engine if engine != null else MarketEngine.new(_rules, EconCatalog.from_data()), dir)
	econ.snapshot_every_ops = 0
	_expect(econ.open() == "", "economy store opens")
	return econ

## The process died: the economy reboots from its disk; the character store (journaled per
## op) keeps what it committed. Returns [bridge, what recover() said].
func _reboot(b: VaultBridge, ts: int) -> Array:
	b.econ.close()
	var again := VaultBridge.new(_econ(b.econ.dir), b.chars)
	return [again, again.recover(ts)]

func _restart(b: VaultBridge, ts: int) -> VaultBridge:
	var got := _reboot(b, ts)
	_expect(got[1] == "", "recover() after a restart: %s" % got[1])
	return got[0]

func _wipe(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var da := DirAccess.open(dir)
	if da:
		for f in da.get_files():
			da.remove(f)

## What the transport relays for a client frame. Before VaultBridge.client() existed, the
## documented relay sent economy ops to apply() and IntentHandlers.CLIENT_OPS to the character
## store; that path stays here so these tests also run (and fail) on the old code.
func _client(b: VaultBridge, op: String, acct: int, args: Dictionary, ts: int = T0) -> Dictionary:
	if b.has_method("client"):
		return b.call("client", op, acct, args, ts)
	if op in VaultBridge.CLIENT_OPS:
		return b.apply(op, acct, args, ts)
	if op in IntentHandlers.CLIENT_OPS:
		return b.chars.apply(op, acct, args, ts)
	return EconArgs.no("unauthorized", "%s is server-only" % op)

## The bridge's stop flag ("" when it serves); "" on builds without one.
static func _stuck(b: VaultBridge) -> String:
	var v: Variant = b.get("broken")
	return v if v is String else ""

func _op(b: VaultBridge, op: String, acct: int, args: Dictionary, ts: int = T0) -> Dictionary:
	if op in VaultBridge.CLIENT_OPS and op not in MarketEngine.READ and not args.has("rid"):
		_rid += 1
		args = args.duplicate()
		args.rid = "b%d" % _rid
	var res := _client(b, op, acct, args, ts)
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

static func _vault(b: VaultBridge, acct: int) -> Dictionary:
	return b.econ.engine.L.acct(acct).vault_items

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

## The first half of a deposit, as VaultBridge runs it, cut before the vault: the mark (with the
## uid act.deposit is about to export) and act.deposit. Returns the exported uid.
func _cut_deposit(b: VaultBridge, who: int, rid: String, count: int, ts: int, item: String = "stone") -> String:
	var slot := _slot(b, who, item)
	var row: Dictionary = b.chars.character(who).d.bag[slot]
	var uid := str(row.uid) if count >= int(row.count) else Provenance.item_uid(int(b.chars.s.seq) + 1, 0)
	b.econ.apply("bridge.begin", who, {"rid": rid, "uid": uid, "op": "deposit"}, ts)
	var out := b.chars.apply("act.deposit", who, {"bag_slot": slot, "count": count}, ts)
	_expect(out.ok and str(out.r.asset.uid) == uid, "a cut deposit exports the uid its mark names (%s vs %s)" % [str(out.get("r", {}).get("asset", {}).get("uid", "")), uid])
	return uid

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
	if _stuck(b) != "":
		bad.append("bridge stopped: %s" % _stuck(b))
	return bad

# --- tests -------------------------------------------------------------------------------

func _test_deposit() -> bool:
	var b := _rig("deposit")
	_gather(b, 1, "crate", 0, SPLIT, 12)
	var slot := _slot(b, 1, SPLIT)
	var row: Dictionary = b.chars.character(1).d.bag[slot].duplicate(true)
	var r := _ok(b, "vault.deposit", 1, {"bag_slot": slot, "rid": "dep-a"})
	_expect(r.uid == row.uid and _units(b, 1).get(SPLIT, 0) == 0 and _vault(b, 1).has(row.uid), "a whole stack moves from the bag to the vault under its own uid")
	var h := _hash(b)
	var again := _op(b, "vault.deposit", 1, {"bag_slot": slot, "rid": "dep-a"})
	var same: bool = again.ok and _hash(b) == h and again.r.uid == r.uid
	_expect(same, "a repeated rid applies nothing in either store and answers the same")
	_gather(b, 1, "crate", 0, SPLIT, 8)
	slot = _slot(b, 1, SPLIT)
	var have: int = _units(b, 1)[SPLIT]
	r = _ok(b, "vault.deposit", 1, {"bag_slot": slot, "count": 3})
	_expect(int(r.item.count) == 3 and _units(b, 1)[SPLIT] == have - 3 and str(r.uid).ends_with(".0") and r.item.origin == "gather", "part of a stack leaves with a new uid and keeps its origin")
	# Malformed arguments are bad_request (contract 2), and change nothing.
	h = _hash(b)
	var codes: PackedStringArray = []
	for args: Dictionary in [{"bag_slot": slot, "count": 2.5}, {"bag_slot": slot, "count": -1}, {"bag_slot": slot, "count": 0}, {"bag_slot": slot, "count": "3"}, {"bag_slot": slot, "count": 1e300}, {"bag_slot": slot, "count": INF}, {"bag_slot": 0.5}, {"bag_slot": -1}, {"bag_slot": 999}, {"pet_uid": ["x"]}, {"pet_uid": 7}]:
		codes.append(str(_op(b, "vault.deposit", 1, args).get("err", "ok")))
	_expect(_hash(b) == h and Array(codes).all(func (c: String) -> bool: return c == "bad_request"), "malformed deposit args answer bad_request: %s" % ",".join(codes))
	var empty := _op(b, "vault.deposit", 1, {"bag_slot": 19})
	_expect(empty.get("err") == "not_found", "an empty slot is still not_found (%s)" % empty.get("err", "ok"))
	print("[econ-bridge] deposit whole=%s part=%s repeat_same_and_unchanged=%s malformed=%s" % [row.uid, r.uid, same, ",".join(codes)])
	return true

func _test_refusals() -> bool:
	var b := _rig("refusals")
	_gather(b, 1, "crate", 0, SPLIT, 8)
	var slot := _slot(b, 1, SPLIT)
	var h := _hash(b)
	var forged := {"id": "raid_helm", "count": 1, "level": 60, "uid": "i1.0", "origin": "craft", "seq": 1}
	var codes: Array = []
	for args: Dictionary in [{"slot_dict": forged}, {"pet_dict": {"species": "tyrannosaurus"}}, {"bag_slot": slot, "item": forged}, {"bag_slot": 19}, {"pet_uid": "p9.0"}, {"bag_slot": "x"}]:
		codes.append(str(_op(b, "vault.deposit", 1, args).get("err", "ok")))
	for op in MarketEngine.BRIDGE + ["bridge.begin", "bridge.end", "bridge.settled"]:
		codes.append(str(b.apply(op, 1, {"slot_dict": forged, "rid": "x"}, T0).get("err", "ok")))
	_expect(_hash(b) == h and not "ok" in codes, "client dicts, empty slots and server-only ops change nothing: %s" % ", ".join(codes))
	_rules.limits.deposit_caps[SPLIT] = 2
	var capped := _op(b, "vault.deposit", 1, {"bag_slot": slot})
	_expect(capped.get("err") == "limit_reached" and _hash(b) == h, "a deposit the vault would refuse never leaves the bag (%s)" % capped.get("err", "ok"))
	_rules.limits.deposit_caps[SPLIT] = 300
	var uid := str(_ok(b, "vault.deposit", 1, {"bag_slot": slot}).uid)
	# A body the character store would not take back (edited in flight) stays in the vault.
	var saved: String = b.chars.s.exported_assets[uid]
	b.chars.s.exported_assets[uid] = saved.replace('"count":', '"count":1')
	h = _hash(b)
	var refused := b.apply("vault.withdraw", 1, {"uid": uid, "rid": "w-bad"}, T0)
	_expect(not refused.ok and _hash(b) == h and _vault(b, 1).has(uid), "a withdrawal char.receive refuses leaves the asset in the vault (%s)" % refused.get("err", "ok"))
	b.chars.s.exported_assets[uid] = saved
	var back := _ok(b, "vault.withdraw", 1, {"uid": uid})
	_expect(int(back.item.count) == int(_units(b, 1)[SPLIT]) and not b.chars.s.exported_assets.has(uid), "the same withdrawal goes through once the body matches")
	var twice := _op(b, "vault.withdraw", 1, {"uid": uid})
	_expect(twice.get("err") == "not_found", "a second withdrawal finds nothing (%s)" % twice.get("err", "ok"))
	print("[econ-bridge] refusals codes=%s cap=%s edited_body=%s twice=%s" % [",".join(codes), capped.get("err", "ok"), refused.get("err", "ok"), twice.get("err", "ok")])
	return true

## Review r3 blocker: a client must not reach act.deposit (or any other server-only op).
## client() is the transport's one relay; it refuses and logs everything server-only.
func _test_client_gate() -> bool:
	var b := _rig("gate")
	_gather(b, 1, "crate", 0, SPLIT, 12)
	_expect("act.deposit" not in IntentHandlers.CLIENT_OPS and "act.deposit" in IntentHandlers.SYSTEM_OPS, "act.deposit is a server-only op of the character store")
	var warn := Warnings.new()
	OS.add_logger(warn)
	var h := _hash(b)
	var codes: PackedStringArray = []
	var slot := _slot(b, 1, SPLIT)
	var body: Dictionary = b.chars.character(1).d.bag[slot].duplicate(true)
	for row: Array in [["act.deposit", {"bag_slot": slot}], ["char.receive", {"asset": body}], ["char.grant", {"asset": body}], ["char.wallet", {"wallet": 999999}], ["char.settled", {"uid": "i1.0"}], ["bridge.begin", {"rid": "x", "uid": "i1.0", "op": "deposit"}], ["bridge.end", {}], ["vault.deposit_item", {"slot_dict": body, "rid": "x"}], ["objective.claim", {"index": 0, "rid": "x"}], ["account.ensure", {"name": "Again"}], ["sys.tick", {}]]:
		codes.append(str(_client(b, row[0], 1, row[1]).get("err", "ok")))
	OS.remove_logger(warn)
	var logged := Array(warn.lines).filter(func (l: String) -> bool: return l.contains("act.deposit")).size()
	_expect(_hash(b) == h and Array(codes).all(func (c: String) -> bool: return c == "unauthorized"), "a client's act.deposit, char.*, bridge.*, vault dicts and objective.claim are refused: %s" % ",".join(codes))
	_expect(logged >= 1, "a refused client act.deposit is logged (%d warning lines)" % logged)
	var dep := _op(b, "vault.deposit", 1, {"bag_slot": slot, "count": 2})
	var gathered := _client(b, "act.gather", 1, {"node_id": "rock", "option": 0})
	_expect(dep.ok and gathered.ok, "vault.deposit and the act.* intents still relay (%s, %s)" % [dep.get("err", "ok"), gathered.get("err", "ok")])
	print("[econ-bridge] gate refused=%s logged=%d deposit_via_vault=%s gather=%s" % [",".join(codes), logged, dep.ok, gathered.ok])
	return true

## Review r3 major: every asset the books split can leave the vault through char.grant: a
## partial buy, a part listing, a partial order fill and the seller's remainder; a withdrawal
## honours `count`. Each unit reaches exactly one character.
func _test_sales() -> bool:
	var b := _rig("sales")
	_gather(b, 1, "crate", 0, SPLIT, 10)
	var stack: Dictionary = b.chars.character(1).d.bag[_slot(b, 1, SPLIT)]
	var n := int(stack.count)
	var uid := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT)}).uid)
	var lid := str(_ok(b, "market.list_fixed", 1, {"asset": {"uid": uid}, "unit_price": 7, "duration_h": 24}).listing.id)
	var bought := _ok(b, "market.buy", 2, {"listing_id": lid, "count": n})
	var got := _ok(b, "vault.withdraw", 2, {"uid": uid})
	_expect(_units(b, 2).get(SPLIT, 0) == n and int(got.get("item", {}).get("count", 0)) == n, "the buyer's character holds the %d units it bought" % n)
	_expect(int(b.chars.character(1).d.wallet) == int(b.econ.engine.L.acct(1).wallet) and int(b.chars.character(2).d.wallet) == 500 - 7 * n, "both wallets are mirrored to the characters")
	var broke := _op(b, "market.buy", 3, {"listing_id": lid, "count": 1})
	_expect(not broke.ok, "a sold listing cannot be bought again")
	# A partial buy splits the export: the buyer withdraws its part, the seller its remainder.
	_gather(b, 1, "crate", 0, SPLIT, 9)
	var whole: int = _units(b, 1)[SPLIT]
	var src := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT)}).uid)
	lid = str(_ok(b, "market.list_fixed", 1, {"asset": {"uid": src}, "unit_price": 5, "duration_h": 24}).listing.id)
	var part := _ok(b, "market.buy", 3, {"listing_id": lid, "count": 2})
	_expect(not b.chars.s.exported_assets.has(src) and b.econ.engine.state().retired.is_empty(), "a split export is settled in the character store")
	var three_before: int = _units(b, 3).get(SPLIT, 0)
	var mine := _op(b, "vault.withdraw", 3, {"uid": str(part.get("asset", {}).get("uid", ""))})
	_expect(mine.ok and _units(b, 3).get(SPLIT, 0) == three_before + 2 and not _vault(b, 3).has(str(part.get("asset", {}).get("uid", ""))), "a partial buy reaches the buyer's character (%s)" % mine.get("err", "ok"))
	_ok(b, "market.cancel", 1, {"listing_id": lid})
	var rest := _op(b, "vault.withdraw", 1, {"uid": src})
	_expect(rest.ok and _units(b, 1).get(SPLIT, 0) == whole - 2 and not _vault(b, 1).has(src), "the seller's remainder comes back to the bag (%s): %d of %d" % [rest.get("err", "ok"), _units(b, 1).get(SPLIT, 0), whole - 2])
	var poor := _op(b, "market.buy", 3, {"listing_id": lid, "count": 1})
	_expect(not poor.ok, "a cancelled listing cannot be bought")
	# A part listing: the unlisted remainder stays withdrawable while the part is on sale.
	_gather(b, 1, "crate", 0, SPLIT, 12)
	var have: int = _units(b, 1)[SPLIT]
	var lot := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT)}).uid)
	_ok(b, "market.list_fixed", 1, {"asset": {"uid": lot, "count": 3}, "unit_price": 4, "duration_h": 24})
	var left := _op(b, "vault.withdraw", 1, {"uid": lot})
	_expect(left.ok and _units(b, 1)[SPLIT] == have - 3, "a part listing's remainder comes back to the bag (%s)" % left.get("err", "ok"))
	# A partial order fill: the buyer withdraws exactly the units it paid for.
	_gather(b, 1, "crate", 0, SPLIT, 10)
	var oid := str(_ok(b, "market.order_create", 2, {"def_id": SPLIT, "qty": 3, "unit_price": 6, "duration_h": 24}).order.id)
	var sell := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT)}).uid)
	_ok(b, "market.sell_to_order", 1, {"order_id": oid, "uid": sell, "count": 3})
	var two_before: int = _units(b, 2).get(SPLIT, 0)
	var filled: Array = _vault(b, 2).keys().filter(func (u: String) -> bool: return str(_vault(b, 2)[u].id) == SPLIT)
	var fill := _op(b, "vault.withdraw", 2, {"uid": str(filled[0]) if not filled.is_empty() else "i1"})
	_expect(fill.ok and _units(b, 2).get(SPLIT, 0) == two_before + 3, "units bought through a buy order reach the buyer's character (%s)" % fill.get("err", "ok"))
	# count is honoured: one unit of an exported stack leaves, the rest stays in the vault.
	var rest_n := int(_vault(b, 1)[sell].count) if _vault(b, 1).has(sell) else 0
	var one := _op(b, "vault.withdraw", 1, {"uid": sell, "count": 1})
	_expect(one.ok and int(one.get("r", {}).get("item", {}).get("count", 0)) == 1 and _vault(b, 1).has(sell) and int(_vault(b, 1)[sell].count) == rest_n - 1, "vault.withdraw {uid, count: 1} takes one unit, not the stack (left %d of %d)" % [int(_vault(b, 1).get(sell, {}).get("count", 0)), rest_n])
	var over := _op(b, "vault.withdraw", 1, {"uid": sell, "count": 999})
	_expect(over.get("err") == "insufficient_items", "more than the stack is insufficient_items (%s)" % over.get("err", "ok"))
	var units := 0
	for acct in [1, 2, 3]:
		units += int(_units(b, acct).get(SPLIT, 0))
		for u: String in _vault(b, acct):
			units += int(_vault(b, acct)[u].count) if str(_vault(b, acct)[u].id) == SPLIT else 0
	for l: Dictionary in b.econ.engine.state().listings.values():
		units += int(l.left) if str(l.asset.id) == SPLIT else 0
	_expect(units == int(b.chars.s.minted.get(SPLIT, 0)) - int(b.chars.s.consumed.get(SPLIT, 0)), "every unit gathered is in exactly one bag, vault or listing (%d of %d)" % [units, int(b.chars.s.minted.get(SPLIT, 0))])
	print("[econ-bridge] sale whole=%d units paid=%d partial_buy=%s remainder=%s part_listing=%s order_fill=%s count1=%s" % [n, int(bought.paid), mine.get("err", "ok"), rest.get("err", "ok"), left.get("err", "ok"), fill.get("err", "ok"), one.get("err", "ok")])
	return true

## PRD:131 and spec 06 (vision fix): a processed instance, dried meat with its processing
## history, deposits, lists, sells and withdraws with every per-instance field intact (uid,
## origin, seq, level, process_count, attributes.processed, flags, creator, created_at).
func _test_processed() -> bool:
	var b := _rig("processed")
	_world.stations["drying_rack"] = [[0, 0, 1.8]]
	var looted := b.chars.apply("act.loot", 1, {"corpse_id": "carcass", "slot": 0, "count": 1}, T0)
	var dried := b.chars.apply("act.craft", 1, {"recipe_id": "dry_meat"}, T0)
	var slot := _slot(b, 1, "dried_meat")
	if not _expect(looted.ok and dried.ok and slot >= 0, "raw meat looted and dried at a drying rack: %s, %s" % [str(looted), str(dried)]):
		return true
	var row: Dictionary = b.chars.character(1).d.bag[slot]
	var crafted := "history=craft" if (row.attributes as Dictionary).has("processed") else "history=test"
	# Until W2-PROCESS and W2-INV merge, the server's craft writes no history and no instance
	# fields; add what those packages write, so the same full body is checked before and after.
	if not (row.attributes as Dictionary).has("processed"):
		row.attributes["processed"] = ["dry"]
	if not row.has("creator"):
		row["creator"] = ""
		row["created_at"] = 0
	var body := CharacterStore.canon(CharacterStore.wire(row))
	var dep := _op(b, "vault.deposit", 1, {"bag_slot": slot})
	if not _expect(dep.ok, "a dried instance deposits: %s" % str(dep)):
		return true
	var uid := str(dep.r.uid)
	var listing: Dictionary = _ok(b, "market.list_fixed", 1, {"asset": {"uid": uid}, "unit_price": 3, "duration_h": 24}).get("listing", {})
	_expect(CharacterStore.canon(CharacterStore.wire(listing.get("asset", {}))) == body, "the listing shows the real instance, history and all: %s" % str(listing.get("asset", {})))
	_ok(b, "market.buy", 2, {"listing_id": str(listing.get("id", "")), "count": int(row.count)})
	_expect(_slot(b, 2, "dried_meat") < 0, "the buyer starts without dried meat")
	_ok(b, "vault.withdraw", 2, {"uid": uid})
	var got: Dictionary = b.chars.character(2).d.bag[_slot(b, 2, "dried_meat")] if _slot(b, 2, "dried_meat") >= 0 else {}
	_expect(CharacterStore.canon(CharacterStore.wire(got)) == body, "the buyer's character holds the same instance, every field intact: %s vs %s" % [CharacterStore.canon(got), body])
	print("[econ-bridge] processed dried_meat %s uid=%s history=%s process_count=%d level=%d origin=%s fields=%s intact=%s" % [crafted, uid, str(got.get("attributes", {}).get("processed")), int(got.get("process_count", -1)), int(got.get("level", -1)), got.get("origin"), ",".join(PackedStringArray(got.keys())), CharacterStore.canon(CharacterStore.wire(got)) == body])
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
	var got: Dictionary = b.chars.character(2).d.pets.get(pid, {}).duplicate(true)
	var owner := str(got.get("owner", ""))
	var expect := CharacterStore.wire(pet) as Dictionary
	got.erase("owner")
	expect.erase("owner")
	_expect(CharacterStore.canon(got) == CharacterStore.canon(expect), "the buyer's character holds the same bonded pet: uid, origin, lineage, stats (no re-taming)")
	_expect(owner == "2" and str(pet.get("owner", "")) == "1", "a bought pet answers to its buyer (owner %s, was %s)" % [owner, pet.get("owner", "")])
	# The buyer can sell it on: the new owner is in the body its next deposit exports.
	_ok(b, "vault.deposit", 2, {"pet_uid": pid})
	_expect(str(b.econ.engine.L.acct(2).vault_pets.get(pid, {}).get("owner", "")) == "2", "a re-deposit exports the pet under its new owner")
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
	print("[econ-bridge] pet uid=%s origin=%s to_buyer=%s owner=%s cage=%s species=%s outbid_refunded=%s" % [pid, pet.origin, b.chars.character(2).d.pets.has(pid) or b.econ.engine.L.acct(2).vault_pets.has(pid), owner, cid, row.attributes.species, int(b.chars.character(3).d.wallet) == 500])
	return true

## Pack 09 (review r3 m2): a bought pet is a bond forming, so its withdrawal is refused while
## the buyer's roster is at Data.bonded_cap() and the pet stays in the vault. Sync step: the cap
## is unlimited until W2-SKILLS merges its single cap function (3 on a server without skill nodes).
func _test_bonded_cap() -> bool:
	var cap := Data.bonded_cap()
	if cap > 100:
		print("[econ-bridge] bonded cap: Data.bonded_cap() is %d on this base; the full-roster case runs once W2-SKILLS merges" % cap)
		return true
	var b := _rig("bonded")
	var pid := _tame(b, 1, "compy_sold")
	_ok(b, "vault.deposit", 1, {"pet_uid": pid})
	var lid := str(_ok(b, "market.list_fixed", 1, {"asset": {"uid": pid}, "unit_price": 40, "duration_h": 24}).listing.id)
	_ok(b, "market.buy", 2, {"listing_id": lid, "count": 1})
	for i in cap:
		_tame(b, 2, "compy_own_%d" % i)
	var roster := (b.chars.character(2).d.pets as Dictionary).size()
	var refused := _op(b, "vault.withdraw", 2, {"uid": pid})
	_expect(refused.get("err") == "limit_reached" and b.econ.engine.L.acct(2).vault_pets.has(pid) and (b.chars.character(2).d.pets as Dictionary).size() == roster, "a full roster (%d of %d) refuses a bought pet, which stays in the vault (%s)" % [roster, cap, refused.get("err", "ok")])
	print("[econ-bridge] bonded cap=%d roster=%d withdraw=%s kept_in_vault=%s" % [cap, roster, refused.get("err", "ok"), b.econ.engine.L.acct(2).vault_pets.has(pid)])
	return true

func _test_crash_recovery() -> bool:
	var b := _rig("crash")
	_gather(b, 1, "crate", 0, SPLIT, 12)
	# 1. Died after act.deposit, before the vault: boot puts the asset in the vault.
	var uid := _cut_deposit(b, 1, "crash-1", 4, T0, SPLIT)
	b = _restart(b, T0 + 1)
	_expect(_vault(b, 1).has(uid) and _broken(b).is_empty(), "a deposit cut after act.deposit lands in the vault at boot: %s" % ", ".join(_broken(b)))
	var h := _hash(b)
	var repeat := _op(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT), "rid": "crash-1"})
	_expect(repeat.ok and _hash(b) == h, "the client's retry of that rid applies nothing")
	# 2. Died after bridge.begin only: nothing moved, the mark is dropped.
	b.econ.apply("bridge.begin", 1, {"rid": "crash-2", "uid": Provenance.item_uid(int(b.chars.s.seq) + 1, 0), "op": "deposit"}, T0)
	var conflict := b.econ.apply("bridge.begin", 2, {"rid": "crash-2b", "uid": "i1.0", "op": "deposit"}, T0)
	_expect(conflict.get("err") == "conflict" and str(b.econ.engine.state().inflight.get("rid", "")) == "crash-2", "bridge.begin refuses while another move is marked (%s)" % conflict.get("err", "ok"))
	b = _restart(b, T0 + 2)
	_expect(_hash(b) != "" and _broken(b).is_empty() and _vault(b, 1).size() == 1, "a deposit cut before act.deposit is dropped at boot")
	# 3. Died after char.receive (which runs first), before the vault let go: boot finishes it.
	b.chars.apply("char.receive", 1, {"asset": _vault(b, 1)[uid]}, T0)
	b = _restart(b, T0 + 3)
	_expect(not _vault(b, 1).has(uid) and _broken(b).is_empty(), "a withdrawal cut after char.receive leaves the vault at boot (no duplicate): %s" % ", ".join(_broken(b)))
	# 4. Died after a partial buy and a wallet move, before settle and mirror.
	var src := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT)}).uid)
	var lid := str(_ok(b, "market.list_fixed", 1, {"asset": {"uid": src}, "unit_price": 3, "duration_h": 24}).listing.id)
	b.econ.apply("market.buy", 2, {"listing_id": lid, "count": 1, "rid": "crash-4"}, T0)
	b = _restart(b, T0 + 4)
	_expect(_broken(b).is_empty() and not b.chars.s.exported_assets.has(src), "boot settles the split export and mirrors the wallets: %s" % ", ".join(_broken(b)))
	# 5. A grant cut after the vault let go, before char.grant: boot grants the units once.
	var bought: Array = _vault(b, 2).keys()
	var before: int = _units(b, 2).get(SPLIT, 0)
	b.econ.apply("bridge.begin", 2, {"rid": "crash-5", "uid": bought[0], "op": "grant"}, T0)
	b.econ.apply("vault.withdraw_item", 2, {"rid": "crash-5", "uid": bought[0], "count": 1}, T0)
	b = _restart(b, T0 + 5)
	_expect(_units(b, 2).get(SPLIT, 0) == before + 1 and _broken(b).is_empty(), "a grant cut after the vault let go reaches the character at boot: %d -> %d, %s" % [before, _units(b, 2).get(SPLIT, 0), ", ".join(_broken(b))])
	# 6. A grant cut after char.grant, before bridge.end: boot does not grant twice.
	var part6 := _ok(b, "market.buy", 3, {"listing_id": lid, "count": 2})
	var puid := str(part6.get("asset", {}).get("uid", ""))
	before = _units(b, 3).get(SPLIT, 0)
	b.econ.apply("bridge.begin", 3, {"rid": "crash-6", "uid": puid, "op": "grant"}, T0)
	var w6 := b.econ.apply("vault.withdraw_item", 3, {"rid": "crash-6", "uid": puid}, T0)
	var seq6 := int(b.econ.engine.L.acct(3).rid_cache.get("crash-6", [0, 0])[1])
	b.chars.apply("char.grant", 3, {"asset": w6.get("r", {}).get("item", {}), "rid": "g%d" % seq6}, T0)
	b = _restart(b, T0 + 6)
	_expect(_units(b, 3).get(SPLIT, 0) == before + 2 and _broken(b).is_empty(), "a grant cut before bridge.end is not granted twice at boot: %d -> %d" % [before, _units(b, 3).get(SPLIT, 0)])
	print("[econ-bridge] crash deposit_after_export=landed deposit_before_export=dropped begin_while_marked=%s withdraw_after_receive=finished split_before_settle=settled grant_after_vault=granted grant_before_end=once consistent=%s" % [conflict.get("err", "ok"), _broken(b).is_empty()])
	return true

## An export that left a character outside the bridge (a server bug; clients cannot since
## act.deposit is server-only) is reported, never moved into the vault of whoever's deposit
## happens to be marked; the marked deposit still finishes for its own account.
func _test_strays() -> bool:
	var b := _rig("strays")
	_gather(b, 1, "crate", 0, SPLIT, 12)
	_gather(b, 2, "crate", 0, SPLIT, 12)
	var stray: Dictionary = b.chars.apply("act.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT), "count": 3}, T0).get("r", {}).get("asset", {})
	var got := _reboot(b, T0 + 1)
	b = got[0]
	_expect(str(got[1]).contains(str(stray.get("uid", "?"))), "recover() reports an export in no vault even with no move marked: '%s'" % got[1])
	# (a) Account 2's deposit cut after bridge.begin, before act.deposit.
	b.econ.apply("bridge.begin", 2, {"rid": "cut-a", "uid": Provenance.item_uid(int(b.chars.s.seq) + 1, 0), "op": "deposit"}, T0)
	got = _reboot(b, T0 + 2)
	b = got[0]
	_expect(not _vault(b, 2).has(str(stray.get("uid", "?"))) and str(got[1]).contains(str(stray.get("uid", "?"))), "a stray export never lands in the vault of a marked deposit (account 2 holds %s)" % str(_vault(b, 2).keys()))
	# (b) Account 2's deposit cut after act.deposit: it lands in account 2's vault, the stray stays reported.
	var mine := _cut_deposit(b, 2, "cut-b", 2, T0, SPLIT)
	got = _reboot(b, T0 + 3)
	b = got[0]
	_expect(_vault(b, 2).has(mine) and not _vault(b, 2).has(str(stray.get("uid", "?"))) and str(got[1]).contains(str(stray.get("uid", "?"))), "the marked deposit lands in its own account's vault, the stray stays out (%s)" % got[1])
	# A person puts the stray back; the bridge serves again.
	b.chars.apply("char.receive", 1, {"asset": stray}, T0)
	_expect(b.recover(T0 + 4) == "" and _broken(b).is_empty(), "once the stray is home the books balance: %s" % ", ".join(_broken(b)))
	print("[econ-bridge] strays reported=%s kept_out_of_other_vault=%s marked_deposit_landed=%s" % [str(got[1]) != "", not _vault(b, 2).has(str(stray.get("uid", "?"))), _vault(b, 2).has(mine)])
	return true

## Review r3 major: a move that cannot finish is finished at once, not at the next boot, and
## while it cannot be the bridge serves nothing, so a copy in two places is never traded.
func _test_recover_any_time() -> bool:
	var b := _rig("anytime", 0, true)
	var flaky := b.econ.engine as FlakyEngine
	_gather(b, 1, "crate", 0, SPLIT, 12)
	print("[econ-bridge] recover-any-time: the next ERROR lines (deliberate fault in ...) are deliberate")
	# (1) The vault faults on letting go after char.receive: it is retried in the same request.
	var uid := str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT), "count": 5}).uid)
	flaky.target = uid
	flaky.fail["vault.withdraw_item"] = 1
	var once := b.apply("vault.withdraw", 1, {"uid": uid, "rid": "w-1"}, T0)
	_expect(not _vault(b, 1).has(uid) and _broken(b).is_empty(), "a vault fault after char.receive is finished in the same request (%s): %s" % [once.get("err", "ok"), ", ".join(_broken(b))])
	# (2) It keeps faulting: the bridge refuses every op, so the vault copy cannot be listed.
	uid = str(_ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT), "count": 3}).uid)
	flaky.target = uid
	flaky.fail["vault.withdraw_item"] = 99
	b.apply("vault.withdraw", 1, {"uid": uid, "rid": "w-2"}, T0)
	var listed := b.apply("market.list_fixed", 1, {"asset": {"uid": uid}, "unit_price": 5, "duration_h": 24, "rid": "l-2"}, T0)
	_expect(not listed.ok and _stuck(b) != "", "while the character and the vault both hold %s nothing can list it (%s)" % [uid, listed.get("err", "ok")])
	flaky.fail["vault.withdraw_item"] = 0
	var heal := b.apply("wallet.get", 1, {}, T0)
	_expect(heal.ok and not _vault(b, 1).has(uid) and _broken(b).is_empty(), "the next op finishes the withdrawal and serves: %s" % ", ".join(_broken(b)))
	# (3) The vault and char.receive both refuse a deposit: the mark stays and the next op lands it.
	var slot := _slot(b, 1, SPLIT)
	flaky.target = Provenance.item_uid(int(b.chars.s.seq) + 1, 0) # the part act.deposit will export
	flaky.fail["vault.deposit_item"] = 1
	flaky.on_fail = func () -> void: b.chars.broken = "deliberate"
	var both := b.apply("vault.deposit", 1, {"bag_slot": slot, "count": 1, "rid": "d-3"}, T0)
	b.chars.broken = ""
	flaky.on_fail = Callable()
	var next := _ok(b, "vault.deposit", 1, {"bag_slot": _slot(b, 1, SPLIT), "count": 1})
	var stranded: Array = b.chars.s.exported_assets.keys().filter(func (u: String) -> bool: return not b.econ.engine.state().src.has(u))
	_expect(not both.ok and stranded.is_empty() and _vault(b, 1).has(str(next.get("uid", ""))) and _broken(b).is_empty(), "an asset both stores refused is in the vault before the next deposit runs: stranded %s, %s" % [str(stranded), ", ".join(_broken(b))])
	print("[econ-bridge] anytime fault_after_receive=%s stuck_listing=%s healed=%s double_refusal_then=%s" % [once.get("err", "ok"), listed.get("err", "ok"), heal.ok, "landed" if stranded.is_empty() else "stranded"])
	return true

## Seeded random traffic through the client relay (and some cut-in-half moves with a restart),
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
	var n := 3600
	for i in n:
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
		var res: Dictionary
		if op == "sys.tick" or op == "objective.claim":
			res = b.apply(op, 0 if op == "sys.tick" else who, args, ts) # the server's own ops
		else:
			res = _client(b, op, who, args, ts)
		var bad := _broken(b)
		if res.get("err") == "server_error":
			bad.append("server_error %s" % res.get("msg", ""))
		if not bad.is_empty():
			_expect(false, "fuzz op %d %s %s broke: %s" % [i, op, str(args), ", ".join(bad)])
			return true
		if (not res.ok or dup) and _hash(b) != before and op != "act.gather":
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
	var coins := int(b.econ.engine.state().initial_grants) + int(b.econ.engine.state().faucet.objectives) + int(b.econ.engine.state().faucet.settlers)
	print("[econ-bridge] fuzz %d ops, %d restarts mid-move, invariants of both stores after every op (coins issued %d, sink %d): %s" % [n, crashes, coins, int(b.econ.engine.state().fee_sink), ", ".join(parts)])
	for op in ["vault.deposit", "vault.withdraw", "market.list_fixed", "market.buy", "market.sell_to_order", "market.bid", "objective.claim"]:
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
		var w := {"rid": _next(), "uid": _any(rng, mine)}
		if rng.randf() < 0.3:
			w.count = rng.randi_range(1, 4)
		return ["vault.withdraw", w]
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
	if roll < 90:
		var oid := _any(rng, orders)
		var want := str(e.state().orders[oid].def_id) if e.state().orders.has(oid) else ""
		var fits: Array = acct.vault_items.keys().filter(func (u: String) -> bool: return str(acct.vault_items[u].id) == want)
		return ["market.sell_to_order", {"rid": _next(), "order_id": oid, "uid": _any(rng, fits if not fits.is_empty() else acct.vault_items.keys()), "count": rng.randi_range(1, 5)}]
	if roll < 92:
		return ["market.order_cancel", {"rid": _next(), "order_id": _any(rng, orders)}]
	if roll < 93:
		return ["objective.claim", {"index": rng.randi_range(0, 30)}]
	if roll < 95:
		# Hostile frames: a client dict and server-only ops through the relay.
		return [["vault.deposit", "act.deposit", "char.grant", "bridge.begin"][rng.randi_range(0, 3)], {"rid": _next(), "bag_slot": 0, "slot_dict": {"id": "stone", "count": 50, "uid": "i1.0", "origin": "gather", "seq": 1}, "asset": {"id": "stone", "count": 50}}]
	return ["sys.tick", {}]

## One deposit, withdrawal or grant cut between the two stores, then a restart and recover().
func _half_move(b: VaultBridge, rng: RandomNumberGenerator, who: int, ts: int) -> VaultBridge:
	var acct := b.econ.engine.L.acct(who)
	var src: Array = acct.vault_items.keys().filter(func (u: String) -> bool: return b.econ.engine.state().src.has(u))
	var made: Array = acct.vault_items.keys().filter(func (u: String) -> bool: return not b.econ.engine.state().src.has(u))
	var roll := rng.randf()
	if roll < 0.35 and not src.is_empty():
		b.chars.apply("char.receive", who, {"asset": acct.vault_items[src[0]]}, ts)
	elif roll < 0.6 and not made.is_empty():
		var rid := _next()
		b.econ.apply("bridge.begin", who, {"rid": rid, "uid": made[0], "op": "grant"}, ts)
		if rng.randf() < 0.7:
			b.econ.apply("vault.withdraw_item", who, {"rid": rid, "uid": made[0], "count": 1}, ts)
	elif _slot(b, who, "stone") >= 0 and rng.randf() < 0.7:
		_cut_deposit(b, who, _next(), 2, ts)
	else:
		b.econ.apply("bridge.begin", who, {"rid": _next(), "uid": Provenance.item_uid(int(b.chars.s.seq) + 1, 0), "op": "deposit"}, ts)
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
