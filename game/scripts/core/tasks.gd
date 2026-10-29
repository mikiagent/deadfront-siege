class_name Tasks
extends RefCounted
## TASKSCREEN (owner 2026-10-28, Durango's Task screen): every task the survivor can claim, in five
## categories. Main Task = the standing orders (objectives.json, Objectives advances them); Daily and
## Weekly = repeatable counts that reset on the real-time UTC day / week; Achievement = character and
## skill level milestones; Domain Construction = first buildings in the domain (World.pioneer_buildings).
## Definitions: data/world/tasks.json. Nothing pays on its own: claim() pays a completed, unclaimed task once.
## State is static (one survivor per client) and saved as the "tasks" block (to_dict / from_dict).

const CATS: Array[StringName] = [&"daily", &"achievement", &"domain", &"main", &"weekly"]
const NAMES := {&"daily": "Daily Task", &"achievement": "Achievement", &"domain": "Domain Construction", &"main": "Main Task", &"weekly": "Weekly Task"}
const PATH := "res://data/world/tasks.json"
const DAY_S := 86400

static var claimed: Dictionary = {}  ## task id -> true
static var counts: Dictionary = {}   ## "daily.gather" / "weekly.craft" -> count since the last reset; "life.<kind>" never resets
static var done: Dictionary = {}     ## "main.<order id>" -> true once Objectives.settle finished it (claimable until received)
static var day: int = -1             ## UTC day number the daily counts belong to
static var week: int = -1            ## Monday-based UTC week number the weekly counts belong to
static var clock_override: int = -1  ## tests: unix seconds to use instead of the system clock
static var _defs: Dictionary = {}

static func defs() -> Dictionary:
	if _defs.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_defs = parsed if parsed is Dictionary else {"_bad": true}
	return _defs

static func reset() -> void:
	claimed = {}
	counts = {}
	done = {}
	day = -1
	week = -1
	roll()

## Objectives.settle finished standing order `id` (objectives.json, or a tutorial order).
static func mark_done(order_id: String) -> void:
	done["main." + order_id] = true

# ---------------------------------------------------------------- counting and resets

static func _unix() -> int:
	return clock_override if clock_override >= 0 else int(Time.get_unix_time_from_system())

## Clears the daily (weekly) counts and claims when the UTC day (week) changed since they were counted.
static func roll() -> void:
	var d := _unix() / DAY_S
	var w := (d + 3) / 7  # 1970-01-01 was a Thursday: +3 puts the week boundary on Monday 00:00 UTC
	if d != day:
		_clear("daily.")
		day = d
	if w != week:
		_clear("weekly.")
		week = w

static func _clear(prefix: String) -> void:
	for dict: Dictionary in [counts, claimed]:
		for k in dict.keys():
			if str(k).begins_with(prefix):
				dict.erase(k)

## Something a task counts happened: &"gather" (units landed), &"craft" and &"craft:<recipe>", &"hunt" (a
## kill), &"butcher" (a part kind taken from a carcass), &"build", &"explore30", &"mineral60".
static func note(kind: StringName, n: int = 1) -> void:
	if n <= 0:
		return
	roll()
	for cat in ["daily", "weekly", "life"]:
		var k := "%s.%s" % [cat, kind]
		counts[k] = int(counts.get(k, 0)) + n

# ---------------------------------------------------------------- rows

## The rows of category `cat` for `p`, in list order: claimable first, then in progress, claimed last.
## Row: {id, cat, title, desc, icon, got, want, frac, done, claimed, claimable, rewards: {t_stones, sp, xp}}.
static func rows(cat: StringName, p: Player) -> Array[Dictionary]:
	roll()
	var out: Array[Dictionary] = []
	match cat:
		&"main":
			out = _main_rows(p)
		&"daily", &"weekly":
			for t: Dictionary in defs().get(str(cat), []):
				if not t.get("hidden", false):
					out.append(_row(cat, t, _counted(str(cat), t.get("count", ""))))
		&"domain":
			for t: Dictionary in defs().get("domain", []):
				if not t.get("hidden", false):
					out.append(_row(cat, t, int(World.pioneer_buildings.get(str(t.get("kind", "")), 0))))
		&"achievement":
			out = _achievement_rows(p)
	var rank := func (r: Dictionary) -> int: return 0 if r["claimable"] else (2 if r["claimed"] else 1)
	var order: Array[Dictionary] = []
	for want_rank in 3:
		for r in out:
			if rank.call(r) == want_rank:
				order.append(r)
	return order

