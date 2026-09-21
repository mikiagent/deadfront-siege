class_name VegBatch
extends MultiMeshInstance3D
## One MultiMesh per nature model. Harvest nodes keep (batch, index) and hide or show their
## instance instead of owning a mesh, so a forest costs one draw call per model.

static var _height_cache: Dictionary = {}

var _xforms: Array[Transform3D] = []
var _committed: bool = false

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
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	b.multimesh = mm
	# A batch contains transforms across the whole island, but its Node3D origin stays at the
	# island origin. Godot distance-culls the whole MultiMesh from that origin, so walking more
	# than 95 m away hid even instances beside the player while their HarvestNodes stayed live.
	# Leave range culling off; camera-frustum culling still skips the single batched draw call.
	b.visibility_range_end = 0.0
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	host.add_child(b)
	return b

func add(xf: Transform3D) -> int:
	_xforms.append(xf)
	if _committed:
		commit()
	return _xforms.size() - 1

func commit() -> void:
	multimesh.instance_count = _xforms.size()
	for i in _xforms.size():
		multimesh.set_instance_transform(i, _xforms[i])
	_committed = true

func set_shown(i: int, shown: bool) -> void:
	if i < 0 or i >= _xforms.size() or not _committed:
		return
	if shown:
		multimesh.set_instance_transform(i, _xforms[i])
	else:
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), _xforms[i].origin))

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
	return mesh

static func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null
