extends SceneTree
## TUTORIAL ISLAND acceptance (owner 2026-10-28): a new character spawns on the shared tutorial island,
## not a home; a scripted bot (scripts/dev/tutorial_bot.gd) completes every tutorial order in order with
## the real actions; the state saves and resumes mid-way; the last order opens the Tamed Island pick and
## ferries the survivor home with what they carry; an old save with a home skips the tutorial;
## --skip-tutorial and --tutorial-step work.
## Run: Godot --headless --path game --script res://tests/t_tutorial.gd -> "[t_tutorial] PASS".

const FIX := "res://tests/fixtures/"

var _fails: PackedStringArray = []
var _started := false
var _host: Node3D
var W: Node
var SG: GDScript
var TUT: GDScript
var _player: Node

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_tutorial] FAIL %s" % what)
	else:
		print("[t_tutorial] ok %s" % what)

func _run() -> void:
	SG = load("res://scripts/core/save_game.gd")
	TUT = load("res://scripts/core/tutorial.gd")
	var watchdog := create_timer(1500.0)
	watchdog.timeout.connect(func () -> void:
		print("[t_tutorial] FAIL watchdog")
		quit(2))
	W = root.get_node("World")
	for n in get_nodes_in_group(&"character_creation"):
		n.free()
	_wipe()
	_host = Node3D.new()
	_host.name = "TTutorialHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	_test_data()
	await _test_new_character()
	await _test_streaming()
	await _test_bot_run()
	await _test_old_save()
	await _test_skip_and_step()
	_wipe()
	if _fails.is_empty():
		print("[t_tutorial] PASS")
		quit(0)
	else:
		print("[t_tutorial] FAILED %d: %s" % [_fails.size(), "; ".join(_fails)])
		quit(1)

func _test_data() -> void:
	var steps: Array = TUT.call("steps")
	_expect(steps.size() >= 12, "the tutorial has its orders (%d)" % steps.size())
	var ids := {}
	for s in steps:
		ids[str((s as Dictionary).get("id", ""))] = true
		_expect(str((s as Dictionary).get("point_at", "")) != "", "order %s names a pointer target" % (s as Dictionary).get("id"))
	_expect(ids.size() == steps.size(), "tutorial order ids are unique")
	_expect(bool((steps[-1] as Dictionary).get("grant_home", false)), "the last order grants the home island")
	_expect(int(TUT.call("resume_index")) > 0, "the standing orders resume at '%s' (index %d)" % [root.get_node("Data").tutorial_resume_at, TUT.call("resume_index")])
	_expect(not W.call("harbour_routes").has("tutorial_isle"), "the tutorial island is never a sail route")

