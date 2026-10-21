extends RefCounted
## W2-PROCESS checks that run in one frame, shared by t_process and run_all: a rack job on the wall
## clock, exact XP per collected job, a save round trip, done colours, and hand-edited process rows through the real load path (SaveSanitizer.clean ->
## SaveRestore.spawn -> ProcessStation.load_dict) and the refund path (saved_stacks). Review r1: a
## forged row injected 1e9 dried meat at level 5e6, a non-number start aborted load_dict and lost the
## row's meat, a string start finished the job at once, and a duplicated uid loaded twice.
## Classes load inside run(): run_all compiles this file before the autoloads exist.

func run(root: Node) -> Dictionary:
	var out := {}
	var IS: GDScript = load("res://scripts/items/item_stack.gd")
	var INV: GDScript = load("res://scripts/items/inventory.gd")
	var CS: GDScript = load("res://scripts/world/craft_station.gd")
	var PS: GDScript = load("res://scripts/world/process_station.gd")
	var SR: GDScript = load("res://scripts/core/save_restore.gd")
	var SAN: GDScript = load("res://scripts/core/save_sanitizer.gd")
	var now: float = PS.now_s()
	var secs: float = PS.job_seconds(&"drying_rack", &"dry_meat")

	var rack: Node3D = CS.make(&"drying_rack")
	root.add_child(rack)
	var ps = PS.of(rack)
	var inv = INV.new(4)
	inv.add(IS.make(&"raw_meat", 1))
	var loaded: int = ps.load_from(inv, &"dry_meat", 1)
	ps.advance(now + secs - 5.0)
	var early: int = ps.ready_count()
	ps.advance(now + secs + 1.0)
	var bag = INV.new(4)
	out["a rack job finishes on the wall clock and collects once (loaded %d, early %d)" % [loaded, early]] = loaded == 1 and early == 0 and ps.collect_into(bag) == 1 and ps.collect_into(bag) == 0
	rack.free()

	var meat := {"id": "raw_meat", "count": 1}
	var job := func (extra: Dictionary) -> Dictionary:
		var j := {"recipe": "dry_meat", "inputs": [meat.duplicate()], "queued_at": now, "started": now, "level": 1}
		j.merge(extra, true)
		return j
	var cases := {
		"huge_count": {"jobs": [], "outputs": [{"recipe": "dry_meat", "stack": {"id": "dried_meat", "count": 1000000000, "level": 5000000}}]},
		"huge_job_level": {"jobs": [job.call({"recipe": "camp_stew", "level": 9999999})], "outputs": []},
		"started_string": {"jobs": [job.call({"started": "abc"})], "outputs": []},
		"started_array": {"jobs": [job.call({"started": [1, 2], "queued_at": [1], "level": [3], "burnt": "yes"})], "outputs": []},
		"started_future": {"jobs": [job.call({"started": now + 3600.0, "queued_at": now + 3600.0})], "outputs": []},
		"not_arrays": {"jobs": "x", "outputs": 5},
		"dup_uid": {"jobs": [], "outputs": [
			{"recipe": "dry_meat", "stack": {"id": "dried_meat", "count": 1, "uid": "l00ab"}},
			{"recipe": "dry_meat", "stack": {"id": "dried_meat", "count": 1, "uid": "l00ab"}}]},
	}
	var got := {}
	for k in cases:
		var kind := "crock_pot" if k == "huge_job_level" else "drying_rack"  # a stew job needs a pot
		var save: Dictionary = SAN.clean({"home": {"buildings": [{"kind": kind, "cell": [0, 0], "rot": 0, "x": 0.0, "z": 0.0, "process": cases[k]}]}})
		var row: Dictionary = save["home"]["buildings"][0]
		var refund: Array = PS.saved_stacks(row.get("process", {}))
		var st: Node3D = SR.spawn(row)
		root.add_child(st)
		var p = PS.of(st)
		var r := {"jobs": p.jobs.size(), "ready": p.ready_count(), "refund": 0, "level": 0, "units": 0}
		for s in refund:
			r["refund"] += s.count
		if not p.jobs.is_empty():
			r["job_level"] = int(p.jobs[0]["level"])
			r["started"] = float(p.jobs[0]["started"])
			r["label"] = p.label_text()
		var b = INV.new(40)
		p.collect_into(b)
		for s in b.slots:
			if s:
				r["level"] = maxi(r["level"], s.level)
				r["units"] += s.count
		r["left"] = p.ready_count()
		got[k] = r
		st.free()
	var huge: Dictionary = got["huge_count"]
	var cap: int = IS.make(&"dried_meat", 1).def().stack_max  # the bound a bag row in the same save gets
	out["a forged 1e9 x lv 5e6 output loads as one stack of <= %d at lv <= 60 (%s)" % [cap, huge]] = huge["units"] <= cap and huge["level"] <= 60 and huge["left"] == 0 and huge["refund"] <= cap
	out["a forged job level is clamped to 60 (%s)" % [got["huge_job_level"]]] = int(got["huge_job_level"].get("job_level", 0)) == 60
	out["a string start restarts the job, it does not finish it (%s)" % [got["started_string"]]] = got["started_string"]["jobs"] == 1 and got["started_string"]["ready"] == 0
	out["array numbers do not abort the load: the meat stays on the rack (%s)" % [got["started_array"]]] = got["started_array"]["jobs"] == 1 and got["started_array"]["refund"] == 1
	var fut: Dictionary = got["started_future"]
	var left_s := -1
	if fut.has("label"):
		var t := str(fut["label"]).get_slice("·", 1).strip_edges()
		left_s = int(t.get_slice(":", 0)) * 60 + int(t.get_slice(":", 1))
	out["a start an hour in the future loads as now, label time <= job length (%s, %ds)" % [fut, left_s]] = fut["jobs"] == 1 and float(fut.get("started", INF)) <= PS.now_s() and left_s >= 0 and left_s <= int(secs)
	out["jobs/outputs that are not arrays load nothing and do not abort (%s)" % [got["not_arrays"]]] = got["not_arrays"]["jobs"] == 0 and got["not_arrays"]["ready"] == 0
	out["a uid on two outputs loads once (%s)" % [got["dup_uid"]]] = got["dup_uid"]["units"] == 1 and got["dup_uid"]["refund"] == 1

	# Review r3: a hand-edited row with 40 queued jobs loaded all 40 onto a 4-slot steamer. Jobs past
	# capacity are outputs of their own inputs: nothing lost, nothing over capacity.
	var many: Array = []
	for i in 40:
		many.append({"recipe": "steam", "inputs": [{"id": "dried_meat", "count": 1}], "queued_at": now, "started": -1.0, "level": 1})
	var srow: Dictionary = SAN.clean({"home": {"buildings": [{"kind": "steamer", "cell": [0, 0], "rot": 0, "x": 0.0, "z": 0.0, "process": {"jobs": many, "outputs": []}}]}})["home"]["buildings"][0]
	var steamer: Node3D = SR.spawn(srow)
	root.add_child(steamer)
	var sp = PS.of(steamer)
	out["40 saved jobs on a 4-place steamer load as %d jobs + %d to collect (40 units kept)" % [sp.jobs.size(), sp.ready_count()]] = sp.jobs.size() == sp.capacity() and sp.jobs.size() + sp.ready_count() == 40
	steamer.free()

	# Review r3: nothing checked collect pays XP exactly once per job (spec 08:126 "repeated XP"; a
	# mutation paying it twice passed every gate). A fresh SkillState banks every point (helper below).
	var PLAYER: GDScript = load("res://scripts/player/player.gd")
	var SK: GDScript = load("res://scripts/skills/skill_state.gd")
	var CR: GDScript = load("res://scripts/items/crafting.gd")
	var who = PLAYER.new()
	var sk = SK.new()
	who.add_child(sk)
	who.skills = sk
	sk._load()
	var per: int = 6 + int(CR.recipe_seconds(CR.recipe(&"dry_meat")))
	var rack2: Node3D = CS.make(&"drying_rack")
	root.add_child(rack2)
	var p2 = PS.of(rack2)
	var xp: Array[float] = []
	for _r in 2:
		var src = INV.new(4)
		for i in 2:
			src.add(IS.make(&"raw_meat", 1))
		p2.load_from(src, &"dry_meat", 2)
		p2.advance(PS.now_s() + secs + 1.0)
		p2.collect_into(INV.new(8), who)
		xp.append(_tree_xp(sk, "processing"))
	p2.collect_into(INV.new(8), who)  # nothing left: pays nothing
	xp.append(_tree_xp(sk, "processing"))
	out["collect pays %d Processing XP per dried meat, once: 2 -> %.0f, 4 -> %.0f, empty collect -> %.0f (want %d, %d, %d)" % [per, xp[0], xp[1], xp[2], 2 * per, 4 * per, 4 * per]] = xp == [2.0 * per, 4.0 * per, 4.0 * per]
	rack2.free()
	who.free()

	# Review r3: only t_process round-tripped a loaded station through CraftStation.to_dict; run_all
	# passed with the "process" key dropped from the save row.
	var rack3: Node3D = CS.make(&"drying_rack")
	root.add_child(rack3)
	var meat3 = IS.make(&"raw_meat", 1)
	meat3.stamp_identity("loot", "tester")
	var inv3 = INV.new(2)
	inv3.add(meat3)
	PS.of(rack3).load_from(inv3, &"dry_meat", 1)
	var row3: Dictionary = JSON.parse_string(JSON.stringify(rack3.to_dict()))
	rack3.free()
	var back3: Node3D = SR.spawn(row3)
	root.add_child(back3)
	var p3 = PS.of(back3)
	var uid3 := str(p3.jobs[0]["inputs"][0].uid) if p3 and p3.jobs.size() == 1 else ""
	out["a loaded rack saves and loads its job through to_dict -> JSON -> spawn (uid %s)" % uid3] = uid3 != "" and uid3 == meat3.uid
	back3.free()

	# Review r3: done food read as an empty dish (steamed: near-white) or vanished in a dark doorway
	# (smoked: near-black). Every station's done colour keeps some colour and some light.
	for sid: String in (PS.rules().get("stations", {}) as Dictionary):
		var c: Variant = PS.config_for(StringName(sid)).get("contents")
		if c is Dictionary:
			var to := Color(str((c as Dictionary).get("to", "#000000")))
			out["%s done colour %s is not near-white or near-black (s %.2f, v %.2f)" % [sid, to.to_html(false), to.s, to.v]] = to.s >= 0.35 and to.v >= 0.33
	return out

## A tree's XP since Lv. 1, counting levels gained, so the check holds whatever level cap applies.
static func _tree_xp(sk: Object, tree: String) -> float:
	var t: Dictionary = sk.trees[tree]
	var total := float(t["xp"])
	for l in range(1, int(t["level"])):
		total += sk.xp_to_next(l)
	return total
