extends Node3D
## Performance budget on the real temperate_25 island (full creature cap, every harvest node):
## after the island settles it samples SAMPLE_FRAMES frames and prints
##   [perf] physics_ms=<p95> frame_ms=<p95> process_ms=<p95> prims_visible=<max> prims_shadow=<max> ...
## then fails above the budgets. Headless measures CPU only (the dummy renderer draws nothing,
## so prims/draws read 0 and are not gated); run it windowed for the render budget.

const SAMPLE_FRAMES := 300
const SETTLE_S := 2.0
# Budgets recorded after W1-AI (AI LOD) and W1-WEB (vegetation culling) merged, 2026-10-19, on
# claude/mmo-overhaul + this package (M5 Pro dev machine): headless physics p95 6.77 ms, frame
# 8.54 ms; windowed 1600x900 Forward+ physics 1.34 ms, frame 10-12 ms. The primitive budgets are
# W1-WEB's camp budget (its report: visible <= 900k, shadow <= 3.0M; 5.2 M total before W1-WEB).
# ASSUMPTION: the CPU budgets are regression fences for the dev machine, not phone targets.
const BUDGET_PHYSICS_MS := 8.0           # half a 60 Hz tick
const BUDGET_FRAME_MS := 33.4            # never below 30 fps
const BUDGET_PRIMS_VISIBLE := 900_000    # windowed only
const BUDGET_PRIMS_SHADOW := 3_000_000   # windowed only

var _player: Player
var _cam: IsoCamera
var _physics: Array[float] = []
var _process_ms: Array[float] = []
var _frames: Array[float] = []
var _prims := 0
var _shadow_prims := 0
var _draws := 0
var _last_us := 0
var _sampling := false

func _ready() -> void:
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	(kit["nav"] as Node).visible = false
	if Game.shot_path != "":
		TouchControls.visible = false
		TouchControls.enabled = false
	World.harvested.clear()
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	var kit_floor := get_node_or_null("Floor")
	if kit_floor:
		kit_floor.queue_free()
	_cam._target = _player
	_cam._snap()
	print("[boot] lab=perf_budget_lab")
	if Game.shot_path == "":
		call_deferred("_run")

func _run() -> void:
	await get_tree().create_timer(SETTLE_S).timeout
	_last_us = Time.get_ticks_usec()
	_sampling = true

func _process(_delta: float) -> void:
	if not _sampling:
		return
	var now := Time.get_ticks_usec()
	_frames.append(float(now - _last_us) / 1000.0)
	_last_us = now
	_physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var vp := get_viewport()
	_prims = maxi(_prims, vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	_shadow_prims = maxi(_shadow_prims, vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
	_draws = maxi(_draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if _frames.size() >= SAMPLE_FRAMES:
		_sampling = false
		_finish()

func _finish() -> void:
	var r := LabResult.new("perf_budget")
	var headless := LabResult.headless()
	var physics := _p95(_physics)
	var frame := _p95(_frames)
	var creatures := int(World.runtime.creature_count) if World.runtime else 0
	print("[perf] physics_ms=%.2f frame_ms=%.2f process_ms=%.2f prims_visible=%d prims_shadow=%d draws=%d creatures=%d nodes=%d headless=%s frames=%d" % [
		physics, frame, _p95(_process_ms), _prims, _shadow_prims, _draws, creatures,
		int(World.runtime.harvest_count) if World.runtime else 0, headless, _frames.size()])
	r.expect(creatures > 0, "island spawned no creatures, so the budget measured nothing")
	r.expect(physics <= BUDGET_PHYSICS_MS, "physics p95 %.2f ms over budget %.1f ms" % [physics, BUDGET_PHYSICS_MS])
	# CI's xvfb window renders on a CPU rasteriser (llvmpipe): frame time there says nothing about
	# the game, so only geometry is gated on it.
	var adapter := RenderingServer.get_video_adapter_name()
	var software := adapter.to_lower().contains("llvmpipe") or adapter.to_lower().contains("softpipe")
	print("[perf] adapter=%s software=%s" % [adapter, software])
	if not software:
		r.expect(frame <= BUDGET_FRAME_MS, "frame p95 %.2f ms over budget %.1f ms" % [frame, BUDGET_FRAME_MS])
	if not headless:
		r.expect(_prims > 0, "renderer reported no primitives")
		r.expect(_prims <= BUDGET_PRIMS_VISIBLE, "visible primitives %d over budget %d" % [_prims, BUDGET_PRIMS_VISIBLE])
		r.expect(_shadow_prims <= BUDGET_PRIMS_SHADOW, "shadow primitives %d over budget %d" % [_shadow_prims, BUDGET_PRIMS_SHADOW])
	r.finish(get_tree(), "physics_ms=%.2f frame_ms=%.2f prims_visible=%d prims_shadow=%d" % [physics, frame, _prims, _shadow_prims])

static func _p95(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(float(sorted.size()) * 0.95))]
