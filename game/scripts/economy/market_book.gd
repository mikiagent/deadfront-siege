class_name MarketBook
extends RefCounted
## Fixed-price listings and auctions (contract 6.2, 6.3): escrow in, buy, bid, buyout,
## cancel, settlement and expiry. Every handler validates everything before its first write.
## Active listings live in `listings`; closed ones move to `closed_listings` (kept 7 days).

const FAR := 1 << 62

var L: Ledger
var H: PriceHistory
var next_due: int = 0 ## derived cache: no active listing ends before this (0 = rescan)

func _init(ledger: Ledger, history: PriceHistory) -> void:
	L = ledger
	H = history

func list_fixed(me: int, a: EconArgs) -> Dictionary:
	var R := L.rules
	var unit := a.integer("unit_price", 1, R.num("max_unit_price"))
	var hours := a.one_of("duration_h", R.g("durations_h"))
	if a.err != "":
		return a.fail()
	var pick := _pick(me, a)
	if not pick.has("uid"):
		return pick
	var fee := maxi(R.num("listing_fee_min"), EconRules.ceil_bp(unit * int(pick.count), R.bp("listing_fee")))
	var why := _can_open(me, fee)
	if not why.is_empty():
		return why
	return _open(me, "fixed", pick, fee, hours, {"unit_price": unit})

func list_auction(me: int, a: EconArgs) -> Dictionary:
	var R := L.rules
	var lot_max := R.num("max_unit_price") * 999
	var start := a.integer("start_bid", 1, lot_max)
	var buyout := a.integer("buyout", 0, lot_max, 0)
	var hours := a.one_of("duration_h", R.g("durations_h"))
	if a.err != "":
		return a.fail()
	if buyout != 0 and buyout <= start:
		return EconArgs.no("bad_request", "buyout must be above start_bid")
	var pick := _pick(me, a)
	if not pick.has("uid"):
		return pick
	var fee := maxi(R.num("listing_fee_min"), EconRules.ceil_bp(start, R.bp("listing_fee")))
	var why := _can_open(me, fee)
	if not why.is_empty():
		return why
	return _open(me, "auction", pick, fee, hours, {"start_bid": start, "buyout": buyout})

func buy(me: int, a: EconArgs) -> Dictionary:
	var id := a.text("listing_id", 2, 24)
	var count := a.integer("count", 1, 999999, 1)
	if a.err != "":
		return a.fail()
	var lst := _active(id)
	if not lst.has("id"):
		return lst
	if lst.kind != "fixed":
		return EconArgs.no("bad_request", "auctions take bids, not buys")
	if L.now >= int(lst.ends):
		return EconArgs.no("expired", "listing has ended")
	if int(lst.seller) == me:
		return EconArgs.no("self_trade", "you cannot buy your own listing")
	if count > int(lst.left):
		return EconArgs.no("insufficient_items", "only %d left" % int(lst.left))
	if L.vault_full(me, lst.type):
		return _full()
	var total := int(lst.unit_price) * count
	if L.tradable(me) < total:
		return EconArgs.no("insufficient_funds", "needs %d tradable Gold" % total)
	L.debit(me, total)
	var trade := _pay_seller(lst, me, count, total, "fixed")
	var part := _release(lst, count)
	L.put_asset(me, lst.type, part)
	if int(lst.left) == 0:
		_close(lst, "sold")
	return EconArgs.ok({"listing": view(lst, me), "asset": part.duplicate(true), "paid": total, "wallet": L.acct(me).wallet, "trade": trade})

