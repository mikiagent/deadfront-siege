extends SceneTree
## TASKSCREEN acceptance: the Task screen's five category tabs list the right tasks; progress follows play
## (gather / craft / hunt counts, buildings, skill levels); Receive pays once and only when complete, and
## the popup itemises it; the tab red dot and the nav badge follow what can be received; daily counts
## reset on the next UTC day and weekly on Monday; the tasks block survives save -> load, and an old save
## (no block) loads its finished orders as received. Writes PNGs with `-- --taskshots=<dir>` (windowed).
## Usage: godot --headless --path game --script res://tests/t_taskscreen.gd -> "[t_taskscreen] PASS", exit 0/1.

var _fails: Array[String] = []
var _started := false
var _host: Node3D
var _player
var _hud
var W: Node
var T: GDScript
var SG: GDScript

func _process(_delta: float) -> bool:
	if _started:
		return false
	if root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
	print("[t_taskscreen] %s %s" % ["ok" if ok else "FAIL", what])

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot_dir() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--taskshots="):
			return a.trim_prefix("--taskshots=")
	return ""

func _run() -> void:
	W = root.get_node("World")
	T = load("res://scripts/core/tasks.gd")
	SG = load("res://scripts/core/save_game.gd")
	_host = Node3D.new()
	_host.name = "TTaskHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("open_orders"):
			_hud = c
	W.home_terrain = &"meadow"
	W.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	await _frames(2)
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	W.objective = 0
	W.objective_best = 0
	T.clock_override = 1_700_000_000  # a Tuesday, 22:13 UTC
	T.reset()
	_test_tabs()
	_test_progress_and_claim()
	_test_main()
	_test_reset()
	await _test_screen()
	await _test_save()
	if _shot_dir() != "":
		await _shots(_shot_dir())
	T.clock_override = -1
	if _fails.is_empty():
		print("[t_taskscreen] PASS")
		quit(0)
	else:
		print("[t_taskscreen] FAIL count=%d" % _fails.size())
		quit(1)

func _ids(cat: StringName) -> Array:
	return T.rows(cat, _player).map(func (r: Dictionary) -> String: return str(r["id"]))

func _test_tabs() -> void:
	_expect(T.CATS == [&"daily", &"achievement", &"domain", &"main", &"weekly"], "five categories in Durango's order")
	var daily := _ids(&"daily")
	_expect(daily.size() == 3 and daily.has("daily.gather") and daily.has("daily.craft") and daily.has("daily.hunt"), "Daily lists gather / craft / hunt (%s)" % [daily])
	_expect(_ids(&"weekly").size() == 3 and _ids(&"weekly").has("weekly.hunt"), "Weekly lists its three")
	var dom := _ids(&"domain")
	_expect(dom.has("domain.workbench") and dom.has("domain.taming_pen") and dom.size() == 8, "Domain Construction lists the build milestones (%s)" % [dom])
	var ach := _ids(&"achievement")
	_expect(ach.size() == 13 and ach.has("achievement.character.5") and ach.has("achievement.cooking.10"), "Achievement: one row per chain, character + 12 skills (%s)" % [ach.slice(0, 3)])
	_expect(_ids(&"main").size() == W.get_node("/root/Data").world_objectives.size(), "Main Task lists every standing order")

func _row(id: String) -> Dictionary:
	return T.find(id, _player)