## New character -> the tutorial island at its dock, no home, and a save that remembers it.
func _test_new_character() -> void:
	W.call("start_new", _host)
	var cc := _host.get_node_or_null("CharacterCreation")
	_expect(cc != null, "start_new opens character creation")
	if cc == null:
		return
	await process_frame
	cc.call("select_occupation", "farmer")
	cc.get("naming").get("field").text = "Tutee"
	var t0 := Time.get_ticks_msec()
	cc.call("_finish")
	var build_ms := Time.get_ticks_msec() - t0
	await create_timer(1.5).timeout  # the wild zones by the town wake on their first ticks
	_expect(W.get("island_id") == &"tutorial_isle", "a new character spawns on the tutorial island (got %s)" % W.get("island_id"))
	_expect(not W.call("is_home") and W.call("is_tutorial"), "the tutorial island is not a home")
	_expect(W.get("home_shape") == &"", "no Tamed Island is held yet")
	_expect(bool(TUT.call("active")) and int(W.get("objective")) == 0, "the tutorial runs from order 1")
	_expect(get_nodes_in_group(&"island_pick").is_empty(), "the island pick does not open at creation any more")
	_expect(not bool(W.get("creation_pending")), "saving is allowed on the tutorial island")
	var rt: Node3D = W.get("runtime")
	if rt:
		var arrival: Vector3 = rt.call("arrival_point")
		_expect(Vector2(_player.global_position.x - arrival.x, _player.global_position.z - arrival.z).length() < 3.0, "the survivor lands at the dock")
		var camp: Vector3 = rt.get("_camp_pos")
		var d := Vector2(camp.x - arrival.x, camp.z - arrival.z).length()
		_expect(d > 12.0 and d < 90.0, "the camp is a short walk from the dock (%.0f m)" % d)
		var pit := false
		for n in get_nodes_in_group("bonfire"):
			if n.get("kind") == &"stone_fire_pit":
				pit = true
		_expect(pit, "the tutorial camp has a stone fire pit")
		_expect(TUT.call("nearest_fresh_water", camp) != null, "fresh water within 260 m of the town")
		var herbs := 0
		for n in get_nodes_in_group("harvest"):
			for o in n.call("options"):
				if str((o as Dictionary).get("item", "")) == "herb_leaf" and (n as Node3D).global_position.distance_to(camp) < 20.0:
					herbs += 1
		_expect(herbs >= 1, "herbs grow by the camp (%d)" % herbs)
		var logs := 0
		for n in get_nodes_in_group("harvest"):
			for o in n.call("options"):
				if str((o as Dictionary).get("item", "")) == "wood_log" and (n as Node3D).global_position.distance_to(camp) < 25.0:
					logs += 1
		_expect(logs >= 1, "a tree for logs stands by the camp (%d)" % logs)
		# The town is safe (island town_safe_m): the compsognathus live in wild zones outside it.
		var safe := float((W.call("def_of", &"tutorial_isle") as Dictionary).get("town_safe_m", 0.0))
		var compy_zones := 0
		for z in rt.find_children("WildZone_*", "", false, false):
			var zd := Vector2((z as Node3D).global_position.x - camp.x, (z as Node3D).global_position.z - camp.z).length()
			_expect(zd >= safe, "%s sits outside the town's safe ring (%.0f >= %.0f m)" % [z.name, zd, safe])
			if str(z.get("species")) == "compsognathus":
				compy_zones += 1
		_expect(safe >= 60.0 and compy_zones >= 2, "weak animals to hunt in the wild lands (%d compsognathus zones, safe %.0f m)" % [compy_zones, safe])
		var alphas := 0
		for n in get_nodes_in_group("creatures"):
			if n.has_method("is_alpha") and n.call("is_alpha"):
				alphas += 1
		_expect(alphas == 0, "no alphas on the newcomer island (%d)" % alphas)
		_test_town(rt, camp)
		_test_town_dress(rt, camp)
		_test_size_and_perf(rt, build_ms)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.get("path")))
	_expect(str(saved.get("island_id", "")) == "tutorial_isle", "the first save is on the tutorial island")
	_expect(saved.get("tutorial") is Dictionary and saved["tutorial"].get("done") == false, "the save carries tutorial.done=false")

## The prebuilt town: the guild, the market stall, stations; nothing in it can be damaged, packed up
## or built over, and the island cannot be claimed.
func _test_town(rt: Node3D, camp: Vector3) -> void:
	var roles := {}
	for b in get_nodes_in_group("town_building"):
		roles[str(b.get("role"))] = true
		_expect(not load("res://scripts/world/structure_health.gd").call("is_structure", b), "%s is indestructible (not a damageable structure)" % b.name)
		_expect(str(load("res://scripts/world/build_placer.gd").call("pack_up_blocker", b)) != "", "%s cannot be packed up" % b.name)
		var cell: Vector2i = b.get("build_cell")
		_expect(str(rt.get("build_grid").call("can_place", &"straw_roll", cell, 0)) != "", "nothing can be built over %s" % b.name)
	_expect(roles.has("guild") and roles.has("market"), "the town has the Faction Hall desk and a market stall (%s)" % [roles.keys()])
	var bench := false
	for n in get_nodes_in_group("craft_station"):
		if n.get("station_id") == &"workbench" and (n as Node3D).global_position.distance_to(camp) < 25.0:
			bench = true
	_expect(bench, "the town has a workbench")
	for n in get_nodes_in_group("placed_building"):
		if (n as Node3D).global_position.distance_to(camp) < 25.0 and n.get("persist_building") != false:
			_expect(false, "town piece %s is saved/destructible" % n.name)
	var acts: Array = []
	for a in _player.call("context_actions"):
		acts.append(str(a["id"]))
	_expect(not acts.has("claim"), "no CLAIM on the tutorial island (%s)" % [acts])
	_expect(not bool(_player.actions.call("claim_confirmed")), "a claim on the tutorial island is refused")
	var guild: Variant = TUT.call("world_point", _player, "guild")
	_expect(guild is Vector3 and (guild as Vector3).distance_to(camp) < 25.0, "the guild stands in the town")

