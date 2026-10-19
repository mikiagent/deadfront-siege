class_name PriceHistory
extends RefCounted
## Trades, hourly OHLC + volume per asset key for 7 days, and the damped reference price
## (contract 6.5): volume-weighted median of the window's trades, skipping prices outside
## 0.25x-4x the previous reference and the 3rd+ trade between one pair of accounts in 24 h.
## Keys are "item:<def_id>" and "pet:<species>" so an item id can never collide with a species.

var L: Ledger

func _init(ledger: Ledger) -> void:
	L = ledger

static func item_key(def_id: String) -> String:
	return "item:%s" % def_id

static func pet_key(species: String) -> String:
	return "pet:%s" % species

## Books one trade: trade log, both accounts' histories, OHLC bucket, reference price.
func record(via: String, ref_id: String, key: String, kind: String, buyer: int, seller: int, count: int, total: int, tax: int) -> Dictionary:
	var R := L.rules
	var s := L.s
	var unit := total / maxi(1, count)
	var t := {
		"id": L.new_id("T"), "ts": L.now, "via": via, "ref": ref_id, "key": key, "type": kind,
		"buyer": buyer, "seller": seller, "count": count, "unit_price": unit, "total": total,
		"tax": tax, "npc": buyer == Ledger.SETTLERS,
	}
	var log: Array = s.trades
	log.append(t.duplicate(true))
	while log.size() > R.num("trades_keep"):
		log.pop_front()
	for id in [buyer, seller]:
		if id == Ledger.SETTLERS:
			continue
		var mine: Array = L.acct(id).trades
		mine.append(t.duplicate(true))
		while mine.size() > R.num("account_trades_keep"):
			mine.pop_front()
	_bucket(key, unit, count, total)
	_reference(key, unit, count, buyer, seller)
	return t

func _bucket(key: String, unit: int, count: int, total: int) -> void:
	var hours: Dictionary = L.s.history.get(key, {})
	L.s.history[key] = hours
	var h := str(L.now / L.rules.num("history_bucket_s"))
	if not hours.has(h):
		hours[h] = [unit, unit, unit, unit, 0, 0]
	var b: Array = hours[h]
	b[1] = maxi(int(b[1]), unit)
	b[2] = mini(int(b[2]), unit)
	b[3] = unit
	b[4] = int(b[4]) + count
	b[5] = int(b[5]) + total

func _reference(key: String, unit: int, count: int, buyer: int, seller: int) -> void:
	var R := L.rules
	var s := L.s
	var prev := int(s.ref.get(key, 0))
	var pair := "%d:%d" % [mini(buyer, seller), maxi(buyer, seller)]
	var seen: Array = s.pairs.get(pair, [])
	s.pairs[pair] = seen
	var wash := seen.size() >= R.num("wash_pair_max")
	seen.append(L.now)
	var outlier := prev > 0 and (float(unit) < float(prev) * float(R.g("reference_outlier_low")) or float(unit) > float(prev) * float(R.g("reference_outlier_high")))
	var rows: Array = s.ref_trades.get(key, [])
	s.ref_trades[key] = rows
	rows.append([L.now, unit, count, 0 if (wash or outlier) else 1])
	while rows.size() > R.num("reference_trades_keep"):
		rows.pop_front()
	_recompute(key)

func _recompute(key: String) -> void:
	var rows: Array = L.s.ref_trades.get(key, [])
	var used: Array = []
	var weight := 0
	for r in rows:
		if int(r[3]) == 1:
			used.append(r)
			weight += int(r[2])
	if used.is_empty():
		return # keep the last reference as the outlier anchor
	used.sort_custom(func (x: Array, y: Array) -> bool: return int(x[1]) < int(y[1]))
	var half := 0
	for r in used:
		half += int(r[2])
		if half * 2 >= weight:
			L.s.ref[key] = int(r[1])
			return

## Drops buckets, reference rows and pair counts that left their windows. Returns true if any did.
func prune() -> bool:
	var R := L.rules
	var s := L.s
	var changed := false
	var oldest_hour := (L.now - R.num("history_keep_s")) / R.num("history_bucket_s")
	for key in s.history.keys():
		var hours: Dictionary = s.history[key]
		for h in hours.keys():
			if int(h) < oldest_hour:
				hours.erase(h)
				changed = true
		if hours.is_empty():
			s.history.erase(key)
	var ref_cut := L.now - R.num("reference_window_s")
	for key in s.ref_trades.keys():
		var rows: Array = s.ref_trades[key]
		var keep := rows.filter(func (r: Array) -> bool: return int(r[0]) > ref_cut)
		if keep.size() != rows.size():
			changed = true
			if keep.is_empty():
				s.ref_trades.erase(key)
			else:
				s.ref_trades[key] = keep
				_recompute(key)
	var wash_cut := L.now - R.num("wash_window_s")
	for pair in s.pairs.keys():
		var seen: Array = s.pairs[pair]
		var keep := seen.filter(func (t: int) -> bool: return t > wash_cut)
		if keep.size() != seen.size():
			changed = true
			if keep.is_empty():
				s.pairs.erase(pair)
			else:
				s.pairs[pair] = keep
	return changed

## Hourly [hour_start_ts, open, high, low, close, units, coins] for the last 7 days, oldest first.
func buckets(key: String, ts: int) -> Array:
	var size := L.rules.num("history_bucket_s")
	var oldest := (ts - L.rules.num("history_keep_s")) / size
	var out: Array = []
	var hours: Dictionary = L.s.history.get(key, {})
	var keys := hours.keys()
	keys.sort_custom(func (x: String, y: String) -> bool: return int(x) < int(y))
	for h in keys:
		if int(h) >= oldest:
			var b: Array = hours[h]
			out.append([int(h) * size, b[0], b[1], b[2], b[3], b[4], b[5]])
	return out

func volume(key: String, ts: int, window_s: int) -> int:
	var units := 0
	var size := L.rules.num("history_bucket_s")
	var hours: Dictionary = L.s.history.get(key, {})
	for h in hours:
		if (int(h) + 1) * size > ts - window_s:
			units += int(hours[h][4])
	return units
