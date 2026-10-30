class_name Factions
extends RefCounted
## FACTIONS (owner 2026-10-29, docs/design/factions.md): the five support organisations of systems PRD
## §15.1 as factions. Reputation points per faction; rank n needs rank_k * n * (n + 1) points (10 ranks,
## PRD); tiers group ranks and carry a title. A new rank pays once: the crate band's items (crate
## factions) or rank_sp skill points (Radio University: no crates, PRD). Missions are Tasks rows
## (category "faction": Tasks.offers / accept / abandon / claim); Receive calls add_rep.
## State is static (one survivor per client) and saved as the "factions" block (to_dict / from_dict).

const PATH := "res://data/world/factions.json"
const RANKS := 10

static var rep: Dictionary = {}  ## faction id -> reputation points
static var _defs: Dictionary = {}

static func defs() -> Dictionary:
	if _defs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_defs = parsed if parsed is Dictionary else {"_bad": true}
	return _defs

## Faction ids in file order.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for k in defs():
		if not str(k).begins_with("_") and defs()[k] is Dictionary:
			out.append(str(k))
	return out

static func def(id: String) -> Dictionary:
	var d: Variant = defs().get(id, {})
	return d if d is Dictionary else {}

static func rule(key: String, dflt: Variant) -> Variant:
	return (defs().get("_rules", {}) as Dictionary).get(key, dflt)

static func reset() -> void:
	rep = {}

static func points(id: String) -> int:
	return int(rep.get(id, 0))

## Reputation needed for rank `n` (0 for rank 0).
static func rank_need(n: int) -> int:
	return int(rule("rank_k", 25)) * n * (n + 1)

static func rank_of_points(pts: int) -> int:
	var r := 0
	while r < RANKS and pts >= rank_need(r + 1):
		r += 1
	return r

static func rank(id: String) -> int:
	return rank_of_points(points(id))

## Tier index (0..4) of `rank`: the last tiers row whose first rank it reached.
static func tier_of_rank(r: int) -> int:
	var t := 0
	var rows: Array = rule("tiers", [[0, "Stranger"]])
	for i in rows.size():
		if r >= int((rows[i] as Array)[0]):
			t = i
	return t

## The title of `id`'s current tier: "Stranger" at tier 0, else the faction's own title.
static func title(id: String) -> String:
	var t := tier_of_rank(rank(id))
	var titles: Array = def(id).get("titles", [])
	if t == 0 or titles.size() < t:
		return str((rule("tiers", [[0, "Stranger"]]) as Array)[0][1])
	return str(titles[t - 1])

## The faction's doors are open to a survivor of `level` (PRD unlock levels).
static func unlocked(id: String, level: int) -> bool:
	return level >= int(def(id).get("unlock_level", 0))

static func char_level(p: Player) -> int:
	return p.skills.character_level() if p != null and p.skills != null else 1

## The crate band key ("1-3") that holds `r` (rank 0 reads the first band: what rank 1 unlocks).
static func crate_band(f: Dictionary, r: int) -> String:
	var bands: Dictionary = f.get("crate_bands", {})
	for key in bands.keys():
		var parts := str(key).split("-")
		if parts.size() == 2 and maxi(r, 1) >= int(parts[0]) and maxi(r, 1) <= int(parts[1]):
			return str(key)
	return str(bands.keys()[0]) if not bands.is_empty() else ""

## What reaching rank `r` of `id` pays: {"items": [ids], "sp": n}.
static func rank_unlock(id: String, r: int) -> Dictionary:
	var f := def(id)
	if bool(f.get("crates", false)):
		return {"items": (f.get("crate_bands", {}) as Dictionary).get(crate_band(f, r), []), "sp": 0}
	return {"items": [], "sp": int(rule("rank_sp", 1))}

## Adds `n` reputation to `id` and pays every rank it crosses (crate items into the bag, what does not
## fit into home cargo; or SP). Returns the ranks gained, in order (empty when none).
static func add_rep(id: String, n: int, p: Player) -> Array[int]:
	var gained: Array[int] = []
	if n <= 0 or def(id).is_empty():
		return gained
	var before := rank(id)
	rep[id] = points(id) + n
	for r in range(before + 1, rank(id) + 1):
		gained.append(r)
		var u := rank_unlock(id, r)
		for item_id in u["items"]:
			var st := ItemStack.make(StringName(str(item_id)), 1)
			if st == null:
				continue
			var left := p.inventory.add(st) if p != null and p.inventory != null else 1
			if left > 0:
				World.cargo_home.add(st)
		if int(u["sp"]) > 0 and p != null and p.skills != null:
			p.skills.sp_extra += int(u["sp"])
			p.skills.sp_now()
		print("[factions] %s rank %d (%s)" % [id, r, title(id)])
	return gained

# ---------------------------------------------------------------- save

static func to_dict() -> Dictionary:
	return {"rep": rep.duplicate()}

## `v` is the save's "factions" block; an older save has none and loads with no reputation.
static func from_dict(v: Variant) -> void:
	rep = {}
	if not v is Dictionary or not (v as Dictionary).get("rep") is Dictionary:
		return
	var r: Dictionary = v["rep"]
	for k in r:
		if def(str(k)).is_empty() or not (r[k] is int or r[k] is float):
			continue
		rep[str(k)] = clampi(int(r[k]), 0, 1000000)
