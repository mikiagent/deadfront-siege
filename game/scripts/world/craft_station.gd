class_name CraftStation
extends StaticBody3D
## Workbench or drying rack. Recipes with a matching station_id need the player within 2 m.

@export var station_id: StringName = &"workbench"
var kind: StringName = &"workbench"
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0

func _ready() -> void:
	kind = station_id
	add_to_group("craft_station")
	add_to_group("placed_building")
	add_to_group(str(station_id))
	if get_node_or_null("Shape") == null and get_node_or_null("Prop") == null and get_node_or_null("FallbackMesh") == null:
		PropVisuals.apply_building_visual(self, station_id, _fallback_size(), _fallback_color())
	_ensure_tap_zone()

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
	return {
		"kind": str(station_id),
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"x": global_position.x,
		"z": global_position.z,
	}

static func from_dict(d: Dictionary) -> CraftStation:
	var id := StringName(str(d.get("kind", "workbench")))
	var s := CraftStation.make(id)
	var cell_v: Variant = d.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		s.build_cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	s.build_rot = int(d.get("rot", 0))
	return s

static func make(id: StringName) -> CraftStation:
	var s := CraftStation.new()
	s.station_id = id
	s.kind = id
	s.persist_building = true
	s.name = str(id)
	return s

func _fallback_size() -> Vector3:
	return Vector3(1.6, 0.9, 0.8) if station_id == &"workbench" else Vector3(1.4, 1.4, 0.5)

func _fallback_color() -> Color:
	return Color(0.45, 0.32, 0.18) if station_id == &"workbench" else Color(0.62, 0.55, 0.38)

## A forgiving touch target over the whole visible station. The model's fitted physics box is
## deliberately tight for movement, but that made clicks near the workbench edges hit terrain.
func _ensure_tap_zone() -> void:
	if get_node_or_null("TapZone") != null:
		return
	var zone := Area3D.new()
	zone.name = "TapZone"
	zone.collision_layer = 2
	zone.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var box := BoxShape3D.new()
	var base := PropVisuals.collision_size(station_id, get_node_or_null("Prop") as Node3D, _fallback_size())
	box.size = Vector3(maxf(2.2, base.x + 0.8), maxf(1.6, base.y + 0.5), maxf(1.8, base.z + 0.8))
	cs.shape = box
	cs.position.y = box.size.y * 0.5
	zone.add_child(cs)
	add_child(zone)
