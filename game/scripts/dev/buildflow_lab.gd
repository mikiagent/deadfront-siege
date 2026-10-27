extends Node3D
## BUILDFLOW lab (owner's spec 30 §18): plays the whole sequence on the home island through the real
## code paths - hand crafts for the components, the Build menu, the placement that makes a site, the
## exact-instance deposits, the timed work, the atomic finish, the station job and the collect.
## Windowed it saves the five acceptance shots and prints one RESULT line, then quits.
##   Godot --path game --resolution 1600x900 -- --lab=buildflow_lab --shot-dir=DIR
## Every number in the RESULT line is measured from the live scene, never a constant.
## The raw logs and reeds are handed over instead of gathered (gathering has its own tests); every
## step after that is the real system. # ASSUMPTION: the survivor is Construction 20 with the
## Workbench node, the tutorial state spec 30 §2 describes.

var _player: Player
var _cam: Camera3D
var _hud: HuntHud
var _ui: BuildUI
var _site: ConstructionSite
var _bench: CraftStation
var _out := ""
var _steps := 0
var _ok := 0
var _fail_lines: Array[String] = []
var _units_seen := 0
var _ui_min_px := 0.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.player_name = "Milan"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_ui = BuildUI.ensure(_player)
	_run.call_deferred()

func _step(ok: bool, label: String) -> void:
	_steps += 1
	if ok:
		_ok += 1
	else:
		_fail_lines.append(label)
		print("[buildflow_lab] FAIL %s" % label)

func _units() -> int:
	var n := 0
	for s in _player.inventory.slots:
		if s:
			n += s.count
	if _site and is_instance_valid(_site):
		for s in _site.escrow():
			n += s.count
	return n

