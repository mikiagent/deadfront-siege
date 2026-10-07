class_name GroundSnare
extends Node3D
## Visible single-use proximity snare. No collider, direct damage or AI disabling.
var heavy: bool = false
var life_left: float = 120.0
var arm_left: float = 1.0
const RADIUS := 1.25

func _ready() -> void:
	add_to_group("ground_snare")
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = RADIUS - 0.08
	mesh.outer_radius = RADIUS
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.5, 0.15) if heavy else Color(0.7, 0.9, 0.3)
	ring.material_override = mat
	add_child(ring)
	var label := Label3D.new()
	label.text = "Heavy snare" if heavy else "Rope snare"
	label.position.y = 0.3
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	add_child(label)

func _physics_process(delta: float) -> void:
	life_left -= delta
	arm_left = maxf(0.0, arm_left - delta)
	if life_left <= 0.0:
		queue_free()
		return
	if arm_left > 0.0: return
	for node in get_tree().get_nodes_in_group("creatures"):
		var creature := node as Creature
		if creature == null or creature.def == null: continue
		var offset := creature.global_position - global_position
		offset.y = 0
		if offset.length() <= RADIUS and creature.apply_trap_control(heavy):
			queue_free()
			return

func to_dict() -> Dictionary:
	return {"heavy": heavy, "life_left": life_left, "arm_left": arm_left,
		"position": [global_position.x, global_position.y, global_position.z]}

static func restore(row: Dictionary, host: Node) -> GroundSnare:
	var pos: Array = row.get("position", [])
	if pos.size() != 3 or float(row.get("life_left", 0.0)) <= 0.0: return null
	var snare := GroundSnare.new()
	snare.heavy = bool(row.get("heavy", false))
	snare.life_left = clampf(float(row.get("life_left", 0.0)), 0.0, 120.0)
	snare.arm_left = clampf(float(row.get("arm_left", 0.0)), 0.0, 1.0)
	host.add_child(snare)
	snare.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	return snare
