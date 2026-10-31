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
	await World._fade_to(func () -> void: ok[0] = World.complete_pick(host, shape_id), World.sail_title(&"home_grassland", shape_id))
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
## landing: the camp's own fire, workbench and shed, plus the Faction Hall's desk (the quest hub that
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
	_faction_plaza(rt)  # FACTIONS: the Faction Hall's desk (role guild) and the faction boards
	# FACTIONS: the market, sign and crates stand dock-relative on the square's flanks, clear of the
	# faction boards' arc in front of the hall (they were fixed world offsets before).
	var flank := func (deg: float, r: float) -> Vector2i: return BuildGrid.tile_of(plaza_polar(rt, deg, r))
	rt._camp_place(TownBuilding.make(&"fishing_stand", &"market", "Market stall"), "TownMarket", &"fishing_stand", flank.call(80.0, 12.0))
	rt._camp_place(TownBuilding.make(&"signpost", &"decor", "Tutorial Island town"), "TownSign", &"signpost", flank.call(14.0, 9.0))
	rt._camp_place(TownBuilding.make(&"barrel", &"decor", ""), "TownBarrel", &"barrel", flank.call(95.0, 13.0))
	rt._camp_place(TownBuilding.make(&"large_box", &"decor", ""), "TownCrates", &"large_box", flank.call(-80.0, 12.0))
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
		var t: Vector3 = plaza_polar(rt, [55.0, -55.0][i], 19.0)  # FACTIONS: dock-relative, clear of the faction boards' arc
		t.y = rt.surface_y(t.x, t.z)
		rt.harvest_count += rt._plant_at("CommonTree", "tutorial_tree_%d" % i, t, &"wood_log", &"axe", rt._climate, lv, Color(0.35, 0.22, 0.1))
	TownDress.build(rt)  # TUTTOWN: the rest of the town, its districts, streets and townsfolk
	_wild_zones(rt)

## FACTIONS (docs/design/factions.md §6): the town follows the player's building rules (owner
## 2026-10-30): every piece on the 1 m BuildGrid, in the placer's default orientation, front facing
## south (+Z, toward the dock on this island and the bottom of the north-up screen). The Faction Hall
## stands north-east of the square (TownDress builds it behind its desk, TownGuild, role guild: the
## tutorial's first order and the map still find it by that role), east of the road north out of town
## so that road stays open. Five faction boards stand in a row in front of it (FACTION_ORDER, the banner
## order); two general boards spread the crowd: one on the square's dock side, one by the dock arrival.
## A spot that is taken moves outward. # ASSUMPTION: every offset (FA11).
const HALL_DESK := Vector3(19.0, 0.0, -15.0)  ## from the camp, metres: the desk in front of the hall door
const BOARD_ROW_Z := -8.0
const BOARD_X := [-12.0, -6.0, 0.0, 6.0, 12.0]  ## along the row, from the desk's x
const FACTION_ORDER := ["company", "chlorophyll_forum", "radio_university", "pioneer_council", "committee"]

static func plaza_polar(rt: IslandRuntime, deg: float, r: float) -> Vector3:
	var camp := rt._camp_pos
	var h := rt.arrival_point() - camp
	var a := atan2(h.z, h.x) + deg_to_rad(deg)
	return camp + Vector3(cos(a), 0.0, sin(a)) * r

## The free cell nearest `want` for a 1x1 piece, stepping out from the camp (Vector2i(-99999) = none).
static func _free_cell(rt: IslandRuntime, want: Vector3) -> Vector2i:
	var out := (want - rt._camp_pos)
	out.y = 0.0
	out = out.normalized()
	for k in 8:
		var q := want + out * float(k)
		var c := BuildGrid.tile_of(q)
		var free := rt.is_dry(q)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var n := c + Vector2i(dx, dz)
				free = free and not rt.build_grid._occupied.has(n) and not rt.build_grid._reserved.has(n)
		if free:
			return c
	return Vector2i(-99999, -99999)

