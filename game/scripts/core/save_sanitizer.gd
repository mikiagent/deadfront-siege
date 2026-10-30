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
const MAX_RANK := 7 # the last documented Pioneer milestone (data/world/domains.json)
## Set by clean() as its last statement: SaveMigrations.read applies only data that carries it.
const CHECKED := "__sanitized"
## Test hook: makes clean() hit a script error just before CHECKED, as a missed edge case would.
static var abort_for_test := false

## Expected type of each field the loader reads; the value is only a type sample. A field of the
## wrong type is erased so the loader's own default applies.
const SHAPE := {
	"player": {"vitals": {}, "statuses": [], "inventory": [], "inventory_extras": {"equipment": {}, "worn": {}, "quick_food": [], "tool_index": 0, "presets": {}, "food_bag": []}, "position": []},
	"pets": [], "tribe": {"members": [], "pending": []}, "ground_snares": [], "carcasses": [], "skills": {}, "skills_v2": {},
	"home": {"terrain": "", "shape": "", "buildings": [], "cargo": [], "claims": [], "camp_layout": {}, "domain": {}, "comm_center": {}},
	"away": {"buildings": [], "claims": [], "domain": {}}, "pending_refunds": [],
	"pioneer_xp": 0, "pioneer_level": 0, "xp_curve": 0, "pioneer_crafts": {}, "pioneer_buildings": {},
	"player_name": "", "player_title": "", "occupation": "", "character_look": {}, "t_stones": 0, "warp_gems": 0, "visited_islands": {}, "raid_victory": false,
	"objective": 0, "objective_best": 0, "island_id": "",
	"tasks": {"claimed": {}, "done": {}, "counts": {}, "day": 0, "week": 0, "active": {}, "taken": {}},
	"factions": {"rep": {}},
	"unstable": {"remaining": 0.0, "harvested": {}, "crater_discovered": false},
	"landmarks": {"found": {}, "state": {}}, "expeditions": {}, "drift": {},
	"clock": 0.0, "saved_unix": 0,
}
## Fields the building from_dicts read with int()/float()/bool() (placed_building, bonfire,
## field_plot, field_catapult, taming_pen, craft_station). Strings go through str(), which takes anything.
## "open" is the overhaul tip's gate flag (placed_building.gd), listed ahead of the merge.
const BUILDING_ROW := {
	"kind": "", "rot": 0, "x": 0.0, "z": 0.0, "sleeps_left": 0, "hp": 0.0, "reload_left": 0.0,
	"seconds_left": 0.0, "fuel_seconds": 0.0, "durability": 0.0, "growth": 0.0, "watered": 0.0, "fertilizer": 0.0, "fertilizer_overflow": 0.0,
	"remaining": 0.0, "cargo": false, "running": false, "mature": false, "failed": false, "open": false,
}
const SNARE_ROW := {"heavy": false, "life_left": 0.0, "arm_left": 0.0}
const STATUS_ROW := {"id": "", "stacks": 0, "time_left": 0.0}
const CAMP_ROW := {"rot": 0}
## CreatureGenetics.from_dict reads these parts with .get() and casts each leaf with int().
## `coloration` is the individual's natural colour profile (CreatureColoration.from_dict clamps it
## and ignores anything that is not a finite number).
## coloration is the individual's colour profile: numbers, a bool and two short labels (morph, pattern).
const GENETICS := {"ivs": {}, "evs": {}, "level_gains": {},
	"coloration": {"hue_deg": 0.0, "sat": 0.0, "val": 0.0, "morph": "", "rare": false,
		"pattern": "", "pattern_scale": 0.0, "pattern_strength": 0.0, "pattern_tone": 0.0, "pattern_seed": 0.0},
	"size": 0.0, "alpha": false} # GENETICS / ALPHAS: optional, an old row has neither
## PetRecord.from_dict and CreatureGenetics.from_dict cast these with float()/int(). tamed_at and
## wild_level are the overhaul tip's (W1-TAME), listed ahead of the merge.
const PET_ROW := {
	"hunger": 0.0, "hunger_max": 0.0, "hunger_efficiency": 0.0, "xp_rate": 0.0, "hp": 0.0,
	"attack": 0.0, "defense": 0.0, "ranged_defense": 0.0, "ranged_attack": 0.0, "accuracy": 0.0,
	"speed": 0.0, "level": 0, "xp": 0.0, "respawn_left": 0.0, "tamed_role": [], "bag": [],
	"tamed_at": 0, "wild_level": 0, "genetics": GENETICS,
	"nature": "", # NATURES: optional (an old row has none; PetRecord.from_dict derives one from the uid)
	"gear": {}, # SADDLES: optional {slot: item row}; an old row has none
}
## Stack attributes read with int() (taming pen, hunt, material tier) or handed to
## CreatureGenetics.from_dict (taming pen, tamed animal release).
const ATTR_ROW := {"grade_seed": 0, "barbed_hits": 0, "toxin_hits": 0, "sedative_hits": 0, "hardness": 0, "genetics": GENETICS}

