class_name MarketEngine
extends RefCounted
## The economy's one entry point: apply(op, account_id, args, ts) -> {ok, r} | {ok:false, err, msg}.
## Pure and deterministic: no nodes, no clock, no randomness. Time is passed in; ids come from
## state. A mutating op validates everything, then writes; a failure changes nothing.
## A mutating success bumps state.seq, which is EconStore's cue to journal it (contract 5).
## Client write ops carry `rid` in args (contract 5.3); a repeat returns the cached response.
## Responses that hand out something the server no longer holds (KEEP_BODY) persist in the
## account's rid_cache, so a repeat after any restart or any amount of traffic still gets them.
## An op that hits an internal error part-way returns server_error and sets `fault`; EconStore
## then rebuilds memory from disk, which never saw the op, so a half-applied op cannot persist.

const READ := ["wallet.get", "vault.get", "market.search", "market.orders", "market.item_detail", "market.trades", "market.mine"]
const WRITE := [
	"wallet.spend", "objective.claim", "market.list_fixed", "market.list_auction", "market.buy",
	"market.bid", "market.buyout", "market.cancel", "market.order_create", "market.order_cancel",
	"market.sell_to_order", "inbox.take",
]
## Vault moves carry a rid like WRITE ops, but only VaultBridge calls them (contract v2 section
## 0.5): a deposit is an asset the character store exported, never a client's dict.
const BRIDGE := ["vault.deposit_item", "vault.deposit_pet", "vault.withdraw_item", "vault.withdraw_pet"]
const SYSTEM := ["account.ensure", "sys.tick", "bridge.begin", "bridge.end", "bridge.settled"] ## called by the server itself, never relayed from a client
const SERVER := ["sys.tick", "bridge.end", "bridge.settled"] ## run as account 0, not as a player
## A withdrawn asset or a taken event exists only in its response; re-reading state cannot recover it.
const KEEP_BODY := ["vault.withdraw_item", "vault.withdraw_pet", "inbox.take"]

var rules: EconRules
var cat: EconCatalog
var L: Ledger
var H: PriceHistory
var V: AssetValidator
var book: MarketBook
var orders: OrderBook
var query: MarketQuery
var settlers: Settlers
var fault := "" ## set when the last op stopped part-way; memory may be ahead of the books
var _responses := {} ## seq -> full response of a recent write not in KEEP_BODY (memory only)
static var _errors: ErrorCount

## Counts engine and script errors, so apply() can tell when an op hit one part-way.
## Errors logged by another thread during an op only cause a needless (safe) reload.
class ErrorCount extends Logger:
	var n := 0
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			n += 1

func _init(p_rules: EconRules, p_catalog: EconCatalog) -> void:
	rules = p_rules
	cat = p_catalog
	if _errors == null:
		_errors = ErrorCount.new()
		OS.add_logger(_errors)
	L = Ledger.new(rules)
	H = PriceHistory.new(L)
	V = AssetValidator.new(cat, rules)
	book = MarketBook.new(L, H)
	orders = OrderBook.new(L, H, cat)
	query = MarketQuery.new(L, H, book, orders, cat)
	settlers = Settlers.new(L, orders, cat)
	reset()

## Empty books holding only the Settlers account; EconStore.reload starts from here too.
func reset() -> void:
	load_state(Ledger.genesis())
	L.now = 0
	L.new_account(Ledger.SETTLERS, str(rules.settler("name")))

## Replaces the whole state (snapshot load). Derived caches are rebuilt lazily.
func load_state(state: Dictionary) -> void:
	L.s = Ledger.norm(state)
	L.events = []
	book.next_due = 0
	orders.next_due = 0
	_responses = {}
	fault = ""

func state() -> Dictionary:
	return L.s

func state_json() -> String:
	return Ledger.canon(L.s)

func seq() -> int:
	return int(L.s.seq)

## Events the last op put in inboxes, as [account_id, event], for the transport to push.
func drain_events() -> Array:
	var out := L.events
	L.events = []
	return out

