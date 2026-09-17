extends Node3D
## Main scene glue. Owns the sun and a debug label. Labs replace the default playfield.

@onready var sun: DirectionalLight3D = $Sun
@onready var debug_label: Label = $UI/DebugLabel
@onready var default_playfield: Node3D = $DefaultPlayfield
@onready var iso_camera: Camera3D = $IsoCamera

func _ready() -> void:
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	if Game.lab_name != "":
		default_playfield.visible = false
		default_playfield.process_mode = Node.PROCESS_MODE_DISABLED
		iso_camera.current = false
		var path := "res://scenes/dev/%s.tscn" % Game.lab_name
		if not ResourceLoader.exists(path):
			push_error("[boot] missing lab %s" % path)
		else:
			add_child(load(path).instantiate())
			print("[boot] lab=%s" % Game.lab_name)
	else:
		print("[boot] main scene ready")

func _process(_delta: float) -> void:
	debug_label.visible = Game.debug_overlay and Game.lab_name == ""
	if Input.is_action_just_pressed("debug_toggle"):
		Game.debug_overlay = not Game.debug_overlay
	if debug_label.visible:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		debug_label.text = "fps %d  |  tod %.2f (%s)  |  player %s" % [
			Engine.get_frames_per_second(), Game.time_of_day, Game.phase_name(),
			(p.global_position.snapped(Vector3.ONE * 0.1) if p else Vector3.ZERO)]