## The five Tamed Island shapes a save may hold as home.shape. Read from the catalogue itself so the
## sanitizer needs no autoload (tests call clean() before World exists) and a shape added to the json
## is allowed without a second list here.
const SHAPE_CATALOGUE := "res://data/world/island_shapes.json"
static var _shape_ids: PackedStringArray = PackedStringArray()

static func shape_ids() -> PackedStringArray:
	if not _shape_ids.is_empty():
		return _shape_ids
	var f := FileAccess.open(SHAPE_CATALOGUE, FileAccess.READ)
	if f == null:
		return _shape_ids
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return _shape_ids
	for row in (parsed as Dictionary).get("shapes", []):
		if row is Dictionary:
			var id := str((row as Dictionary).get("id", ""))
			if id != "":
				_shape_ids.append(id)
	return _shape_ids

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
	var worn: Variant = extras.get("worn", {})
	if worn is Dictionary:
		for slot in (worn as Dictionary).keys():
			var row: Variant = _stack(worn[slot])
			if row == null:
				(worn as Dictionary).erase(slot)
			else:
				worn[slot] = row
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
	# ISLANDPICK: home.shape is one of the five catalogue ids or absent. The type check above already
	# erased an array/number/null/object row; an unknown or empty id is erased here, so the loader only
	# ever sees a shape this build can build. Absent is fine: an old save has no row and keeps its island.
	if home.has("shape") and not shape_ids().has(str(home["shape"])):
		home.erase("shape")
	if home.has("cargo"):
		home["cargo"] = stacks(home["cargo"])
	# DOMAIN-D / spec 29 section 4: the Personal Communications Center's record. It is a record of
	# exact item instances held for one contribution step, so every held row goes through the same
	# item validation as a bag slot, and the rank is clamped to the documented track.
	if home.has("comm_center"):
		home["comm_center"] = _comm_center(home["comm_center"])
	var layout: Dictionary = home.get("camp_layout", {})
	for key in layout.keys():
		var row: Variant = layout[key]
		if not row is Dictionary or ((row as Dictionary).has("cell") and not _is_cell((row as Dictionary)["cell"])):
			layout.erase(key)
		else:
			_shape(row, CAMP_ROW)
	if data.has("pending_refunds"):
		data["pending_refunds"] = _buildings(data["pending_refunds"])
	# CLAIMS2 / spec 29: the domain record. Cells are [x, z] pairs inside the world limit, the cap is
	# a sane positive number, and the identity fields are short strings.
	if (data.get("away", {}) as Dictionary).has("domain"):
		data["away"]["domain"] = _domain(data["away"]["domain"])
	if home.has("domain"):
		home["domain"] = _domain(home["domain"])
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
	# TRIBE M1: each member's worn gear and carry go through the same item validation as a bag slot;
	# TribeRecord.from_dict coerces the rest (numbers clamped, unknown orders/jobs dropped).
	if data.has("tribe"):
		for k in ["members", "pending"]:
			var rows: Variant = (data["tribe"] as Dictionary).get(k, [])
			if rows is Array:
				data["tribe"][k] = (rows as Array).filter(func (r: Variant) -> bool: return r is Dictionary)
				for r: Dictionary in data["tribe"][k]:
					if r.get("carry") is Array:
						r["carry"] = stacks(r["carry"])
					if r.get("escrow") is Array:
						r["escrow"] = stacks(r["escrow"])
					var gear := {}
					if r.get("equipment") is Dictionary:
						for slot in r["equipment"]:
							var st: Variant = _stack(r["equipment"][slot])
							if st != null:
								gear[str(slot)] = st
					r["equipment"] = gear
	# BUTCHER (spec 12 §2): carcasses on the ground. Only a species the build knows, a level play can
	# reach, a cut count inside its own budget and part ids that species really has survive; the loot
	# goes through the same item validation as a bag slot.
	if data.has("carcasses"):
		data["carcasses"] = _carcasses(data["carcasses"])
	if data.has("ground_snares"):
		data["ground_snares"] = _rows(data["ground_snares"], SNARE_ROW).filter(func (r: Variant) -> bool:
			return _is_position((r as Dictionary).get("position")))
	if data.has("skills_v2"):
		_skills(data["skills_v2"], _int(data.get("pioneer_level", 0), 0, SkillState.MAX_LEVEL - 1))
	if data.has("skills"):
		data["skills"] = _legacy_survival(data["skills"], data.get("skills_v2", {}))
	if data.has("t_stones"):
		data["t_stones"] = _int(data["t_stones"], 0, MAX_T_STONES)
	if data.has("warp_gems"):
		data["warp_gems"] = _int(data["warp_gems"], 0, MAX_T_STONES) # BAGUI: same ceiling as T-stones
	for key in ["pioneer_level", "pioneer_xp", "xp_curve", "objective", "objective_best"]:
		if data.has(key):
			data[key] = _int(data[key], 0, 1000000000)
	if data.has("saved_unix"):
		data["saved_unix"] = _int(data["saved_unix"], 0, int(Time.get_unix_time_from_system()))
	# UNSTABLE ISLES: a save standing on the live isle names an id the catalogue only gets back once the
	# saved roll is reinstalled (SaveGame); drift_block decides whether that roll is sound.
	var on_drift := data.has("island_id") and str(data["island_id"]) == str((drift_block(data.get("drift", null))["row"] as Dictionary).get("id", "-"))
	if data.has("island_id") and not World.islands.has(str(data["island_id"])) and not on_drift:
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
		# A pre-W2-INV row may still hold a legacy stack; Inventory.load_array splits it into instances.
		s["count"] = mini(int(count), maxi(1, def.legacy_stack_max))
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
		# COOKROLES (spec 08 §3/§9): a dish's inheritance record is exact data, and a save is untrusted.
		# Rebuild it through CookRoles so a forged file can neither add a trait this build does not
		# read nor mint a level the game never produces; a dish with no record keeps none.
		if (attrs as Dictionary).has("cooked_roles"):
			var rec_rows := CookRoles.sanitize_record((attrs as Dictionary)["cooked_roles"])
			if rec_rows.is_empty():
				(attrs as Dictionary).erase("cooked_roles")
			else:
				(attrs as Dictionary)["cooked_roles"] = rec_rows
		if (attrs as Dictionary).has("cooked_buffs"):
			var buffs := CookRoles.sanitize_buffs((attrs as Dictionary)["cooked_buffs"])
			if buffs.is_empty():
				(attrs as Dictionary).erase("cooked_buffs")
			else:
				(attrs as Dictionary)["cooked_buffs"] = buffs
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
		if b.has("occupant") or TamingPen.is_pen_kind(StringName(str(b["kind"]))):
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
		if p.has("gear"):
			var gear := {}
			for k in p["gear"]:
				var st: Variant = _stack(p["gear"][k])
				if st != null:
					gear[str(k)] = st
			p["gear"] = gear
		out.append(p)
	return out

