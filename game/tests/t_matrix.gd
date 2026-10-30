extends SceneTree
## ISLAND RESOURCES M5 gate (docs/design/island-resources.md sections 4.2, 4.3 and 6):
##   1. The ladder audit: prints the earliest island level for each tool rung and fails when a rung has
##      no source at or below its intended level. A source is a node family a climate grows, either in
##      its ambient "vegetation" or in one of its landmark rows (a row's "min_tier" counts), on an island
##      islands.json lists, harvested with the pick the family's min_pick_tier names (that pick's rung must
##      be reachable by then too). The start islands (home, tutorial) count as level 1.
##   2. Every climate has at least one signature rare: an item its families yield that no other
##      climate's families yield.
##   3. Iron ore is reachable below level 60 (decision A5/A6) and only black iron stays volcanic-only.
## Pure data: reads the JSON directly, no autoloads, no island build.
## Run: Godot --headless --path game --script res://tests/t_matrix.gd -> "[t_matrix] PASS", 0/1.

const D := "res://data/"
const RUNGS := ["stone", "bone", "flint", "obsidian", "copper", "bronze", "iron", "steel"]
## The materials each rung's gear is made from (recipes.json: the smelt/alloy/refine chain).
## Bone comes from any hunt, so it has no node source and counts from level 1.
const RUNG_INPUTS := {
	"stone": ["stone"],
	"bone": [],
	"flint": ["flint"],
	"obsidian": ["obsidian"],
	"copper": ["copper_ore_mat"],
	"bronze": ["copper_ore_mat", "tin_ore"],
	"iron": ["iron_ore"],
	"steel": ["iron_ore"],  # refine_steel takes tier_iron + fuel
}
## The intended earliest level per rung: the island tier the doc's section 4.3 places it on # ASSUMPTION
## for steel, which follows iron.
const INTENDED := {"stone": 1, "bone": 1, "flint": 20, "obsidian": 25, "copper": 35, "bronze": 35, "iron": 40, "steel": 40}
const START_ISLANDS := ["home_grassland", "tutorial_isle"]

var _fails: PackedStringArray = []

func _init() -> void:
	_run()
	if _fails.is_empty():
		print("[t_matrix] PASS")
		quit(0)
	else:
		print("[t_matrix] FAIL count=%d" % _fails.size())
		quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_matrix] FAIL %s" % what)

func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(D + path))

func _run() -> void:
	var families: Dictionary = _json("nature_manifest.json")["families"]
	var climates: Dictionary = _json("world/climates.json")
	var landmarks: Dictionary = (_json("world/landmarks.json") as Dictionary).get("climates", {})
	var islands: Dictionary = _json("world/islands.json")
	var items_raw: Variant = _json("items.json")
	var item_rows: Array = items_raw["items"] if items_raw is Dictionary else items_raw
	# id -> the categories it satisfies (its own id included, so a slot may name either).
	var cats := {}
	for row in item_rows:
		var r: Dictionary = row
		var set := {str(r["id"]): true}
		for c in r.get("categories", []):
			set[str(c)] = true
		cats[str(r["id"])] = set
	# Island levels per climate.
	var levels := {}  # climate -> Array[int]
	for id in islands:
		if not (islands[id] is Dictionary):
			continue
		var row: Dictionary = islands[id]
		var lv := 1 if id in START_ISLANDS else int(row.get("tier", 1))
		var cl := str(row.get("climate", ""))
		if not levels.has(cl):
			levels[cl] = []
		(levels[cl] as Array).append(lv)
	levels["grassland"] = (levels.get("grassland", []) as Array) + [1]  # tutorial isle
	# Every (family, earliest level) a climate offers: ambient at the climate's lowest island, a landmark
	# row at the lowest island at or above its min_tier.
	var offers := {}  # climate -> {family: earliest level}
	for cl in climates:
		if not (climates[cl] is Dictionary):
			continue
		var got := {}
		var lvls: Array = levels.get(cl, [])
		if lvls.is_empty():
			offers[cl] = got
			continue
		var lowest: int = lvls.min()
		for fam in (climates[cl] as Dictionary).get("vegetation", []):
			_offer(got, str(fam), lowest)
		for lrow in landmarks.get(cl, []):
			var min_t := int((lrow as Dictionary).get("min_tier", 0))
			var at := 1000
			for l in lvls:
				if int(l) >= min_t:
					at = mini(at, int(l))
			if at == 1000:
				continue
			for fam in ((lrow as Dictionary).get("nodes", {}) as Dictionary):
				_offer(got, str(fam), at)
		offers[cl] = got
	# 1. Ladder audit, rung by rung (each pick gate looks up a rung below it).
	var rung_at := {}
	print("[t_matrix] ladder: rung  earliest  intended  source")
	for rung in RUNGS:
		var at := 1
		var why := "hunt / start"
		for cat in RUNG_INPUTS[rung]:
			var best := 1000
			var best_src := "none"
			for cl in offers:
				for fam in offers[cl]:
					var f: Dictionary = families.get(fam, {})
					var gate: Dictionary = f.get("min_pick_tier", {})
					for item in (f.get("harvest", {}) as Dictionary):
						if not (cats.get(str(item), {}) as Dictionary).has(cat):
							continue
						var lv: int = offers[cl][fam]
						var pick := str(gate.get(str(item), ""))
						if pick != "":
							lv = maxi(lv, int(rung_at.get(pick, 1000)))
						if lv < best:
							best = lv
							best_src = "%s %s on %s" % [item, fam, cl]
			if best > at or why == "hunt / start":
				why = best_src
			at = maxi(at, best)
		rung_at[rung] = at
		print("[t_matrix]   %-9s %4d  %4d  %s" % [rung, at, int(INTENDED[rung]), why])
		_expect(at <= int(INTENDED[rung]), "rung %s has a source at level %d, intended %d or lower" % [rung, at, int(INTENDED[rung])])
	# 2. Signature rares.
	var yields := {}  # climate -> {item: true}
	for cl in offers:
		var s := {}
		for fam in offers[cl]:
			for item in ((families.get(fam, {}) as Dictionary).get("harvest", {}) as Dictionary):
				s[str(item)] = true
		yields[cl] = s
	for cl in yields:
		if (offers[cl] as Dictionary).is_empty():
			continue  # a climate with no island row grows nothing yet
		var own: Array = []
		for item in yields[cl]:
			var elsewhere := false
			for other in yields:
				if other != cl and (yields[other] as Dictionary).has(item):
					elsewhere = true
					break
			if not elsewhere:
				own.append(item)
		own.sort()
		print("[t_matrix] signature %s: %s" % [cl, ", ".join(PackedStringArray(own)) if not own.is_empty() else "-"])
		_expect(not own.is_empty(), "climate %s has a signature rare no other climate yields" % cl)
	# 3. Iron below 60; black iron stays volcanic.
	_expect(int(rung_at["iron"]) < 60, "iron is reachable below level 60 (%d)" % int(rung_at["iron"]))
	_expect(cats.has("iron_ore"), "an iron_ore item exists")
	for cl in yields:
		if cl != "volcanic":
			_expect(not (yields[cl] as Dictionary).has("black_iron"), "black iron stays volcanic-only (%s)" % cl)

func _offer(got: Dictionary, fam: String, lv: int) -> void:
	got[fam] = mini(int(got.get(fam, 1000)), lv)
