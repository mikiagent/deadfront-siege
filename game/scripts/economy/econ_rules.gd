class_name EconRules
extends RefCounted
## Market numbers (data/economy/market_rules.json) and abuse caps (limits.json). Kept as the
## parsed dictionaries so a test can override one value; `g` refuses unknown keys loudly.

var market: Dictionary = {}
var limits: Dictionary = {}

static func load_default() -> EconRules:
	var r := EconRules.new()
	# JSON parses every number as float; integral ones become ints so `in` and == behave.
	r.market = Ledger.norm(read_json("res://data/economy/market_rules.json"))
	r.limits = Ledger.norm(read_json("res://data/economy/limits.json"))
	return r

func g(key: String) -> Variant:
	if market.has(key):
		return market[key]
	if limits.has(key):
		return limits[key]
	push_error("[econ] missing rule %s" % key)
	return 0

func num(key: String) -> int:
	return int(g(key))

## Fractions become basis points so every fee is exact integer maths.
func bp(key: String) -> int:
	return roundi(float(g(key)) * 10000.0)

func settler(key: String) -> Variant:
	return (market.get("settlers", {}) as Dictionary).get(key, 0)

## Round-up share of `amount`, never more than the amount itself.
static func ceil_bp(amount: int, bps: int) -> int:
	return mini(amount, (amount * bps + 9999) / 10000)

func deposit_cap(def_id: String) -> int:
	var caps: Dictionary = limits.get("deposit_caps", {})
	return int(caps.get(def_id, limits.get("deposit_default_cap", 0)))

static func read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[econ] cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
