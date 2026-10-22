extends SceneTree
## probe: placed sizes

var _started := false

func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 6.0)
	(kit["nav"] as Node).queue_free()
	var world: Node = root.get_node("World")
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	await physics_frame
	var props: Node = (world.runtime as Node).get("props")
	var seen := {}
	for r in props.get("_rows"):
		var kind := str(r["kind"])
		var path := str(r["path"])
		if not path.contains("/biome/"):
			continue
		if seen.has(kind):
			continue
		seen[kind] = true
		var b: VegBatch = r["batch"]
		var mesh: Mesh = b.get("_mesh")
		var sc := float(r["scale"])
		var aabb := mesh.get_aabb().size * sc
		print("[probe] %-13s scale=%.2f world=(%.2f,%.2f,%.2f) radius=%.2f path=%s" % [kind, sc, aabb.x, aabb.y, aabb.z, float(r["radius"]), path.get_file()])
	quit(0)
