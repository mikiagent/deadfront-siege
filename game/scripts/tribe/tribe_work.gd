class_name TribeWork
extends RefCounted
## TRIBE M2a hand-off (docs/design/hunger-and-tribe-automation.md §2.2, §2.8): the survivor picks a
## recipe and its exact materials at a station, or fills a construction site, and ASSIGNS one member
## instead of doing the labour herself. A craft order moves the picked instances out of her bag into
## the member's escrow (TribeRecord.escrow) at once; the member walks over, plays the station's work
## clip and crafts at its OWN skill (the same outcome curve, level cap and burn rule as the survivor at
## that skill); XP goes to the member; the output goes to a chest beside the station, else her bag.
## A build order lets the member drive the site's work timer and finish it at its Construction level.
## Cancel (or any other order) hands the escrow back. Numbers: data/tribe.json "work" (ASSUMPTIONs).
## Server line: like every bag verb this would be an intent the server owns online; M2a is local only.

static var rng := RandomNumberGenerator.new()

static func num(key: String, fallback: float) -> float:
	return Tribe.section_num("work", key, fallback)

static func is_station_job(r: TribeRecord) -> bool:
	return r != null and r.order == &"work" and StringName(str(r.job.get("kind", ""))) in TribeRecord.STATION_JOBS

static func job_kind(r: TribeRecord) -> StringName:
	return StringName(str(r.job.get("kind", ""))) if r else &""

## Work time at a skill level: base × (1 − speed_per_level × level), never below min_time_mult (memo
## §2.2 "the same formula for player and worker"; # ASSUMPTION: only workers use it in M2a).
static func time_mult(level: int) -> float:
	return maxf(num("min_time_mult", 0.5), 1.0 - num("speed_per_level", 0.01) * float(level))

static func nice_skill(id: String) -> String:
	return LevelDisplay.nice_name(id)

## The lowest level of `skill` whose success reaches the minimum, for the refusal text.
static func level_for_success(rec: Dictionary, min_success: float) -> int:
	for lv in range(1, int(Tribe.num("max_skill", 60)) + 1):
		if Crafting.success_chance(rec, float(lv)) >= min_success:
			return lv
	return int(Tribe.num("max_skill", 60))

# ---------------------------------------------------------------- where the work is

static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## The station a craft order names: the craft station of that kind standing on the saved spot.
static func find_station(job: Dictionary) -> Node3D:
	var at: Array = job.get("station", [])
	if at.size() != 2 or _tree() == null:
		return null
	var spot := Vector3(float(at[0]), 0.0, float(at[1]))
	for n in _tree().get_nodes_in_group("craft_station"):
		if n is Node3D and not n.is_queued_for_deletion() and Crafting.node_station_id(n) == str(job.get("station_id", "")) \
				and _flat((n as Node3D).global_position, spot) < 1.0:
			return n as Node3D
	return null

static func find_site(site_id: String) -> ConstructionSite:
	if site_id == "" or _tree() == null:
		return null
	for n in _tree().get_nodes_in_group(ConstructionSite.GROUP):
		if n is ConstructionSite and not n.is_queued_for_deletion() and (n as ConstructionSite).site_id == site_id:
			return n as ConstructionSite
	return null

static func target_of(r: TribeRecord) -> Node3D:
	match job_kind(r):
		&"craft":
			return find_station(r.job)
		&"build":
			return find_site(str(r.job.get("site", "")))
	return null

## The member on a work order at this station or site, else null (one order per worksite).
static func worker_at(n: Node) -> TribeRecord:
	if n == null:
		return null
	for r in Tribe.members:
		if is_station_job(r) and target_of(r) == n:
			return r
	return null

## Where a member stands to work: the station's reach (the survivor's), the site's edge.
static func reach(n: Node3D) -> float:
	if n is ConstructionSite:
		var fp := Blueprints.footprint((n as ConstructionSite).bp())
		return 0.5 * float(maxi(fp.x, fp.y)) * BuildGrid.CELL_SIZE + 0.8  # ASSUMPTION: an arm past the plot's edge
	return Crafting.STATION_RANGE

