extends Node3D
## Visual QA: compy baseline beside the two 3x raptor species.

func _ready() -> void:
	var kit := LabKit.build(self, 36.0)
	var player := kit["player"] as Player
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_spawn_frozen(&"compsognathus", Vector3(-3.2, 0.0, 0.0))
	_spawn_frozen(&"velociraptor", Vector3(0.0, 0.0, 0.0))
	_spawn_frozen(&"deinonychus", Vector3(4.0, 0.0, 0.0))
	var compy := Data.creature(&"compsognathus")
	var raptor := Data.creature(&"velociraptor")
	var deino := Data.creature(&"deinonychus")
	print("[dino_scale] compy h=%.2f l=%.2f velociraptor h=%.2f l=%.2f deinonychus h=%.2f l=%.2f" % [compy.height_meters, compy.real_length_m, raptor.height_meters, raptor.real_length_m, deino.height_meters, deino.real_length_m])
	_label("COMPY  2x", Vector3(-3.2, compy.height_meters + 0.5, 0.0))
	_label("VELOCIRAPTOR  3x", Vector3(0.0, raptor.height_meters + 0.5, 0.0))
	_label("DEINONYCHUS  3x", Vector3(4.0, deino.height_meters + 0.5, 0.0))
	print("[boot] lab=raptor_scale_lab")

func _spawn_frozen(species: StringName, at: Vector3) -> void:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = at
	c.spawn(Data.creature(species))
	c.process_mode = Node.PROCESS_MODE_DISABLED

func _label(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 34
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.position = at
	add_child(label)
