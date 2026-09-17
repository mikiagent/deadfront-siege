class_name Bonfire
extends StaticBody3D
## Interact: Cauterise — clears deep_bleed for 5 HP.

func _ready() -> void:
	add_to_group("bonfire")
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 0.7, 1.1)
	mesh.mesh = box
	mesh.position.y = 0.35
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.35, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.1, 0.7, 1.1)
	cs.shape = sh
	cs.position.y = 0.35
	add_child(cs)

func cauterise(player: Player) -> void:
	if not player.statuses.has(&"deep_bleed"):
		return
	player.vitals.take_damage(5.0)
	player.statuses.clear_id(&"deep_bleed")
	print("[status] %s -deep_bleed cauterise" % player.name)
