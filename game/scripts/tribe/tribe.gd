class_name Tribe
extends RefCounted
## TRIBE M1: the tribe's roster and its rules (vision §5, WildLandsMMO_Loss_Recruitment_Revival.md).
## Members and recruits waiting at the dock live here (static: one offline tribe per process, like the
## World autoload's state); TribeDirector puts their live bodies in the world.
##
## Owner 2026-10-28: "keep the recruit in the harbor, we have to manually accept or deny them". A boat
## brings a recruit to the home dock about once a day; they WAIT there (up to pending_cap) until the
## player Accepts (they join, within the housing cap) or Denies (they leave on the boat). Ignored, the
## oldest leaves after wait_days. Every number comes from data/tribe.json and is an ASSUMPTION.

const DATA := "res://data/tribe.json"

static var members: Array[TribeRecord] = []
static var pending: Array[TribeRecord] = []
## Seconds until the next boat (-1 = not started: set to one interval on first tick).
static var arrival_left: float = -1.0
## The starter recruit has been offered (once per world).
static var seeded: bool = false
## Bumped on every roster change; the UI and the director poll it.
static var version: int = 0
static var rng := RandomNumberGenerator.new()
static var _cfg: Dictionary = {}

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f else null
		_cfg = parsed if parsed is Dictionary else {"member": {}}
	return _cfg

## A data/tribe.json "member" number.
static func num(key: String, fallback: float) -> float:
	var v: Variant = (cfg().get("member", {}) as Dictionary).get(key, fallback)
	return float(v) if v is float or v is int else fallback

static func section_num(section: String, key: String, fallback: float) -> float:
	var v: Variant = (cfg().get(section, {}) as Dictionary).get(key, fallback)
	return float(v) if v is float or v is int else fallback

static func potential_row(id: String) -> Dictionary:
	for r in cfg().get("potential", []):
		if r is Dictionary and str(r.get("id", "")) == id:
			return r
	return {}

static func day_seconds() -> float:
	return Game.day_length_seconds if Game else 720.0

static func reset() -> void:
	members.clear()
	pending.clear()
	arrival_left = -1.0
	seeded = false
	version += 1

# ---------------------------------------------------------------- housing

## How many members the home can house: base + one per bed (sleep structure) at home. Away, the
## cached home buildings count. ASSUMPTION (data/tribe.json "housing").
static func housing_cap() -> int:
	var kinds: Array = (cfg().get("housing", {}) as Dictionary).get("bed_kinds", [])
	var beds := 0
	if World and World.runtime and World.is_home():
		for n in World.runtime.get_tree().get_nodes_in_group("placed_building"):
			if str(n.get("kind")) in kinds and not n.is_queued_for_deletion():
				beds += 1
	elif World:
		for row in World._home_buildings_cache:
			if row is Dictionary and str((row as Dictionary).get("kind", "")) in kinds:
				beds += 1
	return int(section_num("housing", "base", 2.0)) + int(section_num("housing", "per_bed", 1.0)) * beds

# ---------------------------------------------------------------- arrivals

static func pending_cap() -> int:
	return int(section_num("arrivals", "pending_cap", 3.0))

static func arrival_interval() -> float:
	return section_num("arrivals", "every_days", 1.0) * day_seconds()

static func wait_seconds() -> float:
	return section_num("arrivals", "wait_days", 1.0) * day_seconds()

## Advance the boat timer and the dock queue. Returns notices for the player (arrivals, departures).
static func tick(delta: float) -> Array[String]:
	var out: Array[String] = []
	if arrival_left < 0.0:
		arrival_left = arrival_interval()
	var gone: Array[TribeRecord] = []
	for r in pending:
		r.wait_left -= delta
		if r.wait_left <= 0.0:
			gone.append(r)
	for r in gone:
		pending.erase(r)
		out.append("%s left on the boat" % r.name)
	if not gone.is_empty():
		version += 1
	arrival_left -= delta
	while arrival_left <= 0.0:
		arrival_left += arrival_interval()
		var r := arrive()
		if r:
			out.append("A boat brought %s to the dock" % r.name)
	return out

## A recruit steps off the boat and waits at the dock. Null when the dock queue is full (the boat
## turns back; nobody is lost).
static func arrive(p_rng: RandomNumberGenerator = null) -> TribeRecord:
	if pending.size() >= pending_cap():
		return null
	var r := make_recruit(p_rng if p_rng else rng)
	r.wait_left = wait_seconds()
	pending.append(r)
	version += 1
	print("[tribe] %s (%s) arrived at the dock; %d waiting" % [r.name, r.potential, pending.size()])
	return r