static func _faction_plaza(rt: IslandRuntime) -> void:
	var desk := BuildGrid.tile_of(rt._camp_pos + HALL_DESK)
	var spot := _free_cell(rt, rt._camp_pos + HALL_DESK)
	rt._camp_place(TownBuilding.make(&"log_shelter", &"guild", "Faction Hall"), "TownGuild", &"log_shelter", spot if spot.x > -99999 else desk)
	var boards: Array = []
	for i in FACTION_ORDER.size():
		boards.append([FACTION_ORDER[i], rt._camp_pos + Vector3(HALL_DESK.x + float(BOARD_X[i]), 0.0, BOARD_ROW_Z)])
	boards.append(["", plaza_polar(rt, 24.0, 17.0)])  # the square's dock side
	var dock := rt.arrival_point()
	boards.append(["", dock + (rt._camp_pos - dock).normalized() * 9.0])  # by the arrival
	for i in boards.size():
		var fid: String = boards[i][0]
		var cell := _free_cell(rt, boards[i][1])
		if cell.x == -99999:
			continue
		var nm := str(Factions.def(fid).get("name", "")) + " board" if fid != "" else "Faction mission board"
		var b := TownBuilding.make(&"sign", &"faction_board", nm)
		b.faction = fid
		rt._camp_place(b, "FactionBoard_%s" % (fid if fid != "" else str(i)), &"sign", cell)

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
	var step := steps()[World.objective] as Dictionary
	if step.has("menu"):
		return guide(p, step)
	return resolve(p, str(step.get("point_at", "")))

# ---------------------------------------------------------------- menu guidance

## MENU GUIDANCE (owner 2026-10-29: "it points to a menu and doesn't tell you where to scroll"). An
## order that is done inside a menu lists the taps in order under "menu": every alternative is a path
## such as ["MenuHex", "Nav_craft", "Cat_processing", "Recipe_twine", "CraftOne"], optionally led by
## "have:<item>" (that path only while the bag holds it). One shared rule for every order: the pointer
## rings the DEEPEST element of the path that is on screen now, so it walks MENU -> the Craft entry ->
## the tab -> the recipe -> Craft as the player taps. A tab, recipe, skill or bag slot is a gate
## (meta tut_chosen): while it shows and is not the chosen one, nothing past it counts (All open shows
## the twine row, but the pointer still asks for the Materials tab first). A target inside a
## ScrollContainer is scrolled into view once (ensure_control_visible); if it is still outside (the
## player scrolled away), the result carries a scroll cue instead of the ring.
## Elements: a node name under the HUD and the open screens; world:/harvest:/ctx: as point_at;
## "bag:<item>" (the bag cell holding it); "skill:buyable" (the first skill with a node to learn).
## Result: {} or {"ui": Control | "world": Vector3, "index": i, "path": Array, "caption": String,
## "scroll": ScrollContainer, "cue": -1 up / 0 none / 1 down, "covered_ok": bool}.
static var _scrolled_for := ""

static func guide(p: Player, step: Dictionary) -> Dictionary:
	var path := guide_path(p, step)
	if path.is_empty():
		return {}
	var roots := _ui_roots(p)
	var found: Array = []
	for el in path:
		found.append(_find_el(p, roots, str(el)))
	var pick := -1
	for i in range(path.size() - 1, -1, -1):
		var hit: Dictionary = found[i]
		if hit.is_empty() or (hit.has("ui") and not _shown(hit["ui"] as Control)):
			continue
		var gated := false
		for j in range(1, i):  # path[0] is the way in (MENU, the station): never a gate
			if _blocks(found[j]):
				gated = true
				break
		if not gated:
			pick = i
			break
	if pick < 0:
		return {}
	var out: Dictionary = (found[pick] as Dictionary).duplicate()
	out["index"] = pick
	out["path"] = path
	out["cue"] = 0
	if out.has("ui"):
		var c := out["ui"] as Control
		out["caption"] = "Tap " + caption_of(c)
		var sc := _scroll_of(c)
		if sc:
			out["scroll"] = sc
			# Scroll it in until it has been seen in view once; after that the player may scroll away
			# (then the cue shows). The list lays out a frame after a rebuild, so this repeats till then.
			var key := "%d:%s" % [World.objective, str(path[pick])]
			var view := sc.get_global_rect()
			var r := c.get_global_rect()
			if view.grow(1.0).encloses(r):
				_scrolled_for = key
			elif _scrolled_for != key:
				sc.ensure_control_visible(c)
			if r.end.y > view.end.y + 1.0:
				out["cue"] = 1
			elif r.position.y < view.position.y - 1.0:
				out["cue"] = -1
	return out

