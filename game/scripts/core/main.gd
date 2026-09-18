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
		var player := get_tree().get_first_node_in_group("player") as Player
		if player:
			var inv_ui = preload("res://scenes/ui/inventory.tscn").instantiate()
			$UI.add_child(inv_ui)
			player.ui = inv_ui
			inv_ui.bind(player.inventory)
			var craft = preload("res://scenes/ui/craft.tscn").instantiate()
			$UI.add_child(craft)
			player.craft_ui = craft
			craft.bind(player)

func _process(_delta: float) -> void:
	debug_label.visible = false
	if Input.is_action_just_pressed("debug_toggle"):
		Game.debug_overlay = not Game.debug_overlay
