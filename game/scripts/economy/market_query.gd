class_name MarketQuery
extends RefCounted
## Read-only market views (contract 6.5): search, open orders, item detail, trades, mine.
## Nothing here writes state; every returned record is a copy.

const SORTS := ["price_asc", "price_desc", "ending_soon", "newest", "level_desc"]
const KEY_MAX := (1 << 30) - 1
const NUM_MASK := (1 << 33) - 1
## Search stat names (CreatureGenetics.STATS) -> PetDict fields.
const PET_FIELD := {"health": "hp", "melee_defense": "defense", "ranged_defense": "ranged_defense", "melee_attack": "attack", "ranged_attack": "ranged_attack", "accuracy": "accuracy", "speed": "speed"}

var L: Ledger
var H: PriceHistory
var book: MarketBook
var orders: OrderBook
var cat: EconCatalog

func _init(ledger: Ledger, history: PriceHistory, p_book: MarketBook, p_orders: OrderBook, catalog: EconCatalog) -> void:
	L = ledger
	H = history
	book = p_book
	orders = p_orders
	cat = catalog

func search(a: EconArgs) -> Dictionary:
	var R := L.rules
	var lv_max := R.num("level_max")
	var q := a.text("q", 0, 40, "").to_lower()
	var kind := a.choice("kind", ["fixed", "auction", "any"], "any")
	var asset := a.choice("asset", ["item", "pet", "any"], "any")
	var category := a.text("category", 0, 32, "")
	var species := a.text("species", 0, 48, "")
	var min_level := a.integer("min_level", 1, lv_max, 1)
	var max_level := a.integer("max_level", 1, lv_max, lv_max)
	var min_price := a.integer("min_price", 0, EconArgs.SAFE_INT, 0)
	var max_price := a.integer("max_price", 0, EconArgs.SAFE_INT, EconArgs.SAFE_INT)
	var grade := a.text("grade", 0, 2, "")
	var stat_min := a.dict("stat_min", false)
	var sort := a.choice("sort", SORTS, "price_asc")
	var page := a.integer("page", 1, 100000, 1)
	var page_size := a.integer("page_size", 1, R.num("page_size_max"), R.num("page_size_default"))
	if a.err != "":
		return a.fail()
	var mins := {}
	for stat in stat_min:
		var v: Variant = stat_min[stat]
		if not PET_FIELD.has(str(stat)) or not (v is int or v is float) or not is_finite(float(v)):
			return EconArgs.no("bad_request", "stat_min takes %s with numbers" % ", ".join(PET_FIELD.keys()))
		mins[PET_FIELD[str(stat)]] = float(v)
	var cat_name := StringName(category)
	var pets_only := species != "" or grade != "" or not mins.is_empty()
	var now := L.now
	var keys := PackedInt64Array()
	for l: Dictionary in L.s.listings.values():
		var ends: int = l.ends
		if ends <= now:
			continue
		if kind != "any" and l.kind != kind:
			continue
		var is_pet: bool = l.type == "pet"
		if (asset == "item" and is_pet) or (asset == "pet" and not is_pet):
			continue
		var ast: Dictionary = l.asset
		var lv: int = ast.level
		if lv < min_level or lv > max_level:
			continue
		var price := MarketBook.price_of(l)
		if price < min_price or price > max_price:
			continue
		if is_pet:
			if category != "" or (species != "" and ast.species != species) or (grade != "" and not _grade_ok(str(ast.grade), grade)):
				continue
			if q != "" and not str(ast.species).contains(q):
				continue
			var weak := false
			for f in mins:
				if float(ast[f]) < mins[f]:
					weak = true
					break
			if weak:
				continue
		else:
			if pets_only:
				continue
			if category != "" or q != "":
				var def := cat.item(ast.id)
				if category != "" and (def == null or not def.has_category(cat_name)):
					continue
				if q != "" and not (str(ast.id).contains(q) or (def != null and def.display_name.to_lower().contains(q))):
					continue
		var num := Ledger.id_num(l.id)
		var k := 0
		match sort:
			"price_asc": k = mini(price, KEY_MAX)
			"price_desc": k = KEY_MAX - mini(price, KEY_MAX)
			"ending_soon": k = mini(ends - now, KEY_MAX)
			"level_desc": k = R.num("level_max") - lv
			"newest": num = NUM_MASK - num
		keys.append((k << 33) | num)
	keys.sort()
	var results: Array = []
	var from := (page - 1) * page_size
	for i in range(from, mini(from + page_size, keys.size())):
		var num := keys[i] & NUM_MASK
		if sort == "newest":
			num = NUM_MASK - num
		results.append(book.view(L.s.listings["L%d" % num]))
	return EconArgs.ok({"total": keys.size(), "page": page, "page_size": page_size, "results": results})

