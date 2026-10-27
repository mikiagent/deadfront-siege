class_name MarketSystem
extends RefCounted
## Simulated Island Market (docs/design/economy.md v1). Pure simulation: no nodes, no UI.
##
## price = base(category) * level_factor(level) * attribute_bonus * regional_demand(market, item) * saturation(market, item)
##
## Everything here is deterministic: no RNG anywhere. Saturation recovers from an explicit
## tick(hours) the caller drives, so a test, a save file or a future UI all get the same numbers.

const DEFAULT_PATH := "res://data/world/market.json"
const NEVER := -1.0 ## settle_hours sentinel: a listing this far over the price never sells.

var _data: Dictionary = {}
var _saturation: Dictionary = {} ## "market|item" -> multiplier, 1.0 = no saturation
var _listings: Array[Dictionary] = []
var _balance: float = 0.0 ## T-stones held by the simulated market wallet
var _fees_paid: float = 0.0 ## lifetime listing fees: the market's T-stone sink
var _sold_value: float = 0.0

static func load_default() -> MarketSystem:
	var raw: Dictionary = Data.market if Data.market is Dictionary and not Data.market.is_empty() else _read(DEFAULT_PATH)
	return MarketSystem.new(raw)

static func from_data(raw: Dictionary) -> MarketSystem:
	return MarketSystem.new(raw)

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}

func _init(raw: Dictionary = {}) -> void:
	_data = raw.duplicate(true)

# --- data surface -------------------------------------------------------------------------

func is_loaded() -> bool:
	return not _markets().is_empty()

func market_ids() -> Array:
	return _markets().keys()

func market_name(market_id: StringName) -> String:
	return str(_market(market_id).get("name", str(market_id)))

func has_market(market_id: StringName) -> bool:
	return _market(market_id).is_empty() == false

func markets_for_climates(climates: Array) -> Array:
	# PRD §4.2: four regional markets, each covering a set of climates.
	var out: Array = []
	for id in _markets().keys():
		var region: Variant = _market(id).get("region", [])
		for c in climates:
			if region is Array and str(c) in (region as Array):
				out.append(id)
				break
	return out

func level_factor(level: int) -> float:
	return 1.0 + float(_data.get("level_slope", 0.06)) * float(maxi(1, level))

func base_price(item_id: StringName) -> float:
	var overrides: Dictionary = _data.get("item_base_price", {})
	if overrides.has(str(item_id)):
		return float(overrides[str(item_id)])
	var def := Data.item(item_id)
	if def == null:
		return float(_data.get("default_base_price", 3))
	var bases: Dictionary = _data.get("base_price_tstones", {})
	var aliases: Dictionary = _data.get("category_aliases", {})
	var best := -1.0
	for cat in def.categories:
		var key := str(cat)
		if aliases.has(key):
			key = str(aliases[key])
		if bases.has(key):
			best = maxf(best, float(bases[key]))
	if best < 0.0:
		# ASSUMPTION: a category with no price row is worth the generic base price.
		best = float(_data.get("default_base_price", 3))
	return best

func attribute_multiplier(attributes: Dictionary) -> float:
	var bonus: Dictionary = _data.get("attribute_bonus", {})
	var latent := float(bonus.get("latent", 0.25))
	var rare := float(bonus.get("rare", 1.0))
	var ignore: Array = _data.get("attribute_ignore", [])
	var rare_key := str(_data.get("rare_attribute_key", "rare"))
	var rare_traits: Array = []
	var rare_v: Variant = attributes.get(rare_key)
	if rare_v is Array:
		rare_traits = rare_v
	elif rare_v is String:
		rare_traits = [rare_v]
	elif rare_v is bool and bool(rare_v):
		rare_traits = attributes.keys()
	var mult := 1.0
	for key in attributes.keys():
		var k := str(key)
		if k == rare_key or k in ignore:
			continue
		var v: Variant = attributes[key]
		match typeof(v):
			TYPE_NIL:
				continue
			TYPE_BOOL:
				if not bool(v):
					continue
			TYPE_STRING, TYPE_STRING_NAME:
				if str(v).is_empty():
					continue
			TYPE_INT, TYPE_FLOAT:
				if is_zero_approx(float(v)):
					continue
		mult += rare if k in rare_traits else latent
	return mult