## The step's path: the first "menu" alternative whose have: condition holds.
static func guide_path(p: Player, step: Dictionary) -> Array:
	for alt in step.get("menu", []):
		if not alt is Array or (alt as Array).is_empty():
			continue
		var a := alt as Array
		var head := str(a[0])
		if head.begins_with("have:"):
			if p.inventory.count_of(StringName(head.substr(5))) <= 0:
				continue
			return a.slice(1)
		return a
	return []

## Where menu elements live: the HUD (MENU, NavMenu, skills), the craft sheet, the bag, the station
## ring and the build drawer.
static func _ui_roots(p: Player) -> Array[Node]:
	var out: Array[Node] = []
	var hud := p.get_tree().get_first_node_in_group("hud")
	for n: Variant in [hud, p.craft_ui, p.ui, p.station_craft.menu if p.station_craft else null, p.get("build_ui")]:
		if n != null and is_instance_valid(n):
			out.append(n as Node)
	return out

static func _find_el(p: Player, roots: Array[Node], el: String) -> Dictionary:
	if el.begins_with("world:") or el.begins_with("harvest:") or el.begins_with("ctx:"):
		return _resolve_one(p, el)
	if el.begins_with("bag:"):
		return _bag_cell(p, StringName(el.substr(4)))
	if el == "skill:buyable":
		for r in roots:
			for c in r.find_children("Skill_*", "Button", true, false):
				if (c as Node).find_child("Unread", true, false) != null:
					return {"ui": c}
		return {}
	for r in roots:
		var c := r.find_child(el, true, false) as Control
		if c:
			return {"ui": c}
	return {}

## The bag cell that draws `item` (the bag sorts and filters, so cells are found by what they hold).
static func _bag_cell(p: Player, item: StringName) -> Dictionary:
	if p.ui == null or not is_instance_valid(p.ui):
		return {}
	for c in (p.ui as Node).find_children("Slot*", "", true, false):
		var st: Variant = c.get("stack")
		if st is ItemStack and (st as ItemStack).def_id == item:
			c.set_meta(&"tut_chosen", bool(c.get("selected")))
			c.set_meta(&"tut_hard", true)  # Use acts on the selected cell, shown or not
			return {"ui": c}
	return {}

static func _shown(c: Control) -> bool:
	return c != null and is_instance_valid(c) and c.is_visible_in_tree() and c.size.x > 1.0

## A gate that is not chosen blocks the rest of the path: tabs only while they show, recipes and bag
## cells (tut_hard) always.
static func _blocks(hit: Dictionary) -> bool:
	if not hit.has("ui"):
		return false
	var c := hit["ui"] as Control
	if c == null or not c.has_meta(&"tut_chosen") or bool(c.get_meta(&"tut_chosen")):
		return false
	return c.has_meta(&"tut_hard") or _shown(c)

static func _scroll_of(c: Control) -> ScrollContainer:
	var n := c.get_parent()
	while n != null and n is Control:
		if n is ScrollContainer:
			return n as ScrollContainer
		n = n.get_parent()
	return null

