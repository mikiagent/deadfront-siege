extends SceneTree
var _started := false
var _done := false
func _process(_d: float) -> bool:
	if _started or root.get_node_or_null("Data") == null:
		return false
	_started = true
	_run.call_deferred()
	return false
func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var kit: Dictionary = load("res://scripts/dev/lab_kit.gd").build(host, 80.0)
	var player: Node3D = kit["player"]
	var cam: Camera3D = kit["cam"]
	cam.size = 14.0
	player.global_position = Vector3(0, 1, 0)
	player.reset_physics_interpolation()
	cam._snap()
	await process_frame
	print("vp=", cam.get_viewport().get_visible_rect().size, " campos=", cam.global_position, " basis=", cam.global_basis, " size=", cam.size, " dist=", cam.distance, " proj=", cam.projection)
	var chest := player.global_position + Vector3.UP * 0.3
	var back := (cam.global_position - chest).normalized()
	print("chest=", chest, " back=", back, " camforward=", -cam.global_basis.z)
	var mid := player.global_position
	print("survivor centre px=", cam.unproject_position(mid), " chest px=", cam.unproject_position(chest))
	var flat := Vector3(back.x, 0.0, back.z).normalized()
	for k in [6.0, 4.0, 3.0]:
		for k2 in ["behind", "front"]:
			var base: Vector3 = Vector3(chest.x, 0, chest.z) + flat * (k if k2 == "front" else -k)
			for y in [0.0, 3.0, 6.0, 9.0]:
				print(k2, " k=", k, " y=", y, " px=", cam.unproject_position(base + Vector3.UP * y))
	quit(0)
