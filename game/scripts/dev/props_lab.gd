extends Node3D
## PROPS lab (windowed): builds the home island with its scenery layer, prints the prop counts and
## the camp budget numbers, clears one destroyable prop and saves shots.
## Windowed: --resolution 1600x900 --rendering-method gl_compatibility -- --lab=props_lab --shot-dir=DIR
## Prints:
##   [props] id=<climate> props=<n> colliding=<n> passable=<n> destroyable=<n> resources=<n> draws=<n> prims_visible=<n>
##   [props] clear kind=<k> tile=(x,y) ok=<bool> cleared_after=<n>
##   [props] cliff kind=<k> refused=<bool>
## and exits 0 (1 when the layer is empty or a shot failed).

var _player: Player
var _cam: IsoCamera
var _props: Node
var _out := ""
var _shots := 0

func _ready() -> void:
	_out = OS.get_user_data_dir().path_join("props-lab")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_out = a.substr(11)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.debug_overlay = false
	var kit := LabKit.build(self, 8.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 20.0
	_cam.distance = 30.0
	World.home_terrain = &"meadow"
	World.harvested.clear()
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	_cam._target = _player
	_cam._snap()
	# A windowed lab can hang on a slow GPU or a bad scene: quit instead of blocking the runner.
	get_tree().create_timer(120.0).timeout.connect(func () -> void:
		print("[props] FAIL watchdog 120s (shots=%d)" % _shots)
		get_tree().quit(2))
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(1.2).timeout
	var rt: IslandRuntime = World.runtime
	if rt == null:
		print("[props] FAIL no island")
		get_tree().quit(1)
		return
	_props = rt.get("props")
	if _props == null:
		print("[props] FAIL no props layer on the island")
		get_tree().quit(1)
		return
	await get_tree().create_timer(0.4).timeout
	var res := 0
	for n in get_tree().get_nodes_in_group("harvest"):
		if n is HarvestNode:
			res += 1
	var m := await _measure()
	# The plan's camp gate: visible primitives < 900k. Props and the denser scatter must not break it;
	# the batch table printed next says which batch is over its share.
	if int(m["visible"]) >= 900000:
		push_warning("[props] camp over budget: visible prims %d >= 900k" % int(m["visible"]))
	print("[props] id=%s props=%d colliding=%d passable=%d destroyable=%d resources=%d draws=%d prims_visible=%d prims_shadow=%d prims_total=%d" % [
		str(rt._climate), int(_props.call("prop_count")), int(_props.call("colliding_count")),
		int(_props.call("passable_count")), int(_props.call("destroyable_count")), res,
		int(m["draws"]), int(m["visible"]), int(m["shadow"]), int(m["visible"]) + int(m["shadow"])])
	_report_batches(rt)
	# Camp view: the survivor's own frame, where the plan's budget is measured.
	await _shot("camp")
	# A dense cluster: the nearest boulder or rock spire, with the survivor beside it.
	var row: Dictionary = _nearest_prop(["boulder", "cliff_rock", "fallen_log", "tree_stump", "mossy_stone"])
	if not row.is_empty():
		_stand(row["pos"] as Vector3, 6.0)
		await _shot("prop_close")
	# Top-down over the island centre: what the owner sees on the atlas.
	_stand(Vector3(0, 0, 0), 90.0)
	await _shot("top")
	# A cliff placed by hand must refuse to clear (the island may have none in reach).
	var cliff_at := _dry_near(Vector3(0, 0, 0), 12.0)
	_props.call("add_prop", "cliff_rock", cliff_at, 3.2)
	var cliff_row := _last_row("cliff_rock")
	if not cliff_row.is_empty():
		var refused := not bool(_props.call("clear_at_tile", cliff_row["tile"]))
		print("[props] cliff kind=cliff_rock refused=%s" % refused)
	# Clearing: one destroyable prop goes.
	var cleared: Dictionary = _nearest_prop(["boulder", "fallen_log", "tree_stump", "mossy_stone", "fern"])
	var before := int(_props.call("destroyable_count"))
	var ok := false
	if not cleared.is_empty():
		_stand(cleared["pos"] as Vector3, 5.0)
		ok = bool(_props.call("clear_at_tile", cleared["tile"]))
		print("[props] clear kind=%s tile=(%d,%d) ok=%s cleared_after=%d" % [
			str(cleared.get("kind", "")), (cleared["tile"] as Vector2i).x, (cleared["tile"] as Vector2i).y,
			ok, int(_props.get("cleared_count"))])
		await get_tree().create_timer(0.2).timeout
		await _shot("cleared")
	else:
		print("[props] clear kind=- tile=(0,0) ok=false cleared_after=%d" % before)
	print("[props] shots=%d dir=%s" % [_shots, _out])
	get_tree().quit(0 if _shots >= 3 else 1)

## Where the primitives go: one line per batch (instances x mesh triangles), then the total the camp
## frame has to carry. A batch over its share is the thing to fix, not the frame.
func _report_batches(rt: IslandRuntime) -> void:
	var total := 0
	var lines := 0
	for b in rt.get("_batches"):
		var batch: VegBatch = b
		var mesh: Mesh = batch.get("_mesh")
		var tris := 0
		if mesh != null:
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var idx: Variant = arr[Mesh.ARRAY_INDEX]
				tris += (idx as PackedInt32Array).size() / 3 if idx != null else 0
		var n := batch.instance_count()
		var cells := batch.get_child_count()
		if n > 0 and lines < 24:
			print("[props] batch %s instances=%d tris=%d cells=%d prims=%d" % [batch.name, n, tris, cells, n * tris])
			lines += 1
		total += n * tris
	print("[props] cover_batches_total_prims=%d" % total)

## Draws and primitives of the current frame, split the way the plan's gate measures them: the total
## with shadows on, then the same frame with the sun's shadows off (visible only). The difference is
## what the shadow pass costs. Both numbers are read after two frames so the renderer has settled.
func _measure() -> Dictionary:
	for i in 2:
		await get_tree().process_frame
	var sun := _sun()
	var had := sun != null and sun.shadow_enabled
	var total := 0
	var draws := 0
	if sun != null:
		sun.shadow_enabled = true
	await get_tree().process_frame
	await get_tree().process_frame
	draws = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	total = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if sun != null:
		sun.shadow_enabled = false
	await get_tree().process_frame
	await get_tree().process_frame
	var visible := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if sun != null:
		sun.shadow_enabled = had
	for i in 2:
		await get_tree().process_frame
	return {"draws": draws, "visible": visible, "shadow": maxi(0, total - visible)}

func _sun() -> DirectionalLight3D:
	var rt: IslandRuntime = World.runtime
	if rt != null and rt.sun != null:
		return rt.sun
	return get_viewport().get_camera_3d().get_parent().find_child("Sun", true, false) as DirectionalLight3D

## A dry, prop-free point `d`..`d+5` m from `from` in a spread of directions.
func _dry_near(from: Vector3, d: float) -> Vector3:
	var rt: IslandRuntime = World.runtime
	for i in 24:
		var ang := float(i) * TAU / 24.0
		var p := Vector3(from.x + cos(ang) * (d + float(i % 5)), 0.0, from.z + sin(ang) * (d + float(i % 5)))
		if rt == null or not rt.is_dry(p):
			continue
		var tile := BuildGrid.tile_of(p)
		if not (_props.call("prop_at_tile", tile) as Dictionary).is_empty():
			continue
		p.y = rt.surface_y(p.x, p.z)
		return p
	return Vector3(from.x + d, 0.0, from.z)

func _last_row(kind: String) -> Dictionary:
	var arr := _rows()
	for i in range(arr.size() - 1, -1, -1):
		if str(arr[i].get("kind", "")) == kind:
			return arr[i]
	return {}

func _rows() -> Array:
	var arr: Variant = _props.get("_rows")
	return arr as Array if arr is Array else []

func _nearest_prop(kinds: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1e9
	var p := _player.global_position
	for r in _rows():
		if not (str(r.get("kind", "")) in kinds):
			continue
		if bool(r.get("cleared", false)):
			continue
		var pos: Vector3 = r["pos"]
		var d := p.distance_to(pos)
		if d < best_d:
			best_d = d
			best = r
	return best

func _stand(at: Vector3, cam_size: float) -> void:
	var rt: IslandRuntime = World.runtime
	var y := rt.surface_y(at.x, at.z) + 1.0 if rt != null else 1.0
	_player.global_position = Vector3(at.x + 2.2, y, at.z + 2.2)
	var p := _player.global_position
	if rt != null:
		_player.global_position.y = rt.surface_y(p.x, p.z) + 1.0
	_cam.size = cam_size
	_cam._snap()

func _shot(tag: String) -> void:
	# process_frame only: awaiting RenderingServer.frame_post_draw hung the lab (watchdog, 0 shots) when
	# another run held the GPU and the frame callback never arrived.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("[props] shot %s failed" % tag)
		return
	var path := "%s/props_%s.png" % [_out, tag]
	img.save_png(path)
	_shots += 1
	var draws := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("[props] shot %s draws=%d prims_visible=%d" % [path, draws, prims])
