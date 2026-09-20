extends StaticBody3D
## Camp cargo warp. Sends unstable goods to the home harbour basket for a T-stone fee.

var kind: StringName = &"chest"

func _ready() -> void:
	add_to_group("cargo_warp")
	# Kenney chest with a dirt patch (was a glowing blue placeholder box).
	PropVisuals.apply_building_visual(self, &"chest", Vector3(1.0, 0.8, 0.8), Color(0.45, 0.32, 0.2))

func use(player: Player) -> void:
	World.cargo_warp(player)