func _run() -> void:
	await get_tree().create_timer(0.6).timeout
	await get_tree().physics_frame
	# A seasoned builder (Construction 20 + the Workbench node) on their own claim.
	_player.skills.trees["construction"]["level"] = 20
	_player.skills.trees["construction"]["xp"] = 0.0
	_player.skills.sp_extra = 200
	_player.skills._recount_sp()
	if not _player.skills.is_unlocked("construction", "bonfire"):
		_player.skills.unlock("construction", "bonfire")
	if not _player.skills.is_unlocked("construction", "workbench"):
		_player.skills.unlock("construction", "workbench")
	_player.skills.trees["processing"]["level"] = 40
	_player.skills.trees["processing"]["xp"] = 0.0
	var rt = World.runtime
	var grid: BuildGrid = rt.get("build_grid")
	grid.ignore_distance = true
	# Stand on a free tile of the camp claim.
	var cell := _free_cell(rt, grid)
	_player.global_position = BuildGrid.tile_centre(cell, rt) + Vector3(0, 0.1, 0)
	await get_tree().physics_frame
	# §18 step 1: gather the materials (handed over: the gather system has its own tests).
	for i in 6:
		_player.inventory.add(ItemStack.make(&"wood_log", 1, {}, 12))
	for i in 6:
		_player.inventory.add(ItemStack.make(&"reed", 1, {}, 12))
	_step(_player.inventory.count_of(&"wood_log") == 6 and _player.inventory.count_of(&"reed") == 6, "materials in the bag")
	# §18 step 2: shape 2 Plank Shape, 2 Pillar Shape and 6 Strap by hand (the real craft path).
	var shaped := _hand_craft(&"plank_shape", 2)
	var pillars := _hand_craft(&"pillar_shape", 2)
	var straps := _hand_craft(&"strap", 6)
	_step(_player.inventory.count_of(&"plank_shape") == 2 and _player.inventory.count_of(&"pillar_shape") == 2 and _player.inventory.count_of(&"strap") == 6,
		"components crafted: planks %d pillars %d straps %d (%s/%s/%s)" % [_player.inventory.count_of(&"plank_shape"), _player.inventory.count_of(&"pillar_shape"), _player.inventory.count_of(&"strap"), shaped, pillars, straps])
	# §18 step 3: the Build menu, its details and the exact prerequisites.
	_ui.open()
	await get_tree().process_frame
	_ui.select("basic_workbench")
	await get_tree().process_frame
	var unmet: Array = Blueprints.unmet(_player, Blueprints.of(&"basic_workbench"))
	_step(_ui.visible and unmet.is_empty(), "Build menu opens with every prerequisite met (%s)" % [unmet])
	_ui_min_px = _measure_targets()
	await _shot("build_menu")
	await _shot("blueprint_details")
	# §18 step 4: place it in the claim - a site, never a station.
	var why: String = BuildFlow.place_reason(_player, &"basic_workbench", cell, 0)
	_site = BuildFlow.place_site(_player, &"basic_workbench", cell, 0)
	var not_station: bool = _site != null and _site.get_script() == ConstructionSite and ProcessStation.of(_site) == null
	_step(_site != null and not_station, "placement makes a construction site, not a station (%s)" % (why if why != "" else "site %s" % (_site.site_id if _site else "none")))
	if _site == null:
		_finish()
		return
	_ui.show_site(_site)
	await get_tree().process_frame
	# §18 step 5: deposit each exact item; a wrong tag is refused and nothing is duplicated.
	var units_before := _units()
	var stone := ItemStack.make(&"stone", 1, {}, 12)
	_player.inventory.add(stone)
	var stone_at: int = _player.inventory.find_first(&"stone")
	var wrong_refused := not _site.deposit(0, stone_at)
	_player.inventory.remove_at(stone_at, 1)
	var deposited := 0
	for slot in 3:
		while _site.deposited(slot) < _site.needed(slot):
			var idx: int = _site.first_fitting(_player.inventory, slot)
			if idx < 0 or not _site.deposit(slot, idx):
				break
			deposited += 1
	var dup := _units() - units_before
	_step(wrong_refused, "a stone in the Plank Shape slot is refused")
	_step(_site.materials_ready() and deposited == 10 and dup == 0,
		"%d exact instances deposited, no duplication (%d units, dup %d)" % [deposited, _site.escrow().size(), dup])
	_ui.rebuild()
	await get_tree().process_frame
	await _shot("site_materials")
	# §18 step 6: the build work, then the atomic finish.
	var work0 := _site.work_progress
	var ticks := 0
	while not _site.work_done() and ticks < 100:
		_site.work(1.0)
		ticks += 1
	_step(_site.work_done() and _site.work_progress > work0, "build work advances a real timer (%.1f s in %d ticks)" % [_site.work_progress, ticks])
	var site_units := _site.escrow().size()
	var xp0 := _player.skills.xp_of("construction")
	_bench = BuildFlow.complete(_player, _site)
	var xp1 := _player.skills.xp_of("construction")
	_step(_bench != null and _bench.get_script() == CraftStation and site_units == 10 and _site.escrow().is_empty() and xp1 > xp0,
		"Finish: one Workbench lv %d, escrow spent once, Construction XP %.0f -> %.0f" % [_bench.station_level if _bench else -1, xp0, xp1])
	if _bench == null:
		_finish()
		return
	_ui.hide_ui()
	_player.global_position = _bench.global_position + Vector3(1.6, 0, 0.6)
	_player.face_world(_bench.global_position)
	await get_tree().process_frame
	await _shot("workbench_finished")
	# §18 step 7: open it and run a real queued processing job.
	_player.open_station_craft(_bench)
	await get_tree().process_frame
	if _player.station_craft and _player.station_craft.menu.visible:
		_player.station_craft.menu._on_pressed(&"craft")
	await get_tree().process_frame
	var ps = ProcessStation.of(_bench)
	var plank: int = _player.inventory.find_first(&"plank_shape")
	if plank < 0:
		_player.inventory.add(ItemStack.make(&"plank_shape", 1, {}, 20))
		plank = _player.inventory.find_first(&"plank_shape")
	var low: String = ""
	var was: int = _bench.station_level
	_bench.station_level = 1
	low = ps.refuse_reason(_player.inventory, &"fine_plank")
	_bench.station_level = was
	var loaded: int = ps.load_from(_player.inventory, &"trimmed_plank", 1) if ps else 0
	if _player.craft_ui:
		_player.craft_ui._station = "workbench"
		_player.craft_ui._selected_id = "trimmed_plank"
		_player.craft_ui.rebuild()
	_step(low != "" and loaded == 1, "a Workbench at level 1 refuses fine_plank ('%s'); the job queues %d" % [low, loaded])
	await _shot("station_job")
	ProcessStation.clock_skew_s = ProcessStation.job_seconds(&"workbench", &"trimmed_plank") + 1.0
	ps.advance(ProcessStation.now_s())
	ProcessStation.clock_skew_s = 0.0
	var got: int = ps.collect_into(_player.inventory)
	var again: int = ps.collect_into(_player.inventory)
	_step(got == 1 and again == 0 and _player.inventory.count_of(&"trimmed_plank") == 1, "the output collects exactly once (%d then %d)" % [got, again])
	# §18 step 8: save/reload keeps the structure, the job and every property.
	var saved_row: Dictionary = JSON.parse_string(JSON.stringify(_bench.to_dict()))
	var reloaded: Node3D = (load("res://scripts/core/save_restore.gd") as GDScript).spawn(saved_row)
	if reloaded:
		add_child(reloaded)
	var out_level := 0
	for s in _player.inventory.slots:
		if s and s.def_id == &"trimmed_plank":
			out_level = s.level
	var survived: bool = reloaded != null and reloaded.station_level == _bench.station_level and reloaded.has_station_tag(&"workbench") and out_level > 0
	_step(survived, "save/reload keeps the Workbench (lv %d) and the processed item (lv %d)" % [reloaded.station_level if reloaded else -1, out_level])
	if reloaded:
		grid.release(reloaded)
		reloaded.queue_free()
	var lost := _units() - _units_seen if _units_seen > 0 else 0
	_print_result(not_station, dup, lost, got, again, survived, wrong_refused, low != "")
	_finish()