## The chest a station's output goes to: the storage building nearest the station inside chest_link_m.
static func linked_chest(st: Node3D) -> Node3D:
	if st == null or _tree() == null:
		return null
	var best: Node3D = null
	var best_d := num("chest_link_m", 6.0)
	for n in _tree().get_nodes_in_group("placed_building"):
		if n == st or n.is_queued_for_deletion() or not (n.get("storage") is Inventory):
			continue
		var d := _flat((n as Node3D).global_position, st.global_position)
		if d < best_d:
			best_d = d
			best = n as Node3D
	return best

# ---------------------------------------------------------------- craft orders

## What one member would do with this recipe at this station: skill, success, time, and why not.
## `picks` are the survivor's bag indices (Crafting picks); [] skips the materials check.
static func craft_offer(p: Player, r: TribeRecord, rec: Dictionary, station: Node3D, picks: Array[int] = []) -> Dictionary:
	var skill := str(rec.get("skill", "processing"))
	var lv := r.skill(skill) if r else 1
	# ASSUMPTION: a member has no learned nodes or food buffs yet (M2b), so its ability is its level.
	var out := {"skill": skill, "level": lv, "success": Crafting.success_chance(rec, float(lv)),
		"seconds": Crafting.recipe_seconds(rec) * time_mult(lv), "why": ""}
	out["why"] = _craft_why(p, r, rec, station, picks, out)
	return out

static func _craft_why(p: Player, r: TribeRecord, rec: Dictionary, station: Node3D, picks: Array[int], o: Dictionary) -> String:
	if r == null or not Tribe.members.has(r):
		return "No member"
	if is_station_job(r):
		return "%s is busy (%s)" % [r.name, plate_text(r)]
	var rid := str(rec.get("id", ""))
	var sid := Crafting.station_id(rec)
	if sid == "":
		return "Only station crafts can be handed off"  # ASSUMPTION: hand recipes stay the survivor's
	if station == null or not is_instance_valid(station) or Crafting.node_station_id(station) != sid:
		return "Needs a %s" % LevelDisplay.nice_name(sid).to_lower()
	var ps := ProcessStation.of(station)
	if ps and ps.runs(StringName(rid)):
		return "The %s runs this by itself" % LevelDisplay.nice_name(sid).to_lower()
	var other := worker_at(station)
	if other and other != r:
		return "%s already works here" % other.name
	if bool((Tribe.cfg().get("work", {}) as Dictionary).get("teach_by_doing", true)) and not World.pioneer_crafts.has(rid):
		return "Craft it once yourself first"  # memo §2.5 "teach by doing"
	var tool := Crafting.tool_block(tool_bag(r), rec)
	if tool != "":
		return tool  # RECIPETOOLS: the member's own held work tool, never the survivor's
	var minimum := int(rec.get("min_level", 0))
	if minimum > int(o["level"]):
		return "Needs %s %d" % [nice_skill(str(o["skill"])), minimum]
	if p and not picks.is_empty() and (Crafting.missing_ingredient_name(p.inventory, rec) != "" or not Crafting.picks_valid(p.inventory, rec, picks)):
		return "Missing materials"
	var min_ok := num("min_success", 0.8)
	if float(o["success"]) < min_ok:
		return "%d%% success, needs %s %d" % [roundi(float(o["success"]) * 100.0), nice_skill(str(o["skill"])), level_for_success(rec, min_ok)]
	return ""

## A member's hands as a one-slot bag (the tool it holds in its weapon slot), for recipe tool gates.
static func tool_bag(r: TribeRecord) -> Inventory:
	var inv := Inventory.new(1)
	inv.slots[0] = r.equipment.worn(&"weapon") if r else null
	return inv

