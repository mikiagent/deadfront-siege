extends Node3D
## DOMAIN-D lab (owner's spec 29 sections 4 and 10): the Personal Communications Center built on the
## home Tamed Island through the real BUILDFLOW path, then its contribution track walked through its
## own UI - the Domain screen shows 13 plots at Pioneer rank 1, the center panel takes the rank-2
## contributions one exact instance at a time, Complete raises the rank 1 -> 2 and the cap 13 -> 17,
## no cell is claimed by the upgrade, and the record survives a real save/load.
## Windowed: Godot --path game --resolution 1600x900 -- --lab=domaind_lab --shot-dir=DIR
## Every number in the RESULT line is measured from the live scene, never a constant.

var _out := ""
var _player: Player
var _hud: HuntHud
var _rt: IslandRuntime
var _screen: DomainScreen
var _ui: CommCenterUI
var _site: ConstructionSite
var _station: CraftStation
var _shot := 0
var _logs: Array[String] = []

var center_built := 0
var rank_before := 0
var rank_after := 0
var cap_before := 0
var cap_after := 0
var contrib_consumed_once := 0
var no_auto_cells := 0
var save_roundtrip := 0
var ui_min_px := 0.0

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("domaind")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c is HuntHud:
			_hud = c
	World.player_name = "Milan"
	World.home_terrain = &"meadow"
	World.home_claims = []
	World.home_domain = {}
	World.home_comm_center = {}
	World.pioneer_level = 0
	World.pioneer_xp = 0
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	_rt = World.runtime
	if _rt == null or _hud == null:
		_finish("no island or HUD")
		return
	var grid: BuildGrid = _rt.get("build_grid")
	grid.ignore_distance = true
	_learn_workbench()
	rank_before = DomainRules.pioneer_rank()
	cap_before = int(_rt.call("claim_cap"))
	# ---- Main Menu -> Domain, through the HUD's own menu (the capacity line is the acceptance).
	_hud.call("_toggle_sheet", &"menu")
	await get_tree().process_frame
	await get_tree().process_frame
	var rows: Variant = _hud.get("_sheet_rows")
	if rows is ScrollContainer:
		for c in (rows as ScrollContainer).get_children():
			for b in c.get_children():
				if b is Button and str((b as Button).text) == "Domain":
					(b as Button).pressed.emit()
					break
	await get_tree().create_timer(0.4).timeout
	_screen = _hud.call("domain_screen")
	if _screen == null or not _screen.is_open():
		_hud.call("_open_domain")
		_screen = _hud.call("domain_screen")
	await get_tree().create_timer(0.3).timeout
	_logs.append("domain screen open=%s stats=%s" % [_screen != null and _screen.is_open(), str(_screen.get("_stats").text) if _screen else ""])
	await _shot_now("01_domain_before")
	# ---- The center, built through BUILDFLOW on the camp land.
	var cell := _free_cell(grid)
	if cell == Vector2i(1 << 30, 0):
		_finish("no free claimed cell for the center")
		return
	_player.global_position = BuildGrid.tile_centre(cell, _rt) + Vector3(0, 0.1, 0)
	await get_tree().physics_frame
	_give(&"plank_shape", 2)
	_give(&"strap", 4)
	_give(&"stone", 6)
	_site = BuildFlow.place_site(_player, CommCenter.KIND, cell, 0)
	if _site == null:
		_finish("the center's site could not be placed at %s" % cell)
		return
	for i in 2:
		_site.deposit(0, _player.inventory.find_first(&"plank_shape"))
	for i in 4:
		_site.deposit(1, _player.inventory.find_first(&"strap"))
	for i in 6:
		_site.deposit(2, _player.inventory.find_first(&"stone"))
	_site.work(float(_site.bp().get("work_seconds", 20.0)))
	var site_id: String = _site.site_id
	_station = BuildFlow.complete(_player, _site)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	center_built = 1 if _station != null and CommCenter.built(_rt) else 0
	CommCenter.label_station(_rt)  # the world names the center (it shares the workbench grid kind)
	_logs.append("center: site=%s station=%s tags=%s built=%d" % [site_id, str(_station.get("kind")) if _station else "none", str(_station.get("station_tags")) if _station else "[]", center_built])
	await _shot_now("02_center_built")
	# ---- The Domain screen's CENTER button opens the contribution panel.
	_press(_screen, "Center")
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_ui = _screen.center_ui
	if _ui == null or not _ui.is_open():
		_finish("the Domain screen's Center button opened no contribution panel")
		return
	# The contributions the rank-2 step asks for, in the bag, as exact instances.
	_give(&"plank_shape", 2)
	_give(&"stone", 8)
	_ui._refresh()
	_ui._layout()
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	ui_min_px = _ui.min_target_px()
	_logs.append("panel: rank line \"%s\", buttons min %.0f px" % [_ui.get("_rank_line").text, ui_min_px])
	await _shot_now("03_contributions")
	var target := int(CommCenter.target_rank())
	var want_planks := CommCenter.needed(target, 0)
	var want_stone := CommCenter.needed(target, 1)
	for i in want_planks:
		_press(_ui, "Give_0")
		await get_tree().process_frame
	for i in want_stone:
		_press(_ui, "Give_1")
		await get_tree().process_frame
	_ui._refresh()
	_ui._layout()
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	_logs.append("contributed: %s ready=%s" % [str(CommCenter.slot_counts(target)), CommCenter.ready(target)])
	await _shot_now("04_ready")
	# ---- Complete, through the panel's own button.
	var used_before: int = IslandClaims.used(_rt)
	var cells_before: Array = (IslandClaims.owned_cells(_rt).keys() as Array).duplicate()
	var claims_before: int = _rt.claims.size()
	var bag_stone := _player.inventory.count_of(&"stone")
	_press(_ui, "Complete")
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	rank_after = DomainRules.pioneer_rank()
	cap_after = int(_rt.call("claim_cap"))
	var cells_after: Array = (IslandClaims.owned_cells(_rt).keys() as Array).duplicate()
	no_auto_cells = 1 if used_before == IslandClaims.used(_rt) and cells_before == cells_after and claims_before == _rt.claims.size() else 0
	# Consumed exactly once: the step's held rows are empty, the bag lost exactly its units, and a
	# second Complete spends nothing and cannot raise the rank again.
	var held := CommCenter.slot_counts(target)
	var spent := want_planks + want_stone
	var twice: Dictionary = CommCenter.complete(_rt, target)
	contrib_consumed_once = 1 if held.all(func (n: int) -> bool: return n == 0) and bag_stone == 0 and _player.inventory.count_of(&"plank_shape") == 0 \
		and not bool(twice["ok"]) and int(twice["consumed"]) == 0 and DomainRules.pioneer_rank() == rank_after else 0
	_logs.append("upgrade: rank %d -> %d, cap %d -> %d, cells %d -> %d, spent %d, held now %s" % [rank_before, rank_after, cap_before, cap_after, used_before, IslandClaims.used(_rt), spent, str(held)])
	await _shot_now("05_after_upgrade")
	# ---- The Domain screen behind the panel follows the rank while it stays open (its own _process
	# refresh, not an explicit call), then Close reveals the capacity line itself.
	var stats_live: String = str(_screen.get("_stats").text)
	await get_tree().create_timer(0.3).timeout
	stats_live = str(_screen.get("_stats").text)
	_logs.append("domain screen after (panel open): %s" % stats_live)
	_press(_ui, "Close")
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_logs.append("domain screen after (panel closed): %s visible=%s" % [str(_screen.get("_stats").text), _screen.is_open()])
	await _shot_now("06_domain_after")
	# ---- Save round trip through the real save file.
	save_roundtrip = 0
	if SaveGame.save_now():
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.path))
		var home: Variant = (saved as Dictionary).get("home", {}) if saved is Dictionary else {}
		var row: Variant = (home as Dictionary).get("comm_center", {}) if home is Dictionary else {}
		var rank_was := DomainRules.pioneer_rank()
		var held_was := CommCenter.deposited(6, 0) + CommCenter.deposited(6, 2)
		World.home_comm_center = {}
		CommCenter.from_save(row)
		save_roundtrip = 1 if not (row as Variant is Dictionary and (row as Dictionary).is_empty()) \
			and DomainRules.pioneer_rank() == rank_was and int(DomainRules.cap()) == cap_after \
			and CommCenter.deposited(6, 0) + CommCenter.deposited(6, 2) == held_was else 0
		_logs.append("save: row=%s rank=%d cap=%d" % [str(row), DomainRules.pioneer_rank(), int(DomainRules.cap())])
	else:
		_logs.append("save: save_now refused")
	_finish("")