## The starter recruit (data arrivals.starter_recruit): offered once per world, on the first home load.
static func seed_starter() -> TribeRecord:
	if seeded or not bool((cfg().get("arrivals", {}) as Dictionary).get("starter_recruit", true)):
		return null
	seeded = true
	if not members.is_empty() or not pending.is_empty():
		return null
	return arrive()

## A fresh recruit: a random name and body (the character-creation options), level 1, mostly weak or
## mediocre potential, rarely exceptional (weights in data/tribe.json).
static func make_recruit(p_rng: RandomNumberGenerator) -> TribeRecord:
	var r := TribeRecord.new()
	r.uid = TribeRecord.new_uid()
	var names: Array = cfg().get("names", ["Recruit"])
	r.name = str(names[p_rng.randi_range(0, names.size() - 1)]) if not names.is_empty() else "Recruit"
	r.look = CharacterLook.randomized(CharacterLook.GENDERS[p_rng.randi_range(0, CharacterLook.GENDERS.size() - 1)], p_rng)
	r.potential = roll_potential(p_rng)
	r.health = -1.0
	return r

static func roll_potential(p_rng: RandomNumberGenerator) -> String:
	var rows: Array = cfg().get("potential", [])
	var total := 0.0
	for row in rows:
		total += float(row.get("weight", 0.0))
	var pick := p_rng.randf() * total
	for row in rows:
		pick -= float(row.get("weight", 0.0))
		if pick < 0.0:
			return str(row.get("id", "mediocre"))
	return "mediocre"

## Accept a waiting recruit: they join the tribe. "" or why not (housing full).
static func accept(r: TribeRecord) -> String:
	if r == null or not pending.has(r):
		return "Nobody is waiting"
	if members.size() >= housing_cap():
		return "No room: housing for %d (build a bed or tent)" % housing_cap()
	pending.erase(r)
	r.order = &"stay"
	members.append(r)
	version += 1
	print("[tribe] %s joined the tribe (%d / %d)" % [r.name, members.size(), housing_cap()])
	return ""

## Deny a waiting recruit: they leave on the boat.
static func deny(r: TribeRecord) -> void:
	if pending.has(r):
		pending.erase(r)
		version += 1
		print("[tribe] %s was turned away" % r.name)

# ---------------------------------------------------------------- orders and jobs

## Follow-style orders and stay. Any of them ends the current job: one thing at a time.
static func set_order(r: TribeRecord, o: StringName) -> void:
	if r == null or not o in TribeRecord.ORDERS:
		return
	if o == &"work" and r.job.is_empty():
		return
	r.order = o
	if o != &"work":
		r.job = {}
	version += 1

## One job at a time: a new job replaces the old one and ends any follow order.
static func set_job(r: TribeRecord, kind: StringName, center: Vector3, chest: Vector3 = Vector3.INF, radius: float = -1.0) -> String:
	if r == null:
		return "No member"
	if not kind in TribeRecord.JOB_KINDS:
		return "Unknown job"
	r.job = {"kind": str(kind), "center": [center.x, center.z], "radius": radius if radius > 0.0 else num("job_radius_m", 12.0),
		"chest": [] if chest == Vector3.INF else [chest.x, chest.z]}
	r.order = &"work"
	version += 1
	return ""

static func rename(r: TribeRecord, new_name: String) -> String:
	var nm := new_name.strip_edges()
	var why := CharacterStore.name_problem(nm)
	if r == null or why != "":
		return why if why != "" else "no member"
	r.name = nm
	version += 1
	return ""

## M2 hook: direct control of a member. Refused in M1.
static func take_control(_r: TribeRecord) -> String:
	return "Direct control comes later"

# ---------------------------------------------------------------- save

static func to_save() -> Dictionary:
	return {
		"members": members.map(func (r: TribeRecord) -> Dictionary: return r.to_dict()),
		"pending": pending.map(func (r: TribeRecord) -> Dictionary: return r.to_dict()),
		"arrival_left": arrival_left,
		"seeded": seeded,
	}

## An old save has no "tribe": an empty tribe, starter recruit not yet offered.
static func from_save(d: Variant) -> void:
	reset()
	if not d is Dictionary:
		return
	var row: Dictionary = d
	for k in ["members", "pending"]:
		var list: Variant = row.get(k, [])
		if not list is Array:
			continue
		for item in list:
			var r := TribeRecord.from_dict(item)
			if r == null:
				continue
			if k == "members":
				members.append(r)
			elif pending.size() < pending_cap():
				pending.append(r)
	var al: Variant = row.get("arrival_left", -1.0)
	arrival_left = clampf(float(al), -1.0, arrival_interval()) if al is float or al is int else -1.0
	var sv: Variant = row.get("seeded", false)
	seeded = sv is bool and sv
	version += 1
