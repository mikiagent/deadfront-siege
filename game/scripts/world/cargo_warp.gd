extends StaticBody3D
## Camp cargo warp. Sends unstable goods to the home harbour basket for a T-stone fee.

func _ready() -> void:
	add_to_group("cargo_warp")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.6, 1.2)
	mesh.mesh = box
	mesh.position.y = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.45, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.3, 0.8)
	mat.emission_energy_multiplier = 1.2
	mesh.material_override = mat
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position.y = 0.8
	add_child(cs)

func use(player: Player) -> void:
	World.cargo_warp(player)
