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
	cc.call("_finish")
	await process_frame
	await process_frame
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
		_expect(TUT.call("nearest_fresh_water", camp) != null, "fresh water within 80 m of the camp")
		var herbs := 0
		for n in get_nodes_in_group("harvest"):
			for o in n.call("options"):
				if str((o as Dictionary).get("item", "")) == "herb_leaf" and (n as Node3D).global_position.distance_to(camp) < 20.0:
					herbs += 1
		_expect(herbs >= 1, "herbs grow by the camp (%d)" % herbs)
		var logs := 0
		for n in get_nodes_in_group("harvest"):
			for o in n.call("options"):
				if str((o as Dictionary).get("item", "")) == "wood_log" and (n as Node3D).global_position.distance_to(camp) < 20.0:
					logs += 1
		_expect(logs >= 1, "a tree for logs stands by the camp (%d)" % logs)
		var compys := 0
		for n in get_nodes_in_group("creatures"):
			if n.get("def") and n.get("def").id == &"compsognathus":
				compys += 1
		_expect(compys >= 2, "weak animals to hunt (%d compsognathus)" % compys)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.get("path")))
	_expect(str(saved.get("island_id", "")) == "tutorial_isle", "the first save is on the tutorial island")
	_expect(saved.get("tutorial") is Dictionary and saved["tutorial"].get("done") == false, "the save carries tutorial.done=false")

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
