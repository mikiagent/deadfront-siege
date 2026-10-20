class_name Nest
extends StaticBody3D
## A placed egg nest or incubator (kinds in breeding.json nest_kinds) holding one fertilised egg.
## Thin node over Incubation: progress is timestamp-based and lives on the egg stack, so a saved nest
## hatches on the same timestamp after a load. A hatched baby bonds through Bonding; with the roster
## full the ready egg waits in the nest (one notice) until a slot frees.
## Integrator hooks: BuildPlacer/SaveRestore register the kinds (make/from_dict), Player interact calls interact().

const KINDS: Array[StringName] = [&"egg_nest", &"egg_incubator"]

var kind: StringName = &"egg_nest"
var persist_building: bool = true
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var egg: ItemStack
var _tick_left := 0.0
var _waiting_said := false
var _egg_mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("placed_building")
	add_to_group("nest")
	_build_visual()

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)

static func make(p_kind: StringName = &"egg_nest") -> Nest:
	var n := Nest.new()
	n.kind = p_kind if p_kind in KINDS else &"egg_nest"
	n.name = str(n.kind)
	return n

func climate() -> String:
	return str(World.island_def.get("climate", "grassland")) if World else "grassland"

func in_range() -> bool:
	return egg != null and Incubation.temp_ok(StringName(str(egg.attributes.get("species", ""))), kind, climate())

## Puts the first fertilised egg from the bag in an empty nest; otherwise reports the egg's state.
func interact(player: Player) -> bool:
	if egg != null:
		player.notice(status_text())
		return false
	var idx := player.inventory.find_first(Breeding.EGG_ID)
	if idx < 0:
		player.notice("Put a fertilised egg in the nest.")
		return false
	egg = player.inventory.remove_at(idx, 1)
	Incubation.start(egg, Breeding.now())
	_refresh_visual()
	player.notice(status_text())
	return true

func status_text() -> String:
	if egg == null:
		return "Empty nest."
	var sp := str(egg.attributes.get("species", "egg")).capitalize()
	if Incubation.ready(egg):
		return "%s egg is ready to hatch." % sp
	if not in_range():
		var r := Incubation.egg_range(StringName(str(egg.attributes.get("species", ""))))
		return "%s egg is paused: needs %.0f-%.0f C, here is %.0f C. Use an incubator." % [sp, r.x, r.y, Incubation.climate_temp(climate())]
	return "%s egg hatches in %dm." % [sp, ceili(Incubation.remaining_s(egg) / 60.0)]

func _process(delta: float) -> void:
	_tick_left -= delta
	if egg == null or _tick_left > 0.0:
		return
	_tick_left = 1.0
	tick(Breeding.now())

## One incubation step at `at`; hatches into the survivor's roster when done. Returns the baby.
func tick(at: int, rng: RandomNumberGenerator = null) -> PetRecord:
	if egg == null:
		return null
	Incubation.advance(egg, at, in_range())
	if not Incubation.ready(egg):
		return null
	var player := get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null
	if player == null:
		return null
	if not Bonding.can_bond(player):
		if not _waiting_said:
			Bonding.check(player)
			_waiting_said = true
		return null
	var roller := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		roller.randomize()
	var baby := Incubation.hatch(egg, roller)
	if baby == null or not Bonding.try_bond(player, baby):
		return null
	baby.tamer = player.display_name()
	egg = null
	_waiting_said = false
	_refresh_visual()
	player.notice("A %s hatched (grade %s)." % [str(baby.species).capitalize(), baby.grade])
	print("[breed] hatched %s uid=%s sex=%s grade=%s gen=%d" % [baby.species, baby.uid, baby.sex, baby.grade, baby.generation])
	return baby

func to_dict() -> Dictionary:
	return {
		"kind": str(kind),
		"cell": [build_cell.x, build_cell.y],
		"rot": posmod(build_rot, 4),
		"x": global_position.x if is_inside_tree() else position.x,
		"z": global_position.z if is_inside_tree() else position.z,
		"egg": egg.to_dict() if egg else null,
	}

static func from_dict(d: Dictionary) -> Nest:
	var n := make(StringName(str(d.get("kind", "egg_nest"))))
	var cell_v: Variant = d.get("cell", [0, 0])
	if cell_v is Array and (cell_v as Array).size() >= 2:
		n.build_cell = Vector2i(int(cell_v[0]), int(cell_v[1]))
	n.build_rot = int(PetRecord._num(d.get("rot"), 0))
	var e: Variant = d.get("egg", null)
	if e is Dictionary:
		n.egg = ItemStack.from_dict(e as Dictionary)
		if n.egg and n.egg.def_id != Breeding.EGG_ID:
			n.egg = null
	return n

## shortcut: procedural twig ring + egg sphere; a Blender nest/incubator model belongs to the art queue.
func _build_visual() -> void:
	if get_node_or_null("Shape") == null:
		var shape := CollisionShape3D.new()
		shape.name = "Shape"
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 0.5, 1.6)
		shape.shape = box
		shape.position.y = 0.25
		add_child(shape)
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.38
	torus.outer_radius = 0.7
	ring.mesh = torus
	ring.position.y = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.62, 0.7) if kind == &"egg_incubator" else Color(0.48, 0.36, 0.22)
	mat.roughness = 0.9
	ring.material_override = mat
	add_child(ring)
	_egg_mesh = MeshInstance3D.new()
	_egg_mesh.name = "Egg"
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.56
	_egg_mesh.mesh = sphere
	_egg_mesh.position.y = 0.3
	var egg_mat := StandardMaterial3D.new()
	egg_mat.albedo_color = Color(0.93, 0.89, 0.8)
	_egg_mesh.material_override = egg_mat
	add_child(_egg_mesh)
	_refresh_visual()

func _refresh_visual() -> void:
	if _egg_mesh:
		_egg_mesh.visible = egg != null