## The survivor's picks for `uids` (one per recipe slot, from the craft panel): each slot led by that
## instance wherever the bag holds it now, the rest default.
static func picks_for(inv: Inventory, rec: Dictionary, uids: Array[String]) -> Array[int]:
	var picks := Crafting.default_picks(inv, rec)
	for i in mini(picks.size(), uids.size()):
		if uids[i] != "":
			var at := _index_of(inv, uids[i])
			if at >= 0:
				picks[i] = at
	return picks

static func _index_of(inv: Inventory, uid: String) -> int:
	for i in inv.slot_count:
		if inv.slots[i] and inv.slots[i].uid == uid:
			return i
	return -1

## Assign one craft of `rid` at `station` to `r`. Moves the planned instances into escrow now and
## decides the outcome at the member's skill (never re-rolled, as CRAFTFEEL). "" or why not.
static func assign_craft(p: Player, r: TribeRecord, station: Node3D, rid: StringName, uids: Array[String] = []) -> String:
	var rec := Crafting.recipe(rid)
	if p == null or rec.is_empty():
		return "Unknown recipe"
	var picks := picks_for(p.inventory, rec, uids)
	var o := craft_offer(p, r, rec, station, picks)
	if str(o["why"]) != "":
		return str(o["why"])
	if Crafting.missing_ingredient_name(p.inventory, rec) != "":
		return "Missing materials"
	# Pin the exact units the survivor's picks spend (the plan's own rows), then move them.
	var pin := Crafting.plan_craft(rec, p.inventory, picks, 0.0, 1, 0, rng)
	var parts := Crafting.plan_parts(p.inventory, rec, pin)
	if pin.is_empty() or parts.is_empty():
		return "Missing materials"
	if is_station_job(r) or r.escrow.used_slots() > 0:
		return "%s is busy" % r.name
	var lead: Array = pin.get("uids", [])
	for s in Crafting.consume_parts(p.inventory, rec, parts):
		r.escrow.add(s)
	var ep := Crafting.default_picks(r.escrow, rec)
	for i in mini(ep.size(), lead.size()):
		var at := _index_of(r.escrow, str(lead[i])) if str(lead[i]) != "" else -1
		if at >= 0:
			ep[i] = at
	var lv := int(o["level"])
	var level := ProgressionScaling.crafted_level(Crafting.consumed_levels(r.escrow, rec, ep), int(rec.get("max_level", 60)), lv)
	var plan := Crafting.plan_craft(rec, r.escrow, ep, float(lv), level, lv, rng)
	if plan.is_empty():
		refund(p, r)
		return "Missing materials"
	var oc: Dictionary = plan["outcome"]
	r.job = {"kind": "craft", "center": [station.global_position.x, station.global_position.z], "radius": 3.0, "chest": [],
		"station": [station.global_position.x, station.global_position.z], "station_id": Crafting.node_station_id(station),
		"recipe": str(rid), "picks": Array(ep), "level": level, "burnt": bool(plan.get("burnt", false)),
		"outcome": {"success": bool(oc.get("success", true)), "flawless": bool(oc.get("flawless", false)), "rare": str(oc.get("rare", ""))},
		"seconds": float(o["seconds"]), "progress": 0.0, "made": false}
	r.order = &"work"
	Tribe.version += 1
	print("[tribe] %s assigned %s at %s (%s %d, %.0f%%, %.1fs, success=%s)" % [r.name, rid, r.job["station_id"], o["skill"], lv, float(o["success"]) * 100.0, float(o["seconds"]), oc.get("success", true)])
	return ""

# ---------------------------------------------------------------- build orders

static func build_offer(r: TribeRecord, site: ConstructionSite) -> Dictionary:
	var lv := r.skill("construction") if r else 1
	var left := 0.0
	if site and is_instance_valid(site):
		left = maxf(0.0, float(site.bp().get("work_seconds", 1.0)) - site.work_progress) * time_mult(lv)
	var out := {"skill": "construction", "level": lv, "success": 1.0, "seconds": left,
		"result_level": site.preview_level(lv) if site and is_instance_valid(site) else 0, "why": ""}
	if r == null or not Tribe.members.has(r):
		out["why"] = "No member"
	elif is_station_job(r):
		out["why"] = "%s is busy (%s)" % [r.name, plate_text(r)]
	elif site == null or not is_instance_valid(site):
		out["why"] = "The site is gone"
	elif not site.materials_ready():
		out["why"] = "Missing materials"
	elif site.ready_to_finish():
		out["why"] = "Already built: tap Finish"
	elif worker_at(site) and worker_at(site) != r:
		out["why"] = "%s is already building it" % worker_at(site).name
	return out

