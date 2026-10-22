extends Node3D
## CLAIMS2 shot lab (spec 29 Phase A+B): boots the home island with the real HUD, opens Main Menu ->
## Domain, declares a domain through the screen's own Declare + ground preview, expands it to the cap
## by repeating Expand, tries one cell past the cap and one non-adjacent cell (both refused, each with
## its reason), places a building footprint half across the border (refused), measures the grass on
## claimed land, migrates a legacy save with a building, and round-trips the record through the
## sanitizer. Every number in the RESULT line is measured from the live scene.
## Saves <shot-dir>/claims2_<step>_<w>x<h>.png.
## Windowed: --resolution 1600x900 -- --lab=claims2_lab --shot-dir=DIR [--rendering-method gl_compatibility]

const ME := "Milan"

var _out := ""
var _player: Player
var _hud: HuntHud
var _rt: IslandRuntime
var _screen: DomainScreen
var _shot := 0
var _logs: Array[String] = []

var cell_tiles := 0
var cap := 0
var claimed := 0
var refused_at_cap := 0
var non_contiguous_refused := 0
var eligible_shown := 0
var invalid_shown := 0
var tabs := 0
var grass_in_claim := 0
var other_nodes_kept := 0
var footprint_cross_refused := 0
var legacy_buildings_inside := 0
var save_roundtrip := 0
var ui_min_px := 0.0

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("claims2")
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
	World.player_name = ME
	World.home_terrain = &"meadow"
	World.home_claims = []
	World.home_domain = {}
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()  # the lab floor would poke through the island
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	_rt = World.runtime
	if _rt == null or _hud == null:
		_finish("no island or HUD")
		return
	cell_tiles = DomainRules.cell_tiles()
	# ---- Main Menu -> Domain, through the HUD's own menu sheet.
	_hud.call("_toggle_sheet", &"menu")
	await get_tree().process_frame
	await get_tree().process_frame
	var hit_menu := false
	var rows: Variant = _hud.get("_sheet_rows")
	if rows is ScrollContainer:
		for c in (rows as ScrollContainer).get_children():
			for b in c.get_children():
				if b is Button and str((b as Button).text) == "Domain":
					hit_menu = true
					(b as Button).pressed.emit()
					break
	if not hit_menu:
		_hud.call("_open_domain")
	await get_tree().create_timer(0.4).timeout
	_screen = _hud.call("domain_screen")
	_logs.append("menu->domain=%s open=%s" % [hit_menu, _screen != null and _screen.is_open()])
	tabs = (_screen.get("_tab_buttons") as Dictionary).size()
	# The survivor stands in the middle of the window the preview will show.
	var camp_cell: Vector2i = IslandClaims.cell_of(_rt, BuildGrid.tile_of(_rt._camp_pos))
	_player.global_position = BuildGrid.tile_centre(IslandClaims.cell_rect(_rt, camp_cell).get_center(), _rt) + Vector3(0, 1, 0)
	await get_tree().physics_frame
	await get_tree().create_timer(0.4).timeout
	await _shot_now("01_domain_screen")
	# ---- Declare, through the screen: its Declare button opens the ground preview.
	cap = int(_rt.call("claim_cap"))
	var first: Array = IslandClaims.eligible_cells(_rt)
	first.sort_custom(func (a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(camp_cell) < b.distance_squared_to(camp_cell))
	_press("Declare")
	await get_tree().create_timer(0.5).timeout
	var pv: DomainPreview = _screen.preview
	if pv == null:
		_finish("Declare opened no preview")
		return
	# A bush planted in a cell the domain is about to take: it must survive the claim.
	var take: Array = []
	for c: Vector2i in first:
		if pv.info.has(c) and str((pv.info[c] as Dictionary)["state"]) == "eligible":
			take.append(c)
		if take.size() == 3:
			break
	if take.is_empty():
		_finish("no eligible cell in the Declare window")
		return
	var bush_cell: Vector2i = take[take.size() - 1]
	var bush_at: Vector3 = BuildGrid.tile_centre(IslandClaims.cell_rect(_rt, bush_cell).get_center(), _rt)
	var bush: int = IslandScatter.plant_at(_rt, "Bush", "bush", bush_at, &"branch", &"hand", "temperate", 1, Color(0.35, 0.5, 0.25))
	for c: Vector2i in take:
		pv.pick(c)
	await get_tree().process_frame
	var counts: Dictionary = pv.counts()
	eligible_shown = int(counts["eligible"])
	invalid_shown = int(counts["invalid"])
	_player.global_position = BuildGrid.tile_centre(IslandClaims.cell_rect(_rt, take[0]).get_center(), _rt) + Vector3(0, 1, 0)
	await get_tree().physics_frame
	await get_tree().create_timer(0.4).timeout
	await _shot_now("02_preview")
	_press("Confirm")
	await get_tree().create_timer(0.5).timeout
	# ---- A cell on good land that shares no edge with the domain: refused for adjacency (asked
	# before the cap fills, or the cap's refusal would mask it).
	var held: Dictionary = IslandClaims.occupied_cells(_rt)
	var far := IslandClaims.NO_CELL
	var camp_tile: Vector2i = BuildGrid.tile_of(_rt._camp_pos)
	for r in range(3, 25):
		for y in range(camp_cell.y - r, camp_cell.y + r + 1):
			for x in range(camp_cell.x - r, camp_cell.x + r + 1):
				var c := Vector2i(x, y)
				if IC_block_ok(c) and not held.has(c) and not IslandClaims.adjacent_to(c, held):
					far = c
					break
			if far != IslandClaims.NO_CELL:
				break
		if far != IslandClaims.NO_CELL:
			break
	if far != IslandClaims.NO_CELL:
		var out2: Dictionary = _rt.call("claim_domain", [far])
		non_contiguous_refused = 1 if str(out2["reason"]) == "not_adjacent" else 0
		_logs.append("non-adjacent %s: reason=%s" % [far, out2["reason"]])
	# ---- Expand to the cap, one Expand press per cell (the screen's own button each time).
	var guard := 0
	while int(_rt.call("claim_used")) < cap and guard < 40:
		guard += 1
		if _screen.preview == null:
			_press("Expand")
			await get_tree().create_timer(0.25).timeout
		var p: DomainPreview = _screen.preview
		if p == null:
			break
		var pick_one := false
		for c: Vector2i in p.info.keys():
			if str((p.info[c] as Dictionary)["state"]) == "eligible":
				p.pick(c)
				pick_one = true
				break
		if not pick_one:
			_press("Cancel")
			await get_tree().create_timer(0.2).timeout
			break
		_press("Confirm")
		await get_tree().create_timer(0.2).timeout
	claimed = int(_rt.call("claim_used"))
	# The full domain, framed on the survivor.
	var own := Rect2i()
	for r in _rt.claims:
		own = r if not own.has_area() else own.merge(r)
	_player.global_position = BuildGrid.tile_centre(own.get_center(), _rt) + Vector3(0, 1, 0)
	await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout
	await _shot_now("03_domain_full")
	# ---- One more cell at the cap: refused, and the screen says why.
	var spare: Array = _rt.call("claim_eligible_cells")
	if not spare.is_empty():
		var out: Dictionary = _rt.call("claim_domain", [spare[0]])
		refused_at_cap = 1 if str(out["reason"]) == "cap" else 0
		_logs.append("at cap: reason=%s" % out["reason"])
	if _screen.preview == null:
		_press("Expand")
		await get_tree().create_timer(0.4).timeout
	if _screen.preview != null:
		for c: Vector2i in _screen.preview.info.keys():
			if str((_screen.preview.info[c] as Dictionary)["state"]) == "eligible":
				_screen.preview.pick(c)
				break
		await get_tree().process_frame
		_press("Confirm")
		await get_tree().create_timer(0.3).timeout
		_logs.append("screen note: %s" % str(_screen.get("_note").text))
		if _screen.preview != null:
			_press("Cancel")
			await get_tree().create_timer(0.2).timeout
	# ---- A building footprint half across the border: the whole footprint must be owned.
	var border := IslandClaims.NO_CELL
	for r: Rect2i in _rt.claims:
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var t: Vector2i = r.get_center() + d * (r.size.x / 2)
			t = Vector2i(t.x + d.x * (r.size.x / 2 - 1), t.y + d.y * (r.size.y / 2 - 1))
			var cells: Array = _rt.build_grid.cells_for(&"workbench", t, 0)
			var inside := 0
			for k in cells:
				inside += 1 if _rt.is_claimed(k) else 0
			if inside < cells.size() and _rt.spawn_ok(BuildGrid.tile_centre(t, _rt), false):
				border = t
				break
		if border != IslandClaims.NO_CELL:
			break
	if border != IslandClaims.NO_CELL:
		_player.global_position = BuildGrid.tile_centre(border, _rt) + Vector3(0, 1, 0)
		await get_tree().physics_frame
		var why: String = _rt.build_grid.can_place(&"workbench", border, 0)
		footprint_cross_refused = 1 if why == "unclaimed" else 0
		_logs.append("footprint straddle at %s: %s" % [border, why])
	# ---- Grass: nothing of it stands on the claimed land, the bush does.
	grass_in_claim = IslandClaims.grass_in(_rt, _rt.claims)
	other_nodes_kept = 1 if bush == 1 and _node_alive_at(bush_at, "Bush") else 0
	_logs.append("grass_in_claim=%d bush_alive=%d" % [grass_in_claim, other_nodes_kept])
	await get_tree().create_timer(0.3).timeout
	await _shot_now("04_claimed_no_grass")
	# ---- The record survives the sanitizer and an island reload.
	var record: Dictionary = IslandClaims.to_save(_rt)
	var cells_before: Array = (IslandClaims.owned_cells(_rt).keys() as Array).duplicate()
	var json := JSON.stringify({"home": {"domain": record}, "away": {}})
	var back: Variant = JSON.parse_string(json)
	var cleaned: Dictionary = SaveSanitizer.clean(back if back is Dictionary else {})
	World.home_domain = (cleaned["home"] as Dictionary).get("domain", {})
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	await get_tree().process_frame
	_rt = World.runtime
	var after: Array = (IslandClaims.owned_cells(_rt).keys() as Array).duplicate()
	save_roundtrip = 1 if after.size() == cells_before.size() and after.has(cells_before[0]) else 0
	# ---- A legacy save (14x14 camp plot + one staked plot + a building on its own cell) migrates
	# with every placed building inside the domain.
	var cp := Rect2i(camp_tile - Vector2i(7, 7), Vector2i(14, 14))
	var plot := Rect2i(cp.end.x + 20, cp.position.y, 14, 14)
	var bcell := plot.end + Vector2i(6, 0)
	World.home_claims = [[cp.position.x, cp.position.y, 14, 14], [plot.position.x, plot.position.y, 14, 14]]
	World.home_domain = {}
	World._home_buildings_cache = [{"kind": "basket", "cell": [bcell.x, bcell.y], "rot": 0}]
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	await get_tree().process_frame
	_rt = World.runtime
	var owned: Dictionary = IslandClaims.owned_cells(_rt)
	legacy_buildings_inside = 1 if owned.has(IslandClaims.cell_of(_rt, bcell)) else 0
	_logs.append("legacy: %d cells, building cell %s inside=%d" % [owned.size(), IslandClaims.cell_of(_rt, bcell), legacy_buildings_inside])
	# ---- Tap targets, measured on the screen as laid out for this canvas.
	if _screen != null:
		ui_min_px = float(_screen.min_target_px())
	if _screen != null and not _screen.is_open():
		_screen.open(_player)
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	await _shot_now("05_after_migration")
	_finish("")

## A cell with no terrain/ownership refusal (the classifier's own rule outside adjacency).
func IC_block_ok(c: Vector2i) -> bool:
	return IslandClaims.cell_block_reason(_rt, c) == ""

func _node_alive_at(at: Vector3, family: String) -> bool:
	for node in _rt._harvest_nodes.values():
		if is_instance_valid(node) and str(node.get("family")) == family and (node as Node3D).global_position.distance_to(at) < 0.5:
			return true
	return false

func _press(node_name: String) -> void:
	if _screen == null:
		return
	var b: Variant = _screen.find_child(node_name, true, false)
	if b is Button and (b as Button).visible and not (b as Button).disabled:
		(b as Button).pressed.emit()

func _shot_now(step: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var vp := get_viewport().get_visible_rect().size
	var path := _out.path_join("claims2_%s_%dx%d.png" % [step, int(vp.x), int(vp.y)])
	get_viewport().get_texture().get_image().save_png(path)
	_shot += 1
	print("[claims2lab] saved %s" % path)

func _finish(err: String) -> void:
	for l in _logs:
		print("[claims2lab] %s" % l)
	if err != "":
		print("[claims2lab] FAIL %s" % err)
	print("[claims2] RESULT cell_tiles=%d cap=%d claimed=%d refused_at_cap=%d non_contiguous_refused=%d eligible_shown=%d invalid_shown=%d tabs=%d grass_in_claim=%d other_nodes_kept=%d footprint_cross_refused=%d legacy_buildings_inside=%d save_roundtrip=%d ui_min_px=%d shots=%d" % [
		cell_tiles, cap, claimed, refused_at_cap, non_contiguous_refused, eligible_shown, invalid_shown, tabs,
		grass_in_claim, other_nodes_kept, footprint_cross_refused, legacy_buildings_inside, save_roundtrip,
		int(round(ui_min_px)), _shot])
	get_tree().quit(0 if err == "" else 1)
