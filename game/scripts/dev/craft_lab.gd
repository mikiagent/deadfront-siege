extends Node3D
## PRD §24 test 2: two knives from different primaries do not merge. Locked combat knife skipped.

var _player: Player

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	_spawn(&"thicket", Vector3(5, 0, 3), &"fibre_stalk", {"climate": "thicket"}, &"knife", Color(0.18, 0.4, 0.18))
	_spawn(&"tree", Vector3(8, 0, 3), &"wood_log", {}, &"axe", Color(0.35, 0.22, 0.12))
	_spawn(&"rock", Vector3(5, 0, 6), &"stone", {}, &"pick", Color(0.5, 0.5, 0.48))
	var bench := CraftStation.make(&"workbench")
	bench.position = Vector3(-3, 0, 2)
	add_child(bench)
	var rack := CraftStation.make(&"drying_rack")
	rack.position = Vector3(-3, 0, 5)
	add_child(rack)
	print("[boot] lab=craft_lab")
	if DisplayServer.get_name() == "headless":
		get_tree().create_timer(0.4).timeout.connect(_demo)

func _demo() -> void:
	# Locked combat knife must never auto-equip for the thicket.
	var locked := ItemStack.make(&"stone_knife", 1)
	locked.set_flag(&"locked", true)
	_player.inventory.add(locked)
	var thicket: HarvestNode = null
	for n in get_tree().get_nodes_in_group("harvest"):
		if (n as HarvestNode).node_id == &"thicket":
			thicket = n as HarvestNode
			break
	if thicket:
		var why := thicket.can_gather(_player.inventory)
		print("[item] refused %s: %s" % [thicket.node_id, why if why != "" else "open"])
		_player._begin_gather(thicket)
	# Work knife auto-equips and the locked combat knife stays unused.
	LabKit.give(_player, &"stone_knife_work", 1)
	if thicket:
		thicket.depleted = false
		thicket.visible = true
		_player._begin_gather(thicket)
		if _player.gather_target:
			_player._gathering = true
			_player._gather_left = 0.0
			_player._finish_gather()
	# PRD §24 test 2: bone-blade vs stone-blade knives differ and do not merge.
	_player.inventory.add(ItemStack.make(&"raptor_bone", 1, {"hardness": 2, "tint": "#d4c4a8"}))
	_player.inventory.add(ItemStack.make(&"stone", 1, {"tint": "#8a8a8a"}))
	_player.inventory.add(ItemStack.make(&"branch", 4))
	_player.inventory.add(ItemStack.make(&"twine", 4))
	var knife_rec: Dictionary = Data.recipes.get(&"improvised_stone_knife", {})
	var bone_idx := _player.inventory.find_first(&"raptor_bone")
	var stone_idx := _player.inventory.find_first(&"stone")
	var handle_idx := _player.inventory.find_first(&"branch")
	var lash_idx := _player.inventory.find_first(&"twine")
	var bone_picks: Array[int] = [bone_idx, handle_idx, lash_idx]
	Crafting.craft(_player, knife_rec, bone_picks)
	handle_idx = _player.inventory.find_first(&"branch")
	lash_idx = _player.inventory.find_first(&"twine")
	var stone_picks: Array[int] = [stone_idx, handle_idx, lash_idx]
	Crafting.craft(_player, knife_rec, stone_picks)
	var bone_k: ItemStack = null
	var stone_k: ItemStack = null
	for s in _player.inventory.slots:
		if s == null or s.def_id != &"stone_knife_work":
			continue
		if int(s.attributes.get("hardness", 0)) >= 2:
			bone_k = s
		elif str(s.attributes.get("tint", "")) == "#8a8a8a":
			stone_k = s
	var merge := false
	if bone_k and stone_k:
		merge = bone_k.can_merge_with(stone_k)
	print("[craft] knives bone=%s stone=%s merge=%s bone_tint=%s stone_tint=%s" % [
		bone_k != null, stone_k != null, merge,
		bone_k.attributes.get("tint", "") if bone_k else "",
		stone_k.attributes.get("tint", "") if stone_k else "",
	])
	# Butcher a velociraptor corpse (JSON drops via butchering.json).
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	add_child(c)
	c.global_position = Vector3(2, 0, 2)
	c.spawn(Data.creature(&"velociraptor"), &"")
	c.health.take_damage(9999.0, _player)
	await get_tree().create_timer(0.15).timeout
	var corpse: Corpse = null
	for n in get_tree().get_nodes_in_group("corpse"):
		corpse = n as Corpse
		if corpse:
			break
	if corpse:
		corpse.butcher(_player)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

func _spawn(id: StringName, pos: Vector3, def_id: StringName, attrs: Dictionary, tool: StringName, color: Color) -> void:
	var n: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	n.position = pos
	add_child(n)
	n.setup(id, def_id, 1, 1, attrs, tool, color)