func bid(me: int, a: EconArgs) -> Dictionary:
	var R := L.rules
	var id := a.text("listing_id", 2, 24)
	var amount := a.integer("amount", 1, R.num("max_unit_price") * 999)
	if a.err != "":
		return a.fail()
	var lst := _active(id)
	if not lst.has("id"):
		return lst
	if lst.kind != "auction":
		return EconArgs.no("bad_request", "fixed listings take buys, not bids")
	if L.now >= int(lst.ends):
		return EconArgs.no("expired", "auction has ended")
	if int(lst.seller) == me:
		return EconArgs.no("self_trade", "you cannot bid on your own auction")
	var current := int(lst.bid)
	var need := int(lst.start_bid)
	if int(lst.bidder) >= 0:
		need = maxi(need, current + maxi(R.num("auction_min_increment_abs"), EconRules.ceil_bp(current, R.bp("auction_min_increment"))))
	if amount < need:
		return EconArgs.no("bid_too_low", "bid at least %d" % need)
	if L.vault_full(me, lst.type, _leading(me, lst.type, lst.id)):
		return _full()
	# ASSUMPTION: a bid at or above the buyout is refused; the buyer uses buyout instead.
	if int(lst.buyout) > 0 and amount >= int(lst.buyout):
		return EconArgs.no("bad_request", "bid reaches the buyout price; use buyout")
	var held := current if int(lst.bidder) == me else 0
	if L.tradable(me) + held < amount:
		return EconArgs.no("insufficient_funds", "needs %d tradable Gold" % amount)
	_release_bid(lst, me, amount)
	L.debit(me, amount)
	lst.bid = amount
	lst.bidder = me
	lst.bids = int(lst.bids) + 1
	# Anti-sniping: a late bid pushes the end out, a bounded number of times; a bid that would
	# not move the end (exactly snipe_window_s left) does not use up an extension.
	if int(lst.ends) - L.now <= R.num("snipe_window_s") and L.now + R.num("snipe_extend_s") > int(lst.ends) and int(lst.ext) < R.num("snipe_max_extensions"):
		lst.ends = L.now + R.num("snipe_extend_s")
		lst.ext = int(lst.ext) + 1
	return EconArgs.ok({"listing": view(lst, me), "wallet": L.acct(me).wallet})

func buyout(me: int, a: EconArgs) -> Dictionary:
	var id := a.text("listing_id", 2, 24)
	if a.err != "":
		return a.fail()
	var lst := _active(id)
	if not lst.has("id"):
		return lst
	if lst.kind != "auction" or int(lst.buyout) <= 0:
		return EconArgs.no("bad_request", "listing has no buyout")
	if L.now >= int(lst.ends):
		return EconArgs.no("expired", "auction has ended")
	if int(lst.seller) == me:
		return EconArgs.no("self_trade", "you cannot buy your own auction")
	if L.vault_full(me, lst.type):
		return _full()
	var price := int(lst.buyout)
	var held := int(lst.bid) if int(lst.bidder) == me else 0
	if L.tradable(me) + held < price:
		return EconArgs.no("insufficient_funds", "needs %d tradable Gold" % price)
	_release_bid(lst, me, price)
	L.debit(me, price)
	lst.bid = price
	lst.bidder = me
	var trade := _pay_seller(lst, me, int(lst.left), price, "auction")
	var part := _release(lst, int(lst.left))
	L.put_asset(me, lst.type, part)
	_close(lst, "sold")
	return EconArgs.ok({"listing": view(lst, me), "asset": part.duplicate(true), "paid": price, "wallet": L.acct(me).wallet, "trade": trade})

func cancel(me: int, a: EconArgs) -> Dictionary:
	var id := a.text("listing_id", 2, 24)
	if a.err != "":
		return a.fail()
	var lst := _active(id)
	if not lst.has("id"):
		return lst
	if int(lst.seller) != me:
		return EconArgs.no("not_owner", "not your listing")
	if L.now >= int(lst.ends):
		return EconArgs.no("expired", "listing has ended and is being settled")
	if int(lst.bidder) >= 0:
		return EconArgs.no("conflict", "an auction with a bid cannot be cancelled")
	var part := _release(lst, int(lst.left))
	L.put_asset(me, lst.type, part)
	_close(lst, "cancelled")
	return EconArgs.ok({"listing": view(lst, me), "asset": part.duplicate(true)})

