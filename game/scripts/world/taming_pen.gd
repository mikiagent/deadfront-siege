class_name TamingPen
extends StaticBody3D
## Holds one captured animal. 30 real minutes, scaled by Game.time_scale.

const BASE_SECONDS := 30.0 * 60.0
const SUCCESS_CHANCE := 0.70 ## ASSUMPTION:

var occupant: ItemStack
var remaining: float = 0.0
var running: bool = false
var force_result: int = 0

func _ready() -> void:
	add_to_group("taming_pen")
	_build_mesh(Color(0.55, 0.4, 0.22))

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

func _build_mesh(color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.2, 1.4, 3.2)
	mesh.mesh = box
	mesh.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(3.2, 1.4, 3.2)
	cs.shape = sh
	cs.position.y = 0.7
	add_child(cs)
