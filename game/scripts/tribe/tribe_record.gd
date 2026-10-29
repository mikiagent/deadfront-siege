class_name TribeRecord
extends RefCounted
## TRIBE M1: one persistent human tribe member (or a recruit still waiting at the dock). Vision §5:
## a person with a name, a body, innate potential kept apart from earned levels, needs, gear and one
## job at a time. The live body is TribeMember; this row is what saves.

## Orders. follow/guard/heel/attack walk with the survivor (pet-style); stay idles at home; work runs
## the job. A member following you is not working (vision §5 opportunity cost).
const FOLLOW_ORDERS: Array[StringName] = [&"follow", &"guard", &"heel", &"attack"]
const ORDERS: Array[StringName] = [&"follow", &"guard", &"heel", &"attack", &"stay", &"work"]
## Job kinds = HarvestNode.gather_kind(): mine rock, chop trees, gather (fibre, berries, bushes).
const JOB_KINDS: Array[StringName] = [&"mine", &"chop", &"gather"]
## TRIBE M2a hand-off orders (TribeWork): one craft at a station, or one construction site.
const STATION_JOBS: Array[StringName] = [&"craft", &"build"]
## Escrow size: a recipe's picked units plus its output. # ASSUMPTION: no recipe takes more than 14 stacks.
const ESCROW_SLOTS := 16
const SKILLS := ["gathering", "melee"]

var uid: String = ""
var name: String = ""
var look: Dictionary = {}
## Innate potential (data/tribe.json "potential" id); never changes with training.
var potential: String = "mediocre"
var level: int = 1
var xp: float = 0.0
var skills: Dictionary = {"gathering": 1, "melee": 1}
var skill_xp: Dictionary = {"gathering": 0.0, "melee": 0.0}
var health: float = -1.0  # -1 = full (set on first use)
var energy: float = 100.0
var fatigue: float = 0.0
var fullness: float = 100.0
var equipment := EntityEquipment.new(EntityEquipment.HUMAN_SLOTS)
## What the member is carrying between the job node and the chest (saved, so nothing vanishes).
var carry := Inventory.new(6)
var order: StringName = &"stay"
## {"kind": "mine", "center": [x, z], "radius": 12.0, "chest": [x, z] or []}; a station job adds its
## own keys (TribeWork: craft = station, recipe, outcome, progress...; build = site id).
var job: Dictionary = {}
## TRIBE M2a: the exact instances a craft order took from the survivor's bag (then its output until
## delivered). Saved, so a reload mid-craft loses nothing; cancel hands them back.
var escrow := Inventory.new(ESCROW_SLOTS)
## Last position at home [x, y, z] ([] = not placed yet: spawns at the dock).
var pos: Array = []
## Pending recruits only: seconds left before the boat leaves with them.
var wait_left: float = 0.0
## M2 hook: true while the player controls this member directly (never set in M1).
var controlled: bool = false

static func new_uid() -> String:
	return "tm_%d_%d" % [Time.get_ticks_usec(), randi()]

func max_hp() -> float:
	return Tribe.num("hp", 80.0) + Tribe.num("hp_per_level", 4.0) * float(level - 1)

func hp() -> float:
	return max_hp() if health < 0.0 else health

func potential_label() -> String:
	return str(Tribe.potential_row(potential).get("label", potential.capitalize()))

func skill(id: String) -> int:
	return maxi(1, int(skills.get(id, 1)))

## Earned XP in a skill, scaled by innate potential. Returns levels gained.
func add_skill_xp(id: String, amount: float) -> int:
	var per := Tribe.num("xp_per_level", 40.0)
	var gained := 0
	var x := float(skill_xp.get(id, 0.0)) + amount * float(Tribe.potential_row(potential).get("xp_mult", 1.0))
	while x >= per * float(skill(id)) and skill(id) < int(Tribe.num("max_skill", 60)):
		x -= per * float(skill(id))
		skills[id] = skill(id) + 1
		gained += 1
	skill_xp[id] = x
	if gained > 0:
		level = maxi(level, (skill("gathering") + skill("melee")) / 2)
	return gained

func is_following() -> bool:
	return order in FOLLOW_ORDERS

func to_dict() -> Dictionary:
	return {
		"uid": uid, "name": name, "look": look, "potential": potential, "level": level, "xp": xp,
		"skills": skills.duplicate(), "skill_xp": skill_xp.duplicate(),
		"health": health, "energy": energy, "fatigue": fatigue, "fullness": fullness,
		"equipment": equipment.to_dict(), "carry": carry.to_array(),
		"order": str(order), "job": job.duplicate(true), "pos": pos.duplicate(), "wait_left": wait_left,
		"escrow": escrow.to_array(),
	}