## What the tapped thing says: its title, button text, hex caption or recipe name.
static func caption_of(c: Control) -> String:
	for k in ["title", "caption", "bottom_text"]:
		var v: Variant = c.get(k)
		if v is String and str(v).strip_edges() != "":
			return str(v).strip_edges()
	var rn := c.find_child("RecipeName", true, false) as Label
	if rn:
		return rn.text
	if c is Button and (c as Button).text.strip_edges() != "":
		return (c as Button).text.strip_edges()
	var st: Variant = c.get("stack")
	if st is ItemStack:
		var d := (st as ItemStack).def()
		return d.display_name if d else str((st as ItemStack).def_id)
	return "here"

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
		return {"world": best.global_position, "node": best} if best else {}
	if s.begins_with("world:"):
		_nearest_node = null
		var at: Variant = world_point(p, s.substr(6))
		if not at is Vector3:
			return {}
		return {"world": at, "node": _nearest_node} if _nearest_node != null else {"world": at}
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
			return _nearest(p, "creatures", func (n: Node) -> bool: return _huntable(n, &""))
		"corpse":
			# An early kill (on the way to the water, say) completes the hunt order before it comes up, and
			# that carcass may be gone by the butcher order: point at a compsognathus to hunt instead.
			var body: Variant = _nearest(p, "corpse", func (_n: Node) -> bool: return true)
			return body if body != null else world_point(p, "creature:compsognathus")
		"water":
			return nearest_fresh_water(p.global_position)
	# "creature:<species>": a species order points only at that species (owner 2026-10-29: the hunt
	# order pointed at a protoceratops); none awake -> the nearest wild zone of that species.
	if what.begins_with("creature:"):
		var sp := StringName(what.substr(9))
		var live: Variant = _nearest(p, "creatures", func (n: Node) -> bool: return _huntable(n, sp))
		if live != null:
			return live
		var best: Variant = null
		var best_d := INF
		for z in rt.find_children("WildZone_*", "", false, false):
			if z.get("species") == sp and p.global_position.distance_squared_to((z as Node3D).global_position) < best_d:
				best_d = p.global_position.distance_squared_to((z as Node3D).global_position)
				best = (z as Node3D).global_position
		return best
	return null

## A living wild animal (of `species`, when given) the survivor can hunt.
static func _huntable(n: Node, species: StringName) -> bool:
	if not n is Creature:
		return false
	var c := n as Creature
	if c.is_pet or c.health == null or c.health.dead:
		return false
	return species == &"" or (c.def != null and c.def.id == species)

## The node the last _nearest() picked (the pointer follows it every frame).
static var _nearest_node: Node3D = null

static func _nearest(p: Player, group: String, ok: Callable) -> Variant:
	var best: Variant = null
	var best_n: Node3D = null
	var best_d := INF
	for n in p.get_tree().get_nodes_in_group(group):
		if not n is Node3D or (n as Node).is_queued_for_deletion() or not ok.call(n):
			continue
		var d := p.global_position.distance_squared_to((n as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = (n as Node3D).global_position
			best_n = n as Node3D
	_nearest_node = best_n
	return best

static var _water_cache: Dictionary = {}
const WATER_SEARCH_M := 260

## The nearest dry bank beside fresh water (where Drink is offered) within WATER_SEARCH_M, on 3 m
## rings out to 60 m and 4 m rings past that; cached per 12 m cell (water does not move).
## # ASSUMPTION (TUTTOWN 2026-10-29): 260 m; the town by the southern dock is ~205 m from the river.
static func nearest_fresh_water(from: Vector3) -> Variant:
	var key := "%s:%d:%d" % [World.island_id, roundi(from.x / 12.0), roundi(from.z / 12.0)]
	if _water_cache.has(key):
		return _water_cache[key]
	var found: Variant = null
	var radii: Array = range(3, 61, 3) + range(64, WATER_SEARCH_M + 1, 4)
	for r: int in radii:
		var steps_n := maxi(8, int(TAU * float(r) / (3.0 if r <= 60 else 4.0)))
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
