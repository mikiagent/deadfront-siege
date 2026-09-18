extends StaticBody3D
## Opens the sea-route list. Travel is a fade + load, never ocean sailing.

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

func open() -> void:
	(load("res://scripts/ui/world_ui.gd") as GDScript).ensure().show_harbour()
