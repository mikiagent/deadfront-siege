extends Node
## Global game singleton. Holds run-wide state that is NOT scene-local.

signal day_phase_changed(phase: StringName)

## Length of a full day/night cycle in real seconds. The systems PRD (§4.4.1)
## found no canonical value, so this is a tunable, not a fact.
@export var day_length_seconds: float = 720.0

var time_of_day: float = 0.35  # 0..1, 0 = midnight, 0.5 = noon
var debug_overlay: bool = true
var smoke_test: bool = false
var lab_name: String = ""
## Debug multiplier for long real-time systems (taming pen). F8 in capture_lab sets 60.
var time_scale: float = 1.0
## ASSUMPTION: mobile island cap. Spawners should not exceed this.
var max_creatures_per_island: int = 24
## Lab-only: number keys force creature clips (creature_lab) instead of hunt tactics.
var lab_force_clips: bool = false
## Lab-only: F deals a flat 100 damage to the nearest creature.
var lab_flat_attack: bool = false
var shot_path: String = ""
var pointer: Vector2 = Vector2.ZERO

var _last_phase: StringName = &""
var _perf: Label
var _bg_unix: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			smoke_test = true
		elif a.begins_with("--lab="):
			lab_name = a.substr(6)
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
			debug_overlay = false
	print("[boot] Game autoload ready. smoke_test=%s lab=%s godot=%s" % [
		smoke_test, lab_name if lab_name != "" else "-", Engine.get_version_info().string])
	_make_perf()
	if smoke_test:
		get_tree().create_timer(2.0).timeout.connect(_finish_smoke)
	elif shot_path != "":
		get_tree().create_timer(2.6).timeout.connect(_take_shot)

func _make_perf() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.name = "PerfHud"
	add_child(layer)
	_perf = Label.new()
	_perf.position = Vector2(12, 8)
	_perf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf.add_theme_font_size_override("font_size", 16)
	_perf.add_theme_color_override("font_color", Color(0.95, 0.95, 0.7))
	layer.add_child(_perf)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		debug_overlay = not debug_overlay

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		pointer = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		pointer = (event as InputEventMouseButton).position

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / day_length_seconds, 1.0)
	var phase := phase_name()
	if phase != _last_phase:
		_last_phase = phase
		day_phase_changed.emit(phase)
	if _perf:
		_perf.visible = debug_overlay
		if debug_overlay:
			var mem_mb := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
			_perf.text = "fps %d  draws %d  mem %.0f MB  tod %.2f (%s)" % [
				Engine.get_frames_per_second(),
				int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
				mem_mb, time_of_day, phase_name()]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if smoke_test:
			return
		_bg_unix = int(Time.get_unix_time_from_system())
		if get_tree():
			get_tree().paused = true
		(load("res://scripts/core/save_game.gd") as GDScript).save_now()
		print("[world] background autosave")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if get_tree():
			get_tree().paused = false
		var elapsed := 0
		if _bg_unix > 0:
			elapsed = maxi(0, int(Time.get_unix_time_from_system()) - _bg_unix)
		if elapsed > 0 and World.resting_in_tent:
			var player := get_tree().get_first_node_in_group("player") as Player
			if player:
				player.vitals.rest(World.TENT_REST_PER_MIN * (float(elapsed) / 60.0))
				print("[world] background rest %ds" % elapsed)
		_bg_unix = 0

func phase_name() -> StringName:
	if time_of_day < 0.22 or time_of_day >= 0.80:
		return &"night"
	if time_of_day < 0.30:
		return &"dawn"
	if time_of_day < 0.72:
		return &"day"
	return &"dusk"

func clock_label() -> String:
	var mins := int(time_of_day * 24.0 * 60.0)
	mins = mins % (24 * 60)
	return "%02d:%02d" % [int(mins / 60), mins % 60]

func _take_shot() -> void:
	await RenderingServer.frame_post_draw
	var tex := get_viewport().get_texture()
	if tex:
		var img := tex.get_image()
		if img:
			img.save_png(shot_path)
			print("[boot] shot %s" % shot_path)
	get_tree().quit(0)

func _finish_smoke() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var ok := player != null and player.global_position.y > -1.0
	print("[smoke] %s player_pos=%s phase=%s" % ["ok" if ok else "FAIL", player.global_position if player else "none", phase_name()])
	get_tree().quit(0 if ok else 1)
