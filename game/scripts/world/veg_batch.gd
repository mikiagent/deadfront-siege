class_name VegBatch
extends Node3D
## One batch per nature model. Harvest nodes keep (batch, index) and hide or show their
## instance instead of owning a mesh. Instances are bucketed into 32 m cells, one MultiMesh
## per occupied cell, so the camera frustum and a per-cell visibility range cull a forest
## cell by cell instead of drawing the whole island whenever any tree is on screen.

const CELL_M := 32.0
## Render distance of a cell, from the camera to the cell centre. The iso camera sits 40 m from
## the survivor at up to size 28; the farthest visible ground point is ~70 m away even at 21:9,
## plus half a cell diagonal (22.6 m), so nothing near the player is ever culled.
## ASSUMPTION: 120 m covers every supported zoom and aspect up to 32:9.
const CELL_RANGE_END_M := 120.0
## ASSUMPTION: props shorter than this (bushes, rocks, plants) cast no shadow; their shadow was
## a few pixels at iso zoom but ~1.3M shadow triangles at camp.
const SMALL_PROP_M := 2.5

static var _height_cache: Dictionary = {}
static var _long_cache: Dictionary = {}

var _mesh: Mesh
var _mesh_h: float = 1.0
## Optional override for every cell this batch creates (the ground-cover foliage sway shader).
var material_override: Material = null
## Optional translucent tint laid over every cell (scenery props: darker than a resource node, so a
## prop never reads as something to tap). Set before commit(); alpha 0 = off.
var overlay_color: Color = Color(0, 0, 0, 0)
## Forces every cell's shadow mode (scenery props: OFF). -1 keeps the per-cell height rule.
var cast_shadow_override: int = -1
var _overlay: StandardMaterial3D = null
## Batch-local transform of every instance, by index (the index harvest nodes keep).
var _xforms: Array[Transform3D] = []
var _committed: bool = false
var _shown: Dictionary = {}
var _cells: Dictionary = {}  # Vector2i -> MultiMeshInstance3D
var _cell_of: Array[Vector2i] = []
var _slot_of: PackedInt32Array = PackedInt32Array()
var _members: Dictionary = {}  # Vector2i -> Array[int] of instance indices

static func get_for(host: Node3D, path: String) -> VegBatch:
	var key := "VegBatch_" + path.get_file().get_basename()
	var existing := host.get_node_or_null(key)
	if existing is VegBatch:
		return existing as VegBatch
	var mesh := _mesh_of(path)
	if mesh == null:
		return null
	var b := VegBatch.new()
	b.name = key
	b._mesh = mesh
	b._mesh_h = maxf(0.05, mesh.get_aabb().size.y)
	host.add_child(b)
	return b

## A batch that draws an arbitrary mesh (a CARD2D billboard quad, a generated prototype mesh)
## under the same cell bucketing, range culling and shadow rule as a GLB batch. `key` names the
## node and must be unique per mesh on the host.
static func get_for_mesh(host: Node3D, key: String, mesh: Mesh) -> VegBatch:
	if mesh == null:
		return null
	var node_name := "VegBatch_mesh_" + key.get_file().get_basename().validate_node_name()
	var existing := host.get_node_or_null(node_name)
	if existing is VegBatch:
		return existing as VegBatch
	var b := VegBatch.new()
	b.name = node_name
	b._mesh = mesh
	b._mesh_h = maxf(0.05, mesh.get_aabb().size.y)
	host.add_child(b)
	return b

## Per-instance transform written after commit (ground cover tilts each tuft to the ground normal
## before the batch is committed; harvest nodes use this for a settled look).
func set_xform(i: int, xf: Transform3D) -> void:
	if i < 0 or i >= _xforms.size():
		return
	_xforms[i] = xf
	if _committed:
		var cell := _cells.get(_cell_of[i]) as MultiMeshInstance3D
		if cell:
			cell.multimesh.set_instance_transform(_slot_of[i], _local_xform(i, cell.position))

func add(xf: Transform3D) -> int:
	var i := _xforms.size()
	_xforms.append(xf)
	var key := Vector2i(floori(xf.origin.x / CELL_M), floori(xf.origin.z / CELL_M))
	if not _members.has(key):
		_members[key] = [] as Array[int]
	var list: Array[int] = _members[key]
	_cell_of.append(key)
	_slot_of.append(list.size())
	list.append(i)
	if _committed:
		_commit_cell(key)
	return i

