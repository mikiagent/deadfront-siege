class_name MarketFormat
extends RefCounted
## Pure helpers for the market screens: number grouping, player-facing error text, the row model of
## a listing view, the market categories and the cage-able clades. No nodes, no state, no ops.

const QUERY := "res://scripts/economy/market_query.gd"
## Market category -> title where id.capitalize() reads wrong.
const TITLES := {"animal": "Animals", "food_raw": "Raw Food", "food_cooked": "Cooked Food"}
## Clade -> the short "<name> Type" row of the Animals column.
# ASSUMPTION (exchange-spec A3): short forms of the real clades; no invented species (no Avian/Wolf).
const CLADE_NAMES := {
	"Dromaeosauridae": "Raptor", "Ceratopsia": "Ceratops", "Tyrannosauridae": "Tyrant",
	"Machairodontinae": "Sabertooth", "Cervidae": "Megalo", "Stegosauridae": "Stego",
	"Ankylosauridae": "Ankylo", "Ornithomimidae": "Mimid", "Coelophysoidea": "Coelo",
	"Compsognathidae": "Compy", "Neotheropoda": "Dilo",
}
const ERRORS := {
	"offline": "The Island Market needs a connection to the game server.",
	"timeout": "No answer from the server. Retrying…",
	"insufficient_funds": "Not enough tradable T-stones.",
	"self_trade": "That is your own listing.",
	"expired": "No longer available.",
	"not_found": "No longer available.",
	"closed": "No longer available.",
	"not_owner": "Not your listing.",
	"invalid_asset": "This can't be sold on the market.",
	"bag_full": "Your bag is full.",
	"rate_limited": "Too fast, try again.",
	"server_error": "The market is busy finishing a trade. Try again shortly.",
}

static var _cats: Array = []
static var _base: Dictionary = {}
static var _alias: Dictionary = {}

## 27927 -> "27,927".
static func group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out

## What the player reads for a failed op; the server's own words follow when they add something
## (limit_reached says which limit: trade lock, 50 listings, a full vault).
static func error_text(res: Dictionary) -> String:
	var err := str(res.get("err", ""))
	var msg := str(res.get("msg", ""))
	if err == "limit_reached":
		return msg.left(1).to_upper() + msg.substr(1) + "." if msg != "" else "A market limit was reached."
	var head := str(ERRORS.get(err, "Something went wrong."))
	if err in ["offline", "expired", "not_found", "closed", "self_trade"] or msg == "":
		return head
	return "%s (%s)" % [head, msg]

## True when the listing is gone and its row should leave the table.
static func is_gone(res: Dictionary) -> bool:
	return str(res.get("err", "")) in ["expired", "not_found", "closed"]

## What a table row shows for one listing view (one instance, never a merged stack).
static func row(v: Dictionary) -> Dictionary:
	var a: Dictionary = v.get("asset", {})
	var m := {"id": str(v.get("id", "")), "uid": str(a.get("uid", "")), "price": int(v.get("unit_price", v.get("price", 0))),
		"count": int(v.get("left", 1)), "level": int(a.get("level", 1)), "dur": "—", "badge": false, "tint": Color.WHITE}
	if str(v.get("type", "")) == "pet":
		var sp := str(a.get("species", ""))
		m.icon = &"tamed_animal"
		m.badge = true
		m.name = species_name(sp)
		m.type = m.name
		return m
	var def_id := str(a.get("id", ""))
	var stack := ItemStack.from_dict(Provenance.strip(a))
	m.icon = StringName(def_id)
	m.tint = stack.tint_color()
	if def_id == AssetValidator.CAGE:
		var sp := str((a.get("attributes", {}) as Dictionary).get("species", ""))
		m.name = "Captured %s" % species_name(sp)
		m.type = species_name(sp)
		return m
	var def := Data.item(StringName(def_id))
	m.name = def.display_name if def else def_id.capitalize()
	m.type = category_title(market_category(def)) if def else ""
	if stack.max_durability > 0:
		m.dur = "%d/%d" % [stack.durability, stack.max_durability]
	return m

static func species_name(sp: String) -> String:
	var c := Data.creature(StringName(sp))
	return c.species if c and c.species != "" else sp.capitalize()

static func category_title(id: String) -> String:
	return str(TITLES.get(id, id.capitalize()))

## The market category an item sells under (Settlers' rule: its own category, else the alias).
static func market_category(def: ItemDef) -> String:
	if def == null:
		return ""
	if str(def.id) == AssetValidator.CAGE:
		return "animal"
	if _base.is_empty():
		_base = EconRules.read_json("res://data/world/market.json").get("base_price_tstones", {})
		_alias = EconRules.load_default().g("category_alias")
	return Settlers.market_category(def, _base, _alias)

## The search sheet's categories: market.json's price keys in their order.
# ASSUMPTION: unstable_loot is left out (unstable items cannot be listed, economy.md:46), and every
# other category shows even when empty (an empty table says so) instead of 20 count requests per open.
static func categories() -> Array:
	if _cats.is_empty():
		for k: String in EconRules.read_json("res://data/world/market.json").get("base_price_tstones", {}):
			if k != "unstable_loot":
				_cats.append(k)
	return _cats

## Item defs that sell under `cat` (the category column's rows), by display name.
static func defs_in(cat: String) -> Array:
	var denied: Array = EconRules.load_default().g("denied_defs")
	var out: Array = []
	for id: StringName in Data.items:
		var def: ItemDef = Data.items[id]
		if str(id) not in denied and str(id) != AssetValidator.CAGE and market_category(def) == cat:
			out.append(def)
	out.sort_custom(func (x: ItemDef, y: ItemDef) -> bool: return x.display_name < y.display_name)
	return out

## Clades of species that can be caged (bonded or captured), each once, by row title.
static func clades() -> Array:
	var seen := {}
	for id: StringName in Data.creatures:
		var c: CreatureDef = Data.creatures[id]
		if (c.tameable or c.capture_tier > 0) and CLADE_NAMES.has(c.clade):
			seen[c.clade] = "%s Type" % CLADE_NAMES[c.clade]
	var out: Array = []
	for k: String in seen:
		out.append({"clade": k, "title": seen[k]})
	out.sort_custom(func (x: Dictionary, y: Dictionary) -> bool: return str(x.title) < str(y.title))
	return out

## Search sorts the server offers (MarketQuery ships with the client); the screens never sort a page.
static func sorts() -> Array:
	return _const("SORTS", [])

## Search filters the server takes beyond the base set (hook H2 adds market_category, clade, def_id).
static func has_filter(f: String) -> bool:
	return f in _const("FILTERS", [])

static func _const(name: String, fallback: Variant) -> Variant:
	var s := load(QUERY) as Script
	return s.get_script_constant_map().get(name, fallback) if s else fallback
