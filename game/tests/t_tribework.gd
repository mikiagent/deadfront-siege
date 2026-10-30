extends SceneTree
## TRIBE M2a hand-off (docs/design/hunger-and-tribe-automation.md §2.2, §2.8) on the real home island:
##   1. refusals with reasons: craft it once first, missing materials, needs <Skill> N, success below the
##      minimum, busy, one worker per station; the station radial offers ASSIGN, then STOP <name>;
##   2. assign a craft: the picked instances leave the bag into escrow, the member walks to the workbench,
##      works it with the hammer clip and its job plate, the output lands in the basket beside it and the
##      member (not the survivor) gets the XP;
##   3. cancel (and the Stay order) hands the escrow back to the bag;
##   4. save/load mid-craft keeps the escrow, the decided outcome and the progress, and the craft finishes;
##   5. assign a builder to a filled construction site: it completes at the builder's Construction level,
##      the builder gets the XP; an unfilled site is refused ("Missing materials").
## Run: Godot --headless --path game --script res://tests/t_tribework.gd -> "[t_tribework] PASS".

var _fails: PackedStringArray = []
var _started := false
var _done := false
var _sections := 0
const WANT := 5
var player: Node
var host: Node3D
var wb: Node3D
var basket: Node3D
var IS: GDScript

func _process(_delta: float) -> bool:
	if _started or root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	IS = load("res://scripts/items/item_stack.gd")
	_run.call_deferred()
	_watchdog()
	return false

func _watchdog() -> void:
	var t := 0.0
	while t < 400.0:
		await create_timer(1.0, true, false, true).timeout
		t += 1.0
		if _done:
			return
	print("[t_tribework] FAIL watchdog (400 s)")
	quit(1)

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
		print("[t_tribework] FAIL %s" % what)
	else:
		print("[t_tribework] ok %s" % what)

func _finish() -> void:
	_done = true
	Engine.time_scale = 1.0
	_expect(_sections == WANT, "only %d of %d sections completed" % [_sections, WANT])
	if _fails.is_empty():
		print("[t_tribework] PASS")
		quit(0)
	else:
		print("[t_tribework] FAIL count=%d" % _fails.size())
		quit(1)

func _ground(x: float, z: float) -> Vector3:
	var w = root.get_node("World")
	return Vector3(x, w.runtime.surface_y(x, z), z)

func _run() -> void:
	var T = load("res://scripts/tribe/tribe.gd")
	T.reset()
	T.seeded = true
	T.rng.seed = 11
	host = Node3D.new()
	host.name = "TTribeWorkHost"
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 20.0)
	player = kit["player"]
	var world: Node = root.get_node("World")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	var kit_floor := host.get_node_or_null("Floor")
	if kit_floor:
		kit_floor.free()
	await process_frame
	await physics_frame
	_expect(world.is_home(), "the test runs on the home island (members have bodies at home)")
	var at: Vector3 = player.global_position
	wb = load("res://scripts/world/craft_station.gd").make(&"workbench")
	world.runtime.add_child(wb)
	wb.global_position = _ground(at.x + 4.0, at.z)
	basket = load("res://scripts/world/placed_building.gd").make(&"basket")
	world.runtime.add_child(basket)
	basket.global_position = _ground(at.x + 4.0, at.z + 2.5)
	await physics_frame
	await _test_refusals(T, world)
	await _test_craft(T, world)
	await _test_cancel(T, world)
	await _test_save_mid_job(T, world)
	await _test_build(T, world)
	_finish()

func _member(T, nm: String):
	var r = T.make_recruit(T.rng)
	r.name = nm
	var at: Vector3 = player.global_position
	r.pos = [at.x - 2.0, at.y, at.z + 2.0]
	T.members.append(r)
	return r

func _clear_bag() -> void:
	var inv = player.inventory
	for i in inv.slot_count:
		inv.slots[i] = null

func _axe_mats() -> void:
	player.inventory.add(IS.make(&"stone", 1, {}, 1))
	player.inventory.add(IS.make(&"branch", 1, {}, 1))
	player.inventory.add(IS.make(&"twine", 1, {}, 1))

func _count(id: StringName) -> int:
	return player.inventory.count_of(id)

func _settle(frames: int) -> void:
	for i in frames:
		await physics_frame

## Run until `cond` holds (or `limit` seconds of game time at 4x).
func _until(cond: Callable, limit: float, watch: Callable = Callable()) -> bool:
	Engine.time_scale = 4.0
	var t := 0
	var ok := false
	while t < int(limit * 60.0 / 4.0) + 60:
		await physics_frame
		t += 1
		if watch.is_valid():
			watch.call()
		if cond.call():
			ok = true
			break
	Engine.time_scale = 1.0
	return ok

