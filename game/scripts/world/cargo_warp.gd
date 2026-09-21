extends StaticBody3D
## Camp cargo warp: the chest at camp. On an unstable island it ships your unstable goods home
## to the harbour basket for a T-stone fee (World.cargo_warp). Movable in layout mode.

var kind: StringName = &"chest"
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var persist_building: bool = false

func _ready() -> void:
	add_to_group("cargo_warp")
	# Kenney chest with a dirt patch (was a glowing blue placeholder box).
	PropVisuals.apply_building_visual(self, &"chest", Vector3(1.0, 0.8, 0.8), Color(0.45, 0.32, 0.2))

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)

func use(player: Player) -> void:
	World.cargo_warp(player)