## Settles every listing whose end has passed, oldest end first. Returns how many.
func settle_due() -> int:
	if next_due != 0 and L.now < next_due:
		return 0
	var due: Array = []
	var soonest := FAR
	for l in L.s.listings.values():
		if int(l.ends) <= L.now:
			due.append(l)
		else:
			soonest = mini(soonest, int(l.ends))
	next_due = soonest
	due.sort_custom(func (x: Dictionary, y: Dictionary) -> bool:
		return int(x.ends) < int(y.ends) or (int(x.ends) == int(y.ends) and Ledger.id_num(x.id) < Ledger.id_num(y.id)))
	for lst in due:
		var seller := int(lst.seller)
		if lst.kind == "auction" and int(lst.bidder) >= 0:
			var winner := int(lst.bidder)
			var trade := _pay_seller(lst, winner, int(lst.left), int(lst.bid), "auction")
			var part := _release(lst, int(lst.left))
			L.put_asset(winner, lst.type, part)
			L.inbox(winner, "won", {"listing_id": lst.id, "key": lst.key, "uid": part.uid, "count": trade.count, "paid": trade.total})
			_close(lst, "sold")
		else:
			var left := int(lst.left)
			var part := _release(lst, left)
			L.put_asset(seller, lst.type, part)
			L.inbox(seller, "expired", {"listing_id": lst.id, "key": lst.key, "uid": part.uid, "returned": left})
			_close(lst, "expired")
	return due.size()

## Forgets closed listings past retention. Returns how many.
func prune_closed() -> int:
	var cut := L.now - L.rules.num("retention_s")
	var gone := 0
	for id in L.s.closed_listings.keys():
		if int(L.s.closed_listings[id].closed) < cut:
			L.s.closed_listings.erase(id)
			gone += 1
	return gone

## A copy for `me` to see. Other bidders stay anonymous: `bidder` becomes has_bid / my_bid.
func view(lst: Dictionary, me: int) -> Dictionary:
	var v := lst.duplicate(true)
	v.seller_name = L.name_of(int(lst.seller))
	v.price = price_of(lst)
	v.npc = false
	v.has_bid = int(lst.bidder) >= 0
	v.my_bid = me >= 1 and int(lst.bidder) == me
	v.erase("bidder")
	return v

static func price_of(lst: Dictionary) -> int:
	if lst.kind == "fixed":
		return int(lst.unit_price)
	return int(lst.bid) if int(lst.bidder) >= 0 else int(lst.start_bid)

## {uid, count, kind, key} for the asset named in args.asset, or an error result.
func _pick(me: int, a: EconArgs) -> Dictionary:
	var spec := a.dict("asset")
	if a.err != "":
		return a.fail()
	var sub := EconArgs.new(spec)
	var uid := sub.text("uid", 2, EconArgs.UID_MAX)
	if sub.err != "":
		return EconArgs.no("bad_request", "asset.%s" % sub.err)
	var acct := L.acct(me)
	if acct.vault_items.has(uid):
		var stack: Dictionary = acct.vault_items[uid]
		var count := sub.integer("count", 1, 999999, stack.count)
		if sub.err != "":
			return EconArgs.no("bad_request", "asset.%s" % sub.err)
		if count > int(stack.count):
			return EconArgs.no("insufficient_items", "stack holds %d" % int(stack.count))
		return {"uid": uid, "count": count, "kind": "item", "key": PriceHistory.item_key(stack.id)}
	if acct.vault_pets.has(uid):
		var count := sub.integer("count", 1, 1, 1)
		if sub.err != "":
			return EconArgs.no("bad_request", "a pet listing is one pet")
		return {"uid": uid, "count": count, "kind": "pet", "key": PriceHistory.pet_key(acct.vault_pets[uid].species)}
	return EconArgs.no("not_found", "%s is not in your vault" % uid)

func _can_open(me: int, fee: int) -> Dictionary:
	var acct := L.acct(me)
	if int(acct.open_listings) >= L.rules.num("max_open_listings"):
		return EconArgs.no("limit_reached", "at most %d open listings" % L.rules.num("max_open_listings"))
	# ASSUMPTION: a listing fee goes to the sink, not to another account, so bound T-stones pay it
	# (contract v2 0.6 binds the start against transfers); a new player can sell from day one.
	if int(acct.wallet) < fee:
		return EconArgs.no("insufficient_funds", "listing fee is %d Gold" % fee)
	return {}