func _learn_workbench() -> void:
	var sk: Node = _player.skills
	sk.trees["construction"]["level"] = 20
	sk.trees["construction"]["xp"] = 0.0
	sk.sp_extra = 200
	sk._recount_sp()
	if not sk.is_unlocked("construction", "bonfire"):
		sk.unlock("construction", "bonfire")
	if not sk.is_unlocked("construction", "workbench"):
		sk.unlock("construction", "workbench")

func _give(id: StringName, n: int) -> void:
	for i in n:
		_player.inventory.add(ItemStack.make(id, 1, {}, 12))

## A free claimed cell the center's 2x1 footprint fits on.
func _free_cell(grid: BuildGrid) -> Vector2i:
	var first: Rect2i = _rt.claims[0]
	for z in range(first.position.y, first.end.y):
		for x in range(first.position.x, first.end.x):
			var c := Vector2i(x, z)
			if grid.can_place(CommCenter.grid_kind(), c, 0) == "":
				return c
	return Vector2i(1 << 30, 0)

func _press(host: Node, node_name: String) -> void:
	if host == null:
		return
	var b: Variant = host.find_child(node_name, true, false)
	if b is Button and (b as Button).visible and not (b as Button).disabled:
		(b as Button).pressed.emit()
		return
	print("[domaind_lab] button %s not pressable (%s)" % [node_name, "missing" if b == null else "disabled=%s" % (b as Button).disabled])

func _shot_now(step: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var vp := get_viewport().get_visible_rect().size
	var path := _out.path_join("domaind_%s_%dx%d.png" % [step, int(vp.x), int(vp.y)])
	get_viewport().get_texture().get_image().save_png(path)
	_shot += 1
	print("[domaind_lab] saved %s" % path)

func _finish(err: String) -> void:
	if err != "":
		_logs.append("ERROR %s" % err)
	for l in _logs:
		print("[domaind_lab] %s" % l)
	print("[domaind] RESULT center_built=%d rank_before=%d rank_after=%d cap_before=%d cap_after=%d contrib_consumed_once=%d no_auto_cells=%d save_roundtrip=%d ui_min_px=%d shots=%d" % [
		center_built, rank_before, rank_after, cap_before, cap_after, contrib_consumed_once, no_auto_cells, save_roundtrip, int(ui_min_px), _shot])
	get_tree().quit(0 if err == "" else 1)
