class_name Bonfire
extends StaticBody3D
## Interact: Cauterise — clears deep_bleed for 5 HP. Also a cook station (station_id=bonfire).

var kind: StringName = &"bonfire"
var station_id: StringName = &"bonfire"
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var _fire_light: OmniLight3D
var _flicker_phase: float = randf() * TAU

func _ready() -> void:
	add_to_group("placed_building")
	add_to_group("bonfire")
	add_to_group("craft_station")
	if get_node_or_null("Shape") == null and get_node_or_null("Prop") == null and get_node_or_null("FallbackMesh") == null:
		PropVisuals.apply_building_visual(self, kind, Vector3(1.1, 0.7, 1.1), Color(0.85, 0.35, 0.1))
	_setup_fire_light()

func _exit_tree() -> void:
	if World.runtime == null:
		return
	var grid: Variant = World.runtime.get("build_grid")
	if grid is BuildGrid:
		(grid as BuildGrid).release(self)

static func make(p_kind: StringName = &"bonfire") -> Bonfire:
	var b := Bonfire.new()
	b.persist_building = true
	b.kind = p_kind
	b.station_id = &"bonfire" # Shared cook/cauterise recipes; distinct saved building kind.
	b.name = str(p_kind)
	return b

static func from_dict(d: Dictionary) -> Bonfire:
	var saved_kind := StringName(str(d.get("kind", "bonfire")))
	var b := make(&"stone_fire_pit" if saved_kind == &"stone_fire_pit" else &"bonfire")
	var cell_v: Variant = d.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		b.build_cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	b.build_rot = int(d.get("rot", 0))
	return b

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)

func to_dict() -> Dictionary:
	return {
		"kind": str(kind),
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"x": global_position.x,
		"z": global_position.z,
	}

func cauterise(player: Player) -> void:
	if not player.statuses.has(&"deep_bleed"):
		return
	player.downed_by = "the bonfire"
	player.vitals.take_damage(5.0)
	player.statuses.clear_id(&"deep_bleed")
	print("[status] %s -deep_bleed cauterise" % player.name)

func _setup_fire_light() -> void:
	_fire_light = OmniLight3D.new()
	_fire_light.name = "FireLight"
	_fire_light.omni_range = 7.0
	_fire_light.omni_attenuation = 1.4
	_fire_light.light_color = Color(1.0, 0.55, 0.25)
	_fire_light.light_energy = 0.0
	_fire_light.shadow_enabled = false
	_fire_light.position = Vector3(0.0, 0.55, 0.0)
	add_child(_fire_light)
	set_process(true)

func _process(_delta: float) -> void:
	if _fire_light == null:
		return
	var phase := Game.phase_name()
	var on := phase == &"night" or phase == &"dusk" or phase == &"dawn"
	if not on:
		_fire_light.light_energy = 0.0
		return
	var flicker := 1.0 + sin((Time.get_ticks_msec() * 0.001) * 6.5 + _flicker_phase) * 0.12
	flicker += sin((Time.get_ticks_msec() * 0.001) * 13.0 + _flicker_phase * 0.7) * 0.05
	_fire_light.light_energy = 3.6 * flicker