func demand_multiplier(market_id: StringName, item_id: StringName) -> float:
	var m := _market(market_id)
	if m.is_empty():
		return 1.0
	var scarce: Array = m.get("scarce_items", [])
	var abundant: Array = m.get("abundant_items", [])
	if str(item_id) in scarce:
		return float(_data.get("scarce_item_multiplier", 3.0))
	if str(item_id) in abundant:
		return float(_data.get("abundant_item_multiplier", 0.5))
	var demand: Dictionary = m.get("demand", {})
	var def := Data.item(item_id)
	var category := _price_category(item_id)
	var by_cat := float(demand.get("default", 1.0))
	if def != null:
		var best := -1.0
		for cat in def.categories:
			var key := str(cat)
			if demand.has(key) and float(demand[key]) > best:
				best = float(demand[key])
		if best >= 0.0:
			by_cat = best
	elif demand.has(category):
		by_cat = float(demand[category])
	return by_cat

func quality_tier(market_id: StringName, item_id: StringName) -> StringName:
	# Drives the buy-side multiplier: what is abundant here is cheap to buy, what is scarce is dear.
	var m := _market(market_id)
	if str(item_id) in (m.get("scarce_items", []) as Array):
		return &"scarce"
	if str(item_id) in (m.get("abundant_items", []) as Array):
		return &"abundant"
	var d := demand_multiplier(market_id, item_id)
	var tiers: Dictionary = _data.get("buy_tier_demand", {})
	if d >= float(tiers.get("scarce_above", 1.75)):
		return &"scarce"
	if d <= float(tiers.get("abundant_below", 0.75)):
		return &"abundant"
	return &"normal"

# --- price ----------------------------------------------------------------------------------

func saturation(market_id: StringName, item_id: StringName) -> float:
	return float(_saturation.get(_key(market_id, item_id), 1.0))

func price(market_id: StringName, item_id: StringName, level: int = 1, attributes: Dictionary = {}) -> float:
	var p := base_price(item_id) * level_factor(level) * attribute_multiplier(attributes)
	p *= demand_multiplier(market_id, item_id) * saturation(market_id, item_id)
	return snappedf(p, 0.01)

func price_stack(market_id: StringName, stack: ItemStack) -> float:
	if stack == null:
		return 0.0
	return price(market_id, stack.def_id, stack.level, stack.attributes)

func buy_price(market_id: StringName, item_id: StringName, level: int = 1, attributes: Dictionary = {}) -> float:
	var mult: Dictionary = _data.get("buy_multiplier", {})
	var tier := str(quality_tier(market_id, item_id))
	var m := float(mult.get(tier, mult.get("normal", 1.8)))
	return snappedf(price(market_id, item_id, level, attributes) * m, 0.01)

func animal_price(species_base: float, grade: StringName) -> float:
	var mult: Dictionary = _data.get("animal_grade_multiplier", {})
	if not mult.has(str(grade)):
		return 0.0 # unknown grade: refuse rather than guess a multiplier
	return snappedf(species_base * float(mult[str(grade)]), 0.01)

func default_animal_base() -> float:
	# ASSUMPTION: creature data carries no price yet, so an animal's species base is the generic animal base.
	var bases: Dictionary = _data.get("base_price_tstones", {})
	return float(bases.get("animal", 400))

# --- sale side ------------------------------------------------------------------------------

func listing_fee(ask_unit: float, units: int) -> float:
	return snappedf(maxf(0.0, ask_unit) * float(maxi(0, units)) * float(_data.get("listing_fee", 0.05)), 0.01)

