extends Node3D
## Private home island. Headless demo: unstable destroy vs cargo warp, save/load tent rest.

var _player: Player

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	(load("res://scripts/ui/world_ui.gd") as GDScript).instance_on(self)
	World.home_terrain = &"meadow"
	World.t_stones = 20
	World.pioneer_level = 0
	LabKit.give(_player, &"stone_knife_work", 1)
	LabKit.give(_player, &"tent_kit", 1)
	LabKit.give(_player, &"basket_kit", 1)
	LabKit.give(_player, &"work_axe", 1)
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	print("[boot] lab=home_lab")
	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		get_tree().create_timer(0.5).timeout.connect(_demo)

func _demo() -> void:
	# PRD §24 tests 4–5 in spirit: on-foot unstable goods vanish; cargo warp keeps them.
	var lost := ItemStack.make(&"stone", 2, {"tint": "#8a8a8a"})
	lost.set_flag(&"unstable", true)
	_player.inventory.add(lost)
	World._strip_unstable_on_foot(_player)
	World.island_id = &"temperate_25"
	World.island_def = World.def_of(&"temperate_25")
	World.remaining_lifetime = 7200.0
	var keep := ItemStack.make(&"stone", 2, {"tint": "#8a8a8a"})
	keep.set_flag(&"unstable", true)
	_player.inventory.add(keep)
	World.cargo_warp(_player)
	World.load_island(self, &"home_grassland", Vector3(0, 1, 18), false)
	var cargo_n := World.cargo_home.count_of(&"stone")
	print("[world] cargo basket stone=%d" % cargo_n)
	_player.vitals.fatigue = 80.0
	World.resting_in_tent = true
	var SG := load("res://scripts/core/save_game.gd") as GDScript
	SG.save_now()
	var raw := FileAccess.get_file_as_string("user://save_1.json")
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		d["saved_unix"] = int(Time.get_unix_time_from_system()) - 120
		var f := FileAccess.open("user://save_1.json", FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(d))
	SG.load_now(self)
	print("[world] fatigue after rest=%.0f terrain=%s pioneer=%d" % [
		_player.vitals.fatigue, World.home_terrain, World.pioneer_level])
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