# ---------------------------------------------------------------- 1. refusals

func _test_refusals(T, world) -> void:
	var TW = load("res://scripts/tribe/tribe_work.gd")
	var SC = load("res://scripts/items/station_craft.gd")
	_clear_bag()
	_expect(SC.assign_actions(wb).is_empty(), "no tribe members: no ASSIGN hex")
	var r = _member(T, "Joss")
	var acts: Array = SC.assign_actions(wb)
	_expect(acts.size() == 1 and str(acts[0]["id"]) == "assign", "a workbench offers ASSIGN once the tribe has a member (%s)" % [acts])
	world.pioneer_crafts.erase("work_axe")
	_expect(TW.assign_craft(player, r, wb, &"work_axe") == "Craft it once yourself first", "teach by doing: a recipe the survivor never made is refused")
	world.pioneer_crafts["work_axe"] = true
	world.pioneer_crafts["forager_hood"] = true
	_expect(TW.assign_craft(player, r, wb, &"work_axe") == "Missing materials", "an empty bag: 'Missing materials'")
	var hood: Dictionary = load("res://scripts/items/crafting.gd").recipe(&"forager_hood")
	var o: Dictionary = TW.craft_offer(player, r, hood, wb)
	_expect(str(o["why"]) == "Needs Tailoring 10", "a Lv 10 recipe at Tailoring 1: '%s'" % o["why"])
	r.skills["tailoring"] = 10
	var cfg: Dictionary = T.cfg()["work"]
	cfg["min_success"] = 0.9
	o = TW.craft_offer(player, r, hood, wb)
	_expect(str(o["why"]).begins_with("84% success, needs Tailoring"), "below the minimum success: '%s'" % o["why"])
	cfg["min_success"] = 0.8
	o = TW.craft_offer(player, r, hood, wb)
	_expect(str(o["why"]) == "" and is_equal_approx(float(o["success"]), 0.84), "at 84 %% it passes the 80 %% minimum ('%s')" % o["why"])
	_axe_mats()
	_expect(TW.assign_craft(player, r, wb, &"work_axe") == "", "Joss takes the axe")
	var r2 = _member(T, "Kit")
	_axe_mats()
	_expect(TW.assign_craft(player, r, wb, &"work_axe").contains("is busy"), "a member on an order is busy")
	_expect(TW.assign_craft(player, r2, wb, &"work_axe") == "Joss already works here", "one worker per station")
	acts = SC.assign_actions(wb)
	_expect(acts.size() == 1 and str(acts[0]["label"]) == "STOP JOSS", "the radial now offers STOP JOSS (%s)" % [acts])
	# The picker shows a refused member greyed out with the reason.
	var rows: Array = [{"record": r, "text": "Joss", "why": "Joss is busy"}, {"record": r2, "text": TW.offer_text(r2, TW.craft_offer(player, r2, load("res://scripts/items/crafting.gd").recipe(&"work_axe"), wb)), "why": ""}]
	var pick = load("res://scripts/ui/tribe_assign_picker.gd").open_on(host.get_node("UI"), "Assign", rows, func (_x) -> void: pass)
	await process_frame
	var b1: Button = pick.find_child("Pick_" + r.uid, true, false)
	var b2: Button = pick.find_child("Pick_" + r2.uid, true, false)
	_expect(b1 and b1.disabled and b1.text.contains("busy") and b2 and not b2.disabled and b2.text.contains("Weapon Tools 1") and b2.text.contains("100%"),
		"the picker lists members with skill and success, refusals greyed (%s / %s)" % [b1.text if b1 else "-", b2.text if b2 else "-"])
	pick.queue_free()
	TW.cancel(player, r)
	T.members.erase(r2)
	_sections += 1

# ---------------------------------------------------------------- 2. craft hand-off