## Assign a filled site to a builder: it walks over and works the site's timer at its own speed, then
## finishes it at its Construction level (BuildFlow.complete). "" or why not.
static func assign_build(r: TribeRecord, site: ConstructionSite) -> String:
	var o := build_offer(r, site)
	if str(o["why"]) != "":
		return str(o["why"])
	r.job = {"kind": "build", "center": [site.global_position.x, site.global_position.z], "radius": 3.0, "chest": [], "site": site.site_id}
	r.order = &"work"
	site.set_meta(&"tribe_builder", r.uid)  # the site's own timer stops: the builder drives it
	Tribe.version += 1
	print("[tribe] %s assigned to build %s (%s)" % [r.name, site.site_id, site.blueprint_id])
	return ""

# ---------------------------------------------------------------- the work itself

## One frame of work by the member's body at its target. Drains energy and fatigue like gathering.
static func advance(r: TribeRecord, target: Node3D, delta: float) -> void:
	if not is_station_job(r) or target == null:
		return
	r.fatigue = minf(Tribe.num("fatigue_max", 100.0), r.fatigue + num("fatigue_per_work_s", 0.25) * delta)
	r.energy = maxf(0.0, r.energy - num("energy_per_work_s", 0.15) * delta)
	if job_kind(r) == &"build":
		_advance_build(r, target as ConstructionSite, delta)
		return
	if bool(r.job.get("made", false)):
		r.job["retry"] = float(r.job.get("retry", 0.0)) - delta
		if float(r.job["retry"]) <= 0.0:
			r.job["retry"] = 1.0
			_deliver(PlayerRegistry.local(), r, target)
		return
	r.job["progress"] = float(r.job.get("progress", 0.0)) + delta
	if float(r.job["progress"]) >= float(r.job.get("seconds", 1.0)):
		_finish_craft(r, target)

static func progress(r: TribeRecord) -> float:
	if job_kind(r) == &"build":
		var s := find_site(str(r.job.get("site", "")))
		return s.work_ratio() if s else 0.0
	return clampf(float(r.job.get("progress", 0.0)) / maxf(0.01, float(r.job.get("seconds", 1.0))), 0.0, 1.0)

## The decided plan, run on the escrow: success puts the output in escrow and pays the member's XP;
## failure spends the materials (spec 25 §8), exactly as the survivor's craft.
static func _finish_craft(r: TribeRecord, station: Node3D) -> void:
	var p := PlayerRegistry.local()
	var rid := StringName(str(r.job.get("recipe", "")))
	var rec := Crafting.recipe(rid)
	var picks: Array[int] = []
	for v: Variant in r.job.get("picks", []):
		picks.append(int(v))
	if not Crafting.picks_valid(r.escrow, rec, picks):
		picks = Crafting.default_picks(r.escrow, rec)
	var lv := r.skill(str(rec.get("skill", "processing")))
	var plan := Crafting.plan_craft(rec, r.escrow, picks, float(lv), int(r.job.get("level", 1)), lv, rng)
	if plan.is_empty():
		print("[tribe] %s craft %s: escrow no longer fits the recipe; handing it back" % [r.name, rid])
		cancel(p, r)
		return
	var oc: Dictionary = r.job.get("outcome", {})
	plan["outcome"] = {"success": bool(oc.get("success", true)), "flawless": bool(oc.get("flawless", false)), "rare": StringName(str(oc.get("rare", "")))}
	plan["burnt"] = bool(r.job.get("burnt", false))
	var none: Array[ItemStack] = []
	var res := Crafting.run_plan(rec, r.escrow, plan, none, tool_bag(r))
	var name := str(rec.get("display_name", rid))
	match str(res.get("status", "")):
		"made":
			r.add_skill_xp(Crafting.tree_for_recipe(rec), 6.0 + float(int(Crafting.recipe_seconds(rec))))
			r.job["made"] = true
			r.job["retry"] = 0.0
			print("[tribe] %s made %s (%s now %d)" % [r.name, rid, Crafting.tree_for_recipe(rec), r.skill(Crafting.tree_for_recipe(rec))])
			_deliver(p, r, station)
		"failed":
			if p:
				p.notice("%s's %s failed: the materials are lost." % [r.name, name])
			_end(r, "")
		_:
			if p:
				p.notice("%s stopped the %s: %s" % [r.name, name, str(res.get("why", res.get("status", "")))])
			cancel(p, r)

