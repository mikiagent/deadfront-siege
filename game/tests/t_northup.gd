extends SceneTree
## Compass and camera yaw. World axes: north = -Z, south = +Z, east = +X, west = -X. NORTHUP (2026-10-29)
## put north up the screen; ISOCAM (owner 2026-10-30: "i like the isometric look better") put the Durango
## 45 deg diagonal back: north up-right, the town's south-east corners nearest the camera, the stick
## screen-relative, the minimap turned with the camera and its N marker on north, the "X n  Y n" readout
## in world coordinates (Y grows northward).
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

	# ISOCAM (owner 2026-10-30, overriding NORTHUP's yaw 0): the Durango diagonal is back. Camera yaw 45,
	# looking north-west: north is up-right on screen, east down-right, south down-left, west up-left.
	var o: Vector3 = player.global_position
	var c: Vector2 = cam.unproject_position(o)
	var n: Vector2 = cam.unproject_position(o + Vector3(0, 0, -5)) - c
	var s: Vector2 = cam.unproject_position(o + Vector3(0, 0, 5)) - c
	var e: Vector2 = cam.unproject_position(o + Vector3(5, 0, 0)) - c
	var w: Vector2 = cam.unproject_position(o + Vector3(-5, 0, 0)) - c
	# A diamond: each axis runs along a screen diagonal, flattened vertically by the pitch (dy/dx = sin 38.7).
	var diag := func (v: Vector2, want: Vector2) -> bool: return v.x * want.x > 20.0 and v.y * want.y > 20.0 and absf(absf(v.y / v.x) - sin(deg_to_rad(38.7))) < 0.05
	_expect(diag.call(n, Vector2(1, -1)), "north (-Z) is up-right on screen (%s)" % n)
	_expect(diag.call(s, Vector2(-1, 1)), "south (+Z) is down-left (%s)" % s)
	_expect(diag.call(e, Vector2(1, 1)), "east (+X) is down-right (%s)" % e)
	_expect(diag.call(w, Vector2(-1, -1)), "west (-X) is up-left (%s)" % w)
	# A grid-aligned building's south-east corner is the one nearest the camera (its lowest on screen).
	var corners := [Vector3(-4, 0, -4), Vector3(4, 0, -4), Vector3(-4, 0, 4), Vector3(4, 0, 4)]
	var low := 0
	for i in corners.size():
		if cam.unproject_position(o + corners[i]).y > cam.unproject_position(o + corners[low]).y:
			low = i
	_expect(low == 3, "the south-east corner of a square sits lowest on screen (corner %d)" % low)

	# Movement stays screen-relative: stick up walks up the screen (north-west), left walks south-west.
	var up: Vector3 = player.sim.cam_dir(Vector2(0, -1))
	var left: Vector3 = player.sim.cam_dir(Vector2(-1, 0))
	_expect(up.distance_to(Vector3(-1, 0, -1).normalized()) < 0.01, "stick up walks north-west, up the screen (%s)" % up)
	_expect(left.distance_to(Vector3(-1, 0, 1).normalized()) < 0.01, "stick left walks south-west, left on screen (%s)" % left)
	var z0: float = player.global_position.z
	var x0: float = player.global_position.x
	var c0: Vector2 = cam.unproject_position(player.global_position)
	Input.action_press("move_up")
	for i in 20:
		await physics_frame
	Input.action_release("move_up")
	await process_frame
	_expect(player.global_position.z < z0 - 0.3 and player.global_position.x < x0 - 0.3, "holding move_up goes north-west (x %.2f -> %.2f, z %.2f -> %.2f)" % [x0, player.global_position.x, z0, player.global_position.z])
	# The readout keeps world coordinates: X = world x, Y = -world z (north-positive), whatever the camera.
	var hud_y := -roundi(player.global_position.z)
	_expect(hud_y > -roundi(z0), "the readout's Y (= -z) grows walking north (%d -> %d)" % [-roundi(z0), hud_y])

	# The dock on the southern-most coast is below the island centre on screen (down-left).
	var isle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/islands/tutorial_isle.json"))
	var hb: Array = isle.get("harbour", [0, 0, 0])
	var dock := Vector3(float(hb[0]), 0.0, float(hb[2]))
	_expect(dock.z > 0.0, "tutorial isle: the stored dock is south of the centre (z %.0f)" % dock.z)
	var from_centre: Vector2 = cam.unproject_position(o + dock.normalized() * 5.0) - cam.unproject_position(o)  # the bearing: 317 m is past the far plane
	_expect(from_centre.y > 0.0, "the dock projects into the lower half from the island centre (%s)" % from_centre)

	# HUD minimap: drawn turned by the camera's yaw, so screen-up on the map is screen-up in the world,
	# and its N marker points where north lies on screen (the atlas stays north-up).
	var map_n := Vector2(0, -1).rotated(cam.global_rotation.y)
	_expect(map_n.x > 0.0 and map_n.y < 0.0 and map_n.dot(n.normalized()) > 0.95, "the minimap's N marker (%s) points where north is on screen (%s)" % [map_n, n.normalized()])
	_expect(is_equal_approx(float(Iso.YAW_DEG), 45.0) and absf(rad_to_deg(cam.global_rotation.y) - 45.0) < 0.01, "camera yaw 45")
	_expect(is_equal_approx(float(ProjectSettings.get_setting("shader_globals/camera_yaw_deg", {}).get("value", -1.0)), 45.0), "project.godot's camera_yaw_deg default is 45")
	# Zoomed right in the yaw stays put (the camera never swings round behind her facing).
	cam.size = Iso.MIN_SIZE
	await process_frame
	_expect(absf(rad_to_deg(cam.global_rotation.y) - 45.0) < 0.01, "zoomed in, the yaw is still 45")
	_expect(player.sim.cam_dir(Vector2(0, -1)).distance_to(up) < 0.01, "zoomed in, stick up still walks north-west")

	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_northup] PASS")
		quit(0)
	else:
		print("[t_northup] FAIL count=%d" % failures.size())
		quit(1)