func _test_craft(T, _world) -> void:
	var TW = load("res://scripts/tribe/tribe_work.gd")
	_clear_bag()
	_axe_mats()
	var r = T.members[0]
	var xp0: Dictionary = r.skill_xp.duplicate()
	var survivor_xp := str(player.skills.trees.get("weapon_tools", {}))
	# Through the craft panel: place the picks, Assign…, tap Joss in the picker.
	player.global_position = wb.global_position + Vector3(-1.5, 1.0, 0.0)  # the panel's station is the nearest one
	var craft = player.craft_ui
	craft.show_for_station(&"workbench")
	craft.open_place("work_axe")
	await process_frame
	var place = craft._place
	var assign: Button = place.find_child("AssignCta", true, false)
	_expect(assign != null and assign.visible and assign.disabled, "the place view shows Assign…, live once every slot is placed")
	for i in place.placed.size():
		place._select_slot(i)
		place.place_focused()
	await process_frame
	_expect(assign and not assign.disabled, "every slot placed: Assign… is live")
	if assign:
		assign.pressed.emit()
	await process_frame
	var picker: Node = host.get_node("UI").find_child("TribeAssignPicker", true, false)
	var row: Button = picker.find_child("Pick_" + r.uid, true, false) if picker else null
	_expect(row != null and not row.disabled and row.text.begins_with("Joss · Weapon Tools 1 · 100%"), "the picker offers Joss with skill and odds (%s)" % (row.text if row else "none"))
	if row:
		row.pressed.emit()
	await process_frame
	_expect(TW.is_station_job(r) and not craft.visible, "tapping Joss assigns the craft and closes the panel")
	_expect(_count(&"stone") == 0 and _count(&"branch") == 0 and _count(&"twine") == 0 and r.escrow.used_slots() == 3,
		"the picked instances left the bag into escrow (%d escrow stacks)" % r.escrow.used_slots())
	await _settle(4)
	var body = player.tribe.body_of(r)
	_expect(body != null, "the member has a body")
	if body == null:
		_sections += 1
		return
	var seen := {"craft": false, "hammer": false, "plate": "", "dist": 99.0}
	var done := await _until(func () -> bool: return r.job.is_empty(), 60.0, func () -> void:
		if body.state == &"craft":
			seen["craft"] = true
			seen["hammer"] = seen["hammer"] or body._clip == &"work_hammer"
			seen["plate"] = body.plate.text if body.plate.visible else seen["plate"]
			seen["dist"] = minf(seen["dist"], Vector2(body.global_position.x - wb.global_position.x, body.global_position.z - wb.global_position.z).length()))
	_expect(done, "the craft finished (job %s, state %s)" % [r.job, body.state])
	_expect(seen["craft"] and float(seen["dist"]) <= 2.05, "the member walked to the workbench and worked it (%.2f m)" % float(seen["dist"]))
	_expect(seen["hammer"], "with the work_hammer clip")
	_expect(str(seen["plate"]).contains("Joss") and str(seen["plate"]).contains("Crafting"), "its plate shows the job ('%s')" % str(seen["plate"]).replace("\n", " / "))
	var inv = basket.storage
	_expect(inv.count_of(&"work_axe") == 1 and _count(&"work_axe") == 0, "the axe landed in the basket beside the workbench")
	_expect(float(r.skill_xp.get("weapon_tools", 0.0)) > float(xp0.get("weapon_tools", 0.0)) or r.skill("weapon_tools") > 1, "the member got Weapon Tools XP")
	_expect(str(player.skills.trees.get("weapon_tools", {})) == survivor_xp, "the survivor got none")
	await _settle(30)
	_expect(r.order == &"stay" and r.escrow.used_slots() == 0 and not body.plate.visible, "the member stands down, escrow empty, plate hidden")
	_sections += 1

# ---------------------------------------------------------------- 3. cancel refunds

func _test_cancel(T, _world) -> void:
	var TW = load("res://scripts/tribe/tribe_work.gd")
	var r = T.members[0]
	_clear_bag()
	_axe_mats()
	_expect(TW.assign_craft(player, r, wb, &"work_axe") == "" and _count(&"stone") == 0, "assigned again")
	_expect(TW.cancel(player, r) == "", "cancel")
	_expect(_count(&"stone") == 1 and _count(&"branch") == 1 and _count(&"twine") == 1 and r.escrow.used_slots() == 0 and r.order == &"stay",
		"cancel hands every escrowed instance back")
	_expect(TW.assign_craft(player, r, wb, &"work_axe") == "", "assigned once more")
	T.set_order(r, &"stay")
	_expect(_count(&"stone") == 1 and r.escrow.used_slots() == 0 and r.job.is_empty(), "the Stay order cancels it and refunds too")
	_sections += 1

# ---------------------------------------------------------------- 4. save / load mid-job

