extends SceneTree
## CAMERA package (docs/orchestration/reports/claude-mmo-camera.md): the follow camera is the long-lens
## perspective camera measured from Durango (pitch 38.7, FOV 4.3, yaw 45: ISOCAM put the diagonal back), `size` stays its zoom (metres
## of view height at the focus) and the consumers line up with it.
## Usage: godot --headless --path game --script res://tests/t_camera.gd   -> "[t_camera] PASS", exit 0/1.

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
	print("[t_camera] %s %s" % ["ok" if ok else "FAIL", msg])

func _run() -> void:
	var Iso: GDScript = load("res://scripts/camera/iso_camera.gd")
	_expect(not Iso.ortho, "the run is not --cam-ortho")
	_expect(Iso.PROJECTION == Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(Iso.PITCH_DEG, -38.7) and is_equal_approx(Iso.YAW_DEG, 45.0) and is_equal_approx(Iso.FOV_DEG, 4.3),
		"constants: perspective, pitch -38.7, yaw 45, FOV 4.3")
	_expect(Iso.view_basis().is_equal_approx(Basis.from_euler(Vector3(deg_to_rad(-38.7), deg_to_rad(45.0), 0.0))), "view_basis() is the shipped angle")
	# ISOCAM: the iso range keeps the Durango lens; below ISO_MIN_SIZE pitch, lens and lift blend to the close view.
	for s in [Iso.ISO_MIN_SIZE, Iso.DEFAULT_SIZE, Iso.MAX_SIZE]:
		_expect(is_zero_approx(Iso.close_t(s)) and is_equal_approx(Iso.pitch_for(s), -38.7) and is_equal_approx(Iso.fov_for(s), 4.3), "zoom %.1f m is the iso view" % s)
	_expect(is_equal_approx(Iso.close_t(Iso.MIN_SIZE), 1.0) and is_equal_approx(Iso.pitch_for(Iso.MIN_SIZE), Iso.CLOSE_PITCH_DEG) and is_equal_approx(Iso.fov_for(Iso.MIN_SIZE), Iso.CLOSE_FOV_DEG), "the closest zoom is the close view")
	var prev := -90.0
	for i in 11:
		var p: float = Iso.pitch_for(lerpf(Iso.ISO_MIN_SIZE, Iso.MIN_SIZE, float(i) / 10.0))
		_expect(p >= prev - 1e-4, "zooming in only ever tilts toward horizontal (%.2f deg)" % p)
		prev = p
	_expect(Iso.CLOSE_PITCH_DEG + Iso.CLOSE_FOV_DEG * 0.5 < 0.0, "the close view's top edge stays under the horizon (no sky band)")
	_expect(absf(Iso.distance_for(11.0) - 11.0 / (2.0 * tan(deg_to_rad(2.15)))) < 0.01, "distance_for(11) = %.1f m" % Iso.distance_for(11.0))
	_expect(Iso.cull_range(8.0) > Iso.distance_for(Iso.LAB_MAX_SIZE), "cull ranges reach past the farthest lab camera (%.0f m)" % Iso.cull_range(8.0))

	var host := Node3D.new()
	get_root().add_child(host)
	var target := Node3D.new()
	host.add_child(target)
	target.global_position = Vector3(12.0, 1.0, -7.0)
	var cam = Iso.new()
	cam.target_path = target.get_path()
	host.add_child(cam)
	cam.current = true
	await process_frame
	_expect(cam.projection == Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(cam.fov, 4.3), "the camera is perspective with a 4.3 deg lens")
	_expect(is_equal_approx(cam.size, Iso.DEFAULT_SIZE) and is_equal_approx(cam.distance, Iso.distance_for(cam.size)), "default zoom %.1f m at %.1f m" % [cam.size, cam.distance])
	_expect(cam.rotation_degrees.is_equal_approx(Vector3(-38.7, 45.0, 0.0)), "rotation %s" % cam.rotation_degrees)
	_expect(cam.focus_point().distance_to(target.global_position) < 0.01, "it looks at its target (%.3f m off)" % cam.focus_point().distance_to(target.global_position))
	_expect(Iso.focus.distance_to(target.global_position) < 0.01, "it publishes the focus it looks at")
	var view: Vector2 = cam.get_viewport().get_visible_rect().size
	var c: Vector2 = cam.unproject_position(target.global_position)
	_expect(c.distance_to(view * 0.5) < 0.5, "the target is at the screen centre (%s of %s)" % [c, view])
	# size is the view height at the focus: a point size/2 up the image plane sits on the top edge.
	var up: Vector3 = cam.global_basis.y
	var top: Vector2 = cam.unproject_position(target.global_position + up * cam.size * 0.5)
	_expect(absf(top.y) < 1.0, "size %.1f m is the view's height at the focus (top edge at y=%.2f)" % [cam.size, top.y])
	# A tap ray (player_input / build_placer) from the screen centre reaches the focus within the far plane.
	var o: Vector3 = cam.project_ray_origin(view * 0.5)
	var n: Vector3 = cam.project_ray_normal(view * 0.5)
	var t := (target.global_position.y - o.y) / n.y
	_expect(t > 0.0 and t < cam.far and (o + n * t).distance_to(target.global_position) < 0.05, "a tap ray at the centre hits the focus %.0f m out, inside far %.0f m" % [t, cam.far])
	# The lens: ground at the top edge is smaller than at the bottom, and a tall thing at the right edge leans out.
	var m_bot: float = cam.unproject_position(target.global_position - _fwd(cam) * 4.0 + _right(cam)).x - cam.unproject_position(target.global_position - _fwd(cam) * 4.0).x
	var m_top: float = cam.unproject_position(target.global_position + _fwd(cam) * 4.0 + _right(cam)).x - cam.unproject_position(target.global_position + _fwd(cam) * 4.0).x
	_expect(m_top < m_bot and m_top > m_bot * 0.9, "a metre 4 m up the screen is %.1f px, 4 m down %.1f px (the ground recedes gently)" % [m_top, m_bot])
	var edge: Vector3 = target.global_position + _right(cam) * (view.x * 0.5 / view.y * cam.size)
	var lean: Vector2 = cam.unproject_position(edge + Vector3.UP * 10.0) - cam.unproject_position(edge)
	var deg := rad_to_deg(atan2(lean.x, -lean.y))
	_expect(deg > 1.5 and deg < 5.0, "a 10 m pole at the right edge leans out %.2f deg" % deg)
	_expect(absf(Iso.parallax - Iso.PARALLAX_GAIN * sin(deg_to_rad(38.7)) / cam.distance) < 1e-6, "parallax_strength = gain * sin(pitch) / distance (%.5f)" % Iso.parallax)
	# Zoom: the distance and the depth band follow size; the wheel and pinch stay inside min..max.
	for s in [Iso.MIN_SIZE, Iso.ISO_MIN_SIZE, Iso.MAX_SIZE, Iso.MIN_SIZE]:
		cam.size = s
		await process_frame
		var lifted: Vector3 = target.global_position + Vector3.UP * Iso.CLOSE_LIFT_M * Iso.close_t(s)
		_expect(cam.focus_point().distance_to(lifted) < 0.01 and absf(cam.global_position.distance_to(lifted) - Iso.distance_for(s)) < 0.01,
			"zoom %.1f m takes effect in one frame (the focus stays on the target, %.1f m back)" % [s, cam.global_position.distance_to(lifted)])
		_expect(absf(cam.rotation_degrees.x - Iso.pitch_for(s)) < 0.01 and is_equal_approx(cam.fov, Iso.fov_for(s)) and absf(cam.rotation_degrees.y - 45.0) < 0.01,
			"zoom %.1f m: pitch %.1f, lens %.1f deg, yaw %.0f (fixed)" % [s, cam.rotation_degrees.x, cam.fov, cam.rotation_degrees.y])
		var g: float = cam.ground_half_depth()
		var close: bool = Iso.close_t(s) > 0.0
		_expect(is_equal_approx(cam.distance, Iso.distance_for(s)) and (cam.near <= 0.5 if close else cam.near < cam.distance - g - 20.0) and cam.far > cam.distance + cam.view_depth() + 20.0,
			"zoom %.1f m: %.0f m back, near %.1f far %.0f around the ground %.0f-%.0f m" % [s, cam.distance, cam.near, cam.far, cam.distance - g, cam.distance + cam.view_depth()])
		# A tap at the centre still lands on her (player_input's ray), inside the far plane.
		var vo: Vector3 = cam.project_ray_origin(view * 0.5)
		var vn: Vector3 = cam.project_ray_normal(view * 0.5)
		var vt := (lifted.y - vo.y) / vn.y
		_expect(vt > 0.0 and vt < cam.far and (vo + vn * vt).distance_to(lifted) < 0.05, "zoom %.1f m: a centre tap ray reaches the focus" % s)
	_expect(cam.ground_half_depth() <= Iso.SHADOW_DEPTH_MAX and cam.view_depth() > 50.0, "close up the far plane reaches %.0f m past her, the shadow band stops at %.0f m" % [cam.view_depth(), cam.ground_half_depth()])
	var pinch := TouchGestures.new()
	host.add_child(pinch)
	cam.size = 11.0
	pinch._zoom(10.0)
	_expect(is_equal_approx(cam.size, cam.max_size), "pinching out stops at the camera's max %.0f m (got %.1f)" % [cam.max_size, cam.size])
	pinch._zoom(0.01)
	_expect(is_equal_approx(cam.size, cam.min_size), "pinching in stops at the camera's min %.0f m (got %.1f)" % [cam.min_size, cam.size])
	# Occlusion's sight test leans with the props: a tree right of the focus shifts the line left by the
	# same lean the shader gives the crown.
	cam.size = 11.0
	await process_frame
	var base: Vector3 = Iso.focus + _right(cam) * 5.0
	var line: Array = Occlusion.unlean(Vector3(base.x, base.y + 4.0, base.z), Vector3.UP, base)
	var want: Vector3 = Vector3(base.x, base.y + 4.0, base.z) - _right(cam) * (Iso.parallax * 4.0 * 5.0)
	_expect((line[0] as Vector3).distance_to(want) < 1e-4, "the sight line unleans by parallax * height * side")
	host.queue_free()
	await process_frame
	if failures.is_empty():
		print("[t_camera] PASS")
		quit(0)
	else:
		print("[t_camera] FAIL count=%d" % failures.size())
		quit(1)

func _right(cam: Camera3D) -> Vector3:
	return Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()

func _fwd(cam: Camera3D) -> Vector3:
	return Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
