extends SceneTree
## WAVES acceptance (owner 2026-10-28: "I want wave effects on the water too"; bug: "water see-through
## glitch when on the beach"). On the home island: the sea has its SeaWaves driver and a shore-wash skin
## on sea-facing beaches only; a forced storm raises the swell, chop, foam and run-up over clear, and a
## runtime without weather stays calm; the logical sea (HarbourSite.WATER_Y, the plane's height, the
## shader's water_y, WaterAccess depth and swimming) is the same in both; no nodes are added per frame.
## Then, in a small window per renderer (t_waves_render.gd), both shaders compile and deep water hides
## what is under it while shallow water still shows it. --no-render skips the windowed half.
## Run: Godot --headless --path game --script res://tests/t_waves.gd -> "[t_waves] PASS", exit 0/1.

var _fails: PackedStringArray = []
var _started := false

func _process(_delta: float) -> bool:
	if _started or root.get_node_or_null("Data") == null or root.get_node_or_null("World") == null:
		return false
	_started = true
	_run.call_deferred()
	return false

func _ok(cond: bool, what: String) -> void:
	print("[t_waves] %s %s" % ["ok" if cond else "FAIL", what])
	if not cond:
		_fails.append(what)

func _count(n: Node) -> int:
	var c := 1
	for k in n.get_children():
		c += _count(k)
	return c

func _run() -> void:
	var world: Node = root.get_node("World")
	var SW: GDScript = load("res://scripts/world/sea_waves.gd")
	var WA: GDScript = load("res://scripts/player/water_access.gd")
	var HS: GDScript = load("res://scripts/world/harbour_site.gd")
	var host := Node3D.new()
	root.add_child(host)
	world.load_island(host, &"home_grassland", Vector3(0, 1, 18), false)
	await process_frame
	var rt: Node = world.runtime
	var sea: Node = rt.get_node_or_null("SeaWaves")
	_ok(sea != null, "the island has a SeaWaves driver")
	if sea == null:
		_finish()
		return
	var water: MeshInstance3D
	for c in rt.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).material_override == sea.water_mat:
			water = c
	_ok(water != null and (water.mesh as PlaneMesh).subdivide_width >= 64, "the sea plane is subdivided for the swell")
	var skin := sea.get_node_or_null("ShoreWash") as MeshInstance3D
	_ok(skin != null and skin.mesh != null, "the shore-wash skin exists")
	# Foam along the shore: skin vertices sit in the swash band and most of them are surf (sea coast).
	if skin and skin.mesh:
		var arr := skin.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var surf := 0
		for i in verts.size():
			if cols[i].r > 0.5:
				surf += 1
		print("[t_waves] skin verts=%d surf=%d" % [verts.size(), surf])
		_ok(verts.size() > 200 and surf > verts.size() / 3, "foam: the skin runs along the coast (%d verts, %d surf)" % [verts.size(), surf])
		var surf_img: Image = (sea.water_mat.get_shader_parameter("surf_tex") as Texture2D).get_image()
		var res: int = surf_img.get_width()
		var riv: PackedFloat32Array = rt._river_d
		var zero_in_river := true
		var sd := surf_img.get_data()
		for i in res * res:
			if riv[i] < 3.0 and sd[i] != 0:
				zero_in_river = false
				break
		_ok(zero_in_river, "no surf in the river channel")
	_ok(is_equal_approx(SW.target_state(null), 0.0), "no weather -> calm sea")
	var t0 := Time.get_ticks_usec()
	var again: Image = SW.surf_mask(rt)
	SW.build_shore_skin(rt, -0.05, float(SW.STORM["run_up"]), again)
	var build_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("[t_waves] surf mask + skin build %.1f ms" % build_ms)
	_ok(build_ms < 250.0, "the shore build is cheap (%.1f ms)" % build_ms)

	var probes: Array[Vector3] = []
	if skin and skin.mesh:
		var vs: PackedVector3Array = skin.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in range(0, vs.size(), maxi(1, vs.size() / 40)):
			probes.append(vs[i] + Vector3(0.3, 0, 0.3))
	probes.append(Vector3(0, 0, -400))
	var w: Object = rt.get("weather")
	var logical := {}
	for state in ["clear", "storm"]:
		var storm: bool = state == "storm"
		w.set("raining", storm)
		w.set("storm", storm)
		w.set("rain_amount", 1.0 if storm else 0.0)
		sea.settle()
		var amp: float = sea.water_mat.get_shader_parameter("wave_amp")
		logical[state] = {
			"amp": amp,
			"chop": float(sea.water_mat.get_shader_parameter("chop")),
			"foam": float(sea.water_mat.get_shader_parameter("foam_amt")),
			"run": float(sea.shore_mat.get_shader_parameter("run_up")),
			"water_y": float(sea.water_mat.get_shader_parameter("water_y")),
			"plane_y": water.position.y,
			"depths": probes.map(func(p: Vector3) -> float: return WA.depth(p)),
			"swim": probes.map(func(p: Vector3) -> bool: return WA.is_swimming(p)),
		}
		print("[t_waves] %s wave_amp=%.2f chop=%.2f foam=%.2f run_up=%.2f" % [state, amp, logical[state]["chop"], logical[state]["foam"], logical[state]["run"]])
	var c: Dictionary = logical["clear"]
	var s: Dictionary = logical["storm"]
	_ok(s["amp"] >= c["amp"] * 3.0, "storm swell >= 3x clear (%.2f vs %.2f m)" % [s["amp"], c["amp"]])
	_ok(s["chop"] > c["chop"] and s["foam"] > c["foam"] and s["run"] > c["run"], "storm is choppier, foamier and runs further up the beach")
	_ok(c["amp"] <= 0.1, "clear sea is gentle (%.2f m)" % c["amp"])
	_ok(is_equal_approx(HS.WATER_Y, -0.05), "logical sea level is -0.05")
	for st: Dictionary in [c, s]:
		_ok(is_equal_approx(st["water_y"], HS.WATER_Y) and is_equal_approx(st["plane_y"], HS.WATER_Y), "shader water_y and plane height stay at the logical sea")
	_ok(c["depths"] == s["depths"] and c["swim"] == s["swim"], "wading depth and swimming are the same in clear and storm")

	# No node growth while the sea state changes and the driver ticks.
	var before := _count(rt)
	for i in 90:
		w.set("rain_amount", 0.5 + 0.5 * sin(float(i) * 0.2))
		w.set("storm", i % 30 < 15)
		await process_frame
	_ok(_count(rt) == before, "no node growth over 90 frames (%d)" % before)

	var shader_src := FileAccess.get_file_as_string("res://scripts/world/water.gdshader")
	_ok(shader_src.contains("mix(0.62, 1.0, smoothstep(0.0, 1.6, depth))"), "open water reaches full opacity (see-through regression)")
	if not "--no-render" in OS.get_cmdline_user_args():
		_render_checks()
	host.queue_free()
	_finish()

