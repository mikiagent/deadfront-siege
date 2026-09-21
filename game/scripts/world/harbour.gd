extends StaticBody3D
## The dock. Opens the sea-route list; travel is a fade + load, never ocean sailing. Movable in
## layout mode (3x6 footprint, may sit on the shore); the island's harbour marker follows it.

var kind: StringName = &"harbour"
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var persist_building: bool = false

func _ready() -> void:
	add_to_group("harbour")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 0.4, 6.0)
	mesh.mesh = box
	mesh.position.y = 0.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.32, 0.28)
	mesh.material_override = mat
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position.y = 0.2
	add_child(cs)

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)
	var rt := get_parent()
	if rt and rt.get("_harbour_pos") != null:
		rt.set("_harbour_pos", global_position)

func open() -> void:
	(load("res://scripts/ui/world_ui.gd") as GDScript).ensure().show_harbour()
