class_name MarketEngine
extends RefCounted
## The economy's one entry point: apply(op, account_id, args, ts) -> {ok, r} | {ok:false, err, msg}.
## Pure and deterministic: no nodes, no clock, no randomness. Time is passed in; ids come from
## state. A mutating op validates everything, then writes; a failure changes nothing.
## A mutating success bumps state.seq, which is EconStore's cue to journal it (contract 5).
## Client write ops carry `rid` in args (contract 5.3); a repeat returns the cached response.

const READ := ["wallet.get", "vault.get", "market.search", "market.orders", "market.item_detail", "market.trades", "market.mine"]
const WRITE := [
	"wallet.spend", "objective.claim", "vault.deposit_item", "vault.deposit_pet", "vault.withdraw_item",
	"vault.withdraw_pet", "market.list_fixed", "market.list_auction", "market.buy", "market.bid",
	"market.buyout", "market.cancel", "market.order_create", "market.order_cancel",
	"market.sell_to_order", "inbox.take",
]
const SYSTEM := ["account.ensure", "sys.tick"] ## called by the server itself, never relayed from a client

var rules: EconRules
var cat: EconCatalog
var L: Ledger
var H: PriceHistory
var V: AssetValidator
var book: MarketBook
var orders: OrderBook
var query: MarketQuery
var settlers: Settlers

func _init(p_rules: EconRules, p_catalog: EconCatalog) -> void:
	rules = p_rules
	cat = p_catalog
	L = Ledger.new(rules)
	L.new_account(Ledger.SETTLERS, str(rules.settler("name")))
	H = PriceHistory.new(L)
	V = AssetValidator.new(cat, rules)
	book = MarketBook.new(L, H)
	orders = OrderBook.new(L, H, cat)
	query = MarketQuery.new(L, H, book, orders, cat)
	settlers = Settlers.new(L, orders, cat)

## Replaces the whole state (snapshot load). Derived caches are rebuilt lazily.
func load_state(state: Dictionary) -> void:
	L.s = Ledger.norm(state)
	book.next_due = 0
	orders.next_due = 0

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
	var write := op in WRITE
	if not (write or op in READ or op in SYSTEM):
		return EconArgs.no("bad_request", "unknown op %s" % op)
	if op == "sys.tick":
		if account_id != Ledger.SETTLERS:
			return EconArgs.no("unauthorized", "sys.tick is server-only")
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
		var hit: Dictionary = L.acct(account_id).rid_cache.get(rid, {})
		if not hit.is_empty():
			if hit.op != op:
				return EconArgs.no("conflict", "rid already used for %s" % hit.op)
			return (hit.res as Dictionary).duplicate(true)
	var res := _dispatch(op, account_id, a)
	var changed := bool(res.ok) and not res.has("noop")
	res.erase("noop")
	if changed and op not in READ:
		L.s.seq = int(L.s.seq) + 1
		L.s.last_ts = L.now
		if write:
			_remember(L.acct(account_id), rid, op, res)
	return res

func _dispatch(op: String, me: int, a: EconArgs) -> Dictionary:
	match op:
		"account.ensure": return _ensure(me, a)
		"sys.tick": return _tick()
		"wallet.get": return EconArgs.ok({"wallet": L.acct(me).wallet, "held": query.held(me)})
		"wallet.spend": return _spend(me, a)
		"objective.claim": return _claim(me, a)
		"vault.get": return _vault(me)
		"vault.deposit_item": return _deposit_item(me, a)
		"vault.deposit_pet": return _deposit_pet(me, a)
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
		"market.search": return query.search(a)
		"market.orders": return query.open_orders(a)
		"market.item_detail": return query.item_detail(a)
		"market.trades": return query.trades(a)
		"market.mine": return query.mine(me)
		"inbox.take": return _inbox(me)
	return EconArgs.no("bad_request", "unknown op %s" % op)

func _remember(acct: Dictionary, rid: String, op: String, res: Dictionary) -> void:
	acct.rid_cache[rid] = {"op": op, "res": res.duplicate(true)}
	var order: Array = acct.rid_order
	order.append(rid)
	while order.size() > rules.num("rid_cache"):
		acct.rid_cache.erase(order.pop_front())

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
	if index in acct.claimed:
		return EconArgs.no("conflict", "objective %d already claimed" % index)
	var reward := cat.objective_rewards[index]
	acct.claimed.append(index)
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

func _deposit_item(me: int, a: EconArgs) -> Dictionary:
	var slot := a.dict("slot_dict")
	var count := a.integer("count", 1, 999999, slot.get("count", 1) if EconArgs.as_int(slot.get("count")) != null else 1)
	if a.err != "":
		return a.fail()
	var checked := V.item(slot, count)
	if checked.msg != "":
		return EconArgs.no("invalid_asset", checked.msg)
	var acct := L.acct(me)
	if acct.vault_items.size() >= rules.num("max_vault_items"):
		return EconArgs.no("limit_reached", "vault holds at most %d stacks" % rules.num("max_vault_items"))
	var stack: Dictionary = checked.v
	var def_id := str(stack.id)
	var cap_left := rules.deposit_cap(def_id) - _deposited(acct, def_id)
	if count > cap_left:
		return EconArgs.no("limit_reached", "%s deposit cap: %d more in the next 24 h" % [def_id, maxi(0, cap_left)])
	_log_deposit(acct, def_id, count)
	stack.uid = L.new_id("i")
	L.put_item(me, stack)
	L.bump("items_in", def_id, count)
	return EconArgs.ok({"uid": stack.uid, "item": stack.duplicate(true)})

func _deposit_pet(me: int, a: EconArgs) -> Dictionary:
	var raw := a.dict("pet_dict")
	if a.err != "":
		return a.fail()
	var checked := V.pet(raw)
	if checked.msg != "":
		return EconArgs.no("invalid_asset", checked.msg)
	var acct := L.acct(me)
	if acct.vault_pets.size() >= rules.num("max_vault_pets"):
		return EconArgs.no("limit_reached", "vault holds at most %d pets" % rules.num("max_vault_pets"))
	var pet: Dictionary = checked.v
	var species_key := "pet:%s" % pet.species
	if _deposited(acct, species_key) >= rules.num("pet_species_cap") or _deposited(acct, "pets") >= rules.num("pet_daily_cap"):
		return EconArgs.no("limit_reached", "pet deposit cap reached for the next 24 h")
	_log_deposit(acct, species_key, 1)
	_log_deposit(acct, "pets", 1)
	pet.uid = L.new_id("p")
	L.put_pet(me, pet)
	L.s.pets_in = int(L.s.pets_in) + 1
	return EconArgs.ok({"uid": pet.uid, "pet": pet.duplicate(true)})

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
	return EconArgs.ok({"item": part.duplicate(true)})

func _withdraw_pet(me: int, a: EconArgs) -> Dictionary:
	var uid := a.text("uid", 2, 24)
	if a.err != "":
		return a.fail()
	if not L.acct(me).vault_pets.has(uid):
		return EconArgs.no("not_found", "%s is not in your vault" % uid)
	var pet := L.take_pet(me, uid)
	L.s.pets_out = int(L.s.pets_out) + 1
	return EconArgs.ok({"pet": pet.duplicate(true)})

func _inbox(me: int) -> Dictionary:
	var acct := L.acct(me)
	var events: Array = acct.inbox
	if events.is_empty():
		return EconArgs.ok({"events": []}, false)
	acct.inbox = []
	return EconArgs.ok({"events": events.duplicate(true)})
