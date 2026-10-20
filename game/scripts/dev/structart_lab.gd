class_name StructartLab
extends Node3D
## The Blender structure set (props_manifest `glb` rows) laid out on a plain floor with the
## drying-rack stages side by side in the middle row. Headless: loads every model, prints a
## summary and quits non-zero on a missing one. Windowed: --shot=<png> [--cam-size=N]
## (10 frames the four drying-rack stages, 28 the whole set).

const ROWS: Array = [
	[&"tent", &"well", &"smoker", &"crock_pot", &"stone_fire_pit", &"catapult"],
	[&"workbench", &"basket", &"mortar", &"steamer", &"campfire", &"bonfire", &"sign"],
	[&"drying_rack:empty", &"drying_rack:raw", &"drying_rack:drying", &"drying_rack:dried"],
	[&"fence", &"fence_gate", &"floor", &"wall", &"wall_doorway", &"roof", &"harbour"],
]
const ROW_Z: Array[float] = [-7.5, -3.0, 0.8, 5.0]
const GAP := 0.9

var _player: Player
var _cam: IsoCamera
var placed := 0
var _layout: Node3D
var missing: Array[String] = []

static func glb_path(kind: StringName, stage: String = "") -> String:
	var row := _row(kind)
	if stage == "":
		return str(row.get("glb", ""))
	for st: Variant in row.get("stages", []):
		if st is Dictionary and str((st as Dictionary).get("id", "")) == stage:
			return str((st as Dictionary).get("glb", ""))
	return ""

static func instance(kind: StringName, stage: String = "") -> Node3D:
	var path := glb_path(kind, stage)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed else null

## Preview of the integrator hook (see the structart report): swap a placed building's Kenney or
## procedural visual for its Blender GLB. Returns false when the kind has no glb row.
static func swap_visual(building: Node3D, stage: String = "") -> bool:
	var kind := StringName(str(building.get("kind")))
	if kind == &"" and building.get("station_id") != null:
		kind = StringName(str(building.get("station_id")))
	if kind == &"gate":
		kind = &"fence_gate"
	var inst := instance(kind, stage)
	if inst == null:
		return false
	for child in building.get_children():
		# FieldCatapult builds its body from bare MeshInstance3D children; buildings use Prop.
		if child.name == &"Prop" or child.name == &"FallbackMesh" or (child is MeshInstance3D and child.name != &"Foundation"):
			building.remove_child(child)
			child.queue_free()
	inst.name = "Prop"
	building.add_child(inst)
	return true

static func _row(kind: StringName) -> Dictionary:
	var buildings: Dictionary = Data.props_manifest.get("buildings", {})
	var row: Variant = buildings.get(str(kind), {})
	return row as Dictionary if row is Dictionary else {}

func _ready() -> void:
	var kit := LabKit.build(self, 70.0)
	_player = kit["player"]
	_cam = kit["cam"]
	# Rows run along the iso camera's screen-right axis so the sheet reads left to right.
	_layout = Node3D.new()
	_layout.name = "Layout"
	_layout.rotation_degrees.y = 45.0
	add_child(_layout)
	for r in ROWS.size():
		_lay_row(ROWS[r], ROW_Z[r])
	# The camera follows the survivor; stand him just in front of the drying racks.
	_player.global_position = _layout.transform * Vector3(0.0, 1.0, 2.9)
	_cam._snap()
	print("[structart] lab placed %d models, missing %s" % [placed, missing])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if missing.is_empty() else 1)

func _lay_row(names: Array, z: float) -> void:
	var widths: Array[float] = []
	var total := 0.0
	for n: StringName in names:
		var w := _width(StringName(str(n).get_slice(":", 0)))
		widths.append(w)
		total += w + GAP
	var x := -total * 0.5
	for i in names.size():
		var parts := str(names[i]).split(":")
		var kind := StringName(parts[0])
		var stage := parts[1] if parts.size() > 1 else ""
		var inst := instance(kind, stage)
		x += widths[i] * 0.5
		if inst == null:
			missing.append(str(names[i]))
		else:
			inst.position = Vector3(x, 0.0, z)
			_layout.add_child(inst)
			placed += 1
		x += widths[i] * 0.5 + GAP

func _width(kind: StringName) -> float:
	var a: Variant = _row(kind).get("aabb_m", [1.0, 1.0, 1.0])
	return float((a as Array)[0]) if a is Array else 1.0