## TUTTOWN (owner 2026-10-29: "It should feel like a massive town"): districts full of houses, stalls,
## workshops, fields, pens, lamps and townsfolk; cheap (MultiMesh, few lights); every order target, the
## dock and every wild zone still reachable on the tile router through the streets.
func _test_town_dress(rt: Node3D, camp: Vector3) -> void:
	var town: Node = rt.get_node_or_null("TownDress")
	_expect(town != null, "the town is dressed (TownDress)")
	if town == null:
		return
	var st: Dictionary = town.get("stats")
	print("[t_tutorial] town %s" % st)
	_expect(int(st["houses"]) >= 40 and int(st["stalls"]) >= 6 and int(st["workshops"]) >= 4 and int(st["fields"]) >= 4 and int(st["pens"]) >= 2,
		"a big town: %d houses, %d stalls, %d workshops, %d fields, %d pens" % [st["houses"], st["stalls"], st["workshops"], st["fields"], st["pens"]])
	_expect(int(st["npcs"]) >= 8 and int(st["npcs"]) <= 24 and int(st["animals"]) >= 2 and int(st["lamps"]) >= 20, "townsfolk %d, pen animals %d, lamps %d" % [st["npcs"], st["animals"], st["lamps"]])
	# Pen animals carry their eye rims (hidden, energy 0 until a threat): only lights that are on count.
	var lights: Array = town.find_children("*", "Light3D", true, false).filter(func (l: Node) -> bool: return (l as Light3D).visible and (l as Light3D).light_energy > 0.0)
	_expect(lights.size() <= 4, "at most 4 real lights in town (%s)" % [lights.map(func (l: Node) -> String: return str(l.get_parent().name) + "/" + str(l.name))])
	# ISOCAM streaming: only chunks within TownDress.STREAM_R of the player are in the tree; the budget
	# counts the batches loaded around her (the town's total is st["mmi"]).
	var p: Node3D = get_first_node_in_group(&"player") as Node3D  # not PlayerRegistry: this script compiles before the autoloads
	if p:
		town.call("stream", p.global_position)
	var batches := func () -> Array: return town.find_children("Town_*", "MultiMeshInstance3D", false, false)
	var mmis: Array = batches.call()
	_expect(mmis.size() >= 20 and mmis.size() <= 220 and mmis.size() == int(town.call("loaded_batches")) and int(st["instances"]) > 800,
		"the town is batched: %d MultiMeshes loaded around the player (%d in all), %d instances" % [mmis.size(), st["mmi"], st["instances"]])
	if p:  # far from town nothing of it is loaded; walking back loads it again
		town.call("stream", p.global_position + Vector3(2000, 0, 0))
		var gone: int = (batches.call() as Array).size()
		town.call("stream", p.global_position)
		_expect(gone == 0 and (batches.call() as Array).size() == mmis.size(), "town chunks stream out far away (%d left) and back in" % gone)
	var far_ok := true
	for m in mmis:
		far_ok = far_ok and (m as GeometryInstance3D).visibility_range_end > 0.0
	_expect(far_ok, "every town batch has a visibility range")
	# The light-the-fire order never waits on the weather: the square's pit stands under a shelter.
	var pit_at: Variant = TUT.call("world_point", _player, "firepit")
	_expect(pit_at is Vector3 and load("res://scripts/world/fire_weather.gd").call("roof_over", rt.get_tree(), pit_at) != null,
		"the stone fire pit stands under a roof (rain cannot stop the fire order)")
	var guild: Variant = TUT.call("world_point", _player, "guild")
	var hall := false
	for k in town.get("cells"):
		if Vector2(float(k.x) - (guild as Vector3).x, float(k.y) - (guild as Vector3).z).length() < 16.0:
			hall = true
			break
	_expect(hall, "the guild hall stands by the guild")
	var pathing: Variant = rt.get("pathing")
	var targets := {"dock": rt.call("arrival_point"), "guild": guild, "bench": TUT.call("world_point", _player, "bench"), "firepit": TUT.call("world_point", _player, "firepit")}
	for z in rt.find_children("WildZone_*", "", false, false):
		targets[str(z.name)] = (z as Node3D).global_position
	targets["water"] = TUT.call("nearest_fresh_water", camp)
	for n in get_nodes_in_group("harvest"):
		if (n as Node3D).global_position.distance_to(camp) < 25.0:
			targets["node " + str(n.name)] = (n as Node3D).global_position
	var bad: Array = []
	for k in targets:
		if not targets[k] is Vector3:
			bad.append(k)
			continue
		for from in [camp, rt.call("arrival_point")]:  # from the town square and from the dock
			var res: Dictionary = pathing.call("path_result", from, targets[k], 0)
			if not bool(res["reachable"]) and not k in bad:
				bad.append(k)
	_expect(bad.is_empty(), "the square and the dock reach the guild, the bench, the pit, the water, the town's herbs, berries and trees and every wild zone (%s)" % [bad])

