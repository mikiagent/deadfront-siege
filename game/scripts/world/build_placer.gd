class_name BuildPlacer
extends Node
## Ghost building under the cursor, 1 m snap, red on overlap. Consumes a kit, else category leftovers.

var placing: StringName = &""
var ghost: MeshInstance3D
var valid: bool = false
var _cell: Vector3 = Vector3.ZERO

func _kit_id(kind: StringName) -> String:
	match kind:
		&"makeshift_taming_pen":
			return "makeshift_taming_pen"
		&"bonfire":
			return "bonfire_kit"
		&"workbench":
			return "workbench_kit"
		&"drying_rack":
			return "drying_rack_kit"
		&"tent":
			return "tent_kit"
		&"basket":
			return "basket_kit"
		&"fence":
			return "fence_kit"
		&"gate":
			return "gate_kit"
		&"sign":
			return "sign_kit"
		_:
			return ""

func _ready() -> void:
	ghost = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 1.2, 3.0)
	ghost.mesh = box
	ghost.visible = false
	add_child(ghost)

func begin(kind: StringName) -> void:
	placing = kind
	ghost.visible = true

func cancel() -> void:
	placing = &""
	ghost.visible = false

func _process(_delta: float) -> void:
	if placing == &"":
		return
	var hit := _ground()
	if hit.is_empty():
		valid = false
		return
	var pos: Vector3 = hit.position
	_cell = Vector3(round(pos.x), 0.0, round(pos.z))
	ghost.global_position = _cell + Vector3(0, 0.6, 0)
	valid = not _overlaps()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.9, 0.35, 0.45) if valid else Color(0.9, 0.2, 0.15, 0.45)
	ghost.material_override = mat

func confirm(player: Player) -> bool:
	if placing == &"" or not valid:
		return false
	if not _pay(player):
		print("[item] cannot afford %s" % placing)
		return false
	var node := _spawn(placing)
	if node == null:
		return false
	player.get_parent().add_child(node)
	node.global_position = _cell
	print("[item] placed %s" % placing)
	World.note_building(placing)
	cancel()
	return true

func _spawn(kind: StringName) -> Node3D:
	match kind:
		&"makeshift_taming_pen":
			return TamingPen.new()
		&"bonfire":
			return Bonfire.new()
		&"workbench":
			return CraftStation.make(&"workbench")
		&"drying_rack":
			return CraftStation.make(&"drying_rack")
		&"tent", &"basket", &"fence", &"gate", &"sign":
			return (load("res://scripts/world/placed_building.gd") as GDScript).make(kind)
		_:
			return null

func _pay(player: Player) -> bool:
	var kit_id := StringName(str(_kit_id(placing)))
	if kit_id != &"" and player.inventory.count_of(kit_id) > 0:
		return player.inventory.consume(kit_id, 1)
	if placing == &"makeshift_taming_pen":
		if player.inventory.count_of(&"branch") < 4 or player.inventory.count_of(&"twine") < 2:
			return false
		player.inventory.consume(&"branch", 4)
		player.inventory.consume(&"twine", 2)
		return true
	if placing == &"bonfire":
		if player.inventory.count_of(&"branch") < 2:
			return false
		player.inventory.consume(&"branch", 2)
		return true
	if placing == &"workbench":
		if player.inventory.count_of(&"branch") < 4 or player.inventory.count_of(&"twine") < 2:
			return false
		player.inventory.consume(&"branch", 4)
		player.inventory.consume(&"twine", 2)
		return true
	if placing == &"drying_rack":
		if player.inventory.count_of(&"branch") < 3 or player.inventory.count_of(&"twine") < 1:
			return false
		player.inventory.consume(&"branch", 3)
		player.inventory.consume(&"twine", 1)
		return true
	if placing == &"tent":
		return player.inventory.consume(&"tent_kit", 1)
	if placing == &"basket":
		return player.inventory.consume(&"basket_kit", 1)
	if placing == &"fence":
		return player.inventory.consume(&"fence_kit", 1)
	if placing == &"gate":
		return player.inventory.consume(&"gate_kit", 1)
	if placing == &"sign":
		return player.inventory.consume(&"sign_kit", 1)
	return false

func _overlaps() -> bool:
	var space := get_tree().root.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.2, 3.0)
	q.shape = box
	q.transform = Transform3D(Basis.IDENTITY, _cell + Vector3(0, 0.6, 0))
	q.collide_with_bodies = true
	var hits := space.intersect_shape(q, 8)
	for h in hits:
		var n: Object = h.get("collider")
		if n is Player:
			continue
		if n is StaticBody3D and str((n as Node).name).begins_with("Floor"):
			continue
		return true
	return false

func _ground() -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var mouse := Game.pointer
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	return get_tree().root.get_world_3d().direct_space_state.intersect_ray(q)
