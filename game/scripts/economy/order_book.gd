class_name OrderBook
extends RefCounted
## Buy orders and instant sell (contract 6.4). An order escrows qty x unit_price up front and
## pays sellers out of that escrow, so a fill can never spend coins that do not exist.
## Settler (npc) orders consume what they buy and are forgotten when they close.

const FAR := 1 << 62

var L: Ledger
var H: PriceHistory
var cat: EconCatalog
var next_due: int = 0 ## derived cache: no open order ends before this (0 = rescan)

func _init(ledger: Ledger, history: PriceHistory, catalog: EconCatalog) -> void:
	L = ledger
	H = history
	cat = catalog

func create(me: int, a: EconArgs) -> Dictionary:
	var R := L.rules
	var lv_max := R.num("level_max")
	var def_id := a.text("def_id", 1, 48)
	var lo := a.integer("min_level", 1, lv_max, 1)
	var hi := a.integer("max_level", 1, lv_max, lv_max)
	var qty := a.integer("qty", 1, R.num("max_order_qty"))
	var unit := a.integer("unit_price", 1, R.num("max_unit_price"))
	var hours := a.one_of("duration_h", R.g("durations_h"))
	if a.err != "":
		return a.fail()
	if hi < lo:
		return EconArgs.no("bad_request", "max_level is below min_level")
	if cat.item(def_id) == null or def_id in R.g("denied_defs"):
		return EconArgs.no("invalid_asset", "%s cannot be ordered" % def_id)
	var acct := L.acct(me)
	if int(acct.open_orders) >= R.num("max_open_orders"):
		return EconArgs.no("limit_reached", "at most %d open orders" % R.num("max_open_orders"))
	if L.vault_full(me, "item"):
		return EconArgs.no("limit_reached", "your vault is full; withdraw something first")
	if int(acct.wallet) < qty * unit:
		return EconArgs.no("insufficient_funds", "order escrow is %d T-stones" % (qty * unit))
	var o := post(me, def_id, lo, hi, qty, unit, L.now + hours * 3600)
	return EconArgs.ok({"order": view(o), "wallet": acct.wallet})

## Opens an order and escrows its full cost. Callers have checked funds.
func post(buyer: int, def_id: String, lo: int, hi: int, qty: int, unit: int, ends: int) -> Dictionary:
	L.debit(buyer, qty * unit)
	var id := L.new_id("O")
	var o := {
		"id": id, "state": "open", "buyer": buyer, "npc": buyer == Ledger.SETTLERS,
		"def_id": def_id, "key": PriceHistory.item_key(def_id), "min_level": lo, "max_level": hi,
		"qty": qty, "filled": 0, "unit_price": unit, "escrow": qty * unit,
		"created": L.now, "ends": ends, "closed": 0,
	}
	L.s.orders[id] = o
	var acct := L.acct(buyer)
	acct.open_orders = int(acct.open_orders) + 1
	if next_due != 0:
		next_due = mini(next_due, ends)
	return o

func cancel(me: int, a: EconArgs) -> Dictionary:
	var id := a.text("order_id", 2, 24)
	if a.err != "":
		return a.fail()
	var o := _open_order(id)
	if not o.has("id"):
		return o
	if int(o.buyer) != me:
		return EconArgs.no("not_owner", "not your order")
	var refund := int(o.escrow)
	close(o, "cancelled")
	return EconArgs.ok({"order": view(o), "refunded": refund, "wallet": L.acct(me).wallet})