## One windowed child per renderer: compile both shaders and read the deep / shallow pixels.
func _render_checks() -> void:
	for method in ["forward_plus", "gl_compatibility"]:
		var out: Array = []
		var code := OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"),
			"--rendering-method", method, "--resolution", "160x120", "--audio-driver", "Dummy",
			"--script", "res://tests/t_waves_render.gd"], out, true)
		var txt := "\n".join(out)
		var line := ""
		for l in txt.split("\n"):
			if l.begins_with("[t_waves_render]"):
				line = l
		print("[t_waves] %s exit=%d %s" % [method, code, line])
		_ok(code == 0 and line != "", "%s: the render probe ran" % method)
		_ok(not txt.contains("SHADER ERROR"), "%s: water and shore shaders compile" % method)
		if line != "":
			var deep := float(line.get_slice("deep=", 1).get_slice(" ", 0))
			var shallow := float(line.get_slice("shallow=", 1).get_slice(" ", 0))
			_ok(deep < 0.02, "%s: deep water is solid (red bleed %.3f; the 0.95-alpha sea bled 0.14)" % [method, deep])
			_ok(shallow > 0.1, "%s: shallow water still fades to the bed (%.3f)" % [method, shallow])

func _finish() -> void:
	if _fails.is_empty():
		print("[t_waves] PASS")
		quit(0)
	else:
		print("[t_waves] FAIL %d: %s" % [_fails.size(), ", ".join(_fails)])
		quit(1)
