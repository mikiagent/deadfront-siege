extends SceneTree
## Web shader containment regression. Compatibility/Web can hold 1,024 global shader-variable
## buffer items, while Godot reserves 16 items for every geometry instance that uses an instance
## uniform. A real home island in web mode must therefore compile without any instance uniforms.
## Run: Godot --headless --path game --script res://tests/t_webshader.gd

const ITEMS_PER_INSTANCE := 16
const WEB_BUFFER_ITEMS := 1024

var _started := false
var _failures: Array[String] = []

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
	print("[t_webshader] %s %s" % ["ok" if ok else "FAIL", what])

func _run() -> void:
	var world: Node = get_root().get_node("World")
	var data: Node = get_root().get_node("Data")
	_expect(not Occlusion.enabled_for(true, false), "web disables per-instance occlusion")
	_expect(Occlusion.enabled_for(false, false), "native keeps occlusion by default")
	_expect(not Occlusion.enabled_for(false, true), "the native kill switch still disables occlusion")
	var rules: Dictionary = data.world_rules
	var kept_render: Variant = rules.get("resource_render", "card")
	var kept_occlusion: bool = Occlusion.enabled
	rules["resource_render"] = "card"
	# This is the shipped web policy. Native behavior is covered by t_occlude2 and t_card2d.
	Occlusion.enabled = false
	var host := Node3D.new()
	host.name = "WebShaderTest"
	get_root().add_child(host)
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	await process_frame
	await process_frame

	var instances := 0
	var geometry := 0
	for node: Node in host.find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		if gi == null:
			continue
		geometry += 1
		if not _geometry_uses_instance_uniform(gi):
			continue
		if gi is MultiMeshInstance3D:
			var mm := (gi as MultiMeshInstance3D).multimesh
			instances += mm.instance_count if mm != null else 0
		else:
			instances += 1
	var items := instances * ITEMS_PER_INSTANCE
	print("[t_webshader] geometry=%d instance_uniform_instances=%d items=%d limit=%d" % [
		geometry, instances, items, WEB_BUFFER_ITEMS])
	_expect(instances == 0, "web island materials contain no instance uniforms (%d instances)" % instances)
	_expect(items <= WEB_BUFFER_ITEMS, "web shader-variable allocation stays inside %d items (%d)" % [WEB_BUFFER_ITEMS, items])

	rules["resource_render"] = kept_render
	Occlusion.enabled = kept_occlusion
	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("[t_webshader] PASS")
		quit(0)
	else:
		print("[t_webshader] FAIL count=%d" % _failures.size())
		quit(1)

func _geometry_uses_instance_uniform(gi: GeometryInstance3D) -> bool:
	for mat: Material in _materials(gi):
		if mat is ShaderMaterial:
			var shader := (mat as ShaderMaterial).shader
			if shader != null and _expanded_shader(shader).contains("instance uniform"):
				return true
	return false

func _materials(gi: GeometryInstance3D) -> Array[Material]:
	var out: Array[Material] = []
	if gi.material_override != null:
		out.append(gi.material_override)
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		var mi := gi as MeshInstance3D
		mesh = mi.mesh
		if mesh != null:
			for surface in mesh.get_surface_count():
				var override := mi.get_surface_override_material(surface)
				if override != null:
					out.append(override)
	elif gi is MultiMeshInstance3D:
		var mm := (gi as MultiMeshInstance3D).multimesh
		mesh = mm.mesh if mm != null else null
	if mesh != null:
		for surface in mesh.get_surface_count():
			var mat := mesh.surface_get_material(surface)
			if mat != null:
				out.append(mat)
	return out

func _expanded_shader(shader: Shader) -> String:
	return _expand_includes(shader.code, shader.resource_path.get_base_dir(), {})

func _expand_includes(source: String, base: String, seen: Dictionary) -> String:
	var out := PackedStringArray()
	for line in source.split("\n"):
		var trimmed := line.strip_edges()
		if not trimmed.begins_with("#include"):
			out.append(line)
			continue
		var first := trimmed.find('"')
		var last := trimmed.find('"', first + 1)
		if first < 0 or last <= first:
			out.append(line)
			continue
		var include_path := trimmed.substr(first + 1, last - first - 1)
		if not include_path.begins_with("res://"):
			include_path = base.path_join(include_path).simplify_path()
		if seen.has(include_path):
			continue
		seen[include_path] = true
		var included := FileAccess.get_file_as_string(include_path)
		out.append(_expand_includes(included, include_path.get_base_dir(), seen))
	return "\n".join(out)
