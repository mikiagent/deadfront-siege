extends SceneTree
## HUDREDRAW measurement probe (headless, no window): the field HUD on the home island, standing still.
## Samples two runs of one second each and prints, for each, the HUD's `_draw` count, the mean
## Performance.TIME_PROCESS and the frame p95; the second run hides the HUD, so the difference is the
## HUD's own per-frame cost. Then it clears every transient piece and samples the idle signature again
## (how many of the 60 frames redrew the HUD, the minimap, and the process time with the fix in).
## Numbers only: this probe always exits 0, so it can be run before and after the change.
## Usage: godot --headless --path game --script res://tests/t_hudredraw.gd

const FRAMES := 120

var _started := false
var _world: Node
var _host: Node3D
var _hud
var _player

func _process(_delta: float) -> bool:
	if _started or root == null or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	_world = root.get_node("World")
	_host = Node3D.new()
	_host.name = "THudRedrawHost"
	root.add_child(_host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(_host, 4.0)
	_player = kit["player"]
	for c in (kit["ui"] as CanvasLayer).get_children():
		if c.has_method("quick_row_y"):
			_hud = c
	_world.load_island(_host, &"home_grassland", Vector3(0, 1, 18), false)
	(kit["nav"] as Node).queue_free()
	await process_frame
	await physics_frame
	_player.process_mode = Node.PROCESS_MODE_DISABLED  # held where the test puts her
	_player.vitals.fatigue = 0.0
	await _frames(30)
	_clear()
	var shown: Dictionary = await _sample(FRAMES)
	_hud.visible = false
	await _frames(10)
	var hidden: Dictionary = await _sample(FRAMES)
	_hud.visible = true
	print("[t_hudredraw] shown : %d frames, HUD draws %d (%.3f ms of script each, %.3f us an idle frame), minimap draws %d, process mean %.3f ms, p95 %.3f ms" % [FRAMES, shown["draws"], shown["draw_ms"], shown["draw_us"], shown["map_draws"], shown["mean_ms"], shown["p95_ms"]])
	print("[t_hudredraw] hidden: %d frames, HUD draws %d, minimap draws %d, process mean %.3f ms, p95 %.3f ms" % [FRAMES, hidden["draws"], hidden["map_draws"], hidden["mean_ms"], hidden["p95_ms"]])
	# Idle: nothing changes for 60 frames.
	_hud.visible = true
	await _frames(10)
	await create_timer(4.0).timeout  # the belt's drift EMA settles to rest
	_clear()
	await _frames(2)
	var idle: Dictionary = await _sample(60)
	print("[t_hudredraw] idle  : 60 frames, HUD draws %d, minimap draws %d, minimap draws %.3f ms, process mean %.3f ms, p95 %.3f ms" % [idle["draws"], idle["map_draws"], idle["map_draw_ms"], idle["mean_ms"], idle["p95_ms"]])
	quit(0)

## Drops every short-lived piece so the next sample measures the resting HUD.
func _clear() -> void:
	_hud._levelups.clear()
	_hud.top_feed.clear()
	var ev: Variant = _hud.get("_events")
	if ev != null:
		ev.notices.clear()
		ev.toasts.clear()
		ev.skill_toasts.clear()
		ev.bites.clear()
		ev.player_floats.clear()
	if _player.statuses:
		_player.statuses.clear_all()

func _sample(frames: int) -> Dictionary:
	var d0: int = int(_hud.draw_count)
	var m0: int = int(_hud.map_draw_count)
	var u0: int = int(_hud.draw_usec)
	var mu0: int = int(_hud.map_draw_usec)
	var times: Array[float] = []
	for i in frames:
		await process_frame
		times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	times.sort()
	var draws := int(_hud.draw_count) - d0
	var map_draws := int(_hud.map_draw_count) - m0
	var usec := int(_hud.draw_usec) - u0
	var map_usec := int(_hud.map_draw_usec) - mu0
	return {
		"draws": draws,
		"map_draws": map_draws,
		"draw_ms": float(usec) / 1000.0 / maxf(1.0, float(maxi(1, draws))),
		"draw_us": float(usec) / maxf(1.0, float(frames)),
		"map_draw_ms": float(map_usec) / 1000.0 / maxf(1.0, float(maxi(1, map_draws))),
		"mean_ms": times.reduce(func (a: float, b: float) -> float: return a + b, 0.0) / maxf(1.0, float(times.size())),
		"p95_ms": times[mini(times.size() - 1, int(float(times.size()) * 0.95))],
	}