func apply(op: String, account_id: int, args: Dictionary, ts: int) -> Dictionary:
	L.events = []
	L.touched = {}
	fault = ""
	var write := op in WRITE or op in BRIDGE
	if not (write or op in READ or op in SYSTEM):
		return EconArgs.no("bad_request", "unknown op %s" % op)
	if op in SERVER:
		if account_id != Ledger.SETTLERS:
			return EconArgs.no("unauthorized", "%s is server-only" % op)
	elif op == "account.ensure":
		if account_id < 1:
			return EconArgs.no("bad_request", "account_id must be positive")
	elif account_id < 1 or L.acct(account_id).is_empty():
		return EconArgs.no("unauthorized", "unknown account")
	L.now = maxi(ts, int(L.s.last_ts)) # server time never runs backwards inside the books
	var a := EconArgs.new(args)
	var rid := ""
	if write:
		rid = a.text("rid", 1, 64)
		if a.err != "":
			return a.fail()
		var hit: Array = L.acct(account_id).rid_cache.get(rid, [])
		if not hit.is_empty():
			if str(hit[0]) != op:
				return EconArgs.no("conflict", "rid already used for %s" % str(hit[0]))
			var full: Variant = hit[2] if hit.size() > 2 else _responses.get(int(hit[1]))
			if full != null:
				return (full as Dictionary).duplicate(true)
			# shortcut: a repeat of a non-KEEP_BODY op from before the last restart or older than
			# rid_responses_kept ops gets this marker; everything it did is in state to re-read.
			return {"ok": true, "r": {"duplicate": true, "op": op, "seq": int(hit[1])}}
	var errors := _errors.n
	var got: Variant = _dispatch(op, account_id, a)
	var res: Dictionary = got if got is Dictionary else {}
	if not res.has("ok") or _errors.n != errors:
		L.events = []
		if op not in READ:
			fault = "%s by account %d stopped on an internal error" % [op, account_id]
		return EconArgs.no("server_error", "internal error in %s; nothing was applied" % op)
	var changed := bool(res.ok) and not res.has("noop")
	res.erase("noop")
	if changed and op not in READ:
		var seq := int(L.s.seq) + 1
		L.s.seq = seq
		L.s.last_ts = L.now
		_responses.erase(seq - rules.num("rid_responses_kept"))
		if write:
			_remember(L.acct(account_id), rid, op, seq, res)
	return res

func _dispatch(op: String, me: int, a: EconArgs) -> Dictionary:
	match op:
		"account.ensure": return _ensure(me, a)
		"sys.tick": return _tick()
		"bridge.begin": return _begin(me, a)
		"bridge.end": return _end()
		"bridge.settled": return _settled(a)
		"wallet.get": return EconArgs.ok({"wallet": L.acct(me).wallet, "held": query.held(me)})
		"wallet.spend": return _spend(me, a)
		"objective.claim": return _claim(me, a)
		"vault.get": return _vault(me)
		"vault.deposit_item": return _deposit(me, a, "item")
		"vault.deposit_pet": return _deposit(me, a, "pet")
		"vault.withdraw_item": return _withdraw_item(me, a)
		"vault.withdraw_pet": return _withdraw_pet(me, a)
		"market.list_fixed": return book.list_fixed(me, a)
		"market.list_auction": return book.list_auction(me, a)
		"market.buy": return book.buy(me, a)
		"market.bid": return book.bid(me, a)
		"market.buyout": return book.buyout(me, a)
		"market.cancel": return book.cancel(me, a)
		"market.order_create": return orders.create(me, a)
		"market.order_cancel": return orders.cancel(me, a)
		"market.sell_to_order": return orders.sell(me, a)
		"market.search": return query.search(me, a)
		"market.orders": return query.open_orders(a)
		"market.item_detail": return query.item_detail(a)
		"market.trades": return query.trades(a)
		"market.mine": return query.mine(me, a)
		"inbox.take": return _inbox(me)
	return EconArgs.no("bad_request", "unknown op %s" % op)

## The persisted cache holds rid -> [op, seq] (a few dozen bytes), plus the response for
## KEEP_BODY ops; other bodies stay in memory, since state holds everything they report.
func _remember(acct: Dictionary, rid: String, op: String, seq: int, res: Dictionary) -> void:
	var cache: Dictionary = acct.rid_cache
	if op in KEEP_BODY:
		cache[rid] = [op, seq, Ledger.norm(res.duplicate(true))]
	else:
		cache[rid] = [op, seq]
		_responses[seq] = res.duplicate(true)
	acct.rid_last = L.now
	if cache.size() > rules.num("rid_cache"):
		var oldest := ""
		for k in cache:
			if oldest == "" or int(cache[k][1]) < int(cache[oldest][1]):
				oldest = k
		cache.erase(oldest)

## Forgets the rid caches of accounts with no write for rid_keep_s.
# ASSUMPTION: retries and replayed frames arrive within a day; older repeats apply again.
func _prune_rids() -> void:
	var cut := L.now - rules.num("rid_keep_s")
	for acct: Dictionary in L.s.accounts.values():
		if not (acct.rid_cache as Dictionary).is_empty() and int(acct.rid_last) < cut:
			acct.rid_cache = {}

func _summary(acct: Dictionary) -> Dictionary:
	return {"account_id": acct.id, "name": acct.name, "wallet": acct.wallet, "created": acct.created}