func settle_hours(ask_unit: float, price_unit: float) -> float:
	# economy.md: sells instantly at or below the price, ~1 h at +20%, never at +50%.
	if price_unit <= 0.0:
		return NEVER
	var ratio := ask_unit / price_unit
	var at_price := float((_data.get("sell_time_hours", {}) as Dictionary).get("at_price", 0))
	var over_20 := float((_data.get("sell_time_hours", {}) as Dictionary).get("over_20pct", 1))
	if ratio <= 1.0:
		return at_price
	# ASSUMPTION: the slope between the two documented anchors (1.0 -> 0 h, 1.2 -> 1 h) is linear
	# and keeps climbing to the 1.5x hard stop instead of jumping to "never" at 1.2x.
	var h := over_20 * (ratio - 1.0) / 0.2
	if ratio >= 1.5:
		return NEVER
	return snappedf(h, 0.01)

func can_list(market_id: StringName, stack: ItemStack) -> String:
	if stack == null or stack.def_id == &"":
		return "empty"
	if not has_market(market_id):
		return "no_market"
	if stack.is_unstable():
		# PRD §14.5: unstable goods must be cargo-warped home before they can be sold.
		return "unstable"
	return ""

func list_stack(market_id: StringName, stack: ItemStack, ask_unit: float = -1.0) -> Dictionary:
	var refusal := can_list(market_id, stack)
	if refusal != "":
		return {"ok": false, "reason": refusal}
	var unit_price := price_stack(market_id, stack)
	var ask := unit_price if ask_unit < 0.0 else snappedf(ask_unit, 0.01)
	var units := maxi(1, stack.count)
	var fee := listing_fee(ask, units)
	if _balance < fee:
		return {"ok": false, "reason": "no_funds", "fee": fee}
	var hours := settle_hours(ask, unit_price)
	_balance -= fee
	_fees_paid += fee
	var listing := {
		"market": str(market_id),
		"item": str(stack.def_id),
		"units": units,
		"ask": ask,
		"price": unit_price,
		"fee": fee,
		"hours_left": hours,
	}
	_listings.append(listing)
	_settle(0.0) # an ask at or below the computed price sells on the spot
	return {
		"ok": true,
		"sold": hours <= 0.0,
		"reason": "" if hours != NEVER else "never_sells",
		"fee": fee,
		"hours": hours,
		"unit_price": unit_price,
		"ask": ask,
		"units": units,
		"total": snappedf(ask * float(units), 0.01),
	}

func list_animal(market_id: StringName, grade: StringName, species_base: float = -1.0) -> Dictionary:
	if not has_market(market_id):
		return {"ok": false, "reason": "no_market"}
	var base := default_animal_base() if species_base < 0.0 else species_base
	var unit := animal_price(base, grade)
	if unit <= 0.0:
		return {"ok": false, "reason": "bad_grade"}
	var fee := listing_fee(unit, 1)
	if _balance < fee:
		return {"ok": false, "reason": "no_funds", "fee": fee}
	_balance -= fee
	_fees_paid += fee
	_listings.append({
		"market": str(market_id), "item": "animal", "units": 1, "ask": unit,
		"price": unit, "fee": fee, "hours_left": 0.0,
	})
	return {"ok": true, "reason": "", "fee": fee, "price": unit, "hours": 0.0}

func pending_listings() -> int:
	return _listings.size()

func sold_value() -> float:
	return snappedf(_sold_value, 0.01)

# --- buying ---------------------------------------------------------------------------------

func buy(market_id: StringName, item_id: StringName, units: int = 1, level: int = 1, attributes: Dictionary = {}) -> Dictionary:
	if not has_market(market_id):
		return {"ok": false, "reason": "no_market"}
	var unit := buy_price(market_id, item_id, level, attributes)
	var total := snappedf(unit * float(maxi(1, units)), 0.01)
	if _balance < total:
		return {"ok": false, "reason": "no_funds", "cost": total}
	_balance -= total
	return {"ok": true, "reason": "", "unit": unit, "cost": total, "units": maxi(1, units)}