## Owner: 4-5x the home island's land. Measured land area from the dry tiles, build time and cover.
func _test_size_and_perf(rt: Node3D, build_ms: int) -> void:
	var bb: Rect2i = rt.call("dry_bbox")
	var home_m2 := 375.0 * 300.0
	var m2 := float(bb.size.x * bb.size.y)
	_expect(m2 / home_m2 > 3.5 and m2 / home_m2 < 5.5, "the tutorial landmass bbox is %.1fx the home's (%s)" % [m2 / home_m2, bb.size])
	var cover := 0
	for mm in rt.find_children("*", "MultiMeshInstance3D", true, false):
		if (mm as MultiMeshInstance3D).multimesh:
			cover += (mm as MultiMeshInstance3D).multimesh.instance_count
	var zones: Array = rt.find_children("WildZone_*", "", false, false)
	var live := get_nodes_in_group("creatures").size()
	print("[t_tutorial] perf build_ms=%d cover=%d harvest=%d zones=%d live_creatures=%d" % [build_ms, cover, int(rt.get("harvest_count")), zones.size(), live])
	_expect(cover <= 80000, "ground cover stays under the perf ceiling (%d <= 80000)" % cover)
	_expect(int(rt.get("harvest_count")) <= 700, "harvest nodes stay bounded (%d)" % int(rt.get("harvest_count")))
	_expect(zones.size() >= 8 and live <= 24, "wild zones stream: %d zones, %d animals awake" % [zones.size(), live])
	_expect(build_ms < 30000, "the island builds in %d ms (no budget yet; reported)" % build_ms)

## A wild zone exists only near the survivor: far away the town's compsognathus go to sleep, back
## home they wake again.
func _test_streaming() -> void:
	var rt: Node3D = W.get("runtime")
	if rt == null:
		return
	var home_pos: Vector3 = _player.global_position
	# The compsognathus live outside the town's safe ring: stand by the nearest of their zones first.
	var compy_at := Vector3.INF
	for z in rt.find_children("WildZone_*_compsognathus", "", false, false):
		if compy_at == Vector3.INF or (z as Node3D).global_position.distance_to(home_pos) < compy_at.distance_to(home_pos):
			compy_at = (z as Node3D).global_position
	_expect(compy_at != Vector3.INF, "a compsognathus zone exists")
	if compy_at == Vector3.INF:
		return
	_player.global_position = compy_at + Vector3.UP
	await create_timer(1.5).timeout
	var near_town := _count(&"compsognathus")
	_expect(near_town > 0, "the compsognathus zone wakes when she comes near (%d)" % near_town)
	# Owner 2026-10-29: the hunt order pointed at a protoceratops. It names a compsognathus only.
	var keep_obj := int(W.get("objective"))
	var steps: Array = TUT.call("steps")
	for i in steps.size():
		if str((steps[i] as Dictionary).get("id", "")) == "tut_hunt":
			W.set("objective", i)
	var hunt: Dictionary = TUT.call("pointer_target", _player)
	var node: Variant = hunt.get("node")
	_expect(node is Node and (node as Node).get("def") != null and (node as Node).get("def").id == &"compsognathus",
		"the hunt order points at a compsognathus (%s)" % [(node as Node).get("def").id if node is Node and (node as Node).get("def") != null else "nothing"])
	W.set("objective", keep_obj)
	# Owner 2026-10-29: only compsognathus and zebraceratops live on the tutorial island.
	var others: Array = []
	for z in rt.find_children("WildZone_*", "", false, false):
		if not str(z.get("species")) in ["compsognathus", "zebraceratops"]:
			others.append(str(z.get("species")))
	for c in get_nodes_in_group("creatures"):
		var d: Variant = c.get("def")
		if d != null and not str(d.id) in ["compsognathus", "zebraceratops"]:
			others.append(str(d.id))
	_expect(others.is_empty(), "the tutorial island spawns only compsognathus and zebraceratops (%s)" % [others])
	var far := Vector3.INF
	for z in rt.find_children("WildZone_*", "", false, false):
		if (z as Node3D).global_position.distance_to(compy_at) > 280.0:
			far = (z as Node3D).global_position
	_expect(far != Vector3.INF, "a wild zone lies far out in the wild lands")
	if far == Vector3.INF:
		return
	_player.global_position = far + Vector3.UP
	await create_timer(1.5).timeout
	var far_species := 0
	for c in get_nodes_in_group("creatures"):
		if (c as Node3D).global_position.distance_to(far) < 60.0:
			far_species += 1
	_expect(_count(&"compsognathus") < near_town, "the compsognathus sleep while she is far (%d -> %d)" % [near_town, _count(&"compsognathus")])
	_expect(far_species > 0, "the far zone wakes when she arrives (%d animals)" % far_species)
	_player.global_position = compy_at + Vector3.UP
	await create_timer(1.5).timeout
	_expect(_count(&"compsognathus") >= near_town, "the compsognathus wake again on her return (%d)" % _count(&"compsognathus"))
	_player.global_position = home_pos
	await create_timer(1.5).timeout

