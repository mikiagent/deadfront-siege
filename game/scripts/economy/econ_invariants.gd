class_name EconInvariants
extends RefCounted
## Contract 6.7 items 1-4 over a state dict (item 5, replay, is proven by EconStore tests).
## Returns readable violations; an empty array means the books balance.

const LISTING_CLOSED := ["sold", "expired", "cancelled"]
const ORDER_CLOSED := ["filled", "cancelled", "expired"]

static func check(s: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	var coins := int(s.fee_sink)
	var units := {} ## def_id -> units in vaults + listing escrow
	var pets := 0
	var where := {} ## uid -> container, for the exactly-one-place rule
	var open_listings := {}
	var open_orders := {}
	var next_id := int(s.next_id)
	for key in s.accounts:
		var acct: Dictionary = s.accounts[key]
		if str(acct.id) != key:
			bad.append("account %s holds id %s" % [key, str(acct.id)])
		if int(acct.wallet) < 0:
			bad.append("account %s wallet %d" % [key, int(acct.wallet)])
		coins += int(acct.wallet)
		for uid in acct.vault_items:
			var st: Dictionary = acct.vault_items[uid]
			_place(where, uid, "vault %s" % key, next_id, bad)
			if str(st.uid) != uid or int(st.count) <= 0:
				bad.append("vault %s stack %s uid/count wrong" % [key, uid])
			units[st.id] = int(units.get(st.id, 0)) + int(st.count)
		for uid in acct.vault_pets:
			_place(where, uid, "vault %s" % key, next_id, bad)
			if str(acct.vault_pets[uid].uid) != uid:
				bad.append("vault %s pet %s uid wrong" % [key, uid])
			pets += 1
	for id in s.listings:
		var l: Dictionary = s.listings[id]
		if l.state != "active" or s.closed_listings.has(id):
			bad.append("listing %s in book but %s" % [id, l.state])
		if int(l.left) <= 0:
			bad.append("listing %s active with nothing in escrow" % id)
		_place(where, str(l.asset.uid), "listing %s" % id, next_id, bad)
		if l.type == "item":
			if int(l.asset.count) != int(l.left):
				bad.append("listing %s escrow count %d != left %d" % [id, int(l.asset.count), int(l.left)])
			units[l.asset.id] = int(units.get(l.asset.id, 0)) + int(l.left)
		else:
			pets += 1
		if int(l.bidder) >= 0:
			if int(l.bid) <= 0:
				bad.append("listing %s bidder without a hold" % id)
			coins += int(l.bid)
		elif int(l.bid) != 0:
			bad.append("listing %s hold without a bidder" % id)
		open_listings[str(l.seller)] = int(open_listings.get(str(l.seller), 0)) + 1
	for id in s.closed_listings:
		var l: Dictionary = s.closed_listings[id]
		if l.state not in LISTING_CLOSED or int(l.left) != 0:
			bad.append("closed listing %s state %s left %d" % [id, l.state, int(l.left)])
	for id in s.orders:
		var o: Dictionary = s.orders[id]
		if o.state != "open" or s.closed_orders.has(id):
			bad.append("order %s in book but %s" % [id, o.state])
		if int(o.filled) < 0 or int(o.filled) >= int(o.qty):
			bad.append("order %s filled %d of %d while open" % [id, int(o.filled), int(o.qty)])
		if int(o.escrow) != (int(o.qty) - int(o.filled)) * int(o.unit_price):
			bad.append("order %s escrow %d does not cover the unfilled qty" % [id, int(o.escrow)])
		coins += int(o.escrow)
		open_orders[str(o.buyer)] = int(open_orders.get(str(o.buyer), 0)) + 1
	for id in s.closed_orders:
		var o: Dictionary = s.closed_orders[id]
		if o.state not in ORDER_CLOSED or int(o.escrow) != 0:
			bad.append("closed order %s state %s escrow %d" % [id, o.state, int(o.escrow)])
	for key in s.accounts:
		var acct: Dictionary = s.accounts[key]
		if int(acct.open_listings) != int(open_listings.get(key, 0)) or int(acct.open_orders) != int(open_orders.get(key, 0)):
			bad.append("account %s open counters drifted" % key)
	var issued := int(s.initial_grants)
	for source in s.faucet:
		issued += int(s.faucet[source])
	if coins != issued:
		bad.append("coins: held %d != issued %d" % [coins, issued])
	var defs := {}
	for d in [s.items_in, s.items_out, s.items_consumed, units]:
		for k in d:
			defs[k] = true
	for def_id in defs:
		var net := int(s.items_in.get(def_id, 0)) - int(s.items_out.get(def_id, 0)) - int(s.items_consumed.get(def_id, 0))
		if net != int(units.get(def_id, 0)):
			bad.append("items %s: in-out-consumed %d != held %d" % [def_id, net, int(units.get(def_id, 0))])
	if int(s.pets_in) - int(s.pets_out) != pets:
		bad.append("pets: in-out %d != held %d" % [int(s.pets_in) - int(s.pets_out), pets])
	return bad

static func _place(where: Dictionary, uid: String, container: String, next_id: int, bad: Array[String]) -> void:
	if where.has(uid):
		bad.append("uid %s in %s and %s" % [uid, where[uid], container])
	where[uid] = container
	if Ledger.id_num(uid) <= 0 or Ledger.id_num(uid) >= next_id:
		bad.append("uid %s was never issued" % uid)
