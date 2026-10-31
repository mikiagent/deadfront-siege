class_name WorldFacade
extends RefCounted
## What the intent handlers may ask of the island and tell it. This base class is a plain
## in-memory island (tests, labs, the fuzz); W3-SRVWORLD subclasses it over IslandRuntime and
## overrides every method below with the same shapes.
## Reads return plain JSON data (positions as [x, y, z], {} when the thing does not exist):
## IntentHandlers journals what it read, so a replay never needs the island. Writes return
## nothing: the handler has already validated the change and owns every id it creates.

var nodes := {}      ## node_id -> {pos, level, unstable, family, attributes, options: [{item, tool, min, max, left}]}
var corpses := {}    ## corpse_id -> {pos, slots: [ItemStack dict | null]}
var creatures := {}  ## net_id -> {species, variant, pos, hp, hp_max, knocked, defense, dodge, feeds, cooldown, pet, genetics?}
var stations := {}   ## station_id -> [[x, y, z], ...]
var structures := {} ## structure_id -> {kind, cell, rot, owner}
var blocked_cells := {} ## "x,z" -> reason, for placement refusals

# --- reads -------------------------------------------------------------------------------

func node(node_id: String) -> Dictionary:
	return (nodes.get(node_id, {}) as Dictionary).duplicate(true)

func corpse(corpse_id: String) -> Dictionary:
	return (corpses.get(corpse_id, {}) as Dictionary).duplicate(true)

func creature(net_id: String) -> Dictionary:
	return (creatures.get(net_id, {}) as Dictionary).duplicate(true)

## {"ok": bool}: is a station of this kind within reach of pos.
func station_near(station_id: String, pos: Array, reach: float) -> Dictionary:
	for p in stations.get(station_id, []):
		if v3(p).distance_to(v3(pos)) <= reach:
			return {"ok": true}
	return {"ok": false}

## {"why": ""} when `kind` may go at `cell` with `rot` for a survivor standing at pos.
## shortcut: one cell per structure here; W3 answers with BuildGrid.can_place (footprints, claim, reach).
func placement(_kind: String, cell: Array, _rot: int, _pos: Array) -> Dictionary:
	var key := "%d,%d" % [int(cell[0]), int(cell[1])]
	if blocked_cells.has(key):
		return {"why": str(blocked_cells[key])}
	for s: Dictionary in structures.values():
		if int(s.cell[0]) == int(cell[0]) and int(s.cell[1]) == int(cell[1]):
			return {"why": "overlap"}
	return {"why": ""}

# --- writes ------------------------------------------------------------------------------

func take_node_unit(node_id: String, item: String) -> void:
	for o: Dictionary in nodes[node_id].options:
		if str(o.item) == item:
			o.left = maxi(0, int(o.left) - 1)

func take_corpse(corpse_id: String, slot: int, count: int) -> void:
	var slots: Array = corpses[corpse_id].slots
	var row: Dictionary = slots[slot]
	row.count = int(row.count) - count
	if int(row.count) <= 0:
		slots[slot] = null

func damage_creature(net_id: String, amount: float) -> void:
	var c: Dictionary = creatures[net_id]
	c.hp = maxf(0.0, float(c.hp) - amount)

## A feed landed. W3 also extends the knockdown by FieldTame.KNOCKDOWN_EXTEND, as apply_feed does.
func set_tame_feeds(net_id: String, feeds: float) -> void:
	creatures[net_id].feeds = feeds

## The wild creature became the account's asset `asset_uid` (a pet, or a captured_animal
## stack); it leaves the wild roster.
func bond_creature(net_id: String, _asset_uid: String, _account: int) -> void:
	creatures.erase(net_id)

## A net missed: the knockdown ends (CaptureSystem also enrages the creature).
func fail_capture(net_id: String) -> void:
	creatures[net_id].knocked = false

func place(kind: String, cell: Array, rot: int, account: int, structure_id: String) -> void:
	structures[structure_id] = {"kind": kind, "cell": cell.duplicate(), "rot": rot, "owner": account}

# --- helpers for tests and labs --------------------------------------------------------

func add_node(node_id: String, pos: Vector3, options: Array, level: int = 1, family: String = "") -> void:
	nodes[node_id] = {"pos": arr(pos), "level": level, "unstable": false, "family": family, "attributes": {"level": level}, "options": options.duplicate(true)}

## `torpor` is the fraction of the bar (Creature.torpor_frac()), 0..1.
func add_creature(net_id: String, species: String, pos: Vector3, hp: float, extra: Dictionary = {}) -> void:
	var c := {"species": species, "variant": "", "pos": arr(pos), "hp": hp, "hp_max": hp, "knocked": false, "torpor": 0.0, "defense": 10.0, "dodge": 0.04, "feeds": 0.0, "cooldown": 0.0, "pet": false, "alpha": false}
	c.merge(extra, true)
	creatures[net_id] = c

static func v3(p: Variant) -> Vector3:
	if p is Array and (p as Array).size() >= 3:
		return Vector3(float(p[0]), float(p[1]), float(p[2]))
	return Vector3.ZERO

static func arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]