func sell(me: int, a: EconArgs) -> Dictionary:
	var R := L.rules
	var id := a.text("order_id", 2, 24)
	var uid := a.text("uid", 2, 24)
	var count := a.integer("count", 1, 999999)
	if a.err != "":
		return a.fail()
	var o := _open_order(id)
	if not o.has("id"):
		return o
	if L.now >= int(o.ends):
		return EconArgs.no("expired", "order has ended")
	if int(o.buyer) == me:
		return EconArgs.no("self_trade", "you cannot fill your own order")
	var vault: Dictionary = L.acct(me).vault_items
	if not vault.has(uid):
		return EconArgs.no("not_found", "%s is not in your vault" % uid)
	var stack: Dictionary = vault[uid]
	if not accepts(o, stack):
		return EconArgs.no("invalid_asset", "order wants %s level %d..%d" % [o.def_id, int(o.min_level), int(o.max_level)])
	if count > int(stack.count):
		return EconArgs.no("insufficient_items", "stack holds %d" % int(stack.count))
	var want := int(o.qty) - int(o.filled)
	if count > want:
		return EconArgs.no("bad_request", "order wants only %d more" % want)
	var buyer := int(o.buyer)
	# Each fill is a new stack in the buyer's vault, so a full vault pauses the order.
	if not o.npc and L.vault_full(buyer, "item"):
		return EconArgs.no("limit_reached", "the buyer's vault is full; try another order")
	var pay := int(o.unit_price) * count
	var tax := EconRules.ceil_bp(pay, R.bp("sales_tax"))
	o.escrow = int(o.escrow) - pay
	L.credit(me, pay - tax)
	L.to_sink(tax)
	var units := L.take_item(me, uid, count)
	if o.npc:
		L.bump("items_consumed", str(units.id), count) # Settlers use what they buy
	else:
		L.put_item(buyer, units)
	o.filled = int(o.filled) + count
	var trade := H.record("order", o.id, o.key, "item", buyer, me, count, pay, tax)
	L.inbox(buyer, "filled", {"order_id": o.id, "key": o.key, "uid": units.uid, "count": count, "unit_price": int(o.unit_price), "seller": L.name_of(me)})
	if int(o.filled) >= int(o.qty):
		close(o, "filled")
	return EconArgs.ok({"order": view(o), "paid": pay - tax, "tax": tax, "wallet": L.acct(me).wallet, "trade": trade})

## Units qualify when def and level fit and the stack is not locked or unstable (6.1).
static func accepts(o: Dictionary, stack: Dictionary) -> bool:
	if str(stack.id) != str(o.def_id):
		return false
	if int(stack.level) < int(o.min_level) or int(stack.level) > int(o.max_level):
		return false
	return not ("locked" in stack.flags or "unstable" in stack.flags)

## Refunds any escrow left and closes the order.
func close(o: Dictionary, state: String) -> void:
	var left := int(o.escrow)
	if left > 0:
		L.credit(int(o.buyer), left)
	o.escrow = 0
	o.state = state
	o.closed = L.now
	L.s.orders.erase(o.id)
	if not o.npc: # ASSUMPTION: closed Settler orders are not kept (about 288 a day); they read as not_found
		L.s.closed_orders[o.id] = o
	var acct := L.acct(int(o.buyer))
	acct.open_orders = int(acct.open_orders) - 1

func expire_due() -> int:
	if next_due != 0 and L.now < next_due:
		return 0
	var due: Array = []
	var soonest := FAR
	for o in L.s.orders.values():
		if int(o.ends) <= L.now:
			due.append(o)
		else:
			soonest = mini(soonest, int(o.ends))
	next_due = soonest
	due.sort_custom(func (x: Dictionary, y: Dictionary) -> bool:
		return int(x.ends) < int(y.ends) or (int(x.ends) == int(y.ends) and Ledger.id_num(x.id) < Ledger.id_num(y.id)))
	for o in due:
		L.inbox(int(o.buyer), "expired", {"order_id": o.id, "key": o.key, "filled": int(o.filled), "refunded": int(o.escrow)})
		close(o, "expired")
	return due.size()

func prune_closed() -> int:
	var cut := L.now - L.rules.num("retention_s")
	var gone := 0
	for id in L.s.closed_orders.keys():
		if int(L.s.closed_orders[id].closed) < cut:
			L.s.closed_orders.erase(id)
			gone += 1
	return gone

func view(o: Dictionary) -> Dictionary:
	var v := o.duplicate(true)
	v.buyer_name = L.name_of(int(o.buyer))
	return v

func _open_order(id: String) -> Dictionary:
	if L.s.orders.has(id):
		return L.s.orders[id]
	if L.s.closed_orders.has(id):
		return EconArgs.no("closed", "order is %s" % L.s.closed_orders[id].state)
	return EconArgs.no("not_found", "no order %s" % id)
