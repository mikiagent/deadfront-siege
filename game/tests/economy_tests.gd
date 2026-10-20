extends RefCounted
## Economy engine tests (docs/orchestration/mmo/contracts.md 4-6): every op and error code,
## market edge cases, a seeded 3000-op fuzz with the 6.7 invariants after every op, journal
## replay, torn lines, snapshots, and a 10,000-listing search timing.
## Loaded by run_all.gd after the Data autoload exists (the catalog reads it).

const T0 := 1760000000
const DIR := "user://econ_tests"
const FUZZ_DEFS := ["stone", "wood_log", "fibre_stalk", "raw_meat", "copper_ore", "stone_knife"]
const FUZZ_PETS := ["velociraptor", "triceratops", "compsognathus"]
const HOSTILE := ["yes", {"x": 1}, [1, 2], null] ## wrong-typed values a client could send for any field

var failures: Array[String] = []
var cat: EconCatalog
var _rid := 0
var _seq := 0 ## character-store seq for the provenance stamps test assets carry

func run() -> Array[String]:
	cat = EconCatalog.from_data()
	# Each test returns true on its last line; a script error aborts it and returns null.
	for test: Callable in [_test_accounts_wallet_objectives, _test_item_deposits, _test_attribute_sources, _test_pet_deposits, _test_withdraw, _test_fixed_listings, _test_auctions, _test_anti_snipe_and_settlement, _test_orders, _test_expiry, _test_search, _test_history_and_reference, _test_reference_poisoning, _test_settlers, _test_idempotency, _test_rid_bodies, _test_vault_caps, _test_clock, _test_market_views, _test_journal_replay, _test_torn_newline, _test_snapshots, _test_snapshot_failures, _test_fault_reload, _test_fuzz, _test_search_perf]:
		if test.call() != true:
			failures.append("econ: %s stopped early (script error)" % test.get_method())
	return failures

func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("econ: " + msg)

## Test rules: rich wallets and Settlers off unless a test turns them on.
func _rules(rich: bool = true) -> EconRules:
	var r := EconRules.load_default()
	if rich:
		r.market.starting_wallet = 100000
	r.market.settlers.daily_budget = 0
	return r

func _engine(r: EconRules = null, accounts: int = 4) -> MarketEngine:
	var e := MarketEngine.new(r if r != null else _rules(), cat)
	for id in range(1, accounts + 1):
		e.apply("account.ensure", id, {"name": "Player %d" % id}, T0)
	return e

## Applies an op, adding a fresh rid to write ops, and asserts the 6.7 invariants plus
## "a failed or read-only op changes nothing" after every call.
func _op(e: MarketEngine, op: String, who: int, args: Dictionary = {}, ts: int = T0) -> Dictionary:
	if (op in MarketEngine.WRITE or op in MarketEngine.BRIDGE) and not args.has("rid"):
		_rid += 1
		args = args.duplicate()
		args.rid = "r%d" % _rid
	var before := e.state_json()
	var res := e.apply(op, who, args, ts)
	var bad := EconInvariants.check(e.state())
	_expect(bad.is_empty(), "%s broke invariants: %s" % [op, str(bad)])
	if not res.ok or op in MarketEngine.READ:
		_expect(e.state_json() == before, "%s changed state although it %s" % [op, "failed" if not res.ok else "is read-only"])
	return res

func _ok(e: MarketEngine, op: String, who: int, args: Dictionary = {}, ts: int = T0) -> Dictionary:
	var res := _op(e, op, who, args, ts)
	_expect(res.ok, "%s should succeed: %s" % [op, str(res)])
	return res.get("r", {})

func _err(e: MarketEngine, op: String, who: int, args: Dictionary, code: String, ts: int = T0, why: String = "") -> void:
	var res := _op(e, op, who, args, ts)
	_expect(not res.ok and res.get("err") == code, "%s (%s) should fail with %s, got %s" % [op, why, code, str(res)])

## First path where two JSON-shaped values differ, for readable replay failures.
static func _diff(x: Variant, y: Variant, path: String = "") -> String:
	if typeof(x) != typeof(y):
		return "%s: %s vs %s" % [path, type_string(typeof(x)), type_string(typeof(y))]
	if x is Dictionary:
		for k in x:
			if not y.has(k):
				return "%s.%s missing on the right" % [path, k]
			var d := _diff(x[k], y[k], "%s.%s" % [path, k])
			if d != "":
				return d
		for k in y:
			if not x.has(k):
				return "%s.%s missing on the left" % [path, k]
		return ""
	if x is Array:
		if x.size() != y.size():
			return "%s: %d vs %d items" % [path, x.size(), y.size()]
		for i in x.size():
			var d := _diff(x[i], y[i], "%s[%d]" % [path, i])
			if d != "":
				return d
		return ""
	return "" if x == y else "%s: %s vs %s" % [path, var_to_str(x), var_to_str(y)]

func _same(a: MarketEngine, b: MarketEngine) -> String:
	if a.state_json() == b.state_json():
		return ""
	var d := _diff(a.state(), b.state())
	return d if d != "" else "same values, different JSON text"

func _wallet(e: MarketEngine, id: int) -> int:
	return int(e.L.acct(id).wallet)