func _test_progress_and_claim() -> void:
	_expect(T.claimable_count(_player) == 0, "a fresh survivor has nothing to receive (%d)" % T.claimable_count(_player))
	var t0: int = W.t_stones
	_expect(T.claim("daily.gather", _player).is_empty() and W.t_stones == t0, "Receive on an unfinished task pays nothing")
	T.note(&"gather", 12)
	var r := _row("daily.gather")
	_expect(int(r["got"]) == 12 and int(r["want"]) == 30 and not r["claimable"], "gathering counts toward the daily (%d/%d)" % [r["got"], r["want"]])
	_expect(int(_row("weekly.gather")["got"]) == 12, "and toward the weekly")
	T.note(&"gather", 20)
	r = _row("daily.gather")
	_expect(r["done"] and r["claimable"] and int(r["got"]) == 30, "past the target it reads 30/30 and can be received")
	_expect(T.claimable_count(_player, &"daily") == 1 and T.claimable_count(_player, &"weekly") == 0, "red dot logic: Daily has one, Weekly none")
	var xp0: int = W.pioneer_xp + W.pioneer_level * 100000
	var paid: Dictionary = T.claim("daily.gather", _player)
	_expect(not paid.is_empty() and W.t_stones == t0 + 5, "Receive pays its T-stones once (%d -> %d)" % [t0, W.t_stones])
	_expect(W.pioneer_xp + W.pioneer_level * 100000 > xp0, "and its EXP")
	_expect(T.claim("daily.gather", _player).is_empty() and W.t_stones == t0 + 5, "a second Receive pays nothing")
	_expect(_row("daily.gather")["claimed"] and T.claimable_count(_player, &"daily") == 0, "the row reads received; the dot clears")
	# Domain: buildings placed in the domain (the saved first-of-kind memory).
	W.pioneer_buildings["workbench"] = 1
	_expect(_row("domain.workbench")["claimable"], "a placed workbench completes Build a Workbench")
	W.pioneer_buildings.erase("workbench")
	# Achievement: a skill level through the skills API, paying T-stones, one skill point and EXP.
	var sk = _player.skills
	sk.trees["cooking"]["level"] = 10
	var a := _row("achievement.cooking.10")
	_expect(a["claimable"] and str(a["title"]) == "Level Up Cooking" and str(a["desc"]) == "Reach Cooking level 10.", "Cooking Lv 10 completes Level Up Cooking (%s / %s)" % [a.get("title"), a.get("desc")])
	var sp0: int = sk.sp_now()
	var t1: int = W.t_stones
	T.claim("achievement.cooking.10", _player)
	_expect(sk.sp_now() == sp0 + 1 and W.t_stones == t1 + 10, "the achievement pays 1 skill point and 10 T-stones (SP %d -> %d)" % [sp0, sk.sp_now()])
	var next: Array = T.rows(&"achievement", _player).filter(func (x: Dictionary) -> bool: return str(x["id"]).begins_with("achievement.cooking."))
	_expect(next.size() == 1 and str(next[0]["id"]) == "achievement.cooking.20" and not next[0]["claimable"], "the Cooking chain moves on to Lv 20")
	sk.trees["cooking"]["level"] = 1

func _test_main() -> void:
	var steps: Array = W.get_node("/root/Data").world_objectives
	var first := "main." + str((steps[0] as Dictionary)["id"])
	var t0: int = W.t_stones
	_player.inventory.add(load("res://scripts/items/item_stack.gd").make(&"branch", 3))
	var Obj: GDScript = load("res://scripts/core/objectives.gd")
	_expect(Obj.settle(_player) >= 1 and W.objective >= 1, "a finished order still advances the standing orders")
	_expect(W.t_stones == t0, "but settle pays nothing on its own")
	_expect(_row(first)["claimable"], "the finished order waits as a claimable Main Task")
	_expect(not _row("main." + str((steps[W.objective] as Dictionary)["id"]))["claimable"], "the running order is not claimable")
	_expect(T.rows(&"main", _player)[0]["id"] == first, "claimable rows sort first")
	T.claim(first, _player)
	_expect(_row(first)["claimed"], "Receive marks the order received")

func _test_reset() -> void:
	T.note(&"craft", 3)
	T.note(&"hunt", 1)
	_expect(_row("daily.craft")["claimable"], "3 crafts complete the daily craft")
	T.claim("daily.craft", _player)
	T.clock_override += 3 * 3600  # Wednesday 01:13 UTC: a new day, same week
	_expect(int(_row("daily.craft")["got"]) == 0 and not _row("daily.craft")["claimed"], "the next UTC day resets the daily counts and claims")
	_expect(int(_row("weekly.craft")["got"]) == 3 and int(_row("weekly.hunt")["got"]) == 1, "the weekly counts carry over inside the week")
	T.clock_override += 5 * 86400  # the next Monday 01:13 UTC
	_expect(int(_row("weekly.craft")["got"]) == 0, "Monday 00:00 UTC resets the weekly counts")

func _tab_dot(sheet: Control, cat: StringName) -> bool:
	return (sheet.find_child("Tab_%s" % cat, true, false).get_node("Dot") as Control).visible