func _count(species: StringName) -> int:
	var n := 0
	for c in get_nodes_in_group("creatures"):
		if c.get("def") and c.get("def").id == species and not c.is_queued_for_deletion():
			n += 1
	return n

## Every order in order with the real actions; save + reload half-way and carry on; the last order ferries home.
func _test_bot_run() -> void:
	var bot = load("res://scripts/dev/tutorial_bot.gd").new()
	bot.name = "TutorialBot"
	root.add_child(bot)
	bot.player = _player
	bot.minutes = 60.0
	var steps: Array = TUT.call("steps")
	var half := 9
	# The pointer has a target for each world order at its start (HUD orders need the HUD; t_ui-style labs cover those).
	var why: String = await _run_with_pointer(bot, 0, half)
	_expect(why == "", "orders 1-%d complete in order (%s)" % [half, why])
	if why != "":
		return
	var did_before: Dictionary = (W.get("tutorial") as Dictionary).get("did", {}).duplicate()
	var level_before := int(W.get("pioneer_level"))
	_expect(bool(SG.call("save_now")), "a mid-tutorial save is written")
	# Forget, then load: the island, order and records come back.
	W.set("objective", 0)
	W.set("tutorial", {"done": true, "did": {}})
	SG.call("load_now", _host)
	await process_frame
	await process_frame
	_expect(W.get("island_id") == &"tutorial_isle", "the reload is on the tutorial island")
	_expect(bool(TUT.call("active")) and int(W.get("objective")) == half, "the reload resumes at order %d (got %d)" % [half + 1, int(W.get("objective")) + 1])
	_expect((W.get("tutorial") as Dictionary).get("did", {}) == did_before, "the tutorial records survive the reload (%s)" % [(W.get("tutorial") as Dictionary).get("did")])
	_expect(int(W.get("pioneer_level")) == level_before, "the level survives the reload")
	_player = W.call("_player")
	bot.player = _player
	why = await _run_with_pointer(bot, half, steps.size())
	_expect(why == "", "orders %d-%d complete in order (%s)" % [half + 1, steps.size(), why])
	if why != "":
		return
	_expect(W.call("is_home"), "the last order ferries the survivor to the Tamed Island")
	_expect(W.get("home_shape") == &"meadow", "the picked shape is the home (%s)" % W.get("home_shape"))
	_expect(not bool(TUT.call("active")), "the tutorial is done")
	_expect(int(W.get("objective")) == int(TUT.call("resume_index")), "the standing orders continue at '%s'" % root.get_node("Data").tutorial_resume_at)
	_expect(_player.inventory.count_of(&"work_axe") >= 1, "the bag comes along (work axe)")
	_expect(int(_player.skills.sp_spent) > 0, "learned skills come along")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.get("path")))
	_expect(str(saved.get("island_id", "")) == "home_grassland" and not saved.has("tutorial"), "the home save drops the tutorial row (done = absent)")
	_expect(str((saved.get("home", {}) as Dictionary).get("shape", "")) == "meadow", "the save holds the picked Tamed Island")
	# Reload once more: home, never the tutorial again.
	SG.call("load_now", _host)
	await process_frame
	_expect(W.call("is_home") and not bool(TUT.call("active")), "a reload after the tutorial loads the home")
	for n in root.find_children("ArrivalWelcome", "CanvasLayer", true, false):
		n.free()
	bot.queue_free()