# --- saturation and time --------------------------------------------------------------------

func apply_sale(market_id: StringName, item_id: StringName, units: int) -> float:
	var per := float((_data.get("saturation", {}) as Dictionary).get("per_unit_sold", 0.02))
	var floor_s := float((_data.get("saturation", {}) as Dictionary).get("floor", 0.2))
	var key := _key(market_id, item_id)
	var s := float(_saturation.get(key, 1.0)) * pow(1.0 - per, float(maxi(0, units)))
	_saturation[key] = maxf(floor_s, s)
	return _saturation[key]

func tick(hours: float) -> void:
	if hours > 0.0:
		_recover(float(hours))
	_settle(float(hours))

func _recover(hours: float) -> void:
	var rate := float((_data.get("saturation", {}) as Dictionary).get("recovery_per_hour", 0.1))
	# 10% of the remaining gap per hour, compounding: price == 1 - (1 - saturation) * 0.9^hours.
	var kept := pow(1.0 - rate, hours)
	for key in _saturation.keys():
		var s := float(_saturation[key])
		_saturation[key] = 1.0 - (1.0 - s) * kept

func _settle(hours: float) -> void:
	var still_open: Array[Dictionary] = []
	for listing in _listings:
		var left := float(listing["hours_left"])
		if left == NEVER:
			still_open.append(listing)
			continue
		left -= hours
		if left > 0.0:
			listing["hours_left"] = left
			still_open.append(listing)
			continue
		_sold_value += float(listing["ask"]) * float(listing["units"])
		_balance += float(listing["ask"]) * float(listing["units"])
		if str(listing["item"]) != "animal":
			apply_sale(StringName(str(listing["market"])), StringName(str(listing["item"])), int(listing["units"]))
	_listings = still_open

# --- T-stones -------------------------------------------------------------------------------

func balance() -> float:
	return snappedf(_balance, 0.01)

func credit(amount: float) -> void:
	_balance += amount

func debit(amount: float) -> bool:
	if amount > _balance:
		return false
	_balance -= amount
	return true

func fees_paid() -> float:
	return snappedf(_fees_paid, 0.01)

# --- price memory (M9 save wiring) ----------------------------------------------------------

func state_dict() -> Dictionary:
	return {
		"saturation": _saturation.duplicate(true),
		"listings": _listings.duplicate(true),
		"balance": _balance,
		"fees_paid": _fees_paid,
		"sold_value": _sold_value,
	}

func restore_state(state: Dictionary) -> void:
	var sat: Variant = state.get("saturation", {})
	_saturation = (sat as Dictionary).duplicate(true) if sat is Dictionary else {}
	_listings.clear()
	for row in state.get("listings", []):
		if row is Dictionary:
			_listings.append((row as Dictionary).duplicate(true))
	_balance = float(state.get("balance", 0.0))
	_fees_paid = float(state.get("fees_paid", 0.0))
	_sold_value = float(state.get("sold_value", 0.0))

# --- helpers --------------------------------------------------------------------------------

func _key(market_id: StringName, item_id: StringName) -> String:
	return "%s|%s" % [str(market_id), str(item_id)]

func _markets() -> Dictionary:
	var m: Variant = _data.get("markets", {})
	return m as Dictionary if m is Dictionary else {}

func _market(market_id: StringName) -> Dictionary:
	var row: Variant = _markets().get(str(market_id), {})
	return row as Dictionary if row is Dictionary else {}

func _price_category(item_id: StringName) -> String:
	var def := Data.item(item_id)
	if def == null or def.categories.is_empty():
		return ""
	var aliases: Dictionary = _data.get("category_aliases", {})
	var key := str(def.categories[0])
	return str(aliases.get(key, key))
