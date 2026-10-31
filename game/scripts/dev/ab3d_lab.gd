extends Node3D
## 3D A/B (owner 2026-10-30: "keep pushing to full 3D"): the same island views drawn the way the game
## draws them today and the way a 3D pass would, with the render cost read live. Run it once per
## variant and compare the shots and RESULT lines:
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- \
##     --lab=ab3d_lab --shot-dir=DIR --tag=cards                   (today)
##     ... --models --tag=models                                   (3D resources + 3D scenery)
##     ... --models --cam-fov=30 --cam-pitch=-45 --tag=models_wide (3D, wider lens)
## --only=<substring> runs only the matching views.
## Saves DIR/ab3d_<tag>_<view>.png and prints one line per view:
##   [ab3d] RESULT tag= view= draw_calls= primitives= objects= vram_mb= ms_median= ms_p95=
## Frame times come from whatever GPU runs it: compare variants on one machine, never across machines.

const WARMUP := 10
const FRAMES := 40
## [view, island, zoom (m of view height), where]: "camp", "trees" (the densest stand of tree and palm nodes)
## or "rocks" (the nearest outcrop, cliff or boulder to the camp).
const VIEWS := [
	["jungle_camp", &"tropical_25", 14.0, "camp"],
	["jungle_trees", &"tropical_25", 18.0, "trees"],
	["jungle_rocks", &"tropical_25", 18.0, "rocks"],
	["home_trees", &"home_grassland", 18.0, "trees"],
]

var _player: Player
var _cam: IsoCamera
var _shot_dir := "."
var _tag := "cards"
var _only := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			_shot_dir = a.substr(11)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var kit := LabKit.build(self, 24.0)
	_player = kit["player"]
	_cam = kit["cam"]
	Game.debug_overlay = false
	TouchControls.visible = false
	TouchControls.enabled = false
	(kit["ui"] as CanvasLayer).visible = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("[boot] lab=ab3d_lab tag=%s fov=%.1f pitch=%.1f models=%s" % [_tag, IsoCamera.fov_deg, IsoCamera.pitch_deg(), IslandProps.models_3d])
	get_tree().create_timer(600.0).timeout.connect(func () -> void:
		print("[ab3d] FAIL watchdog")
		get_tree().quit(2))
	_run.call_deferred()

func _run() -> void:
	var loaded := &""
	for v: Array in VIEWS:
		if _only != "" and not str(v[0]).contains(_only):
			continue
		if v[1] != loaded:
			World.load_island(self, v[1], Vector3(0, 1, 18), false)
			loaded = v[1]
			for i in 5:
				await get_tree().process_frame
		var rt: IslandRuntime = World.runtime
		if rt == null:
			print("[ab3d] FAIL no island %s" % str(v[1]))
			continue
		var at := _spot(rt, str(v[3]))
		_player.global_position = Vector3(at.x + 2.4, rt.surface_y(at.x + 2.4, at.z + 2.4) + 1.0, at.z + 2.4)
		_cam.size = float(v[2])
		_cam._snap()
		await _measure(str(v[0]))
	print("[ab3d] DONE")
	get_tree().quit(0)

func _spot(rt: IslandRuntime, where: String) -> Vector3:
	var camp := rt._camp_pos
	if where == "trees":
		var pts: Array[Vector3] = []
		for n in get_tree().get_nodes_in_group("harvest"):
			if n is HarvestNode and ((n as HarvestNode).family.contains("Tree") or (n as HarvestNode).family.contains("Palm")):
				pts.append((n as Node3D).global_position)
		var best := camp
		var best_n := -1
		for i in range(0, pts.size(), maxi(1, pts.size() / 400)):
			var c := 0
			for q in pts:
				if q.distance_squared_to(pts[i]) < 144.0:
					c += 1
			if c > best_n:
				best_n = c
				best = pts[i]
		return best
	if where == "rocks":
		var props: Node = rt.get("props")
		var best := camp
		var best_d := 1e12
		for r in (props.get("_rows") if props else []):
			var row := r as Dictionary
			if str(row.get("kind", "")) in ["cliff_rock", "rock_spire", "mesa_cliff", "boulder", "basalt_column", "stone_arch"]:
				var d := (row["pos"] as Vector3).distance_squared_to(camp)
				if d < best_d:
					best_d = d
					best = row["pos"]
		return best
	return camp

func _measure(view: String) -> void:
	for i in WARMUP:
		await get_tree().process_frame
	var ms: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		ms.append(float(now - last) / 1000.0)
		last = now
	ms.sort()
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/ab3d_%s_%s.png" % [_shot_dir, _tag, view])
	print("[ab3d] RESULT tag=%s view=%s draw_calls=%d primitives=%d objects=%d vram_mb=%.1f ms_median=%.2f ms_p95=%.2f" % [
		_tag, view,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		ms[ms.size() / 2], ms[int(ms.size() * 0.95)]])
