class_name DomainRules
extends RefCounted
## Spec 29 domain configuration (game/data/world/domains.json): cell size, the Tamed Island cap and
## its documented Pioneer-rank milestones. Every number the PRD gives is data here; nothing in this
## file tunes gameplay balance. A domain record itself lives on the island runtime (IslandClaims).

const PATH := "res://data/world/domains.json"
## Fallbacks when the json is missing so a broken data file never removes the cap.
const DEFAULTS := {
	"cell_tiles": 4,
	"tamed_island": {"start_cap": 13, "rank_caps": {"1": 13, "2": 17, "6": 23, "7": 30}},
}

static var _config: Dictionary = {}

static func config() -> Dictionary:
	if _config.is_empty():
		var parsed: Variant = null
		if FileAccess.file_exists(PATH):
			var f := FileAccess.open(PATH, FileAccess.READ)
			if f:
				parsed = JSON.parse_string(f.get_as_text())
		_config = (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}
		for key in DEFAULTS:
			var want: Variant = DEFAULTS[key]
			if not _config.has(key):
				_config[key] = (want as Dictionary).duplicate(true) if want is Dictionary else want
	return _config

## World tiles along one side of a claim cell (spec 29 section 3: 4 by default).
static func cell_tiles() -> int:
	var n := int(config().get("cell_tiles", 4))
	return n if n > 0 else 4

static func tamed_island() -> Dictionary:
	var row: Variant = config().get("tamed_island", {})
	return row as Dictionary if row is Dictionary else {}

## The Tamed Island's documented starting cap (spec 29 section 4: 13).
static func start_cap() -> int:
	return maxi(1, int(tamed_island().get("start_cap", 13)))

static func rank_caps() -> Dictionary:
	var row: Variant = tamed_island().get("rank_caps", {})
	return row as Dictionary if row is Dictionary else {}

## The player's Pioneer rank for cap purposes: the survivor's own level (World.pioneer_level, which
## starts at 0 and so reads as spec 29's rank 1) or the rank the Personal Communications Center has
## raised the island to, whichever is higher. Only the center's track (DOMAIN-D) changes it by
## contributing; nothing here claims land.
static func pioneer_rank() -> int:
	CommCenter.register_blueprint()  # the center's build blueprint (data/world/comm_center.json)
	return maxi(1, maxi(int(World.pioneer_level), CommCenter.rank()))

## Claim cap at a Pioneer rank: the highest documented milestone at or below it (a rank between two
## milestones keeps the previous cap, spec 29 section 4), never below the starting cap.
static func cap_for_rank(rank: int) -> int:
	var caps := rank_caps()
	var best_rank := 0
	var best_cap := 0
	for key in caps:
		var r := int(str(key))
		var c := int(caps[key])
		if c <= 0 or r > rank:
			continue
		if r > best_rank or (r == best_rank and c > best_cap):
			best_rank = r
			best_cap = c
	return maxi(start_cap() if best_cap <= 0 else best_cap, start_cap())

## Cap for this survivor now.
static func cap() -> int:
	return cap_for_rank(pioneer_rank())

## Every documented milestone, for the Domain screen's "next at rank N" line.
static func next_milestone(rank: int) -> Array:
	var best := Vector2i(-1, 0)
	for key in rank_caps():
		var r := int(str(key))
		if r > rank and (best.x < 0 or r < best.x):
			best = Vector2i(r, int(rank_caps()[key]))
	return [best.x, best.y]