## Called by auth on hello: creates the account with the starting wallet the first time.
func _ensure(me: int, a: EconArgs) -> Dictionary:
	var name := a.text("name", 3, 20, "")
	if a.err != "":
		return a.fail()
	for ch in name:
		if not (ch >= "a" and ch <= "z") and not (ch >= "A" and ch <= "Z") and not (ch >= "0" and ch <= "9") and ch not in [" ", "_", "-"]:
			return EconArgs.no("bad_request", "name may use letters, digits, space, _ and -")
	var acct := L.acct(me)
	if not acct.is_empty():
		return EconArgs.ok(_summary(acct), false)
	acct = L.new_account(me, name if name != "" else "Player%d" % me)
	L.grant_start(me, rules.num("starting_wallet"))
	return EconArgs.ok(_summary(acct))

func _tick() -> Dictionary:
	var settled := book.settle_due()
	var expired := orders.expire_due()
	var refreshed := false
	if L.now / int(rules.settler("refresh_s")) != int(L.s.settlers.hour):
		H.prune()
		_prune_rids()
		book.prune_closed()
		orders.prune_closed()
		refreshed = settlers.tick()
	var changed := settled > 0 or expired > 0 or refreshed
	return EconArgs.ok({"settled": settled, "expired": expired, "settlers": refreshed}, changed)

func _spend(me: int, a: EconArgs) -> Dictionary:
	var reason := a.choice("reason", cat.spend_costs.keys())
	var amount := a.integer("amount", 1, rules.num("max_unit_price"))
	if a.err != "":
		return a.fail()
	# ASSUMPTION: the server does not know where a client sails in v1, so any listed cost is legal.
	if amount not in cat.spend_costs[reason]:
		return EconArgs.no("bad_request", "%s costs %s" % [reason, str(cat.spend_costs[reason])])
	if int(L.acct(me).wallet) < amount:
		return EconArgs.no("insufficient_funds", "needs %d T-stones" % amount)
	L.debit(me, amount)
	L.to_sink(amount)
	return EconArgs.ok({"reason": reason, "spent": amount, "wallet": L.acct(me).wallet})

func _claim(me: int, a: EconArgs) -> Dictionary:
	var index := a.integer("index", 0, cat.objective_rewards.size() - 1)
	if a.err != "":
		return a.fail()
	var acct := L.acct(me)
	if index in acct.claimed_objectives:
		return EconArgs.no("conflict", "objective %d already claimed" % index)
	var reward := cat.objective_rewards[index]
	acct.claimed_objectives.append(index)
	L.mint(me, reward, "objectives")
	return EconArgs.ok({"index": index, "reward": reward, "wallet": acct.wallet})

func _vault(me: int) -> Dictionary:
	var acct := L.acct(me)
	return EconArgs.ok({"items": _sorted_copies(acct.vault_items), "pets": _sorted_copies(acct.vault_pets)})

static func _sorted_copies(vault: Dictionary) -> Array:
	var ids := vault.keys()
	ids.sort_custom(func (x: String, y: String) -> bool: return Ledger.id_num(x) < Ledger.id_num(y))
	var out: Array = []
	for id in ids:
		out.append((vault[id] as Dictionary).duplicate(true))
	return out

## Why vault.deposit_* would refuse `asset` for `me`, or {} (read-only). VaultBridge asks
## first, so act.deposit never takes an asset from a character that the vault would refuse.
func deposit_refusal(me: int, kind: String, asset: Variant) -> Dictionary:
	if not Provenance.is_server(asset):
		return EconArgs.no("invalid_asset", "only assets with server provenance enter the vault")
	var body := Provenance.strip(asset)
	var why := V.pet(body) if kind == "pet" else V.item(body)
	if why != "":
		return EconArgs.no("invalid_asset", why)
	if L.s.src.has(asset.uid) or L.s.retired.has(asset.uid):
		return EconArgs.no("conflict", "%s is already in the economy" % asset.uid)
	if L.vault_full(me, kind):
		var cap := rules.num("max_vault_pets" if kind == "pet" else "max_vault_items")
		return EconArgs.no("limit_reached", "vault holds at most %d %s" % [cap, "pets" if kind == "pet" else "stacks"])
	var acct := L.acct(me)
	if kind == "pet":
		if _deposited(acct, "pet:%s" % body.species) >= rules.num("pet_species_cap") or _deposited(acct, "pets") >= rules.num("pet_daily_cap"):
			return EconArgs.no("limit_reached", "pet deposit cap reached for the next 24 h")
		return {}
	var def_id := str(body.id)
	var cap_left := rules.deposit_cap(def_id, cat.item(def_id).categories) - _deposited(acct, def_id)
	if int(body.count) > cap_left:
		return EconArgs.no("limit_reached", "%s deposit cap: %d more in the next 24 h" % [def_id, maxi(0, cap_left)])
	return {}