func _run_with_pointer(bot: Node, from: int, to: int) -> String:
	var steps: Array = TUT.call("steps")
	for i in range(from, to):
		var spec := str((steps[i] as Dictionary).get("point_at", ""))
		if not (spec.begins_with("ui:") or spec.begins_with("ctx:") or spec.begins_with("have:")):
			var tgt: Dictionary = TUT.call("pointer_target", _player)
			_expect(tgt.has("world"), "order %d (%s) has a pointer target on the island" % [i + 1, (steps[i] as Dictionary).get("id")])
		var why: String = await bot.call("run_steps", i, i + 1)
		if why != "":
			return why
	return ""

## A save with a home and no tutorial row (every save before this feature) loads into the home.
func _test_old_save() -> void:
	_wipe()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIX + "save_v1.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(SG.get("path")).get_base_dir()))
	var f := FileAccess.open(SG.get("path"), FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	W.set("tutorial", {"done": false, "did": {}})
	var loaded: bool = W.call("ensure_survivor", _host)
	await process_frame
	_expect(loaded, "an old save loads (no character creation)")
	_expect(not bool(TUT.call("active")), "an old save counts as tutorial done")
	_expect(W.get("island_id") != &"tutorial_isle" and W.call("is_home"), "an old save loads into its home (%s)" % W.get("island_id"))
	_expect(get_nodes_in_group(&"island_pick").is_empty(), "an old save is never offered the pick")
	_expect(get_nodes_in_group(&"character_creation").is_empty(), "an old save never sees character creation")
	# A forged row cannot inject junk: bad types fall back to done.
	var clean: Dictionary = TUT.call("from_save", {"done": "no", "did": {"eat": 1e30, "x": "y"}})
	_expect(clean["done"] == true and int(clean["did"]["eat"]) == 1000000 and not clean["did"].has("x"), "a forged tutorial row is cleaned (%s)" % [clean])

## --skip-tutorial: a new game goes straight to the pick; a mid-tutorial save jumps to the grant.
## --tutorial-step=n: a new game starts at order n.
func _test_skip_and_step() -> void:
	_wipe()
	for n in root.find_children("ArrivalWelcome", "CanvasLayer", true, false):
		n.free()
	W.set("home_shape", &"")
	W.set("home_terrain", &"")
	TUT.set("dev_args", PackedStringArray(["--skip-tutorial"]))
	W.call("start_new", _host)
	var cc := _host.get_node_or_null("CharacterCreation")
	cc.call("select_occupation", "farmer")
	cc.call("_finish")
	await process_frame
	var ips := get_nodes_in_group(&"island_pick")
	_expect(not ips.is_empty() and (ips[0] as CanvasLayer).visible, "--skip-tutorial opens the pick right after creation")
	_expect(W.get("island_id") != &"tutorial_isle" and not bool(TUT.call("active")), "--skip-tutorial never loads the tutorial island")
	for n in ips:
		n.free()
	# Mid-tutorial save + --skip-tutorial: the load opens the grant.
	_wipe()
	W.set("home_shape", &"")
	TUT.set("dev_args", PackedStringArray(["--tutorial-step=5"]))
	W.call("start_new", _host)
	cc = _host.get_node_or_null("CharacterCreation")
	cc.call("select_occupation", "farmer")
	cc.call("_finish")
	await process_frame
	_expect(int(W.get("objective")) == 4 and bool(TUT.call("active")), "--tutorial-step=5 starts at order 5 (got %d)" % (int(W.get("objective")) + 1))
	TUT.set("dev_args", PackedStringArray(["--skip-tutorial"]))
	TUT.set("_offering", false)
	SG.call("load_now", _host)
	await process_frame
	ips = get_nodes_in_group(&"island_pick")
	_expect(not ips.is_empty() and (ips[0] as CanvasLayer).visible, "--skip-tutorial on a mid-tutorial save opens the Tamed Island grant")
	for n in ips:
		n.free()
	TUT.set("dev_args", PackedStringArray())
	TUT.set("_offering", false)

func _wipe() -> void:
	var p := str(SG.get("path"))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(p + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p + suffix))