func _test_screen() -> void:
	T.note(&"hunt", 2)  # daily hunt claimable
	_hud.open_orders()
	await _frames(2)
	var sheet: Control = _hud._orders_sheet
	_expect(sheet.visible and sheet.cat == &"daily", "the screen opens on the first tab with something to receive (%s)" % sheet.cat)
	_expect(_tab_dot(sheet, &"daily") and not _tab_dot(sheet, &"weekly") and not _tab_dot(sheet, &"domain"), "the red dot shows on Daily only")
	var row: Control = sheet._list.get_child(0)
	var rec: Button = row.find_child("Receive", true, false)
	_expect(str(row.get_meta("task_id")) == "daily.hunt" and rec != null, "the claimable row sits first with a Receive button")
	_expect(sheet._list.get_children().filter(func (c: Node) -> bool: return c.find_child("Receive", true, false) != null).size() == 1, "only the complete task shows Receive")
	var t0: int = W.t_stones
	rec.pressed.emit()
	await _frames(1)
	_expect(W.t_stones == t0 + 5 and sheet.popup.visible, "Receive pays and opens the popup")
	_expect(str(sheet._pop_title.text) == "Daily Hunt Complete" and sheet._pop_rows.get_child_count() == 2, "the popup reads Daily Hunt Complete with T-Stones and EXP rows (%s, %d)" % [sheet._pop_title.text, sheet._pop_rows.get_child_count()])
	_expect(not _tab_dot(sheet, &"daily"), "the Daily dot clears after Receive")
	(sheet._pop_ok as Button).pressed.emit()
	_expect(not sheet.popup.visible, "OK closes the popup")
	# Nav badge: the HUD polls the claimable count into the Orders/Tasks entry and the MENU hex.
	T.note(&"gather", 400)
	_hud.set("_tasks_poll", 0.0)
	_hud._tick_orders_auto(0.01)
	_expect(_hud.field.count(&"orders") == T.claimable_count(_player) and _hud.field.count(&"orders") >= 2, "the nav badge counts what can be received (%d)" % _hud.field.count(&"orders"))
	sheet.select(&"weekly")
	await _frames(1)
	_expect(sheet._list.get_child(0).find_child("Receive", true, false) != null, "Weekly Gathering is receivable after 400 gathers")
	sheet.close()

func _test_save() -> void:
	T.note(&"craft", 2)
	var before: Dictionary = T.to_dict()
	_expect(SG.save_now(), "the game saves")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SG.path))
	_expect(raw.has("tasks") and (raw["tasks"] as Dictionary).has("claimed"), "the save carries a tasks block")
	T.reset()
	SG.load_now(_host)
	await _frames(2)
	var after: Dictionary = T.to_dict()
	_expect(after["claimed"] == before["claimed"] and int(after["counts"].get("daily.craft", 0)) == int(before["counts"].get("daily.craft", 0)) and int(after["day"]) == int(before["day"]), "claims, counts and the reset day survive save -> load (%s)" % [after["claimed"].keys()])
	# An old save has no tasks block: the orders it already finished were paid, so they load as received.
	W.objective = 3
	T.from_dict(null)
	var steps: Array = W.get_node("/root/Data").world_objectives
	_expect(_row("main." + str((steps[2] as Dictionary)["id"]))["claimed"] and not _row("main." + str((steps[3] as Dictionary)["id"]))["claimed"] and T.claimable_count(_player, &"main") == 0, "an old save's finished orders load as received, nothing to claim twice")
	T.from_dict({"claimed": "junk", "counts": {"daily.gather": [1]}, "day": "x"})
	_expect(int(T.counts.get("daily.gather", 0)) == 0, "a forged tasks block loads without errors or counts")

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	W.objective = 0
	T.reset()
	_player.skills.trees["cooking"]["level"] = 10
	_player.skills.trees["gathering"]["level"] = 7
	for view in [Vector2i(1600, 900), Vector2i(844, 390)]:
		root.size = view
		root.content_scale_size = view
		await _frames(3)
		_hud.open_orders()
		var sheet: Control = _hud._orders_sheet
		sheet.select(&"achievement")
		await _frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("task_achievement_%dx%d.png" % [view.x, view.y]))
		sheet.receive("achievement.cooking.10")
		await _frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("task_claim_popup_%dx%d.png" % [view.x, view.y]))
		sheet.close()
		T.claimed.erase("achievement.cooking.10")
	print("[t_taskscreen] shots in %s" % dir)
