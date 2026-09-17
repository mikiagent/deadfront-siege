extends Node3D
## Six harvest nodes: two climate-stamped fibre stalks, branch, stone, herb, knife-gated thicket.

var _player: Player
var _debug: Label

func _ready() -> void:
	var kit := LabKit.build(self)
	_player = kit["player"]
	_debug = kit["debug"]
	_spawn(&"fibre_a", Vector3(4, 0, 2), &"fibre_stalk", {"climate": "temperate"}, &"none", Color(0.45, 0.72, 0.32))
	_spawn(&"fibre_b", Vector3(6, 0, 2), &"fibre_stalk", {"climate": "tropical"}, &"none", Color(0.25, 0.62, 0.28))
	_spawn(&"branches", Vector3(4, 0, 5), &"branch", {}, &"none", Color(0.55, 0.38, 0.2))
	_spawn(&"stones", Vector3(7, 0, 5), &"stone", {}, &"none", Color(0.55, 0.55, 0.5))
	_spawn(&"herbs", Vector3(4, 0, 8), &"herb_leaf", {}, &"none", Color(0.3, 0.7, 0.45))
	_spawn(&"thicket", Vector3(7, 0, 8), &"fibre_stalk", {"climate": "thicket"}, &"knife", Color(0.18, 0.4, 0.18))
	if DisplayServer.get_name() == "headless":
		get_tree().create_timer(0.4).timeout.connect(_demo)

func _demo() -> void:
	# Headless proof: two climate-stamped fibre stalks stay unmerged; thicket refuses without a knife.
	for n in get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node == null:
			continue
		var why := node.can_gather(_player.inventory)
		if why != "":
			print("[item] refused %s: %s" % [node.node_id, why])
			continue
		var stack := node.roll_yield()
		var attrs: Dictionary = stack.attributes.duplicate(true)
		var before := stack.count
		var left := _player.inventory.add(stack)
		print("[item] +%d %s %s" % [before - left, stack.def_id, attrs])
		if str(node.node_id).begins_with("fibre"):
			var again := node.roll_yield()
			var attrs2: Dictionary = again.attributes.duplicate(true)
			var before2 := again.count
			var left2 := _player.inventory.add(again)
			print("[item] +%d %s %s" % [before2 - left2, again.def_id, attrs2])
		node.mark_gathered()
	LabKit.give(_player, &"stone_knife_work", 1)
	for n in get_tree().get_nodes_in_group("harvest"):
		var node := n as HarvestNode
		if node and node.node_id == &"thicket":
			node.depleted = false
			node.visible = true
			var stack := node.roll_yield()
			var attrs: Dictionary = stack.attributes.duplicate(true)
			var before := stack.count
			var left := _player.inventory.add(stack)
			print("[item] +%d %s %s" % [before - left, stack.def_id, attrs])
	var temperate := 0
	var tropical := 0
	for s in _player.inventory.slots:
		if s and s.def_id == &"fibre_stalk":
			if str(s.attributes.get("climate", "")) == "temperate":
				temperate += s.count
			elif str(s.attributes.get("climate", "")) == "tropical":
				tropical += s.count
	print("[item] fibre stacks temperate=%d tropical=%d (unmerged climates)" % [temperate, tropical])

func _process(_delta: float) -> void:
	if _player:
		_debug.text = "foundation_lab  slots %d/%d  (tap a plant; thicket needs a knife)" % [
			_player.inventory.used_slots(), _player.inventory.slot_count]

func _spawn(id: StringName, pos: Vector3, def_id: StringName, attrs: Dictionary, tool: StringName, color: Color) -> void:
	var n: HarvestNode = preload("res://scenes/world/harvest_node.tscn").instantiate()
	n.position = pos
	add_child(n)
	n.setup(id, def_id, 1, 1, attrs, tool, color)
