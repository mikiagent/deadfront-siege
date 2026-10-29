class_name TownBuilding
extends StaticBody3D
## TUTORIAL ISLAND town (owner 2026-10-28): a prebuilt, indestructible town building. Never saved
## (persist_building = false), so StructureHealth never counts it as a structure (no creature or
## siege damage), pack-up refuses it ("Camp pieces stay put"), and its grid cells are occupied, so
## nothing is built over it. Roles: "guild" (the Adventurer's Guild, # ASSUMPTION working name: the
## quest hub; a tap opens the Orders sheet with the tutorial orders), "market" (a stall; a tap opens
## the Island Market screen), "decor" (signs, crates, barrels: no action).

var kind: StringName = &"log_shelter"
var role: StringName = &"decor"
var display_name: String = ""
var persist_building: bool = false
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0

static func make(p_kind: StringName, p_role: StringName, p_name: String) -> TownBuilding:
	var b := TownBuilding.new()
	b.kind = p_kind
	b.role = p_role
	b.display_name = p_name
	return b

func _ready() -> void:
	add_to_group("placed_building")
	add_to_group("town_building")
	PropVisuals.apply_building_visual(self, kind, Vector3(3.0, 2.6, 3.0), Color(0.55, 0.42, 0.28))

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)

func pack_up_block_reason() -> String:
	return "Town buildings stay put"

## Tap: PlayerActions.building_interact calls this first. True = handled.
func interact(p: Player) -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	match role:
		&"guild":
			if p:
				p.notice("Adventurer's Guild: your orders")
			if hud and hud.has_method("open_orders"):
				hud.call("open_orders")
			return true
		&"market":
			if hud and hud.has_method("open_market"):
				hud.call("open_market")
			return true
	if p and display_name != "":
		p.notice(display_name)
	return display_name != ""