## Open orders, best first: highest unit price, then oldest.
func open_orders(a: EconArgs) -> Dictionary:
	var def_id := a.text("def_id", 0, 48, "")
	var limit := a.integer("limit", 1, 100, 50)
	if a.err != "":
		return a.fail()
	var rows := best_orders(def_id)
	var out: Array = []
	for o in rows.slice(0, limit):
		out.append(orders.view(o))
	return EconArgs.ok({"total": rows.size(), "orders": out})

func best_orders(def_id: String) -> Array:
	var rows: Array = []
	for o in L.s.orders.values():
		if int(o.ends) > L.now and (def_id == "" or o.def_id == def_id):
			rows.append(o)
	rows.sort_custom(func (x: Dictionary, y: Dictionary) -> bool:
		if int(x.unit_price) != int(y.unit_price):
			return int(x.unit_price) > int(y.unit_price)
		if int(x.created) != int(y.created):
			return int(x.created) < int(y.created)
		return Ledger.id_num(x.id) < Ledger.id_num(y.id))
	return rows

func item_detail(a: EconArgs) -> Dictionary:
	var key := _key(a)
	if key.begins_with("!"):
		return EconArgs.no("bad_request", key.substr(1))
	var best_ask := 0
	for l in L.s.listings.values():
		if l.key == key and l.kind == "fixed" and int(l.ends) > L.now and (best_ask == 0 or int(l.unit_price) < best_ask):
			best_ask = int(l.unit_price)
	var best_bid := 0
	if key.begins_with("item:"):
		var top := best_orders(key.substr(5))
		if not top.is_empty():
			best_bid = int(top[0].unit_price)
	var last := 0
	for i in range(L.s.trades.size() - 1, -1, -1):
		if L.s.trades[i].key == key:
			last = int(L.s.trades[i].unit_price)
			break
	return EconArgs.ok({
		"key": key, "best_ask": best_ask, "best_bid": best_bid, "last_price": last,
		"ref_price": int(L.s.ref.get(key, 0)),
		"volume_24h": H.volume(key, L.now, 86400), "volume_7d": H.volume(key, L.now, 7 * 86400),
		"buckets": H.buckets(key, L.now),
	})

func trades(a: EconArgs) -> Dictionary:
	var key := _key(a)
	var limit := a.integer("limit", 1, 100, 20)
	if key.begins_with("!") or a.err != "":
		return EconArgs.no("bad_request", key.substr(1) if key.begins_with("!") else a.err)
	var out: Array = []
	for i in range(L.s.trades.size() - 1, -1, -1):
		if out.size() >= limit:
			break
		if L.s.trades[i].key == key:
			out.append(L.s.trades[i].duplicate(true))
	return EconArgs.ok({"key": key, "trades": out})

func mine(me: int) -> Dictionary:
	var listings: Array = []
	var bids: Array = []
	for l in L.s.listings.values():
		if int(l.seller) == me:
			listings.append(book.view(l))
		if int(l.bidder) == me:
			bids.append(book.view(l))
	for l in L.s.closed_listings.values():
		if int(l.seller) == me:
			listings.append(book.view(l))
	var mine_orders: Array = []
	for o in L.s.orders.values():
		if int(o.buyer) == me:
			mine_orders.append(orders.view(o))
	for o in L.s.closed_orders.values():
		if int(o.buyer) == me:
			mine_orders.append(orders.view(o))
	var newest := func (x: Dictionary, y: Dictionary) -> bool: return Ledger.id_num(x.id) > Ledger.id_num(y.id)
	listings.sort_custom(newest)
	bids.sort_custom(newest)
	mine_orders.sort_custom(newest)
	var trade_rows: Array = (L.acct(me).trades as Array).duplicate(true)
	trade_rows.reverse()
	return EconArgs.ok({"listings": listings, "bids": bids, "orders": mine_orders, "trades": trade_rows})

## T-stones an account has locked in standing bids and open orders.
func held(me: int) -> int:
	var total := 0
	for l in L.s.listings.values():
		if int(l.bidder) == me:
			total += int(l.bid)
	for o in L.s.orders.values():
		if int(o.buyer) == me:
			total += int(o.escrow)
	return total

## "item:<def>" or "pet:<species>" from exactly one of def_id / species; "!why" when invalid.
func _key(a: EconArgs) -> String:
	var def_id := a.text("def_id", 1, 48, "")
	var species := a.text("species", 1, 48, "")
	if a.err != "":
		return "!" + a.err
	if (def_id == "") == (species == ""):
		return "!give exactly one of def_id or species"
	if def_id != "":
		return PriceHistory.item_key(def_id) if cat.item(def_id) != null else "!unknown def_id"
	return PriceHistory.pet_key(species) if cat.creature(species) != null else "!unknown species"

## "S" matches S-, S and S+; "S+" matches only S+.
static func _grade_ok(have: String, want: String) -> bool:
	return have.begins_with(want) if want.length() == 1 else have == want
