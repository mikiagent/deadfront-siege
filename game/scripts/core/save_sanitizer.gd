class_name SaveSanitizer
extends RefCounted
## Trust boundary for save files. The JSON on disk is user-editable, so after migration every
## field the loader reads is coerced to its type, unknown ids are dropped and numbers are clamped
## to what play can reach. A save written by this build passes through unchanged. Anything missed
## here and aborting clean() itself is caught by the CHECKED sentinel; a callee that aborts during
## SaveGame._apply is not caught in general, so every field a from_dict casts must be shaped here.

const MAX_LEVEL := 60
const MAX_T_STONES := 100000 # ASSUMPTION: no shipped faucet comes near this; it only stops forged balances
const WORLD_LIMIT := 2000.0 # ASSUMPTION: metres from the island origin; islands are a few hundred across
const DEFAULT_POSITION := [0.0, 1.0, 12.0] # the loader's own fallback spawn
const MAX_CLAIM_TILES := 14 # IslandRuntime.claim_at's plot side; a bigger rect is forged
const SLOT_LOCK := "_slot_lock" # placeholder Inventory.add writes behind a multi-slot item
## Set by clean() as its last statement: SaveMigrations.read applies only data that carries it.
const CHECKED := "__sanitized"
## Test hook: makes clean() hit a script error just before CHECKED, as a missed edge case would.
static var abort_for_test := false

## Expected type of each field the loader reads; the value is only a type sample. A field of the
## wrong type is erased so the loader's own default applies.
const SHAPE := {
	"player": {"vitals": {}, "statuses": [], "inventory": [], "inventory_extras": {"equipment": {}, "quick_food": [], "tool_index": 0}, "position": []},
	"pets": [], "ground_snares": [], "skills": {}, "skills_v2": {},
	"home": {"terrain": "", "buildings": [], "cargo": [], "claims": [], "camp_layout": {}},
	"away": {"buildings": [], "claims": []}, "pending_refunds": [],
	"pioneer_xp": 0, "pioneer_level": 0, "pioneer_crafts": {}, "pioneer_buildings": {},
	"player_name": "", "occupation": "", "t_stones": 0, "visited_islands": {}, "raid_victory": false,
	"objective": 0, "objective_best": 0, "island_id": "",
	"unstable": {"remaining": 0.0, "harvested": {}, "crater_discovered": false},
	"clock": 0.0, "saved_unix": 0,
}
## Fields the building from_dicts read with int()/float()/bool() (placed_building, bonfire,
## field_plot, field_catapult, taming_pen, craft_station). Strings go through str(), which takes anything.
## "open" is the overhaul tip's gate flag (placed_building.gd), listed ahead of the merge.
const BUILDING_ROW := {
	"kind": "", "rot": 0, "x": 0.0, "z": 0.0, "sleeps_left": 0, "hp": 0.0, "reload_left": 0.0,
	"seconds_left": 0.0, "growth": 0.0, "watered": 0.0, "fertilizer": 0.0, "fertilizer_overflow": 0.0,
	"remaining": 0.0, "cargo": false, "running": false, "mature": false, "failed": false, "open": false,
}
const SNARE_ROW := {"heavy": false, "life_left": 0.0, "arm_left": 0.0}
const STATUS_ROW := {"id": "", "stacks": 0, "time_left": 0.0}
const CAMP_ROW := {"rot": 0}
## CreatureGenetics.from_dict reads these parts with .get() and casts each leaf with int().
const GENETICS := {"ivs": {}, "evs": {}, "level_gains": {}}
## PetRecord.from_dict and CreatureGenetics.from_dict cast these with float()/int(). tamed_at and
## wild_level are the overhaul tip's (W1-TAME), listed ahead of the merge.
const PET_ROW := {
	"hunger": 0.0, "hunger_max": 0.0, "hunger_efficiency": 0.0, "xp_rate": 0.0, "hp": 0.0,
	"attack": 0.0, "defense": 0.0, "ranged_defense": 0.0, "ranged_attack": 0.0, "accuracy": 0.0,
	"speed": 0.0, "level": 0, "xp": 0.0, "respawn_left": 0.0, "tamed_role": [], "bag": [],
	"tamed_at": 0, "wild_level": 0, "genetics": GENETICS,
}
## Stack attributes read with int() (taming pen, hunt, material tier) or handed to
## CreatureGenetics.from_dict (taming pen, tamed animal release).
const ATTR_ROW := {"grade_seed": 0, "barbed_hits": 0, "toxin_hits": 0, "hardness": 0, "genetics": GENETICS}

