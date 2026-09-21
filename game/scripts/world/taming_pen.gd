class_name TamingPen
extends StaticBody3D
## Holds one captured animal. 30 real minutes, scaled by Game.time_scale.

const BASE_SECONDS := 30.0 * 60.0
const SUCCESS_CHANCE := 0.70 ## ASSUMPTION:

var kind: StringName = &"makeshift_taming_pen"
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var occupant: ItemStack
var remaining: float = 0.0
var running: bool = false
var force_result: int = 0

func _ready() -> void:
	add_to_group("placed_building")
	add_to_group("taming_pen")
	if get_node_or_null("Shape") == null and get_node_or_null("PropRing") == null and get_node_or_null("FallbackMesh") == null:
		_build_visual()

func _exit_tree() -> void:
	if World.runtime == null:
		return
	var grid: Variant = World.runtime.get("build_grid")
	if grid is BuildGrid:
		(grid as BuildGrid).release(self)

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)

func to_dict() -> Dictionary:
	var rec := {
		"kind": str(kind),
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"x": global_position.x,
		"z": global_position.z,
		"running": running,
		"remaining": remaining,
	}
	rec["occupant"] = occupant.to_dict() if occupant else null
	return rec

static func make() -> TamingPen:
	var pen := TamingPen.new()
	pen.kind = &"makeshift_taming_pen"
	pen.persist_building = true
	pen.name = "makeshift_taming_pen"
	return pen

static func from_dict(d: Dictionary) -> TamingPen:
	var pen := make()
	var cell_v: Variant = d.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		pen.build_cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	pen.build_rot = int(d.get("rot", 0))
	pen.running = bool(d.get("running", false))
	pen.remaining = float(d.get("remaining", 0.0))
	var occ: Variant = d.get("occupant", null)
	if occ is Dictionary:
		pen.occupant = ItemStack.from_dict(occ as Dictionary)
	return pen

func try_insert(player: Player) -> bool:
	if running:
		return false
	var idx := player.inventory.find_first(&"captured_animal")
	if idx < 0:
		return false
	occupant = player.inventory.remove_at(idx, 1)
	remaining = BASE_SECONDS
	running = true
	print("[capture] pen start %s" % occupant.attributes.get("species", "?"))
	return true

func feed(player: Player) -> bool:
	if not running or occupant == null:
		return false
	var meat := player.inventory.find_first(&"raptor_meat")
	if meat < 0:
		return false
	player.inventory.remove_at(meat, 1)
	remaining = maxf(5.0, remaining * 0.6)
	print("[capture] pen fed remaining=%.1fs" % remaining)
	return true

func _process(delta: float) -> void:
	if not running:
		return
	remaining -= delta * Game.time_scale
	if remaining > 0.0:
		return
	running = false
	var species := StringName(str(occupant.attributes.get("species", "velociraptor")))
	var def := Data.creature(species)
	if def == null:
		return
	var ok := randf() < SUCCESS_CHANCE
	if force_result > 0:
		ok = true
	elif force_result < 0:
		ok = false
	if ok:
		var grade := _roll_grade(int(occupant.attributes.get("grade_seed", 0)))
		var tamed := ItemStack.make(&"tamed_animal", 1, {
			"species": str(species),
			"variant": str(occupant.attributes.get("variant", "")),
			"grade": str(grade),
			"genetics": occupant.attributes.get("genetics", {}),
		})
		var player := get_tree().get_first_node_in_group("player") as Player
		if player:
			player.inventory.add(tamed)
		print("[capture] pen %s %s" % [species, grade])
	else:
		print("[capture] pen %s escaped" % species)
		_spawn_wild(def)
	occupant = null

func _roll_grade(seed: int) -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else randi()
	var r := rng.randf()
	if r < 0.08:
		return &"S"
	if r < 0.28:
		return &"A"
	if r < 0.75:
		return &"B"
	return &"C"

func _spawn_wild(def: CreatureDef) -> void:
	var c: Creature = preload("res://scenes/creatures/creature.tscn").instantiate()
	get_parent().add_child(c)
	c.global_position = global_position + Vector3(2, 0, 0)
	c.spawn(def)
	c.brain.state = &"flee"

func _build_visual() -> void:
	PropVisuals.ensure_foundation(self, &"makeshift_taming_pen")
	PropVisuals.ensure_collision(self, Vector3(4.0, 1.8, 4.0))
	var ring := Node3D.new()
	ring.name = "PropRing"
	add_child(ring)
	var fence_path := PropVisuals.model_path(&"makeshift_taming_pen")
	var gate_path := PropVisuals.model_path(&"gate")
	var placed := 0
	for part in _ring_layout():
		var node: Node3D = null
		var path := gate_path if bool(part["gate"]) else fence_path
		if path != "" and ResourceLoader.exists(path):
			var packed := load(path)
			if packed is PackedScene:
				node = (packed as PackedScene).instantiate() as Node3D
		if node == null:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(2.0, 1.4, 0.2)
			mesh.mesh = box
			mesh.position.y = 0.7
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.55, 0.4, 0.22)
			mesh.material_override = mat
			node = mesh
		node.position = part["pos"]
		node.rotation.y = deg_to_rad(float(part["rot"]))
		ring.add_child(node)
		placed += 1
	if placed <= 0:
		PropVisuals.apply_building_visual(self, &"makeshift_taming_pen", Vector3(3.2, 1.4, 3.2), Color(0.55, 0.4, 0.22))

func _ring_layout() -> Array[Dictionary]:
	return [
		{"pos": Vector3(-1.0, 0.0, -1.92), "rot": 0, "gate": false},
		{"pos": Vector3(1.0, 0.0, -1.92), "rot": 0, "gate": false},
		{"pos": Vector3(-1.0, 0.0, 1.92), "rot": 0, "gate": false},
		{"pos": Vector3(1.0, 0.0, 1.92), "rot": 0, "gate": true},
		{"pos": Vector3(-1.92, 0.0, -1.0), "rot": 90, "gate": false},
		{"pos": Vector3(-1.92, 0.0, 1.0), "rot": 90, "gate": false},
		{"pos": Vector3(1.92, 0.0, -1.0), "rot": 90, "gate": false},
		{"pos": Vector3(1.92, 0.0, 1.0), "rot": 90, "gate": false},
	]
