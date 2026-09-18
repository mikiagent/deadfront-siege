class_name CraftStation
extends StaticBody3D
## Workbench or drying rack. Recipes with a matching station_id need the player within 2 m.

@export var station_id: StringName = &"workbench"

func _ready() -> void:
	add_to_group("craft_station")
	add_to_group(str(station_id))
	if get_child_count() > 0:
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 0.9, 0.8) if station_id == &"workbench" else Vector3(1.4, 1.4, 0.5)
	mesh.mesh = box
	mesh.position.y = box.size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.32, 0.18) if station_id == &"workbench" else Color(0.62, 0.55, 0.38)
	mesh.material_override = mat
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = box.size
	cs.shape = sh
	cs.position.y = box.size.y * 0.5
	add_child(cs)

static func make(id: StringName) -> CraftStation:
	var s := CraftStation.new()
	s.station_id = id
	s.name = str(id)
	return s