static func clean(data: Dictionary) -> Dictionary:
	_shape(data, SHAPE)
	var player: Dictionary = data.get("player", {})
	if player.has("inventory"):
		player["inventory"] = stacks(player["inventory"])
	var extras: Dictionary = player.get("inventory_extras", {})
	var equipment: Variant = extras.get("equipment", {})
	if equipment is Dictionary:
		for slot in (equipment as Dictionary).keys():
			if Data.item(StringName(str(equipment[slot]))) == null:
				(equipment as Dictionary).erase(slot)
	if player.has("position") and not _is_position(player["position"]):
		player["position"] = DEFAULT_POSITION.duplicate()
	var vitals: Dictionary = player.get("vitals", {})
	for key in vitals.keys():
		var v: float = _num(vitals[key], 0.0, 1000000.0, NAN)
		if is_nan(v):
			vitals.erase(key) # not a number: Vitals.from_dict keeps its current value
		else:
			vitals[key] = v
	if player.has("statuses"):
		player["statuses"] = _rows(player["statuses"], STATUS_ROW)
	var home: Dictionary = data.get("home", {})
	if home.has("cargo"):
		home["cargo"] = stacks(home["cargo"])
	var layout: Dictionary = home.get("camp_layout", {})
	for key in layout.keys():
		var row: Variant = layout[key]
		if not row is Dictionary or ((row as Dictionary).has("cell") and not _is_cell((row as Dictionary)["cell"])):
			layout.erase(key)
		else:
			_shape(row, CAMP_ROW)
	if data.has("pending_refunds"):
		data["pending_refunds"] = _buildings(data["pending_refunds"])
	for block in [home, data.get("away", {})]:
		if (block as Dictionary).has("buildings"):
			block["buildings"] = _buildings(block["buildings"])
		if (block as Dictionary).has("claims"):
			block["claims"] = (block["claims"] as Array).filter(func (r: Variant) -> bool:
				return r is Array and (r as Array).size() >= 4 and _all_numbers((r as Array).slice(0, 4)) \
					and absf(r[0]) <= WORLD_LIMIT and absf(r[1]) <= WORLD_LIMIT \
					and r[2] >= 1 and r[2] <= MAX_CLAIM_TILES and r[3] >= 1 and r[3] <= MAX_CLAIM_TILES)
	if data.has("pets"):
		data["pets"] = _pets(data["pets"])
	if data.has("ground_snares"):
		data["ground_snares"] = _rows(data["ground_snares"], SNARE_ROW).filter(func (r: Variant) -> bool:
			return _is_position((r as Dictionary).get("position")))
	if data.has("skills_v2"):
		_skills(data["skills_v2"], _int(data.get("pioneer_level", 0), 0, SkillState.MAX_LEVEL - 1))
	if data.has("skills"):
		data["skills"] = _legacy_survival(data["skills"], data.get("skills_v2", {}))
	if data.has("t_stones"):
		data["t_stones"] = _int(data["t_stones"], 0, MAX_T_STONES)
	for key in ["pioneer_level", "pioneer_xp", "objective", "objective_best"]:
		if data.has(key):
			data[key] = _int(data[key], 0, 1000000000)
	if data.has("saved_unix"):
		data["saved_unix"] = _int(data["saved_unix"], 0, int(Time.get_unix_time_from_system()))
	if data.has("island_id") and not World.islands.has(str(data["island_id"])):
		data["island_id"] = "home_grassland"
	if abort_for_test:
		var none: Object = null
		none.call("abort") # a real script error, so the test exercises the engine's abort path
	data[CHECKED] = true
	return data

