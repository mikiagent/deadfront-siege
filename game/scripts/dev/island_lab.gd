extends Node3D
## Temperate-25 island. Survivor at camp. Headless prints [world] island temperate_25.

var _player: Player
var _cam: IsoCamera

func _ready() -> void:
	var kit := LabKit.build(self, 20.0)
	_player = kit["player"]
	_cam = kit["cam"]
	_cam.size = 36.0
	_cam.distance = 28.0
	var nav: Node = kit["nav"]
	nav.visible = false
	LabKit.give(_player, &"work_axe", 1)
	LabKit.give(_player, &"stone_knife_work", 1)
	World.load_island(self, &"temperate_25", Vector3(0, 1, 12), false)
	_cam._target = _player
	_cam._snap()
	print("[boot] lab=island_lab")
	if Game.shot_path.contains("crater") and World.runtime:
		_player.global_position = Vector3(8.0, 2.0, -177.0)
		if World.runtime.has_method("surface_y"):
			_player.global_position.y = World.runtime.surface_y(_player.global_position.x, _player.global_position.z) + 1.2
		_cam.size = 32.0
		_cam._snap()
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().create_timer(0.8).timeout.connect(func () -> void:
			if World.runtime:
				print("[world] mm=%d nodes=%d creatures=%d" % [
					int(World.runtime.mm_count), int(World.runtime.harvest_count), int(World.runtime.creature_count)])
			get_tree().quit()
		)