## The count `what` (a kind, or a list of kinds that sum) under `prefix` ("daily", "weekly", "life").
static func _counted(prefix: String, what: Variant) -> int:
	var n := 0
	for k in (what if what is Array else [what]):
		n += int(counts.get("%s.%s" % [prefix, k], 0))
	return n

static func _row(cat: StringName, t: Dictionary, got: int) -> Dictionary:
	var want := maxi(1, int(t.get("want", 1)))
	var id := "%s.%s" % [cat, t.get("id", "")]
	var desc := str(t.get("desc", ""))
	return _shape(id, cat, str(t.get("title", "")), desc % want if desc.contains("%d") else desc, str(t.get("icon", "notice")),
		got, want, got >= want, {"t_stones": int(t.get("t_stones", 0)), "warp_gems": int(t.get("warp_gems", 0)), "xp": int(t.get("xp", 0)), "sp": int(t.get("sp", 0))})

static func _shape(id: String, cat: StringName, title: String, desc: String, icon: String, got: int, want: int, done: bool, rewards: Dictionary) -> Dictionary:
	var is_claimed := claimed.has(id)
	return {"id": id, "cat": cat, "title": title, "desc": desc, "icon": icon, "got": mini(got, want), "want": want,
		"frac": clampf(float(got) / float(want), 0.0, 1.0), "done": done, "claimed": is_claimed,
		"claimable": done and not is_claimed, "rewards": rewards}

## Every order of the running list (Objectives._steps: the tutorial's while it runs, else the standing
## orders). Done = finished by Objectives.settle (the `done` set, not the index: the tutorial hands over to
## the standing orders part-way down their list). The running one reads its best-held count; a later one
## reads the bag now. An earlier order that was never finished (skipped by that hand-over) is not listed.
## A finished, unreceived order of the other list (the tutorial's, once it ended) stays listed until received.
static func _main_rows(p: Player) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var steps := Objectives._steps()
	var listed := {}
	for i in steps.size():
		var s: Dictionary = steps[i]
		var id := "main." + str(s.get("id", i))
		listed[id] = true
		var is_done := done.has(id)
		if i < World.objective and not is_done:
			continue
		var st: Dictionary = {"got": 1, "want": 1}
		if not is_done:
			st = {"got": 0, "want": 1}
			if p != null:
				st = Objectives._progress(p, s)
				if i == World.objective:
					st = Objectives._with_best(st)
		var r := _shape(id, &"main", str(s.get("title", "")), str(s.get("hint", "")), "notice",
			int(st["got"]), int(st["want"]), is_done, {"t_stones": int(s.get("t_stones", 0)), "warp_gems": int(s.get("warp_gems", 0)), "xp": int(s.get("xp", 0)), "sp": 0})
		r["index"] = i
		out.append(r)
	for list_name in ["world_tutorial", "world_objectives"]:
		var other: Variant = Data.get(list_name)
		if not other is Array:
			continue
		for s: Dictionary in other:
			var id := "main." + str(s.get("id", ""))
			if not listed.has(id) and done.has(id) and not claimed.has(id):
				listed[id] = true
				var r := _shape(id, &"main", str(s.get("title", "")), str(s.get("hint", "")), "notice", 1, 1, true,
					{"t_stones": int(s.get("t_stones", 0)), "warp_gems": int(s.get("warp_gems", 0)), "xp": int(s.get("xp", 0)), "sp": 0})
				r["index"] = -1
				out.append(r)
	return out