## One bag as Inventory.to_array writes it. Slot positions are kept (dropped stacks become null).
static func stacks(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		out.append(_stack(row))
	for i in out.size():
		var s: Variant = out[i]
		if s is Dictionary and str(s.get("id", "")) == SLOT_LOCK:
			var attrs: Variant = s.get("attributes", {})
			var anchor := int(_num(attrs.get("anchor", -1), -1.0, float(out.size()), -1.0)) if attrs is Dictionary else -1
			var held: Variant = out[anchor] if anchor >= 0 and anchor < out.size() else null
			if not held is Dictionary or str(held.get("id", "")) == SLOT_LOCK:
				out[i] = null # its anchor item was dropped; a lone lock would block the slot forever
	return out

static func _stack(row: Variant) -> Variant:
	if not row is Dictionary:
		return null
	var s: Dictionary = row
	var id := str(s.get("id", ""))
	if id == SLOT_LOCK:
		return s
	var def := Data.item(StringName(id))
	if def == null:
		return null
	if s.has("count"):
		var count := _num(s["count"], -1.0, 1e9, -1.0)
		if count < 1.0:
			return null
		s["count"] = mini(int(count), maxi(1, def.stack_max))
	if s.has("level"):
		s["level"] = _int(s["level"], 1, MAX_LEVEL)
	if s.has("process_count"):
		s["process_count"] = _int(s["process_count"], 0, 1000000)
	for key in ["attributes", "flags"]:
		if s.has(key) and not (s[key] is Dictionary if key == "attributes" else s[key] is Array):
			s.erase(key)
	var attrs: Variant = s.get("attributes")
	if attrs is Dictionary:
		# A captured or tamed animal must be of a known species, as a bonded pet must.
		if (attrs as Dictionary).has("species") and Data.creature(StringName(str(attrs["species"]))) == null:
			return null
		_shape(attrs, ATTR_ROW)
		_genetics((attrs as Dictionary).get("genetics"))
	if s.has("durability") or s.has("max_durability"):
		# A fresh stack of the same id, level and attributes knows the real ceiling.
		var fresh := ItemStack.make(StringName(id), 1, s.get("attributes", {}), int(s.get("level", -1)))
		var top := _int(s.get("max_durability", fresh.max_durability), 0, fresh.max_durability)
		if s.has("max_durability"):
			s["max_durability"] = top
		if s.has("durability"):
			s["durability"] = _int(s["durability"], 0, top)
	return s

static func _buildings(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		if not row is Dictionary or not (row as Dictionary).get("kind") is String:
			continue
		var b: Dictionary = row
		_shape(b, BUILDING_ROW)
		if b.has("cell") and not _is_cell(b["cell"]):
			b.erase("cell")
		if b.has("contents"):
			b["contents"] = stacks(b["contents"]) if b["contents"] is Array else []
		if b.has("occupant") or str(b["kind"]) == "makeshift_taming_pen":
			b["occupant"] = _stack(b.get("occupant")) # null when it is not a known, well-formed stack
			if b["occupant"] == null:
				b["running"] = false # a running pen reads its occupant when the timer ends
		out.append(b)
	return out

static func _pets(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		if not row is Dictionary or Data.creature(StringName(str((row as Dictionary).get("species", "")))) == null:
			continue
		var p: Dictionary = row
		_shape(p, PET_ROW)
		_genetics(p.get("genetics"))
		if p.has("level"):
			p["level"] = _int(p["level"], 1, MAX_LEVEL)
		if p.has("bag"):
			p["bag"] = stacks(p["bag"])
		out.append(p)
	return out

## Keep only numeric stats under each genetics part (keys other than ivs/evs/level_gains are never read).
static func _genetics(g: Variant) -> void:
	if not g is Dictionary:
		return
	for part in (g as Dictionary).values():
		if not part is Dictionary:
			continue
		for stat in (part as Dictionary).keys():
			if not (part[stat] is int or part[stat] is float):
				(part as Dictionary).erase(stat)

## Tree levels cap at 60. Bought nodes must exist in trees.json and be reachable (tree level,
## prerequisite); walking the trees in order, a node is kept only while the total cost stays within
## the budget, and sp_spent is that total, so a forged unlocked list cannot buy nodes for free.
## Budget (W2-SKILLS, spec 03): the SP the character level paid plus the one-time sp_extra. A rev-1
## save bought its nodes under the old per-tree award, so its budget is what its tree levels paid
## then: a migration never takes a learned node or an unspent SP away (SkillState turns what the
## character level does not cover into sp_extra). sp_extra is capped at that old award, the most a
## migration can grant. shortcut: a forged save can still claim up to the old award of its tree
## levels; server-side purchases (W3-SRVACT) close it.
static func _skills(sv: Dictionary, pioneer_level: int = 0) -> void:
	var trees: Dictionary = sv.get("trees") if sv.get("trees") is Dictionary else {}
	var payout := SkillState.new()
	payout._load()
	var legacy_paid := 0
	for id in trees.keys():
		if not SkillState.ORDER.has(str(id)):
			trees.erase(id)
			continue
		var row: Dictionary = trees[id] if trees[id] is Dictionary else {}
		var level := _int(row.get("level", 0), 0, MAX_LEVEL)
		row["level"] = level
		# A tree at the character-level cap banks its XP (SkillState._resolve): keep what it can still use.
		row["xp"] = _num(row.get("xp", 0.0), 0.0, SkillState.xp_to_max(level), 0.0)
		row["unlocked"] = row.get("unlocked") if row.get("unlocked") is Array else []
		trees[id] = row
		for l in range(1, level + 1):
			legacy_paid += payout.sp_for_level(l)
	var char_paid := SkillRules.paid_for_level(payout, pioneer_level + 1)
	var earned := legacy_paid
	# Written back so SkillState.from_dict reads the same rev (a hand-edited [2] or "2" is rev 1).
	sv["rev"] = _int(sv.get("rev", 1), 1, SkillState.REV)
	if int(sv["rev"]) >= SkillState.REV:
		sv["sp_extra"] = _int(sv.get("sp_extra", 0), 0, legacy_paid)
		earned = char_paid + int(sv["sp_extra"])
	var spent := 0
	for id in SkillState.ORDER:
		if not trees.has(id):
			continue
		var row: Dictionary = trees[id]
		var claimed: Array = row["unlocked"]
		var kept: Array = []
		for node in payout.nodes(id):
			var nid := str(node.get("id", ""))
			var req := str(node.get("requires", "")) if node.get("requires") != null else ""
			var cost := int(node.get("sp", 0))
			if claimed.has(nid) and int(row["level"]) >= int(node.get("level", 1)) and (req == "" or kept.has(req)) and spent + cost <= earned:
				kept.append(nid)
				spent += cost
		row["unlocked"] = kept
	payout.free()
	sv["trees"] = trees
	sv["sp_spent"] = spent
	sv["sp_available"] = _int(sv.get("sp_available", 0), 0, maxi(0, earned - spent))
	for k in ["refund_day", "refunds_today"]: # optional daily refund counter (SkillState.refund_block)
		if sv.has(k):
			sv[k] = _int(sv[k], -1, 1 << 30)

## Legacy {survival node id: bool}. Only survival.json ids with bool values survive. When a skill
## tree save exists it is the record of what was bought, so a node stays true only if its tree node
## (or the arabic-numbered twin SkillState.unlock mirrors it from) is kept above.
## ASSUMPTION: butchering_I/II have no tree node (only the debug panel sets them); they load false
## next to a skill tree save.
static func _legacy_survival(raw: Dictionary, sv: Variant) -> Dictionary:
	var bought := {}
	var has_trees: bool = sv is Dictionary and (sv as Dictionary).get("trees") is Dictionary
	if has_trees:
		for nid in (sv["trees"] as Dictionary).get("survival", {}).get("unlocked", []):
			bought[str(nid)] = true
			bought[SkillState._roman_id(str(nid))] = true
	var out := {}
	for id in raw:
		if Data.survival_nodes.has(StringName(str(id))) and raw[id] is bool:
			out[str(id)] = raw[id] and (not has_trees or bought.has(str(id)))
	return out

## Keep the Dictionary rows of an array, each coerced to `shape`.
static func _rows(rows: Array, shape: Dictionary) -> Array:
	var out: Array = []
	for r in rows:
		if r is Dictionary:
			_shape(r, shape)
			out.append(r)
	return out

static func _is_cell(v: Variant) -> bool:
	return v is Array and (v as Array).size() >= 2 and _all_numbers(v)

## Erase every field whose type does not match the sample (ints and floats are interchangeable,
## JSON reads every number as a float).
static func _shape(data: Dictionary, shape: Dictionary) -> void:
	for key in shape:
		if not data.has(key):
			continue
		var want: Variant = shape[key]
		var got: Variant = data[key]
		var numeric := (want is int or want is float) and (got is int or got is float)
		if typeof(got) != typeof(want) and not numeric:
			data.erase(key)
		elif want is Dictionary and not (want as Dictionary).is_empty():
			_shape(got, want)

static func _is_position(v: Variant) -> bool:
	if not (v is Array and (v as Array).size() == 3 and _all_numbers(v)):
		return false
	for c in v:
		if absf(float(c)) > WORLD_LIMIT:
			return false
	return true

static func _all_numbers(a: Array) -> bool:
	for c in a:
		if not (c is int or c is float) or not is_finite(float(c)):
			return false
	return true

static func _num(v: Variant, lo: float, hi: float, fallback: float) -> float:
	if not (v is int or v is float) or not is_finite(float(v)):
		return fallback
	return clampf(float(v), lo, hi)

static func _int(v: Variant, lo: int, hi: int) -> int:
	return int(_num(v, float(lo), float(hi), float(lo)))
