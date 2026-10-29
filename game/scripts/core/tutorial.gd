class_name Tutorial
extends RefCounted
## TUTORIAL ISLAND (owner 2026-10-28): a NEW survivor lands on the shared tutorial island after
## character creation (not on a personal island), follows the tutorial orders (objectives.json
## "tutorial", one system per step, run by the existing Orders system: Objectives, the HUD orders
## card/badge, the Orders sheet), and the last order grants a Tamed Island: the ISLANDPICK screen
## opens, the survivor sails there with everything carried, and the standing orders continue.
##
## State is World.tutorial, saved as the save's "tutorial" row: {"done": bool, "did": {key: count}}.
## A save without the row is an existing survivor with a home: done (they never see the tutorial).
## While it runs, World.objective indexes the tutorial list.
##
## Dev: --skip-tutorial (new game goes straight to the pick, as before; a mid-tutorial save jumps to
## the grant), --tutorial-step=<n> (a new game starts at tutorial step n, 1-based).

const ISLAND := &"tutorial_isle"
const MAX_DID := 1000000

static var _offering := false
## Tests stand in for the command line here (--skip-tutorial, --tutorial-step=n); empty = the real one.
static var dev_args: PackedStringArray = []

static func _args() -> PackedStringArray:
	return dev_args if not dev_args.is_empty() else OS.get_cmdline_user_args()

static func active() -> bool:
	return not bool(World.tutorial.get("done", true))

static func steps() -> Array:
	return Data.world_tutorial

static func fresh() -> Dictionary:
	return {"done": false, "did": {}}

static func skip_requested() -> bool:
	return "--skip-tutorial" in _args()

## --tutorial-step=<n>: 1-based, clamped to the list (n past the end lands on the grant).
static func start_step() -> int:
	for a in _args():
		if a.begins_with("--tutorial-step="):
			return clampi(int(a.substr(16)) - 1, 0, steps().size())
	return 0

## The save row is user-editable JSON: only a bool and bounded integer counts under short keys pass.
## No row (every save written before this feature, all of which own a home) means done.
static func from_save(v: Variant) -> Dictionary:
	if not v is Dictionary:
		return {"done": true, "did": {}}
	var row := v as Dictionary
	var done_v: Variant = row.get("done", true)
	var did := {}
	var raw: Variant = row.get("did", {})
	if raw is Dictionary:
		for k in (raw as Dictionary).keys():
			var n: Variant = (raw as Dictionary)[k]
			if str(k).length() <= 64 and (n is int or n is float) and is_finite(float(n)):
				did[str(k)] = clampi(int(n), 0, MAX_DID)
	return {"done": done_v if done_v is bool else true, "did": did}

## Something a tutorial order counts happened (eat, eat:<item>, kill, build, skill). Only while the
## tutorial runs, so a home survivor's save keeps exactly its old shape.
static func note(what: String) -> void:
	if not active():
		return
	var did: Dictionary = World.tutorial.get("did", {})
	did[what] = mini(int(did.get(what, 0)) + 1, MAX_DID)
	World.tutorial["did"] = did

static func did(what: String) -> int:
	return int((World.tutorial.get("did", {}) as Dictionary).get(what, 0))

# ---------------------------------------------------------------- flow

## Character creation just finished: land on the tutorial island at its dock (the survivor arrives
## by boat; # ASSUMPTION: the dock, not the camp) and start saving. Replaces the old jump straight to the island pick.
static func begin(host: Node) -> void:
	World.tutorial = fresh()
	World.objective = start_step()
	World.objective_best = 0
	var def := World.def_of(ISLAND)
	var h: Array = def.get("harbour", [0, 0, 12])
	World.load_island(host, ISLAND, Vector3(float(h[0]), 1.0, float(h[2])), false)
	var p := World._player()
	if p and World.runtime and World.runtime.has_method("arrival_point"):
		p.global_position = (World.runtime as IslandRuntime).arrival_point() + Vector3.UP
	World.finish_creation()
	World._save_now()
	print("[tutorial] begin island=%s step=%d/%d at=%s" % [ISLAND, World.objective + 1, steps().size(), str(p.global_position.snapped(Vector3.ONE) if p else Vector3.ZERO)])
	resume(host)

## After a load (or begin): a tutorial whose orders are all done is waiting for its grant, and
## --skip-tutorial jumps a running tutorial to it.
static func resume(host: Node) -> void:
	if not active():
		return
	if skip_requested():
		World.objective = steps().size()
	if World.objective >= steps().size():
		grant_home(host)

