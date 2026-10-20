extends StaticBody3D
## The dock. Opens the sea-route list; travel is a fade + load, never ocean sailing. Movable in
## layout mode (3x6 footprint); HarbourSite keeps it on the coast with the pier pointing out to
## sea along local -Z. The island's harbour marker follows it.
## Visual: the props_manifest "harbour" row (glb, else Kenney model) when one exists, else a
## composite of textured Kenney props: plank pier on log piles, canvas shed, cargo, rope, log raft.

const KENNEY := "res://assets/props/kenney/%s.glb"
const FEET_Y := -0.75  # world height of the pile feet; the deck stands DECK_H above them
const DECK_H := 1.2  # same as the Blender pier.glb, so it can replace the composite by data alone

var kind: StringName = &"harbour"
var build_cell: Vector2i = Vector2i.ZERO
var build_rot: int = 0
var persist_building: bool = false
var _visual: Node3D
var _shape: CollisionShape3D

func _ready() -> void:
	add_to_group("harbour")
	_visual = _manifest_model()
	if _visual == null:
		_visual = _composite()
	_visual.name = "Visual"
	add_child(_visual)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.3, 8.0)  # deck, shed and cargo, out to the pier's seaward end
	_shape.shape = box
	add_child(_shape)
	_level()

func set_grid_pose(cell: Vector2i, rot: int) -> void:
	var moved := cell != build_cell or posmod(rot, 4) != build_rot
	build_cell = cell
	build_rot = posmod(rot, 4)
	rotation.y = deg_to_rad(float(build_rot) * 90.0)
	_level()
	var rt := get_parent()
	if rt and rt.get("_harbour_pos") != null:
		rt.set("_harbour_pos", global_position)
	# A layout move carries the walkable approach strip along; pathing samples it at setup.
	if moved and rt and rt.get("pathing") != null and rt.has_method("_setup_pathing"):
		rt.call("_setup_pathing")

func open() -> void:
	(load("res://scripts/ui/world_ui.gd") as GDScript).ensure().show_harbour()

## The grid puts the origin at the footprint's mean ground height; the pier stands on the water.
func _level() -> void:
	if _visual == null or not is_inside_tree():
		return
	_visual.position.y = FEET_Y - global_position.y
	_shape.position = Vector3(0.0, _visual.position.y + DECK_H + 0.85, -1.0)

func _manifest_model() -> Node3D:
	var row: Variant = (Data.props_manifest.get("buildings", {}) as Dictionary).get("harbour", null)
	if not row is Dictionary:
		return null
	var path := str((row as Dictionary).get("glb", ""))
	if path == "":
		path = PropVisuals.model_path(kind)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed else null

## Local frame: x across the pier, landward edge at z = +3, deck from z = +3 out to z = -5.
func _composite() -> Node3D:
	var root := Node3D.new()
	for i in 4:
		_prop(root, "floor", Vector3(0.0, DECK_H - 0.2, 2.0 - 2.0 * float(i)))
	for z in [2.9, 1.0, -1.0, -3.0, -4.85]:
		for x in [-0.92, 0.92]:
			# Kenney log lies along z; stood up and thinned it is a 2.2 m pile, top flush with the deck.
			_prop(root, "tree-log", Vector3(x, DECK_H - 1.1, z), Vector3(90.0, 0.0, 0.0), Vector3(0.26, 0.26, 0.55))
	_prop(root, "structure-canvas", Vector3(0.0, DECK_H, 1.95), Vector3(0.0, 90.0, 0.0), Vector3(0.95, 0.95, 0.95))
	_prop(root, "box", Vector3(0.5, DECK_H, -0.3), Vector3(0.0, 12.0, 0.0), Vector3.ONE * 0.62)
	_prop(root, "box", Vector3(0.52, DECK_H + 0.62, -0.32), Vector3(0.0, -20.0, 0.0), Vector3.ONE * 0.45)
	_prop(root, "barrel", Vector3(-0.5, DECK_H, -0.7), Vector3.ZERO, Vector3.ONE * 0.58)
	_prop(root, "box-large", Vector3(0.48, DECK_H, -1.6), Vector3(0.0, 4.0, 0.0), Vector3(0.6, 0.55, 0.5))
	_prop(root, "bucket", Vector3(-0.55, DECK_H, -2.3), Vector3.ZERO, Vector3.ONE * 0.7)
	_prop(root, "fish-large", Vector3(0.2, DECK_H, -2.9), Vector3(0.0, 35.0, 0.0), Vector3.ONE * 0.55)
	for x in [-0.82, 0.82]:
		_prop(root, "tree-trunk", Vector3(x, DECK_H, -4.65), Vector3.ZERO, Vector3(0.3, 0.42, 0.3))
		_rope(root, Vector3(x, DECK_H + 0.2, -4.65), 0.12, 0.2)
	_rope(root, Vector3(-0.45, DECK_H + 0.03, -3.8), 0.18, 0.3)
	# A log raft moored alongside, floating at the waterline (water is 0.7 m above the pile feet).
	for i in 3:
		_prop(root, "tree-log-small", Vector3(2.5 + 0.42 * float(i), 0.5, -3.9), Vector3(0.0, 8.0, 0.0), Vector3(0.42, 0.4, 0.8))
	return root

func _prop(parent: Node3D, model: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> void:
	var packed := load(KENNEY % model) as PackedScene
	if packed == null:
		return
	var n := packed.instantiate() as Node3D
	n.position = pos
	n.rotation_degrees = rot_deg
	n.scale = scale_v
	parent.add_child(n)

func _rope(parent: Node3D, pos: Vector3, inner: float, outer: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 24
	torus.ring_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.5, 0.33)
	mat.roughness = 0.95
	torus.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.position = pos
	mi.scale = Vector3(1.0, 0.6, 1.0)
	parent.add_child(mi)
