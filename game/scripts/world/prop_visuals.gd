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

static func attach_tool_model(anchor: Node3D, def_id: StringName) -> Node3D:
	## Kenney tool GLB parented to the survivor's right-hand anchor.
	if anchor == null:
		return null
	var model_key := tool_model_key(def_id)
	if model_key == "":
		return null
	var path := "res://assets/props/kenney/%s.glb" % model_key
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path)
	if not (packed is PackedScene):
		return null
	var inst := (packed as PackedScene).instantiate() as Node3D
	if inst == null:
		return null
	inst.name = "HeldTool"
	anchor.add_child(inst)
	# ASSUMPTION: handle spans the hand; Kenney tools face +Y up, rotate to grip.
	inst.rotation_degrees = Vector3(0.0, 0.0, -80.0)
	inst.position = Vector3(0.02, 0.02, 0.0)
	inst.scale = Vector3.ONE * 0.55
	return inst

static func tool_model_key(def_id: StringName) -> String:
	var tools: Dictionary = Data.props_manifest.get("tools", {})
	var key := str(def_id)
	if tools.has(key):
		return str(tools[key])
	var def := Data.item(def_id)
	if def == null:
		return ""
	match str(def.tool_class):
		"axe":
			return str(tools.get("work_axe", "tool-axe"))
		"pick":
			return str(tools.get("pick", "tool-pickaxe"))
		"knife":
			# ASSUMPTION: no knife GLB; hammer silhouette stands in.
			return str(tools.get("hammer", "tool-hammer"))
		"hoe":
			return str(tools.get("hoe", "tool-hoe"))
		"shovel":
			return str(tools.get("shovel", "tool-shovel"))
		_:
			return ""

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
	# Portable bedding lies directly on terrain; a large dirt footprint dwarfs it.
	if kind == &"straw_roll":
		return
	# Durango reference: a rough circular dirt patch under every structure, not a slab.
	var dims := footprint(kind)
	var radius := 0.5 * sqrt(float(dims.x * dims.x + dims.y * dims.y)) + 1.0
	var mesh := host.get_node_or_null("Foundation") as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name = "Foundation"
		host.add_child(mesh)
	mesh.mesh = make_disc_mesh(radius)
	mesh.position = Vector3(0.0, 0.08, 0.0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = disc_material(radius, Color(0.62, 0.48, 0.34))

static var _disc_noise: NoiseTexture2D

static func make_disc_mesh(radius: float, segments: int = 28) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := float(i) / float(segments) * TAU
		var a1 := float(i + 1) / float(segments) * TAU
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
	return st.commit()

static func disc_material(radius: float, tint: Color, modulate: Color = Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://scripts/world/dirt_disc.gdshader")
	var dirt := "res://assets/terrain/brown_mud_leaves_01_diff_1k.jpg"
	if ResourceLoader.exists(dirt):
		m.set_shader_parameter("dirt_tex", load(dirt))
	if _disc_noise == null:
		var n := FastNoiseLite.new()
		n.seed = 911
		n.frequency = 0.12
		_disc_noise = NoiseTexture2D.new()
		_disc_noise.width = 128
		_disc_noise.height = 128
		_disc_noise.seamless = true
		_disc_noise.noise = n
	m.set_shader_parameter("noise_tex", _disc_noise)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	m.set_shader_parameter("modulate", modulate)
	return m

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