## The last order is done: open the Tamed Island pick (ISLANDPICK's screen, moved here from the end of
## character creation; # ASSUMPTION: no doc places the pick). The pick's SELECT AND MOVE ferries the survivor home.
static func grant_home(host: Node) -> void:
	if _offering or not active():
		return
	_offering = true
	World.objective = steps().size()
	World.objective_best = 0
	var ip = (load("res://scripts/ui/island_pick.gd") as GDScript).instance_on(host)
	ip.picked.connect(func (shape_id: StringName) -> void:
		var ok: bool = await ferry(host, shape_id)
		if not ok:
			print("[tutorial] tamed island pick refused: shape=%s" % shape_id)
			ip.failed()
			return
		ip.close()
	)
	ip.open()
	print("[tutorial] all orders done: the Tamed Island pick is open")

## Sail from the tutorial island to the picked Tamed Island. Everything the survivor carries comes
## along (bag, worn gear, skills, levels, T-stones, bonded animals): # ASSUMPTION, the docs say
## nothing about a tutorial carry-over, so nothing is taken. What was built on the tutorial island
## stays there (it is shared, and not a home). False when World refuses the pick.
static func ferry(host: Node, shape_id: StringName) -> bool:
	if not World.has_shape(shape_id) or World.home_shape != &"":
		return false
	var keep_objective := World.objective
	World.tutorial["done"] = true
	World.objective = resume_index()
	World.objective_best = 0
	# The tutorial island's land and node state are not the home's.
	World.harvested = {}
	World.away_domain = {}
	World.unstable_claims = []
	World.free_claim_used = false
	var ok := [false]
	await World._fade_to(func () -> void: ok[0] = World.complete_pick(host, shape_id))
	if not ok[0]:
		World.tutorial["done"] = false
		World.objective = keep_objective
		return false
	_offering = false
	print("[tutorial] done: ferried to the Tamed Island %s; standing orders resume at %d (%s)" % [shape_id, World.objective, Data.tutorial_resume_at])
	return true

## The standing order the main list resumes at once the tutorial has taught its first steps.
static func resume_index() -> int:
	var i := 0
	for step in Data.world_objectives:
		if str((step as Dictionary).get("id", "")) == Data.tutorial_resume_at:
			return i
		i += 1
	return 0

# ---------------------------------------------------------------- island

## The prebuilt town on top of the generated island (owner 2026-10-28), around the camp at the
## landing: the camp's own fire, workbench and shed, plus the Adventurer's Guild (the quest hub that
## hands out these orders), a market stall (Island Market screen), a permanent stone fire pit (the
## "light the fire" and cooking orders), a drying rack, a sign and crates. Every piece is
## indestructible and never saved (persist_building = false; see TownBuilding). Herbs, berries and
## two trees at the town's edge make every order completable on this island's own content, and the
## wild lands outside are ZoneSpawners (island data wild_zones). # ASSUMPTION: layout and models.
static func dress(rt: IslandRuntime) -> void:
	var camp := rt._camp_pos
	var at := func (dx: float, dz: float) -> Vector2i: return BuildGrid.tile_of(camp + Vector3(dx, 0.0, dz))
	var pit := Bonfire.make(&"stone_fire_pit")
	pit.persist_building = false
	rt._camp_place(pit, "TutorialFirePit", &"stone_fire_pit", at.call(-2.0, 4.5))
	rt._camp_place(TownBuilding.make(&"log_shelter", &"guild", "Adventurer's Guild"), "TownGuild", &"log_shelter", at.call(-11.0, -9.0))
	rt._camp_place(TownBuilding.make(&"fishing_stand", &"market", "Market stall"), "TownMarket", &"fishing_stand", at.call(10.0, -9.0))
	rt._camp_place(TownBuilding.make(&"signpost", &"decor", "Tutorial Island town"), "TownSign", &"signpost", at.call(-5.0, -6.0))
	rt._camp_place(TownBuilding.make(&"barrel", &"decor", ""), "TownBarrel", &"barrel", at.call(13.0, -6.0))
	rt._camp_place(TownBuilding.make(&"large_box", &"decor", ""), "TownCrates", &"large_box", at.call(-14.0, -5.0))
	var rack := CraftStation.make(&"drying_rack")
	rack.persist_building = false
	rt._camp_place(rack, "TownDryingRack", &"drying_rack", at.call(8.0, 5.0))
	var lv := 1
	var spots := [Vector3(15, 0, 6), Vector3(16, 0, 10), Vector3(14, 0, 13), Vector3(-15, 0, 6), Vector3(-16, 0, 10), Vector3(-14, 0, 13)]
	for i in spots.size():
		var p: Vector3 = camp + spots[i]
		p.y = rt.surface_y(p.x, p.z)
		var herb := i < 3
		rt.harvest_count += rt._plant_at("HerbPlant" if herb else "BerrySprig", "tutorial_%s_%d" % ["herb" if herb else "berry", i], p,
			&"herb_leaf" if herb else &"berries", &"none", rt._climate, lv, Color(0.3, 0.55, 0.25) if herb else Color(0.55, 0.15, 0.3))
	for i in 2:
		var t: Vector3 = camp + [Vector3(-19, 0, 2), Vector3(19, 0, 1)][i]
		t.y = rt.surface_y(t.x, t.z)
		rt.harvest_count += rt._plant_at("CommonTree", "tutorial_tree_%d" % i, t, &"wood_log", &"axe", rt._climate, lv, Color(0.35, 0.22, 0.1))
	_wild_zones(rt)

