extends Node3D
## Desktop acceptance for character inventory, animal growth and atlas family.

var player: Player

func _ready() -> void:
	var kit := LabKit.build(self, 30.0)
	player = kit["player"]
	World.player_name = "Milan"
	World.occupation = "Gatherer"
	World.pioneer_level = 7
	for id in [&"work_axe", &"stone_knife_work", &"work_pick", &"berry", &"branch", &"stone", &"fibre_stalk"]:
		LabKit.give(player, id, 2)
	for id in [&"protoceratops", &"velociraptor", &"stegosaurus"]:
		var rec := PetRecord.from_def(Data.creature(id), &"B")
		rec.level = player.bonded.size() * 4 + 3
		rec.xp = 18
		player.bonded.append(rec)
	await get_tree().process_frame
	if Game.shot_path.contains("animals"):
		var screen := AnimalScreen.new()
		var layer := CanvasLayer.new()
		add_child(layer)
		layer.add_child(screen)
		screen.open(player)
	else:
		player.ui.visible = true
		player.ui.rebuild()

	if DisplayServer.get_name() == "headless" and Game.shot_path == "":
		var unlimited_ok := Data.bonded_cap() > 1000000
		var animal := AnimalScreen.new()
		var layer := CanvasLayer.new()
		add_child(layer)
		layer.add_child(animal)
		animal.open(player)
		await get_tree().process_frame
		var animal_ok := animal.visible and animal._list.get_child_count() == 3 and animal._detail.text.contains("GROWTH / POTENTIAL")
		var inventory_ok := player.ui != null and player.ui._profile != null and player.ui._grid.columns == 5
		var stego: PetRecord = player.bonded[2]
		print("[uifamily] inventory=%s animals=%s unlimited=%s active_cap=%d stego=%s" % [inventory_ok, animal_ok, unlimited_ok, Player.MAX_PETS_OUT, stego.species])
		get_tree().quit(0 if inventory_ok and animal_ok and unlimited_ok and Player.MAX_PETS_OUT == 3 else 1)
