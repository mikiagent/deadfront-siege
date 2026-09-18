class_name PropVisuals
extends RefCounted
## Shared helpers for manifest-driven prop visuals, collision and foundations.

const FOUNDATION_HEIGHT := 0.15

static func footprint(kind: StringName) -> Vector2i:
	var row := _building_row(kind)
	var fp: Variant = row.get("footprint", [1, 1])
	if fp is Array and fp.size() >= 2:
		return Vector2i(maxi(1, int(fp[0])), maxi(1, int(fp[1])))
	return Vector2i.ONE

static func apply_building_visual(host: Node3D, kind: StringName, fallback_size: Vector3, fallback_color: Color) -> Dictionary:
	var model := attach_model(host, kind)
	if model == null:
		model = _fallback_mesh(host, fallback_size, fallback_color)
	var collision := collision_size(kind, model, fallback_size)
	ensure_collision(host, collision)
	ensure_foundation(host, kind)
	return {"model": model, "collision": collision}

static func attach_model(host: Node3D, kind: StringName) -> Node3D:
	var path := model_path(kind)
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if not (packed is PackedScene):
		return null
	var inst := (packed as PackedScene).instantiate() as Node3D
	if inst == null:
		return null
	inst.name = "Prop"
	host.add_child(inst)
	return inst

static func model_path(kind: StringName) -> String:
	var row := _building_row(kind)
	var model := str(row.get("model", ""))
	if model == "":
		return ""
	return "res://assets/props/kenney/%s.glb" % model

static func collision_size(kind: StringName, model_root: Node3D, fallback_size: Vector3 = Vector3.ONE) -> Vector3:
	var row := _building_row(kind)
	var model_name := str(row.get("model", ""))
	if model_name != "":
		var sizes: Dictionary = Data.props_manifest.get("model_sizes_m", {})
		var raw: Variant = sizes.get(model_name, null)
		if raw is Array and (raw as Array).size() >= 3:
			var arr := raw as Array
			return Vector3(maxf(0.2, float(arr[0])), maxf(0.2, float(arr[2])), maxf(0.2, float(arr[1])))
	if model_root:
		var measured := _measure_aabb(model_root)
		if measured != Vector3.ZERO:
			return measured
	return Vector3(maxf(0.2, fallback_size.x), maxf(0.2, fallback_size.y), maxf(0.2, fallback_size.z))

static func ensure_collision(host: Node3D, size: Vector3) -> void:
	var cs := host.get_node_or_null("Shape") as CollisionShape3D
	if cs == null:
		cs = CollisionShape3D.new()
		cs.name = "Shape"
		host.add_child(cs)
	var box := cs.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		cs.shape = box
	box.size = size
	cs.position = Vector3(0.0, size.y * 0.5, 0.0)

static func ensure_foundation(host: Node3D, kind: StringName) -> void:
	var dims := footprint(kind)
	var mesh := host.get_node_or_null("Foundation") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "Foundation"
		host.add_child(mesh)
	var box := BoxMesh.new()
	box.size = Vector3(maxf(0.5, float(dims.x)), FOUNDATION_HEIGHT, maxf(0.5, float(dims.y)))
	mesh.mesh = box
	mesh.position = Vector3(0.0, FOUNDATION_HEIGHT * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.41, 0.30, 0.19, 0.92)
	mat.roughness = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat

static func _fallback_mesh(host: Node3D, size: Vector3, color: Color) -> Node3D:
	var mesh := host.get_node_or_null("FallbackMesh") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "FallbackMesh"
		host.add_child(mesh)
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = Vector3(0.0, size.y * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	return mesh

static func _building_row(kind: StringName) -> Dictionary:
	var key := str(kind)
	if key == "gate":
		key = "fence_gate"
	elif key == "makeshift_taming_pen":
		key = "taming_pen"
	var buildings: Dictionary = Data.props_manifest.get("buildings", {})
	var row: Variant = buildings.get(key, {})
	if row is Dictionary:
		return row as Dictionary
	return {}

static func _measure_aabb(root: Node3D) -> Vector3:
	var pts: Array[Vector3] = []
	_collect_mesh_points(root, Transform3D.IDENTITY, pts)
	if pts.is_empty():
		return Vector3.ZERO
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo.x = minf(lo.x, p.x)
		lo.y = minf(lo.y, p.y)
		lo.z = minf(lo.z, p.z)
		hi.x = maxf(hi.x, p.x)
		hi.y = maxf(hi.y, p.y)
		hi.z = maxf(hi.z, p.z)
	return Vector3(
		maxf(0.2, hi.x - lo.x),
		maxf(0.2, hi.y - lo.y),
		maxf(0.2, hi.z - lo.z)
	)

static func _collect_mesh_points(node: Node, parent_xf: Transform3D, out_pts: Array[Vector3]) -> void:
	var current := parent_xf
	if node is Node3D:
		current = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var aabb := mi.mesh.get_aabb()
			var corners := [
				aabb.position,
				aabb.position + Vector3(aabb.size.x, 0, 0),
				aabb.position + Vector3(0, aabb.size.y, 0),
				aabb.position + Vector3(0, 0, aabb.size.z),
				aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
				aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
				aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
				aabb.position + aabb.size,
			]
			for p in corners:
				out_pts.append(current * p)
	for child in node.get_children():
		_collect_mesh_points(child, current, out_pts)
