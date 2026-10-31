class_name Settlers
extends RefCounted
## NPC account 0 (contract 6.6): the price floor and the only faucet besides objectives.
## Each refresh it cancels its open orders and posts new ones from market.json demand.
## Each server day its holdings (wallet + order escrow) are topped up to the daily budget,
## so at most `daily_budget` T-stones can reach players through Settlers per day. It never sells.

var L: Ledger
var orders: OrderBook
var demand: Array = [] ## [def_id, unit_price, weight], highest demand first

func _init(ledger: Ledger, p_orders: OrderBook, cat: EconCatalog) -> void:
	L = ledger
	orders = p_orders
	demand = demand_table(cat, ledger.rules)

## Refreshes on a new refresh window. Returns true if it changed anything.
func tick() -> bool:
	var R := L.rules
	var st: Dictionary = L.s.settlers
	var refresh := int(R.settler("refresh_s"))
	var window := L.now / refresh
	if window == int(st.hour):
		return false
	for o in L.s.orders.values().duplicate():
		if int(o.buyer) == Ledger.SETTLERS:
			orders.close(o, "cancelled")
	var day := L.now / 86400
	if day != int(st.day):
		var budget := int(R.settler("daily_budget"))
		var top_up := budget - int(L.acct(Ledger.SETTLERS).wallet)
		if top_up > 0:
			L.mint(Ledger.SETTLERS, top_up, "settlers")
		st.day = day
	st.hour = window
	if demand.is_empty():
		return true
	var n := mini(int(R.settler("orders_per_refresh")), demand.size())
	var per := mini(int(L.acct(Ledger.SETTLERS).wallet), int(R.settler("escrow_per_refresh"))) / n
	var start := (window * n) % demand.size()
	for i in n:
		var row: Array = demand[(start + i) % demand.size()]
		var qty := mini(int(R.settler("max_qty")), per / int(row[1]))
		if qty >= 1:
			orders.post(Ledger.SETTLERS, row[0], 1, R.num("level_max"), qty, int(row[1]), L.now + refresh * 2)
	return true

## Every tradeable def with a market category, priced base x mean regional demand x
## scarce/abundant multiplier x price_factor.
static func demand_table(cat: EconCatalog, R: EconRules) -> Array:
	var base: Dictionary = cat.market.get("base_price_tstones", {})
	var markets: Dictionary = cat.market.get("markets", {})
	var alias: Dictionary = R.g("category_alias")
	var excluded: Array = R.settler("excluded_categories")
	var scarce := float(cat.market.get("scarce_item_multiplier", 1.0))
	var abundant := float(cat.market.get("abundant_item_multiplier", 1.0))
	var rows: Array = []
	if markets.is_empty():
		return rows
	var ids := cat.items.keys()
	ids.sort()
	for def_id in ids:
		if def_id in R.g("denied_defs") or def_id == AssetValidator.CAGE:
			continue
		var mc := market_category(cat.item(def_id), base, alias)
		if mc == "" or mc in excluded:
			continue
		var weight := 0.0
		for m in markets.values():
			var dem: Dictionary = m.get("demand", {})
			var w := float(dem.get(mc, dem.get("default", 1.0)))
			if def_id in m.get("scarce_items", []):
				w *= scarce
			elif def_id in m.get("abundant_items", []):
				w *= abundant
			weight += w
		weight /= float(markets.size())
		rows.append([def_id, maxi(1, roundi(float(base[mc]) * weight * float(R.settler("price_factor")))), weight])
	rows.sort_custom(func (x: Array, y: Array) -> bool: return x[2] > y[2] or (x[2] == y[2] and str(x[0]) < str(y[0])))
	return rows

## First item category that is a market category, else the first one with an alias.
static func market_category(def: ItemDef, base: Dictionary, alias: Dictionary) -> String:
	for c in def.categories:
		if base.has(str(c)):
			return str(c)
	for c in def.categories:
		if alias.has(str(c)) and base.has(str(alias[str(c)])):
			return str(alias[str(c)])
	return ""