func _open(me: int, kind: String, pick: Dictionary, fee: int, hours: int, extra: Dictionary) -> Dictionary:
	var acct := L.acct(me)
	var asset := L.take_pet(me, pick.uid) if pick.kind == "pet" else L.take_item(me, pick.uid, pick.count)
	L.pay_sink(me, fee)
	var id := L.new_id("L")
	var lst := {
		"id": id, "kind": kind, "state": "active", "seller": me, "type": pick.kind, "key": pick.key,
		"asset": asset, "qty": pick.count, "left": pick.count, "unit_price": 0, "start_bid": 0,
		"buyout": 0, "bid": 0, "bidder": -1, "bids": 0, "ext": 0, "fee": fee,
		"created": L.now, "ends": L.now + hours * 3600, "closed": 0,
	}
	lst.merge(extra, true)
	L.s.listings[id] = lst
	acct.open_listings = int(acct.open_listings) + 1
	if next_due != 0:
		next_due = mini(next_due, int(lst.ends))
	return EconArgs.ok({"listing": view(lst, me), "fee": fee, "wallet": acct.wallet})

func _active(id: String) -> Dictionary:
	if L.s.listings.has(id):
		return L.s.listings[id]
	if L.s.closed_listings.has(id):
		return EconArgs.no("closed", "listing is %s" % L.s.closed_listings[id].state)
	return EconArgs.no("not_found", "no listing %s" % id)

## Takes `count` units out of escrow. All of it leaves with its uid; a part gets a new uid.
func _release(lst: Dictionary, count: int) -> Dictionary:
	var asset: Dictionary = lst.asset
	if count >= int(lst.left):
		var shown := asset.duplicate(true)
		if lst.type == "item":
			shown.count = lst.qty
		lst.asset = shown # display copy: the escrowed dict now belongs to its new owner
		lst.left = 0
		return asset
	asset.count = int(asset.count) - count
	L.retire(str(asset.uid))
	lst.left = int(lst.left) - count
	var part := asset.duplicate(true)
	part.count = count
	part.uid = L.new_id("i")
	return part

## Seller gets the price minus sales tax; the tax goes to the sink. Books the trade.
func _pay_seller(lst: Dictionary, buyer: int, count: int, total: int, via: String) -> Dictionary:
	var seller := int(lst.seller)
	var tax := EconRules.ceil_bp(total, L.rules.bp("sales_tax"))
	L.credit(seller, total - tax)
	L.to_sink(tax)
	var trade := H.record(via, lst.id, lst.key, lst.type, buyer, seller, count, total, tax)
	L.inbox(seller, "sold", {"listing_id": lst.id, "key": lst.key, "count": count, "total": total, "tax": tax, "net": total - tax, "buyer": L.name_of(buyer)})
	return trade

## Auctions of `kind` that `me` leads (other than `skip`): each delivers to their vault if it ends now.
func _leading(me: int, kind: String, skip: String) -> int:
	var n := 0
	for l: Dictionary in L.s.listings.values():
		if int(l.bidder) == me and l.type == kind and l.id != skip:
			n += 1
	return n

static func _full() -> Dictionary:
	return EconArgs.no("limit_reached", "your vault is full; withdraw something first")

## Hands a standing bid back to its bidder; tells them unless they are outbidding themselves.
func _release_bid(lst: Dictionary, me: int, new_amount: int) -> void:
	var prev := int(lst.bidder)
	if prev < 0:
		return
	L.credit(prev, int(lst.bid))
	if prev != me:
		L.inbox(prev, "outbid", {"listing_id": lst.id, "key": lst.key, "refunded": int(lst.bid), "now": new_amount})
	lst.bid = 0
	lst.bidder = -1

func _close(lst: Dictionary, state: String) -> void:
	lst.state = state
	lst.closed = L.now
	lst.left = 0
	L.s.listings.erase(lst.id)
	L.s.closed_listings[lst.id] = lst
	var acct := L.acct(int(lst.seller))
	acct.open_listings = int(acct.open_listings) - 1