## Keep only numeric stats under each genetics part (keys other than ivs/evs/level_gains/coloration
## are never read; coloration.morph is a label, dropped here, its hue/sat/val carry the look).
static func _genetics(g: Variant) -> void:
	if not g is Dictionary:
		return
	for key in (g as Dictionary).keys():
		var part: Variant = (g as Dictionary)[key]
		if not part is Dictionary:
			continue
		for stat in (part as Dictionary).keys():
			var v: Variant = (part as Dictionary)[stat]
			if str(key) == "coloration":
				# The profile keeps its bool and its two labels; _shape above already typed them.
				if not (v is int or v is float or v is bool or v is String):
					(part as Dictionary).erase(stat)
			elif not (v is int or v is float):
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
	# SLOWLEVELS research: a known tree, the level it leaves, an end no later than that research takes from
	# now. shortcut: an end forged into the past is not caught (no start is stored); add one if saves get shared.
	var r: Variant = sv.get("research")
	if r != null:
		var rd: Dictionary = r if r is Dictionary else {}
		var tid := str(rd.get("tree", ""))
		if not SkillState.ORDER.has(tid) or not trees.has(tid) or not (rd.get("end") is float or rd.get("end") is int):
			sv.erase("research")
		else:
			var from := _int(rd.get("from", 0), 1, MAX_LEVEL)
			sv["research"] = {"tree": tid, "from": from, "end": minf(float(rd["end"]), SkillState.now_s() + SkillState.research_s(from))}
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
## One carcass row as CarcassParts.to_row writes it (shaped by SaveRestore.restore_carcasses).
static func _carcasses(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		if not row is Dictionary:
			continue
		var r: Dictionary = row
		var species := str(r.get("species", ""))
		if Data.creature(StringName(species)) == null:
			continue
		var parts := _part_ids(species)
		if parts.is_empty():
			continue  # a species with no butcher table has no part picker and no saved state
		_shape(r, {"level": 0, "cuts_left": 0, "cuts_budget": 0, "cut_parts": [], "loot": [], "position": []})
		r["level"] = _int(r.get("level", 1), 1, MAX_LEVEL)
		var budget := _int(r.get("cuts_budget", 1), 1, CarcassParts.CUTS_MAX)
		r["cuts_budget"] = budget
		r["cuts_left"] = _int(r.get("cuts_left", budget), 0, budget)
		var cut: Array = []
		for id in (r.get("cut_parts", []) if r.get("cut_parts") is Array else []):
			var s := str(id)
			if parts.has(s) and not cut.has(s):
				cut.append(s)
		r["cut_parts"] = cut
		if r.get("loot") is Array:
			r["loot"] = stacks(r["loot"])
		else:
			r["loot"] = []
		if not _is_position(r.get("position")):
			r.erase("position")  # no spot: the loader drops it (a carcass with no place on the island)
		if not r.has("position"):
			continue
		var pos: Array = r["position"]
		if absf(float(pos[0])) > WORLD_LIMIT or absf(float(pos[2])) > WORLD_LIMIT:
			continue
		out.append(r)
	return out

## Item ids that species' butchering.json rows offer (a cut part must be one of them).
static func _part_ids(species: String) -> Dictionary:
	var table: Dictionary = Data.butcher_tables.get(species, {})
	var ids := {}
	for block in ["base", "rare"]:
		for row in (table.get(block, []) if table.get(block) is Array else []):
			if row is Dictionary:
				var id := str((row as Dictionary).get("id", ""))
				if id != "":
					ids[id] = true
	return ids

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

## One center record from disk: {"rank", "steps"}, where steps maps a target rank to one array of
## held instances per required slot. Anything that is not a rank of the documented track, a valid
## item instance, or a sane slot row is dropped, so a forged save can neither raise the rank past the
## track nor hand the center an item the game does not have.
static func _comm_center(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var d: Dictionary = v
	var out_steps: Dictionary = {}
	var raw: Variant = d.get("steps", {})
	if raw is Dictionary:
		for key in raw:
			var rank := int(str(key))
			if rank < 2 or rank > MAX_RANK:
				continue
			var rows: Variant = (raw as Dictionary)[key]
			if not rows is Array:
				continue
			var cols: Array = []
			for col: Variant in rows:
				var held: Array = []
				if col is Array:
					for row: Variant in col:
						var s: Variant = _stack(row)
						if s != null:
							held.append(s)
				cols.append(held)
			out_steps[str(rank)] = cols
	return {"rank": _int(d.get("rank", 1), 1, MAX_RANK), "steps": out_steps}

## A domain record from disk, coerced: {} when it carries no usable cells (an island with no domain).
## A forged cell list clamps to the world limit and drops repeated cells; the cap keeps its number
## (it is a floor for migrated saves) but never absurd.
static func _domain(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var d: Dictionary = v
	var cells: Array = []
	var seen := {}
	for c in d.get("cells", []):
		if not (c is Array and (c as Array).size() >= 2 and _all_numbers(c)):
			continue
		if absf(float(c[0])) > WORLD_LIMIT or absf(float(c[1])) > WORLD_LIMIT:
			continue
		var cell := [int(c[0]), int(c[1])]
		if seen.has(cell):
			continue
		seen[cell] = true
		cells.append(cell)
	if cells.is_empty():
		return {}
	return {
		"domain_id": str(d.get("domain_id", "")) if str(d.get("domain_id", "")).length() <= 64 else "",
		"kind": str(d.get("kind", "")) if str(d.get("kind", "")) in ["tamed_island", "unstable"] else "tamed_island",
		"island_id": str(d.get("island_id", "")),
		"owner": str(d.get("owner", "self")),
		"owner_clan_id": str(d.get("owner_clan_id", "")),
		"cells": cells,
		"max_cells": _int(d.get("max_cells", 0), 1, 1000),
		"status": str(d.get("status", "active")),
		"renewal_deadline": d.get("renewal_deadline", null),
		"permissions_profile_id": str(d.get("permissions_profile_id", "owner_only")),
	}

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

## LANDMARKS: the save's landmarks.found / landmarks.state rows, island id -> {site id: value}. Found
## rows keep true flags; state rows keep {"left": seconds >= 0, "spent": bool}. Anything else (a hand
## edit, a wrong type) is dropped, and ids are capped so a crafted file cannot grow the dictionary.
static func landmark_rows(raw: Variant, state: bool) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for island in (raw as Dictionary).keys():
		var row: Variant = (raw as Dictionary)[island]
		if not row is Dictionary or str(island).length() > 64:
			continue
		var clean := {}
		for sid in (row as Dictionary).keys():
			if str(sid).length() > 64 or clean.size() >= 32:
				continue
			var v: Variant = (row as Dictionary)[sid]
			if state:
				if v is Dictionary:
					var left: Variant = (v as Dictionary).get("left", 0.0)
					var l := float(left) if (left is float or left is int) and is_finite(float(left)) else 0.0
					clean[str(sid)] = {"left": clampf(l, 0.0, 86400.0), "spent": bool((v as Dictionary).get("spent", false))}
			elif v is bool and v:
				clean[str(sid)] = true
		if not clean.is_empty():
			out[str(island)] = clean
	return out

## ISLAND RESET: the save's expeditions rows, island id -> {generation >= 0, left (seconds, -1 = no
## clock), harvested (a node snapshot Dictionary)}. Wrong types fall back to a first visit.
static func expedition_rows(raw: Variant) -> Dictionary:
	var out := {}
	if not raw is Dictionary:
		return out
	for island in (raw as Dictionary).keys():
		var row: Variant = (raw as Dictionary)[island]
		if not row is Dictionary or str(island).length() > 64 or out.size() >= 64:
			continue
		var r: Dictionary = row
		var g: Variant = r.get("generation", 0)
		var l: Variant = r.get("left", -1.0)
		var h: Variant = r.get("harvested", {})
		out[str(island)] = {
			"generation": clampi(int(g), 0, 1000000) if (g is int or g is float) and is_finite(float(g)) else 0,
			"left": clampf(float(l), -1.0, 7.0 * 86400.0) if (l is int or l is float) and is_finite(float(l)) else -1.0,
			"harvested": h if h is Dictionary else {},
		}
		# The last layout's landmark centres ([[x, z], ...]): the next reroll keeps away from them.
		var lc: Variant = r.get("last_centres", null)
		if lc is Array:
			var pts: Array = []
			for pt in (lc as Array).slice(0, 32):
				if pt is Array and (pt as Array).size() >= 2 and (pt[0] is int or pt[0] is float) and (pt[1] is int or pt[1] is float) and is_finite(float(pt[0])) and is_finite(float(pt[1])):
					pts.append([float(pt[0]), float(pt[1])])
			out[str(island)]["last_centres"] = pts
	return out

## UNSTABLE ISLES: the saved board {"row", "cooldown", "count"}. A row that does not name a known
## template, climate and shape is dropped (no isle), so a forged save cannot invent an island kind.
static func drift_block(raw: Variant) -> Dictionary:
	var out := {"row": {}, "cooldown": 0.0, "count": 0}
	if not raw is Dictionary:
		return out
	var d: Dictionary = raw
	var cd: Variant = d.get("cooldown", 0.0)
	out["cooldown"] = clampf(float(cd), 0.0, 86400.0) if (cd is int or cd is float) and is_finite(float(cd)) else 0.0
	var n: Variant = d.get("count", 0)
	out["count"] = clampi(int(n), 0, 1000000) if (n is int or n is float) and is_finite(float(n)) else 0
	var row: Variant = d.get("row", {})
	if not row is Dictionary or (row as Dictionary).is_empty():
		return out
	var r: Dictionary = row
	var tmpl := str(r.get("template", ""))
	var id := str(r.get("id", ""))
	var tmpl_row: Variant = World.islands.get(tmpl, null) if World else null
	if not id.begins_with("drift_") or id.length() > 24 or not tmpl_row is Dictionary or str((tmpl_row as Dictionary).get("kind", "")) != "unstable":
		return out
	var nums := ["n", "seed", "tier", "size_m", "offer_left"]
	for k in nums:
		var v: Variant = r.get(k, null)
		if not (v is int or v is float) or not is_finite(float(v)):
			return out
	out["row"] = {
		"id": id,
		"n": clampi(int(r["n"]), 1, 1000000),
		"seed": int(r["seed"]),
		"tier": clampi(int(r["tier"]), 15, 60),
		"climate": str((tmpl_row as Dictionary).get("climate", "")),
		"template": tmpl,
		"family": str(r.get("family", "classic")),
		"size_m": clampi(int(r["size_m"]), 200, 440),
		"offer_left": clampf(float(r["offer_left"]), 0.0, 86400.0),
	}
	out["count"] = maxi(int(out["count"]), int(out["row"]["n"]))
	return out