static func _with(d: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := d.duplicate(true)
	out[key] = value
	return out

## A stack as act.deposit exports it: the gameplay fields plus a fresh server provenance stamp.
func _stack(def_id: String, count: int, level: int = 1) -> Dictionary:
	return _stamp(ItemStack.make(StringName(def_id), count, {}, level).to_dict(), "i", "gather")

func _stamp(d: Dictionary, prefix: String, origin: String) -> Dictionary:
	_seq += 1
	return Provenance.stamp(d, "%s%d.0" % [prefix, _seq], origin, _seq)

func _deposit(e: MarketEngine, who: int, def_id: String, count: int, level: int = 1, ts: int = T0) -> String:
	return str(_ok(e, "vault.deposit_item", who, {"slot_dict": _stack(def_id, count, level)}, ts).get("uid", ""))

func _pet(species: String, level: int = 1, seed: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rec := PetRecord.from_def(Data.creature(StringName(species)), &"B", &"", CreatureGenetics.roll(rng))
	while rec.level < level:
		rec.add_xp(PetRecord.xp_to_next(rec.level) / rec.xp_rate + 0.01)
	return _stamp(rec.to_dict(), "p", "tame")

func _list(e: MarketEngine, who: int, uid: String, price: int, count: int = -1, ts: int = T0, hours: int = 24) -> String:
	var asset := {"uid": uid}
	if count > 0:
		asset.count = count
	return str(_ok(e, "market.list_fixed", who, {"asset": asset, "unit_price": price, "duration_h": hours}, ts).get("listing", {}).get("id", ""))

func _auction(e: MarketEngine, who: int, uid: String, start: int, buyout: int = 0, hours: int = 24, ts: int = T0) -> String:
	return str(_ok(e, "market.list_auction", who, {"asset": {"uid": uid}, "start_bid": start, "buyout": buyout, "duration_h": hours}, ts).get("listing", {}).get("id", ""))

func _events(e: MarketEngine, who: int, ts: int = T0) -> Array:
	var evs: Array = []
	for ev in _ok(e, "inbox.take", who, {}, ts).get("events", []):
		evs.append(str(ev.ev))
	return evs

func _test_accounts_wallet_objectives() -> bool:
	var e := MarketEngine.new(_rules(false), cat)
	var r := _ok(e, "account.ensure", 1, {"name": "Alice"})
	_expect(int(r.wallet) == 20, "starting wallet is 20")
	var seq := e.seq()
	_ok(e, "account.ensure", 1, {"name": "Alice"})
	_expect(e.seq() == seq, "account.ensure on an existing account changes nothing")
	_err(e, "account.ensure", 2, {"name": "x"}, "bad_request", T0, "short name")
	_err(e, "account.ensure", 2, {"name": "bad!name"}, "bad_request", T0, "bad characters")
	_err(e, "account.ensure", 0, {}, "bad_request", T0, "account 0 is Settlers")
	_err(e, "wallet.get", 9, {}, "unauthorized", T0, "unknown account")
	_err(e, "wallet.get", 0, {}, "unauthorized", T0, "clients cannot act as Settlers")
	_err(e, "sys.tick", 1, {}, "unauthorized", T0, "tick is server-only")
	_err(e, "market.teleport", 1, {}, "bad_request", T0, "unknown op")
	var no_rid := e.apply("wallet.spend", 1, {"reason": "travel", "amount": 5}, T0)
	_expect(not no_rid.ok and no_rid.err == "bad_request", "write ops need a rid")
	r = _ok(e, "wallet.spend", 1, {"reason": "travel", "amount": 5})
	_expect(int(r.wallet) == 15 and int(e.state().fee_sink) == 5, "a travel spend leaves the wallet for the sink")
	_err(e, "wallet.spend", 1, {"reason": "travel", "amount": 7}, "bad_request", T0, "amount not in the cost table")
	_err(e, "wallet.spend", 1, {"reason": "travel", "amount": -5}, "bad_request", T0, "negative spend")
	_err(e, "wallet.spend", 1, {"reason": "travel", "amount": 5.5}, "bad_request", T0, "fractional spend")
	_err(e, "wallet.spend", 1, {"reason": "bribe", "amount": 5}, "bad_request", T0, "unknown reason")
	_err(e, "wallet.spend", 1, {"reason": "claim", "amount": cat.spend_costs.claim[0]}, "insufficient_funds", T0, "claim with 15")
	var idx := cat.objective_rewards.find(2)
	r = _ok(e, "objective.claim", 1, {"index": idx})
	_expect(int(r.reward) == 2 and int(r.wallet) == 17, "an objective pays its T-stones")
	_err(e, "objective.claim", 1, {"index": idx}, "conflict", T0, "claimed twice")
	_err(e, "objective.claim", 1, {"index": 999}, "bad_request", T0, "index out of range")
	_expect(int(e.state().faucet.objectives) == 2, "objective rewards are booked as faucet")
	r = _ok(e, "wallet.get", 1)
	_expect(int(r.wallet) == 17 and int(r.held) == 0, "wallet.get reports wallet and holds")
	return true

func _bad_item(e: MarketEngine, slot: Dictionary, why: String) -> void:
	_err(e, "vault.deposit_item", 1, {"slot_dict": slot}, "invalid_asset", T0, why)

func _test_item_deposits() -> bool:
	var r := _rules()
	r.limits.deposit_caps.stone = 30
	r.limits.max_vault_items = 6
	var e := _engine(r)
	var stone := _stack("stone", 10)
	var uid := str(_ok(e, "vault.deposit_item", 1, {"slot_dict": stone}).uid)
	_expect(uid == stone.uid and Ledger.canon(e.L.acct(1).vault_items[uid]) == Ledger.canon(Ledger.norm(stone)), "a deposit keeps its own uid, origin and seq, byte for byte")
	_err(e, "vault.deposit_item", 2, {"slot_dict": stone}, "conflict", T0, "the same uid deposited twice (a dupe)")
	_bad_item(e, Provenance.strip(_stack("stone", 1)), "no server provenance (a client dict)")
	_bad_item(e, _with(_stack("stone", 1), "origin", "cheat"), "an origin the server never stamps")
	var base := _stack("stone", 5)
	_bad_item(e, _with(base, "id", "unobtainium"), "unknown def")
	_bad_item(e, _stack("tamed_animal", 1), "pet in item form")
	_bad_item(e, _with(base, "count", 1000), "over stack_max")
	_bad_item(e, _with(base, "count", 2.5), "fractional count")
	_bad_item(e, _with(base, "level", 61), "level 61")
	_bad_item(e, _with(base, "level", 0), "level 0")
	_bad_item(e, _with(base, "flags", ["locked"]), "locked")
	_bad_item(e, _with(base, "flags", ["unstable"]), "unstable")
	_bad_item(e, _with(base, "flags", ["shiny"]), "unknown flag")
	_bad_item(e, _with(base, "attributes", {"evil": 1}), "unknown attribute")
	_bad_item(e, _with(base, "attributes", {"hardness": 11}), "attribute out of range")
	_bad_item(e, _with(base, "attributes", {"tint": "red"}), "tint not a colour")
	_bad_item(e, _with(base, "attributes", {"tint": "#-12345"}), "tint with a sign")
	_bad_item(e, _with(base, "attributes", {"tint": "#+1234567"}), "tint with a sign, 8 digits")
	_bad_item(e, _with(base, "durability", 5), "durability on a plain item")
	_bad_item(e, _with(base, "dupe", true), "unknown field")
	_bad_item(e, _with(base, "process_count", 500), "process count")
	var knife := _stack("stone_knife", 1, 10)
	var cap := int(knife.max_durability)
	_bad_item(e, _with(knife, "durability", 0), "broken")
	_bad_item(e, _with(knife, "durability", cap + 1), "durability over max")
	_bad_item(e, _with(_with(knife, "max_durability", cap + 50), "durability", cap + 50), "max durability over the level cap")
	_bad_item(e, _with(knife, "count", 2), "durability items do not stack")
	_ok(e, "vault.deposit_item", 1, {"slot_dict": knife})
	var fancy := _with(_with(base, "flags", ["raw"]), "attributes", {"tint": "#8a8a8a", "hardness": 2, "level": 5, "climate": "tundra"})
	var got := _ok(e, "vault.deposit_item", 1, {"slot_dict": fancy})
	_expect(got.item.flags == ["raw"] and int(got.item.attributes.hardness) == 2, "whitelisted flags and attributes survive")
	_err(e, "vault.deposit_item", 1, {}, "bad_request", T0, "no slot_dict")
	_err(e, "vault.deposit_item", 1, {"slot_dict": "stone"}, "bad_request", T0, "slot_dict not an object")
	_deposit(e, 1, "stone", 15) # 10 + 5 + 15 = the 30 cap
	_err(e, "vault.deposit_item", 1, {"slot_dict": _stack("stone", 1)}, "limit_reached", T0 + 60, "rolling 24 h cap")
	_deposit(e, 1, "stone", 1, 1, T0 + 86401)
	_deposit(e, 1, "wood_log", 1, 1, T0 + 86401)
	_err(e, "vault.deposit_item", 1, {"slot_dict": _stack("wood_log", 1)}, "limit_reached", T0 + 86401, "vault full")
	var derived := EconRules.load_default()
	var pinned: Dictionary = derived.limits.deposit_caps
	derived.limits.deposit_caps = {}
	for def_id in pinned:
		_expect(cat.item(def_id) != null and derived.deposit_cap(def_id, cat.item(def_id).categories) == int(pinned[def_id]), "limits.json pins %s to its category rule" % def_id)
	for def_id in cat.items:
		if def_id not in r.g("denied_defs") and def_id != AssetValidator.CAGE: # a cage needs its animal (tested below)
			var made := ItemStack.make(StringName(def_id), 1, {}, 30).to_dict()
			var why: String = e.V.item(made)
			_expect(why == "", "a fresh %s from the catalog passes deposit checks (%s)" % [def_id, why])
	for key in base.keys() + ["def_id"]:
		for hostile in HOSTILE:
			_bad_item(e, _with(base, key, hostile), "item %s = %s" % [key, var_to_str(hostile)])
	var wire: Dictionary = JSON.parse_string(JSON.stringify(_stack("wood_log", 3, 7)))
	got = _ok(e, "vault.deposit_item", 2, {"slot_dict": wire}, T0 + 86401)
	_expect(typeof(got.item.level) == TYPE_INT and int(got.item.count) == 3, "JSON floats from the wire normalise to ints")
	# Contract 6.1: a captured (untamed) animal trades as its cage; the buyer still tames it.
	var genes := CreatureGenetics.neutral()
	genes.ivs = {&"health": 3, &"melee_defense": 4, &"ranged_defense": 5, &"melee_attack": 6, &"ranged_attack": 7, &"accuracy": 8, &"speed": 9}
	var cage := _stamp(ItemStack.make(&"captured_animal", 1, {"species": "compsognathus", "variant": "", "grade_seed": 77, "genetics": genes.to_dict()}).to_dict(), "i", "tame")
	_expect(e.V.item(Provenance.strip(cage)) == "", "a captured cage passes deposit checks (%s)" % e.V.item(Provenance.strip(cage)))
	_bad_item(e, _with(cage, "attributes", _with(cage.attributes, "species", "dragon")), "a cage of an unknown species")
	_bad_item(e, _with(cage, "attributes", _with(cage.attributes, "tint", "#ffffff")), "a cage with a foreign attribute")
	_bad_item(e, _with(cage, "attributes", _with(cage.attributes, "genetics", {"ivs": {"health": 40}})), "a cage with impossible genetics")
	_err(e, "market.order_create", 2, {"def_id": "captured_animal", "min_level": 1, "qty": 1, "unit_price": 50, "duration_h": 24}, "invalid_asset", T0 + 86401, "cages trade by listing only")
	return true

func _bad_pet(e: MarketEngine, pet: Dictionary, why: String) -> void:
	_err(e, "vault.deposit_pet", 1, {"pet_dict": pet}, "invalid_asset", T0, why)

func _test_pet_deposits() -> bool:
	var r := _rules()
	r.limits.pet_species_cap = 2
	var e := _engine(r)
	var p := _pet("velociraptor", 1, 7)
	var got := _ok(e, "vault.deposit_pet", 1, {"pet_dict": p})
	_expect(got.uid == p.uid and Ledger.canon(got.pet) == Ledger.canon(Ledger.norm(p)), "a pet keeps its uid, origin, lineage and stats byte for byte")
	_err(e, "vault.deposit_pet", 2, {"pet_dict": p}, "conflict", T0, "the same pet deposited twice")
	var levelled := _pet("velociraptor", 6, 8)
	got = _ok(e, "vault.deposit_pet", 1, {"pet_dict": JSON.parse_string(JSON.stringify(levelled))})
	_expect(int(got.pet.level) == 6, "a levelled pet's stats recompute from species, level and genetics")
	_err(e, "vault.deposit_pet", 1, {"pet_dict": _pet("velociraptor", 1, 9)}, "limit_reached", T0, "per-species daily cap")
	var t := _pet("triceratops", 3, 11)
	_bad_pet(e, Provenance.strip(t), "a pet without server provenance (a client dict)")
	_bad_pet(e, _with(t, "grade", "S+" if t.grade != "S+" else "D-"), "a grade its genetics do not give")
	_bad_pet(e, _with(t, "parent_uids", ["p1", "p2", "p3"]), "three parents")
	_bad_pet(e, _with(t, "name", "x".repeat(PetRecord.NAME_MAX + 1)), "a name over the limit")
	_bad_pet(e, _with(t, "hp", float(t.hp) * 1.01), "hp +1 %")
	_bad_pet(e, _with(t, "speed", float(t.speed) * 0.99), "speed -1 %")
	_bad_pet(e, _with(t, "attack", "lots"), "attack not a number")
	var g: Dictionary = t.genetics.duplicate(true)
	g.ivs.health = 32
	_bad_pet(e, _with(t, "genetics", g), "IV 32")
	g = t.genetics.duplicate(true)
	g.evs = {"health": 100, "melee_attack": 100, "speed": 100, "accuracy": 1}
	_bad_pet(e, _with(t, "genetics", g), "EV total 301")
	g = t.genetics.duplicate(true)
	g.level_gains = {"health": 7}
	_bad_pet(e, _with(t, "genetics", g), "more level gains than levels")
	g = t.genetics.duplicate(true)
	g.ivs.erase("speed")
	_bad_pet(e, _with(t, "genetics", g), "missing IV")
	_bad_pet(e, _with(t, "bag", [_stack("stone", 1)]), "bag not empty")
	_bad_pet(e, _with(t, "summoned", true), "summoned")
	_bad_pet(e, _with(t, "species", "dragon"), "unknown species")
	_bad_pet(e, _with(t, "xp_rate", 2.0), "xp_rate not a grade rate")
	_bad_pet(e, _with(t, "level", 0), "level 0")
	_bad_pet(e, _with(t, "level", 4), "stats belong to another level")
	_err(e, "vault.deposit_pet", 1, {"pet_dict": 5}, "bad_request", T0, "pet_dict not an object")
	for key in t.keys() + ["summoned"]:
		for hostile in HOSTILE:
			if not (hostile is String and key in ["owner", "tamer", "name"]): # any string is a name
				_bad_pet(e, _with(t, key, hostile), "pet %s = %s" % [key, var_to_str(hostile)])
	_bad_pet(e, _with(t, "summoned", 1), "summoned as 1")
	_bad_pet(e, _with(t, "uid", "p1"), "a uid the server never issues")
	_bad_pet(e, _with(t, "variant", "triceratops_golden"), "variant the def does not list")
	_bad_pet(e, _with(t, "tamed_role", [1]), "tamed_role not names")
	_ok(e, "vault.deposit_pet", 1, {"pet_dict": _with(_pet("triceratops", 3, 11), "summoned", 0)})
	_ok(e, "vault.deposit_pet", 1, {"pet_dict": t})
	var snow := _with(_pet("velociraptor", 1, 40), "variant", "velociraptor_snow")
	_expect(str(_ok(e, "vault.deposit_pet", 3, {"pet_dict": snow}).pet.variant) == "velociraptor_snow", "a variant the def lists is accepted")
	var noisy := _pet("triceratops", 2, 12)
	noisy.hp = float(noisy.hp) * 1.004
	got = _ok(e, "vault.deposit_pet", 2, {"pet_dict": noisy})
	_expect(float(got.pet.hp) == float(noisy.hp), "float noise under 0.5 % is accepted and stored as exported")
	return true

func _test_withdraw() -> bool:
	var e := _engine()
	var uid := _deposit(e, 1, "stone", 10, 3)
	var r := _ok(e, "vault.withdraw_item", 1, {"uid": uid, "count": 4})
	_expect(int(r.item.count) == 4, "withdraw returns the units")
	var v := _ok(e, "vault.get", 1)
	_expect(v.items.size() == 1 and v.items[0].uid == uid and int(v.items[0].count) == 6, "the rest keeps its uid")
	var back := ItemStack.from_dict(r.item)
	_expect(back.def_id == &"stone" and back.count == 4 and back.level == 3, "a withdrawn dict loads as an ItemStack")
	_err(e, "vault.withdraw_item", 1, {"uid": uid, "count": 7}, "insufficient_items", T0, "more than the stack")
	_err(e, "vault.withdraw_item", 2, {"uid": uid}, "not_found", T0, "someone else's uid")
	_ok(e, "vault.withdraw_item", 1, {"uid": uid})
	_err(e, "vault.withdraw_item", 1, {"uid": uid}, "not_found", T0, "withdrawn twice")
	_expect(int(e.state().items_in.stone) == 10 and int(e.state().items_out.stone) == 10, "deposit and withdraw ledgers balance")
	var pet := _pet("velociraptor", 2, 3)
	var pid := str(_ok(e, "vault.deposit_pet", 1, {"pet_dict": pet}).uid)
	r = _ok(e, "vault.withdraw_pet", 1, {"uid": pid})
	var rec := PetRecord.from_dict(r.pet)
	_expect(rec.level == 2 and absf(rec.hp - float(pet.hp)) < 0.01, "a withdrawn pet loads as a PetRecord")
	_err(e, "vault.withdraw_pet", 1, {"uid": pid}, "not_found", T0, "pet withdrawn twice")
	return true

func _test_fixed_listings() -> bool:
	var r := _rules()
	r.limits.max_open_listings = 3
	var e := _engine(r)
	var uid := _deposit(e, 1, "stone", 10)
	var w1 := _wallet(e, 1)
	var ask := {"asset": {"uid": uid, "count": 6}, "unit_price": 10, "duration_h": 24}
	_err(e, "market.list_fixed", 1, _with(ask, "duration_h", 5), "bad_request", T0, "5 h duration")
	_err(e, "market.list_fixed", 1, _with(ask, "unit_price", 0), "bad_request", T0, "price 0")
	_err(e, "market.list_fixed", 1, _with(ask, "asset", {"uid": "i99999"}), "not_found", T0, "uid not in vault")
	_err(e, "market.list_fixed", 1, _with(ask, "asset", {"uid": uid, "count": 11}), "insufficient_items", T0, "more than the stack")
	_err(e, "market.list_fixed", 1, _with(ask, "asset", uid), "bad_request", T0, "asset not an object")
	_err(e, "market.list_fixed", 2, ask, "not_found", T0, "listing someone else's stack")
	var res := _ok(e, "market.list_fixed", 1, ask)
	var lid := str(res.listing.id)
	_expect(int(res.fee) == 3 and _wallet(e, 1) == w1 - 3, "5 % listing fee, rounded up")
	_expect(int(e.L.acct(1).vault_items[uid].count) == 4, "the unlisted part stays in the vault")
	var w2 := _wallet(e, 2)
	res = _ok(e, "market.buy", 2, {"listing_id": lid, "count": 2})
	_expect(_wallet(e, 2) == w2 - 20, "the buyer pays unit x count")
	_expect(_wallet(e, 1) == w1 - 3 + 19, "the seller gets the price minus 3 % tax (rounded up)")
	_expect(int(res.asset.count) == 2 and e.L.acct(2).vault_items.has(res.asset.uid), "bought units land in the buyer's vault")
	_expect(int(res.listing.left) == 4, "a partial buy leaves the rest listed")
	_err(e, "market.buy", 1, {"listing_id": lid, "count": 1}, "self_trade", T0, "self-buy")
	_err(e, "market.buy", 2, {"listing_id": lid, "count": 5}, "insufficient_items", T0, "more than listed")
	_err(e, "market.buy", 2, {"listing_id": "L99999"}, "not_found", T0, "unknown listing")
	_err(e, "market.cancel", 2, {"listing_id": lid}, "not_owner", T0, "cancel someone else's")
	res = _ok(e, "market.cancel", 1, {"listing_id": lid})
	_expect(int(res.asset.count) == 4 and e.L.acct(1).vault_items.has(res.asset.uid), "cancel after a partial sale returns the rest")
	_expect(_wallet(e, 1) == w1 - 3 + 19, "the listing fee is not refunded")
	_err(e, "market.buy", 2, {"listing_id": lid}, "closed", T0, "buy a cancelled listing")
	_err(e, "market.cancel", 1, {"listing_id": lid}, "closed", T0, "cancel twice")
	var knife := _deposit(e, 1, "stone_knife", 1, 5)
	var kid := _list(e, 1, knife, 500)
	_ok(e, "market.buy", 2, {"listing_id": kid})
	_err(e, "market.buy", 3, {"listing_id": kid}, "closed", T0, "the same listing bought twice")
	_expect(e.L.acct(2).vault_items.has(knife), "a whole-lot buy moves the uid itself")
	var big := _list(e, 1, _deposit(e, 1, "stone", 1), 1000000)
	_err(e, "market.buy", 2, {"listing_id": big}, "insufficient_funds", T0, "too expensive")
	var logs := _deposit(e, 1, "wood_log", 5)
	_list(e, 1, logs, 2, 1)
	_list(e, 1, logs, 2, 1)
	_err(e, "market.list_fixed", 1, {"asset": {"uid": logs, "count": 1}, "unit_price": 2, "duration_h": 12}, "limit_reached", T0, "open listing cap")
	var poor := _engine(_rules(false), 1)
	var pu := _deposit(poor, 1, "stone", 1)
	_err(poor, "market.list_fixed", 1, {"asset": {"uid": pu}, "unit_price": 1000, "duration_h": 12}, "insufficient_funds", T0, "fee above the wallet")
	return true

func _test_auctions() -> bool:
	var e := _engine()
	var uid := _deposit(e, 1, "copper_ore", 5)
	_err(e, "market.list_auction", 1, {"asset": {"uid": uid}, "start_bid": 100, "buyout": 100, "duration_h": 24}, "bad_request", T0, "buyout not above start")
	_err(e, "market.list_auction", 1, {"asset": {"uid": uid}, "start_bid": 0, "duration_h": 24}, "bad_request", T0, "start 0")
	var res := _ok(e, "market.list_auction", 1, {"asset": {"uid": uid}, "start_bid": 100, "buyout": 500, "duration_h": 24})
	var aid := str(res.listing.id)
	_expect(int(res.fee) == 5, "the auction fee is 5 % of start_bid")
	_err(e, "market.bid", 2, {"listing_id": aid, "amount": 99}, "bid_too_low", T0, "under start")
	var w2 := _wallet(e, 2)
	_ok(e, "market.bid", 2, {"listing_id": aid, "amount": 100})
	_expect(_wallet(e, 2) == w2 - 100, "a bid moves into escrow")
	_expect(int(_ok(e, "wallet.get", 2).held) == 100, "wallet.get shows the hold")
	_err(e, "market.bid", 3, {"listing_id": aid, "amount": 104}, "bid_too_low", T0, "under +5 %")
	_ok(e, "market.bid", 3, {"listing_id": aid, "amount": 105})
	_expect(_wallet(e, 2) == w2, "an outbid hold comes back")
	_expect(_events(e, 2) == ["outbid"], "the outbid bidder is told")
	_err(e, "market.bid", 1, {"listing_id": aid, "amount": 200}, "self_trade", T0, "seller bids")
	_err(e, "market.bid", 2, {"listing_id": aid, "amount": 500}, "bad_request", T0, "bid at the buyout")
	_err(e, "market.bid", 2, {"listing_id": aid, "amount": 2000000000}, "bad_request", T0, "bid above the lot cap")
	_err(e, "market.cancel", 1, {"listing_id": aid}, "conflict", T0, "cancel an auction with a bid")
	_err(e, "market.buy", 2, {"listing_id": aid}, "bad_request", T0, "buy on an auction")
	var w3 := _wallet(e, 3)
	var w1 := _wallet(e, 1)
	var w4 := _wallet(e, 4)
	_err(e, "market.buyout", 1, {"listing_id": aid}, "self_trade", T0, "seller buys out")
	res = _ok(e, "market.buyout", 4, {"listing_id": aid})
	_expect(_wallet(e, 3) == w3 + 105, "a buyout refunds the standing bid")
	_expect(_wallet(e, 1) == w1 + 485 and _wallet(e, 4) == w4 - 500, "buyout pays the seller minus tax")
	_expect(e.L.acct(4).vault_items.has(uid), "the lot keeps its uid in the winner's vault")
	_expect(_events(e, 3) == ["outbid"] and _events(e, 1) == ["sold"], "outbid and sold events")
	_err(e, "market.buyout", 2, {"listing_id": aid}, "closed", T0, "buyout a sold auction")
	var plain := _auction(e, 1, _deposit(e, 1, "stone", 2), 10, 0, 12)
	_err(e, "market.buyout", 2, {"listing_id": plain}, "bad_request", T0, "no buyout set")
	var fixed := _list(e, 1, _deposit(e, 1, "stone", 1), 5)
	_err(e, "market.bid", 2, {"listing_id": fixed, "amount": 50}, "bad_request", T0, "bid on a fixed listing")
	var mine := _auction(e, 1, _deposit(e, 1, "stone", 3), 20, 100, 12)
	_ok(e, "market.bid", 2, {"listing_id": mine, "amount": 20})
	_ok(e, "market.bid", 2, {"listing_id": mine, "amount": 40})
	_expect(_events(e, 2).is_empty(), "raising your own bid is not an outbid")
	w2 = _wallet(e, 2)
	_ok(e, "market.buyout", 2, {"listing_id": mine})
	_expect(_wallet(e, 2) == w2 + 40 - 100, "the high bidder's buyout nets out their hold")
	var lone := _deposit(e, 1, "stone", 4)
	var quiet := _auction(e, 1, lone, 30, 0, 12)
	_ok(e, "market.cancel", 1, {"listing_id": quiet})
	_expect(e.L.acct(1).vault_items.has(lone), "cancelling an auction without bids returns the lot")
	return true

func _test_anti_snipe_and_settlement() -> bool:
	var e := _engine()
	var lot := _deposit(e, 1, "copper_ore", 2)
	var aid := _auction(e, 1, lot, 10, 0, 12)
	var lst: Dictionary = e.state().listings[aid]
	var ts := int(lst.ends) - 30
	var amount := 10
	var bidder := 2
	var ends_after_ten := 0
	for i in 11:
		_ok(e, "market.bid", bidder, {"listing_id": aid, "amount": amount}, ts)
		lst = e.state().listings[aid]
		if i == 9:
			ends_after_ten = int(lst.ends)
		_expect(i >= 10 or int(lst.ends) == ts + 60, "a late bid extends to now + 60 s (bid %d)" % i)
		amount *= 2
		bidder = 5 - bidder
		ts = int(lst.ends) - 10
	_expect(int(lst.ext) == 10 and int(lst.ends) == ends_after_ten, "at most 10 extensions")
	_err(e, "market.bid", bidder, {"listing_id": aid, "amount": amount}, "expired", int(lst.ends), "bid after the end")
	var high := int(lst.bid)
	var winner := int(lst.bidder)
	var w1 := _wallet(e, 1)
	var t := _ok(e, "sys.tick", 0, {}, int(lst.ends))
	_expect(int(t.settled) == 1, "the tick settles the ended auction")
	_expect(_wallet(e, 1) == w1 + high - EconRules.ceil_bp(high, 300), "settlement pays the seller minus tax")
	_expect(e.L.acct(winner).vault_items.has(lot), "the winner receives the lot")
	_expect("won" in _events(e, winner, int(lst.ends)), "the winner is told")
	_expect(e.state().closed_listings[aid].state == "sold", "the auction is sold")
	var idle := _deposit(e, 1, "fibre_stalk", 4, 1, int(lst.ends))
	var quiet := _auction(e, 1, idle, 50, 0, 12, int(lst.ends))
	_ok(e, "sys.tick", 0, {}, int(lst.ends) + 12 * 3600)
	_expect(e.L.acct(1).vault_items.has(idle), "an auction without bids returns to the seller")
	_expect(e.state().closed_listings[quiet].state == "expired", "and is marked expired")
	return true

func _order(e: MarketEngine, who: int, def_id: String, qty: int, unit: int, lo: int = 1, hi: int = 60, hours: int = 24, ts: int = T0) -> String:
	return str(_ok(e, "market.order_create", who, {"def_id": def_id, "min_level": lo, "max_level": hi, "qty": qty, "unit_price": unit, "duration_h": hours}, ts).get("order", {}).get("id", ""))

func _test_orders() -> bool:
	var r := _rules()
	r.limits.max_open_orders = 2
	var e := _engine(r)
	var spec := {"def_id": "stone", "min_level": 1, "max_level": 10, "qty": 10, "unit_price": 5, "duration_h": 24}
	_err(e, "market.order_create", 2, _with(spec, "def_id", "unobtainium"), "invalid_asset", T0, "unknown def")
	_err(e, "market.order_create", 2, _with(spec, "def_id", "tamed_animal"), "invalid_asset", T0, "denied def")
	_err(e, "market.order_create", 2, _with(_with(spec, "min_level", 10), "max_level", 5), "bad_request", T0, "max below min")
	_err(e, "market.order_create", 2, _with(spec, "qty", 0), "bad_request", T0, "qty 0")
	_err(e, "market.order_create", 2, _with(_with(spec, "qty", 9999), "unit_price", 1000000), "insufficient_funds", T0, "escrow above the wallet")
	var w2 := _wallet(e, 2)
	var oid := str(_ok(e, "market.order_create", 2, spec).order.id)
	_expect(_wallet(e, 2) == w2 - 50, "an order escrows qty x price")
	var uid := _deposit(e, 1, "stone", 8, 3)
	var high := _deposit(e, 1, "stone", 2, 20)
	_err(e, "market.sell_to_order", 1, {"order_id": oid, "uid": high, "count": 1}, "invalid_asset", T0, "level above range")
	_err(e, "market.sell_to_order", 2, {"order_id": oid, "uid": uid, "count": 1}, "self_trade", T0, "own order")
	_err(e, "market.sell_to_order", 1, {"order_id": oid, "uid": uid, "count": 9}, "insufficient_items", T0, "more than the stack")
	_err(e, "market.sell_to_order", 1, {"order_id": oid, "uid": "i99999", "count": 1}, "not_found", T0, "uid not in vault")
	_err(e, "market.sell_to_order", 1, {"order_id": oid, "uid": _deposit(e, 1, "wood_log", 2), "count": 1}, "invalid_asset", T0, "wrong def")
	var w1 := _wallet(e, 1)
	var res := _ok(e, "market.sell_to_order", 1, {"order_id": oid, "uid": uid, "count": 4})
	_expect(_wallet(e, 1) == w1 + 19, "the seller gets 20 minus tax")
	_expect(int(res.order.filled) == 4 and int(res.order.escrow) == 30, "a partial fill draws from escrow")
	var more := _deposit(e, 1, "stone", 10, 2)
	_err(e, "market.sell_to_order", 1, {"order_id": oid, "uid": more, "count": 7}, "bad_request", T0, "more than the order wants")
	_ok(e, "market.sell_to_order", 1, {"order_id": oid, "uid": uid, "count": 4})
	res = _ok(e, "market.sell_to_order", 1, {"order_id": oid, "uid": more, "count": 2})
	_expect(res.order.state == "filled" and int(res.order.escrow) == 0, "the order closes when filled")
	_err(e, "market.sell_to_order", 1, {"order_id": oid, "uid": more, "count": 1}, "closed", T0, "sell to a filled order")
	var got := 0
	for st in e.L.acct(2).vault_items.values():
		if st.id == "stone":
			got += int(st.count)
	_expect(got == 10 and _events(e, 2) == ["filled", "filled", "filled"], "the buyer's vault holds the 10 and three fill events")
	var o2 := _order(e, 2, "stone", 3, 2)
	var o3 := _order(e, 2, "wood_log", 1, 9)
	_err(e, "market.order_create", 2, spec, "limit_reached", T0, "open order cap")
	_err(e, "market.order_cancel", 1, {"order_id": o2}, "not_owner", T0, "cancel someone else's")
	w2 = _wallet(e, 2)
	_ok(e, "market.order_cancel", 2, {"order_id": o2})
	_expect(_wallet(e, 2) == w2 + 6, "cancel refunds the escrow")
	_err(e, "market.order_cancel", 2, {"order_id": o2}, "closed", T0, "cancel twice")
	_err(e, "market.order_cancel", 2, {"order_id": "O999999"}, "not_found", T0, "unknown order")
	var o4 := _order(e, 3, "wood_log", 2, 12)
	var best := _ok(e, "market.orders", 1, {"def_id": "wood_log"})
	_expect(best.orders.size() == 2 and best.orders[0].id == o4 and best.orders[1].id == o3, "orders list best price first")
	var wood := _deposit(e, 1, "wood_log", 1)
	_err(e, "market.sell_to_order", 1, {"order_id": o3, "uid": wood, "count": 1}, "expired", T0 + 24 * 3600, "sell after the end")
	w2 = _wallet(e, 2)
	_ok(e, "sys.tick", 0, {}, T0 + 24 * 3600)
	_expect(_wallet(e, 2) == w2 + 9 and e.state().closed_orders[o3].state == "expired", "expiry refunds the escrow")
	_err(e, "market.sell_to_order", 1, {"order_id": o3, "uid": wood, "count": 1}, "closed", T0 + 24 * 3600, "sell to an expired order")
	return true

func _test_expiry() -> bool:
	var e := _engine()
	var uid := _deposit(e, 1, "raw_meat", 6)
	var lid := _list(e, 1, uid, 3, 4, T0, 12)
	var end := T0 + 12 * 3600
	_err(e, "market.buy", 2, {"listing_id": lid}, "expired", end, "buy after the end")
	_err(e, "market.cancel", 1, {"listing_id": lid}, "expired", end, "cancel after the end")
	_ok(e, "sys.tick", 0, {}, end)
	var stacks: Array = e.L.acct(1).vault_items.values()
	var meat := 0
	for st in stacks:
		meat += int(st.count)
	_expect(meat == 6 and e.state().closed_listings[lid].state == "expired", "expiry returns unsold units")
	_expect(_events(e, 1, end) == ["expired"], "the seller is told")
	var seq := e.seq()
	_ok(e, "sys.tick", 0, {}, end + 5)
	_expect(e.seq() == seq, "an idle tick changes nothing and is not journaled")
	return true

func _test_search() -> bool:
	var e := _engine()
	var stone := _list(e, 1, _deposit(e, 1, "stone", 5), 10)
	_list(e, 1, _deposit(e, 1, "stone", 3, 5), 30, -1, T0, 48)
	var knife := _list(e, 1, _deposit(e, 1, "stone_knife", 1, 10), 200, -1, T0, 72)
	var copper := _auction(e, 1, _deposit(e, 1, "copper_ore", 4), 50, 0, 12)
	var raptor := _pet("velociraptor", 3, 21)
	var raptor_uid := str(_ok(e, "vault.deposit_pet", 2, {"pet_dict": raptor}).uid)
	var raptor_lid := _list(e, 2, raptor_uid, 900)
	var tric_lid := _auction(e, 2, str(_ok(e, "vault.deposit_pet", 2, {"pet_dict": _pet("triceratops", 1, 22)}).uid), 700, 0, 48)
	var all := _ok(e, "market.search", 3, {})
	_expect(int(all.total) == 6 and all.results[0].id == stone, "default search is cheapest first")
	_expect(_ok(e, "market.search", 3, {"sort": "price_desc"}).results[0].id == raptor_lid, "price_desc")
	_expect(int(_ok(e, "market.search", 3, {"kind": "auction"}).total) == 2, "kind filter")
	var pets := _ok(e, "market.search", 3, {"asset": "pet"})
	_expect(int(pets.total) == 2, "asset filter")
	for row in pets.results:
		var a: Dictionary = row.asset
		_expect(a.has("genetics") and a.genetics.ivs.size() == 7 and a.has("grade") and int(a.level) >= 1 and float(a.hp) > 0.0 and float(a.speed) > 0.0, "pet listings carry full stats and genetics")
	_expect(int(_ok(e, "market.search", 3, {"species": "triceratops"}).total) == 1, "species filter")
	var tools := _ok(e, "market.search", 3, {"category": "tool"})
	_expect(int(tools.total) == 1 and tools.results[0].id == knife, "category filter")
	_expect(int(_ok(e, "market.search", 3, {"q": "STONE"}).total) == 3, "text search matches ids and names, any case")
	_expect(int(_ok(e, "market.search", 3, {"min_level": 5}).total) == 2, "min_level filter")
	_expect(int(_ok(e, "market.search", 3, {"max_level": 1, "asset": "item"}).total) == 2, "max_level filter")
	_expect(int(_ok(e, "market.search", 3, {"min_price": 100, "max_price": 800}).total) == 2, "price filter")
	var grade := str(e.state().listings[raptor_lid].asset.grade)
	var by_grade := _ok(e, "market.search", 3, {"grade": grade.substr(0, 1)})
	_expect(int(by_grade.total) >= 1, "grade letter filter")
	for row in by_grade.results:
		_expect(str(row.asset.grade).begins_with(grade.substr(0, 1)), "grade filter only returns that letter")
	var hp := float(e.state().listings[raptor_lid].asset.hp)
	_expect(_ok(e, "market.search", 3, {"stat_min": {"health": hp - 0.5}, "species": "velociraptor"}).results[0].id == raptor_lid, "stat_min keeps strong pets")
	_expect(int(_ok(e, "market.search", 3, {"stat_min": {"health": 1.0e9}}).total) == 0, "stat_min drops weak pets")
	_expect(_ok(e, "market.search", 3, {"sort": "ending_soon"}).results[0].id == copper, "ending_soon")
	_expect(_ok(e, "market.search", 3, {"sort": "newest"}).results[0].id == tric_lid, "newest")
	_expect(_ok(e, "market.search", 3, {"sort": "level_desc"}).results[0].id == knife, "level_desc")
	var p1 := _ok(e, "market.search", 3, {"page_size": 4})
	var p2 := _ok(e, "market.search", 3, {"page_size": 4, "page": 2})
	_expect(p1.results.size() == 4 and p2.results.size() == 2 and p2.results[0].id != p1.results[0].id, "paging")
	_expect(str(all.results[0].seller_name) == "Player 1", "results name the seller")
	_err(e, "market.search", 3, {"page_size": 51}, "bad_request", T0, "page_size over 50")
	_err(e, "market.search", 3, {"sort": "random"}, "bad_request", T0, "unknown sort")
	_err(e, "market.search", 3, {"kind": "barter"}, "bad_request", T0, "unknown kind")
	_err(e, "market.search", 3, {"stat_min": {"luck": 1}}, "bad_request", T0, "unknown stat")
	_expect(int(_ok(e, "market.search", 3, {}, T0 + 12 * 3600).total) == 5, "ended listings are hidden before the tick")
	var mine := _ok(e, "market.mine", 1)
	_expect(mine.listings.size() == 4 and mine.orders.is_empty(), "market.mine lists my listings")
	_ok(e, "vault.get", 1)
	_ok(e, "wallet.get", 1)
	return true

func _test_history_and_reference() -> bool:
	var e := _engine(null, 6)
	var trade := func (seller: int, buyer: int, count: int, unit: int, ts: int) -> void:
		var lid := _list(e, seller, _deposit(e, seller, "stone", count, 1, ts), unit, -1, ts)
		_ok(e, "market.buy", buyer, {"listing_id": lid, "count": count}, ts)
	trade.call(1, 2, 5, 10, T0)
	trade.call(3, 4, 1, 12, T0 + 60)
	_expect(int(e.state().ref["item:stone"]) == 10, "reference = volume-weighted median")
	trade.call(1, 2, 10, 20, T0 + 120)
	_expect(int(e.state().ref["item:stone"]) == 20, "the median moves with volume")
	trade.call(1, 2, 100, 50, T0 + 180)
	_expect(int(e.state().ref["item:stone"]) == 20, "a third trade between one pair in 24 h is ignored (wash)")
	trade.call(5, 6, 100, 100, T0 + 240)
	_expect(int(e.state().ref["item:stone"]) == 20, "a trade above 4x the reference is ignored (outlier)")
	trade.call(3, 6, 1, 40, T0 + 7200)
	var d := _ok(e, "market.item_detail", 1, {"def_id": "stone"}, T0 + 7300)
	_expect(int(d.ref_price) == 20 and int(d.last_price) == 40, "item_detail reports reference and last price")
	_expect(int(d.volume_24h) == 217 and int(d.volume_7d) == 217, "volume counts units")
	_expect(d.buckets.size() == 2, "trades bucket by hour")
	var b: Array = d.buckets[0]
	_expect(int(b[1]) == 10 and int(b[2]) == 100 and int(b[3]) == 10 and int(b[4]) == 100 and int(b[5]) == 216, "hourly OHLC + volume")
	var recent := _ok(e, "market.trades", 1, {"def_id": "stone", "limit": 2}, T0 + 7300)
	_expect(recent.trades.size() == 2 and int(recent.trades[0].unit_price) == 40 and int(recent.trades[1].unit_price) == 100, "trades are newest first")
	_expect(_ok(e, "market.mine", 2, {}, T0 + 7300).trades.size() == 3, "market.mine lists my trades")
	_err(e, "market.item_detail", 1, {}, "bad_request", T0 + 7300, "no key")
	_err(e, "market.item_detail", 1, {"def_id": "stone", "species": "velociraptor"}, "bad_request", T0 + 7300, "two keys")
	_err(e, "market.item_detail", 1, {"def_id": "unobtainium"}, "bad_request", T0 + 7300, "unknown def")
	_err(e, "market.trades", 1, {"def_id": "stone", "limit": 500}, "bad_request", T0 + 7300, "limit over 100")
	_ok(e, "market.item_detail", 1, {"species": "velociraptor"}, T0 + 7300)
	var later := T0 + 8 * 86400
	_ok(e, "sys.tick", 0, {}, later)
	d = _ok(e, "market.item_detail", 1, {"def_id": "stone"}, later)
	_expect(d.buckets.is_empty() and int(d.volume_7d) == 0, "history keeps 7 days")
	_expect(int(d.ref_price) == 0 and not e.state().ref.has("item:stone"), "with no trades left in the window there is no reference (no stale anchor)")
	_expect(not e.state().ref_trades.has("item:stone") and e.state().pairs.is_empty(), "windows are pruned")
	return true

func _test_settlers() -> bool:
	var r := EconRules.load_default()
	var e := _engine(r, 2)
	var t := T0 - T0 % 86400 + 86400 + 5 * 3600 # 05:00 the next server day
	_expect(_ok(e, "sys.tick", 0, {}, t).settlers == true, "the first tick refreshes Settlers")
	var s := e.state()
	_expect(int(s.faucet.settlers) == 2000, "the day's budget is minted")
	var npc := _npc_orders(e)
	var escrow := 0
	for o in npc:
		escrow += int(o.escrow)
		_expect(o.npc == true and o.state == "open" and int(o.unit_price) >= 1, "Settler orders are npc buy orders")
	_expect(npc.size() >= 1 and npc.size() <= 12 and escrow <= 500, "one refresh posts at most 12 orders and 500 escrow")
	_expect(_wallet(e, 0) + escrow == 2000, "Settler holdings equal the budget")
	var listed := _ok(e, "market.orders", 1, {}, t)
	_expect(listed.orders.size() > 0 and listed.orders[0].npc == true and listed.orders[0].buyer_name == "Settlers", "orders say Settlers")
	var o: Dictionary = npc[0]
	var def := cat.item(str(o.def_id))
	var n := mini(mini(int(o.qty), def.stack_max), 3)
	var uid := _deposit(e, 1, str(o.def_id), n, 1, t)
	var w1 := _wallet(e, 1)
	_ok(e, "market.sell_to_order", 1, {"order_id": o.id, "uid": uid, "count": n}, t)
	var paid := int(o.unit_price) * n
	_expect(_wallet(e, 1) == w1 + paid - EconRules.ceil_bp(paid, 300), "selling to Settlers pays")
	_expect(int(s.items_consumed[str(o.def_id)]) == n, "Settlers consume what they buy")
	_expect(not s.ref.has("item:%s" % o.def_id), "Settler trades do not set a reference price")
	_err(e, "market.order_cancel", 1, {"order_id": npc[npc.size() - 1].id}, "not_owner", t, "cancel a Settler order")
	var seq := e.seq()
	_ok(e, "sys.tick", 0, {}, t + 60)
	_expect(e.seq() == seq, "no refresh inside the same hour")
	_ok(e, "sys.tick", 0, {}, t + 3600)
	_expect(_wallet(e, 0) + _escrow(_npc_orders(e)) == 2000 - paid and int(s.faucet.settlers) == 2000, "an hourly refresh re-posts without minting")
	_expect(not _npc_orders(e).is_empty() and not s.orders.has(o.id), "old Settler orders are replaced")
	_ok(e, "sys.tick", 0, {}, t + 86400)
	_expect(int(s.faucet.settlers) == 2000 + paid, "the next day mints only what left Settlers")
	_expect(_wallet(e, 0) + _escrow(_npc_orders(e)) == 2000, "holdings are back to the budget")
	var table := Settlers.demand_table(cat, r)
	_expect(table.size() > 20, "Settlers demand covers the catalog")
	for row in table:
		_expect(int(row[1]) >= 1 and str(row[0]) not in r.g("denied_defs"), "demand rows are priced and tradeable")
	return true

func _npc_orders(e: MarketEngine) -> Array:
	var out: Array = []
	for o in e.state().orders.values():
		if int(o.buyer) == 0:
			out.append(o)
	return out

static func _escrow(orders: Array) -> int:
	var total := 0
	for o in orders:
		total += int(o.escrow)
	return total

func _test_idempotency() -> bool:
	var e := _engine()
	var args := {"slot_dict": _stack("stone", 5), "count": 5, "rid": "dep-1"}
	var first := _op(e, "vault.deposit_item", 1, args)
	var seq := e.seq()
	var again := _op(e, "vault.deposit_item", 1, args)
	_expect(JSON.stringify(first) == JSON.stringify(again), "a repeated rid returns the cached response")
	_expect(e.seq() == seq and e.L.acct(1).vault_items.size() == 1, "and applies nothing")
	_err(e, "vault.withdraw_item", 1, {"uid": first.r.uid, "rid": "dep-1"}, "conflict", T0, "rid reused for another op")
	var lid := _list(e, 1, str(first.r.uid), 10, 2)
	var buy := {"listing_id": lid, "count": 1, "rid": "buy-1"}
	var w2 := _wallet(e, 2)
	_op(e, "market.buy", 2, buy)
	_op(e, "market.buy", 2, buy)
	_expect(_wallet(e, 2) == w2 - 10, "a double-submitted buy pays once")
	_ok(e, "market.buy", 3, buy)
	_expect(e.state().closed_listings.has(lid), "rids are per account")
	for i in 70:
		_ok(e, "vault.deposit_item", 4, {"slot_dict": _stack("wood_log", 1), "rid": "w%d" % i})
	var cache: Dictionary = e.L.acct(4).rid_cache
	_expect(cache.size() == 64 and not cache.has("w5") and cache.has("w6"), "the rid cache keeps the last 64")
	_expect(cache.w69 is Array and JSON.stringify(cache).length() < 64 * 40, "the persisted cache holds [op, seq], not response bodies")
	var stacks: int = e.L.acct(4).vault_items.size()
	seq = e.seq()
	_ok(e, "vault.deposit_item", 4, {"slot_dict": _stack("wood_log", 1), "rid": "w0"})
	_expect(e.seq() == seq + 1 and e.L.acct(4).vault_items.size() == stacks + 1, "an evicted rid applies again")
	_ok(e, "vault.deposit_item", 4, {"slot_dict": _stack("wood_log", 1), "rid": "w69"})
	_expect(e.seq() == seq + 1 and e.L.acct(4).vault_items.size() == stacks + 1, "a recent rid still hits")
	var reloaded := MarketEngine.new(_rules(), cat)
	reloaded.load_state(JSON.parse_string(e.state_json()))
	var repeat := _op(reloaded, "vault.deposit_item", 4, {"slot_dict": _stack("wood_log", 1), "rid": "w69"})
	_expect(repeat.ok and repeat.r.get("duplicate") == true and reloaded.seq() == seq + 1, "after a restart a repeat is still a no-op and says duplicate")
	_ok(e, "wallet.spend", 3, {"reason": "travel", "amount": 5, "rid": "late"}, T0 + 24 * 3600)
	_ok(e, "sys.tick", 0, {}, T0 + 25 * 3600)
	_expect(e.L.acct(4).rid_cache.is_empty() and e.L.acct(3).rid_cache.has("late"), "rid caches idle for a day are forgotten, active ones kept")
	return true

## Collects every value stored under `key` anywhere in a parsed JSON tree.
static func _collect(node: Variant, key: String, out: Array) -> void:
	if node is Dictionary:
		for k in node:
			if str(k) == key:
				out.append(node[k])
			else:
				_collect(node[k], key, out)
	elif node is Array:
		for x in node:
			_collect(x, key, out)

## Every attribute the game writes onto a stack (drop tables, catalog defaults, harvest nodes,
## crafting and combat) passes the deposit whitelist, so legitimate items are never refused.
func _test_attribute_sources() -> bool:
	var e := _engine()
	var pairs: Array = [] ## [key, value, source]
	var blocks: Array = []
	_collect(EconRules.read_json("res://data/butchering.json"), "attributes", blocks)
	for block in blocks:
		for k in block:
			pairs.append([str(k), block[k], "butchering.json"])
	var bleed := 0
	for def_id in cat.items:
		var def := cat.item(def_id)
		bleed = maxi(bleed, def.bleed_every_hits)
		for k in def.default_attributes:
			pairs.append([str(k), def.default_attributes[k], "items.json %s" % def_id])
	var buffs: Array = []
	_collect(EconRules.read_json("res://data/recipes.json"), "buff_id", buffs)
	for b in buffs:
		pairs.append(["food_buff", b, "recipes.json (crafting)"])
	var climates: Array = ["grassland"] # IslandRuntime's default
	_collect(Data.world_islands, "climate", climates)
	var da := DirAccess.open("res://data/islands")
	for fname in da.get_files() if da else []:
		if fname.ends_with(".json"):
			_collect(EconRules.read_json("res://data/islands/%s" % fname), "climate", climates)
	for c in climates:
		pairs.append(["climate", c, "island_runtime harvest"])
	for tier in ProgressionScaling.TOOL_TIERS:
		pairs.append(["material_tier", str(tier), "crafting"])
	for n in [1, 60]:
		pairs.append(["level", n, "corpse / harvest"])
	for n in 4:
		pairs.append(["toxin_hits", n, "player coat"])
	for n in bleed:
		pairs.append(["barbed_hits", n, "hunt"])
	_expect(pairs.size() > 40 and buffs.size() > 0 and climates.size() > 3, "attribute sources were found (%d)" % pairs.size())
	for row in pairs:
		var why: String = e.V._attribute(row[0], Ledger.norm(row[1]))
		_expect(why == "", "attribute %s = %s from %s is allowed (%s)" % [row[0], var_to_str(row[1]), row[2], why])
	# End to end: the rare raptor bone drop, and a knife crafted from it (Crafting copies the
	# primary's attributes and adds material_tier).
	var bone := _stamp(ItemStack.make(&"raptor_bone", 1, {"hardness": 4, "frill": 1}, 12).to_dict(), "i", "loot")
	_ok(e, "vault.deposit_item", 1, {"slot_dict": bone})
	var knife := _stamp(ItemStack.make(&"stone_knife", 1, {"hardness": 4, "frill": 1, "material_tier": "bone"}, 12).to_dict(), "i", "craft")
	_ok(e, "vault.deposit_item", 1, {"slot_dict": knife})
	return true

## Contract 6.5 damping must not be capturable: two self-dealt trades at 10x set the first
## reference, and honest trades from more pairs than that must still move it back.
func _test_reference_poisoning() -> bool:
	var e := _engine(null, 8)
	var key := "item:fibre_stalk"
	var trade := func (seller: int, buyer: int, count: int, unit: int, ts: int) -> void:
		var lid := _list(e, seller, _deposit(e, seller, "fibre_stalk", count, 1, ts), unit, -1, ts)
		_ok(e, "market.buy", buyer, {"listing_id": lid, "count": count}, ts)
	trade.call(1, 2, 1, 100, T0)
	trade.call(2, 1, 1, 100, T0 + 60)
	_expect(int(e.state().ref[key]) == 100, "two self-dealt trades set the first reference")
	trade.call(3, 4, 20, 10, T0 + 120)
	trade.call(5, 6, 20, 10, T0 + 180)
	trade.call(7, 8, 20, 10, T0 + 240)
	_expect(int(e.state().ref[key]) == 10, "honest trades from more pairs re-anchor the reference (got %d)" % int(e.state().ref.get(key, 0)))
	trade.call(3, 5, 5, 11, T0 + 300)
	_expect(int(e.state().ref[key]) == 10, "and the poisoned trades are now the outliers")
	trade.call(1, 2, 1, 12, T0 + 86400 + 600)
	var rows: Array = e.state().ref_trades[key]
	_expect(int(rows.back()[3]) == 1, "pair trades older than 24 h no longer count, even before the hourly prune")
	# Re-anchoring needs most trades and most units: three 1-unit trades far below the band
	# do not outvote 21 units traded inside it (by count alone they would, and drag it to 10).
	# The 100-unit outlier in _test_history_and_reference covers the other side.
	var stone := "item:stone"
	var deal := func (seller: int, buyer: int, count: int, unit: int, ts: int) -> void:
		var lid := _list(e, seller, _deposit(e, seller, "stone", count, 1, ts), unit, -1, ts)
		_ok(e, "market.buy", buyer, {"listing_id": lid, "count": count}, ts)
	var t := T0 + 2 * 86400
	deal.call(1, 2, 10, 10, t)
	deal.call(3, 4, 11, 20, t + 60)
	_expect(int(e.state().ref[stone]) == 20, "two in-band trades set the reference (got %d)" % int(e.state().ref.get(stone, 0)))
	deal.call(5, 6, 1, 1, t + 120)
	deal.call(7, 8, 1, 1, t + 180)
	deal.call(1, 3, 1, 1, t + 240)
	_expect(int(e.state().ref[stone]) == 20, "many tiny outliers do not re-anchor the reference (got %d)" % int(e.state().ref.get(stone, 0)))
	return true

## Withdrawals and inbox.take hand out what the server no longer holds, so a repeated rid must
## get the original body back after a snapshot and restart, and after any amount of traffic.
func _test_rid_bodies() -> bool:
	var dir := DIR + "/rid"
	_wipe(dir)
	var store := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	store.snapshot_every_ops = 0
	_expect(store.open() == "", "rid store opens")
	for id in [1, 2]:
		store.apply("account.ensure", id, {"name": "Player %d" % id}, T0)
	var uid := str(store.apply("vault.deposit_item", 1, {"slot_dict": _stack("stone", 10), "rid": "d1"}, T0).r.uid)
	var pid := str(store.apply("vault.deposit_pet", 1, {"pet_dict": _pet("velociraptor", 2, 3), "rid": "d2"}, T0).r.uid)
	var wood := str(store.apply("vault.deposit_item", 1, {"slot_dict": _stack("wood_log", 5), "rid": "d3"}, T0).r.uid)
	var lid := str(store.apply("market.list_fixed", 1, {"asset": {"uid": wood}, "unit_price": 4, "duration_h": 24, "rid": "d4"}, T0).r.listing.id)
	store.apply("market.buy", 2, {"listing_id": lid, "count": 1, "rid": "b1"}, T0)
	var calls := [
		["vault.withdraw_item", {"uid": uid, "rid": "w1"}],
		["vault.withdraw_pet", {"uid": pid, "rid": "w2"}],
		["inbox.take", {"rid": "t1"}],
	]
	var first := []
	for c in calls:
		first.append(store.apply(c[0], 1, c[1], T0))
	_expect(first[0].ok and int(first[0].r.item.count) == 10 and first[1].ok and first[2].r.events.size() == 1, "withdrawals and a take succeed: %s" % str(first[2]))
	_expect(store.snapshot() == "", "rid snapshot succeeds")
	store.close()
	var boot := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	boot.snapshot_every_ops = 0
	_expect(boot.open() == "", "rid store reopens from the snapshot")
	var seq := boot.engine.seq()
	for i in calls.size():
		var again := boot.apply(calls[i][0], 1, calls[i][1], T0 + 60)
		_expect(again.ok and Ledger.canon(Ledger.norm(again)) == Ledger.canon(Ledger.norm(first[i])), "%s repeated after a snapshot and restart returns the original body, got %s" % [calls[i][0], str(again)])
	_expect(boot.engine.seq() == seq and boot.engine.L.acct(1).vault_items.is_empty() and boot.engine.L.acct(1).vault_pets.is_empty(), "and applies nothing")
	boot.close()
	_wipe(dir)
	var e := _engine(null, 2)
	var part := _deposit(e, 1, "stone", 10)
	var took := e.apply("vault.withdraw_item", 1, {"uid": part, "count": 4, "rid": "w"}, T0)
	for i in e.rules.num("rid_responses_kept") + 1:
		e.apply("wallet.spend", 2, {"reason": "travel", "amount": 5, "rid": "s%d" % i}, T0)
	var later := e.apply("vault.withdraw_item", 1, {"uid": part, "count": 4, "rid": "w"}, T0)
	_expect(Ledger.canon(Ledger.norm(later)) == Ledger.canon(Ledger.norm(took)), "a withdraw repeated after %d other writes returns the original item, got %s" % [e.rules.num("rid_responses_kept") + 1, str(later)])
	_expect(int(e.L.acct(1).vault_items[part].count) == 6, "and withdraws nothing more")
	_expect(EconInvariants.check(e.state()).is_empty(), "the cached bodies do not count as held assets")
	return true

## max_vault_items / max_vault_pets bound every op that adds an asset, not just deposits.
## Assets already in escrow (auction wins, returns) still deliver: nothing is ever refused late.
func _test_vault_caps() -> bool:
	var r := _rules()
	r.limits.max_vault_items = 3
	r.limits.max_vault_pets = 1
	var e := _engine(r, 3)
	var lid := _list(e, 1, _deposit(e, 1, "stone", 20), 2)
	var bought := 0
	for i in 10:
		if _op(e, "market.buy", 2, {"listing_id": lid, "count": 1}).ok:
			bought += 1
	_expect(bought == 3 and e.L.acct(2).vault_items.size() == 3, "ten 1-unit buys into a 3-stack vault stop at 3 (bought %d)" % bought)
	_err(e, "market.buy", 2, {"listing_id": lid, "count": 1}, "limit_reached", T0, "buy into a full vault")
	var a1 := _auction(e, 1, _deposit(e, 1, "wood_log", 2), 10, 100)
	var a2 := _auction(e, 1, _deposit(e, 1, "fibre_stalk", 1), 10)
	_err(e, "market.bid", 2, {"listing_id": a1, "amount": 10}, "limit_reached", T0, "bid with a full vault")
	_err(e, "market.buyout", 2, {"listing_id": a1}, "limit_reached", T0, "buyout into a full vault")
	_err(e, "market.order_create", 2, {"def_id": "stone", "qty": 5, "unit_price": 1, "duration_h": 24}, "limit_reached", T0, "order with a full vault")
	_ok(e, "vault.withdraw_item", 2, {"uid": e.L.acct(2).vault_items.keys()[0]})
	_ok(e, "market.bid", 2, {"listing_id": a1, "amount": 10})
	_err(e, "market.bid", 2, {"listing_id": a2, "amount": 10}, "limit_reached", T0, "a leading bid holds the last slot")
	_ok(e, "market.bid", 2, {"listing_id": a1, "amount": 20})
	_deposit(e, 2, "copper_ore", 1)
	_ok(e, "sys.tick", 0, {}, T0 + 25 * 3600)
	_expect(e.state().closed_listings[a1].state == "sold" and e.L.acct(2).vault_items.size() == 4, "an auction won into a vault filled since still delivers (4 of 3)")
	var t := T0 + 26 * 3600
	var oid := _order(e, 3, "stone", 10, 2, 1, 60, 24, t)
	var units := _deposit(e, 1, "stone", 10, 1, t)
	for i in 3:
		_ok(e, "market.sell_to_order", 1, {"order_id": oid, "uid": units, "count": 1}, t)
	_err(e, "market.sell_to_order", 1, {"order_id": oid, "uid": units, "count": 1}, "limit_reached", t, "a fill into the buyer's full vault")
	var pl := _list(e, 1, str(_ok(e, "vault.deposit_pet", 1, {"pet_dict": _pet("velociraptor", 1, 5)}, t).uid), 10, -1, t)
	_ok(e, "vault.deposit_pet", 2, {"pet_dict": _pet("compsognathus", 1, 6)}, t)
	_err(e, "market.buy", 2, {"listing_id": pl}, "limit_reached", t, "pet bought into a full pet vault")
	return true

## Through the store, time never runs backwards, even across failed and read-only ops.
func _test_clock() -> bool:
	var dir := DIR + "/clock"
	_wipe(dir)
	var store := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	store.snapshot_every_ops = 0
	_expect(store.open() == "", "clock store opens")
	for id in [1, 2]:
		store.apply("account.ensure", id, {"name": "Player %d" % id}, T0)
	var uid := str(store.apply("vault.deposit_item", 1, {"slot_dict": _stack("stone", 5), "rid": "c1"}, T0).r.uid)
	var short := str(store.apply("market.list_fixed", 1, {"asset": {"uid": uid, "count": 2}, "unit_price": 3, "duration_h": 12, "rid": "c2"}, T0).r.listing.id)
	var long := str(store.apply("market.list_fixed", 1, {"asset": {"uid": uid, "count": 2}, "unit_price": 3, "duration_h": 24, "rid": "c3"}, T0).r.listing.id)
	var end_short := T0 + 12 * 3600
	var late: Dictionary = store.apply("market.buy", 2, {"listing_id": short, "count": 1, "rid": "c4"}, end_short + 5)
	_expect(not late.ok and late.err == "expired", "a buy after the end is refused: %s" % str(late))
	var back: Dictionary = store.apply("market.buy", 2, {"listing_id": short, "count": 1, "rid": "c5"}, end_short - 30)
	_expect(not back.ok and back.err == "expired", "a clock stepped back after a refusal cannot reopen the listing: %s" % str(back))
	var end_long := T0 + 24 * 3600
	_expect(store.apply("market.search", 2, {}, end_long + 5).ok, "a read at the later time")
	back = store.apply("market.buy", 2, {"listing_id": long, "count": 1, "rid": "c6"}, end_long - 30)
	_expect(not back.ok and back.err == "expired", "a clock stepped back after a read cannot reopen the listing: %s" % str(back))
	store.close()
	_wipe(dir)
	return true

func _test_market_views() -> bool:
	var r := _rules()
	r.market.inbox_max = 2
	var e := _engine(r)
	var aid := _auction(e, 1, _deposit(e, 1, "copper_ore", 2), 10, 0, 12)
	_ok(e, "market.bid", 2, {"listing_id": aid, "amount": 10})
	var seen: Dictionary = _ok(e, "market.search", 3, {"kind": "auction"}).results[0]
	_expect(not seen.has("bidder") and seen.has_bid == true and seen.my_bid == false, "search does not name the bidder")
	_expect(_ok(e, "market.search", 2, {"kind": "auction"}).results[0].my_bid == true, "but tells the bidder the bid is theirs")
	_expect(_ok(e, "market.mine", 2).bids[0].my_bid == true, "market.mine lists my bids")
	var ends := int(e.state().listings[aid].ends)
	_ok(e, "market.bid", 3, {"listing_id": aid, "amount": 20}, ends - 60)
	_expect(int(e.state().listings[aid].ext) == 0 and int(e.state().listings[aid].ends) == ends, "a bid with exactly 60 s left neither moves the end nor spends an extension")
	_ok(e, "market.bid", 2, {"listing_id": aid, "amount": 40}, ends - 59)
	_expect(int(e.state().listings[aid].ext) == 1 and int(e.state().listings[aid].ends) == ends + 1, "a second later it extends")
	_events(e, 1)
	for i in 3:
		_ok(e, "market.buy", 4, {"listing_id": _list(e, 1, _deposit(e, 1, "stone", 1), 5)})
	var box := _ok(e, "inbox.take", 1)
	_expect(box.events.size() == 2 and int(box.dropped) == 1, "inbox.take says how many events overflowed inbox_max")
	_expect(int(_ok(e, "inbox.take", 1).dropped) == 0, "and resets the count")
	var tape: Dictionary = _ok(e, "market.trades", 3, {"def_id": "stone"}).trades[0]
	_expect(not tape.has("buyer") and not tape.has("seller") and _ok(e, "market.mine", 4).trades[0].has("buyer"), "the public tape names no accounts; my own trades do")
	for i in 5:
		_ok(e, "market.cancel", 4, {"listing_id": _list(e, 4, _deposit(e, 4, "stone", 1), 5)})
	var p1 := _ok(e, "market.mine", 4, {"page_size": 2})
	var p3 := _ok(e, "market.mine", 4, {"page_size": 2, "page": 3})
	_expect(p1.closed_listings.size() == 2 and int(p1.closed_total.listings) == 5 and p3.closed_listings.size() == 1, "market.mine pages closed listings")
	_expect(Ledger.id_num(p1.closed_listings[0].id) > Ledger.id_num(p1.closed_listings[1].id), "newest first")
	_err(e, "market.mine", 4, {"page_size": 500}, "bad_request", T0, "page_size over the cap")
	return true

## A deterministic scenario touching every mutating op, run through an EconStore.
func _scenario(store: EconStore) -> void:
	var t := T0
	for id in [1, 2, 3]:
		store.apply("account.ensure", id, {"name": "Journal %d" % id}, t)
	var dep := store.apply("vault.deposit_item", 1, {"slot_dict": _stack("stone", 20, 4), "rid": "a"}, t)
	var uid := str(dep.r.uid)
	var pet := store.apply("vault.deposit_pet", 2, {"pet_dict": _pet("velociraptor", 4, 31), "rid": "b"}, t)
	var lid := str(store.apply("market.list_fixed", 1, {"asset": {"uid": uid, "count": 8}, "unit_price": 7, "duration_h": 12, "rid": "c"}, t + 10).r.listing.id)
	store.apply("market.buy", 2, {"listing_id": lid, "count": 3, "rid": "d"}, t + 20)
	var aid := str(store.apply("market.list_auction", 2, {"asset": {"uid": pet.r.uid}, "start_bid": 300, "buyout": 900, "duration_h": 12, "rid": "e"}, t + 30).r.listing.id)
	store.apply("market.bid", 1, {"listing_id": aid, "amount": 300, "rid": "f"}, t + 40)
	store.apply("market.bid", 3, {"listing_id": aid, "amount": 400, "rid": "g"}, t + 50)
	var oid := str(store.apply("market.order_create", 3, {"def_id": "stone", "min_level": 1, "qty": 6, "unit_price": 6, "duration_h": 24, "rid": "h"}, t + 60).r.order.id)
	store.apply("market.sell_to_order", 1, {"order_id": oid, "uid": uid, "count": 4, "rid": "i"}, t + 70)
	store.apply("wallet.spend", 2, {"reason": "travel", "amount": 5, "rid": "j"}, t + 80)
	store.apply("objective.claim", 2, {"index": 4, "rid": "k"}, t + 90)
	store.apply("vault.withdraw_item", 1, {"uid": uid, "count": 2, "rid": "l"}, t + 100)
	store.apply("market.search", 2, {"q": "stone"}, t + 110)
	store.apply("sys.tick", 0, {}, t + 12 * 3600)
	store.apply("inbox.take", 1, {"rid": "m"}, t + 12 * 3600 + 5)
	store.apply("market.order_cancel", 3, {"order_id": oid, "rid": "n"}, t + 12 * 3600 + 10)
	store.apply("vault.deposit_item", 3, {"slot_dict": JSON.parse_string(JSON.stringify(_stack("stone_knife", 1, 9))), "rid": "o"}, t + 12 * 3600 + 20)

func _wipe(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var da := DirAccess.open(dir)
	if da:
		for f in da.get_files():
			da.remove(f)

func _test_journal_replay() -> bool:
	var dir := DIR + "/journal"
	_wipe(dir)
	var store := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	store.snapshot_every_ops = 0
	_expect(store.open() == "", "an empty store opens")
	_scenario(store)
	var live := store.engine.state_json()
	_expect(EconInvariants.check(store.engine.state()).is_empty(), "scenario keeps the books balanced")
	store.close()
	var refused := store.apply("wallet.spend", 1, {"reason": "travel", "amount": 5, "rid": "closed"}, T0 + 13 * 3600)
	_expect(refused.get("err") == "server_error" and store.engine.state_json() == live, "a closed store refuses ops with server_error and changes nothing")
	var fresh := MarketEngine.new(_rules(), cat)
	var why := EconStore.new(fresh, dir).replay_file(dir + "/journal.jsonl")
	_expect(why == "" and fresh.state_json() == live, "journal replay from empty reproduces the state byte for byte (%s %s)" % [why, _same(store.engine, fresh)])
	var f := FileAccess.open(dir + "/journal.jsonl", FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("{\"seq\": 9999, \"ts\": 17")
	f.close()
	var reboot := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	reboot.snapshot_every_ops = 0
	_expect(reboot.open() == "" and reboot.engine.state_json() == live, "a torn final journal line is discarded")
	_expect(not FileAccess.get_file_as_string(dir + "/journal.jsonl").contains("9999"), "the torn bytes are cut from the file")
	var res := reboot.apply("wallet.spend", 1, {"reason": "travel", "amount": 5, "rid": "after-torn"}, T0 + 13 * 3600)
	_expect(res.ok, "the store keeps journaling after a torn line")
	var after := reboot.engine.state_json()
	reboot.close()
	var again := MarketEngine.new(_rules(), cat)
	_expect(EconStore.new(again, dir).replay_file(dir + "/journal.jsonl") == "" and again.state_json() == after, "replay after the repair still matches")
	var lines := FileAccess.get_file_as_string(dir + "/journal.jsonl").split("\n")
	lines[2] = "{broken"
	var w := FileAccess.open(dir + "/journal.jsonl", FileAccess.WRITE)
	w.store_string("\n".join(lines))
	w.close()
	_expect(EconStore.new(MarketEngine.new(_rules(), cat), dir).open() != "", "a corrupt line before the end stops boot")
	_wipe(dir)
	return true

func _test_snapshots() -> bool:
	var dir := DIR + "/snapshot"
	_wipe(dir)
	var store := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	store.snapshot_every_ops = 7
	_expect(store.open() == "", "store opens")
	_scenario(store)
	var live := store.engine.state_json()
	var seq := store.engine.seq()
	store.close()
	_expect(FileAccess.file_exists(dir + "/snapshot.json") and not FileAccess.file_exists(dir + "/snapshot.json.tmp"), "the snapshot is renamed into place")
	var journal_rows := FileAccess.get_file_as_string(dir + "/journal.jsonl").strip_edges().split("\n", false).size()
	_expect(journal_rows < 7 and journal_rows < seq, "the journal is truncated after a snapshot")
	var reboot := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	_expect(reboot.open() == "" and reboot.engine.state_json() == live, "snapshot + journal tail reproduce the state byte for byte")
	_expect(reboot.snapshot() == "", "a manual snapshot succeeds")
	reboot.close()
	var cold := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	_expect(cold.open() == "" and cold.engine.state_json() == live and FileAccess.get_file_as_string(dir + "/journal.jsonl") == "", "a snapshot alone boots to the same state")
	cold.close()
	_wipe(dir)
	return true

func _spend(store: EconStore, who: int, rid: String) -> bool:
	return bool(store.apply("wallet.spend", who, {"reason": "travel", "amount": 5, "rid": rid}, T0 + 13 * 3600).ok)

## A crash can cut only the newline off the last line. That line is a whole op and stays; its
## newline must come back, or the next append would fuse two ops into one corrupt line.
func _test_torn_newline() -> bool:
	var dir := DIR + "/newline"
	_wipe(dir)
	var store := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	store.snapshot_every_ops = 0
	_expect(store.open() == "", "store opens")
	_scenario(store)
	var live := store.engine.state_json()
	store.close()
	var path := store.journal_path()
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	f.resize(f.get_length() - 1)
	f.close()
	var boot := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	boot.snapshot_every_ops = 0
	_expect(boot.open() == "" and boot.engine.state_json() == live, "a last line missing only its newline is kept")
	_expect(FileAccess.get_file_as_string(path).ends_with("}\n"), "and its newline is restored")
	_expect(_spend(boot, 1, "nl-1") and _spend(boot, 2, "nl-2"), "two more ops are acknowledged")
	var after := boot.engine.state_json()
	boot.close()
	var again := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	_expect(again.open() == "" and again.engine.state_json() == after, "the second reboot keeps every acknowledged op")
	again.close()
	_wipe(dir)
	return true

func _test_snapshot_failures() -> bool:
	var dir := DIR + "/snapfail"
	_wipe(dir)
	var store := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	store.snapshot_every_ops = 7
	_expect(store.open() == "", "store opens")
	_scenario(store)
	_expect(FileAccess.file_exists(store.snapshot_path(true)) and FileAccess.file_exists(store.journal_path(true)), "a second snapshot keeps the generation before it")
	# A snapshot that cannot be written must not cost the old snapshot or the journal.
	var tmp := store.snapshot_path() + ".tmp"
	DirAccess.make_dir_absolute(tmp)
	_expect(store.snapshot() != "" and store.broken == "", "a failed snapshot write is reported and the store keeps serving")
	DirAccess.remove_absolute(tmp)
	_expect(_spend(store, 1, "sf-1"), "ops still journal after a failed snapshot")
	var live := store.engine.state_json()
	store.close()
	var boot := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	_expect(boot.open() == "" and boot.engine.state_json() == live, "nothing was lost to the failed snapshot")
	boot.close()
	# A snapshot that never fully reached the disk boots from the generation before.
	var text := FileAccess.get_file_as_string(store.snapshot_path())
	var w := FileAccess.open(store.snapshot_path(), FileAccess.WRITE)
	w.store_string(text.substr(0, text.length() / 2))
	w.close()
	var fallback := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	fallback.snapshot_every_ops = 0
	_expect(fallback.open() == "" and fallback.engine.state_json() == live, "a torn snapshot.json boots from snapshot.prev.json and both journals")
	_expect(FileAccess.file_exists(dir + "/snapshot.bad.json") and not FileAccess.file_exists(store.snapshot_path()), "the bad snapshot is set aside")
	_expect(fallback.snapshot() == "", "the next snapshot succeeds")
	fallback.close()
	var cold := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	_expect(cold.open() == "" and cold.engine.state_json() == live, "and boots to the same state")
	_expect(_spend(cold, 1, "sf-2"), "an op after the post-fallback snapshot")
	var live2 := cold.engine.state_json()
	cold.close()
	# snapshot.prev.json is still the generation before the bad one, so journal.prev must still
	# bridge it: a second bad snapshot.json must boot, not stop on a seq gap.
	text = FileAccess.get_file_as_string(store.snapshot_path())
	w = FileAccess.open(store.snapshot_path(), FileAccess.WRITE)
	w.store_string(text.substr(0, text.length() / 2))
	w.close()
	var second := EconStore.new(MarketEngine.new(_rules(), cat), dir)
	var why := second.open()
	_expect(why == "" and second.engine.state_json() == live2, "a bad snapshot after a fallback boot still boots from snapshot.prev and the journals (%s)" % why)
	second.close()
	for prev in [false, true]:
		var bad := FileAccess.open(store.snapshot_path(prev), FileAccess.WRITE)
		bad.store_string("{")
		bad.close()
	_expect(EconStore.new(MarketEngine.new(_rules(), cat), dir).open().begins_with("no readable snapshot"), "two unreadable snapshots stop boot instead of starting empty")
	var old := FileAccess.open(store.snapshot_path(), FileAccess.WRITE)
	old.store_string('{"v": 1, "seq": 0}')
	old.close()
	_expect(EconStore.new(MarketEngine.new(_rules(), cat), dir).open().contains("version"), "a snapshot from another state version stops boot")
	_wipe(dir)
	return true

## wallet.spend with args.boom writes to the books, then hits an internal error part-way.
class FaultyEngine extends MarketEngine:
	func _init(r: EconRules, c: EconCatalog) -> void:
		super(r, c)

	func _dispatch(op: String, me: int, a: EconArgs) -> Dictionary:
		if op == "wallet.spend" and a.has("boom"):
			L.acct(me).wallet += 1000
			if str(a.a.boom) == "debit":
				L.debit(me, 1 << 40)
			else:
				var hostile: Variant = {}
				if bool(hostile):
					pass
		return super._dispatch(op, me, a)

func _test_fault_reload() -> bool:
	var dir := DIR + "/fault"
	_wipe(dir)
	var store := EconStore.new(FaultyEngine.new(_rules(), cat), dir)
	store.snapshot_every_ops = 0
	_expect(store.open() == "", "fault store opens")
	_scenario(store)
	print("[econ] fault test: the next SCRIPT ERROR and ERROR lines are deliberate")
	for kind in ["script", "debit"]:
		var before := store.engine.state_json()
		var res := store.apply("wallet.spend", 1, {"reason": "travel", "amount": 5, "boom": kind, "rid": "boom-" + kind}, T0 + 13 * 3600)
		_expect(not res.ok and res.err == "server_error", "an op that errors part-way returns server_error (%s): %s" % [kind, str(res)])
		_expect(store.engine.state_json() == before and store.broken == "", "and memory reloads from disk without it (%s)" % kind)
	_expect(_spend(store, 1, "boom-script"), "the store keeps serving, and the faulted rid was never cached")
	var live := store.engine.state_json()
	store.close()
	var fresh := MarketEngine.new(_rules(), cat)
	_expect(EconStore.new(fresh, dir).replay_file(store.journal_path()) == "" and fresh.state_json() == live, "the journal never saw the faulted ops")
	var e := FaultyEngine.new(_rules(), cat)
	e.apply("account.ensure", 1, {"name": "Solo"}, T0)
	var r := e.apply("wallet.spend", 1, {"reason": "travel", "amount": 5, "boom": "script", "rid": "x"}, T0)
	_expect(r.err == "server_error" and e.fault != "", "a bare engine flags the fault for its owner")
	_wipe(dir)
	return true

func _test_fuzz() -> bool:
	var rules := _rules(false)
	rules.market.starting_wallet = 400
	rules.market.settlers.daily_budget = 2000
	var dir := DIR + "/fuzz"
	_wipe(dir)
	var store := EconStore.new(MarketEngine.new(rules, cat), dir)
	store.snapshot_every_ops = 0
	_expect(store.open() == "", "fuzz store opens")
	var e := store.engine
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261018
	var pets: Array = []
	for i in 8:
		pets.append(_pet(FUZZ_PETS[i % FUZZ_PETS.size()], 1 + i % 4, 100 + i))
	for id in range(1, 7):
		store.apply("account.ensure", id, {"name": "Fuzz %d" % id}, T0)
	var ts := T0
	var tally := {}
	var last_write := {}
	var broken := false
	for i in 3000:
		ts += rng.randi_range(0, 600)
		if rng.randf() < 0.02:
			ts += rng.randi_range(3600, 30 * 3600)
		var who := rng.randi_range(1, 6)
		var pick := _fuzz_op(e, rng, who, pets)
		var op: String = pick[0]
		var args: Dictionary = pick[1]
		var dup := false
		if op in MarketEngine.WRITE or op in MarketEngine.BRIDGE:
			if rng.randf() < 0.04 and last_write.has(who):
				op = last_write[who][0]
				args = last_write[who][1]
				dup = e.L.acct(who).rid_cache.has(str(args.rid)) # a rid idle for a day applies again
			else:
				args.rid = "f%d" % i
		var before := e.state_json()
		var seq := e.seq()
		var res := store.apply(op, 0 if op == "sys.tick" else who, args, ts)
		var bad := EconInvariants.check(e.state())
		if res.get("err") == "server_error" or store.broken != "":
			bad.append("internal error: %s" % str(res.get("msg", store.broken)))
		if not bad.is_empty():
			_expect(false, "fuzz op %d %s broke invariants: %s" % [i, op, str(bad)])
			broken = true
			break
		if (not res.ok or op in MarketEngine.READ or dup) and e.state_json() != before:
			_expect(false, "fuzz op %d %s changed state although it %s" % [i, op, "failed" if not res.ok else ("repeated a rid" if dup else "is read-only")])
			broken = true
			break
		if dup and seq != e.seq():
			_expect(false, "fuzz op %d: a repeated rid applied twice" % i)
		if res.ok and (op in MarketEngine.WRITE or op in MarketEngine.BRIDGE) and not dup and e.seq() != seq:
			last_write[who] = [op, args]
		var row: Array = tally.get(op, [0, 0])
		row[0 if res.ok else 1] += 1
		tally[op] = row
	store.close()
	var parts: PackedStringArray = []
	for op in tally:
		parts.append("%s %d/%d" % [op.get_slice(".", 1), tally[op][0], tally[op][0] + tally[op][1]])
	print("[econ] fuzz 3000 ops over 6 accounts, invariants after every op: %s" % ", ".join(parts))
	for op in ["vault.deposit_item", "market.list_fixed", "market.list_auction", "market.buy", "market.bid", "market.sell_to_order", "market.cancel", "vault.withdraw_item", "sys.tick"]:
		_expect(int(tally.get(op, [0, 0])[0]) > 0, "fuzz exercised a successful %s" % op)
	if broken:
		return true
	var fresh := MarketEngine.new(rules, cat)
	var why := EconStore.new(fresh, dir).replay_file(dir + "/journal.jsonl")
	_expect(why == "" and fresh.state_json() == e.state_json(), "the fuzz journal replays from empty byte for byte (%s)" % why)
	_wipe(dir)
	return true

static func _any(rng: RandomNumberGenerator, pool: Array, fallback: String) -> String:
	if pool.is_empty() or rng.randf() < 0.05:
		return fallback
	return str(pool[rng.randi_range(0, pool.size() - 1)])

func _fuzz_op(e: MarketEngine, rng: RandomNumberGenerator, who: int, pets: Array) -> Array:
	var acct := e.L.acct(who)
	var items: Array = acct.vault_items.keys()
	var mine: Array = items + acct.vault_pets.keys()
	var listings: Array = e.state().listings.keys()
	var orders: Array = e.state().orders.keys()
	var durations := [12, 24, 48, 72, 5]
	var roll := rng.randi_range(0, 99)
	if roll < 14:
		var def: String = FUZZ_DEFS[rng.randi_range(0, FUZZ_DEFS.size() - 1)]
		var n := 1 if def == "stone_knife" else rng.randi_range(1, 40)
		var slot := _stack(def, n, rng.randi_range(1, 12))
		if rng.randf() < 0.06:
			slot.flags = ["locked"]
		if rng.randf() < 0.04:
			slot.level = 99
		if rng.randf() < 0.05:
			slot[_any(rng, slot.keys(), "def_id")] = HOSTILE[rng.randi_range(0, HOSTILE.size() - 1)]
		return ["vault.deposit_item", {"slot_dict": slot}]
	if roll < 17:
		var pet := _stamp(Provenance.strip(pets[rng.randi_range(0, pets.size() - 1)]), "p", "tame") # each deposit is another animal
		if rng.randf() < 0.05 and not acct.vault_pets.is_empty():
			pet = (acct.vault_pets.values()[0] as Dictionary).duplicate(true) # one already held: a dupe attempt
		if rng.randf() < 0.15:
			pet[_any(rng, pet.keys(), "summoned")] = HOSTILE[rng.randi_range(0, HOSTILE.size() - 1)]
		return ["vault.deposit_pet", {"pet_dict": pet}]
	if roll < 21:
		return ["vault.withdraw_item", {"uid": _any(rng, items, "i1"), "count": rng.randi_range(1, 20)}]
	if roll < 22:
		return ["vault.withdraw_pet", {"uid": _any(rng, acct.vault_pets.keys(), "p1")}]
	if roll < 32:
		return ["market.list_fixed", {"asset": {"uid": _any(rng, mine, "i1"), "count": rng.randi_range(1, 8)}, "unit_price": rng.randi_range(1, 40), "duration_h": durations[rng.randi_range(0, 4)]}]
	if roll < 38:
		return ["market.list_auction", {"asset": {"uid": _any(rng, mine, "i1")}, "start_bid": rng.randi_range(1, 60), "buyout": [0, rng.randi_range(1, 150)][rng.randi_range(0, 1)], "duration_h": durations[rng.randi_range(0, 3)]}]
	if roll < 48:
		return ["market.buy", {"listing_id": _any(rng, listings, "L1"), "count": rng.randi_range(1, 4)}]
	if roll < 56:
		var lid := _any(rng, listings, "L1")
		var price := MarketBook.price_of(e.state().listings[lid]) if e.state().listings.has(lid) else 1
		return ["market.bid", {"listing_id": lid, "amount": price + rng.randi_range(-2, 12)}]
	if roll < 58:
		return ["market.buyout", {"listing_id": _any(rng, listings, "L1")}]
	if roll < 62:
		var own := listings.filter(func (id: String) -> bool: return int(e.state().listings[id].seller) == who)
		return ["market.cancel", {"listing_id": _any(rng, own if rng.randf() < 0.7 else listings, "L1")}]
	if roll < 67:
		var lo := rng.randi_range(1, 6)
		return ["market.order_create", {"def_id": FUZZ_DEFS[rng.randi_range(0, FUZZ_DEFS.size() - 1)], "min_level": lo, "max_level": rng.randi_range(lo - 1, 60), "qty": rng.randi_range(1, 15), "unit_price": rng.randi_range(1, 12), "duration_h": durations[rng.randi_range(0, 4)]}]
	if roll < 69:
		var own := orders.filter(func (id: String) -> bool: return int(e.state().orders[id].buyer) == who)
		return ["market.order_cancel", {"order_id": _any(rng, own if rng.randf() < 0.7 else orders, "O1")}]
	if roll < 77:
		var oid := _any(rng, orders, "O1")
		var uid := _any(rng, items, "i1")
		if e.state().orders.has(oid) and rng.randf() < 0.8:
			for u in items: # usually offer a stack the order accepts, so fills actually happen
				if OrderBook.accepts(e.state().orders[oid], acct.vault_items[u]):
					uid = u
					break
		return ["market.sell_to_order", {"order_id": oid, "uid": uid, "count": rng.randi_range(1, 8)}]
	if roll < 79:
		return ["inbox.take", {}]
	if roll < 80:
		return ["wallet.spend", {"reason": "travel", "amount": 5}]
	if roll < 81:
		return ["objective.claim", {"index": rng.randi_range(0, 30)}]
	if roll < 88:
		return ["sys.tick", {}]
	var reads := [
		["market.search", {"sort": MarketQuery.SORTS[rng.randi_range(0, 4)], "asset": ["any", "item", "pet"][rng.randi_range(0, 2)], "page_size": 10}],
		["market.orders", {}], ["market.item_detail", {"def_id": "stone"}], ["market.trades", {"def_id": "stone"}],
		["market.mine", {}], ["wallet.get", {}], ["vault.get", {}],
	]
	return reads[rng.randi_range(0, reads.size() - 1)]

func _test_search_perf() -> bool:
	var r := _rules()
	r.market.starting_wallet = 1000000000
	r.limits.max_open_listings = 1000000
	r.limits.max_vault_items = 1000000
	r.limits.deposit_caps = {}
	r.limits.category_caps = {}
	r.limits.deposit_default_cap = 1000000000
	var e := MarketEngine.new(r, cat)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var made := 0
	for who in range(1, 21):
		e.apply("account.ensure", who, {}, T0)
		var uid := str(e.apply("vault.deposit_item", who, {"slot_dict": _stack("stone", 999), "rid": "d"}, T0).r.uid)
		for k in 500:
			var res := e.apply("market.list_fixed", who, {"asset": {"uid": uid, "count": 1}, "unit_price": rng.randi_range(1, 5000), "duration_h": 72, "rid": "l%d" % k}, T0 + k)
			if res.ok:
				made += 1
	_expect(made == 10000, "perf setup listed 10000 (got %d)" % made)
	var best := 1.0e9
	var first := 0.0
	var res := {}
	for i in 3:
		var t0 := Time.get_ticks_usec()
		res = e.apply("market.search", 1, {"sort": "price_asc", "page": 1, "page_size": 50}, T0 + 600)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		first = ms if i == 0 else first
		best = minf(best, ms)
	var t1 := Time.get_ticks_usec()
	var q := e.apply("market.search", 1, {"q": "stone", "sort": "newest", "page_size": 50}, T0 + 600)
	var q_ms := float(Time.get_ticks_usec() - t1) / 1000.0
	print("[econ] search over %d active listings: page 1 in %.1f ms first call, %.1f ms best of 3; q+newest in %.1f ms" % [made, first, best, q_ms])
	_expect(res.ok and int(res.r.total) == 10000 and res.r.results.size() == 50, "perf search returns page 1")
	_expect(first < 50.0 and best < 50.0, "search page 1 over 10000 listings under 50 ms (first %.1f ms, best %.1f ms)" % [first, best])
	# Scale probe: every account here made 500 heavy writes; its persisted rid cache must stay
	# a few bytes per entry (it held full listing responses once, about 56 KB per account).
	var rid_bytes := 0
	for who in range(1, 21):
		rid_bytes = maxi(rid_bytes, JSON.stringify(e.L.acct(who).rid_cache).length())
	var t2 := Time.get_ticks_usec()
	var snap_len := e.state_json().length()
	print("[econ] state with %d listings: %d KB, stringified in %.0f ms; largest rid cache %d bytes" % [made, snap_len / 1024, float(Time.get_ticks_usec() - t2) / 1000.0, rid_bytes])
	_expect(rid_bytes < 64 * 40, "a full rid cache persists in under 2.5 KB (%d bytes)" % rid_bytes)
	# Scale probe: the whole snapshot (stringify, write, read back, compare, rotate) runs on the
	# caller's thread every snapshot_every_s; this is the stall a 10,000-listing state costs.
	var sdir := DIR + "/perf"
	_wipe(sdir)
	var snap := EconStore.new(e, sdir)
	var t3 := Time.get_ticks_usec()
	var snap_why := snap.snapshot()
	print("[econ] full snapshot of that state: %.0f ms" % (float(Time.get_ticks_usec() - t3) / 1000.0))
	_expect(snap_why == "", "perf snapshot succeeds (%s)" % snap_why)
	snap.close()
	_wipe(sdir)
	var sorted := true
	for i in range(1, 50):
		if int(res.r.results[i].unit_price) < int(res.r.results[i - 1].unit_price):
			sorted = false
	_expect(sorted and q.ok, "perf results are sorted")
	return true
