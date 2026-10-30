extends SceneTree
## NORTHUP (owner 2026-10-29: "north is up and south is down"). World axes: north = -Z, south = +Z,
## east = +X, west = -X. The shipped IsoCamera must show north up the screen, the stick's "up" must walk
## north, the southern-most dock must sit below the island centre on screen, the HUD minimap (drawn
## turned by the camera yaw) must be north-up, and the "X n  Y n" readout's Y must grow northward.
## Usage: godot --headless --path game --script res://tests/t_northup.gd   -> "[t_northup] PASS", exit 0/1.

var failures: Array[String] = []
var _started := false

func _process(_delta: float) -> bool:
	if _started:
		return false
	if get_root() == null or get_root().get_node_or_null("Data") == null or get_root().get_node_or_null("Game") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _expect(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)
	print("[t_northup] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	var host := Node3D.new()
	get_root().add_child(host)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(160, 1, 160)
	fs.shape = box
	floor.add_child(fs)
	floor.position.y = -0.5
	host.add_child(floor)
	var player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0, 1.0, 0)
	host.add_child(player)
	var Iso: GDScript = load("res://scripts/camera/iso_camera.gd")
	var cam = Iso.new()
	cam.target_path = player.get_path()
	host.add_child(cam)
	cam.current = true
	for i in 3:
		await process_frame

	# The compass on screen: north up, south down, east right, west left.
	var o: Vector3 = player.global_position
	var c: Vector2 = cam.unproject_position(o)
	var n: Vector2 = cam.unproject_position(o + Vector3(0, 0, -5))
	var s: Vector2 = cam.unproject_position(o + Vector3(0, 0, 5))
	var e: Vector2 = cam.unproject_position(o + Vector3(5, 0, 0))
	var w: Vector2 = cam.unproject_position(o + Vector3(-5, 0, 0))
	_expect(n.y < c.y - 20.0 and absf(n.x - c.x) < 1.0, "north (-Z) is straight up the screen (%s from %s)" % [n, c])
	_expect(s.y > c.y + 20.0 and absf(s.x - c.x) < 1.0, "south (+Z) is straight down (%s)" % s)
	_expect(e.x > c.x + 20.0 and absf(e.y - c.y) < 1.0, "east (+X) is right (%s)" % e)
	_expect(w.x < c.x - 20.0 and absf(w.y - c.y) < 1.0, "west (-X) is left (%s)" % w)

	# Movement stays camera-relative: stick up walks north, left walks west.
	var up: Vector3 = player.sim.cam_dir(Vector2(0, -1))
	var left: Vector3 = player.sim.cam_dir(Vector2(-1, 0))
	_expect(up.distance_to(Vector3(0, 0, -1)) < 0.01, "stick up walks north (%s)" % up)
	_expect(left.distance_to(Vector3(-1, 0, 0)) < 0.01, "stick left walks west, not south (%s)" % left)
	var z0: float = player.global_position.z
	Input.action_press("move_up")
	for i in 20:
		await physics_frame
	Input.action_release("move_up")
	_expect(player.global_position.z < z0 - 0.5, "holding move_up goes north (z %.2f -> %.2f)" % [z0, player.global_position.z])
	var hud_y := -roundi(player.global_position.z)
	_expect(hud_y > -roundi(z0), "the readout's Y (= -z) grows walking up (%d -> %d)" % [-roundi(z0), hud_y])

	# The dock on the southern-most coast is below the island centre on screen.
	var isle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/islands/tutorial_isle.json"))
	var hb: Array = isle.get("harbour", [0, 0, 0])
	var dock := Vector3(float(hb[0]), 0.0, float(hb[2]))
	_expect(dock.z > 0.0, "tutorial isle: the stored dock is south of the centre (z %.0f)" % dock.z)
	var from_centre: Vector2 = cam.unproject_position(o + dock.normalized() * 5.0) - cam.unproject_position(o)  # the bearing: 317 m is past the far plane
	_expect(from_centre.y > absf(from_centre.x), "the dock projects into the lower half from the island centre (%s)" % from_centre)

	# HUD minimap: drawn turned by the camera's yaw, so a zero yaw is north-up (and the atlas is north-up).
	_expect(absf(cam.global_rotation.y) < 1e-4 and is_zero_approx(float(Iso.YAW_DEG)), "minimap turn (camera yaw) is 0: north-up")
	_expect(is_zero_approx(float(ProjectSettings.get_setting("shader_globals/camera_yaw_deg", {}).get("value", -1.0))), "project.godot's camera_yaw_deg default is 0")

	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_northup] PASS")
		quit(0)
	else:
		print("[t_northup] FAIL count=%d" % failures.size())
		quit(1)