## Output (and anything left in escrow) into the station's chest, else the survivor's bag. What fits
## nowhere waits in escrow and is retried every second; the plate says so.
static func _deliver(p: Player, r: TribeRecord, station: Node3D) -> void:
	var chest := linked_chest(station)
	var where: PackedStringArray = []
	for i in r.escrow.slot_count:
		var st := r.escrow.slots[i]
		if st == null or st.def_id == Inventory.LOCK:
			continue
		var made := st.def_id
		var had := st.count
		var left := had
		if chest:
			left = (chest.get("storage") as Inventory).add(st)
			if left < had and not where.has("the %s" % LevelDisplay.nice_name(BuildPlacer.kind_of_building(chest)).to_lower()):
				where.append("the %s" % LevelDisplay.nice_name(BuildPlacer.kind_of_building(chest)).to_lower())
		if left > 0 and p:
			var before := left
			left = p.inventory.add(st)
			if left < before and not where.has("your bag"):
				where.append("your bag")
		if left <= 0:
			r.escrow.slots[i] = null
		if left < had and p:
			p.toast(made, had - left)
	r.escrow.changed.emit()
	var rec := Crafting.recipe(StringName(str(r.job.get("recipe", ""))))
	if r.escrow.used_slots() > 0:
		r.job["waiting"] = true
		return
	if p:
		p.notice("%s made the %s%s" % [r.name, str(rec.get("display_name", r.job.get("recipe", ""))), (" (in " + " and ".join(where) + ")") if not where.is_empty() else ""])
	_end(r, "")

static func _advance_build(r: TribeRecord, site: ConstructionSite, delta: float) -> void:
	if site == null or not is_instance_valid(site):
		return
	var secs := float(site.bp().get("work_seconds", 1.0))
	site.work_progress = minf(secs, site.work_progress + delta / time_mult(r.skill("construction")))
	if not site.work_done():
		return
	var p := PlayerRegistry.local()
	var name := str(site.bp().get("display_name", "site"))
	var built := BuildFlow.complete(p, site, r)
	if built == null:
		return  # complete() said why (no island runtime); the builder keeps standing by
	if p:
		p.notice("%s finished the %s" % [r.name, name])
	_end(r, "")

## Order over: the member stands down where it is.
static func _end(r: TribeRecord, _why: String) -> void:
	var s := find_site(str(r.job.get("site", ""))) if job_kind(r) == &"build" else null
	if s and str(s.get_meta(&"tribe_builder", "")) == r.uid:
		s.remove_meta(&"tribe_builder")
	r.job = {}
	r.order = &"stay"
	Tribe.version += 1

# ---------------------------------------------------------------- cancel and refunds

## Stop the order and hand back everything in escrow (all or nothing: a bag that cannot take it all
## keeps the order running). "" or why not.
static func cancel(p: Player, r: TribeRecord) -> String:
	if r == null:
		return "No member"
	if r.escrow.used_slots() > 0:
		var why := refund(p, r)
		if why != "":
			return why
	if is_station_job(r):
		print("[tribe] %s's %s order cancelled" % [r.name, job_kind(r)])
		_end(r, "")
	return ""

