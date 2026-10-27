extends Node3D
## Existing player/world save and load through an isolated temporary save path.

func _ready() -> void:
	var save: GDScript = load("res://scripts/core/save_game.gd")
	var previous_path: String = save.path
	var fixture_path := "/private/tmp/deadfront-c0-lab-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	save.path = fixture_path
	if "--c0-error-ui" in OS.get_cmdline_user_args():
		var invalid := FileAccess.open(fixture_path, FileAccess.WRITE)
		if invalid == null:
			get_tree().quit(1)
			return
		invalid.store_string('{"schema":99,"player":{},"home":{}}')
		invalid.close()
		save.load_now(self)
		# The existing --shot mechanism captures the resulting recovery screen.
		return
	var kit := LabKit.build(self, 30.0)
	var player: Player = kit["player"]
	World.home_terrain = &"meadow"
	World.load_island(self, &"home_grassland", Vector3(0, 1, 12), false)
	var material := ItemStack.make(&"branch", 5, {"grain": "test"}, 7)
	material.set_flag(&"unstable", true)
	player.inventory.add(material)
	var pet := PetRecord.from_def(Data.creature(&"velociraptor"), &"B")
	pet.level = 4
	player.bonded.append(pet)
	World.cargo_home.add(ItemStack.make(&"stone", 3))
	World.t_stones = 37
	World.home_claims = [[1, 2, 3, 4]]
	World.camp_layout = {"test_layout": 12}
	var building = (load("res://scripts/world/placed_building.gd") as GDScript).make(&"basket")
	World.runtime.add_child(building)
	building.set_grid_pose(Vector2i(4, 8), 1)
	building.storage.add(ItemStack.make(&"stone", 2))
	var expected_inventory := JSON.stringify(player.inventory.to_array())
	var expected_pet := JSON.stringify(player.bonded[0].to_dict())
	save.save_now()
	var failures: Array[String] = []
	if not FileAccess.file_exists(fixture_path):
		failures.append("initial save was not written")
	else:
		player.inventory.load_array([])
		player.bonded.clear()
		World.cargo_home.load_array([])
		World.t_stones = 0
		World.home_claims = []
		World.camp_layout = {}
		save.load_now(self)
		if JSON.stringify(player.inventory.to_array()) != expected_inventory:
			failures.append("inventory, material level, attributes or flags changed")
		if player.bonded.size() != 1 or JSON.stringify(player.bonded[0].to_dict()) != expected_pet:
			failures.append("bonded pet or genetics changed")
		if World.cargo_home.count_of(&"stone") != 3 or World.t_stones != 37:
			failures.append("cargo or T-stones changed")
		var claims_ok: bool = World.home_claims.size() == 1 and World.home_claims[0] is Array and World.home_claims[0].size() == 4
		if claims_ok:
			for i in range(4):
				claims_ok = claims_ok and int(World.home_claims[0][i]) == i + 1
		if not claims_ok or int(World.camp_layout.get("test_layout", -1)) != 12:
			failures.append("home claims or camp layout changed")
		var restored := false
		for node: Node in get_tree().get_nodes_in_group("placed_building"):
			if World.runtime.is_ancestor_of(node) and node.get("kind") == &"basket" and node.get("build_cell") == Vector2i(4, 8):
				var storage: Inventory = node.get("storage")
				restored = storage != null and storage.count_of(&"stone") == 2 and int(node.get("build_rot")) == 1
		if not restored:
			failures.append("placed basket, rotation or contents changed")
		save.save_now()
		if not FileAccess.file_exists(fixture_path + ".bak"):
			failures.append("saving remained blocked after a successful load")
		# Exercise the existing v1 migration and old world-coordinate placement.
		var legacy := FileAccess.get_file_as_string("res://tests/fixtures/save_v1_c0.json")
		var legacy_file := FileAccess.open(fixture_path, FileAccess.WRITE)
		legacy_file.store_string(legacy)
		legacy_file.close()
		save.load_now(self)
		var legacy_index := player.inventory.find_first(&"branch")
		if legacy_index < 0:
			failures.append("legacy inventory stack disappeared")
		else:
			var legacy_stack: ItemStack = player.inventory.slots[legacy_index]
			if legacy_stack.count != 5 or legacy_stack.level != 7 or legacy_stack.attributes.get("grain") != "test" or not legacy_stack.is_unstable():
				failures.append("legacy material count, level, attributes or flags changed")
		if player.bonded.size() != 1 or int(player.bonded[0].genetics.ivs.get(&"health", -1)) != 7 or int(player.bonded[0].genetics.evs.get(&"health", -1)) != 2:
			failures.append("legacy pet genetics changed")
		var legacy_building := false
		for node: Node in get_tree().get_nodes_in_group("placed_building"):
			if World.runtime.is_ancestor_of(node) and node.get("kind") == &"basket" and node.get("build_cell") == Vector2i(4, 8):
				legacy_building = true
		if not legacy_building:
			failures.append("legacy world-coordinate building did not reach its grid cell")
	save.path = previous_path
	if FileAccess.file_exists(fixture_path):
		DirAccess.remove_absolute(fixture_path)
	if FileAccess.file_exists(fixture_path + ".bak"):
		DirAccess.remove_absolute(fixture_path + ".bak")
	if failures.is_empty():
		print("C0 SAVE RECOVERY LAB PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			print("C0 SAVE RECOVERY LAB FAIL: %s" % failure)
		get_tree().quit(1)
