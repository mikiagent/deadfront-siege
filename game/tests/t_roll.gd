extends SceneTree
## MEASUREMENT PASS 2 (temporary, replaced by the ROLL acceptance spec below)
var _started := false
var host: Node3D
var player
var data: Node

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("World") == null:
		return false
	_started = true
	data = get_root().get_node("Data")
	_run.call_deferred()
	return false

func _run() -> void:
	print("[t_roll] has hunt_hud=%s" % ResourceLoader.exists("res://scripts/ui/hunt_hud.gd"))
	host = Node3D.new()
	host.name = "TRollMeasure2"
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var cam := Camera3D.new()
	host.add_child(cam)
	cam.position = Vector3(0, 12, 12)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(20, 4, 1)
	ws.shape = wb
	wall.add_child(ws)
	wall.position = Vector3(0, 2, -3)
	host.add_child(wall)
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	player.vitals.max_health = 1000.0
	player.vitals.health = 1000.0
	for i in 30:
		await physics_frame
	var start: Vector3 = player.global_position
	player.sim.try_roll(Vector3(0, 0, -1))
	while player.rolling:
		await physics_frame
	print("[t_roll] wall dist=%.3f m" % (player.global_position - start).length())
	for i in 40:
		await physics_frame
	player.global_position = Vector3(0, 1.0, 4)
	await physics_frame
	var d = (load("res://scenes/creatures/creature.tscn") as PackedScene).instantiate()
	d.position = Vector3(0, 0, 2.0)
	host.add_child(d)
	d.spawn(data.creature(&"deinonychus"))
	d.brain.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 5:
		await physics_frame
	print("[t_roll] creature group=%s dist=%.2f" % [d.is_in_group("creatures"), player.global_position.distance_to(d.global_position)])
	print("[t_roll] MEASURE2 DONE")
	host.queue_free()
	await process_frame
	quit(0)