func _test_save_mid_job(T, _world) -> void:
	var TW = load("res://scripts/tribe/tribe_work.gd")
	var SS = load("res://scripts/core/save_sanitizer.gd")
	var r = T.members[0]
	_clear_bag()
	_axe_mats()
	var axes0: int = basket.storage.count_of(&"work_axe")
	_expect(TW.assign_craft(player, r, wb, &"work_axe") == "", "assigned for the save test")
	r.job["seconds"] = 30.0  # a long craft, so the save lands mid-way
	r.job["progress"] = 12.0
	var outcome: Dictionary = r.job["outcome"].duplicate()
	var row: Dictionary = SS.clean({"tribe": JSON.parse_string(JSON.stringify(T.to_save()))})
	T.from_save(row["tribe"])
	for uid in player.tribe.live.keys():  # a real load rebuilds the scene; here the old bodies go
		player.tribe.live[uid].queue_free()
	player.tribe.live.clear()
	var r2 = T.members[0]
	_expect(r2 != r and r2.escrow.used_slots() == 3 and str(r2.job.get("kind", "")) == "craft" and r2.order == &"work", "the order and its escrow came back (%s)" % [r2.job])
	_expect(is_equal_approx(float(r2.job["progress"]), 12.0) and r2.job["outcome"] == outcome, "progress and the decided outcome are kept")
	r2.job["progress"] = 29.0
	var done := await _until(func () -> bool: return r2.job.is_empty(), 40.0)
	_expect(done and basket.storage.count_of(&"work_axe") == axes0 + 1, "the loaded order finished into the basket")
	# An old save's member row (no escrow, M1 job) still loads.
	var old = load("res://scripts/tribe/tribe_record.gd").from_dict({"name": "Old", "job": {"kind": "mine", "center": [1, 2]}, "order": "work"})
	_expect(old.escrow.used_slots() == 0 and str(old.job["kind"]) == "mine", "an M1 row loads unchanged")
	_sections += 1

# ---------------------------------------------------------------- 5. construction

func _test_build(T, world) -> void:
	var TW = load("res://scripts/tribe/tribe_work.gd")
	var r = T.members[0]
	var grid = world.runtime.get("build_grid")
	grid.ignore_distance = true
	var base: Vector2i = load("res://scripts/world/build_grid.gd").tile_of(player.global_position)
	var cell := Vector2i(999, 999)
	for d in range(3, 14):
		for c in [base + Vector2i(-d, 0), base + Vector2i(0, d), base + Vector2i(0, -d), base + Vector2i(-d, d)]:
			if grid.can_place(&"workbench", c, 0) == "":
				cell = c
				break
		if cell.x != 999:
			break
	_expect(cell.x != 999, "a free cell for the site")
	var site = load("res://scripts/world/construction_site.gd").new()
	site.setup(&"basic_workbench", "Tester")
	site.grid_kind = &"workbench"
	world.runtime.add_child(site)
	site.global_transform = grid.placement_transform(&"workbench", cell, 0)
	site.set_grid_pose(cell, 0)
	grid.occupy(site, grid.cells_for(&"workbench", cell, 0))
	_expect(TW.assign_build(r, site) == "Missing materials", "an unfilled site is refused: 'Missing materials'")
	_clear_bag()
	for row in [["plank_shape", 30], ["plank_shape", 20], ["pillar_shape", 15], ["pillar_shape", 15]]:
		player.inventory.add(IS.make(StringName(row[0]), 1, {}, int(row[1])))
	for i in 6:
		player.inventory.add(IS.make(&"strap", 1, {}, 3))
	site.bind_bag(player.inventory)
	for s in site.slot_count():
		while site.deposited(s) < site.needed(s):
			var idx: int = site.first_fitting(player.inventory, s)
			if idx < 0 or not site.deposit(s, idx):
				break
	_expect(site.materials_ready(), "the site is filled")
	site.building = true
	var o: Dictionary = TW.build_offer(r, site)
	_expect(int(o["result_level"]) == 1 and str(o["why"]) == "", "the builder's offer: Construction 1 caps the station at Lv 1 (%s)" % [o])
	var bbody = player.tribe.body_of(r)
	bbody.process_mode = Node.PROCESS_MODE_DISABLED
	var w0: float = site.work_progress
	_expect(TW.assign_build(r, site) == "", "assign the builder")
	await _settle(30)
	_expect(is_equal_approx(site.work_progress, w0) and site.building, "the site's own timer waits for the builder (%.2f -> %.2f)" % [w0, site.work_progress])
	bbody.process_mode = Node.PROCESS_MODE_INHERIT
	var xp0: float = float(r.skill_xp.get("construction", 0.0))
	var survivor_c: int = player.skills.level_of("construction")
	var done := await _until(func () -> bool: return not is_instance_valid(site) or site.is_queued_for_deletion(), 40.0)
	_expect(done and r.job.is_empty(), "the builder finished the site (%s)" % [r.job])
	var built: Node3D = null
	for n in get_nodes_in_group("craft_station"):
		if n != wb and str(n.get("station_id")) == "workbench":
			built = n
	_expect(built != null and built.station_level == 1, "a workbench stands, at the builder's level cap (Lv %d)" % (built.station_level if built else -1))
	_expect(float(r.skill_xp.get("construction", 0.0)) > xp0 or r.skill("construction") > 1, "the builder got Construction XP")
	_expect(player.skills.level_of("construction") == survivor_c, "the survivor's Construction is untouched")
	_sections += 1