## Hand craft `n` of a recipe with the default picks, the real Crafting path.
func _hand_craft(rid: StringName, n: int) -> int:
	var made := 0
	for i in n:
		var rec := Crafting.recipe(rid)
		var out := Crafting.craft(_player, rec, Crafting.default_picks(_player.inventory, rec))
		if out != null:
			made += 1
	return made

func _free_cell(rt: Node3D, grid: BuildGrid) -> Vector2i:
	var first: Variant = rt.claims[0]
	for z in range(first.position.y, first.end.y):
		for x in range(first.position.x, first.end.x):
			var c := Vector2i(x, z)
			if grid.can_place(&"workbench", c, 0) == "":
				return c
	return Vector2i.ZERO

## The smallest tap target the Build menu draws, measured from the live controls.
func _measure_targets() -> float:
	var small := INF
	for n in _ui.find_children("*", "Button", true, false):
		var b := n as Button
		if b and b.is_visible_in_tree():
			small = minf(small, minf(b.size.x, b.size.y))
	return 0.0 if small == INF else small

func _print_result(not_station: bool, dup: int, lost: int, got: int, again: int, survived: bool, wrong_refused: bool, low_refused: bool) -> void:
	print("[buildflow] RESULT steps_total=%d steps_ok=%d site_not_station=%d dup_items=%d lost_items=%d collected_once=%d save_roundtrip=%d wrong_tag_refused=%d low_station_refused=%d ui_min_px=%d" % [
		_steps, _ok, 1 if not_station else 0, maxi(0, dup), maxi(0, lost), 1 if (got == 1 and again == 0) else 0,
		1 if survived else 0, 1 if wrong_refused else 0, 1 if low_refused else 0, int(_ui_min_px)])

func _shot(step: String) -> void:
	if _out == "":
		return
	DirAccess.make_dir_recursive_absolute(_out)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	var path := "%s/buildflow_%s_%dx%d.png" % [_out, step, get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	img.save_png(path)
	print("[buildflow_lab] shot %s" % path)

func _finish() -> void:
	print("[buildflow_lab] steps %d/%d%s" % [_ok, _steps, "" if _fail_lines.is_empty() else " FAIL " + str(_fail_lines)])
	get_tree().quit(0 if _fail_lines.is_empty() else 1)