static func _wild_zones(rt: IslandRuntime) -> void:
	var camp := rt._camp_pos
	var rows: Variant = World.def_of(ISLAND).get("wild_zones", [])
	if not rows is Array:
		return
	# ASSUMPTION: the town and its surroundings are free of wild zones (island data town_safe_m).
	var safe := float(World.def_of(ISLAND).get("town_safe_m", 0.0))
	var n := 0
	for row in rows:
		if not row is Dictionary:
			continue
		var r := row as Dictionary
		var ang := deg_to_rad(float(r.get("angle", 0.0)))
		var want := camp + Vector3(cos(ang), 0.0, sin(ang)) * maxf(safe, float(r.get("dist", 60.0)))
		var spot := _dry_near(rt, want, safe)
		if spot == Vector3.INF:
			print("[tutorial] wild zone %s: no dry land near %s" % [r.get("species", "?"), want.snapped(Vector3.ONE)])
			continue
		var z := ZoneSpawner.new()
		z.name = "WildZone_%d_%s" % [n, str(r.get("species", ""))]
		z.species = StringName(str(r.get("species", "compsognathus")))
		z.count = int(r.get("count", 1))
		z.as_pack = bool(r.get("pack", false))
		z.position = spot
		rt.add_child(z)
		n += 1

## The nearest dry spawnable ground to `want`, searched on rings out to 40 m, toward the town first.
## Never closer than `min_town_m` to the town (town_safe_m).
static func _dry_near(rt: IslandRuntime, want: Vector3, min_town_m: float = 0.0) -> Vector3:
	var camp := rt._camp_pos
	for r in range(0, 41, 4):
		for k in 12:
			var a := TAU * float(k) / 12.0
			var q := want + Vector3(cos(a), 0.0, sin(a)) * float(r)
			q.y = rt.surface_y(q.x, q.z) + 0.3
			if rt.spawn_ok(q, false) and rt.is_dry(q) and Vector2(q.x - camp.x, q.z - camp.z).length() >= min_town_m:
				return q
			if r == 0:
				break
	return Vector3.INF

## Is the camp's stone fire pit burning? A fire with no fuel model (before FIREPITS) always burns.
static func fire_lit() -> bool:
	if World.runtime == null:
		return false
	for n in World.runtime.get_tree().get_nodes_in_group("bonfire"):
		if not World.runtime.is_ancestor_of(n) or n.get("kind") != &"stone_fire_pit":
			continue
		if not n.has_method("burning") or bool(n.call("burning")):
			return true
	return false

static func near(p: Player, what: String, radius: float) -> bool:
	var at: Variant = world_point(p, what)
	if not at is Vector3:
		return false
	var d := (at as Vector3) - p.global_position
	d.y = 0.0
	return d.length() <= radius

# ---------------------------------------------------------------- the onboarding pointer

## The pointer's target for the current tutorial step: {"ui": Control} or {"world": Vector3}, or {}
## when nothing resolves (or no tutorial runs). TutorialPointer draws it; t_tutorial checks it.
static func pointer_target(p: Player) -> Dictionary:
	if not active() or p == null or World.objective < 0 or World.objective >= steps().size():
		return {}
	return resolve(p, str((steps()[World.objective] as Dictionary).get("point_at", "")))