## Escrow back into the survivor's bag, all or nothing. `quiet`: no notice (the director's retry).
static func refund(p: Player, r: TribeRecord, quiet: bool = false) -> String:
	var back: Array[ItemStack] = []
	for st in r.escrow.slots:
		if st != null and st.def_id != Inventory.LOCK:
			back.append(st)
	if back.is_empty():
		return ""
	if p == null or not BuildPlacer.fits_in_bag(p.inventory, back):
		if p and not quiet:
			p.notice("Bag is full: make room to take back %s's materials." % r.name)
		return "Bag is full"
	for st in back:
		p.inventory.add(st.duplicate_stack())
	r.escrow.load_array([])
	print("[tribe] %s handed back %d stacks" % [r.name, back.size()])
	return ""

# ---------------------------------------------------------------- display and save

## The job line on the member's plate and in the Tribe screen.
static func plate_text(r: TribeRecord) -> String:
	match job_kind(r):
		&"craft":
			var rec := Crafting.recipe(StringName(str(r.job.get("recipe", ""))))
			var nm := str(rec.get("display_name", r.job.get("recipe", "")))
			if bool(r.job.get("waiting", false)):
				return "%s ready · no room" % nm
			return "Crafting %s %d%%" % [nm, roundi(progress(r) * 100.0)]
		&"build":
			var s := find_site(str(r.job.get("site", "")))
			return "Building %s %d%%" % [str(s.bp().get("display_name", "site")) if s else "site", roundi(progress(r) * 100.0)]
	return ""

## A picker row's text: "Joss · Processing 3 · 100% · 1.9s".
static func offer_text(r: TribeRecord, o: Dictionary) -> String:
	var t := "%s · %s %d · %d%% · %.0fs" % [r.name, nice_skill(str(o["skill"])), int(o["level"]), roundi(float(o["success"]) * 100.0), ceilf(float(o["seconds"]))]
	if o.has("result_level") and int(o["result_level"]) > 0:
		t += " · %s" % LevelDisplay.label(int(o["result_level"]))
	return t

## A saved station job, shaped (TribeRecord.from_dict hands it here). {} drops it; the escrow stays
## on the record and the director hands it back.
static func clean_job(j: Dictionary) -> Dictionary:
	var kind := str(j.get("kind", ""))
	var c: Variant = j.get("center", [])
	if not TribeRecord._xz(c):
		return {}
	var out := {"kind": kind, "center": [float(c[0]), float(c[1])], "radius": 3.0, "chest": []}
	if kind == "build":
		var sid := str(j.get("site", ""))
		if sid == "" or sid.length() > 64:
			return {}
		out["site"] = sid
		return out
	var rid := str(j.get("recipe", ""))
	if Crafting.recipe(StringName(rid)).is_empty() or not TribeRecord._xz(j.get("station", [])):
		return {}
	var oc: Variant = j.get("outcome", {})
	var ocd: Dictionary = oc if oc is Dictionary else {}
	var picks: Array = []
	var pv: Variant = j.get("picks", [])
	if pv is Array:
		for v: Variant in pv:
			picks.append(clampi(int(TribeRecord._n(v, -1.0)), -1, TribeRecord.ESCROW_SLOTS - 1))
	out.merge({"station": [float(j["station"][0]), float(j["station"][1])], "station_id": str(j.get("station_id", "")).left(32),
		"recipe": rid, "picks": picks, "level": clampi(int(TribeRecord._n(j.get("level"), 1.0)), 1, 60), "burnt": j.get("burnt") == true,
		"outcome": {"success": ocd.get("success", true) != false, "flawless": ocd.get("flawless") == true, "rare": str(ocd.get("rare", "")).left(32)},
		"seconds": clampf(TribeRecord._n(j.get("seconds"), 3.0), 0.1, 86400.0), "progress": maxf(0.0, TribeRecord._n(j.get("progress"), 0.0)),
		"made": j.get("made") == true})
	return out