func commit() -> void:
	for key: Vector2i in _members:
		_commit_cell(key)
	_committed = true

func set_shown(i: int, shown: bool) -> void:
	if i < 0 or i >= _xforms.size() or not _committed:
		return
	_shown[i] = shown
	var cell := _cells.get(_cell_of[i]) as MultiMeshInstance3D
	if cell:
		cell.multimesh.set_instance_transform(_slot_of[i], _local_xform(i, cell.position))

## Number of instances in the batch (all cells).
func instance_count() -> int:
	return _xforms.size()

## The cell node that draws instance i (null before commit).
func cell_for(i: int) -> MultiMeshInstance3D:
	if i < 0 or i >= _xforms.size():
		return null
	return _cells.get(_cell_of[i]) as MultiMeshInstance3D

func _commit_cell(key: Vector2i) -> void:
	var cell := _cells.get(key) as MultiMeshInstance3D
	if cell == null:
		cell = MultiMeshInstance3D.new()
		cell.name = "c%d_%d" % [key.x, key.y]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh
		cell.multimesh = mm
		if material_override != null:
			cell.material_override = material_override
		if overlay_color.a > 0.0:
			# One shared overlay material for the batch: a blended pass over the same geometry.
			if _overlay == null:
				_overlay = StandardMaterial3D.new()
				_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_overlay.albedo_color = overlay_color
				_overlay.disable_receive_shadows = true
			cell.material_overlay = _overlay
		# The node sits at the cell centre so range culling measures from the cell, not the island.
		cell.position = Vector3((float(key.x) + 0.5) * CELL_M, 0.0, (float(key.y) + 0.5) * CELL_M)
		cell.visibility_range_end = CELL_RANGE_END_M
		add_child(cell)
		_cells[key] = cell
	var list: Array[int] = _members[key]
	# Per cell, from this cell's tallest instance, so a late tall add cannot leave cells inconsistent.
	var max_h := 0.0
	for i in list:
		max_h = maxf(max_h, _mesh_h * _xforms[i].basis.get_scale().y)
	if cast_shadow_override >= 0:
		cell.cast_shadow = cast_shadow_override as GeometryInstance3D.ShadowCastingSetting
	else:
		cell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if max_h < SMALL_PROP_M else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	cell.multimesh.instance_count = list.size()
	for slot in list.size():
		cell.multimesh.set_instance_transform(slot, _local_xform(list[slot], cell.position))

func _local_xform(i: int, cell_origin: Vector3) -> Transform3D:
	var xf := _xforms[i]
	if bool(_shown.get(i, true)):
		return Transform3D(xf.basis, xf.origin - cell_origin)
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), xf.origin - cell_origin)

## Largest side in metres of the model's first mesh (AABB), cached per path.
static func mesh_longest(path: String) -> float:
	if _long_cache.has(path):
		return float(_long_cache[path])
	var mesh := _mesh_of(path)
	var n := 1.0
	if mesh:
		var sz := mesh.get_aabb().size
		n = maxf(0.05, maxf(sz.x, maxf(sz.y, sz.z)))
	_long_cache[path] = n
	return n

## Height in metres of the model's first mesh (AABB), cached per path.
static func mesh_height(path: String) -> float:
	if _height_cache.has(path):
		return float(_height_cache[path])
	var mesh := _mesh_of(path)
	var h := 1.0
	if mesh:
		h = maxf(0.05, mesh.get_aabb().size.y)
	_height_cache[path] = h
	return h

static func _mesh_of(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if not packed is PackedScene:
		return null
	var inst: Node = (packed as PackedScene).instantiate()
	var mesh := _first_mesh(inst)
	inst.free()
	if mesh and path.contains("/generated/"):
		_strip_emission(mesh)
	return mesh

## Meshy exports copy the albedo into a full-strength emissive map, which makes generated
## crowns and rocks glow neon under the island light. Nature never self-lights, so drop it.
## The import script (tools/import/strip_emission.gd) already does this; this stays as a guard.
static func _strip_emission(mesh: Mesh) -> void:
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled:
			(mat as BaseMaterial3D).emission_enabled = false

static func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null
