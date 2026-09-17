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
## Lab-only: number keys force creature clips (creature_lab) instead of hunt tactics.
var lab_force_clips: bool = false
## Lab-only: F deals a flat 100 damage to the nearest creature.
var lab_flat_attack: bool = false

var _last_phase: StringName = &""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--smoke":
			smoke_test = true
		elif a.begins_with("--lab="):
			lab_name = a.substr(6)
	print("[boot] Game autoload ready. smoke_test=%s lab=%s godot=%s" % [
		smoke_test, lab_name if lab_name != "" else "-", Engine.get_version_info().string])
	if smoke_test:
		get_tree().create_timer(2.0).timeout.connect(_finish_smoke)

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / day_length_seconds, 1.0)
	var phase := phase_name()
	if phase != _last_phase:
		_last_phase = phase
		day_phase_changed.emit(phase)

func phase_name() -> StringName:
	if time_of_day < 0.22 or time_of_day >= 0.80:
		return &"night"
	if time_of_day < 0.30:
		return &"dawn"
	if time_of_day < 0.72:
		return &"day"
	return &"dusk"

func _finish_smoke() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var ok := player != null and player.global_position.y > -1.0
	print("[smoke] %s player_pos=%s phase=%s" % ["ok" if ok else "FAIL", player.global_position if player else "none", phase_name()])
	get_tree().quit(0 if ok else 1)