## One row per chain (the character level, then each skill tree in SkillState.ORDER): its lowest unclaimed
## milestone, or its last one once every milestone is claimed. Levels come from the skills API only.
static func _achievement_rows(p: Player) -> Array[Dictionary]:
	var a: Dictionary = defs().get("achievement", {})
	var chains: Array = [["character", "Character", "equip", a.get("character_levels", [])]]
	for tree in SkillState.ORDER:
		chains.append([tree, str(SkillState.NAMES.get(tree, tree)), tree, a.get("skill_levels", [])])
	var out: Array[Dictionary] = []
	for c: Array in chains:
		var milestones: Array = c[3]
		if milestones.is_empty():
			continue
		var lv := 0
		if p != null and p.skills != null:
			lv = p.skills.character_level() if c[0] == "character" else p.skills.level_of(str(c[0]))
		var pick := int(milestones[milestones.size() - 1])
		for m in milestones:
			if not claimed.has("achievement.%s.%d" % [c[0], int(m)]):
				pick = int(m)
				break
		var rewards := {"t_stones": int(a.get("t_stones_per_level", 1)) * pick, "sp": int(a.get("skill_points", 1)), "xp": int(a.get("xp_per_level", 5)) * pick}
		out.append(_shape("achievement.%s.%d" % [c[0], pick], &"achievement", "Level Up %s" % c[1],
			"Reach %s level %d." % ["character" if c[0] == "character" else str(c[1]), pick], str(c[2]), lv, pick, lv >= pick, rewards))
	for t: Dictionary in a.get("tasks", []):
		if not t.get("hidden", false):
			out.append(_row(&"achievement", t, _counted("life", t.get("count", ""))))
	return out

static func find(id: String, p: Player) -> Dictionary:
	var cat := StringName(id.get_slice(".", 0))
	for r in rows(cat, p):
		if r["id"] == id:
			return r
	return {}

# ---------------------------------------------------------------- claiming

## How many tasks in `cat` (every category when &"") can be received now. Cheap enough to poll.
static func claimable_count(p: Player, cat: StringName = &"") -> int:
	var n := 0
	for c in CATS:
		if cat == &"" or c == cat:
			for r in rows(c, p):
				n += 1 if r["claimable"] else 0
	return n

## Pays task `id` once, when it is complete and not yet received. Returns its row (with the rewards
## paid) or {} when there is nothing to pay. T-stones and character XP go to World, skill points to
## SkillState.sp_extra (spec 03's one-time SP outside character levels).
static func claim(id: String, p: Player) -> Dictionary:
	var r := find(id, p)
	if r.is_empty() or not r["claimable"]:
		return {}
	claimed[id] = true
	var rw: Dictionary = r["rewards"]
	World.t_stones += int(rw.get("t_stones", 0))
	World.warp_gems += maxi(0, int(rw.get("warp_gems", 0))) # BAGUI: the knife order's tutorial grant
	World.add_xp(int(rw.get("xp", 0)))
	if int(rw.get("sp", 0)) > 0 and p != null and p.skills != null:
		p.skills.sp_extra += int(rw["sp"])
		p.skills.sp_now()
	print("[tasks] received %s (+%d gold, +%d gems, +%d SP, +%d xp)" % [id, int(rw.get("t_stones", 0)), int(rw.get("warp_gems", 0)), int(rw.get("sp", 0)), int(rw.get("xp", 0))])
	r["claimed"] = true
	r["claimable"] = false
	return r

# ---------------------------------------------------------------- save

static func to_dict() -> Dictionary:
	return {"claimed": claimed.duplicate(), "done": done.duplicate(), "counts": counts.duplicate(), "day": day, "week": week}

## `v` is the save's "tasks" block. A save from before the Task screen has none: its standing orders up
## to World.objective were paid when they finished, so they load as received (set World.objective first).
static func from_dict(v: Variant) -> void:
	claimed = {}
	counts = {}
	done = {}
	day = -1
	week = -1
	if v is Dictionary and (v as Dictionary).has("claimed"):
		var d: Dictionary = v
		for k in (d["claimed"] if d["claimed"] is Dictionary else {}):
			claimed[str(k)] = true
		for k in (d["done"] if d.get("done") is Dictionary else {}):
			done[str(k)] = true
		var c: Dictionary = d["counts"] if d.get("counts") is Dictionary else {}
		for k in c:
			counts[str(k)] = clampi(int(c[k]), 0, 1000000) if (c[k] is int or c[k] is float) else 0
		day = int(d["day"]) if (d.get("day") is int or d.get("day") is float) else -1
		week = int(d["week"]) if (d.get("week") is int or d.get("week") is float) else -1
	else:
		var steps := Objectives._steps()
		for i in mini(World.objective, steps.size()):
			var id := "main." + str((steps[i] as Dictionary).get("id", i))
			claimed[id] = true
			done[id] = true
	roll()