static func resolve(p: Player, spec: String) -> Dictionary:
	for alt in spec.split("|", false):
		var s := str(alt)
		if s.begins_with("have:"):
			var parts := s.substr(5).split("=", false, 1)
			if parts.size() < 2 or p.inventory.count_of(StringName(parts[0])) <= 0:
				continue
			s = parts[1]
		var hit := _resolve_one(p, s)
		if not hit.is_empty():
			return hit
	return {}

static func _resolve_one(p: Player, s: String) -> Dictionary:
	var hud := p.get_tree().get_first_node_in_group("hud")
	if s.begins_with("ui:"):
		var c := hud.find_child(s.substr(3), true, false) as Control if hud else null
		return {"ui": c} if c and c.is_visible_in_tree() else {}
	if s.begins_with("ctx:"):
		var id := s.substr(4)
		if hud == null:
			return {}
		var c := hud.find_child("Ctx_" + id, true, false) as Control
		if c and c.is_visible_in_tree():
			return {"ui": c}
		var field: Variant = hud.get("field")
		if field != null and str(field.get("choice_id")) == id and field.get("interact_hex") is Control:
			return {"ui": field.get("interact_hex")}
		return {}
	if s.begins_with("harvest:"):
		var item := s.substr(8)
		var best: Node3D = null
		var best_d := INF
		for n in p.get_tree().get_nodes_in_group("harvest"):
			var hn := n as HarvestNode
			if hn == null or hn.depleted:
				continue
			for o in hn.options():
				if str((o as Dictionary).get("item", "")) == item:
					var d := p.global_position.distance_squared_to(hn.global_position)
					if d < best_d:
						best_d = d
						best = hn
					break
		return {"world": best.global_position} if best else {}
	if s.begins_with("world:"):
		var at: Variant = world_point(p, s.substr(6))
		return {"world": at} if at is Vector3 else {}
	return {}

## Named places on the tutorial island (and the nearest live thing for creature / corpse / water).
static func world_point(p: Player, what: String) -> Variant:
	var rt := World.runtime as IslandRuntime
	if rt == null:
		return null
	match what:
		"camp":
			return rt._camp_pos
		"guild":
			return _nearest(p, "town_building", func (n: Node) -> bool: return n.get("role") == &"guild")
		"harbour":
			return rt.arrival_point()
		"bench":
			return _nearest(p, "craft_station", func (n: Node) -> bool: return n.get("station_id") == &"workbench")
		"firepit":
			var pit: Variant = _nearest(p, "bonfire", func (n: Node) -> bool: return n.get("kind") == &"stone_fire_pit")
			return pit if pit != null else _nearest(p, "bonfire", func (_n: Node) -> bool: return true)
		"creature":
			return _nearest(p, "creatures", func (n: Node) -> bool: return n is Creature and not (n as Creature).is_pet and (n as Creature).health != null and not (n as Creature).health.dead)
		"corpse":
			return _nearest(p, "corpse", func (_n: Node) -> bool: return true)
		"water":
			return nearest_fresh_water(p.global_position)
	return null

static func _nearest(p: Player, group: String, ok: Callable) -> Variant:
	var best: Variant = null
	var best_d := INF
	for n in p.get_tree().get_nodes_in_group(group):
		if not n is Node3D or (n as Node).is_queued_for_deletion() or not ok.call(n):
			continue
		var d := p.global_position.distance_squared_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = (n as Node3D).global_position
	return best

static var _water_cache: Dictionary = {}

## The nearest dry bank beside fresh water (where Drink is offered) within 160 m, on a 3 m ring
## search; cached per 12 m cell (water does not move).
static func nearest_fresh_water(from: Vector3) -> Variant:
	var key := "%s:%d:%d" % [World.island_id, roundi(from.x / 12.0), roundi(from.z / 12.0)]
	if _water_cache.has(key):
		return _water_cache[key]
	var found: Variant = null
	for r in range(3, 161, 3):
		var steps_n := maxi(8, int(TAU * float(r) / 3.0))
		for k in steps_n:
			var a := TAU * float(k) / float(steps_n)
			var q := from + Vector3(cos(a) * float(r), 0.0, sin(a) * float(r))
			if not WaterAccess.in_water(q) and WaterAccess.near_fresh(q):
				found = q
				break
		if found != null:
			break
	_water_cache[key] = found
	return found
