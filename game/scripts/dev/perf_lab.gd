extends Node3D
## PERFGATES lab: the plan's section 1.7 camp-view row, measured in a real window. Stands the
## survivor at the home island's camp with the game's own HUD and camera, lets the island settle,
## then times 20 s of frames and reads the renderer's own counters. Prints exactly one line:
##   [perfgates] RESULT draws=<n> prims=<n> shadow_prims=<n> frame_p95_ms=<ms> frame_mean_ms=<ms>
## and saves <shot-dir>/perf_lab_<w>x<h>.png. Quits by itself.
##   Godot --path game --resolution 1600x900 --rendering-method gl_compatibility --
##     --lab=perf_lab --shot-dir=/tmp/perf_shots
## prims = primitives in the base pass (sun shadow pass off for that sample), shadow_prims = the
## frame's total with the shadow pass on (the plan's "shadow" row, "today 2.83M total"), draws =
## draw calls in frame. Frame times
## are wall-clock dt between frames; with vsync on the machine's compositor caps them near the
## display rate (camera_lab's note), so the same numbers at 844x390 show the resolution's effect.
## The plan's budgets for this row: prims < 900k, shadow < 3.0M, draws < 450.
## Headless: prints a note and quits (frame timing and primitives need a renderer).

const PERF_SECONDS := 20.0
const SETTLE_SECONDS := 2.5
## Frames skipped after the shadow switch: the pipeline recompiles once.
const SHADOW_SETTLE := 4

var _shot_dir := ""
var _args := {}
var _done := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_shot_dir = str(_args.get("shot-dir", ""))
	Game.debug_overlay = false
	Game.shot_path = ""  # the lab saves its own shot
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("[perfgates] headless: camp-view primitives and frame timing need a renderer")
		get_tree().quit(0)
		return
	if _shot_dir != "":
		DirAccess.make_dir_recursive_absolute(_shot_dir)
	var kit := LabKit.build(self, 4.0)
	var player: Player = kit["player"]
	var cam: Camera3D = kit["cam"]
	# The kit's floor and nav would stand in the camp view; the island brings its own ground.
	for n in ["Nav", "Floor"]:
		var dead := get_node_or_null(n)
		if dead:
			dead.queue_free()
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	var rt: Node = World.runtime
	if rt == null:
		print("[perfgates] RESULT draws=0 prims=0 shadow_prims=0 frame_p95_ms=0 frame_mean_ms=0")
		get_tree().quit(1)
		return
	var camp: Vector3 = rt.get("_camp_pos")
	if camp == Vector3.ZERO:
		camp = rt.call("arrival_point")
	# Beside the camp, as a survivor stands when she opens her base: the tent and the landing in view.
	player.global_position = camp + Vector3(2.0, 1.0, 2.0)
	player.global_position.y = float(rt.call("surface_y", player.global_position.x, player.global_position.z)) + 1.0
	player.reset_physics_interpolation()
	cam.set("_target", player)
	cam.call("_snap")
	# The camera looks down the view axis; keep the far plane generous for the island's sea planes.
	cam.far = maxf(cam.far, 900.0)
	print("[perfgates] lab=perf_lab camp=%s res=%s" % [str(camp), _res_tag()])
	await _shot()
	await _timing(rt)
	get_tree().quit(0)

func _res_tag() -> String:
	var w := DisplayServer.window_get_size().x
	var h := DisplayServer.window_get_size().y
	return "%dx%d" % [w, h]

func _shot() -> void:
	await RenderingServer.frame_post_draw
	if _shot_dir == "":
		return
	var img := get_viewport().get_texture().get_image()
	var path := _shot_dir.path_join("perf_lab_%s.png" % _res_tag())
	img.save_png(path)
	print("[perfgates] shot %s" % path)

## 20 s of live frames: dt per frame plus the renderer's counters. The shadow pass is measured
## separately afterwards so switching it cannot distort the frame times.
func _timing(rt: Node) -> void:
	# A build's first frames compile pipelines and upload the island's textures; time after that.
	var settle_until := Time.get_ticks_msec() + int(SETTLE_SECONDS * 1000.0)
	while Time.get_ticks_msec() < settle_until:
		await get_tree().process_frame
	var dts: Array[float] = []
	var draws := 0.0
	var prims := 0.0
	var last := Time.get_ticks_usec()
	var end := last + int(PERF_SECONDS * 1000000.0)
	while Time.get_ticks_usec() < end:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		dts.append(float(now - last) / 1000.0)
		last = now
		draws += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	if dts.is_empty():
		print("[perfgates] RESULT draws=0 prims=0 shadow_prims=0 frame_p95_ms=0 frame_mean_ms=0")
		return
	var sorted := dts.duplicate()
	sorted.sort()
	var n := sorted.size()
	var mean := 0.0
	for d in dts:
		mean += d
	mean /= float(n)
	var p95: float = sorted[int(n * 0.95)] if n > 1 else sorted[0]
	var base_prims := await _prims_without_shadow()
	# With the shadow pass back on: the total the plan's "shadow < 3.0M" row compares against.
	var shadow_prims := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("[perfgates] RESULT draws=%.0f prims=%d shadow_prims=%d frame_p95_ms=%.2f frame_mean_ms=%.2f" % [
		draws / float(n), base_prims, shadow_prims, p95, mean])

## Primitives in the base pass: the sun's shadow pass switched off for one sample and back on.
func _prims_without_shadow() -> int:
	var lights: Array[DirectionalLight3D] = []
	for l in find_children("*", "DirectionalLight3D", true, false):
		var dl := l as DirectionalLight3D
		if dl != null and dl.shadow_enabled:
			lights.append(dl)
			dl.shadow_enabled = false
	for i in SHADOW_SETTLE:
		await RenderingServer.frame_post_draw
	var base := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	for l in lights:
		l.shadow_enabled = true
	for i in SHADOW_SETTLE:
		await RenderingServer.frame_post_draw
	return base