## Defensive: the save is user-editable (SaveSanitizer shapes it first). A bad field keeps its default.
static func from_dict(d: Variant) -> TribeRecord:
	if not d is Dictionary:
		return null
	var r := TribeRecord.new()
	var row: Dictionary = d
	r.uid = str(row.get("uid", ""))
	if r.uid == "":
		r.uid = new_uid()
	r.name = str(row.get("name", "Recruit")).left(20)
	r.look = CharacterLook.clean(row.get("look", {}))
	var pot := str(row.get("potential", "mediocre"))
	r.potential = pot if not Tribe.potential_row(pot).is_empty() else "mediocre"
	r.level = clampi(int(_n(row.get("level"), 1.0)), 1, 60)
	r.xp = maxf(0.0, _n(row.get("xp"), 0.0))
	# M2a: a member trains whatever skill its work orders use (construction, processing...), so any
	# saved skill id loads; Gathering and Melee always exist.
	var sd: Variant = row.get("skills", {})
	var keys: Array = SKILLS.duplicate()
	if sd is Dictionary:
		for k: Variant in sd:
			if k is String and not keys.has(k) and (k as String).length() <= 32:
				keys.append(k)
	for k in keys:
		var sv: Variant = row.get("skills", {})
		var xv: Variant = row.get("skill_xp", {})
		r.skills[k] = clampi(int(_n((sv as Dictionary).get(k) if sv is Dictionary else null, 1.0)), 1, int(Tribe.num("max_skill", 60)))
		r.skill_xp[k] = maxf(0.0, _n((xv as Dictionary).get(k) if xv is Dictionary else null, 0.0))
	var hpv := _n(row.get("health"), -1.0)
	r.health = -1.0 if hpv < 0.0 else minf(hpv, r.max_hp())
	r.energy = clampf(_n(row.get("energy"), 100.0), 0.0, Tribe.num("energy_max", 100.0))
	r.fatigue = clampf(_n(row.get("fatigue"), 0.0), 0.0, Tribe.num("fatigue_max", 100.0))
	r.fullness = clampf(_n(row.get("fullness"), 100.0), 0.0, Tribe.num("fullness_max", 100.0))
	r.equipment = EntityEquipment.from_dict(row.get("equipment", {}), EntityEquipment.HUMAN_SLOTS)
	var cv: Variant = row.get("carry", [])
	if cv is Array:
		r.carry.load_array(cv)
	var ev: Variant = row.get("escrow", [])
	if ev is Array:
		r.escrow.load_array(ev)
	var o := StringName(str(row.get("order", "stay")))
	r.order = o if o in ORDERS else &"stay"
	var jv: Variant = row.get("job", {})
	r.job = _clean_job(jv)
	if r.order == &"work" and r.job.is_empty():
		r.order = &"stay"
	var pv: Variant = row.get("pos", [])
	if pv is Array and (pv as Array).size() == 3 and (pv as Array).all(func (v: Variant) -> bool: return (v is float or v is int) and absf(float(v)) < 2000.0):
		r.pos = (pv as Array).duplicate()
	r.wait_left = maxf(0.0, _n(row.get("wait_left"), 0.0))
	return r

static func _clean_job(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {}
	var j: Dictionary = v
	var kind := StringName(str(j.get("kind", "")))
	var c: Variant = j.get("center", [])
	if kind in STATION_JOBS:
		return TribeWork.clean_job(j)
	if not kind in JOB_KINDS or not _xz(c):
		return {}
	var out := {"kind": str(kind), "center": [float(c[0]), float(c[1])], "radius": clampf(_n(j.get("radius"), 12.0), 2.0, 40.0), "chest": []}
	if _xz(j.get("chest", [])):
		out["chest"] = [float(j["chest"][0]), float(j["chest"][1])]
	return out

static func _xz(v: Variant) -> bool:
	return v is Array and (v as Array).size() == 2 and (v[0] is float or v[0] is int) and (v[1] is float or v[1] is int) \
		and absf(float(v[0])) < 2000.0 and absf(float(v[1])) < 2000.0

static func _n(v: Variant, fallback: float) -> float:
	if (v is float or v is int) and not is_nan(float(v)) and not is_inf(float(v)):
		return float(v)
	return fallback