## vault.deposit_item {slot_dict} / vault.deposit_pet {pet_dict}: the whole asset act.deposit
## exported, kept byte for byte under its own uid, so a withdrawal hands char.receive the
## exact body it recorded.
func _deposit(me: int, a: EconArgs, kind: String) -> Dictionary:
	var asset: Dictionary = Ledger.norm(a.dict("pet_dict" if kind == "pet" else "slot_dict")) # wire floats -> ints, as stored
	if a.err != "":
		return a.fail()
	var no := deposit_refusal(me, kind, asset)
	if not no.is_empty():
		return no
	var body := asset.duplicate(true)
	var acct := L.acct(me)
	if kind == "pet":
		_log_deposit(acct, "pet:%s" % body.species, 1)
		_log_deposit(acct, "pets", 1)
		L.put_pet(me, body)
		L.s.pets_in = int(L.s.pets_in) + 1
	else:
		_log_deposit(acct, str(body.id), int(body.count))
		L.put_item(me, body)
		L.bump("items_in", str(body.id), int(body.count))
	L.s.src[body.uid] = true
	L.s.inflight = {}
	return EconArgs.ok({"uid": body.uid, kind: body.duplicate(true)})

## bridge.begin {rid}: VaultBridge's mark before act.deposit takes an asset from a character;
## vault.deposit_* (or bridge.end) clears it. Boot reads it to finish or undo that deposit.
func _begin(me: int, a: EconArgs) -> Dictionary:
	var rid := a.text("rid", 1, 64)
	if a.err != "":
		return a.fail()
	L.s.inflight = {"account": me, "rid": rid}
	return EconArgs.ok({})

func _end() -> Dictionary:
	if L.s.inflight.is_empty():
		return EconArgs.ok({}, false)
	L.s.inflight = {}
	return EconArgs.ok({})

## bridge.settled {uids}: the character store dropped these retired exports (char.settled).
func _settled(a: EconArgs) -> Dictionary:
	var uids: Variant = a.a.get("uids")
	if not uids is Array:
		return EconArgs.no("bad_request", "uids must be a list")
	var n := 0
	for uid in uids:
		if L.s.retired.erase(str(uid)):
			n += 1
	return EconArgs.ok({"settled": n}, n > 0)

## Units deposited under `key` within the rolling window (read-only).
func _deposited(acct: Dictionary, key: String) -> int:
	var cut := L.now - rules.num("deposit_window_s")
	var total := 0
	for row in acct.deposits.get(key, []):
		if int(row[0]) > cut:
			total += int(row[1])
	return total

func _log_deposit(acct: Dictionary, key: String, count: int) -> void:
	var cut := L.now - rules.num("deposit_window_s")
	var rows: Array = (acct.deposits.get(key, []) as Array).filter(func (r: Array) -> bool: return int(r[0]) > cut)
	rows.append([L.now, count])
	acct.deposits[key] = rows

func _withdraw_item(me: int, a: EconArgs) -> Dictionary:
	var uid := a.text("uid", 2, 24)
	if a.err != "":
		return a.fail()
	var vault: Dictionary = L.acct(me).vault_items
	if not vault.has(uid):
		return EconArgs.no("not_found", "%s is not in your vault" % uid)
	var count := a.integer("count", 1, 999999, vault[uid].count)
	if a.err != "":
		return a.fail()
	if count > int(vault[uid].count):
		return EconArgs.no("insufficient_items", "stack holds %d" % int(vault[uid].count))
	var part := L.take_item(me, uid, count)
	L.bump("items_out", str(part.id), count)
	L.s.src.erase(part.uid)
	return EconArgs.ok({"item": part.duplicate(true)})

func _withdraw_pet(me: int, a: EconArgs) -> Dictionary:
	var uid := a.text("uid", 2, 24)
	if a.err != "":
		return a.fail()
	if not L.acct(me).vault_pets.has(uid):
		return EconArgs.no("not_found", "%s is not in your vault" % uid)
	var pet := L.take_pet(me, uid)
	L.s.pets_out = int(L.s.pets_out) + 1
	L.s.src.erase(uid)
	return EconArgs.ok({"pet": pet.duplicate(true)})

func _inbox(me: int) -> Dictionary:
	var acct := L.acct(me)
	var events: Array = acct.inbox
	if events.is_empty():
		return EconArgs.ok({"events": [], "dropped": 0}, false)
	var dropped := int(acct.inbox_dropped) ## older events pushed out past inbox_max
	acct.inbox = []
	acct.inbox_dropped = 0
	return EconArgs.ok({"events": events.duplicate(true), "dropped": dropped})
